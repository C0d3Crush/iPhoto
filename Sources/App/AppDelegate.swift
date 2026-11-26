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
        // Stale ratings.json (keyed by non-stable Swift hashValue) — remove once on upgrade.
        let ratingsURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto/ratings.json")
        try? FileManager.default.removeItem(at: ratingsURL)

        // View-Rendering-Smoketest: wenn per Umgebungsvariable aktiviert, wartet die
        // App 2 s (Zeit fuer Combine-Subscriptions, LazyStacks, Toolbar-Layout) und
        // beendet dann exit(0). Crashes waehrend Layout landen im CrashReporter und
        // liefern beim naechsten Start Nicht-0-Exit — der Test-Runner interpretiert
        // das als FAIL. Kein Ersatz fuer echte Snapshots, aber faengt regressionelle
        // Force-Unwraps und Threading-Verstoesse in Views.
        if ProcessInfo.processInfo.environment["IPHOTO_SMOKETEST"] == "1" {
            Log.info("SMOKETEST: aktiv, beende nach 2 s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                Log.info("SMOKETEST: OK, exit(0)")
                CrashReporter.markCleanExit()
                exit(0)
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
