import Foundation
import ImageIO
import CoreImage
import AppKit

final class ThumbnailDiskCache {
    static let shared = ThumbnailDiskCache()

    private let cacheDir: URL

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = base.appendingPathComponent("iPhoto/thumbs")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func load(for url: URL, maxDimension: Int) -> CGImage? {
        guard let key = cacheKey(for: url, maxDimension: maxDimension) else { return nil }
        let cacheURL = cacheDir.appendingPathComponent("\(key).jpg")
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        guard let src = CGImageSourceCreateWithURL(cacheURL as CFURL, nil) else { return nil }
        // kCGImageSourceShouldCacheImmediately forces JPEG decode here on the BG thread
        // rather than lazily on the first draw pass on the main thread (#22).
        let opts = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(src, 0, opts)
    }

    func save(_ image: CGImage, for url: URL, maxDimension: Int) {
        guard let key = cacheKey(for: url, maxDimension: maxDimension) else { return }
        let cacheURL = cacheDir.appendingPathComponent("\(key).jpg")
        guard let dest = CGImageDestinationCreateWithURL(
            cacheURL as CFURL, "public.jpeg" as CFString, 1, nil) else { return }
        let opts: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.75]
        CGImageDestinationAddImage(dest, image, opts as CFDictionary)
        CGImageDestinationFinalize(dest)
    }

    var stats: (count: Int, bytes: Int64) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else { return (0, 0) }
        var total: Int64 = 0
        for u in urls {
            if let r = try? u.resourceValues(forKeys: [.fileSizeKey]), let sz = r.fileSize {
                total += Int64(sz)
            }
        }
        return (urls.count, total)
    }

    func clearAll() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    private func cacheKey(for url: URL, maxDimension: Int) -> String? {
        guard let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mtime = attr[.modificationDate] as? Date else { return nil }
        let raw = "\(url.path)|\(mtime.timeIntervalSince1970)|\(maxDimension)"
        return String(fnv1a(raw), radix: 16)
    }

    private func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 14695981039346656037
        for b in s.utf8 { h ^= UInt64(b); h = h &* 1099511628211 }
        return h
    }
}
