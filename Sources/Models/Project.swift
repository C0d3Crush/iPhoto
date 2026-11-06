import Foundation

struct Project: Codable, Identifiable {
    let id: UUID
    var name: String
    var folderPaths: [String]
    var createdAt: Date
    var lastOpenedAt: Date?

    init(id: UUID = UUID(), name: String, folderPaths: [String]) {
        self.id = id
        self.name = name
        self.folderPaths = folderPaths
        self.createdAt = Date()
    }
}
