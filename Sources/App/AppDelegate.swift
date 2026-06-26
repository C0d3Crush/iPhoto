import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: ImageViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CrashReporter.installCrashHandlers()
        if let report = CrashReporter.checkAndMark() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.viewModel?.pendingCrashReport = report
            }
        }
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
