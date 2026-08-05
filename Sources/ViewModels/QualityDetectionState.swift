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
    @Published var blurryDocuments: [ImageDocument] = []         { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var underexposedDocuments: [ImageDocument] = []   { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var overexposedDocuments: [ImageDocument] = []    { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var blurThreshold: Double = BlurDetector.defaultThreshold
    @Published var shadowClipThreshold: Double = ExposureDetector.defaultShadowClipThreshold
    @Published var highlightClipThreshold: Double = ExposureDetector.defaultHighlightClipThreshold
}
