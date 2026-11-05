import SwiftUI

enum PhotoTool: String, CaseIterable, Hashable {
    case move
    case crop
    case zoomIn
    case zoomOut
    case fitToWindow
    case rotateLeft
    case rotateRight
    case inpaint
    case localBrush

    var icon: String {
        switch self {
        case .move:        return "arrow.up.left.and.arrow.down.right"
        case .crop:        return "crop"
        case .zoomIn:      return "plus.magnifyingglass"
        case .zoomOut:     return "minus.magnifyingglass"
        case .fitToWindow: return "aspectratio"
        case .rotateLeft:  return "rotate.left"
        case .rotateRight: return "rotate.right"
        case .inpaint:     return "wand.and.rays"
        case .localBrush:  return "paintbrush"
        }
    }

    var label: String {
        switch self {
        case .move:        return "Auswahl / Bewegen"
        case .crop:        return "Zuschneiden"
        case .zoomIn:      return "Vergrößern"
        case .zoomOut:     return "Verkleinern"
        case .fitToWindow: return "An Fenster anpassen"
        case .rotateLeft:  return "90° links"
        case .rotateRight: return "90° rechts"
        case .inpaint:     return "Inpaint (Retusche)"
        case .localBrush:  return "Lokale Anpassungen"
        }
    }
}

struct ToolboxPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var activeTool: PhotoTool = .move

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            toolGrid(tools: [.move, .crop])
            Divider().padding(.vertical, 4)
            toolGrid(tools: [.zoomIn, .zoomOut, .fitToWindow])
            Divider().padding(.vertical, 4)
            toolGrid(tools: [.rotateLeft, .rotateRight])
            Divider().padding(.vertical, 4)
            toolGrid(tools: [.inpaint, .localBrush])
        }
        .padding(8)
    }

    @ViewBuilder
    private func toolGrid(tools: [PhotoTool]) -> some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(tools, id: \.self) { tool in
                toolButton(tool)
            }
        }
    }

    private func toolButton(_ tool: PhotoTool) -> some View {
        Button(action: { activate(tool) }) {
            VStack(spacing: 3) {
                Image(systemName: tool.icon)
                    .font(.system(size: 18))
                    .frame(height: 22)
                Text(tool.label)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                activeTool == tool
                    ? Color.accentColor.opacity(0.25)
                    : Color(NSColor.controlBackgroundColor)
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(activeTool == tool ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help(tool.label)
        .disabled(viewModel.currentImage == nil && tool != .move)
    }

    private func activate(_ tool: PhotoTool) {
        activeTool = tool
        switch tool {
        case .move:
            if viewModel.adj.cropToolActive { viewModel.adj.cropToolActive = false }
            if viewModel.inpaint.isMaskingMode { viewModel.inpaint.isMaskingMode = false }
        case .crop:
            viewModel.adj.cropToolActive = true
        case .zoomIn:
            viewModel.zoomIn()
            activeTool = .move
        case .zoomOut:
            viewModel.zoomOut()
            activeTool = .move
        case .fitToWindow:
            viewModel.fitToWindow()
            activeTool = .move
        case .rotateLeft:
            viewModel.rotateLeft()
            activeTool = .move
        case .rotateRight:
            viewModel.rotateRight()
            activeTool = .move
        case .inpaint:
            viewModel.inpaint.isMaskingMode = true
        case .localBrush:
            let adj = LocalAdjustment(
                label: "Linearer Verlauf",
                mask: .linearGradient(startX: 0.5, startY: 0.0, endX: 0.5, endY: 0.5)
            )
            viewModel.adj.adjustments.localAdjustments.append(adj)
            activeTool = .move
        }
    }
}
