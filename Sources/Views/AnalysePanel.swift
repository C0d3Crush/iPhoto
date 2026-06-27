import SwiftUI

private enum AnalyseTool: String, CaseIterable {
    case histogram = "Histogramm"
    case waveform  = "Waveform"
    case parade    = "RGB-Parade"
    case curves    = "Kurven"
}

struct AnalysePanel: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @StateObject private var engine = AnalysisEngine()
    @State private var toolOrder: [AnalyseTool] = AnalyseTool.allCases
    @State private var collapsed: Set<AnalyseTool> = Set(AnalyseTool.allCases)
    @State private var draggingTool: AnalyseTool?

    var body: some View {
        if viewModel.currentImage == nil {
            VStack {
                Spacer()
                Text("Kein Bild geladen")
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                ForEach(toolOrder, id: \.self) { tool in
                    AnalyseToolBlock(
                        tool: tool,
                        isCollapsed: collapsed.contains(tool),
                        draggingTool: $draggingTool,
                        engine: engine,
                        viewModel: viewModel,
                        onToggleCollapse: { toggle(tool) }
                    )
                    .opacity(draggingTool == tool ? 0.4 : 1.0)
                    .onDrop(of: ["public.text"],
                            delegate: ToolDropDelegate(
                                target: tool,
                                order: $toolOrder,
                                dragging: $draggingTool))
                    Divider()
                }
            }
            .onAppear { triggerAnalysis() }
            .onChange(of: viewModel.collection.currentIndex) { _ in engine.clear() }
            .onChange(of: viewModel.displayImageVersion) { _ in triggerAnalysis() }
        }
    }

    private func toggle(_ tool: AnalyseTool) {
        if collapsed.contains(tool) { collapsed.remove(tool) }
        else { collapsed.insert(tool) }
    }

    private func triggerAnalysis() {
        if let img = viewModel.adjustedImage ?? viewModel.currentImage {
            engine.analyze(img)
        }
    }
}

// MARK: - Tool block

private struct AnalyseToolBlock: View {
    let tool: AnalyseTool
    let isCollapsed: Bool
    @Binding var draggingTool: AnalyseTool?
    let engine: AnalysisEngine
    let viewModel: ImageViewModel
    let onToggleCollapse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                Text(tool.rawValue)
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
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .contentShape(Rectangle())
            .onTapGesture { onToggleCollapse() }
            .onDrag {
                DispatchQueue.main.async { draggingTool = tool }
                return NSItemProvider(object: tool.rawValue as NSString)
            }

            if !isCollapsed {
                toolContent
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var toolContent: some View {
        switch tool {
        case .histogram:
            HistogramView(engine: engine)
        case .waveform:
            WaveformView(engine: engine, isParade: false)
        case .parade:
            WaveformView(engine: engine, isParade: true)
        case .curves:
            CurvesView().environmentObject(viewModel)
        }
    }
}

// MARK: - Drop delegate

private struct ToolDropDelegate: DropDelegate {
    let target: AnalyseTool
    @Binding var order: [AnalyseTool]
    @Binding var dragging: AnalyseTool?

    func dropEntered(info: DropInfo) {
        guard let src = dragging, src != target,
              let from = order.firstIndex(of: src),
              let to   = order.firstIndex(of: target) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            order.move(fromOffsets: IndexSet(integer: from),
                       toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool { dragging = nil; return true }
}
