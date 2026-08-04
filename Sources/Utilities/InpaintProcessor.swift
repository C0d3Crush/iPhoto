import Foundation
import CoreGraphics
import ImageIO

struct InpaintProcessor {

    struct Config {
        var cmtDirectory: String
        var checkpointPath: String
        var python3Path: String
    }

    enum InpaintError: LocalizedError {
        case python3NotFound(String)
        case cmtNotFound(String)
        case checkpointNotFound(String)
        case writeFailed
        case processExited(Int32, String)
        case resultNotFound
        case imageConversionFailed

        var errorDescription: String? {
            switch self {
            case .python3NotFound(let p):  return "Python 3 nicht gefunden: \(p)"
            case .cmtNotFound(let p):      return "CMT demo.py nicht gefunden: \(p)"
            case .checkpointNotFound(let p): return "Checkpoint nicht gefunden: \(p)"
            case .writeFailed:             return "Temporäre Dateien konnten nicht geschrieben werden"
            case .processExited(let c, let e): return "CMT beendet (Code \(c)): \(e.isEmpty ? "kein Output" : e)"
            case .resultNotFound:          return "Kein Ergebnis-Bild im Output-Verzeichnis"
            case .imageConversionFailed:   return "Ergebnis-Bild konnte nicht geladen werden"
            }
        }
    }

    static func validateSetup(config: Config) throws {
        let fm = FileManager.default
        let python = expand(config.python3Path)
        guard fm.fileExists(atPath: python) else { throw InpaintError.python3NotFound(python) }

        let cmtDir = expand(config.cmtDirectory)
        let demo = (cmtDir as NSString).appendingPathComponent("demo.py")
        guard fm.fileExists(atPath: demo) else { throw InpaintError.cmtNotFound(demo) }

        let ckpt = expand(config.checkpointPath)
        guard fm.fileExists(atPath: ckpt) else { throw InpaintError.checkpointNotFound(ckpt) }
    }

    // Synchronous — must be called on a background queue.
    static func run(image: CGImage, mask: CGImage, config: Config) throws -> CGImage {
        try validateSetup(config: config)

        let fm = FileManager.default
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("iPhoto_inpaint_\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let imgURL  = tmp.appendingPathComponent("input.png")
        let maskURL = tmp.appendingPathComponent("mask.png")
        let outDir  = tmp.appendingPathComponent("out")
        try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

        guard savePNG(image, to: imgURL) else { throw InpaintError.writeFailed }

        let grayMask = toGrayscale(mask) ?? mask
        guard savePNG(grayMask, to: maskURL) else { throw InpaintError.writeFailed }

        let cmtDir = expand(config.cmtDirectory)
        let python = expand(config.python3Path)
        let ckpt   = expand(config.checkpointPath)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: python)
        task.currentDirectoryURL = URL(fileURLWithPath: cmtDir)
        task.arguments = [
            "demo.py",
            "--ckpt",         ckpt,
            "--img_path",     imgURL.path,
            "--mask_path",    maskURL.path,
            "--output_path",  outDir.path
        ]
        let errPipe = Pipe()
        task.standardError  = errPipe
        task.standardOutput = Pipe()

        try task.run()
        task.waitUntilExit()

        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard task.terminationStatus == 0 else {
            throw InpaintError.processExited(task.terminationStatus, String(stderr.suffix(500)))
        }

        let files = (try? fm.contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)) ?? []
        guard let resultURL = files.first else { throw InpaintError.resultNotFound }

        guard let src = CGImageSourceCreateWithURL(resultURL as CFURL, nil),
              let result = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { throw InpaintError.imageConversionFailed }

        return result
    }

    // MARK: - Helpers

    private static func expand(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    private static func savePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let dst = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(dst, image, nil)
        return CGImageDestinationFinalize(dst)
    }

    private static func toGrayscale(_ image: CGImage) -> CGImage? {
        let w = image.width, h = image.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
}
