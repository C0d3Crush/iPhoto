import SwiftUI

struct LibraryGridView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                if viewModel.visibleDocuments.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Keine Bilder importiert")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.visibleDocuments, id: \.id) { doc in
                            let actualIndex = viewModel.collectionIndex(for: doc) ?? 0
                            let isSelected = viewModel.collection.selectedIndices.contains(actualIndex)
                            ThumbnailCell(document: doc, isSelected: isSelected)
                                .id(actualIndex)
                                .frame(width: 176)
                                .contentShape(Rectangle())
                                .onTapGesture { handleTap(at: actualIndex) }
                                .contextMenu { albumContextMenu(for: doc) }
                                .onDrag { NSItemProvider(object: doc.url as NSURL) }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .onChange(of: viewModel.collection.currentIndex) { newIndex in
                withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
            }
        }
    }

    private func handleTap(at index: Int) {
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command {
            viewModel.toggleSelection(at: index)
        } else if flags == .shift {
            viewModel.extendSelection(to: index)
        } else {
            viewModel.selectDocument(at: index)
        }
    }

    @ViewBuilder
    private func albumContextMenu(for doc: ImageDocument) -> some View {
        if !viewModel.albums.isEmpty {
            let multiSelect = viewModel.collection.selectedIndices.count > 1
            Menu(multiSelect ? "Alle (\(viewModel.collection.selectedIndices.count)) zu Album hinzufügen" : "Zu Album hinzufügen") {
                ForEach(viewModel.albums) { album in
                    Button(album.name) {
                        if multiSelect {
                            viewModel.addSelectedToAlbum(albumID: album.id)
                        } else {
                            viewModel.addToAlbum(doc, albumID: album.id)
                        }
                    }
                }
            }
            if case .album(let id) = viewModel.navSelection as NavSelection? {
                Button("Aus Album entfernen") { viewModel.removeFromAlbum(doc, albumID: id) }
            }
        }
    }
}
