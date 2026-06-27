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

    // Saves a crash report to ~/Documents/bugreports/ and returns the saved URL.
    @discardableResult
    static func saveReport(_ report: String) -> URL? {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/bugreports")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "iPhoto_Crash_\(formatter.string(from: Date())).txt"
        let url = dir.appendingPathComponent(filename)
        try? report.write(to: url, atomically: true, encoding: .utf8)
        return url
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
        installSignalHandlers()
    }

    private static func installSignalHandlers() {
        // Store the log file path in a C-accessible global buffer so the signal
        // handler (which must be async-signal-safe) can open the file with open(2).
        _ = Log.shared.fileURL.path.withCString { src in
            strlcpy(&iphotoLogPathBuf, src, iphotoLogPathBuf.count)
        }
        for sig in [SIGSEGV, SIGABRT, SIGBUS, SIGILL] {
            signal(sig, iphotoSignalHandler)
        }
    }
}

// MARK: - C callbacks (free functions, no captures)

// 4096 bytes is always enough for a filesystem path on macOS (PATH_MAX = 1024).
var iphotoLogPathBuf = [CChar](repeating: 0, count: 4096)

// Pre-allocated signal message buffers — filled at startup, never modified.
// Using pre-allocated buffers avoids any malloc call inside the signal handler,
// which is not async-signal-safe and caused a second SIGSEGV inside the handler.
var iphotoMsgSIGSEGV = Array("[SIGNAL] SIGSEGV (Segmentation Fault)\n".utf8CString)
var iphotoMsgSIGABRT = Array("[SIGNAL] SIGABRT (Abort)\n".utf8CString)
var iphotoMsgSIGBUS  = Array("[SIGNAL] SIGBUS (Bus Error)\n".utf8CString)
var iphotoMsgSIGILL  = Array("[SIGNAL] SIGILL (Illegal Instruction)\n".utf8CString)
var iphotoMsgUnknown = Array("[SIGNAL] SIGNAL (unknown)\n".utf8CString)

// Must be a free function (not a closure) to be used as a C callback.
private func iphotoUncaughtExceptionHandler(_ exception: NSException) {
    let stack = exception.callStackSymbols.prefix(10).joined(separator: "\n  ")
    Log.shared.writeSync(level: .error,
        "UNCAUGHT EXCEPTION: \(exception.name.rawValue) — \(exception.reason ?? "–")\n  \(stack)")
    Thread.sleep(forTimeInterval: 0.3)
}

// Async-signal-safe: only syscalls (open/write/close) + reads from pre-allocated global buffers.
private func iphotoSignalHandler(_ sig: Int32) {
    let fd = open(&iphotoLogPathBuf, O_WRONLY | O_CREAT | O_APPEND, 0o644)
    if fd >= 0 {
        switch sig {
        case SIGSEGV: iphotoMsgSIGSEGV.withUnsafeBufferPointer { _ = write(fd, $0.baseAddress, $0.count - 1) }
        case SIGABRT: iphotoMsgSIGABRT.withUnsafeBufferPointer { _ = write(fd, $0.baseAddress, $0.count - 1) }
        case SIGBUS:  iphotoMsgSIGBUS.withUnsafeBufferPointer  { _ = write(fd, $0.baseAddress, $0.count - 1) }
        case SIGILL:  iphotoMsgSIGILL.withUnsafeBufferPointer  { _ = write(fd, $0.baseAddress, $0.count - 1) }
        default:      iphotoMsgUnknown.withUnsafeBufferPointer { _ = write(fd, $0.baseAddress, $0.count - 1) }
        }
        Darwin.close(fd)
    }
    // Reset to default handler and re-raise so the OS records a proper crash report.
    signal(sig, SIG_DFL)
    raise(sig)
}
