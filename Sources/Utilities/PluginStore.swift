import Foundation
import AppKit
import SwiftUI

final class PluginStore: ObservableObject {
    static let shared = PluginStore()

    @Published private(set) var plugins: [Plugin] = []
    @Published var enabledIDs: Set<String> = []

    // Serial queue for all shell-command runs — prevents parallel process storms on fast navigation.
    let pluginQueue = DispatchQueue(label: "iphoto.plugins", qos: .utility)

    var pluginDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto/Plugins")
    }

    // Builtins decoded from embedded strings — no file I/O, available immediately.
    static let builtinPlugins: [Plugin] = builtins.compactMap {
        try? JSONDecoder().decode(Plugin.self, from: $0.json.data(using: .utf8)!)
    }.sorted { $0.order != $1.order ? $0.order < $1.order : $0.name < $1.name }

    init() {
        let t0 = Date()
        // Synchronous fast path: builtins decoded from strings, no file I/O.
        Self.applyMigrations()
        let builtins = Self.builtinPlugins
        var enabled = Set<String>()
        for p in builtins {
            let stored = UserDefaults.standard.object(forKey: p.resolvedStorageKey) as? Bool
            if stored ?? p.defaultEnabled { enabled.insert(p.id) }
        }
        plugins = builtins
        enabledIDs = enabled

        // Sync builtin JSONs to disk — skips unchanged files (typically a no-op after first install).
        let dir = pluginDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Self.writeBuiltinsIfNeeded(in: dir)

        // Background: load user plugins from disk, write example if absent.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Write example plugin if not present.
            self?.writeExampleIfNeeded(in: dir)

            // Load user (non-builtin) plugins.
            let userPlugins = Self.loadUserPluginsFromDisk(at: dir)
            let all = (builtins + userPlugins).sorted { $0.order != $1.order ? $0.order < $1.order : $0.name < $1.name }
            var allEnabled = enabled
            for p in userPlugins {
                let stored = UserDefaults.standard.object(forKey: p.resolvedStorageKey) as? Bool
                if stored ?? p.defaultEnabled { allEnabled.insert(p.id) }
            }
            Log.perf(String(format: "pluginstore-init %.0f ms (%d builtins + %d user)",
                           Date().timeIntervalSince(t0) * 1000, builtins.count, userPlugins.count))
            DispatchQueue.main.async { [weak self] in
                self?.plugins = all
                self?.enabledIDs = allEnabled
            }
        }
    }

    private static func applyMigrations() {
        // v1: force-enable storage plugin (was defaultEnabled:false before 1.102)
        if !UserDefaults.standard.bool(forKey: "migration.storage.enabled.v1") {
            UserDefaults.standard.set(true, forKey: "plugin.speicher")
            UserDefaults.standard.set(true, forKey: "migration.storage.enabled.v1")
        }
        // v1: remove navigation plugin (deprecated, superseded by sidebar)
        if !UserDefaults.standard.bool(forKey: "migration.navigation.disabled.v1") {
            UserDefaults.standard.set(false, forKey: "plugin.navigation")
            UserDefaults.standard.set(true,  forKey: "migration.navigation.disabled.v1")
        }
        // Always clean up navigation JSON (no longer a builtin)
        let pluginDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto/Plugins/builtin-navigation.json")
        try? FileManager.default.removeItem(at: pluginDir)
    }

    func reload() {
        let dir = pluginDirectory
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let (loaded, enabled) = Self.loadFromDisk(at: dir)
            DispatchQueue.main.async {
                self?.plugins = loaded
                self?.enabledIDs = enabled
            }
        }
    }

    // Loads only user (non-builtin) JSON plugins from disk. Logs warnings on decode failure.
    private static func loadUserPluginsFromDisk(at dir: URL) -> [Plugin] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ).filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix("builtin-") }) ?? []

        return urls.compactMap { url -> Plugin? in
            guard let data = try? Data(contentsOf: url) else {
                Log.warning("Plugin laden fehlgeschlagen: \(url.lastPathComponent)")
                return nil
            }
            do {
                return try JSONDecoder().decode(Plugin.self, from: data)
            } catch {
                Log.warning("Plugin JSON ungültig (\(url.lastPathComponent)): \(error.localizedDescription)")
                return nil
            }
        }.sorted { $0.order != $1.order ? $0.order < $1.order : $0.name < $1.name }
    }

    private static func loadFromDisk(at dir: URL) -> ([Plugin], Set<String>) {
        let userPlugins = loadUserPluginsFromDisk(at: dir)
        let all = (builtinPlugins + userPlugins).sorted { $0.order != $1.order ? $0.order < $1.order : $0.name < $1.name }
        var enabled = Set<String>()
        for plugin in all {
            let stored = UserDefaults.standard.object(forKey: plugin.resolvedStorageKey) as? Bool
            if stored ?? plugin.defaultEnabled { enabled.insert(plugin.id) }
        }
        return (all, enabled)
    }

    func revealPluginDirectory() {
        NSWorkspace.shared.open(pluginDirectory)
    }

    // MARK: - Enabled state

    func isEnabled(_ id: String) -> Bool { enabledIDs.contains(id) }

    func setEnabled(_ id: String, _ value: Bool) {
        if value { enabledIDs.insert(id) } else { enabledIDs.remove(id) }
        let key = plugins.first(where: { $0.id == id })?.resolvedStorageKey ?? "plugin.\(id)"
        UserDefaults.standard.set(value, forKey: key)
    }

    func enabledBinding(for id: String) -> Binding<Bool> {
        Binding(get: { self.isEnabled(id) }, set: { self.setEnabled(id, $0) })
    }

    // MARK: - Display order

    static func loadDisplayOrder(from plugins: [Plugin]) -> [Plugin] {
        let raw = UserDefaults.standard.string(forKey: "inspector.panelOrder") ?? ""
        let ids = raw.split(separator: ",").map(String.init)
        let byID = Dictionary(uniqueKeysWithValues: plugins.map { ($0.id, $0) })
        let saved = ids.compactMap { byID[$0] }
        return Set(saved.map(\.id)) == Set(plugins.map(\.id))
            ? saved
            : plugins  // already sorted by order from reload()
    }

    static func saveDisplayOrder(_ plugins: [Plugin]) {
        UserDefaults.standard.set(plugins.map(\.id).joined(separator: ","),
                                  forKey: "inspector.panelOrder")
    }

    // MARK: - Shell command runner

    // Blocking — must be called from a background thread.
    func run(command: String, imageURL: URL) -> String {
        let escaped = imageURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let resolved = command.replacingOccurrences(of: "{path}", with: "'\(escaped)'")

        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments  = ["-c", resolved]
        process.environment = ProcessInfo.processInfo.environment
            .merging(["IPHOTO_PATH": imageURL.path]) { _, new in new }

        let outPipe = Pipe()
        process.standardOutput = outPipe
        // Discard stderr into /dev/null — an unread Pipe deadlocks when stderr fills the 64 KB buffer.
        process.standardError  = FileHandle.nullDevice

        do { try process.run() } catch { return "" }

        // 5-second timeout: terminate the child if it hangs (e.g. network drive, bad command).
        let timeout = DispatchWorkItem { process.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: timeout)

        // Read stdout BEFORE waitUntilExit — draining the pipe prevents the child from blocking
        // on write() when output exceeds the ~64 KB kernel pipe buffer.
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()

        return (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    private func createDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(
            at: pluginDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    private static let builtins: [(filename: String, json: String)] = [
        ("builtin-compare.json", """
        {
          "id": "com.iphoto.builtin.compare",
          "name": "Bildvergleich",
          "icon": "arrow.left.arrow.right",
          "builtin": "compare",
          "order": 0,
          "defaultEnabled": true,
          "storageKey": "feature.compareEnabled"
        }
        """),
        ("builtin-toolbox.json", """
        {
          "id": "com.iphoto.builtin.toolbox",
          "name": "Werkzeuge",
          "icon": "hammer",
          "builtin": "toolbox",
          "order": 1,
          "defaultEnabled": false,
          "storageKey": "plugin.werkzeuge"
        }
        """),
        ("builtin-rating.json", """
        {
          "id": "com.iphoto.builtin.rating",
          "name": "Bewertung",
          "icon": "star.fill",
          "builtin": "rating",
          "order": 1,
          "defaultEnabled": true,
          "storageKey": "plugin.bewertung"
        }
        """),
        ("builtin-metadata.json", """
        {
          "id": "com.iphoto.builtin.metadata",
          "name": "Metadaten",
          "icon": "info.circle",
          "builtin": "metadata",
          "order": 2,
          "defaultEnabled": true,
          "storageKey": "plugin.metadata"
        }
        """),
        ("builtin-adjustments.json", """
        {
          "id": "com.iphoto.builtin.adjustments",
          "name": "Anpassungen",
          "icon": "slider.horizontal.3",
          "builtin": "adjustments",
          "order": 3,
          "defaultEnabled": false,
          "storageKey": "plugin.anpassungen"
        }
        """),
        ("builtin-local.json", """
        {
          "id": "com.iphoto.builtin.local",
          "name": "Lokal",
          "icon": "paintbrush",
          "builtin": "local",
          "order": 4,
          "defaultEnabled": false,
          "storageKey": "plugin.lokal"
        }
        """),
        ("builtin-presets.json", """
        {
          "id": "com.iphoto.builtin.presets",
          "name": "Rezepte",
          "icon": "wand.and.stars",
          "builtin": "presets",
          "order": 5,
          "defaultEnabled": false,
          "storageKey": "plugin.rezepte"
        }
        """),
        ("builtin-analyse.json", """
        {
          "id": "com.iphoto.builtin.analyse",
          "name": "Analyse",
          "icon": "chart.bar.xaxis",
          "builtin": "analyse",
          "order": 6,
          "defaultEnabled": false,
          "storageKey": "plugin.analyse"
        }
        """),
        ("builtin-hotpixel.json", """
        {
          "id": "com.iphoto.builtin.hotpixel",
          "name": "Hotpixel",
          "icon": "dot.radiowaves.right",
          "builtin": "hotpixel",
          "order": 8,
          "defaultEnabled": false,
          "storageKey": "plugin.hotpixel"
        }
        """),
        ("builtin-inpaint.json", """
        {
          "id": "com.iphoto.builtin.inpaint",
          "name": "Inpaint",
          "icon": "wand.and.rays",
          "builtin": "inpaint",
          "order": 9,
          "defaultEnabled": false,
          "storageKey": "plugin.inpaint"
        }
        """),
        ("builtin-similar.json", """
        {
          "id": "com.iphoto.builtin.similar",
          "name": "Ähnliche Bilder",
          "icon": "square.on.square.dashed",
          "builtin": "similar",
          "order": 10,
          "defaultEnabled": true,
          "storageKey": "plugin.similar"
        }
        """),
        ("builtin-people.json", """
        {
          "id": "com.iphoto.builtin.people",
          "name": "Menschen",
          "icon": "person.2",
          "builtin": "people",
          "order": 11,
          "defaultEnabled": true,
          "storageKey": "plugin.people"
        }
        """),
        ("builtin-storage.json", """
        {
          "id": "com.iphoto.builtin.storage",
          "name": "Speicher",
          "icon": "internaldrive",
          "builtin": "storage",
          "order": 12,
          "defaultEnabled": true,
          "storageKey": "plugin.speicher"
        }
        """),
    ]

    private static func writeBuiltinsIfNeeded(in dir: URL) {
        for (filename, json) in builtins {
            let url = dir.appendingPathComponent(filename)
            let data = json.data(using: .utf8)!
            // Skip write if file already has the same content.
            if let existing = try? Data(contentsOf: url), existing == data { continue }
            try? data.write(to: url, options: .atomic)
        }
    }

    private func writeExampleIfNeeded(in dir: URL) {
        let exampleURL = dir.appendingPathComponent("example-exif.json")
        guard !FileManager.default.fileExists(atPath: exampleURL.path) else { return }
        let example = """
        {
          "id": "com.iphoto.example-exif",
          "name": "EXIF Extended",
          "icon": "info.circle",
          "order": 50,
          "defaultEnabled": false,
          "rows": [
            { "label": "Objektiv",   "command": "exiftool -LensModel -s3 {path}" },
            { "label": "Blende",     "command": "exiftool -Aperture -s3 {path}" },
            { "label": "Verschluss", "command": "exiftool -ShutterSpeed -s3 {path}" },
            { "label": "ISO",        "command": "exiftool -ISO -s3 {path}" },
            { "label": "GPS",        "command": "exiftool -GPSPosition -s3 {path}" }
          ],
          "actions": [
            { "label": "In Finder zeigen", "icon": "folder", "command": "open -R {path}" },
            { "label": "In Preview öffnen", "icon": "eye",   "command": "open -a Preview {path}" }
          ]
        }
        """
        try? example.write(to: exampleURL, atomically: true, encoding: .utf8)
    }
}
