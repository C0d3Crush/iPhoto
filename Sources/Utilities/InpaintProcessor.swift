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

        // demo.py matches image and mask by filename — both must share the same name.
        let imgDir  = tmp.appendingPathComponent("img")
        let maskDir = tmp.appendingPathComponent("mask")
        let outDir  = tmp.appendingPathComponent("out")
        try fm.createDirectory(at: imgDir,  withIntermediateDirectories: true)
        try fm.createDirectory(at: maskDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: outDir,  withIntermediateDirectories: true)

        guard savePNG(image, to: imgDir.appendingPathComponent("inpaint.png")) else { throw InpaintError.writeFailed }

        let grayMask = toGrayscale(mask) ?? mask
        guard savePNG(grayMask, to: maskDir.appendingPathComponent("inpaint.png")) else { throw InpaintError.writeFailed }

        let cmtDir = expand(config.cmtDirectory)
        let python = expand(config.python3Path)
        let ckpt   = expand(config.checkpointPath)

        let wrapperScript = (cmtDir as NSString).appendingPathComponent("run_inpaint.sh")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: wrapperScript)
        task.currentDirectoryURL = URL(fileURLWithPath: cmtDir)
        task.arguments = [
            "--ckpt",        ckpt,
            "--img_path",    imgDir.path,
            "--mask_path",   maskDir.path,
            "--output_path", outDir.path
        ]

        let errPipe = Pipe()
        let outPipe = Pipe()
        task.standardError  = errPipe
        task.standardOutput = outPipe

        try task.run()
        // Drain pipes BEFORE waitUntilExit to prevent deadlock when output exceeds 64 KB.
        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let timeout = DispatchWorkItem { task.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 300, execute: timeout)
        task.waitUntilExit()
        timeout.cancel()
        guard task.terminationStatus == 0 else {
            let combined = (stdout + "\n" + stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            throw InpaintError.processExited(task.terminationStatus, combined)
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

    // Converts the brush-stroke mask (red on transparent) to a binary grayscale mask:
    // any pixel with alpha > 0 → white (255), transparent → black (0).
    private static func toGrayscale(_ image: CGImage) -> CGImage? {
        let w = image.width, h = image.height
        let bytesPerRow = w * 4
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let ptr = ctx.data else { return nil }
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Build binary grayscale from alpha channel
        let rgba = ptr.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var gray = [UInt8](repeating: 0, count: w * h)
        for i in 0 ..< w * h {
            gray[i] = rgba[i * 4 + 3] > 0 ? 255 : 0
        }
        return gray.withUnsafeMutableBytes { buf in
            guard let grayCtx = CGContext(data: buf.baseAddress, width: w, height: h,
                                          bitsPerComponent: 8, bytesPerRow: w,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return nil }
            return grayCtx.makeImage()
        }
    }
}
