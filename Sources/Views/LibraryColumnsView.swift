import SwiftUI
import AppKit

struct LibraryColumnsView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        HSplitView {
            // Left: narrow thumbnail column
            ZStack {
                if viewModel.collection.documents.isEmpty {
                    Color(NSColor.controlBackgroundColor)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(viewModel.visibleDocuments, id: \.id) { doc in
                                let actualIndex = viewModel.collectionIndex(for: doc) ?? 0
                                let isSelected = viewModel.collection.selectedIndices.contains(actualIndex)
                                ColumnsThumbnailRow(doc: doc, isSelected: isSelected)
                                    .onTapGesture {
                                        viewModel.selectDocument(at: actualIndex)
                                    }
                                    .contextMenu {
                                        ThumbnailContextMenu(doc: doc)
                                            .environmentObject(viewModel)
                                    }
                                    .onAppear { viewModel.requestVisibleThumbnail(at: actualIndex) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                DropTargetView()
                    .environmentObject(viewModel)
            }
            .frame(minWidth: 160, idealWidth: 200, maxWidth: 280)
            .background(Color(NSColor.controlBackgroundColor))

            // Right: detail
            DetailView()
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ColumnsThumbnailRow: View {
    let doc: ImageDocument
    let isSelected: Bool

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumb = doc.thumbnailImage {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color(NSColor.controlBackgroundColor)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                )
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            thumbnailView
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            VStack(alignment: .leading, spacing: 1) {
                Text(doc.url.lastPathComponent)
                    .font(.system(size: 12))
                    .lineLimit(1)
                if doc.rating > 0 {
                    Text(String(repeating: "★", count: doc.rating))
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                }
            }

            Spacer()

            if doc.flagStatus == .pick {
                Image(systemName: "flag.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
    }
}
