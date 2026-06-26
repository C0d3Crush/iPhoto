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
        // Split on the dedicated session boundary (never appears inside a timestamped log entry).
        let sessions = log.components(separatedBy: Log.sessionMarker)

        // sessions[0]  = everything before first session (usually empty)
        // sessions[n-1] = current (non-crashed) session
        // sessions[n-2] = the crashed session
        let crashedSession: String
        if sessions.count >= 3 {
            crashedSession = Log.sessionMarker + sessions[sessions.count - 2]
        } else if sessions.count == 2 {
            crashedSession = Log.sessionMarker + sessions[0]  // only one full session
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

    // MARK: - Exception / Signal handlers

    static func installCrashHandlers() {
        NSSetUncaughtExceptionHandler(iphotoUncaughtExceptionHandler)
    }
}

// Must be a free function (not a closure) to be used as a C callback.
private func iphotoUncaughtExceptionHandler(_ exception: NSException) {
    let stack = exception.callStackSymbols.prefix(10).joined(separator: "\n  ")
    Log.shared.writeSync(level: .error,
        "UNCAUGHT EXCEPTION: \(exception.name.rawValue) — \(exception.reason ?? "–")\n  \(stack)")
    // Brief pause so the sync write can complete before the process dies.
    Thread.sleep(forTimeInterval: 0.3)
}
