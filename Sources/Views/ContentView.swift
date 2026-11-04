import SwiftUI
import AppKit


struct ContentView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    @AppStorage("actionBar.order")       private var actionBarOrderRaw: String = ""
    @AppStorage("albumPanel.width")      private var albumPanelWidthStored: Double = 320
    // Live width drives the frame; AppStorage is only written on drag end to avoid UserDefaults latency.
    @State private var albumPanelLive: CGFloat = 320

    @AppStorage("gallery.stripHeight")   private var stripHeightStored: Double = 138
    @State private var stripHeightLive: CGFloat = 138

    // Nav toolbar visibility
    @AppStorage("navtoolbar.showSidebar")    private var navShowSidebar    = true
    @AppStorage("navtoolbar.showViewMode")   private var navShowViewMode   = true
    @AppStorage("navtoolbar.showNavigation") private var navShowNavigation = true
    @AppStorage("navtoolbar.showInspector")  private var navShowInspector  = true

    // Per-item action bar visibility
    @AppStorage("toolbar.item.sort")        private var showSort        = true
    @AppStorage("toolbar.item.eye")         private var showEye         = true
    @AppStorage("toolbar.item.rotateLeft")  private var showRotateLeft  = true
    @AppStorage("toolbar.item.rotateRight") private var showRotateRight = true
    @AppStorage("toolbar.item.zoomOut")     private var showZoomOut     = true
    @AppStorage("toolbar.item.fitToWindow") private var showFitToWindow = true
    @AppStorage("toolbar.item.actualSize")  private var showActualSize  = true
    @AppStorage("toolbar.item.zoomIn")      private var showZoomIn      = true

    private var toolbarOrder: [ActionBarItem] {
        if actionBarOrderRaw.isEmpty { return ActionBarItem.allCases }
        let saved = actionBarOrderRaw.split(separator: ",")
            .compactMap { ActionBarItem(rawValue: String($0)) }
        let missing = ActionBarItem.allCases.filter { !saved.contains($0) }
        return saved.isEmpty ? ActionBarItem.allCases : saved + missing
    }

    private func toolbarItemVisible(_ item: ActionBarItem) -> Bool {
        switch item {
        case .sort:        return showSort
        case .eye:         return showEye
        case .rotateLeft:  return showRotateLeft
        case .rotateRight: return showRotateRight
        case .zoomOut:     return showZoomOut
        case .fitToWindow: return showFitToWindow
        case .actualSize:  return showActualSize
        case .zoomIn:      return showZoomIn
        }
    }

    var body: some View {
        ZStack {
            layoutArea
            if viewModel.modeSwitcherEnabled && viewModel.showModeSwitcher {
                ModeSwitcherView()
                    .environmentObject(viewModel)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                PanelToggleGroup(
                    showSidebar: navShowSidebar,
                    showInspector: navShowInspector,
                    sidebarActive: viewModel.navSidebarVisible,
                    inspectorActive: viewModel.inspectorVisible,
                    onToggleSidebar: { viewModel.navSidebarVisible.toggle() },
                    onToggleInspector: { viewModel.toggleInspector() }
                )

                if viewModel.modeSwitcherEnabled {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            viewModel.showModeSwitcher.toggle()
                        }
                    }) {
                        Image(systemName: "square.grid.2x2")
                            .opacity(viewModel.showModeSwitcher ? 1.0 : 0.6)
                    }
                    .help("Ansicht wählen (⌘M)")
                    .keyboardShortcut("m", modifiers: .command)
                }

                if viewModel.showingLibraryDetail {
                    Button(action: { viewModel.showingLibraryDetail = false }) {
                        Image(systemName: "square.grid.3x3")
                    }
                    .help("Zurück zur Bibliothek")
                }

                if viewModel.qualityDetailActive {
                    Button(action: { viewModel.qualityDetailActive = false }) {
                        Image(systemName: "square.grid.3x3")
                    }
                    .help("Zurück zur Übersicht")
                }

                let isLibrary = viewModel.navSelection == .library || viewModel.navSelection == nil
                let showModePicker = !viewModel.compare.active
                    && (isLibrary ? navShowViewMode : true)
                if showModePicker {
                    Menu {
                        ForEach(LibraryViewMode.allCases, id: \.self) { mode in
                            Button(action: { viewModel.libraryViewMode = mode }) {
                                Label(
                                    mode.displayName,
                                    systemImage: viewModel.libraryViewMode == mode ? "checkmark" : mode.icon
                                )
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.libraryViewMode.icon)
                    }
                    .help("Ansicht wählen")
                    .menuStyle(BorderlessButtonMenuStyle())
                    .fixedSize()
                }

                if !viewModel.compare.active && navShowNavigation {
                    Button(action: { viewModel.previous() }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!viewModel.collection.hasPrevious)
                    .help("Vorheriges Bild")

                    Button(action: { viewModel.next() }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!viewModel.collection.hasNext)
                    .help("Nächstes Bild")
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                if !viewModel.compare.active {
                    ForEach(toolbarOrder.filter { toolbarItemVisible($0) }, id: \.self) { item in
                        toolbarButton(for: item)
                    }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) { EmptyView() }
        }
        .onChange(of: viewModel.navSelection) { sel in
            viewModel.showingLibraryDetail = false
            viewModel.qualityDetailActive = false
            if viewModel.compare.active { viewModel.stopCompareMode() }
            if case .album = sel {} else { viewModel.sidebarSelectedAlbumIDs = []; viewModel.sidebarAnchorAlbumID = nil }
            if case .smartFolder = sel {} else { viewModel.sidebarSelectedSmartFolderIDs = []; viewModel.sidebarAnchorSmartFolderID = nil }
        }
        .onChange(of: viewModel.windowTitle) { title in
            NSApp.mainWindow?.title = title
        }
        .onAppear {
            NSApp.mainWindow?.title = viewModel.windowTitle
            albumPanelLive = CGFloat(albumPanelWidthStored)
            stripHeightLive = CGFloat(stripHeightStored)
        }
        .sheet(isPresented: $viewModel.hdr.showSheet, onDismiss: {
            viewModel.hdr.error = nil
            viewModel.hdr.resultURL = nil
        }) {
            HDRMergeSheet(
                isPresented: $viewModel.hdr.showSheet,
                docs: viewModel.selectedDocsForHDR
            )
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showExportSheet) {
            let selectedDocs = viewModel.collection.selectedIndices
                .sorted()
                .compactMap { idx -> ImageDocument? in
                    guard idx < viewModel.collection.documents.count else { return nil }
                    return viewModel.collection.documents[idx]
                }
            ExportSheet(
                documents: viewModel.collection.documents,
                selectedDocuments: selectedDocs,
                currentDocument: viewModel.collection.currentDocument,
                currentAdjustments: viewModel.hasActiveAdjustments ? viewModel.adj.adjustments : nil,
                isPresented: $viewModel.showExportSheet
            )
        }
    }

    @ViewBuilder
    private func toolbarButton(for item: ActionBarItem) -> some View {
        switch item {
        case .sort:
            SortMenuButton().environmentObject(viewModel).fixedSize()
        case .eye:
            Button(action: { viewModel.adj.showOriginal.toggle() }) {
                Image(systemName: viewModel.adj.showOriginal ? "eye.slash" : "eye")
            }
            .help(item.helpText)
            .disabled(viewModel.currentImage == nil)
        case .rotateLeft:
            Button(action: { viewModel.rotateLeft() }) { Image(systemName: item.icon) }
                .help(item.helpText).disabled(viewModel.currentImage == nil)
                .keyboardShortcut("[", modifiers: .command)
        case .rotateRight:
            Button(action: { viewModel.rotateRight() }) { Image(systemName: item.icon) }
                .help(item.helpText).disabled(viewModel.currentImage == nil)
                .keyboardShortcut("]", modifiers: .command)
        case .zoomOut:
            Button(action: { viewModel.zoomOut() }) { Image(systemName: item.icon) }
                .help(item.helpText).disabled(viewModel.currentImage == nil)
                .keyboardShortcut("-", modifiers: .command)
        case .fitToWindow:
            Button(action: { viewModel.fitToWindow() }) { Image(systemName: item.icon) }
                .help(item.helpText).disabled(viewModel.currentImage == nil)
        case .actualSize:
            Button(action: { viewModel.actualSize() }) { Image(systemName: item.icon) }
                .help(item.helpText).disabled(viewModel.currentImage == nil)
                .keyboardShortcut("0", modifiers: .command)
        case .zoomIn:
            Button(action: { viewModel.zoomIn() }) { Image(systemName: item.icon) }
                .help(item.helpText).disabled(viewModel.currentImage == nil)
                .keyboardShortcut("=", modifiers: .command)
        }
    }

    // Minimum album-panel width; below the snap threshold we close the expanded view.
    private let albumPanelMin: CGFloat = 200
    private let albumPanelSnapClose: CGFloat = 160

    @ViewBuilder private var layoutArea: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if viewModel.navSidebarVisible {
                    let maxW = max(albumPanelMin, geo.size.width - 120)
                    let panelW = max(albumPanelMin, min(albumPanelLive, maxW))

                    Group {
                        if viewModel.sidebarAlbumExpanded {
                            AlbumGridExpandedView()
                                .environmentObject(viewModel)
                        } else {
                            NavSidebarView()
                                .environmentObject(viewModel)
                        }
                    }
                    .frame(width: panelW)
                    .frame(maxHeight: .infinity)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    AlbumPanelDivider(
                        currentWidth: panelW,
                        minWidth: albumPanelMin,
                        maxWidth: maxW,
                        snapClose: albumPanelSnapClose,
                        onDrag: { delta in
                            albumPanelLive = max(albumPanelMin, min(albumPanelLive + delta, maxW))
                        },
                        onRelease: { finalW in
                            albumPanelWidthStored = Double(albumPanelLive)
                        }
                    )
                }

                ZStack { mainContent }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewModel.inspectorVisible {
                    Divider()
                    InspectorView()
                        .environmentObject(viewModel)
                }
            }
        }
    }

    @ViewBuilder private var mainContent: some View {
        let isLibrary = viewModel.navSelection == .library || viewModel.navSelection == nil
        let inQualityOverview = !viewModel.qualityDetailActive
            && (viewModel.navSelection == .blurry
                || viewModel.navSelection == .underexposed
                || viewModel.navSelection == .overexposed
                || viewModel.navSelection == .closedEyes)

        if viewModel.compare.active {
            CompareView()
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.navSelection == .trash {
            VStack(spacing: 0) {
                if viewModel.showFullGrid {
                    LibraryFullGridView()
                        .environmentObject(viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    detailWithStrip
                }
                TrashSizeBar()
                    .environmentObject(viewModel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.navSelection == .duplicates {
            DuplicatesView()
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.navSelection == .similar {
            SimilarView()
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if inQualityOverview && viewModel.navSelection == .blurry {
            BlurryView()
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if inQualityOverview && viewModel.navSelection == .closedEyes {
            ClosedEyesView()
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if inQualityOverview {
            ExposureView()
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLibrary && !viewModel.showingLibraryDetail {
            switch viewModel.libraryViewMode {
            case .grid:
                LibraryFullGridView()
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .list:
                LibraryListView()
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .columns:
                LibraryColumnsView()
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .gallery:
                detailWithStrip
            }
        } else if !isLibrary {
            switch viewModel.libraryViewMode {
            case .gallery:
                detailWithStrip
            case .grid:
                LibraryFullGridView()
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .list:
                LibraryListView()
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .columns:
                LibraryColumnsView()
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private let stripMin: CGFloat = 138
    private let stripMax: CGFloat = 600

    @ViewBuilder private var detailWithStrip: some View {
        VStack(spacing: 0) {
            DetailView()
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !viewModel.collection.documents.isEmpty {
                StripDivider(
                    onDrag: { delta in
                        stripHeightLive = max(stripMin, min(stripHeightLive + delta, stripMax))
                    },
                    onRelease: {
                        stripHeightStored = Double(stripHeightLive)
                    }
                )
                LibraryGridView()
                    .environmentObject(viewModel)
                    .frame(height: stripHeightLive)
            }
        }

        if viewModel.adj.cropToolActive, let img = viewModel.currentImage {
            CropEditorView(
                image: img,
                initialCrop: viewModel.adj.adjustments.cropRect,
                initialRotation: viewModel.adj.adjustments.rotation
            )
            .environmentObject(viewModel)
        }
    }
}

struct DetailView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            if viewModel.tetherMode {
                TetherInlineView()
                    .environmentObject(viewModel)
            } else if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    Text("Bild wird geladen…")
                        .foregroundColor(.secondary)
                }
            } else if !viewModel.visibleDocuments.isEmpty,
                      let image = viewModel.adj.showOriginal ? viewModel.currentImage
                        : (viewModel.inpaint.resultImage
                           ?? viewModel.adj.adjustedImage
                           ?? viewModel.currentImage) {
                ZoomableScrollView(
                    image: image,
                    zoomFactor: $viewModel.zoomFactor,
                    fitToWindow: $viewModel.fitToWindowRequested,
                    maskModeEnabled: viewModel.inpaint.isMaskingMode,
                    brushRadius: viewModel.inpaint.brushRadius,
                    onMaskUpdate: { bmp in viewModel.inpaint.pendingMaskBitmap = bmp }
                )

            } else if let err = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(err)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Bilder hier ablegen")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("oder ⌘O zum Öffnen")
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
            }

            DropTargetView()
                .environmentObject(viewModel)
        }
    }
}

struct LoadingBar: View {
    @ObservedObject var activity: BackgroundActivityState
    @State private var showPopover = false

    private var queue: [BackgroundActivityState.LoadingTask] { activity.loadingQueue }

    // Die Sidebar prüft loadingQueue.isEmpty, aber LoadingBar beobachtet activity selbst:
    // leert dequeue() die Queue, rendert SwiftUI diesen Body noch einmal, bevor die
    // Sidebar die View entfernt — queue[0] würde dann trappen (SIGILL, Bug #34).
    @ViewBuilder var body: some View {
        if let task = queue.first {
            bar(task: task, pending: queue.count - 1,
                taskPaused: activity.pausedTasks.contains(task.id))
        }
    }

    private func bar(task: BackgroundActivityState.LoadingTask,
                     pending: Int, taskPaused: Bool) -> some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: task.icon)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(task.label)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if task.total > 0 {
                        Text("\(task.done) / \(task.total)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Button {
                        activity.togglePause(id: task.id)
                    } label: {
                        Image(systemName: taskPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .padding(3)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(taskPaused ? "Fortsetzen" : "Pausieren")
                    if pending > 0 {
                        Button {
                            showPopover.toggle()
                        } label: {
                            Text("+\(pending)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                            QueuePopover(activity: activity)
                        }
                    }
                }
                if taskPaused {
                    ProgressView(value: task.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity)
                        .opacity(0.4)
                } else if task.total > 0 {
                    ProgressView(value: task.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity)
                } else {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: task.progress)
    }
}

struct QueuePopover: View {
    @ObservedObject var activity: BackgroundActivityState

    private var queue: [BackgroundActivityState.LoadingTask] { activity.loadingQueue }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ausstehende Aufgaben")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            ForEach(Array(queue.enumerated()), id: \.element.id) { i, t in
                let paused = activity.pausedTasks.contains(t.id)
                HStack(spacing: 10) {
                    Image(systemName: t.icon)
                        .font(.system(size: 12))
                        .foregroundColor(paused ? .secondary : (i == 0 ? .accentColor : .secondary))
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(t.label)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            if paused {
                                Text("Pausiert")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            } else if i == 0 {
                                Text("Aktiv")
                                    .font(.system(size: 10))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        if t.total > 0 {
                            HStack(spacing: 6) {
                                ProgressView(value: t.progress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .opacity(paused ? 0.4 : 1)
                                Text("\(t.done)/\(t.total)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(LinearProgressViewStyle())
                                .opacity(paused ? 0.4 : 1)
                        }
                    }
                    Button {
                        activity.togglePause(id: t.id)
                    } label: {
                        Image(systemName: paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(4)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(paused ? "Fortsetzen" : "Pausieren")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                if i < queue.count - 1 {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .padding(.bottom, 10)
        .frame(minWidth: 280)
    }
}

// MARK: - Panel toggle group (Xcode-style)

private struct PanelToggleGroup: View {
    let showSidebar: Bool
    let showInspector: Bool
    let sidebarActive: Bool
    let inspectorActive: Bool
    let onToggleSidebar: () -> Void
    let onToggleInspector: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                panelButton(icon: "sidebar.left", active: sidebarActive, isFirst: true,
                            isLast: !showInspector, action: onToggleSidebar)
                    .help("Navigation ein-/ausblenden")
            }
            if showInspector {
                panelButton(icon: "sidebar.right", active: inspectorActive,
                            isFirst: !showSidebar, isLast: true, action: onToggleInspector)
                    .help("Inspector ein-/ausblenden")
                    .keyboardShortcut("i", modifiers: .command)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlColor))
                .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }

    private func panelButton(icon: String, active: Bool,
                              isFirst: Bool, isLast: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: active ? .medium : .regular))
                .foregroundColor(active ? Color.primary : Color.secondary)
                .frame(width: 28, height: 22)
                .background(
                    active
                        ? RoundedRectangle(cornerRadius: isFirst && isLast ? 6 : (isFirst ? 6 : (isLast ? 6 : 0)))
                            .fill(Color(NSColor.selectedControlColor).opacity(0.35))
                        : nil
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Resizable gallery strip divider

private struct StripDivider: View {
    let onDrag: (CGFloat) -> Void
    let onRelease: () -> Void

    @State private var hovered = false
    @State private var dragStart: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(hovered
                  ? Color.accentColor.opacity(0.6)
                  : Color(NSColor.separatorColor))
            .frame(height: 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { v in
                        let delta = v.translation.height - dragStart
                        dragStart = v.translation.height
                        onDrag(delta)
                    }
                    .onEnded { _ in
                        dragStart = 0
                        onRelease()
                    }
            )
            .cursor(.resizeUpDown)
    }
}

// MARK: - Resizable album-panel divider

private struct AlbumPanelDivider: View {
    let currentWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let snapClose: CGFloat
    let onDrag: (CGFloat) -> Void
    let onRelease: (CGFloat) -> Void

    @State private var hovered = false
    @State private var dragStart: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(hovered
                  ? Color.accentColor.opacity(0.6)
                  : Color(NSColor.separatorColor))
            .frame(width: 4)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { v in
                        let delta = v.translation.width - dragStart
                        dragStart = v.translation.width
                        onDrag(delta)
                    }
                    .onEnded { _ in
                        dragStart = 0
                        onRelease(currentWidth)
                    }
            )
            .cursor(.resizeLeftRight)
    }
}

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Album Banner

private struct BannerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 400
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct AlbumBannerView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @State private var showAlbumDetail = false
    @State private var showSmartFolderSheet = false
    @State private var bannerWidth: CGFloat = 400

    var body: some View {
        switch viewModel.navSelection {
        case .album(let id):
            if let album = viewModel.library.albums.first(where: { $0.id == id }) {
                bannerContent(
                    name: album.name,
                    subtitle: "\(album.photoURLs.count) Fotos",
                    description: album.albumDescription,
                    isSmartFolder: false,
                    docs: albumCoverDocs(album),
                    saveTitle: { viewModel.updateAlbum(album, name: $0, description: album.albumDescription) },
                    menu: { AnyView(Group {
                        Button("Informationen…") { showAlbumDetail = true }
                        Divider()
                        Button("Album löschen") { viewModel.deleteAlbum(album) }
                    }) }
                )
                .sheet(isPresented: $showAlbumDetail) {
                    AlbumDetailSheet(album: album, isPresented: $showAlbumDetail)
                        .environmentObject(viewModel)
                }
            }
        case .smartFolder(let id):
            if let sf = viewModel.library.smartFolders.first(where: { $0.id == id }) {
                let count = viewModel.smartFolderCounts[id] ?? 0
                bannerContent(
                    name: sf.name,
                    subtitle: "\(count) Fotos",
                    description: nil,
                    isSmartFolder: true,
                    docs: smartFolderCoverDocs(sf),
                    saveTitle: { newName in
                        var updated = sf; updated.name = newName
                        viewModel.updateSmartFolder(updated)
                    },
                    menu: { AnyView(Group {
                        Button("iAlbum bearbeiten…") { showSmartFolderSheet = true }
                        Divider()
                        Button("iAlbum löschen") { viewModel.deleteSmartFolder(sf) }
                    }) }
                )
                .sheet(isPresented: $showSmartFolderSheet) {
                    SmartFolderSheet(editing: sf).environmentObject(viewModel)
                }
            }
        case .albumFolder(let id):
            if let folder = viewModel.library.albumFolders.first(where: { $0.id == id }) {
                bannerContent(
                    name: folder.name,
                    subtitle: "Ordner",
                    description: nil,
                    isSmartFolder: false,
                    docs: [],
                    saveTitle: { viewModel.renameAlbumFolder(folder, to: $0) },
                    menu: { AnyView(EmptyView()) }
                )
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func bannerContent(name: String, subtitle: String, description: String?,
                               isSmartFolder: Bool, docs: [ImageDocument],
                               saveTitle: @escaping (String) -> Void,
                               menu: @escaping () -> AnyView) -> some View {
        let compact = bannerWidth < 320
        let thumbSize: CGFloat = compact ? 80 : 110
        Group {
            if compact {
                VStack(alignment: .center, spacing: 8) {
                    mosaicView(docs: docs, isSmartFolder: isSmartFolder)
                        .frame(width: thumbSize, height: thumbSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    bannerTextBlock(name: name, subtitle: subtitle, description: description,
                                    saveTitle: saveTitle, menu: menu, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            } else {
                HStack(spacing: 20) {
                    mosaicView(docs: docs, isSmartFolder: isSmartFolder)
                        .frame(width: thumbSize, height: thumbSize)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                    bannerTextBlock(name: name, subtitle: subtitle, description: description,
                                    saveTitle: saveTitle, menu: menu, alignment: .leading)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { geo in
                Color(NSColor.windowBackgroundColor)
                    .preference(key: BannerWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(BannerWidthKey.self) { bannerWidth = $0 }
        .onAppear {
            isEditingTitle = false
            for doc in docs {
                if let idx = viewModel.collectionIndex(for: doc) {
                    viewModel.requestVisibleThumbnail(at: idx)
                }
            }
        }
    }

    @ViewBuilder
    private func bannerTextBlock(name: String, subtitle: String, description: String?,
                                 saveTitle: @escaping (String) -> Void,
                                 menu: @escaping () -> AnyView,
                                 alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 6) {
                if alignment == .center { Spacer() }
                if isEditingTitle {
                    TextField("", text: $titleDraft, onCommit: {
                        let t = titleDraft.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { saveTitle(t) }
                        isEditingTitle = false
                    })
                    .font(.system(size: alignment == .center ? 14 : 22, weight: .bold))
                    .textFieldStyle(PlainTextFieldStyle())
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .onExitCommand { isEditingTitle = false }
                } else {
                    Text(name)
                        .font(.system(size: alignment == .center ? 14 : 22, weight: .bold))
                        .lineLimit(2)
                        .multilineTextAlignment(alignment == .center ? .center : .leading)
                        .onTapGesture {
                            titleDraft = name
                            isEditingTitle = true
                        }
                }
                Menu {
                    menu()
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: alignment == .center ? 12 : 15))
                        .foregroundColor(.secondary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .fixedSize()
                if alignment == .center { Spacer() }
            }
            Text(subtitle)
                .font(alignment == .center ? .caption : .callout)
                .foregroundColor(.secondary)
            if let desc = description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .lineLimit(2)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
            }
        }
    }

    @ViewBuilder
    private func mosaicView(docs: [ImageDocument], isSmartFolder: Bool) -> some View {
        let images = docs.compactMap { $0.thumbnailImage ?? $0.placeholderThumbnailImage }
        if images.isEmpty {
            ZStack {
                Color(NSColor.separatorColor).opacity(0.3)
                Image(systemName: isSmartFolder ? "folder.badge.gearshape" : "photo.on.rectangle")
                    .font(.system(size: 32)).foregroundColor(.secondary)
            }
        } else if images.count == 1 {
            GeometryReader { geo in
                Image(nsImage: images[0]).resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
            }
            .background(Color(NSColor.separatorColor).opacity(0.3))
        } else {
            GeometryReader { geo in
                let half = geo.size.width / 2
                VStack(spacing: 1) {
                    HStack(spacing: 1) {
                        bannerTile(images[safe: 0], size: half)
                        bannerTile(images[safe: 1], size: half)
                    }
                    HStack(spacing: 1) {
                        bannerTile(images[safe: 2], size: half)
                        bannerTile(images[safe: 3], size: half)
                    }
                }
            }
            .background(Color(NSColor.separatorColor).opacity(0.3))
        }
    }

    private func bannerTile(_ image: NSImage?, size: CGFloat) -> some View {
        Group {
            if let img = image {
                Image(nsImage: img).resizable().scaledToFill()
                    .frame(width: size, height: size).clipped()
            } else {
                Color(NSColor.separatorColor).opacity(0.2).frame(width: size, height: size)
            }
        }
    }

    private func albumCoverDocs(_ album: Album) -> [ImageDocument] {
        // Wenn ein Cover explizit gesetzt wurde, nur dieses eine Bild zeigen.
        if let coverURL = album.coverPhotoURL,
           let doc = viewModel.collection.documents.first(where: { $0.url == coverURL }) {
            return [doc]
        }
        let urlSet = Set(album.photoURLs)
        var pool: [ImageDocument] = []
        for doc in viewModel.collection.documents {
            if urlSet.contains(doc.url) { pool.append(doc) }
            if pool.count == 4 { break }
        }
        return pool
    }

    private func smartFolderCoverDocs(_ sf: SmartFolder) -> [ImageDocument] {
        var result: [ImageDocument] = []
        for doc in viewModel.collection.documents {
            if viewModel.smartFolderMatches(doc, sf: sf) {
                result.append(doc)
                if result.count == 4 { break }
            }
        }
        return result
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
