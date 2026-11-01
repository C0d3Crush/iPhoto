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

            let hasContent = !viewModel.library.albums.isEmpty
                || !viewModel.library.albumFolders.isEmpty
                || !viewModel.library.smartFolders.isEmpty
            if !hasContent {
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
                    VStack(alignment: .leading, spacing: 0) {
                        // Album folders
                        if !viewModel.library.albumFolders.isEmpty {
                            sectionHeader("Ordner", icon: "folder")
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(viewModel.library.albumFolders) { folder in
                                    FolderGridCell(folder: folder)
                                        .environmentObject(viewModel)
                                }
                            }
                            .padding(.horizontal, 16).padding(.bottom, 20)
                        }

                        // Regular albums
                        if !viewModel.library.albums.isEmpty {
                            sectionHeader("Alben", icon: "rectangle.stack")
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(viewModel.library.albums) { album in
                                    AlbumGridCell(album: album)
                                        .environmentObject(viewModel)
                                }
                            }
                            .padding(.horizontal, 16).padding(.bottom, 20)
                        }

                        // Smart folders / playlists
                        if !viewModel.library.smartFolders.isEmpty {
                            sectionHeader("iAlben", icon: "folder.badge.gearshape")
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(viewModel.library.smartFolders) { sf in
                                    SmartFolderGridCell(smartFolder: sf)
                                        .environmentObject(viewModel)
                                }
                            }
                            .padding(.horizontal, 16).padding(.bottom, 20)
                        }
                    }
                    .padding(.top, 16)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Section Header helper (free func on AlbumGridExpandedView)

private func sectionHeader(_ title: String, icon: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon).font(.caption).foregroundColor(.secondary)
        Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
    }
    .padding(.horizontal, 16).padding(.bottom, 8)
}

// MARK: - Folder cell

private struct FolderGridCell: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let folder: AlbumFolder
    @State private var hovered = false

    var body: some View {
        Button(action: {
            viewModel.navSelection = .albumFolder(folder.id)
            withAnimation(.easeInOut(duration: 0.2)) { viewModel.sidebarAlbumExpanded = false }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Color(NSColor.separatorColor).opacity(0.3)
                    Image(systemName: "folder.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(hovered ? Color.accentColor : Color.clear, lineWidth: 2))
                .scaleEffect(hovered ? 1.03 : 1.0)
                .animation(.easeOut(duration: 0.12), value: hovered)

                Text(folder.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2).multilineTextAlignment(.center)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovered = $0 }
    }
}

// MARK: - Smart folder cell

private struct SmartFolderGridCell: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let smartFolder: SmartFolder
    @State private var hovered = false

    var body: some View {
        Button(action: {
            viewModel.navSelection = .smartFolder(smartFolder.id)
            withAnimation(.easeInOut(duration: 0.2)) { viewModel.sidebarAlbumExpanded = false }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Color(NSColor.separatorColor).opacity(0.3)
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 32)).foregroundColor(.secondary)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(hovered ? Color.accentColor : Color.clear, lineWidth: 2))
                .scaleEffect(hovered ? 1.03 : 1.0)
                .animation(.easeOut(duration: 0.12), value: hovered)

                Text(smartFolder.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2).multilineTextAlignment(.center)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovered = $0 }
    }
}

// MARK: - Album cell

private struct AlbumGridCell: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let album: Album
    @State private var hovered = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showCoverPicker = false

    // First 4 docs from the collection whose URL is in this album.
    // If a coverPhotoURL is set, that doc is placed first.
    private var coverDocs: [ImageDocument] {
        let urlSet = Set(album.photoURLs)
        var pool: [ImageDocument] = []
        for doc in viewModel.collection.documents {
            if urlSet.contains(doc.url) {
                pool.append(doc)
            }
        }
        if let coverURL = album.coverPhotoURL,
           let coverDoc = pool.first(where: { $0.url == coverURL }) {
            var result = [coverDoc]
            for doc in pool where doc.url != coverURL {
                result.append(doc)
                if result.count == 4 { break }
            }
            return result
        }
        return Array(pool.prefix(4))
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
        .contextMenu {
            Button("Album umbenennen") {
                renameText = album.name
                isRenaming = true
            }
            Button("Titelbild festlegen…") {
                showCoverPicker = true
            }
            Divider()
            Button("Album löschen") {
                viewModel.deleteAlbum(album)
            }
        }
        .alert(isPresented: $isRenaming) {
            Alert(
                title: Text("Album umbenennen"),
                message: nil,
                primaryButton: .default(Text("Speichern"), action: {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { viewModel.renameAlbum(album, to: trimmed) }
                }),
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        }
        .sheet(isPresented: $showCoverPicker) {
            CoverPickerSheet(album: album, isPresented: $showCoverPicker)
                .environmentObject(viewModel)
        }
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

// MARK: - Cover Picker Sheet

private struct CoverPickerSheet: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let album: Album
    @Binding var isPresented: Bool

    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 110), spacing: 8)]

    // Up to 20 docs from the album for cover selection
    private var candidateDocs: [ImageDocument] {
        let urlSet = Set(album.photoURLs)
        var result: [ImageDocument] = []
        for doc in viewModel.collection.documents {
            if urlSet.contains(doc.url) {
                result.append(doc)
                if result.count == 20 { break }
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Titelbild festlegen")
                    .font(.headline)
                Spacer()
                Button("Abbrechen") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if candidateDocs.isEmpty {
                Text("Keine Fotos im Album")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(candidateDocs) { doc in
                            CoverPickerTile(doc: doc, isCover: doc.url == album.coverPhotoURL) {
                                viewModel.setCoverPhoto(doc.url, forAlbum: album)
                                isPresented = false
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 400, height: 340)
    }
}

private struct CoverPickerTile: View {
    let doc: ImageDocument
    let isCover: Bool
    let onSelect: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let img = doc.thumbnailImage ?? doc.placeholderThumbnailImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(NSColor.separatorColor).opacity(0.3)
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 90, height: 90)
                .clipped()
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(isCover ? Color.accentColor : (hovered ? Color.accentColor.opacity(0.5) : Color.clear), lineWidth: 2))

                if isCover {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .background(Color.white.clipShape(Circle()))
                        .padding(4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovered = $0 }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
