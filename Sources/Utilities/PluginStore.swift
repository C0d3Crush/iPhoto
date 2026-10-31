import Foundation
import AppKit
import SwiftUI

final class PluginStore: ObservableObject {
    static let shared = PluginStore()

    @Published private(set) var plugins: [Plugin] = []
    @Published var enabledIDs: Set<String> = []

    var pluginDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto/Plugins")
    }

    init() {
        createDirectoryIfNeeded()
        writeBuiltins()
        writeExampleIfNeeded()
        reload()
    }

    func reload() {
        let dir = pluginDirectory
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ).filter { $0.pathExtension == "json" }) ?? []

        let loaded = urls.compactMap { url -> Plugin? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Plugin.self, from: data)
        }.sorted { $0.order != $1.order ? $0.order < $1.order : $0.name < $1.name }

        var enabled = Set<String>()
        for plugin in loaded {
            let stored = UserDefaults.standard.object(forKey: plugin.resolvedStorageKey) as? Bool
            if stored ?? plugin.defaultEnabled { enabled.insert(plugin.id) }
        }

        DispatchQueue.main.async {
            self.plugins = loaded
            self.enabledIDs = enabled
        }
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
        process.standardError  = Pipe()

        do { try process.run() } catch { return "" }
        process.waitUntilExit()

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    private func createDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(
            at: pluginDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    private static let builtins: [(filename: String, json: String)] = [
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
        ("builtin-navigation.json", """
        {
          "id": "com.iphoto.builtin.navigation",
          "name": "Navigation",
          "icon": "map",
          "builtin": "navigation",
          "order": 7,
          "defaultEnabled": false,
          "storageKey": "plugin.navigation"
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
    ]

    private func writeBuiltins() {
        for (filename, json) in PluginStore.builtins {
            let url = pluginDirectory.appendingPathComponent(filename)
            try? json.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func writeExampleIfNeeded() {
        let exampleURL = pluginDirectory.appendingPathComponent("example-exif.json")
        guard !FileManager.default.fileExists(atPath: exampleURL.path) else { return }
        let example = """
        {
          "id": "com.iphoto.example-exif",
          "name": "EXIF Extended",
          "icon": "info.circle",
          "order": 50,
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
