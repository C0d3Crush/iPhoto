import Foundation

struct Album: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var photoURLs: [URL]
    /// Übergeordneter AlbumFolder — nil = auf Root-Ebene sichtbar.
    /// Custom-Decoder unten macht das Feld rückwärtskompatibel: alte JSON-Dateien
    /// ohne parentID landen automatisch auf Root, keine Migration nötig.
    var parentID: UUID?

    init(name: String, parentID: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.photoURLs = []
        self.parentID = parentID
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, photoURLs, parentID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.photoURLs = try c.decode([URL].self, forKey: .photoURLs)
        self.parentID = try c.decodeIfPresent(UUID.self, forKey: .parentID)
    }
}

/// Container für Alben (und andere AlbumFolders). Enthält selbst keine Fotos —
/// beim Klick werden die Fotos aller enthaltenen Alben rekursiv aggregiert.
struct AlbumFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    /// Übergeordneter Folder — nil = Root-Ebene.
    var parentID: UUID?

    init(name: String, parentID: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.parentID = parentID
    }
}

enum NavSelection: Hashable {
    case library
    case album(UUID)
    case albumFolder(UUID)
    case folder(UUID)
    case smartFolder(UUID)
    case volume(UUID)
    case trash
    case duplicates
    case similar
    // Temporärer Scope auf eine einzelne Similar-Gruppe: main viewer + Pfeiltasten
    // iterieren nur innerhalb dieser Gruppe. Int = Index in quality.similarGroups.
    case similarGroup(Int)
    case blurry
    case underexposed
    case overexposed
    case closedEyes
}
