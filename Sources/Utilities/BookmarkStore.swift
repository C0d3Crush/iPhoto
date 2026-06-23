import Foundation

final class BookmarkStore {
    static let shared = BookmarkStore()

    private var bookmarks: [String: Data] = [:]
    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("bookmarks.json")
        load()
    }

    // Call after NSOpenPanel grants access to a URL
    func save(url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        bookmarks[url.absoluteString] = data
        persist()
    }

    // Resolves bookmark and starts security-scoped access.
    // Returns the URL to use and a stop closure — caller MUST call stop() when done.
    func access(url: URL) -> (url: URL, stop: () -> Void) {
        if let data = bookmarks[url.absoluteString] {
            var stale = false
            if let resolved = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                let didStart = resolved.startAccessingSecurityScopedResource()
                if stale { save(url: resolved) }
                return (resolved, { if didStart { resolved.stopAccessingSecurityScopedResource() } })
            }
        }
        // No bookmark — try direct access (works within same session)
        let didStart = url.startAccessingSecurityScopedResource()
        return (url, { if didStart { url.stopAccessingSecurityScopedResource() } })
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Data].self, from: data) else { return }
        bookmarks = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
