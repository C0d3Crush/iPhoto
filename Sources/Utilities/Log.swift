import Foundation

enum LogLevel: String {
    case debug   = "DEBUG"
    case info    = "INFO "
    case warning = "WARN "
    case error   = "ERROR"
}

final class Log {
    static let shared = Log()

    private let fileURL: URL
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
        write(level: .info, "=== iPhoto gestartet === log: \(fileURL.path)")
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
