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
                                .frame(width: 156)
                                .contentShape(Rectangle())
                                .onAppear { viewModel.requestVisibleThumbnail(at: actualIndex) }
                                .onTapGesture { handleTap(at: actualIndex) }
                                .contextMenu { ThumbnailContextMenu(doc: doc).environmentObject(viewModel) }
                                .onDrag { NSItemProvider(object: doc.url as NSURL) }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .onAppear {
                proxy.scrollTo(viewModel.collection.currentIndex, anchor: .center)
            }
            .onChange(of: viewModel.collection.currentIndex) { newIndex in
                withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
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
}
