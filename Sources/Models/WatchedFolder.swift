import Foundation

struct WatchedFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var bookmarkData: Data
    var autoSync: Bool = false
    var importDestinationPath: String? = nil
    var isDefaultLibrary: Bool = false

    var importDestinationURL: URL? {
        guard let p = importDestinationPath else { return nil }
        return URL(fileURLWithPath: p)
    }

    init(url: URL) throws {
        self.id = UUID()
        self.name = url.lastPathComponent
        // .withSecurityScope requires a sandboxed app; fall back to minimal bookmark in CLI/non-sandboxed context
        if let d = try? url.bookmarkData(options: .withSecurityScope,
                                          includingResourceValuesForKeys: nil, relativeTo: nil) {
            self.bookmarkData = d
        } else {
            self.bookmarkData = try url.bookmarkData(options: .minimalBookmark,
                                                      includingResourceValuesForKeys: nil, relativeTo: nil)
        }
    }

    /// Resolves the security-scoped URL. Caller must invoke the returned stop closure when done.
    func resolveURL() -> (url: URL, stop: () -> Void)? {
        var isStale = false
        // Try security-scoped first; fall back to plain resolution (minimal bookmarks)
        let resolved: URL?
        if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope,
                               relativeTo: nil, bookmarkDataIsStale: &isStale) {
            resolved = url
        } else {
            resolved = try? URL(resolvingBookmarkData: bookmarkData, options: [],
                                relativeTo: nil, bookmarkDataIsStale: &isStale)
        }
        guard let url = resolved else { return nil }
        let didStart = url.startAccessingSecurityScopedResource()
        return (url, { if didStart { url.stopAccessingSecurityScopedResource() } })
    }

    /// True when the folder's volume is currently mounted and accessible.
    var isAvailable: Bool {
        guard let resolved = resolveURL() else { return false }
        defer { resolved.stop() }
        return FileManager.default.fileExists(atPath: resolved.url.path)
    }

    /// True when the folder lives on a removable volume (SD card, USB drive, etc.).
    var isRemovableMedia: Bool {
        guard let resolved = resolveURL() else {
            // Bookmark resolves to /Volumes/... even when unmounted — check path prefix
            return bookmarkPath?.hasPrefix("/Volumes/") ?? false
        }
        defer { resolved.stop() }
        let vals = try? resolved.url.resourceValues(forKeys: [.volumeIsRemovableKey])
        return vals?.volumeIsRemovable ?? false
    }

    /// Best-effort path extracted from bookmark without starting security scope.
    var bookmarkPath: String? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return url.path
    }
}
