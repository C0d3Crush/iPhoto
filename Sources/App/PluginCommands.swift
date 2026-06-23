import SwiftUI

struct PluginCommands: Commands {
    @AppStorage("plugin.metadata") var metadataActive: Bool = true

    var body: some Commands {
        CommandMenu("Plugins") {
            Toggle(isOn: $metadataActive) {
                Text(InspectorPanel.metadata.rawValue)
            }
        }
    }
}
