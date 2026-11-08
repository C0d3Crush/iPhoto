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

    // Serial queue serializes all index.json mutations — prevents race between
    // concurrent backupFile / deleteVersion / CLI calls that could corrupt the index (#64).
    private let queue = DispatchQueue(label: "com.c0d3cru5h.iphoto.versions", qos: .utility)

    private static let maxVersionsPerFile = 20

    private func pathHash(_ url: URL) -> UInt64 {
        // djb2 hash — stable across process runs (unlike Swift's hashValue)
        var h: UInt64 = 5381
        for byte in url.path.utf8 { h = h &* 31 &+ UInt64(byte) }
        return h
    }

    func versionDir(for url: URL) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto/versions/\(pathHash(url))")
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
        // Only create the directory here (not on every read path) to avoid per-image empty dirs (#64).
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let id   = UUID()
        let ext  = url.pathExtension
        let dest = dir.appendingPathComponent("\(id).\(ext)")
        try FileManager.default.copyItem(at: url, to: dest)

        let meta = ImageVersionMeta(id: id, date: Date(), ext: ext, label: label)
        try queue.sync {
            var list = loadVersions(for: url)
            list.append(meta)
            // Retention: keep at most maxVersionsPerFile, pruning oldest first (#64).
            if list.count > Self.maxVersionsPerFile {
                let excess = list.sorted { $0.date < $1.date }
                    .prefix(list.count - Self.maxVersionsPerFile)
                for old in excess {
                    try? FileManager.default.removeItem(at: versionURL(old, for: url))
                }
                list = list.filter { m in !excess.contains { $0.id == m.id } }
            }
            try JSONEncoder().encode(list).write(to: indexURL(for: url), options: .atomic)
        }
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
        // Run deletion on BG queue to keep main thread free (#64).
        queue.async {
            try? FileManager.default.removeItem(at: self.versionURL(meta, for: url))
            let idx = self.indexURL(for: url)
            guard let data = try? Data(contentsOf: idx),
                  var list = try? JSONDecoder().decode([ImageVersionMeta].self, from: data)
            else { return }
            list.removeAll { $0.id == meta.id }
            try? JSONEncoder().encode(list).write(to: idx, options: .atomic)
        }
    }

    func thumbnail(for meta: ImageVersionMeta, url: URL) -> CGImage? {
        try? RAWImageDecoder.thumbnail(url: versionURL(meta, for: url))
    }
}
