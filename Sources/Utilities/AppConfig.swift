import Foundation

struct AppConfig {

    static let appBundleID = "com.c0d3cru5h.iPhoto12"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appBundleID) ?? UserDefaults.standard
    }

    static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("iPhoto", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil)
        return dir.appendingPathComponent("settings.json")
    }

    static let knownKeys: [String] = [
        // Badge-Sichtbarkeit
        "badge.rating", "badge.colorLabel", "badge.flag",
        "badge.blurry", "badge.under", "badge.over", "badge.eyes",
        "badge.bestInStack", "badge.adjustments", "badge.hdr",
        // Toolbar-Sichtbarkeit
        "navtoolbar.showSidebar", "navtoolbar.showViewMode", "navtoolbar.showNavigation",
        "navtoolbar.showInspector", "navtoolbar.showSort", "navtoolbar.showSlider",
        "navtoolbar.showShare", "navtoolbar.showTag", "navtoolbar.showMore",
        "navtoolbar.showSearch",
        // Entwickler
        "settings.geekMode",
    ]

    static func currentSettings() -> [String: Any] {
        var dict: [String: Any] = [:]
        for key in knownKeys {
            if let v = defaults.object(forKey: key) {
                dict[key] = v
            }
        }
        return dict
    }

    @discardableResult
    static func exportToFile(_ url: URL? = nil) throws -> URL {
        let target = url ?? fileURL
        let data = try JSONSerialization.data(
            withJSONObject: currentSettings(),
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: target, options: .atomic)
        return target
    }

    static func importFromFile(_ url: URL? = nil) throws {
        let source = url ?? fileURL
        let data = try Data(contentsOf: source)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "AppConfig", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Ungültiges JSON-Format"])
        }
        let valid = Set(knownKeys)
        for (key, value) in dict where valid.contains(key) {
            defaults.set(value, forKey: key)
        }
        defaults.synchronize()
    }
}
