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
        quality: Double
    ) throws {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, format.uti as CFString, 1, nil
        ) else {
            throw ExportError.cannotCreateDestination(url)
        }

        var props: [CFString: Any] = [:]
        if format.supportsQuality {
            props[kCGImageDestinationLossyCompressionQuality] = quality
        }

        // Immer nach sRGB konvertieren — Adobe RGB und andere Profile
        // werden von manchen Viewern (inkl. Preview auf macOS 11) nicht korrekt gelesen.
        let t0 = Date()
        let srgbImage = convertToSRGB(image) ?? image
        Log.debug(String(format: "sRGB-Konvertierung: %.1f ms (%@)", Date().timeIntervalSince(t0) * 1000, url.lastPathComponent))
        CGImageDestinationAddImage(dest, srgbImage, props.isEmpty ? nil : props as CFDictionary)

        guard CGImageDestinationFinalize(dest) else {
            throw ExportError.finalizeFailed(url)
        }
    }

    private static func convertToSRGB(_ image: CGImage) -> CGImage? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let ci = CIImage(cgImage: image)
        return sharedSRGBCIContext.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: srgb)
    }

}
