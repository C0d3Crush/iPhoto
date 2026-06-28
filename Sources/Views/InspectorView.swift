import SwiftUI

enum InspectorPanel: String, CaseIterable {
    case rating           = "Bewertung"
    case metadata         = "Metadaten"
    case adjustments      = "Anpassungen"
    case localAdjustments = "Lokal"
    case presets          = "Rezepte"
    case analyse          = "Analyse"
    case navigation       = "Navigation"
    case hotpixel         = "Hotpixel"

    var storageKey: String { "plugin.\(rawValue.lowercased())" }
}

struct InspectorView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @AppStorage("plugin.bewertung")   var ratingActive:           Bool = true
    @AppStorage("plugin.metadata")    var metadataActive:         Bool = true
    @AppStorage("plugin.anpassungen") var adjustmentsActive:      Bool = false
    @AppStorage("plugin.lokal")       var localAdjustmentsActive: Bool = false
    @AppStorage("plugin.rezepte")     var presetsActive:          Bool = false
    @AppStorage("plugin.analyse")     var analyseActive:          Bool = false
    @AppStorage("plugin.navigation")  var navigationActive:       Bool = false
    @AppStorage("plugin.hotpixel")    var hotpixelActive:         Bool = false

    @State private var panelOrder: [InspectorPanel] = InspectorView.loadOrder()
    @State private var collapsed: Set<InspectorPanel> = Set(InspectorPanel.allCases)
    @State private var draggingPanel: InspectorPanel?

    private var activePanels: Set<InspectorPanel> {
        var s = Set<InspectorPanel>()
        if ratingActive           { s.insert(.rating) }
        if metadataActive         { s.insert(.metadata) }
        if adjustmentsActive      { s.insert(.adjustments) }
        if localAdjustmentsActive { s.insert(.localAdjustments) }
        if presetsActive          { s.insert(.presets) }
        if analyseActive          { s.insert(.analyse) }
        if navigationActive       { s.insert(.navigation) }
        if hotpixelActive         { s.insert(.hotpixel) }
        return s
    }

    private var orderedActive: [InspectorPanel] {
        panelOrder.filter { activePanels.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if orderedActive.isEmpty {
                Spacer()
                Text("Kein Plugin aktiv")
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(orderedActive, id: \.self) { panel in
                            InspectorBlock(
                                panel: panel,
                                isCollapsed: collapsed.contains(panel),
                                draggingPanel: $draggingPanel,
                                onToggleCollapse: { toggle(panel) }
                            )
                            .opacity(draggingPanel == panel ? 0.4 : 1.0)
                            .onDrop(of: ["public.text"],
                                    delegate: PanelDropDelegate(
                                        target: panel,
                                        order: $panelOrder,
                                        dragging: $draggingPanel))
                            Divider()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if viewModel.currentImage != nil {
                Divider()
                HStack(spacing: 8) {
                    if !viewModel.savedVersions.isEmpty {
                        Button(action: { viewModel.showVersionHistory = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("\(viewModel.savedVersions.count) Version\(viewModel.savedVersions.count == 1 ? "" : "en")")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.accentColor)
                    }
                    Spacer()
                    if viewModel.hasMetadataChanges {
                        Button(action: { viewModel.saveMetadata() }) {
                            if viewModel.isSavingToFile {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Text("Metadaten")
                            }
                        }
                        .disabled(viewModel.isSavingToFile)
                        .help("Metadaten ins Bild schreiben")
                    }
                    if viewModel.hasActiveAdjustments {
                        Button(action: { viewModel.showExportSheet = true }) {
                            Text("Exportieren")
                        }
                        .help("Anpassungen als neue Datei rendern")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(width: 280)
        .clipped()
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $viewModel.showVersionHistory) {
            VersionHistorySheet(isPresented: $viewModel.showVersionHistory)
                .environmentObject(viewModel)
        }
        .onChange(of: panelOrder) { InspectorView.saveOrder($0) }
    }


    private func toggle(_ panel: InspectorPanel) {
        if collapsed.contains(panel) { collapsed.remove(panel) }
        else { collapsed.insert(panel) }
    }

    // MARK: - Order persistence

    private static func loadOrder() -> [InspectorPanel] {
        let raw = UserDefaults.standard.string(forKey: "inspector.panelOrder") ?? ""
        let saved = raw.split(separator: ",").compactMap { InspectorPanel(rawValue: String($0)) }
        return Set(saved) == Set(InspectorPanel.allCases) ? saved : InspectorPanel.allCases
    }

    private static func saveOrder(_ order: [InspectorPanel]) {
        UserDefaults.standard.set(order.map(\.rawValue).joined(separator: ","),
                                  forKey: "inspector.panelOrder")
    }
}

// MARK: - Block

private struct InspectorBlock: View {
    let panel: InspectorPanel
    let isCollapsed: Bool
    @Binding var draggingPanel: InspectorPanel?
    let onToggleCollapse: () -> Void
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Draggable header
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                Text(panel.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onToggleCollapse) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .contentShape(Rectangle())
            .onTapGesture { onToggleCollapse() }
            .onDrag {
                DispatchQueue.main.async { draggingPanel = panel }
                return NSItemProvider(object: panel.rawValue as NSString)
            }

            // Content
            if !isCollapsed {
                panelContent
                    .frame(maxWidth: .infinity)
                    .clipShape(Rectangle())
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        switch panel {
        case .rating:
            RatingPanel()
        case .metadata:
            MetadataPanel()
        case .adjustments:
            AdjustmentsPanel()
        case .localAdjustments:
            LocalAdjustmentsPanel()
        case .presets:
            PresetsPanel()
        case .analyse:
            AnalysePanel()
        case .navigation:
            NavigationPanel()
        case .hotpixel:
            HotPixelPanel()
        }
    }
}

// MARK: - Drop delegate

private struct PanelDropDelegate: DropDelegate {
    let target: InspectorPanel
    @Binding var order: [InspectorPanel]
    @Binding var dragging: InspectorPanel?

    func dropEntered(info: DropInfo) {
        guard let src = dragging, src != target,
              let from = order.firstIndex(of: src),
              let to   = order.firstIndex(of: target) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            order.move(fromOffsets: IndexSet(integer: from),
                       toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
