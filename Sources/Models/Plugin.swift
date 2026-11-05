import Foundation

struct Plugin: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    var icon: String = "puzzlepiece.extension"
    var builtin: String? = nil       // non-nil → renders a built-in Swift view by this key
    var order: Int = 99
    var defaultEnabled: Bool = true
    var storageKey: String = ""      // "" → derived as "plugin.<id>"
    var rows: [PluginRow] = []
    var actions: [PluginAction] = []

    var resolvedStorageKey: String {
        storageKey.isEmpty ? "plugin.\(id)" : storageKey
    }

    var isBuiltin: Bool { builtin != nil }

    // Synthesized Codable doesn't use Swift default values for missing keys,
    // so we handle optional fields manually to stay compatible with all JSON variants.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(String.self,        forKey: .id)
        name           = try c.decode(String.self,        forKey: .name)
        icon           = try c.decodeIfPresent(String.self,     forKey: .icon)          ?? "puzzlepiece.extension"
        builtin        = try c.decodeIfPresent(String.self,     forKey: .builtin)
        order          = try c.decodeIfPresent(Int.self,        forKey: .order)         ?? 99
        defaultEnabled = try c.decodeIfPresent(Bool.self,       forKey: .defaultEnabled) ?? true
        storageKey     = try c.decodeIfPresent(String.self,     forKey: .storageKey)    ?? ""
        rows           = try c.decodeIfPresent([PluginRow].self,    forKey: .rows)      ?? []
        actions        = try c.decodeIfPresent([PluginAction].self, forKey: .actions)   ?? []
    }

    struct PluginRow: Codable, Equatable {
        let label: String
        var command: String?
        var staticValue: String?

        enum CodingKeys: String, CodingKey {
            case label, command
            case staticValue = "static"
        }
    }

    struct PluginAction: Codable, Equatable {
        let label: String
        var icon: String?
        let command: String
    }
}
