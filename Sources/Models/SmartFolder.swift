import Foundation

// MARK: - Dynamic Date Range

enum DynamicDateRange: String, Codable, CaseIterable {
    case today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth, thisYear
    case last7Days, last30Days, last90Days

    var displayName: String {
        switch self {
        case .today:      return "Heute"
        case .yesterday:  return "Gestern"
        case .thisWeek:   return "Diese Woche"
        case .lastWeek:   return "Letzte Woche"
        case .thisMonth:  return "Dieser Monat"
        case .lastMonth:  return "Letzter Monat"
        case .thisYear:   return "Dieses Jahr"
        case .last7Days:  return "Letzte 7 Tage"
        case .last30Days: return "Letzte 30 Tage"
        case .last90Days: return "Letzte 90 Tage"
        }
    }

    func matches(_ date: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .today:
            return cal.isDateInToday(date)
        case .yesterday:
            return cal.isDateInYesterday(date)
        case .thisWeek:
            return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .lastWeek:
            let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: now)!
            return cal.isDate(date, equalTo: lastWeek, toGranularity: .weekOfYear)
        case .thisMonth:
            return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .lastMonth:
            let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!
            return cal.isDate(date, equalTo: lastMonth, toGranularity: .month)
        case .thisYear:
            return cal.isDate(date, equalTo: now, toGranularity: .year)
        case .last7Days:
            return date >= cal.date(byAdding: .day, value: -7, to: now)!
        case .last30Days:
            return date >= cal.date(byAdding: .day, value: -30, to: now)!
        case .last90Days:
            return date >= cal.date(byAdding: .day, value: -90, to: now)!
        }
    }
}

// MARK: - Attribute

enum SmartFolderAttribute: String, Codable, CaseIterable {
    // Enum-Typ
    case flag, colorLabel, isRAW, orientation, hdr
    // Numerisch
    case rating, iso, focalLength, aperture
    // Datum
    case captureDate
    // Text
    case cameraMake, cameraModel, lens, filename
    // Album
    case album

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
        case .captureDate:  return "Aufnahmedatum"
        case .cameraMake:   return "Kamera-Hersteller"
        case .cameraModel:  return "Kamera-Modell"
        case .lens:         return "Objektiv"
        case .filename:     return "Dateiname"
        case .album:        return "Album"
        }
    }

    enum AttributeType { case enumType, numeric, dateType, text, albumType }

    var type: AttributeType {
        switch self {
        case .flag, .colorLabel, .isRAW, .orientation, .hdr: return .enumType
        case .rating, .iso, .focalLength, .aperture:   return .numeric
        case .captureDate:                             return .dateType
        case .cameraMake, .cameraModel, .lens, .filename: return .text
        case .album:                                   return .albumType
        }
    }

    var defaultOperator: SmartFolderOperator {
        switch type {
        case .enumType:  return .isExact
        case .numeric:   return .greaterThan
        case .dateType:  return .isDynamic
        case .text:      return .contains
        case .albumType: return .isExact
        }
    }

    var availableOperators: [SmartFolderOperator] {
        switch type {
        case .enumType:  return [.isExact, .isNot]
        case .numeric:   return [.isExact, .isNot, .greaterThan, .lessThan, .inRange]
        case .dateType:  return [.isDynamic, .isAfter, .isBefore, .inDateRange]
        case .text:      return [.contains, .notContains, .isExact, .isNot, .beginsWith, .endsWith]
        case .albumType: return [.isExact, .isNot]
        }
    }
}

// MARK: - Operator

enum SmartFolderOperator: String, Codable {
    case isExact, isNot
    case contains, notContains, beginsWith, endsWith
    case greaterThan, lessThan, inRange
    case isBefore, isAfter, inDateRange, isDynamic

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
        case .isBefore:    return "ist vor"
        case .isAfter:     return "ist nach"
        case .inDateRange: return "liegt zwischen"
        case .isDynamic:   return "ist in"
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
    var dateValue: Date = Date()
    var dateValue2: Date = Date()
    var dynamicDateRange: DynamicDateRange = .thisMonth

    // Custom decode for backward compatibility with saved folders that lack date fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeIfPresent(UUID.self,                  forKey: .id)              ?? UUID()
        attribute       = try c.decodeIfPresent(SmartFolderAttribute.self,  forKey: .attribute)       ?? .flag
        op              = try c.decodeIfPresent(SmartFolderOperator.self,   forKey: .op)              ?? .isExact
        flagValue       = try c.decodeIfPresent(FlagStatus.self,            forKey: .flagValue)       ?? .pick
        ratingValue     = try c.decodeIfPresent(Int.self,                   forKey: .ratingValue)     ?? 3
        ratingValue2    = try c.decodeIfPresent(Int.self,                   forKey: .ratingValue2)    ?? 5
        colorValue      = try c.decodeIfPresent(ColorLabel.self,            forKey: .colorValue)      ?? .red
        textValue       = try c.decodeIfPresent(String.self,                forKey: .textValue)       ?? ""
        numericValue    = try c.decodeIfPresent(Double.self,                forKey: .numericValue)    ?? 100
        numericValue2   = try c.decodeIfPresent(Double.self,                forKey: .numericValue2)   ?? 400
        boolValue       = try c.decodeIfPresent(Bool.self,                  forKey: .boolValue)       ?? true
        dateValue       = try c.decodeIfPresent(Date.self,                  forKey: .dateValue)       ?? Date()
        dateValue2      = try c.decodeIfPresent(Date.self,                  forKey: .dateValue2)      ?? Date()
        dynamicDateRange = try c.decodeIfPresent(DynamicDateRange.self,     forKey: .dynamicDateRange) ?? .thisMonth
    }

    init() {}
}

// MARK: - SmartFolder

struct SmartFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var criteria: [SmartFolderCriterion]
    var matchAll: Bool
    var group: String?

    init(name: String) {
        id = UUID()
        self.name = name
        criteria = []
        matchAll = true
        group = nil
    }

    // Custom decode for backward compatibility with saved folders that lack the group field.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decodeIfPresent(UUID.self,                    forKey: .id)       ?? UUID()
        name     = try c.decodeIfPresent(String.self,                  forKey: .name)     ?? ""
        criteria = try c.decodeIfPresent([SmartFolderCriterion].self,  forKey: .criteria) ?? []
        matchAll = try c.decodeIfPresent(Bool.self,                    forKey: .matchAll) ?? true
        group    = try c.decodeIfPresent(String.self,                  forKey: .group)
    }
}
