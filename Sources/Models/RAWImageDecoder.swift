import ImageIO
import CoreGraphics
import CoreImage
import Foundation

// Breadcrumb: last RAF decode operation. BG threads update via strlcpy before each risky call.
// Signal handler (CrashReporter.swift) reads this to show which step crashed.
// Writes are lock-serialised so parallel decodes can't interleave bytes; the signal
// handler reads lock-free (async-signal-safe), a torn read there is acceptable.
var iphotoLastOpBuf = [CChar](repeating: 0, count: 512)
private let breadcrumbLock = NSLock()

func iphotoBreadcrumb(_ message: String) {
    breadcrumbLock.lock()
    message.withCString { strlcpy(&iphotoLastOpBuf, $0, iphotoLastOpBuf.count) }
    breadcrumbLock.unlock()
}

// Geteilter CIContext — laut Apple-Dokumentation thread-safe für Rendering.
// Einen Context pro App statt einen pro Thread: Metal/GPU erschöpft sich nicht mehr
// wenn 20+ Thumbnails gleichzeitig dekodiert werden. Auch von ImageExporter genutzt.
let sharedSRGBCIContext = CIContext(options: [.useSoftwareRenderer: false])

// Begrenzt gleichzeitige CIContext-Renders auf 2 (GPU-Schutz bei Vollbild-Decodes).
private let ciSemaphore = DispatchSemaphore(value: 2)

// Begrenzt gleichzeitige ImageIO-Thumbnail-Decodes auf 3.
// CGImageSourceCreateThumbnailAtIndex ist auf macOS 11 nicht thread-safe
// bei parallelem Zugriff auf viele RAF-embedded-JPEGs → SIGSEGV.
private let imageIOSemaphore = DispatchSemaphore(value: 3)

private func makeCIContext() -> CIContext { sharedSRGBCIContext }

enum DecoderError: LocalizedError {
    case cannotCreateSource
    case cannotDecodeImage

    var errorDescription: String? {
        switch self {
        case .cannotCreateSource: return "Datei konnte nicht geöffnet werden."
        case .cannotDecodeImage:  return "Bild konnte nicht dekodiert werden."
        }
    }
}

struct RAWImageDecoder {
    // true, wenn decode() ohnehin nur das eingebettete JPEG liefert (RAF auf macOS 11) —
    // eine separate Preview-Phase mit Dwell bringt dann nichts.
    static func fullDecodeIsCheap(url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "raf" else { return false }
        if #available(macOS 12.0, *) { return false }
        return true
    }

    static func decode(url: URL) throws -> CGImage {
        // macOS 11: Der System-RAW-Decoder für RAF crasht mit SIGSEGV — ImageIO überspringen.
        if url.pathExtension.lowercased() == "raf" {
            if #available(macOS 12.0, *) {
                // macOS 12+: ImageIO unterstützt RAF nativ — weiter wie üblich
            } else {
                Log.trace("decode macOS11-RAF-Pfad: \(url.lastPathComponent)")
                if let image = decodeEmbeddedJPEG(url: url) { return image }
                throw DecoderError.cannotDecodeImage
            }
        }

        // Versuch 1: ImageIO (funktioniert für alle Standard-Formate + RAW auf macOS 12+)
        if let image = decodeViaImageIO(url: url) {
            return image
        }

        // Versuch 2: Eingebetteten JPEG-Preview extrahieren (Fallback für RAF auf macOS 11)
        if let image = decodeEmbeddedJPEG(url: url) {
            return image
        }

