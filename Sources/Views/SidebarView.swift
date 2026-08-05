import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @StateObject private var scroller = AppKitScroller()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            LazyHStack(spacing: 12) {
                ForEach(viewModel.visibleDocuments, id: \.id) { doc in
                    let actualIndex = viewModel.collectionIndex(for: doc) ?? 0
                    let isSelected = viewModel.collection.documents.indices.contains(viewModel.collection.currentIndex)
                        && viewModel.collection.documents[viewModel.collection.currentIndex].id == doc.id
                    let q = viewModel.qualityFlags(for: doc)
                    ThumbnailCell(document: doc, isSelected: isSelected,
                                  isBlurry: q.blur, isUnder: q.under, isOver: q.over)
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
            .background(ScrollViewGrabber(scroller: scroller))
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onChange(of: viewModel.collection.currentIndex) { _ in
            scrollToCurrent()
        }
    }

    // Kein ScrollViewProxy.scrollTo: hinterlässt auf macOS 11 ein persistentes
    // Scroll-Ziel, das nach Layout-Neuaufbau crasht (Bug #31) — AppKit-Scroll.
    private func scrollToCurrent() {
        guard let cur = viewModel.collection.currentDocument,
              let pos = viewModel.visiblePosition(for: cur.id) else { return }
        scroller.centerHorizontally(position: pos, cellWidth: 156, spacing: 12, padding: 8)
    }

    @ViewBuilder
    private func albumContextMenu(for doc: ImageDocument) -> some View {
        if !viewModel.library.albums.isEmpty {
            Menu("Zu Album hinzufügen") {
                ForEach(viewModel.library.albums) { album in
                    Button(album.name) { viewModel.addToAlbum(doc, albumID: album.id) }
                }
            }
            if case .album(let id) = viewModel.navSelection as NavSelection? {
                Button("Aus Album entfernen") { viewModel.removeFromAlbum(doc, albumID: id) }
            }
        }
    }
}
