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

    let fileURL: URL
    private let queue = DispatchQueue(label: "iphoto.logger", qos: .utility)
    private var fileHandle: FileHandle?
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private init() {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("iPhoto.log")
        // Rotate if over 10 MB
        if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 10_000_000 {
            try? FileManager.default.removeItem(at: fileURL)
        }
        // Write session boundary as a RAW line (not through write() so it never appears inside a
        // timestamped log entry — CrashReporter.buildReport() splits on this exact string).
        let boundary = "\n\(Log.sessionMarker) \(fileURL.path)\n"
        appendRaw(boundary)
        // Open a persistent handle for all subsequent writes — serialized through the queue.
        // Keeps the fd open for the app's lifetime; avoids per-call open/seek/close overhead
        // and eliminates the race when multiple threads write concurrently.
        fileHandle = try? FileHandle(forWritingTo: fileURL)
        fileHandle?.seekToEndOfFile()
    }

    // Unique marker that only appears as a standalone boundary, never inside a log entry.
    static let sessionMarker = "###SESSION_START###"

    // Writes the log line, blocking only when called from a non-Main thread (crash diagnostics).
    // On Main: uses async to avoid priority inversion and jitter in the navigation hot-path.
    func writeSync(level: LogLevel, _ msg: String, function: String = #function) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] [\(function)] \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        if Thread.isMainThread {
            queue.async { self.fileHandle?.write(data) }
        } else {
            queue.sync { self.fileHandle?.write(data) }
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
        queue.async { [weak self] in self?.fileHandle?.write(data) }
    }
}
