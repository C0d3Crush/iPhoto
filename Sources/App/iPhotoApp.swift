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
                .onAppear { }
        }
        Settings {
            SettingsView().environmentObject(viewModel)
        }
        .commands {
            PluginCommands()
            CommandGroup(replacing: .appInfo) {
                Button("Über iPhoto") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Rückgängig") {
                    NotificationCenter.default.post(name: .undoRequested, object: nil)
                }
                .keyboardShortcut("z", modifiers: .command)
                Button("Wiederholen") {
                    NotificationCenter.default.post(name: .redoRequested, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Markieren") {
                Button("Als Pick markieren") {
                    NotificationCenter.default.post(name: .flagPickRequested, object: nil)
                }
                .keyboardShortcut("p", modifiers: [])
                Button("Als Abgelehnt markieren") {
                    NotificationCenter.default.post(name: .flagRejectRequested, object: nil)
                }
                .keyboardShortcut("x", modifiers: [])
            }
            CommandMenu("Speicher") {
                Button("Ausgewählte sichern") {
                    NotificationCenter.default.post(name: .backupRequested, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)
                Button("Papierkorb leeren") {
                    NotificationCenter.default.post(name: .emptyTrashRequested, object: nil)
                }
                .keyboardShortcut(KeyEquivalent.delete, modifiers: [.command, .shift])
                Button("Duplikate prüfen") {
                    NotificationCenter.default.post(name: .checkDuplicatesRequested, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                Button("Backup-Ordner öffnen") {
                    NotificationCenter.default.post(name: .openBackupFolderRequested, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
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
    static let importRequested          = Notification.Name("importRequested")
    static let exportRequested          = Notification.Name("exportRequested")
    static let openURLs                 = Notification.Name("openURLs")
    static let clearCollection          = Notification.Name("clearCollection")
    static let flagPickRequested        = Notification.Name("flagPickRequested")
    static let flagRejectRequested      = Notification.Name("flagRejectRequested")
    static let undoRequested            = Notification.Name("undoRequested")
    static let redoRequested            = Notification.Name("redoRequested")
    static let backupRequested          = Notification.Name("backupRequested")
    static let emptyTrashRequested      = Notification.Name("emptyTrashRequested")
    static let checkDuplicatesRequested = Notification.Name("checkDuplicatesRequested")
    static let openBackupFolderRequested = Notification.Name("openBackupFolderRequested")
}
