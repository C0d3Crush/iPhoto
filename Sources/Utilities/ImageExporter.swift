import ImageIO
import CoreGraphics
import CoreImage
import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case png  = "PNG"
    case tiff = "TIFF"
    case heif = "HEIF"

    var id: String { rawValue }

    var uti: String {
        switch self {
        case .jpeg: return "public.jpeg"
        case .png:  return "public.png"
        case .tiff: return "public.tiff"
        case .heif: return "public.heif"
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png:  return "png"
        case .tiff: return "tiff"
        case .heif: return "heic"
        }
    }

    var supportsQuality: Bool {
        self == .jpeg || self == .heif
    }
}

enum ExportError: LocalizedError {
    case cannotLoadImage(String)
    case cannotCreateDestination(URL)
    case finalizeFailed(URL)

    var errorDescription: String? {
        switch self {
        case .cannotLoadImage(let name):   return "Bild konnte nicht geladen werden: \(name)"
        case .cannotCreateDestination(let url): return "Zieldatei konnte nicht erstellt werden: \(url.lastPathComponent)"
        case .finalizeFailed(let url):     return "Schreiben fehlgeschlagen: \(url.lastPathComponent)"
        }
    }
}

struct ExportResult {
    let total: Int
    let succeeded: Int
    let failed: [(filename: String, reason: String)]
}

struct ImageExporter {
    static func exportSingle(
        image: CGImage,
        to url: URL,
        format: ExportFormat,
        quality: Double,
        sourceURL: URL? = nil
    ) throws {
        let exportSingleStart = Date()
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, format.uti as CFString, 1, nil
        ) else {
            throw ExportError.cannotCreateDestination(url)
        }

        var props: [CFString: Any] = [:]
        if format.supportsQuality {
            props[kCGImageDestinationLossyCompressionQuality] = quality
        }

        // Copy source EXIF/GPS/IPTC/TIFF metadata into the export file.
        if let srcURL = sourceURL,
           var meta = MetadataService.rawSourceProperties(url: srcURL) {
            // Pixels are already rotated by the render pipeline — write "up" so viewers don't rotate again.
            meta[kCGImagePropertyOrientation] = 1 as CFNumber
            // Remove top-level pixel dimensions; ImageIO derives them from the actual image data.
            meta.removeValue(forKey: kCGImagePropertyPixelWidth)
            meta.removeValue(forKey: kCGImagePropertyPixelHeight)
            for (k, v) in meta { props[k] = v }
        }

        let t0 = Date()
        // Use 16-bit output for lossless formats when source has >8 bpc (e.g. RAW → TIFF/PNG).
        let use16bit = !format.supportsQuality && image.bitsPerComponent > 8
        let srgbImage = convertToSRGB(image, use16bit: use16bit) ?? image
        Log.debug(String(format: "sRGB-Konvertierung: %.1f ms %dbit (%@)",
                         Date().timeIntervalSince(t0) * 1000, use16bit ? 16 : 8,
                         url.lastPathComponent))
        CGImageDestinationAddImage(dest, srgbImage, props.isEmpty ? nil : props as CFDictionary)

        guard CGImageDestinationFinalize(dest) else {
            throw ExportError.finalizeFailed(url)
        }
        Log.perf(String(format: "EXPORT-SINGLE %@ %.0f ms: %@",
                        format.rawValue, Date().timeIntervalSince(exportSingleStart) * 1000,
                        url.lastPathComponent))
    }

    private static func convertToSRGB(_ image: CGImage, use16bit: Bool = false) -> CGImage? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let ci = CIImage(cgImage: image)
        let fmt: CIFormat = use16bit ? .RGBA16 : .RGBA8
        return sharedSRGBCIContext.createCGImage(ci, from: ci.extent, format: fmt, colorSpace: srgb)
    }

}
