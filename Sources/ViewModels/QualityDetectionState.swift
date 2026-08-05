import Foundation
import Combine

/// State-Bündel für Qualitätsanalysen (Duplikate, Unschärfe, Belichtung).
/// Zuvor lag der State (7 Felder + 3 Cache-Invalidierungs-Publisher) direkt auf
/// ImageViewModel — Extraktion senkt die VM-Komplexität, ohne Semantik zu ändern.
///
/// Main-Thread-Invariante: analog zu ImageCollection/ImageViewModel — alle Producer
/// in ImageViewModel+QualityDetection.swift dispatchen bereits via
/// DispatchQueue.main.async zurück.
final class QualityDetectionState: ObservableObject {
    @Published var duplicateGroups: [[ImageDocument]] = []       { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var similarGroups: [[ImageDocument]] = []         { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var blurryDocuments: [ImageDocument] = []         { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var underexposedDocuments: [ImageDocument] = []   { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var overexposedDocuments: [ImageDocument] = []    { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    // Schwellenwerte werden in UserDefaults persistiert — Overrides des Nutzers und
    // manuelle Anpassungen im Settings-Panel überleben so den App-Neustart.
    @Published var blurThreshold: Double = BlurDetector.defaultThreshold {
        didSet { UserDefaults.standard.set(blurThreshold, forKey: Self.blurKey) }
    }
    @Published var shadowClipThreshold: Double = ExposureDetector.defaultShadowClipThreshold {
        didSet { UserDefaults.standard.set(shadowClipThreshold, forKey: Self.shadowKey) }
    }
    @Published var highlightClipThreshold: Double = ExposureDetector.defaultHighlightClipThreshold {
        didSet { UserDefaults.standard.set(highlightClipThreshold, forKey: Self.highlightKey) }
    }

    static let blurKey      = "quality.blurThreshold"
    static let shadowKey    = "quality.shadowClipThreshold"
    static let highlightKey = "quality.highlightClipThreshold"

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: Self.blurKey)      != nil { blurThreshold          = d.double(forKey: Self.blurKey) }
        if d.object(forKey: Self.shadowKey)    != nil { shadowClipThreshold    = d.double(forKey: Self.shadowKey) }
        if d.object(forKey: Self.highlightKey) != nil { highlightClipThreshold = d.double(forKey: Self.highlightKey) }
    }

    func resetThresholdsToDefaults() {
        blurThreshold          = BlurDetector.defaultThreshold
        shadowClipThreshold    = ExposureDetector.defaultShadowClipThreshold
        highlightClipThreshold = ExposureDetector.defaultHighlightClipThreshold
    }
}
