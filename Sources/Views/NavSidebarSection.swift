import SwiftUI

enum NavSidebarSection: String, CaseIterable, Hashable {
    case library, albums, folders, smartFolders, iFolders, volumes, trash, backup, duplicates, blurry, people

    static func loadOrder() -> [NavSidebarSection] {
        guard let raw = UserDefaults.standard.string(forKey: "nav.sectionOrder") else {
            return NavSidebarSection.allCases
        }
        let saved = raw.split(separator: ",").compactMap { NavSidebarSection(rawValue: String($0)) }
        let missing = NavSidebarSection.allCases.filter { !saved.contains($0) }
        return saved + missing
    }

    static func saveOrder(_ order: [NavSidebarSection]) {
        UserDefaults.standard.set(order.map(\.rawValue).joined(separator: ","), forKey: "nav.sectionOrder")
    }

    static func isVisible(_ section: NavSidebarSection) -> Bool {
        let key = "sidebar.section.\(section.rawValue)"
        return UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    static func setVisible(_ section: NavSidebarSection, _ visible: Bool) {
        UserDefaults.standard.set(visible, forKey: "sidebar.section.\(section.rawValue)")
    }

    var displayName: String {
        switch self {
        case .library:      return "Bibliothek"
        case .albums:       return "Alben"
        case .folders:      return "Ordner"
        case .smartFolders: return "iAlben"
        case .iFolders:     return "iOrdner"
        case .volumes:      return "Wechseldatenträger"
        case .trash:        return "Papierkorb"
        case .backup:       return "Backup"
        case .duplicates:   return "Duplikate"
        case .blurry:       return "Qualität"
        case .people:       return "Menschen"
        }
    }

    var icon: String {
        switch self {
        case .library:      return "photo.on.rectangle.angled"
        case .albums:       return "rectangle.stack"
        case .folders:      return "folder"
        case .smartFolders: return "folder.badge.gearshape"
        case .iFolders:     return "folder.badge.gearshape"
        case .volumes:      return "externaldrive"
        case .trash:        return "trash"
        case .backup:       return "externaldrive.badge.checkmark"
        case .duplicates:   return "doc.on.doc"
        case .blurry:       return "eye.trianglebadge.exclamationmark"
        case .people:       return "person.2"
        }
    }
}
