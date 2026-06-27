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
                VStack(spacing: 0) {
                    DetailView()
                        .environmentObject(viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if let progress = viewModel.thumbnailLoadProgress {
                        ThumbnailLoadBar(progress: progress,
                                         total: viewModel.collection.documents.count)
                    }

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

            if viewModel.inspectorVisible {
                Divider()
                InspectorView()
                    .environmentObject(viewModel)
            }
        }
        .onChange(of: viewModel.windowTitle) { title in
            NSApp.mainWindow?.title = title
        }
        .onAppear {
            NSApp.mainWindow?.title = viewModel.windowTitle
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
                Button(action: { viewModel.showOriginal.toggle() }) {
                    Image(systemName: viewModel.showOriginal ? "eye.slash" : "eye")
                }
                .help("Original / Anpassungen")
                .disabled(viewModel.currentImage == nil)
            }

            ToolbarItemGroup(placement: .automatic) {
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

private struct ThumbnailLoadBar: View {
    let progress: Double
    let total: Int

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(maxWidth: .infinity)
                Text("\(Int(progress * Double(total))) / \(total)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: progress)
    }
}
