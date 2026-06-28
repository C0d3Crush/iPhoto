import SwiftUI
import AppKit

struct LibraryFullGridView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private let columns = [GridItem(.adaptive(minimum: 160))]

    var body: some View {
        ZStack {
          Group {
            if viewModel.collection.documents.isEmpty {
                ZStack {
                    Color(NSColor.windowBackgroundColor).ignoresSafeArea()
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
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(viewModel.visibleDocuments, id: \.id) { doc in
                                let idx = viewModel.collectionIndex(for: doc) ?? 0
                                let isSel = viewModel.collection.selectedIndices.contains(idx)
                                ThumbnailCell(document: doc, isSelected: isSel)
                                    .id(idx)
                                    .frame(width: 156)
                                    .contentShape(Rectangle())
                                    .onAppear { viewModel.requestVisibleThumbnail(at: idx) }
                                    .onTapGesture { handleTap(at: idx) }
                                    .contextMenu { contextMenu(for: doc) }
                                    .onDrag { NSItemProvider(object: doc.url as NSURL) }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    .onChange(of: viewModel.collection.currentIndex) { newIndex in
                        withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
                    }
                }
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

    private func handleTap(at index: Int) {
        let flags = viewModel.lastClickModifiers
        if flags.contains(.command) {
            viewModel.toggleSelection(at: index)
        } else if flags.contains(.shift) {
            viewModel.extendSelection(to: index)
        } else {
            viewModel.selectDocument(at: index)
        }
    }

    @ViewBuilder
    private func contextMenu(for doc: ImageDocument) -> some View {
        if !viewModel.albums.isEmpty {
            let multi = viewModel.collection.selectedIndices.count > 1
            Menu(multi ? "Alle (\(viewModel.collection.selectedIndices.count)) zu Album hinzufügen" : "Zu Album hinzufügen") {
                ForEach(viewModel.albums) { album in
                    Button(album.name) {
                        if multi { viewModel.addSelectedToAlbum(albumID: album.id) }
                        else      { viewModel.addToAlbum(doc, albumID: album.id) }
                    }
                }
            }
        }
    }
}
