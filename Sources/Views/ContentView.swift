import SwiftUI
import AppKit


struct ContentView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    @AppStorage("actionBar.order") private var actionBarOrderRaw: String = ""

    // Per-item visibility
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
            HStack(spacing: 0) {
                if viewModel.sidebarAlbumExpanded {
                    AlbumGridExpandedView()
                        .environmentObject(viewModel)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    if viewModel.navSidebarVisible {
                        NavSidebarView()
                            .environmentObject(viewModel)
                        Divider()
                    }

                    ZStack {
                        mainContent
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if viewModel.inspectorVisible {
                    Divider()
                    InspectorView()
                        .environmentObject(viewModel)
                }
            }

            if viewModel.modeSwitcherEnabled && viewModel.showModeSwitcher {
                ModeSwitcherView()
                    .environmentObject(viewModel)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { viewModel.navSidebarVisible.toggle() }) {
                    Image(systemName: "sidebar.left")
                        .opacity(viewModel.navSidebarVisible ? 1.0 : 0.5)
                }
                .help("Navigation ein-/ausblenden")

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
                if isLibrary && !viewModel.compare.active {
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
                if !isLibrary && !viewModel.compare.active {
                    Button(action: { viewModel.showFullGrid.toggle() }) {
                        Image(systemName: viewModel.showFullGrid ? "rectangle.split.2x1" : "square.grid.3x3")
                            .opacity(viewModel.showFullGrid ? 1.0 : 0.6)
                    }
                    .help(viewModel.showFullGrid ? "Detail-Ansicht" : "Rasteransicht")
                }

                if !viewModel.compare.active {
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

            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { viewModel.toggleInspector() }) {
                    Image(systemName: "sidebar.right")
                        .opacity(viewModel.inspectorVisible ? 1.0 : 0.5)
                }
                .help("Inspector ein-/ausblenden")
                .keyboardShortcut("i", modifiers: .command)
            }
        }
        .onChange(of: viewModel.navSelection) { _ in
            viewModel.showingLibraryDetail = false
            viewModel.qualityDetailActive = false
            if viewModel.compare.active { viewModel.stopCompareMode() }
        }
        .onChange(of: viewModel.windowTitle) { title in
            NSApp.mainWindow?.title = title
        }
        .onAppear {
            NSApp.mainWindow?.title = viewModel.windowTitle
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
        } else if !isLibrary && viewModel.showFullGrid {
            LibraryFullGridView()
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            detailWithStrip
        }
    }

    @ViewBuilder private var detailWithStrip: some View {
        VStack(spacing: 0) {
            DetailView()
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !viewModel.collection.documents.isEmpty {
                Divider()
                LibraryGridView()
                    .environmentObject(viewModel)
                    .frame(height: 138)
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
            } else if let image = viewModel.adj.showOriginal ? viewModel.currentImage
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
