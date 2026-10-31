import SwiftUI
import AppKit

struct LibraryListView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        ZStack {
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
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.visibleDocuments, id: \.id) { doc in
                            let actualIndex = viewModel.collectionIndex(for: doc) ?? 0
                            let isSelected = viewModel.collection.selectedIndices.contains(actualIndex)
                            LibraryListRow(doc: doc, isSelected: isSelected)
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
                .background(Color(NSColor.windowBackgroundColor))
            }
            DropTargetView()
                .environmentObject(viewModel)
        }
    }
}

private struct LibraryListRow: View {
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
                        .foregroundColor(.secondary)
                )
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            thumbnailView
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.url.lastPathComponent)
                    .font(.system(size: 13))
                    .lineLimit(1)
                if doc.isRAW {
                    Text("RAW")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(3)
                }
            }

            Spacer()

            // Rating
            if doc.rating > 0 {
                Text(String(repeating: "★", count: doc.rating))
                    .font(.caption)
                    .foregroundColor(.yellow)
            }

            // Flag
            if doc.flagStatus == .pick {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if doc.flagStatus == .reject {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Color label
            if doc.colorLabel != .none {
                Circle()
                    .fill(Color(doc.colorLabel.displayColor))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}
