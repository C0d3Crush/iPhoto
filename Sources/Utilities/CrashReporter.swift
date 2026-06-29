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
        iphotoSignalHandlerFired = 0
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
var iphotoMsgSIGSEGV    = Array("[SIGNAL] SIGSEGV (Segmentation Fault)\n".utf8CString)
var iphotoMsgSIGABRT    = Array("[SIGNAL] SIGABRT (Abort)\n".utf8CString)
var iphotoMsgSIGBUS     = Array("[SIGNAL] SIGBUS (Bus Error)\n".utf8CString)
var iphotoMsgSIGILL     = Array("[SIGNAL] SIGILL (Illegal Instruction)\n".utf8CString)
var iphotoMsgUnknown    = Array("[SIGNAL] SIGNAL (unknown)\n".utf8CString)
var iphotoMsgMainThread = Array("[SIGNAL_THREAD] main\n".utf8CString)
var iphotoMsgBGThread   = Array("[SIGNAL_THREAD] background\n".utf8CString)
var iphotoMsgLastOpPfx  = Array("[SIGNAL_LAST_OP] ".utf8CString)

// Guards against two threads entering the signal handler simultaneously.
// OSAtomicCompareAndSwap32 is async-signal-safe (single atomic CAS instruction).
var iphotoSignalHandlerFired: Int32 = 0

// Pre-allocated buffer for assembling all signal output — written via strlcpy/strlcat,
// then flushed in a single write() call (atomic under O_APPEND).
var iphotoSignalOutputBuf = [CChar](repeating: 0, count: 1024)

// Must be a free function (not a closure) to be used as a C callback.
private func iphotoUncaughtExceptionHandler(_ exception: NSException) {
    let stack = exception.callStackSymbols.prefix(10).joined(separator: "\n  ")
    Log.shared.writeSync(level: .error,
        "UNCAUGHT EXCEPTION: \(exception.name.rawValue) — \(exception.reason ?? "–")\n  \(stack)")
    Thread.sleep(forTimeInterval: 0.3)
}

// Async-signal-safe: only syscalls + reads/writes to pre-allocated global buffers.
// OSAtomicCompareAndSwap32, strlcpy/strlcat/strlen, pthread_main_np, open/write/close — all safe.
private func iphotoSignalHandler(_ sig: Int32) {
    // Only the first thread to arrive writes diagnostics — prevents duplicate [SIGNAL_THREAD] lines
    // when a process-wide signal (e.g. SIGABRT from abort()) reaches multiple threads at once.
    guard OSAtomicCompareAndSwap32(0, 1, &iphotoSignalHandlerFired) else {
        signal(sig, SIG_DFL)
        raise(sig)
        return
    }

    let fd = open(&iphotoLogPathBuf, O_WRONLY | O_CREAT | O_APPEND, 0o644)
    if fd >= 0 {
        // Assemble entire output into iphotoSignalOutputBuf, then flush with a single write().
        // O_APPEND + single write() is atomic at the kernel level — no logger write from a live
        // background thread can land between our SIGNAL_THREAD, SIGNAL_LAST_OP, and SIGNAL lines.
        if pthread_main_np() != 0 {
            iphotoMsgMainThread.withUnsafeBufferPointer { strlcpy(&iphotoSignalOutputBuf, $0.baseAddress, iphotoSignalOutputBuf.count) }
        } else {
            iphotoMsgBGThread.withUnsafeBufferPointer { strlcpy(&iphotoSignalOutputBuf, $0.baseAddress, iphotoSignalOutputBuf.count) }
        }
        let opLen = strlen(&iphotoLastOpBuf)
        if opLen > 0 {
            iphotoMsgLastOpPfx.withUnsafeBufferPointer { strlcat(&iphotoSignalOutputBuf, $0.baseAddress, iphotoSignalOutputBuf.count) }
            strlcat(&iphotoSignalOutputBuf, &iphotoLastOpBuf, iphotoSignalOutputBuf.count)
            strlcat(&iphotoSignalOutputBuf, "\n", iphotoSignalOutputBuf.count)
        }
        switch sig {
        case SIGSEGV: iphotoMsgSIGSEGV.withUnsafeBufferPointer { strlcat(&iphotoSignalOutputBuf, $0.baseAddress, iphotoSignalOutputBuf.count) }
        case SIGABRT: iphotoMsgSIGABRT.withUnsafeBufferPointer { strlcat(&iphotoSignalOutputBuf, $0.baseAddress, iphotoSignalOutputBuf.count) }
        case SIGBUS:  iphotoMsgSIGBUS.withUnsafeBufferPointer  { strlcat(&iphotoSignalOutputBuf, $0.baseAddress, iphotoSignalOutputBuf.count) }
        case SIGILL:  iphotoMsgSIGILL.withUnsafeBufferPointer  { strlcat(&iphotoSignalOutputBuf, $0.baseAddress, iphotoSignalOutputBuf.count) }
        default:      iphotoMsgUnknown.withUnsafeBufferPointer { strlcat(&iphotoSignalOutputBuf, $0.baseAddress, iphotoSignalOutputBuf.count) }
        }
        _ = write(fd, &iphotoSignalOutputBuf, strlen(&iphotoSignalOutputBuf))
        Darwin.close(fd)
    }
    // Reset to default handler and re-raise so the OS records a proper crash report.
    signal(sig, SIG_DFL)
    raise(sig)
}
