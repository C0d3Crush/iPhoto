import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Read the crash log BEFORE installCrashHandlers() — because installCrashHandlers()
        // accesses Log.shared which triggers Log.init() which may rotate (delete) the log
        // file if it exceeds 2 MB, destroying the crashed session's data.
        if let report = CrashReporter.checkAndMark() {
            CrashReporter.saveReport(report)
        }
        CrashReporter.installCrashHandlers()
        Heartbeat.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        CrashReporter.markCleanExit()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        NotificationCenter.default.post(name: .openURLs, object: urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
