import SwiftUI
import AppKit

struct AlbumGridExpandedView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.sidebarAlbumExpanded = false
                    }
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Zurück zur normalen Ansicht")

                Text("Alben")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(viewModel.library.albums.count) Alben")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if viewModel.library.albums.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Keine Alben vorhanden")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.library.albums) { album in
                            AlbumGridCell(album: album)
                                .environmentObject(viewModel)
                        }
                    }
                    .padding(16)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct AlbumGridCell: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let album: Album
    @State private var hovered = false

    // First 4 docs from the collection whose URL is in this album
    private var coverDocs: [ImageDocument] {
        let urlSet = Set(album.photoURLs)
        var result: [ImageDocument] = []
        for doc in viewModel.collection.documents {
            if urlSet.contains(doc.url) {
                result.append(doc)
                if result.count == 4 { break }
            }
        }
        return result
    }

    private var coverImages: [NSImage] {
        coverDocs.compactMap { $0.thumbnailImage ?? $0.placeholderThumbnailImage }
    }

    var body: some View {
        Button(action: { selectAlbum() }) {
            VStack(spacing: 6) {
                mosaicView
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(hovered ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .scaleEffect(hovered ? 1.03 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: hovered)

                VStack(spacing: 2) {
                    Text(album.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text("\(album.photoURLs.count) Fotos")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovered = $0 }
        .onAppear { requestThumbnails() }
    }

    @ViewBuilder
    private var mosaicView: some View {
        if coverImages.isEmpty {
            ZStack {
                Color(NSColor.separatorColor).opacity(0.3)
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
            }
        } else if coverImages.count == 1 {
            Image(nsImage: coverImages[0])
                .resizable()
                .scaledToFill()
                .background(Color(NSColor.separatorColor).opacity(0.3))
        } else {
            GeometryReader { geo in
                let half = geo.size.width / 2
                VStack(spacing: 1) {
                    HStack(spacing: 1) {
                        mosaicTile(coverImages[safe: 0], size: half)
                        mosaicTile(coverImages[safe: 1], size: half)
                    }
                    HStack(spacing: 1) {
                        mosaicTile(coverImages[safe: 2], size: half)
                        mosaicTile(coverImages[safe: 3], size: half)
                    }
                }
            }
            .background(Color(NSColor.separatorColor).opacity(0.3))
        }
    }

    private func mosaicTile(_ image: NSImage?, size: CGFloat) -> some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Color(NSColor.separatorColor).opacity(0.2)
                    .frame(width: size, height: size)
            }
        }
    }

    private func selectAlbum() {
        viewModel.navSelection = .album(album.id)
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.sidebarAlbumExpanded = false
        }
    }

    // Trigger the standard thumbnail pipeline for the first 4 album docs.
    // Uses the thread-safe orchestrator path instead of raw CGImageSource calls.
    private func requestThumbnails() {
        for doc in coverDocs {
            if let idx = viewModel.collectionIndex(for: doc) {
                viewModel.requestVisibleThumbnail(at: idx)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
