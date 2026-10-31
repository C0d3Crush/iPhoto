import Foundation
import SwiftUI

final class PanelStore: ObservableObject {
    static let shared = PanelStore()

    @Published private(set) var panels: [PanelDescriptor] = []
    @Published var enabledIDs: Set<String> = []

    init() {
        load()
    }

    func isEnabled(_ id: String) -> Bool { enabledIDs.contains(id) }

    func setEnabled(_ id: String, _ value: Bool) {
        if value { enabledIDs.insert(id) } else { enabledIDs.remove(id) }
        let key = panels.first(where: { $0.id == id })?.resolvedStorageKey ?? "panel.\(id)"
        UserDefaults.standard.set(value, forKey: key)
    }

    func enabledBinding(for id: String) -> Binding<Bool> {
        Binding(get: { self.isEnabled(id) }, set: { self.setEnabled(id, $0) })
    }

    // MARK: - Display order

    func orderedPanels(from order: [PanelDescriptor]) -> [PanelDescriptor] { order }

    static func loadDisplayOrder(from panels: [PanelDescriptor]) -> [PanelDescriptor] {
        let raw = UserDefaults.standard.string(forKey: "inspector.panelOrder") ?? ""
        let ids = raw.split(separator: ",").map(String.init)
        let byID = Dictionary(uniqueKeysWithValues: panels.map { ($0.id, $0) })
        let saved = ids.compactMap { byID[$0] }
        return Set(saved.map(\.id)) == Set(panels.map(\.id))
            ? saved
            : panels.sorted { $0.order < $1.order }
    }

    static func saveDisplayOrder(_ panels: [PanelDescriptor]) {
        UserDefaults.standard.set(panels.map(\.id).joined(separator: ","),
                                  forKey: "inspector.panelOrder")
    }

    // MARK: - Private

    private func load() {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let panelsDir = URL(fileURLWithPath: resourcePath).appendingPathComponent("Panels")
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: panelsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ).filter { $0.pathExtension == "json" }) ?? []

        let loaded = urls.compactMap { url -> PanelDescriptor? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(PanelDescriptor.self, from: data)
        }.sorted { $0.order < $1.order }

        var enabled = Set<String>()
        for panel in loaded {
            let stored = UserDefaults.standard.object(forKey: panel.resolvedStorageKey) as? Bool
            if stored ?? panel.defaultEnabled { enabled.insert(panel.id) }
        }

        panels = loaded
        enabledIDs = enabled
    }
}
