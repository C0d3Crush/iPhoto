import SwiftUI

struct InspectorView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @ObservedObject private var pluginStore = PluginStore.shared
    @ObservedObject private var panelStore  = PanelStore.shared

    @State private var panelOrder: [PanelDescriptor] =
        PanelStore.loadDisplayOrder(from: PanelStore.shared.panels)
    @State private var collapsed: Set<String> = Set(PanelStore.shared.panels.map(\.id))
    @State private var collapsedPlugins: Set<String> = []
    @State private var draggingPanel: PanelDescriptor?

    private var orderedActive: [PanelDescriptor] {
        panelOrder.filter { panelStore.isEnabled($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if orderedActive.isEmpty && pluginStore.plugins.isEmpty {
                Spacer()
                Text("Kein Panel aktiv")
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(orderedActive, id: \.id) { panel in
                            InspectorBlock(
                                panel: panel,
                                isCollapsed: collapsed.contains(panel.id),
                                draggingPanel: $draggingPanel,
                                onToggleCollapse: { toggleCollapsed(panel.id) }
                            )
                            .opacity(draggingPanel == panel ? 0.4 : 1.0)
                            .onDrop(of: ["public.text"],
                                    delegate: PanelDropDelegate(
                                        target: panel,
                                        order: $panelOrder,
                                        dragging: $draggingPanel))
                            Divider()
                        }

                        ForEach(pluginStore.plugins) { plugin in
                            PluginBlock(
                                plugin: plugin,
                                isCollapsed: collapsedPlugins.contains(plugin.id),
                                onToggleCollapse: {
                                    if collapsedPlugins.contains(plugin.id) {
                                        collapsedPlugins.remove(plugin.id)
                                    } else {
                                        collapsedPlugins.insert(plugin.id)
                                    }
                                }
                            )
                            .environmentObject(viewModel)
                            Divider()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if viewModel.currentImage != nil {
                Divider()
                HStack(spacing: 8) {
                    if !viewModel.versions.savedVersions.isEmpty {
                        Button(action: { viewModel.versions.showHistory = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("\(viewModel.versions.savedVersions.count) Version\(viewModel.versions.savedVersions.count == 1 ? "" : "en")")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.accentColor)
                    }
                    Spacer()
                    if viewModel.hasMetadataChanges {
                        Button(action: { viewModel.saveMetadata() }) {
                            if viewModel.versions.isSavingToFile {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Text("Metadaten")
                            }
                        }
                        .disabled(viewModel.versions.isSavingToFile)
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
        .sheet(isPresented: $viewModel.versions.showHistory) {
            VersionHistorySheet(isPresented: $viewModel.versions.showHistory)
                .environmentObject(viewModel)
        }
        .onChange(of: panelOrder) { PanelStore.saveDisplayOrder($0) }
        .onChange(of: panelStore.panels) { newPanels in
            // Sync order when panels change (e.g. after bundle reload)
            panelOrder = PanelStore.loadDisplayOrder(from: newPanels)
        }
    }

    private func toggleCollapsed(_ id: String) {
        if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
    }
}

// MARK: - Block

private struct InspectorBlock: View {
    let panel: PanelDescriptor
    let isCollapsed: Bool
    @Binding var draggingPanel: PanelDescriptor?
    let onToggleCollapse: () -> Void
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                Text(panel.name)
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
                return NSItemProvider(object: panel.id as NSString)
            }

            if !isCollapsed {
                panelContent
                    .frame(maxWidth: .infinity)
                    .clipShape(Rectangle())
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        switch panel.id {
        case "rating":      RatingPanel()
        case "metadata":    MetadataPanel()
        case "adjustments": AdjustmentsPanel()
        case "local":       LocalAdjustmentsPanel()
        case "presets":     PresetsPanel()
        case "analyse":     AnalysePanel()
        case "navigation":  NavigationPanel()
        case "hotpixel":    HotPixelPanel()
        case "inpaint":     InpaintPanel()
        default:            EmptyView()
        }
    }
}

// MARK: - Drop delegate

private struct PanelDropDelegate: DropDelegate {
    let target: PanelDescriptor
    @Binding var order: [PanelDescriptor]
    @Binding var dragging: PanelDescriptor?

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

// MARK: - Plugin Block

private struct PluginBlock: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let plugin: Plugin
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                Image(systemName: plugin.icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(plugin.name)
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

            if !isCollapsed {
                PluginPanelView(plugin: plugin)
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity)
                    .clipShape(Rectangle())
            }
        }
    }
}
