import Foundation

enum CrashReporter {

    private static var sentinelURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("running.lock")
    }

    private static var logURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/iPhoto/iPhoto.log")
    }

    // Called on launch — returns crash report string if previous session crashed
    static func checkAndMark() -> String? {
        let crashed = FileManager.default.fileExists(atPath: sentinelURL.path)
        let report = crashed ? buildReport() : nil
        let timestamp = ISO8601DateFormatter().string(from: Date())
        try? timestamp.write(to: sentinelURL, atomically: true, encoding: .utf8)
        return report
    }

    // Called on clean quit
    static func markCleanExit() {
        try? FileManager.default.removeItem(at: sentinelURL)
    }

    private static func buildReport() -> String {
        let log = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        let sessionMarker = "=== iPhoto gestartet ==="
        let sessions = log.components(separatedBy: sessionMarker)

        // Take the second-to-last session (the crashed one)
        let crashedSession: String
        if sessions.count >= 2 {
            crashedSession = sessionMarker + sessions[sessions.count - 2]
        } else {
            crashedSession = log
        }

        let header = """
        iPhoto Crash Report
        Datum: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .medium))
        Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)

        === Log der abgestürzten Session ===

        """
        return header + crashedSession.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
