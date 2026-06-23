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

            VStack(spacing: 0) {
                DetailView()
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                SidebarView()
                    .environmentObject(viewModel)
                    .frame(height: 130)
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
            ExportSheet(
                documents: viewModel.collection.documents,
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

            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    Text("Bild wird geladen…")
                        .foregroundColor(.secondary)
                }
            } else if let image = viewModel.currentImage {
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

            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { viewModel.toggleInspector() }) {
                    Image(systemName: "sidebar.right")
                        .opacity(viewModel.inspectorVisible ? 1.0 : 0.5)
                }
                .help("Inspector ein-/ausblenden")
                .keyboardShortcut("i", modifiers: .command)
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
        }
    }

    private var subtitleText: String {
        guard let img = viewModel.currentImage else { return "" }
        return "\(img.width) × \(img.height)  –  \(Int(viewModel.zoomFactor * 100))%"
    }
}
