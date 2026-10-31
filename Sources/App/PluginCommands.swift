import SwiftUI

struct PluginCommands: Commands {
    @ObservedObject var panelStore = PanelStore.shared

    var body: some Commands {
        CommandMenu("Panels") {
            ForEach(panelStore.panels) { panel in
                Toggle(panel.name, isOn: panelStore.enabledBinding(for: panel.id))
            }
            Divider()
            Button("Externe Plugins neu laden") {
                PluginStore.shared.reload()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
            Button("Plugin-Ordner öffnen") {
                PluginStore.shared.revealPluginDirectory()
            }
        }
    }
}
