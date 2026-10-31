import Foundation
import AppKit

final class PluginStore: ObservableObject {
    static let shared = PluginStore()

    @Published private(set) var plugins: [Plugin] = []

    var pluginDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto/Plugins")
    }

    init() {
        createDirectoryIfNeeded()
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
        }.sorted { $0.name < $1.name }

        DispatchQueue.main.async { self.plugins = loaded }
    }

    func revealPluginDirectory() {
        NSWorkspace.shared.open(pluginDirectory)
    }

    // Runs a plugin shell command, substituting {path} and exposing IPHOTO_PATH env var.
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

    private func writeExampleIfNeeded() {
        let exampleURL = pluginDirectory.appendingPathComponent("example-exif.json")
        guard !FileManager.default.fileExists(atPath: exampleURL.path) else { return }
        let example = """
        {
          "id": "com.iphoto.example-exif",
          "name": "EXIF Extended",
          "icon": "info.circle",
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
