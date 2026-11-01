import SwiftUI
import AppKit

struct AlbumGridExpandedView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Search + toggle row
            HStack(spacing: 0) {
                SearchBarView(query: $viewModel.searchQuery)
                    .environmentObject(viewModel)
                    .frame(maxWidth: .infinity)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.sidebarAlbumExpanded = false
                    }
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 10)
                        .padding(.top, 14)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Alben als Liste anzeigen")
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Bibliothek section — Library as thumbnail cell
                    gridSectionHeader("Bibliothek")
                    let libraryColumns = [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)]
                    LazyVGrid(columns: libraryColumns, spacing: 16) {
                        LibraryGridCell()
                            .environmentObject(viewModel)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 4)

                    let hasAlbumContent = !viewModel.library.albums.isEmpty
                        || !viewModel.library.albumFolders.isEmpty
                        || !viewModel.library.smartFolders.isEmpty

                    if hasAlbumContent {
                        // Album folders
                        if !viewModel.library.albumFolders.isEmpty {
                            gridSectionHeader("Ordner", icon: "folder")
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
                            gridSectionHeader("Alben", icon: "rectangle.stack")
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(viewModel.library.albums) { album in
                                    AlbumGridCell(album: album)
                                        .environmentObject(viewModel)
                                }
                            }
                            .padding(.horizontal, 16).padding(.bottom, 20)
                        }

                        // Smart folders
                        if !viewModel.library.smartFolders.isEmpty {
                            gridSectionHeader("iAlben", icon: "folder.badge.gearshape")
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(viewModel.library.smartFolders) { sf in
                                    SmartFolderGridCell(smartFolder: sf)
                                        .environmentObject(viewModel)
                                }
                            }
                            .padding(.horizontal, 16).padding(.bottom, 20)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("Keine Alben vorhanden")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Section Header / Nav Row helpers

private func gridSectionHeader(_ title: String, icon: String? = nil) -> some View {
    HStack(spacing: 6) {
        if let icon = icon {
            Image(systemName: icon).font(.caption).foregroundColor(.secondary)
        }
        Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
    }
    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
}

// MARK: - Library cell

