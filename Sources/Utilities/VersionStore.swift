import Foundation
import CoreGraphics
import ImageIO

struct ImageVersionMeta: Codable, Identifiable {
    let id: UUID
    let date: Date
    let ext: String
    var label: String?
}

final class VersionStore {
    static let shared = VersionStore()

    func versionDir(for url: URL) -> URL {
        // djb2 hash — stable across process runs (unlike Swift's hashValue which is randomized)
        var h: UInt64 = 5381
        for byte in url.path.utf8 { h = h &* 31 &+ UInt64(byte) }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto/versions/\(h)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private func indexURL(for url: URL) -> URL {
        versionDir(for: url).appendingPathComponent("index.json")
    }

    func loadVersions(for url: URL) -> [ImageVersionMeta] {
        guard let data = try? Data(contentsOf: indexURL(for: url)),
              let list = try? JSONDecoder().decode([ImageVersionMeta].self, from: data)
        else { return [] }
        return list.sorted { $0.date > $1.date }
    }

    @discardableResult
    func backupFile(at url: URL, label: String? = nil) throws -> ImageVersionMeta {
        let dir  = versionDir(for: url)
        let id   = UUID()
        let ext  = url.pathExtension
        let dest = dir.appendingPathComponent("\(id).\(ext)")
        try FileManager.default.copyItem(at: url, to: dest)

        let meta = ImageVersionMeta(id: id, date: Date(), ext: ext, label: label)
        var list = loadVersions(for: url)
        list.append(meta)
        try JSONEncoder().encode(list).write(to: indexURL(for: url), options: .atomic)
        return meta
    }

    func writeImage(_ image: CGImage, to url: URL) throws {
        let ext = url.pathExtension.lowercased()
        let utiStr: String
        switch ext {
        case "png":           utiStr = "public.png"
        case "tif", "tiff":   utiStr = "public.tiff"
        case "heic", "heif":  utiStr = "public.heic"
        case "webp":          utiStr = "org.webmproject.webp"
        default:              utiStr = "public.jpeg"
        }

        // Read existing properties before overwriting so EXIF/GPS/TIFF survive.
        // Orientation is reset to 1 because the CGImage is already correctly oriented.
        var opts: [CFString: Any] = utiStr == "public.jpeg"
            ? [kCGImageDestinationLossyCompressionQuality: 0.95] : [:]
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           var props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
            props[kCGImagePropertyOrientation] = 1 as CFNumber
            for (k, v) in opts { props[k] = v }
            opts = props
        }

        // Write to a temp file in the same directory, then atomically replace.
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).\(ext)")
        guard let dest = CGImageDestinationCreateWithURL(tmp as CFURL, utiStr as CFString, 1, nil) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        CGImageDestinationAddImage(dest, image, opts as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            try? FileManager.default.removeItem(at: tmp)
            throw CocoaError(.fileWriteUnknown)
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }

    func restoreVersion(_ meta: ImageVersionMeta, to url: URL) throws {
        let src = versionURL(meta, for: url)
        let data = try Data(contentsOf: src)
        try data.write(to: url, options: .atomic)
    }

    func versionURL(_ meta: ImageVersionMeta, for url: URL) -> URL {
        versionDir(for: url).appendingPathComponent("\(meta.id).\(meta.ext)")
    }

    func deleteVersion(_ meta: ImageVersionMeta, for url: URL) {
        try? FileManager.default.removeItem(at: versionURL(meta, for: url))
        var list = loadVersions(for: url).filter { $0.id != meta.id }
        try? JSONEncoder().encode(list).write(to: indexURL(for: url), options: .atomic)
    }

    func thumbnail(for meta: ImageVersionMeta, url: URL) -> CGImage? {
        try? RAWImageDecoder.thumbnail(url: versionURL(meta, for: url))
    }
}
