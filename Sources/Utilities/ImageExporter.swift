import ImageIO
import CoreGraphics
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
        let srgbImage = convertToSRGB(image) ?? image
        CGImageDestinationAddImage(dest, srgbImage, props.isEmpty ? nil : props as CFDictionary)

        guard CGImageDestinationFinalize(dest) else {
            throw ExportError.finalizeFailed(url)
        }
    }

    private static func convertToSRGB(_ image: CGImage) -> CGImage? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let w = image.width, h = image.height
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: srgb,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    static func exportBatch(
        documents: [ImageDocument],
        to folderURL: URL,
        format: ExportFormat,
        quality: Double,
        progressHandler: @escaping (Int, Int) -> Void,
        completion: @escaping (ExportResult) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var succeeded = 0
            var failed: [(String, String)] = []
            let total = documents.count

            for (i, doc) in documents.enumerated() {
                let image: CGImage
                do {
                    if let cached = doc.cgImage {
                        image = cached
                    } else {
                        image = try RAWImageDecoder.decode(url: doc.url)
                    }
                } catch {
                    failed.append((doc.filename, error.localizedDescription))
                    progressHandler(i + 1, total)
                    continue
                }

                let stem = (doc.filename as NSString).deletingPathExtension
                let outURL = folderURL
                    .appendingPathComponent(stem)
                    .appendingPathExtension(format.fileExtension)

                do {
                    try exportSingle(image: image, to: outURL, format: format, quality: quality)
                    succeeded += 1
                } catch {
                    failed.append((doc.filename, error.localizedDescription))
                }
                progressHandler(i + 1, total)
            }

            completion(ExportResult(total: total, succeeded: succeeded, failed: failed))
        }
    }
}