        throw DecoderError.cannotDecodeImage
    }

    static func thumbnail(url: URL, maxDimension: Int = 160) throws -> CGImage {
        // macOS 11: Der System-RAW-Decoder für RAF crasht mit SIGSEGV — ImageIO überspringen.
        if url.pathExtension.lowercased() == "raf" {
            if #available(macOS 12.0, *) {
                // macOS 12+: ImageIO unterstützt RAF nativ — weiter wie üblich
            } else {
                Log.trace("thumbnail(\(maxDimension)px) macOS11-RAF-Pfad: \(url.lastPathComponent)")
                if let thumb = decodeEmbeddedJPEG(url: url, maxDimension: maxDimension) { return thumb }
                throw DecoderError.cannotDecodeImage
            }
        }

        // Versuch 1: RAF – eingebettetes JPEG-Preview direkt aus dem Container lesen (schnell, kleine Bitmap)
        if let thumb = decodeEmbeddedJPEG(url: url, maxDimension: maxDimension) {
            return thumb
        }

        // Versuch 2: ImageIO-Thumbnail für JPEG/PNG/HEIC/TIFF und RAW auf macOS 12+
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
            ]
            if let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) {
                return thumb
            }
        }

        throw DecoderError.cannotDecodeImage
    }

    // MARK: - Private

    private static func decodeViaImageIO(url: URL) -> CGImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }
        let decodeOptions: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, decodeOptions as CFDictionary) else {
            return nil
        }
        return applyExifOrientation(image, source: source)
    }

    // Liest den JPEG-Preview der im RAF-Dateiheader referenziert ist.
    // RAF v0200/v0201 (Fujifilm X-T1 bis X-T5 u.a.) speichert Offset+Länge
    // des embedded JPEG als Big-Endian UInt32 bei Byte 0x54 / 0x58.
    //
    // maxDimension != nil → Thumbnail-Pfad: CGImageSourceCreateThumbnailAtIndex mit
    // kCGImageSourceThumbnailMaxPixelSize + kCGImageSourceCreateThumbnailWithTransform.
    // Dekodiert direkt auf Zielgröße (≤ 1 MB), kein volles 37-MB-Zwischenbild, kein CIImage.
    // Verhindert den OOM/SIGABRT bei parallelem Batch-Laden großer RAF-Alben.
    //
    // maxDimension == nil → Vollbild-Pfad: CGImageSourceCreateImageAtIndex + applyExifOrientation
    // (nur für decode() genutzt).
    private static func decodeEmbeddedJPEG(url: URL, maxDimension: Int? = nil) -> CGImage? {
        guard let ext = url.pathExtension.lowercased() as String?,
              ext == "raf" else { return nil }

        let name = url.lastPathComponent
        iphotoBreadcrumb("decodeEmbeddedJPEG: FileHandle öffnen (\(name))")
        Log.trace("FileHandle öffnen: \(name)")
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) } catch {
            Log.error("RAF: FileHandle konnte nicht geöffnet werden (\(name)): \(error.localizedDescription)")
            return nil
        }
        defer { try? handle.close() }

        // Header lesen (mindestens 96 Bytes) — werfende API verhindert ObjC-Exception → SIGABRT
        iphotoBreadcrumb("decodeEmbeddedJPEG: Header lesen (\(name))")
        guard let header = try? handle.read(upToCount: 96), header.count >= 96 else {
            Log.error("RAF: Header unvollständig oder nicht lesbar (\(name))")
            return nil
        }

        // RAF-Signatur prüfen
        let sig = String(bytes: header.prefix(16), encoding: .ascii) ?? ""
        guard sig.hasPrefix("FUJIFILMCCD-RAW") else {
            Log.error("RAF: Signatur ungültig (\(name)): '\(sig)'")
            return nil
        }

        // JPEG-Offset und -Länge aus dem Verzeichnis lesen (Big-Endian)
        let jpegOffset = header.readUInt32BE(at: 0x54)
        let jpegLength = header.readUInt32BE(at: 0x58)
        guard jpegOffset > 0, jpegLength > 0 else {
            Log.error("RAF: kein eingebettetes JPEG referenziert (\(name)): offset=\(jpegOffset) length=\(jpegLength)")
            return nil
        }

        // JPEG-Bytes extrahieren
        iphotoBreadcrumb("decodeEmbeddedJPEG: JPEG-Bytes lesen @\(jpegOffset)+\(jpegLength) (\(name))")
        Log.trace("JPEG-Bytes lesen: offset=\(jpegOffset) length=\(jpegLength) \(name)")
        guard (try? handle.seek(toOffset: UInt64(jpegOffset))) != nil else {
            Log.error("RAF: Seek auf JPEG-Offset \(jpegOffset) fehlgeschlagen (\(name))")
            return nil
        }
        guard let jpegData = try? handle.read(upToCount: Int(jpegLength)),
              jpegData.count >= 4,
              jpegData[0] == 0xFF, jpegData[1] == 0xD8 else {
            Log.error("RAF: eingebettetes JPEG unlesbar oder ohne JPEG-Magic (\(name))")
            return nil
        }

        imageIOSemaphore.wait()
        defer { imageIOSemaphore.signal() }

        iphotoBreadcrumb("decodeEmbeddedJPEG: CGImageSourceCreateWithData (\(name))")
        Log.trace("CGImageSourceCreateWithData: \(jpegData.count)B \(name)")
        guard let source = CGImageSourceCreateWithData(jpegData as CFData, nil) else { return nil }

        if let maxDim = maxDimension {
            // Thumbnail-Pfad: direkt auf Zielgröße dekodieren — kein volles 37-MB-Bild im Speicher.
            // kCGImageSourceCreateThumbnailWithTransform wendet EXIF-Rotation an, kein CIImage nötig.
            iphotoBreadcrumb("decodeEmbeddedJPEG: CGImageSourceCreateThumbnailAtIndex (\(name))")
            Log.trace("CGImageSourceCreateThumbnailAtIndex: \(maxDim)px \(name)")
            // FromImageAlways: erzwingt JPEG-DCT-Sub-Sampling (1/8 Zwischenstufe) statt des
            // vollen Bildes. FromImageIfAbsent crashte bei großen embedded JPEGs ohne IFD1-Thumbnail
            // (z.B. neuere Fujifilm-Kameras mit 5 MB+ Preview) — ImageIO dekodierte dort das
            // komplette JPEG (~52–100 MB Zwischenbild) → OOM → SIGSEGV/SIGILL.
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDim
            ]
            let t0 = Date()
            let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary)
            Log.trace("CreateThumbnailAtIndex fertig: \(Int(Date().timeIntervalSince(t0) * 1000)) ms \(name)")
            return thumb
        }

        // Vollbild-Pfad: volle Auflösung + manuelle EXIF-Rotation (für decode())
        iphotoBreadcrumb("decodeEmbeddedJPEG: CGImageSourceCreateImageAtIndex (\(name))")
        Log.trace("CGImageSourceCreateImageAtIndex: \(name)")
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        iphotoBreadcrumb("decodeEmbeddedJPEG: applyExifOrientation (\(name)) \(image.width)x\(image.height)")
        Log.trace("applyExifOrientation: \(image.width)×\(image.height) \(name)")
        return applyExifOrientation(image, source: source)
    }

    private static func applyExifOrientation(_ image: CGImage, source: CGImageSource) -> CGImage {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let raw = props[kCGImagePropertyOrientation] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: raw),
              orientation != .up else { return image }
        ciSemaphore.wait()
        defer { ciSemaphore.signal() }
        iphotoBreadcrumb("applyExifOrientation: CIImage.oriented (raw=\(raw))")
        Log.trace("CIImage.oriented: raw=\(raw) \(image.width)×\(image.height)")
        let ci = CIImage(cgImage: image).oriented(orientation)
        iphotoBreadcrumb("applyExifOrientation: CIContext.createCGImage")
        Log.trace("CIContext.createCGImage: \(Int(ci.extent.width))×\(Int(ci.extent.height))")
        let result = sharedSRGBCIContext.createCGImage(ci, from: ci.extent)
        iphotoBreadcrumb("applyExifOrientation: done")
        return result ?? image
    }

    private static func scaledDown(_ image: CGImage, maxDimension: Int) -> CGImage {
        let w = image.width, h = image.height
        let scale = min(CGFloat(maxDimension) / CGFloat(max(w, h)), 1.0)
        let newW = Int(CGFloat(w) * scale)
        let newH = Int(CGFloat(h) * scale)
        guard let ctx = CGContext(
            data: nil, width: newW, height: newH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage() ?? image
    }
}

