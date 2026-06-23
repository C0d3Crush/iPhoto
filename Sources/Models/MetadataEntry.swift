import Foundation

enum MetadataCategory: String, CaseIterable {
    case general  = "Allgemein"
    case dateTime = "Datum & Zeit"
    case camera   = "Kamera"
    case location = "Ort"
}

struct MetadataEntry: Identifiable {
    let id          = UUID()
    let displayName : String
    let key         : String
    let category    : MetadataCategory
    var value       : String
    var isEditable  : Bool = true
}

enum MetadataError: LocalizedError {
    case cannotReadFile
    case unknownFileType
    case cannotWriteFile
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotReadFile:        return "Datei konnte nicht gelesen werden."
        case .unknownFileType:       return "Unbekanntes Dateiformat."
        case .cannotWriteFile:       return "Ausgabeziel konnte nicht erstellt werden."
        case .writeFailed(let msg):  return "Schreiben fehlgeschlagen: \(msg)"
        }
    }
}
