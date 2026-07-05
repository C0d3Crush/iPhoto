import SwiftUI
import AppKit


struct ContentView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        HStack(spacing: 0) {
            if viewModel.navSidebarVisible {
                NavSidebarView()
                    .environmentObject(viewModel)
                Divider()
            }

            ZStack {
                let isLibrary = viewModel.navSelection == .library || viewModel.navSelection == nil
                let showGrid = (isLibrary && !viewModel.showingLibraryDetail) || (!isLibrary && viewModel.showFullGrid)

                if showGrid {
                    // Vollbild-Raster
                    LibraryFullGridView()
                        .environmentObject(viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Detail-Ansicht + Strip
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

                    if viewModel.cropToolActive, let img = viewModel.currentImage {
                        CropEditorView(
                            image: img,
                            initialCrop: viewModel.adjustments.cropRect,
                            initialRotation: viewModel.adjustments.rotation
                        )
                        .environmentObject(viewModel)
                    }
                }

            }

            if viewModel.inspectorVisible {
                Divider()
                InspectorView()
                    .environmentObject(viewModel)
            }
        }
        .onChange(of: viewModel.navSelection) { _ in
            viewModel.showingLibraryDetail = false
        }
        .onChange(of: viewModel.windowTitle) { title in
            NSApp.mainWindow?.title = title
        }
        .onAppear {
            NSApp.mainWindow?.title = viewModel.windowTitle
        }
        .sheet(isPresented: $viewModel.showHDRMergeSheet, onDismiss: {
            viewModel.hdrMergeError = nil
            viewModel.hdrMergeResultURL = nil
        }) {
            HDRMergeSheet(
                isPresented: $viewModel.showHDRMergeSheet,
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
                isPresented: $viewModel.showExportSheet
            )
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
            } else if let image = viewModel.showOriginal ? viewModel.currentImage : (viewModel.adjustedImage ?? viewModel.currentImage) {
                ZoomableScrollView(
                    image: image,
                    zoomFactor: $viewModel.zoomFactor,
                    fitToWindow: $viewModel.fitToWindowRequested
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
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { viewModel.navSidebarVisible.toggle() }) {
                    Image(systemName: "sidebar.left")
                        .opacity(viewModel.navSidebarVisible ? 1.0 : 0.5)
                }
                .help("Navigation ein-/ausblenden")

                if viewModel.showingLibraryDetail {
                    Button(action: { viewModel.showingLibraryDetail = false }) {
                        Image(systemName: "square.grid.3x3")
                    }
                    .help("Zurück zur Bibliothek")
                }

                let isLibrary = viewModel.navSelection == .library || viewModel.navSelection == nil
                if !isLibrary {
                    Button(action: { viewModel.showFullGrid.toggle() }) {
                        Image(systemName: viewModel.showFullGrid ? "rectangle.split.2x1" : "square.grid.3x3")
                            .opacity(viewModel.showFullGrid ? 1.0 : 0.6)
                    }
                    .help(viewModel.showFullGrid ? "Detail-Ansicht" : "Rasteransicht")
                }

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

            ToolbarItemGroup(placement: .automatic) {
                SortMenuButton()
                    .environmentObject(viewModel)

                Button(action: { viewModel.showOriginal.toggle() }) {
                    Image(systemName: viewModel.showOriginal ? "eye.slash" : "eye")
                }
                .help("Original / Anpassungen")
                .disabled(viewModel.currentImage == nil)
            }

            ToolbarItemGroup(placement: .automatic) {
                Button(action: { viewModel.rotateLeft() }) {
                    Image(systemName: "rotate.left")
                }
                .help("90° links drehen (⌘[)")
                .keyboardShortcut("[", modifiers: .command)
                .disabled(viewModel.currentImage == nil)

                Button(action: { viewModel.rotateRight() }) {
                    Image(systemName: "rotate.right")
                }
                .help("90° rechts drehen (⌘])")
                .keyboardShortcut("]", modifiers: .command)
                .disabled(viewModel.currentImage == nil)

                Button(action: { viewModel.zoomOut() }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Verkleinern")
                .keyboardShortcut("-", modifiers: .command)
                .disabled(viewModel.currentImage == nil)

                Button(action: { viewModel.fitToWindow() }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("An Fenster anpassen")
                .disabled(viewModel.currentImage == nil)

                Button(action: { viewModel.actualSize() }) {
                    Image(systemName: "1.magnifyingglass")
                }
                .help("Originalgröße")
                .keyboardShortcut("0", modifiers: .command)
                .disabled(viewModel.currentImage == nil)

                Button(action: { viewModel.zoomIn() }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Vergrößern")
                .keyboardShortcut("=", modifiers: .command)
                .disabled(viewModel.currentImage == nil)
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
    }

    private var subtitleText: String {
        guard let img = viewModel.currentImage else { return "" }
        return "\(img.width) × \(img.height)  –  \(Int(viewModel.zoomFactor * 100))%"
    }
}

struct LoadingBar: View {
    let queue: [ImageViewModel.LoadingTask]
    @State private var showPopover = false

    private var task: ImageViewModel.LoadingTask { queue[0] }
    private var pending: Int { queue.count - 1 }

    var body: some View {
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
                            QueuePopover(queue: queue)
                        }
                    }
                }
                if task.total > 0 {
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
    let queue: [ImageViewModel.LoadingTask]

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
                HStack(spacing: 10) {
                    Image(systemName: t.icon)
                        .font(.system(size: 12))
                        .foregroundColor(i == 0 ? .accentColor : .secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(t.label)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            if i == 0 {
                                Text("Aktiv")
                                    .font(.system(size: 10))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        if t.total > 0 {
                            HStack(spacing: 6) {
                                ProgressView(value: t.progress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                Text("\(t.done)/\(t.total)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                    }
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
