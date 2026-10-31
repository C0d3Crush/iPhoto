import Foundation

struct PanelDescriptor: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    var icon: String = "square.grid.2x2"
    var defaultEnabled: Bool = false
    var order: Int = 99
    var storageKey: String = ""

    var resolvedStorageKey: String {
        storageKey.isEmpty ? "panel.\(id)" : storageKey
    }
}
