import Foundation
import ImageIO
import CoreImage
import CoreGraphics
import AppKit

/// Erzeugt komprimierte JPEG-Backups einzelner Bilder in einem konfigurierbaren
/// Zielordner (`~/Pictures/iPhoto/Backups/<Jahr>/<Monat>/` als Default).
///
/// Reine Utility — keine ViewModel-Kopplung, keine Alerts. Aufrufer (ImageViewModel+Backup)
/// erledigt Multi-Selection, Pick-Schutz, Fortschritt und optionales Papierkorb-Verschieben.
enum BackupService {

    enum Result {
        case written(URL)
        case skipped(existingURL: URL)
        case failed(reason: String)

        var isSuccess: Bool {
            if case .written = self { return true }
            return false
        }
    }

    /// Führt ein Backup für ein einzelnes Bild durch. Blockiert bis fertig — Aufrufer
    /// muss auf einer Background-Queue laufen.
    /// `writtenInBatch` verhindert, dass zwei Quelldateien mit gleichem Namen sich gegenseitig
    /// überschreiben — auch im `.overwrite`-Modus (der nur für *vorherige Runs* gilt).
    /// `batchLock` serialisiert Zugriffe auf `writtenInBatch` bei paralleler Ausführung (#66).
    static func backup(source: URL, root: URL, settings: BackupSettings,
                       writtenInBatch: inout Set<String>,
                       batchLock: NSLock? = nil) -> Result {
        // Open the image source ONCE — reused for date extraction AND metadata copy (#66).
        let sourceProps = readImageProperties(source: source)

        // Zielordner <root>/<Jahr>/<Monat>/ aus Aufnahmedatum (EXIF DateTimeOriginal)
        // → File-mtime als Fallback. So landen Backups jahresweise sortiert wie in
        // Fotos.app, unabhängig davon wann sie erzeugt wurden.
        let captureDate = extractCaptureDate(from: sourceProps) ?? fileModificationDate(source) ?? Date()
        let subfolder = yearMonthSubfolder(date: captureDate)
        let targetDir = root.appendingPathComponent(subfolder, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        } catch {
            return .failed(reason: "Zielordner konnte nicht angelegt werden: \(error.localizedDescription)")
        }

        let stem = source.deletingPathExtension().lastPathComponent
        let baseTarget = targetDir.appendingPathComponent("\(stem).jpg")
        let target: URL
        batchLock?.lock()
        let alreadyWritten = writtenInBatch.contains(baseTarget.path)
        batchLock?.unlock()
        // If this exact path was already written in this batch, force rename to avoid
        // silently overwriting a file we just created (same filename from two different dirs).
        let effectiveMode: BackupSettings.CollisionMode = alreadyWritten ? .rename : settings.collisionMode
        switch resolveCollision(baseTarget: baseTarget, mode: effectiveMode) {
        case .use(let url):   target = url
        case .skip(let url):  return .skipped(existingURL: url)
        }

        // Volle Auflösung dekodieren — Downscale danach optional per CoreImage.
        // Fällt der Decode aus, ist das Bild in iPhoto ohnehin nicht darstellbar.
        let cgImage: CGImage
        do {
            cgImage = try RAWImageDecoder.decode(url: source)
        } catch {
            return .failed(reason: "Bild konnte nicht dekodiert werden: \(error.localizedDescription)")
        }

        let outImage = settings.downscaleEnabled
            ? downscale(cgImage, longSide: settings.longSidePixels) ?? cgImage
            : cgImage

        // sRGB — Adobe-RGB/DisplayP3 werden von Preview/älteren Viewern sonst falsch angezeigt
        // (identische Konvertierung wie ImageExporter).
        let srgb = convertToSRGB(outImage) ?? outImage

        // Metadaten: optional Original-Properties (EXIF/TIFF/GPS/Orientation) mitschreiben.
        // Reuses sourceProps from above — no second CGImageSourceCreateWithURL (#66).
        var props: [CFString: Any] = [:]
        props[kCGImageDestinationLossyCompressionQuality] = settings.jpegQuality
        if settings.copyMetadata, let sp = sourceProps {
            merge(&props, with: sp)
            // Nach sRGB-Konvertierung ist die Orientation bereits angewandt — sonst würde
            // Preview das Bild ein zweites Mal rotieren.
            props[kCGImagePropertyOrientation] = 1
        }

        guard let dest = CGImageDestinationCreateWithURL(
            target as CFURL, "public.jpeg" as CFString, 1, nil
        ) else {
            return .failed(reason: "Ziel-JPEG konnte nicht erstellt werden.")
        }
        CGImageDestinationAddImage(dest, srgb, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            return .failed(reason: "Schreiben fehlgeschlagen: \(target.lastPathComponent)")
        }
        batchLock?.lock()
        writtenInBatch.insert(target.path)
        batchLock?.unlock()
        return .written(target)
    }

    // MARK: - Kollisions-Handling

    private enum CollisionResolution {
        case use(URL)
        case skip(URL)
    }

    private static func resolveCollision(baseTarget: URL,
                                         mode: BackupSettings.CollisionMode) -> CollisionResolution {
        let fm = FileManager.default
        guard fm.fileExists(atPath: baseTarget.path) else { return .use(baseTarget) }
        switch mode {
        case .overwrite: return .use(baseTarget)
        case .skip:      return .skip(baseTarget)
        case .rename:
            let dir = baseTarget.deletingLastPathComponent()
            let stem = baseTarget.deletingPathExtension().lastPathComponent
            let ext = baseTarget.pathExtension
            for n in 2...9999 {
                let candidate = dir.appendingPathComponent("\(stem)-\(n).\(ext)")
                if !fm.fileExists(atPath: candidate.path) { return .use(candidate) }
            }
            return .skip(baseTarget) // 9999 Kollisionen → überspringen statt überschreiben
        }
    }

    // MARK: - EXIF-Datum / Dateisystem-Datum

    private static let exifDateParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f
    }()

    private static func extractCaptureDate(from props: [CFString: Any]?) -> Date? {
        guard let props = props,
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String else {
            return nil
        }
        return exifDateParser.date(from: dateString)
    }

    private static func fileModificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    private static func yearMonthSubfolder(date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return String(format: "%04d/%02d", y, m)
    }

    // MARK: - ImageIO-Properties

    private static func readImageProperties(source: URL) -> [CFString: Any]? {
        guard let cgSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(cgSource, 0, nil) as? [CFString: Any] else {
            return nil
        }
        return props
    }

    private static func merge(_ target: inout [CFString: Any], with source: [CFString: Any]) {
        for (k, v) in source {
            // LossyCompressionQuality nicht aus Original übernehmen — wir setzen sie selbst.
            if k == kCGImageDestinationLossyCompressionQuality { continue }
            target[k] = v
        }
    }

    // MARK: - Downscale + sRGB

    private static func downscale(_ image: CGImage, longSide: Int) -> CGImage? {
        let w = image.width, h = image.height
        let long = max(w, h)
        guard long > longSide, longSide > 0 else { return image }
        let scale = CGFloat(longSide) / CGFloat(long)
        let ci = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return sharedSRGBCIContext.createCGImage(ci, from: ci.extent)
    }

    private static func convertToSRGB(_ image: CGImage) -> CGImage? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let ci = CIImage(cgImage: image)
        return sharedSRGBCIContext.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: srgb)
    }
}
