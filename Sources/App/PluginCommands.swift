import SwiftUI

struct PluginCommands: Commands {
    @AppStorage("plugin.bewertung")   var ratingActive:           Bool = true
    @AppStorage("plugin.metadata")    var metadataActive:         Bool = true
    @AppStorage("plugin.anpassungen") var adjustmentsActive:      Bool = false
    @AppStorage("plugin.lokal")       var localAdjustmentsActive: Bool = false
    @AppStorage("plugin.rezepte")     var presetsActive:          Bool = false
    @AppStorage("plugin.analyse")     var analyseActive:          Bool = false
    @AppStorage("plugin.navigation")  var navigationActive:       Bool = false
    @AppStorage("plugin.hotpixel")    var hotpixelActive:         Bool = false
    @AppStorage("plugin.inpaint")     var inpaintActive:          Bool = false

    var body: some Commands {
        CommandMenu("Plugins") {
            Group {
                Toggle(isOn: $ratingActive)           { Text(InspectorPanel.rating.rawValue) }
                Toggle(isOn: $metadataActive)         { Text(InspectorPanel.metadata.rawValue) }
                Toggle(isOn: $adjustmentsActive)      { Text(InspectorPanel.adjustments.rawValue) }
                Toggle(isOn: $localAdjustmentsActive) { Text(InspectorPanel.localAdjustments.rawValue) }
                Toggle(isOn: $presetsActive)          { Text(InspectorPanel.presets.rawValue) }
            }
            Divider()
            Group {
                Toggle(isOn: $analyseActive)          { Text(InspectorPanel.analyse.rawValue) }
                Toggle(isOn: $navigationActive)       { Text(InspectorPanel.navigation.rawValue) }
                Toggle(isOn: $hotpixelActive)         { Text(InspectorPanel.hotpixel.rawValue) }
                Toggle(isOn: $inpaintActive)          { Text(InspectorPanel.inpaint.rawValue) }
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
