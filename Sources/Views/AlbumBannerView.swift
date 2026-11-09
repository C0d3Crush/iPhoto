import SwiftUI
import AppKit

private struct BannerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 400
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct AlbumBannerView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @State private var showAlbumDetail = false
    @State private var showSmartFolderSheet = false
    @State private var bannerWidth: CGFloat = 400

    var body: some View {
        switch viewModel.navSelection {
        case .album(let id):
            if let album = viewModel.library.albums.first(where: { $0.id == id }) {
                bannerContent(
                    name: album.name,
                    subtitle: "\(album.photoURLs.count) Fotos",
                    description: album.albumDescription,
                    isSmartFolder: false,
                    docs: albumCoverDocs(album),
                    saveTitle: { viewModel.updateAlbum(album, name: $0, description: album.albumDescription) },
                    menu: { AnyView(Group {
                        Button("Informationen…") { showAlbumDetail = true }
                        Divider()
                        Button("Album löschen") { viewModel.deleteAlbum(album) }
                    }) }
                )
                .sheet(isPresented: $showAlbumDetail) {
                    AlbumDetailSheet(album: album, isPresented: $showAlbumDetail)
                        .environmentObject(viewModel)
                }
            }
        case .smartFolder(let id):
            if let sf = viewModel.library.smartFolders.first(where: { $0.id == id }) {
                let count = viewModel.smartFolderCounts[id] ?? 0
                bannerContent(
                    name: sf.name,
                    subtitle: "\(count) Fotos",
                    description: nil,
                    isSmartFolder: true,
                    docs: smartFolderCoverDocs(sf),
                    saveTitle: { newName in
                        var updated = sf; updated.name = newName
                        viewModel.updateSmartFolder(updated)
                    },
                    menu: { AnyView(Group {
                        Button("iAlbum bearbeiten…") { showSmartFolderSheet = true }
                        Divider()
                        Button("iAlbum löschen") { viewModel.deleteSmartFolder(sf) }
                    }) }
                )
                .sheet(isPresented: $showSmartFolderSheet) {
                    SmartFolderSheet(editing: sf).environmentObject(viewModel)
                }
            }
        case .albumFolder(let id):
            if let folder = viewModel.library.albumFolders.first(where: { $0.id == id }) {
                bannerContent(
                    name: folder.name,
                    subtitle: "Ordner",
                    description: nil,
                    isSmartFolder: false,
                    docs: [],
                    saveTitle: { viewModel.renameAlbumFolder(folder, to: $0) },
                    menu: { AnyView(EmptyView()) }
                )
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func bannerContent(name: String, subtitle: String, description: String?,
                               isSmartFolder: Bool, docs: [ImageDocument],
                               saveTitle: @escaping (String) -> Void,
                               menu: @escaping () -> AnyView) -> some View {
        let compact = bannerWidth < 320
        let thumbSize: CGFloat = compact ? 80 : 110
        Group {
            if compact {
                VStack(alignment: .center, spacing: 8) {
                    mosaicView(docs: docs, isSmartFolder: isSmartFolder)
                        .frame(width: thumbSize, height: thumbSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    bannerTextBlock(name: name, subtitle: subtitle, description: description,
                                    saveTitle: saveTitle, menu: menu, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            } else {
                HStack(spacing: 20) {
                    mosaicView(docs: docs, isSmartFolder: isSmartFolder)
                        .frame(width: thumbSize, height: thumbSize)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                    bannerTextBlock(name: name, subtitle: subtitle, description: description,
                                    saveTitle: saveTitle, menu: menu, alignment: .leading)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { geo in
                Color(NSColor.windowBackgroundColor)
                    .preference(key: BannerWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(BannerWidthKey.self) { bannerWidth = $0 }
        .onAppear {
            isEditingTitle = false
            for doc in docs {
                if let idx = viewModel.collectionIndex(for: doc) {
                    viewModel.requestVisibleThumbnail(at: idx)
                }
            }
        }
    }

    @ViewBuilder
    private func bannerTextBlock(name: String, subtitle: String, description: String?,
                                 saveTitle: @escaping (String) -> Void,
                                 menu: @escaping () -> AnyView,
                                 alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 6) {
                if alignment == .center { Spacer() }
                if isEditingTitle {
                    TextField("", text: $titleDraft, onCommit: {
                        let t = titleDraft.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { saveTitle(t) }
                        isEditingTitle = false
                    })
                    .font(.system(size: alignment == .center ? 14 : 22, weight: .bold))
                    .textFieldStyle(PlainTextFieldStyle())
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .onExitCommand { isEditingTitle = false }
                } else {
                    Text(name)
                        .font(.system(size: alignment == .center ? 14 : 22, weight: .bold))
                        .lineLimit(2)
                        .multilineTextAlignment(alignment == .center ? .center : .leading)
                        .onTapGesture {
                            titleDraft = name
                            isEditingTitle = true
                        }
                }
                Menu {
                    menu()
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: alignment == .center ? 12 : 15))
                        .foregroundColor(.secondary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .fixedSize()
                if alignment == .center { Spacer() }
            }
            Text(subtitle)
                .font(alignment == .center ? .caption : .callout)
                .foregroundColor(.secondary)
            if let desc = description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .lineLimit(2)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
            }
        }
    }

    @ViewBuilder
    private func mosaicView(docs: [ImageDocument], isSmartFolder: Bool) -> some View {
        let images = docs.compactMap { $0.thumbnailImage ?? $0.placeholderThumbnailImage }
        if images.isEmpty {
            ZStack {
                Color(NSColor.separatorColor).opacity(0.3)
                Image(systemName: isSmartFolder ? "folder.badge.gearshape" : "photo.on.rectangle")
                    .font(.system(size: 32)).foregroundColor(.secondary)
            }
        } else if images.count == 1 {
            GeometryReader { geo in
                Image(nsImage: images[0]).resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
            }
            .background(Color(NSColor.separatorColor).opacity(0.3))
        } else {
            GeometryReader { geo in
                let half = geo.size.width / 2
                VStack(spacing: 1) {
                    HStack(spacing: 1) {
                        bannerTile(images[safe: 0], size: half)
                        bannerTile(images[safe: 1], size: half)
                    }
                    HStack(spacing: 1) {
                        bannerTile(images[safe: 2], size: half)
                        bannerTile(images[safe: 3], size: half)
                    }
                }
            }
            .background(Color(NSColor.separatorColor).opacity(0.3))
        }
    }

    private func bannerTile(_ image: NSImage?, size: CGFloat) -> some View {
        Group {
            if let img = image {
                Image(nsImage: img).resizable().scaledToFill()
                    .frame(width: size, height: size).clipped()
            } else {
                Color(NSColor.separatorColor).opacity(0.2).frame(width: size, height: size)
            }
        }
    }

    private func albumCoverDocs(_ album: Album) -> [ImageDocument] {
        // Wenn ein Cover explizit gesetzt wurde, nur dieses eine Bild zeigen.
        if let coverURL = album.coverPhotoURL,
           let doc = viewModel.collection.documents.first(where: { $0.url == coverURL }) {
            return [doc]
        }
        let urlSet = Set(album.photoURLs)
        var pool: [ImageDocument] = []
        for doc in viewModel.collection.documents {
            if urlSet.contains(doc.url) { pool.append(doc) }
            if pool.count == 4 { break }
        }
        return pool
    }

    private func smartFolderCoverDocs(_ sf: SmartFolder) -> [ImageDocument] {
        var result: [ImageDocument] = []
        for doc in viewModel.collection.documents {
            if viewModel.smartFolderMatches(doc, sf: sf) {
                result.append(doc)
                if result.count == 4 { break }
            }
        }
        return result
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
