import ImageIO
import CoreGraphics
import CoreImage
import Foundation

// CIContext ist nicht thread-safe — jeder Decode-Aufruf erstellt seinen eigenen Context.
private func makeCIContext() -> CIContext {
    CIContext(options: [.useSoftwareRenderer: false])
}

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
    static func decode(url: URL) throws -> CGImage {
        // macOS 11: Der System-RAW-Decoder für RAF crasht mit SIGSEGV — ImageIO überspringen.
        if url.pathExtension.lowercased() == "raf" {
            if #available(macOS 12.0, *) {
                // macOS 12+: ImageIO unterstützt RAF nativ — weiter wie üblich
            } else {
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
        // Versuch 1: RAF – eingebettetes JPEG-Preview direkt aus dem Container lesen (schnell, hohe Qualität)
        if let full = decodeEmbeddedJPEG(url: url) {
            return scaledDown(full, maxDimension: maxDimension)
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
    private static func decodeEmbeddedJPEG(url: URL) -> CGImage? {
        guard let ext = url.pathExtension.lowercased() as String?,
              ext == "raf" else { return nil }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }

        // Header lesen (mindestens 96 Bytes)
        let header = handle.readData(ofLength: 96)
        guard header.count >= 96 else { return nil }

        // RAF-Signatur prüfen
        let sig = String(bytes: header.prefix(16), encoding: .ascii) ?? ""
        guard sig.hasPrefix("FUJIFILMCCD-RAW") else { return nil }

        // JPEG-Offset und -Länge aus dem Verzeichnis lesen (Big-Endian)
        let jpegOffset = header.readUInt32BE(at: 0x54)
        let jpegLength = header.readUInt32BE(at: 0x58)
        guard jpegOffset > 0, jpegLength > 0 else { return nil }

        // JPEG-Bytes extrahieren
        handle.seek(toFileOffset: UInt64(jpegOffset))
        let jpegData = handle.readData(ofLength: Int(jpegLength))
        guard jpegData.count >= 4,
              jpegData[0] == 0xFF, jpegData[1] == 0xD8 else { return nil }

        guard let source = CGImageSourceCreateWithData(jpegData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        return applyExifOrientation(image, source: source)
    }

    private static func applyExifOrientation(_ image: CGImage, source: CGImageSource) -> CGImage {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let raw = props[kCGImagePropertyOrientation] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: raw),
              orientation != .up else { return image }
        let ci = CIImage(cgImage: image).oriented(orientation)
        return makeCIContext().createCGImage(ci, from: ci.extent) ?? image
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

