import Foundation
import CoreGraphics
import ImageIO

struct ImageVersionMeta: Codable, Identifiable {
    let id: UUID
    let date: Date
    let ext: String
}

final class VersionStore {
    static let shared = VersionStore()

    func versionDir(for url: URL) -> URL {
        let hash = abs(url.path.hashValue)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto/versions/\(hash)")
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
    func backupFile(at url: URL) throws -> ImageVersionMeta {
        let dir  = versionDir(for: url)
        let id   = UUID()
        let ext  = url.pathExtension
        let dest = dir.appendingPathComponent("\(id).\(ext)")
        try FileManager.default.copyItem(at: url, to: dest)

        let meta = ImageVersionMeta(id: id, date: Date(), ext: ext)
        var list = loadVersions(for: url)
        list.append(meta)
        try JSONEncoder().encode(list).write(to: indexURL(for: url), options: .atomic)
        return meta
    }

    func writeImage(_ image: CGImage, to url: URL) throws {
        let ext = url.pathExtension.lowercased()
        let utiStr: String = ext == "png"                    ? "public.png"  :
                             (ext == "tif" || ext == "tiff") ? "public.tiff" :
                                                               "public.jpeg"
        let uti = utiStr as CFString
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, uti, 1, nil) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        let opts: [CFString: Any] = utiStr == "public.jpeg"
            ? [kCGImageDestinationLossyCompressionQuality: 0.95] : [:]
        CGImageDestinationAddImage(dest, image, opts as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
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
