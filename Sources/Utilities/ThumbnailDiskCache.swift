import Foundation
import ImageIO
import CoreImage
import AppKit

final class ThumbnailDiskCache {
    static let shared = ThumbnailDiskCache()

    private let cacheDir: URL
    // Eviction limit — if the cache exceeds this, oldest files are pruned on each save (#23).
    private static let maxCacheBytes: Int64 = 500 * 1024 * 1024

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
        // Write to a temp file, then atomically replace — no half-written JPEG on concurrent reads (#23).
        let tmpURL = cacheDir.appendingPathComponent(".\(key).\(ProcessInfo.processInfo.processIdentifier).tmp")
        guard let dest = CGImageDestinationCreateWithURL(
            tmpURL as CFURL, "public.jpeg" as CFString, 1, nil) else { return }
        let opts: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.75]
        CGImageDestinationAddImage(dest, image, opts as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            try? FileManager.default.removeItem(at: tmpURL)
            return
        }
        _ = try? FileManager.default.replaceItemAt(cacheURL, withItemAt: tmpURL)
        evictIfNeeded()
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

    private func evictIfNeeded() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        var totalBytes: Int64 = 0
        var items: [(url: URL, size: Int64, mtime: Date)] = []
        for u in entries where u.pathExtension == "jpg" {
            guard let r = try? u.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let sz = r.fileSize, let mt = r.contentModificationDate else { continue }
            let s = Int64(sz)
            totalBytes += s
            items.append((u, s, mt))
        }
        guard totalBytes > Self.maxCacheBytes else { return }

        // Evict oldest files first until we're under the limit.
        items.sort { $0.mtime < $1.mtime }
        for item in items {
            guard totalBytes > Self.maxCacheBytes else { break }
            try? fm.removeItem(at: item.url)
            totalBytes -= item.size
        }
    }
}
