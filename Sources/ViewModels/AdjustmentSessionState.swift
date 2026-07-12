import Foundation
import Combine
import CoreImage

/// Anpassungs-Session des aktuell angezeigten Bildes: Regler-State, gerendertes
/// Ergebnis, Undo/Redo-Historie, Presets und Render-Infrastruktur.
/// Zugriff nur vom Main-Thread — Render-Ergebnisse kommen via main.async zurück.
final class AdjustmentSessionState: ObservableObject {

    @Published var adjustments: AdjustmentState = AdjustmentState()
    @Published var adjustedImage: CGImage? = nil
    @Published var displayImageVersion: UUID = UUID()
    @Published var cropToolActive: Bool = false
    @Published var showOriginal: Bool = false
    /// Temporär ausgeblendete Einzel-Effekte (Auge-Toggle) — wird nicht persistiert
    @Published var bypassedAdjustments: Set<PartialKeyPath<AdjustmentState>> = []
    @Published var copiedAdjustments: AdjustmentState? = nil
    @Published var userPresets: [Preset] = []

    var history = AdjustmentHistory()
    var isUndoRedoing = false
    /// Zuletzt in den Katalog geschriebener (bzw. daraus geladener) Anpassungs-Stand
    var lastPersisted = AdjustmentState()
    /// Verwirft veraltete Render-Ergebnisse nach schnellem Bildwechsel
    var renderToken: UUID = UUID()

    let ciContext: CIContext = {
        var opts: [CIContextOption: Any] = [.useSoftwareRenderer: false]
        if let linearSRGB = CGColorSpace(name: CGColorSpace.linearSRGB) {
            opts[.workingColorSpace] = linearSRGB
        }
        opts[.workingFormat] = CIFormat.RGBAh
        return CIContext(options: opts)
    }()

    var hasActiveAdjustments: Bool { adjustments != AdjustmentState() }
}
