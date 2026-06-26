import Foundation

enum LogLevel: String {
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
        // Rotate if over 2 MB
        if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 2_000_000 {
            try? FileManager.default.removeItem(at: fileURL)
        }
        // Write session boundary as a RAW line (not through write() so it never appears inside a
        // timestamped log entry — CrashReporter.buildReport() splits on this exact string).
        let boundary = "\n\(Log.sessionMarker) \(fileURL.path)\n"
        appendRaw(boundary)
    }

    // Unique marker that only appears as a standalone boundary, never inside a log entry.
    static let sessionMarker = "###SESSION_START###"

    // Synchronous write — safe to call from crash/signal handlers.
    func writeSync(level: LogLevel, _ msg: String, function: String = #function) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] [\(function)] \(msg)\n"
        appendRaw(line)
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

    private func write(level: LogLevel, _ msg: String, file: String = #file, function: String = #function) {
        let timestamp = dateFormatter.string(from: Date())
        let filename = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let line = "[\(timestamp)] [\(level.rawValue)] [\(filename).\(function)] \(msg)\n"
        queue.async {
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.fileURL.path) {
                    if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: self.fileURL, options: .atomic)
                }
            }
        }
    }
}
