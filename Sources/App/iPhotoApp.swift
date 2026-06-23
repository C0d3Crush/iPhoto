import SwiftUI

@main
struct iPhotoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ImageViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 600, minHeight: 400)
                .onAppear {
                    appDelegate.viewModel = viewModel
                }
        }
        .commands {
            PluginCommands()
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Importieren…") {
                    NotificationCenter.default.post(name: .importRequested, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Exportieren…") {
                    NotificationCenter.default.post(name: .exportRequested, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Divider()

                Button("Alle entfernen") {
                    NotificationCenter.default.post(name: .clearCollection, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let importRequested = Notification.Name("importRequested")
    static let exportRequested = Notification.Name("exportRequested")
    static let openURLs        = Notification.Name("openURLs")
    static let clearCollection = Notification.Name("clearCollection")
}
