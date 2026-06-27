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

    var body: some Commands {
        CommandMenu("Plugins") {
            Toggle(isOn: $ratingActive)           { Text(InspectorPanel.rating.rawValue) }
            Toggle(isOn: $metadataActive)         { Text(InspectorPanel.metadata.rawValue) }
            Toggle(isOn: $adjustmentsActive)      { Text(InspectorPanel.adjustments.rawValue) }
            Toggle(isOn: $localAdjustmentsActive) { Text(InspectorPanel.localAdjustments.rawValue) }
            Toggle(isOn: $presetsActive)          { Text(InspectorPanel.presets.rawValue) }
            Divider()
            Toggle(isOn: $analyseActive)          { Text(InspectorPanel.analyse.rawValue) }
            Toggle(isOn: $navigationActive)       { Text(InspectorPanel.navigation.rawValue) }
            Toggle(isOn: $hotpixelActive)         { Text(InspectorPanel.hotpixel.rawValue) }
        }
    }
}
