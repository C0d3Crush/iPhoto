import Foundation

struct RatingEntry: Codable {
    var rating: Int
    var flagStatus: FlagStatus
    var colorLabel: ColorLabel
    var elo: Double
    var eloMatches: Int

    init(rating: Int, flagStatus: FlagStatus, colorLabel: ColorLabel,
         elo: Double = 1500, eloMatches: Int = 0) {
        self.rating = rating
        self.flagStatus = flagStatus
        self.colorLabel = colorLabel
        self.elo = elo
        self.eloMatches = eloMatches
    }

    // Tolerantes Decoding — alte Einträge ohne elo/eloMatches bekommen die Defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rating = try c.decode(Int.self, forKey: .rating)
        self.flagStatus = try c.decode(FlagStatus.self, forKey: .flagStatus)
        self.colorLabel = try c.decode(ColorLabel.self, forKey: .colorLabel)
        self.elo = (try? c.decode(Double.self, forKey: .elo)) ?? 1500
        self.eloMatches = (try? c.decode(Int.self, forKey: .eloMatches)) ?? 0
    }
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
