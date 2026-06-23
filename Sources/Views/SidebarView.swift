import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.visibleDocuments, id: \.id) { doc in
                        let actualIndex = viewModel.collectionIndex(for: doc) ?? 0
                        let isSelected = viewModel.collection.documents.indices.contains(viewModel.collection.currentIndex)
                            && viewModel.collection.documents[viewModel.collection.currentIndex].id == doc.id
                        ThumbnailCell(document: doc, isSelected: isSelected)
                            .id(actualIndex)
                            .frame(width: 176)
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.selectDocument(at: actualIndex) }
                            .contextMenu { albumContextMenu(for: doc) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .onChange(of: viewModel.collection.currentIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func albumContextMenu(for doc: ImageDocument) -> some View {
        if !viewModel.albums.isEmpty {
            Menu("Zu Album hinzufügen") {
                ForEach(viewModel.albums) { album in
                    Button(album.name) { viewModel.addToAlbum(doc, albumID: album.id) }
                }
            }
            if case .album(let id) = viewModel.navSelection as NavSelection? {
                Button("Aus Album entfernen") { viewModel.removeFromAlbum(doc, albumID: id) }
            }
        }
    }
}