struct LibraryGridCell: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var hovered = false

    private var isSelected: Bool {
        viewModel.navSelection == .library || viewModel.navSelection == nil
    }

    private var coverDocs: [ImageDocument] {
        Array(viewModel.collection.documents.prefix(4))
    }

    private var coverImages: [NSImage] {
        coverDocs.compactMap { $0.thumbnailImage ?? $0.placeholderThumbnailImage }
    }

    var body: some View {
        Button(action: { viewModel.navSelection = .library }) {
            VStack(spacing: 6) {
                mosaicView
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : (hovered ? Color.accentColor.opacity(0.5) : Color.clear), lineWidth: 2)
                    )
                    .scaleEffect(hovered ? 1.03 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: hovered)

                VStack(spacing: 2) {
                    Text("Library")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    Text("\(viewModel.collection.documents.count) Fotos")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovered = $0 }
        .onAppear {
            for (i, doc) in coverDocs.enumerated() {
                if let idx = viewModel.collectionIndex(for: doc) {
                    viewModel.requestVisibleThumbnail(at: idx)
                } else {
                    viewModel.requestVisibleThumbnail(at: i)
                }
            }
        }
    }

    @ViewBuilder
    private var mosaicView: some View {
        if coverImages.isEmpty {
            ZStack {
                Color(NSColor.separatorColor).opacity(0.3)
                Image(systemName: "photo.stack")
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
}

// MARK: - Folder cell

private struct FolderGridCell: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let folder: AlbumFolder
    @State private var hovered = false

    var body: some View {
        Button(action: {
            viewModel.navSelection = .albumFolder(folder.id)
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
    @State private var showEdit = false

    private var coverDocs: [ImageDocument] {
        var result: [ImageDocument] = []
        for doc in viewModel.collection.documents {
            if viewModel.smartFolderMatches(doc, sf: smartFolder) {
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
        Button(action: {
            viewModel.navSelection = .smartFolder(smartFolder.id)
        }) {
            VStack(spacing: 6) {
                mosaicView
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
        .onAppear { requestThumbnails() }
        .contextMenu {
            Button("iAlbum bearbeiten…") { showEdit = true }
            Divider()
            Button("iAlbum löschen") { viewModel.deleteSmartFolder(smartFolder) }
        }
        .sheet(isPresented: $showEdit) {
            SmartFolderSheet(editing: smartFolder)
                .environmentObject(viewModel)
        }
    }

    @ViewBuilder
    private var mosaicView: some View {
        if coverImages.isEmpty {
            ZStack {
                Color(NSColor.separatorColor).opacity(0.3)
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 28)).foregroundColor(.secondary)
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

    private func requestThumbnails() {
        for doc in coverDocs {
            if let idx = viewModel.collectionIndex(for: doc) {
                viewModel.requestVisibleThumbnail(at: idx)
            }
        }
    }
}

// MARK: - Album cell

private struct AlbumGridCell: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let album: Album
    @State private var hovered = false
    @State private var showDetail = false

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

    // map (not compactMap) preserves index positions — cover photo stays at [0]
    // even if its thumbnail isn't loaded yet; mosaicTile handles nil gracefully.
    private var coverImages: [NSImage?] {
        coverDocs.map { $0.thumbnailImage ?? $0.placeholderThumbnailImage }
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
            Button("Informationen…") { showDetail = true }
            Divider()
            Button("Album löschen") { viewModel.deleteAlbum(album) }
        }
        .sheet(isPresented: $showDetail) {
            AlbumDetailSheet(album: album, isPresented: $showDetail)
                .environmentObject(viewModel)
        }
    }

    @ViewBuilder
    private var mosaicView: some View {
        let hasAny = coverImages.contains(where: { $0 != nil })
        if coverImages.isEmpty || !hasAny {
            ZStack {
                Color(NSColor.separatorColor).opacity(0.3)
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
            }
        } else if coverImages.count == 1 {
            Group {
                if let img = coverImages[0] {
                    Image(nsImage: img).resizable().scaledToFill()
                } else {
                    Color(NSColor.separatorColor).opacity(0.3)
                }
            }
            .background(Color(NSColor.separatorColor).opacity(0.3))
        } else {
            GeometryReader { geo in
                let half = geo.size.width / 2
                VStack(spacing: 1) {
                    HStack(spacing: 1) {
                        mosaicTile(coverImages.count > 0 ? coverImages[0] : nil, size: half)
                        mosaicTile(coverImages.count > 1 ? coverImages[1] : nil, size: half)
                    }
                    HStack(spacing: 1) {
                        mosaicTile(coverImages.count > 2 ? coverImages[2] : nil, size: half)
                        mosaicTile(coverImages.count > 3 ? coverImages[3] : nil, size: half)
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

// MARK: - Album Detail Sheet

struct AlbumDetailSheet: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let album: Album
    @Binding var isPresented: Bool

    private enum Tab: String, CaseIterable {
        case details = "Details"
        case cover   = "Cover"
    }

    @State private var selectedTab: Tab = .details
    @State private var nameText: String
    @State private var descText: String

    init(album: Album, isPresented: Binding<Bool>) {
        self.album = album
        self._isPresented = isPresented
        self._nameText = State(initialValue: album.name)
        self._descText = State(initialValue: album.albumDescription ?? "")
    }

    private var currentAlbum: Album {
        viewModel.library.albums.first(where: { $0.id == album.id }) ?? album
    }

    private var headerImage: NSImage? {
        let a = currentAlbum
        let urlSet = Set(a.photoURLs)
        let docs = viewModel.collection.documents
        if let coverURL = a.coverPhotoURL,
           let doc = docs.first(where: { $0.url == coverURL }) {
            return doc.thumbnailImage ?? doc.placeholderThumbnailImage
        }
        for doc in docs where urlSet.contains(doc.url) {
            if let img = doc.thumbnailImage ?? doc.placeholderThumbnailImage { return img }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    Color(NSColor.separatorColor).opacity(0.3)
                    if let img = headerImage {
                        Image(nsImage: img).resizable().scaledToFill()
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20)).foregroundColor(.secondary)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(nameText.isEmpty ? album.name : nameText)
                        .font(.headline).lineLimit(1)
                    Text("\(album.photoURLs.count) Fotos")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16).padding(.vertical, 8)

            Divider()

            if selectedTab == .details { detailsTab } else { coverTab }

            Divider()

            HStack {
                Button("Abbrechen") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("OK") {
                    let trimmed = nameText.trimmingCharacters(in: .whitespaces)
                    viewModel.updateAlbum(album,
                                         name: trimmed.isEmpty ? album.name : trimmed,
                                         description: descText)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 460, height: 400)
    }

    @ViewBuilder
    private var detailsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Name")
                    .frame(width: 100, alignment: .trailing)
                    .foregroundColor(.secondary).font(.callout)
                TextField("", text: $nameText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            HStack(spacing: 8) {
                Text("Beschreibung")
                    .frame(width: 100, alignment: .trailing)
                    .foregroundColor(.secondary).font(.callout)
                TextField("", text: $descText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            HStack(spacing: 8) {
                Text("Fotos")
                    .frame(width: 100, alignment: .trailing)
                    .foregroundColor(.secondary).font(.callout)
                Text("\(album.photoURLs.count)")
                    .font(.callout)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private let coverColumns = [GridItem(.adaptive(minimum: 80, maximum: 110), spacing: 8)]

    private var candidateDocs: [ImageDocument] {
        let urlSet = Set(currentAlbum.photoURLs)
        var result: [ImageDocument] = []
        for doc in viewModel.collection.documents {
            if urlSet.contains(doc.url) {
                result.append(doc)
                if result.count == 24 { break }
            }
        }
        return result
    }

    @ViewBuilder
    private var coverTab: some View {
        if candidateDocs.isEmpty {
            Text("Keine Fotos im Album")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: coverColumns, spacing: 8) {
                    ForEach(candidateDocs) { doc in
                        CoverPickerTile(doc: doc, isCover: doc.url == currentAlbum.coverPhotoURL) {
                            viewModel.setCoverPhoto(doc.url, forAlbum: album)
                        }
                    }
                }
                .padding(12)
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
