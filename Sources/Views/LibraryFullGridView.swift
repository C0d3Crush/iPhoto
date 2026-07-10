import SwiftUI
import AppKit

struct LibraryFullGridView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: viewModel.gridThumbnailSize + 8))]
    }
    private var cellWidth: CGFloat { viewModel.gridThumbnailSize }
    @StateObject private var scroller = AppKitScroller()

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
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(viewModel.visibleDocuments, id: \.id) { doc in
                                let idx = viewModel.collectionIndex(for: doc) ?? 0
                                let isSel = viewModel.collection.selectedIndices.contains(idx)
                                ThumbnailCell(document: doc, isSelected: isSel, thumbnailWidth: cellWidth,
                                              stackCount: viewModel.stackCounts[doc.id] ?? 0,
                                              isStackExpanded: viewModel.isStackExpanded(doc),
                                              isStackMember: viewModel.stackLeaderByMember[doc.id].map { $0 != doc.id } ?? false,
                                              onStackToggle: { viewModel.toggleStack(leader: doc) })
                                    .frame(width: cellWidth + 8)
                                    .contentShape(Rectangle())
                                    .onAppear { viewModel.requestVisibleThumbnail(at: idx) }
                                    .onTapGesture(count: 2) { openDetail(at: idx) }
                                    .onTapGesture { handleTap(at: idx) }
                                    .contextMenu { ThumbnailContextMenu(doc: doc).environmentObject(viewModel) }
                                    .onDrag { NSItemProvider(object: doc.url as NSURL) }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(ScrollViewGrabber(scroller: scroller))
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    .onChange(of: viewModel.collection.currentIndex) { _ in
                        scrollToCurrent()
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
            ToolbarItemGroup(placement: .automatic) {
                SortMenuButton()
                    .environmentObject(viewModel)
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Slider(value: $viewModel.gridThumbnailSize, in: 80...400, step: 10)
                        .frame(width: 120)
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .help("Rastergröße anpassen")
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

    // Kein ScrollViewProxy.scrollTo: hinterlässt auf macOS 11 ein persistentes
    // Scroll-Ziel, das nach Layout-Neuaufbau crasht (Bug #31) — AppKit-Scroll.
    private func scrollToCurrent() {
        guard let cur = viewModel.collection.currentDocument,
              let pos = viewModel.visibleDocuments.firstIndex(where: { $0.id == cur.id }) else { return }
        let count = viewModel.visibleDocuments.count
        let clipWidth = scroller.scrollView?.contentView.bounds.width ?? 0
        let itemWidth = cellWidth + 8
        let colSpacing: CGFloat = 8
        let cols = max(1, Int((clipWidth - 24 + colSpacing) / (itemWidth + colSpacing)))
        scroller.centerRow(position: pos, count: count, columns: cols, verticalPadding: 12)
    }

    private func openDetail(at index: Int) {
        viewModel.selectDocument(at: index)
        let isLibrary = viewModel.navSelection == .library || viewModel.navSelection == nil
        if isLibrary {
            viewModel.showingLibraryDetail = true
        } else {
            viewModel.showFullGrid = false
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

}
