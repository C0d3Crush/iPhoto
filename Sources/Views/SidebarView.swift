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
                            .frame(width: 156)
                            .contentShape(Rectangle())
                            .onAppear { viewModel.requestVisibleThumbnail(at: actualIndex) }
                            .onTapGesture { viewModel.selectDocument(at: actualIndex) }
                            .contextMenu { albumContextMenu(for: doc) }
                            .onDrag { NSItemProvider(object: doc.url as NSURL) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .onChange(of: viewModel.collection.currentIndex) { newIndex in
                // Kein withAnimation: animiertes scrollTo crasht auf macOS 11 in
                // HostingScrollView.checkAnimationCompletion (EXC_BAD_ACCESS)
                proxy.scrollTo(newIndex, anchor: .center)
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
