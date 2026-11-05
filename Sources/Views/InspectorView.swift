import SwiftUI

struct InspectorView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @ObservedObject private var pluginStore = PluginStore.shared

    @State private var pluginOrder: [Plugin] =
        PluginStore.loadDisplayOrder(from: PluginStore.shared.plugins)
    @State private var collapsed: Set<String> = {
        if let saved = UserDefaults.standard.stringArray(forKey: "inspector.collapsed") {
            return Set(saved)
        }
        return Set(PluginStore.shared.plugins.map(\.id))
    }()
    @State private var draggingPlugin: Plugin?

    private var orderedActive: [Plugin] {
        pluginOrder.filter { pluginStore.isEnabled($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with expand toggle
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.inspectorExpanded.toggle()
                    }
                }) {
                    Image(systemName: viewModel.inspectorExpanded
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 10)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                }
                .buttonStyle(PlainButtonStyle())
                .help(viewModel.inspectorExpanded ? "Inspector verkleinern" : "Inspector vergrößern")
                Spacer()
            }
            Divider()

            if orderedActive.isEmpty {
                Spacer()
                Text("Kein Panel aktiv")
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(orderedActive, id: \.id) { plugin in
                            PluginBlock(
                                plugin: plugin,
                                isCollapsed: collapsed.contains(plugin.id),
                                draggingPlugin: $draggingPlugin,
                                onToggleCollapse: { toggleCollapsed(plugin.id) }
                            )
                            .opacity(draggingPlugin == plugin ? 0.4 : 1.0)
                            .onDrop(of: ["public.text"],
                                    delegate: PluginDropDelegate(
                                        target: plugin,
                                        order: $pluginOrder,
                                        dragging: $draggingPlugin))
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
        .frame(width: viewModel.inspectorExpanded ? 480 : 280)
        .clipped()
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $viewModel.versions.showHistory) {
            VersionHistorySheet(isPresented: $viewModel.versions.showHistory)
                .environmentObject(viewModel)
        }
        .onChange(of: pluginOrder) { PluginStore.saveDisplayOrder($0) }
        .onChange(of: pluginStore.plugins) { newPlugins in
            pluginOrder = PluginStore.loadDisplayOrder(from: newPlugins)
        }
    }

    private func toggleCollapsed(_ id: String) {
        if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
        UserDefaults.standard.set(Array(collapsed), forKey: "inspector.collapsed")
    }
}

// MARK: - Unified Plugin Block

private struct PluginBlock: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let plugin: Plugin
    let isCollapsed: Bool
    @Binding var draggingPlugin: Plugin?
    let onToggleCollapse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                Image(systemName: plugin.icon)
                    .font(.caption)
                    .foregroundColor(plugin.isBuiltin ? .secondary : .accentColor)
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
            .onDrag {
                DispatchQueue.main.async { draggingPlugin = plugin }
                return NSItemProvider(object: plugin.id as NSString)
            }

            if !isCollapsed {
                pluginContent
                    .frame(maxWidth: .infinity)
                    .clipShape(Rectangle())
            }
        }
    }

    @ViewBuilder
    private var pluginContent: some View {
        if let key = plugin.builtin {
            builtinView(for: key)
        } else {
            PluginPanelView(plugin: plugin)
                .environmentObject(viewModel)
        }
    }

    @ViewBuilder
    private func builtinView(for key: String) -> some View {
        switch key {
        case "compare":     ComparePanel()
        case "rating":      RatingPanel()
        case "metadata":    MetadataPanel()
        case "adjustments": AdjustmentsPanel()
        case "local":       LocalAdjustmentsPanel()
        case "presets":     PresetsPanel()
        case "analyse":     AnalysePanel()
        case "navigation":  NavigationPanel()
        case "hotpixel":    HotPixelPanel()
        case "inpaint":     InpaintPanel()
        case "toolbox":     ToolboxPanel()
        case "similar":     SimilarPanel()
        case "people":      PeoplePanel()
        default:            EmptyView()
        }
    }
}

// MARK: - Drop delegate

private struct PluginDropDelegate: DropDelegate {
    let target: Plugin
    @Binding var order: [Plugin]
    @Binding var dragging: Plugin?

    func dropEntered(info: DropInfo) {
        guard let src = dragging, src.id != target.id,
              let from = order.firstIndex(where: { $0.id == src.id }),
              let to   = order.firstIndex(where: { $0.id == target.id }) else { return }
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
