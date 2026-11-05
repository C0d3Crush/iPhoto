import Foundation

enum LibraryViewMode: String, CaseIterable {
    case grid, list, columns, gallery

    var displayName: String {
        switch self {
        case .grid:    return "Als Symbole"
        case .list:    return "Als Liste"
        case .columns: return "Als Spalten"
        case .gallery: return "Als Galerie"
        }
    }

    var icon: String {
        switch self {
        case .grid:    return "square.grid.2x2"
        case .list:    return "list.bullet"
        case .columns: return "rectangle.split.2x1.fill"
        case .gallery: return "photo"
        }
    }
}
