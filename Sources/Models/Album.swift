import Foundation

struct Album: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var photoURLs: [URL]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.photoURLs = []
    }
}

enum NavSelection: Hashable {
    case library
    case album(UUID)
}
