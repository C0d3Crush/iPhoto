import SwiftUI

struct PluginCommands: Commands {
    @AppStorage("plugin.metadata") var metadataActive: Bool = true
    @AppStorage("plugin.anpassungen") var adjustmentsActive: Bool = false

    var body: some Commands {
        CommandMenu("Plugins") {
            Toggle(isOn: $metadataActive) {
                Text(InspectorPanel.metadata.rawValue)
            }
            Toggle(isOn: $adjustmentsActive) {
                Text(InspectorPanel.adjustments.rawValue)
            }
        }
    }
}
