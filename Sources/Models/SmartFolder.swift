import Foundation

enum SmartFolderCriterionKind: String, Codable, CaseIterable {
    case flag, ratingAtLeast, colorLabel, cameraMake, cameraModel

    var displayName: String {
        switch self {
        case .flag:         return "Markierung"
        case .ratingAtLeast:return "Mindestbewertung"
        case .colorLabel:   return "Farblabel"
        case .cameraMake:   return "Kamera-Hersteller"
        case .cameraModel:  return "Kamera-Modell"
        }
    }
}

struct SmartFolderCriterion: Identifiable, Codable {
    var id: UUID = UUID()
    var kind: SmartFolderCriterionKind = .flag
    var flagValue: FlagStatus = .pick
    var ratingValue: Int = 3
    var colorValue: ColorLabel = .red
    var textValue: String = ""
}

struct SmartFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var criteria: [SmartFolderCriterion]
    var matchAll: Bool

    init(name: String) {
        id = UUID()
        self.name = name
        criteria = []
        matchAll = true
    }
}
