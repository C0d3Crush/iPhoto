import CoreGraphics
import Vision

// Erkennt Motive/Szenen per VNClassifyImageRequest (macOS 11+).
// Gibt bis zu maxLabels Identifier mit Konfidenz ≥ confidenceThreshold zurück,
// sortiert nach absteigender Konfidenz. Identifiers werden lowercase+underscore
// normalisiert, damit Matching stabil bleibt (Vision ändert Schreibweise nicht,
// aber Leerzeichen vermeiden ist defensive Programmierung).
//
// Perf-Anker: ~80–200 ms pro 512 px Thumbnail — nur im Background-Motif-Scan.

struct MotifAssessor {
    static let confidenceThreshold: Float = 0.25
    static let maxLabels = 8

    // Bekannte Labels für die SmartFolder-UI (id = was wir speichern, name = Anzeige).
    // Vision-Identifiers sind oft hierarchisch; wir matchen contains() → Parent-Labels
    // ("animal") treffen auch spezifischere Bilder ("dog_domestic").
    static let knownLabels: [(id: String, name: String)] = [
        ("sky",           "Himmel"),
        ("cloud",         "Wolken"),
        ("nature",        "Natur"),
        ("outdoor",       "Draußen"),
        ("indoor",        "Drinnen"),
        ("tree",          "Baum / Wald"),
        ("flower",        "Blume"),
        ("plant",         "Pflanze"),
        ("dog",           "Hund"),
        ("cat",           "Katze"),
        ("bird",          "Vogel"),
        ("horse",         "Pferd"),
        ("person",        "Person"),
        ("water",         "Wasser"),
        ("ocean",         "Meer"),
        ("beach",         "Strand"),
        ("mountain",      "Berg"),
        ("snow",          "Schnee"),
        ("architecture",  "Architektur"),
        ("food",          "Essen"),
        ("vehicle",       "Fahrzeug"),
        ("night",         "Nacht"),
        ("sunset",        "Sonnenuntergang"),
        ("animal",        "Tier (allg.)"),
    ]

    struct Result {
        let tags: [String]
    }

    static func assess(url: URL) -> Result? {
        guard let img = try? RAWImageDecoder.thumbnail(url: url, maxDimension: 512) else { return nil }
        return assess(image: img)
    }

    static func assess(image: CGImage) -> Result {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let observations = request.results as? [VNClassificationObservation] else {
            return Result(tags: [])
        }
        let tags = observations
            .filter { $0.confidence >= confidenceThreshold }
            .prefix(maxLabels)
            .map { $0.identifier.lowercased().replacingOccurrences(of: " ", with: "_") }
        return Result(tags: Array(tags))
    }

    // Suche nach einem bekannten Display-Namen für einen gespeicherten Identifier.
    static func displayName(for id: String) -> String {
        knownLabels.first { id.contains($0.id) }?.name ?? id
    }
}
