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
