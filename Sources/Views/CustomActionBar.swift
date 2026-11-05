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

// MARK: - Bar

struct CustomActionBar: View {
    @EnvironmentObject var viewModel: ImageViewModel

    @AppStorage("toolbar.sort")   private var showSort   = true
    @AppStorage("toolbar.eye")    private var showEye    = true
    @AppStorage("toolbar.rotate") private var showRotate = true
    @AppStorage("toolbar.zoom")   private var showZoom   = true

    @State private var itemOrder: [ActionBarItem] = ActionBarItem.loadOrder()
    @State private var isJiggling: Bool = false
    @State private var jiggleLeft:  Bool = false
    @State private var dragging:    ActionBarItem?

    private let jiggleTick = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    private func isVisible(_ item: ActionBarItem) -> Bool {
        switch item {
        case .sort:                     return showSort
        case .eye:                      return showEye
        case .rotateLeft, .rotateRight: return showRotate
        case .zoomOut, .fitToWindow, .actualSize, .zoomIn: return showZoom
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if isJiggling {
                Button("Fertig") { stopJiggle() }
                    .font(.system(size: 11, weight: .semibold))
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .transition(.opacity)
                Divider().frame(height: 16).padding(.trailing, 4)
            }

            ForEach(itemOrder, id: \.self) { item in
                if isJiggling || isVisible(item) {
                    actionButton(item)
                        .opacity(isJiggling && !isVisible(item) ? 0.4 : 1.0)
                        .modifier(JiggleMod(active: isJiggling, left: jiggleLeft))
                        .onDrag {
                            DispatchQueue.main.async { self.dragging = item }
                            return NSItemProvider(object: item.rawValue as NSString)
                        }
                        .onDrop(of: ["public.text"],
                                delegate: ABDropDelegate(target: item,
                                                         order: $itemOrder,
                                                         dragging: $dragging))
                        .opacity(dragging == item ? 0.35 : 1.0)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 6)
        .frame(height: 30)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
        .onReceive(jiggleTick) { _ in if isJiggling { jiggleLeft.toggle() } }
        .background(
            Button("") { if isJiggling { stopJiggle() } }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0).allowsHitTesting(false)
        )
        .onChange(of: isJiggling) { if !$0 { ActionBarItem.saveOrder(itemOrder) } }
    }

    // MARK: - Individual buttons

    @ViewBuilder
    private func actionButton(_ item: ActionBarItem) -> some View {
        Group {
            switch item {
            case .sort:
                SortMenuButton().environmentObject(viewModel)
                    .fixedSize()
            case .eye:
                Button(action: { viewModel.adj.showOriginal.toggle() }) {
                    Image(systemName: viewModel.adj.showOriginal ? "eye.slash" : "eye")
                }
                .help(item.helpText)
                .disabled(viewModel.currentImage == nil)
            case .rotateLeft:
                Button(action: { viewModel.rotateLeft() }) {
                    Image(systemName: item.icon)
                }
                .help(item.helpText)
                .disabled(viewModel.currentImage == nil)
                .keyboardShortcut("[", modifiers: .command)
            case .rotateRight:
                Button(action: { viewModel.rotateRight() }) {
                    Image(systemName: item.icon)
                }
                .help(item.helpText)
                .disabled(viewModel.currentImage == nil)
                .keyboardShortcut("]", modifiers: .command)
            case .zoomOut:
                Button(action: { viewModel.zoomOut() }) {
                    Image(systemName: item.icon)
                }
                .help(item.helpText)
                .disabled(viewModel.currentImage == nil)
                .keyboardShortcut("-", modifiers: .command)
            case .fitToWindow:
                Button(action: { viewModel.fitToWindow() }) {
                    Image(systemName: item.icon)
                }
                .help(item.helpText)
                .disabled(viewModel.currentImage == nil)
            case .actualSize:
                Button(action: { viewModel.actualSize() }) {
                    Image(systemName: item.icon)
                }
                .help(item.helpText)
                .disabled(viewModel.currentImage == nil)
                .keyboardShortcut("0", modifiers: .command)
            case .zoomIn:
                Button(action: { viewModel.zoomIn() }) {
                    Image(systemName: item.icon)
                }
                .help(item.helpText)
                .disabled(viewModel.currentImage == nil)
                .keyboardShortcut("=", modifiers: .command)
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                if !isJiggling { startJiggle() }
            }
        )
    }

    // MARK: - Jiggle control

    private func startJiggle() {
        isJiggling = true
        jiggleLeft  = false
    }

    private func stopJiggle() {
        withAnimation(.easeOut(duration: 0.15)) { isJiggling = false }
        dragging = nil
    }
}

// MARK: - Jiggle modifier

private struct JiggleMod: ViewModifier {
    let active: Bool
    let left: Bool
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? (left ? -2.5 : 2.5) : 0))
            .animation(active ? .easeInOut(duration: 0.12) : .spring(response: 0.2), value: left)
            .animation(.easeOut(duration: 0.15), value: active)
    }
}

// MARK: - Drop delegate

private struct ABDropDelegate: DropDelegate {
    let target:  ActionBarItem
    @Binding var order:   [ActionBarItem]
    @Binding var dragging: ActionBarItem?

    func dropEntered(info: DropInfo) {
        guard let src = dragging, src != target,
              let from = order.firstIndex(of: src),
              let to   = order.firstIndex(of: target) else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            order.move(fromOffsets: IndexSet(integer: from),
                       toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { dragging = nil; return true }
}
