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
    @State private var coverImage: NSImage? = nil
    @State private var hovered = false

    var body: some View {
        Button(action: { selectAlbum() }) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.separatorColor).opacity(0.3))
                    if let img = coverImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
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
        .onAppear { loadCover() }
    }

    private func selectAlbum() {
        viewModel.navSelection = .album(album.id)
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.sidebarAlbumExpanded = false
        }
    }

    private func loadCover() {
        guard let url = album.photoURLs.first else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                    kCGImageSourceThumbnailMaxPixelSize: 220,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceCreateThumbnailFromImageAlways: true
                  ] as CFDictionary) else { return }
            let img = NSImage(cgImage: cg, size: .zero)
            DispatchQueue.main.async { self.coverImage = img }
        }
    }
}
