import SwiftUI

struct PluginCommands: Commands {
    @ObservedObject var pluginStore = PluginStore.shared

    var body: some Commands {
        CommandMenu("Panels") {
            ForEach(pluginStore.plugins) { plugin in
                Toggle(plugin.name, isOn: pluginStore.enabledBinding(for: plugin.id))
            }
            Divider()
            Button("Plugins neu laden") {
                PluginStore.shared.reload()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
            Button("Plugin-Ordner öffnen") {
                PluginStore.shared.revealPluginDirectory()
            }
        }
    }
}
