import Foundation

enum LogLevel: String {
    case trace   = "TRACE"
    case debug   = "DEBUG"
    case info    = "INFO "
    case warning = "WARN "
    case error   = "ERROR"
}

final class Log {
    // Internal so CrashReporter can call writeSync from the exception handler.
    static let shared = Log()

    // Set once during init() — lets CrashReporter.buildReport() identify the current session's
    // marker and pick the preceding (crashed) session instead.
    static private(set) var currentSessionID: String? = nil

    let fileURL: URL       // per-session log: iPhoto-yyyy-MM-dd_HHmmss.log
    let errorFileURL: URL  // persistent WARN/ERROR log across all sessions

    private let queue = DispatchQueue(label: "iphoto.logger", qos: .utility)
    private var fileHandle: FileHandle?
    private var errorFileHandle: FileHandle?
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private init() {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Per-session filename: iPhoto-2026-11-27_143201.log (timestamp → sortable)
        let nameFmt = DateFormatter()
        nameFmt.dateFormat = "yyyy-MM-dd_HHmmss"
        fileURL = dir.appendingPathComponent("iPhoto-\(nameFmt.string(from: Date())).log")

        // Separate error log: accumulates WARN + ERROR across sessions; rotate at 2 MB, one backup.
        errorFileURL = dir.appendingPathComponent("iPhoto-errors.log")
        let fm = FileManager.default
        if let size = try? errorFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > 2_000_000 {
            let backup = dir.appendingPathComponent("iPhoto-errors.log.1")
            try? fm.removeItem(at: backup)
            try? fm.moveItem(at: errorFileURL, to: backup)
        }

        // Auto-cleanup: keep only the 10 newest session log files; delete older ones.
        if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            let sessionFiles = contents
                .filter { $0.lastPathComponent.hasPrefix("iPhoto-")
                          && $0.pathExtension == "log"
                          && !$0.lastPathComponent.contains("errors") }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            if sessionFiles.count > 10 {
                for old in sessionFiles.dropLast(10) {
                    try? fm.removeItem(at: old)
                }
            }
        }

        // Write session boundary with a stable UUID so CrashReporter can always find the
        // previous (crashed) session regardless of whether Log was already initialized.
        let sessionID = UUID().uuidString
        Log.currentSessionID = sessionID
        appendRaw("\(Log.sessionMarker) \(sessionID)\n")

        // Open persistent handles for all subsequent writes — serialized through the queue.
        // Keeps the fd open for the app's lifetime; avoids per-call open/seek/close overhead.
        fileHandle = try? FileHandle(forWritingTo: fileURL)
        fileHandle?.seekToEndOfFile()

        if !fm.fileExists(atPath: errorFileURL.path) {
            fm.createFile(atPath: errorFileURL.path, contents: nil, attributes: nil)
        }
        errorFileHandle = try? FileHandle(forWritingTo: errorFileURL)
        errorFileHandle?.seekToEndOfFile()
    }

    // Unique marker that only appears as a standalone boundary, never inside a log entry.
    static let sessionMarker = "###SESSION_START###"

    // Writes the log line, blocking only when called from a non-Main thread (crash diagnostics).
    // On Main: uses async to avoid priority inversion and jitter in the navigation hot-path.
    func writeSync(level: LogLevel, _ msg: String, function: String = #function) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] [\(function)] \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        let isErr = level == .warning || level == .error
        if Thread.isMainThread {
            queue.async {
                self.fileHandle?.write(data)
                if isErr { self.errorFileHandle?.write(data) }
            }
        } else {
            queue.sync {
                self.fileHandle?.write(data)
                if isErr { self.errorFileHandle?.write(data) }
            }
        }
    }

    private func appendRaw(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile(); handle.write(data); handle.closeFile()
            }
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // Synchroner Write — wird sofort auf Disk geschrieben, bevor die nächste Operation startet.
    // Nur für crash-diagnostisch kritische Pfade verwenden (Decode-Pipeline, BG-Task-Starts).
    static func trace(_ msg: String, function: String = #function) {
        shared.writeSync(level: .trace, msg, function: function)
    }

    static func debug(_ msg: String, file: String = #file, function: String = #function) {
        shared.write(level: .debug, msg, file: file, function: function)
    }
    static func info(_ msg: String, file: String = #file, function: String = #function) {
        shared.write(level: .info, msg, file: file, function: function)
    }
    static func warning(_ msg: String, file: String = #file, function: String = #function) {
        shared.write(level: .warning, msg, file: file, function: function)
    }
    static func error(_ msg: String, file: String = #file, function: String = #function) {
        shared.write(level: .error, msg, file: file, function: function)
    }
    static func perf(_ msg: String, file: String = #file, function: String = #function) {
        shared.write(level: .info, "PERF \(msg)", file: file, function: function)
    }

    private func write(level: LogLevel, _ msg: String, file: String = #file, function: String = #function) {
        let timestamp = dateFormatter.string(from: Date())
        let filename = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let line = "[\(timestamp)] [\(level.rawValue)] [\(filename).\(function)] \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        let isErr = level == .warning || level == .error
        queue.async { [weak self] in
            self?.fileHandle?.write(data)
            if isErr { self?.errorFileHandle?.write(data) }
        }
    }
}
