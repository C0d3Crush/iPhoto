import SwiftUI

struct LibraryGridView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    var thumbnailWidth: CGFloat = 156

    @StateObject private var scroller = AppKitScroller()

    var body: some View {
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
                            let q = viewModel.qualityFlags(for: doc)
                            ThumbnailCell(document: doc, isSelected: isSelected,
                                          thumbnailWidth: thumbnailWidth,
                                          stackCount: viewModel.stackCounts[doc.id] ?? 0,
                                          isStackExpanded: viewModel.isStackExpanded(doc),
                                          isStackMember: viewModel.stackLeaderByMember[doc.id].map { $0 != doc.id } ?? false,
                                          onStackToggle: { viewModel.toggleStack(leader: doc) },
                                          isBlurry: q.blur, isUnder: q.under, isOver: q.over,
                                          isEyesClosed: q.eyes)
                                .frame(width: thumbnailWidth)
                                .contentShape(Rectangle())
                                .onAppear { viewModel.requestVisibleThumbnail(at: actualIndex) }
                                .onTapGesture { handleTap(at: actualIndex) }
                                .contextMenu { ThumbnailContextMenu(doc: doc).environmentObject(viewModel) }
                                .onDrag { NSItemProvider(object: doc.url as NSURL) }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ScrollViewGrabber(scroller: scroller))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            DispatchQueue.main.async { scrollToCurrent() }
        }
        .onChange(of: viewModel.collection.currentIndex) { _ in
            scrollToCurrent()
        }
    }

    // Kein ScrollViewProxy.scrollTo: hinterlässt auf macOS 11 ein persistentes
    // Scroll-Ziel, das nach Layout-Neuaufbau crasht (Bug #31) — AppKit-Scroll.
    private func scrollToCurrent() {
        guard let cur = viewModel.collection.currentDocument,
              let pos = viewModel.visiblePosition(for: cur.id) else { return }
        scroller.centerHorizontally(position: pos, cellWidth: thumbnailWidth, spacing: 12, padding: 8)
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
}
