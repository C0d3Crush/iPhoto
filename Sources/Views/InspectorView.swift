import SwiftUI

enum InspectorPanel: String, CaseIterable {
    case metadata    = "Metadaten"
    case adjustments = "Anpassungen"
    case analyse     = "Analyse"

    var storageKey: String { "plugin.\(rawValue.lowercased())" }
}

struct InspectorView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @AppStorage("plugin.metadata")    var metadataActive:    Bool = true
    @AppStorage("plugin.anpassungen") var adjustmentsActive: Bool = false
    @AppStorage("plugin.analyse")     var analyseActive:     Bool = false

    @State private var panelOrder: [InspectorPanel] = InspectorView.loadOrder()
    @State private var collapsed: Set<InspectorPanel> = Set(InspectorPanel.allCases)
    @State private var draggingPanel: InspectorPanel?

    private var activePanels: Set<InspectorPanel> {
        var s = Set<InspectorPanel>()
        if metadataActive    { s.insert(.metadata) }
        if adjustmentsActive { s.insert(.adjustments) }
        if analyseActive     { s.insert(.analyse) }
        return s
    }

    private var orderedActive: [InspectorPanel] {
        panelOrder.filter { activePanels.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if orderedActive.isEmpty {
                    VStack {
                        Spacer()
                        Text("Kein Plugin aktiv")
                            .foregroundColor(.secondary)
                            .font(.callout)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
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
                    }
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
                    Button(action: { viewModel.saveAll() }) {
                        if viewModel.isSavingToFile {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Text("Speichern")
                        }
                    }
                    .disabled(viewModel.isSavingToFile || !canSave)
                    .help(helpText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $viewModel.showVersionHistory) {
            VersionHistorySheet(isPresented: $viewModel.showVersionHistory)
                .environmentObject(viewModel)
        }
        .onChange(of: panelOrder) { InspectorView.saveOrder($0) }
    }

    private var canSave: Bool {
        (viewModel.hasActiveAdjustments && !viewModel.currentDocIsRAW) || viewModel.hasMetadataChanges
    }

    private var helpText: String {
        if viewModel.currentDocIsRAW && !viewModel.hasMetadataChanges {
            return "RAW — Anpassungen nicht speicherbar, aber Metadaten schon"
        }
        return "Änderungen ins Bild schreiben"
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
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        switch panel {
        case .metadata:
            MetadataPanel()
        case .adjustments:
            AdjustmentsPanel()
        case .analyse:
            AnalysePanel()
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
