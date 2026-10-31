import Foundation

struct Plugin: Identifiable, Codable {
    let id: String
    let name: String
    var icon: String = "puzzlepiece.extension"
    var rows: [PluginRow] = []
    var actions: [PluginAction] = []

    struct PluginRow: Codable {
        let label: String
        var command: String?
        var staticValue: String?

        enum CodingKeys: String, CodingKey {
            case label, command
            case staticValue = "static"
        }
    }

    struct PluginAction: Codable {
        let label: String
        var icon: String?
        let command: String
    }
}
