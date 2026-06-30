import Foundation

struct RatingEntry: Codable {
    var rating: Int
    var flagStatus: FlagStatus
    var colorLabel: ColorLabel
}

final class RatingStore {
    static let shared = RatingStore()
    private let lock = NSLock()
    private var cache: [String: RatingEntry] = [:]
    private var loaded = false
    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ratings.json")
    }
    private func key(for url: URL) -> String { String(abs(url.path.hashValue)) }
    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: RatingEntry].self, from: data)
        else { return }
        cache = dict
    }
    private func persist() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
    func load(for url: URL) -> RatingEntry? {
        lock.lock(); defer { lock.unlock() }
        ensureLoaded(); return cache[key(for: url)]
    }
    func save(_ entry: RatingEntry, for url: URL) {
        lock.lock(); defer { lock.unlock() }
        ensureLoaded(); cache[key(for: url)] = entry; persist()
    }
}
