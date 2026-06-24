import Foundation

struct WatchedFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var bookmarkData: Data

    init(url: URL) throws {
        self.id = UUID()
        self.name = url.lastPathComponent
        self.bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves the security-scoped URL. Caller must invoke the returned stop closure when done.
    func resolveURL() -> (url: URL, stop: () -> Void)? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        let didStart = url.startAccessingSecurityScopedResource()
        return (url, { if didStart { url.stopAccessingSecurityScopedResource() } })
    }
}
