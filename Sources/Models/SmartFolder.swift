import Foundation

// MARK: - Attribute

enum SmartFolderAttribute: String, Codable, CaseIterable {
    // Enum-Typ
    case flag, colorLabel, isRAW, orientation, hdr
    // Numerisch
    case rating, iso, focalLength, aperture
    // Text
    case cameraMake, cameraModel, lens, filename

    var displayName: String {
        switch self {
        case .flag:         return "Markierung"
        case .colorLabel:   return "Farblabel"
        case .isRAW:        return "Dateityp"
        case .orientation:  return "Ausrichtung"
        case .hdr:          return "HDR"
        case .rating:       return "Bewertung"
        case .iso:          return "ISO"
        case .focalLength:  return "Brennweite"
        case .aperture:     return "Blende"
        case .cameraMake:   return "Kamera-Hersteller"
        case .cameraModel:  return "Kamera-Modell"
        case .lens:         return "Objektiv"
        case .filename:     return "Dateiname"
        }
    }

    enum AttributeType { case enumType, numeric, text }

    var type: AttributeType {
        switch self {
        case .flag, .colorLabel, .isRAW, .orientation, .hdr: return .enumType
        case .rating, .iso, .focalLength, .aperture:   return .numeric
        case .cameraMake, .cameraModel, .lens, .filename: return .text
        }
    }

    var defaultOperator: SmartFolderOperator {
        switch type {
        case .enumType: return .isExact
        case .numeric:  return .greaterThan
        case .text:     return .contains
        }
    }

    var availableOperators: [SmartFolderOperator] {
        switch type {
        case .enumType: return [.isExact, .isNot]
        case .numeric:  return [.isExact, .isNot, .greaterThan, .lessThan, .inRange]
        case .text:     return [.contains, .notContains, .isExact, .isNot, .beginsWith, .endsWith]
        }
    }
}

// MARK: - Operator

enum SmartFolderOperator: String, Codable {
    case isExact, isNot
    case contains, notContains, beginsWith, endsWith
    case greaterThan, lessThan, inRange

    var displayName: String {
        switch self {
        case .isExact:     return "ist"
        case .isNot:       return "ist nicht"
        case .contains:    return "enthält"
        case .notContains: return "enthält nicht"
        case .beginsWith:  return "beginnt mit"
        case .endsWith:    return "endet mit"
        case .greaterThan: return "ist größer als"
        case .lessThan:    return "ist kleiner als"
        case .inRange:     return "ist im Bereich"
        }
    }
}

// MARK: - Criterion

struct SmartFolderCriterion: Identifiable, Codable {
    var id: UUID = UUID()
    var attribute: SmartFolderAttribute = .flag
    var op: SmartFolderOperator = .isExact
    var flagValue: FlagStatus = .pick
    var ratingValue: Int = 3
    var ratingValue2: Int = 5
    var colorValue: ColorLabel = .red
    var textValue: String = ""
    var numericValue: Double = 100
    var numericValue2: Double = 400
    var boolValue: Bool = true
}

// MARK: - SmartFolder

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
