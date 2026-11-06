import SwiftUI

// MARK: - Item definition

enum ActionBarItem: String, CaseIterable, Hashable {
    case sort, eye, rotateLeft, rotateRight, zoomOut, fitToWindow, actualSize, zoomIn

    var icon: String {
        switch self {
        case .sort:        return "arrow.up.arrow.down"
        case .eye:         return "eye"
        case .rotateLeft:  return "rotate.left"
        case .rotateRight: return "rotate.right"
        case .zoomOut:     return "minus.magnifyingglass"
        case .fitToWindow: return "arrow.up.left.and.arrow.down.right"
        case .actualSize:  return "1.magnifyingglass"
        case .zoomIn:      return "plus.magnifyingglass"
        }
    }

    var helpText: String {
        switch self {
        case .sort:        return "Sortierung"
        case .eye:         return "Original / Anpassungen"
        case .rotateLeft:  return "90° links drehen (⌘[)"
        case .rotateRight: return "90° rechts drehen (⌘])"
        case .zoomOut:     return "Verkleinern (⌘−)"
        case .fitToWindow: return "An Fenster anpassen"
        case .actualSize:  return "Originalgröße (⌘0)"
        case .zoomIn:      return "Vergrößern (⌘=)"
        }
    }

    static func loadOrder() -> [ActionBarItem] {
        guard let raw = UserDefaults.standard.string(forKey: "actionBar.order") else {
            return ActionBarItem.allCases
        }
        let saved = raw.split(separator: ",").compactMap { ActionBarItem(rawValue: String($0)) }
        let missing = ActionBarItem.allCases.filter { !saved.contains($0) }
        return saved.isEmpty ? ActionBarItem.allCases : saved + missing
    }

    static func saveOrder(_ items: [ActionBarItem]) {
        UserDefaults.standard.set(items.map(\.rawValue).joined(separator: ","),
                                  forKey: "actionBar.order")
    }
}
