import SwiftUI

// MARK: - Drop delegate for section reordering

struct NavSectionDropDelegate: DropDelegate {
    let target: NavSidebarSection
    @Binding var order: [NavSidebarSection]
    @Binding var dragging: NavSidebarSection?

    func dropEntered(info: DropInfo) {
        guard let src = dragging, src != target,
              let from = order.firstIndex(of: src),
              let to   = order.firstIndex(of: target) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            order.move(fromOffsets: IndexSet(integer: from),
                       toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

// MARK: - AlbumRow

struct AlbumRow: View {
    let album: Album
    let isSelected: Bool
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isTargeted = false

    private var isMultiSelected: Bool {
        viewModel.sidebarSelectedAlbumIDs.contains(album.id)
    }

    var body: some View {
        Button(action: {
            let shift = viewModel.lastClickModifiers.contains(.shift)
            viewModel.sidebarSelectAlbum(album, extending: shift)
        }) {
            HStack(spacing: 4) {
                Label(album.name, systemImage: isTargeted ? "rectangle.stack.fill" : "rectangle.stack")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                if album.photoURLs.count > 0 {
                    Text("\(album.photoURLs.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((isSelected || isMultiSelected) ? Color.accentColor.opacity(0.2) : (isTargeted ? Color.accentColor.opacity(0.1) : Color.clear))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
            providers.first?.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    let selected = viewModel.collection.selectedIndices
                    let docs = viewModel.collection.documents
                    let droppedIsSelected = selected.contains(where: { idx in
                        idx < docs.count && docs[idx].url == url
                    })
                    if droppedIsSelected && selected.count > 1 {
                        viewModel.addSelectedToAlbum(albumID: album.id)
                    } else if let doc = viewModel.collection.documents.first(where: { $0.url == url }) {
                        viewModel.addToAlbum(doc, albumID: album.id)
                    }
                }
            }
            return true
        }
    }
}

struct FolderRow: View {
    let folder: WatchedFolder
    let isSelected: Bool
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isExpanded: Bool = false

    private var resolvedURL: URL? { folder.resolveURL()?.url }

    private var allDocs: [ImageDocument] {
        guard let url = resolvedURL else { return [] }
        let prefix = url.standardized.path
        return viewModel.collection.documents.filter { $0.standardizedPath.hasPrefix(prefix) }
    }

    private var isRemovable: Bool { folder.isRemovableMedia }
    private var isAvailable: Bool { folder.isAvailable }

    private var folderIcon: String {
        if isRemovable { return isAvailable ? "externaldrive.fill" : "externaldrive.badge.exclamationmark" }
        return isExpanded ? "folder.fill" : "folder"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                guard isAvailable || !isRemovable else { return }
                viewModel.navSelection = .folder(folder.id)
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)
                        .opacity(isRemovable && !isAvailable ? 0 : 1)
                    VStack(alignment: .leading, spacing: 1) {
                        Label(folder.name, systemImage: folderIcon)
                            .foregroundColor(isRemovable && !isAvailable ? .secondary : .primary)
                            .lineLimit(1)
                        if isRemovable && !isAvailable {
                            Text("Speichermedium nicht verfügbar")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    let count = allDocs.count
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 4)

            if isExpanded, let rootURL = resolvedURL {
                let subs = sidebarSubfolders(of: rootURL, in: allDocs)
                let direct = sidebarDirectDocs(of: rootURL, in: allDocs)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(subs, id: \.path) { sub in
                        SidebarSubfolderRow(folderURL: sub, depth: 0)
                            .environmentObject(viewModel)
                    }
                    ForEach(direct) { doc in
                        SidebarFileRow(doc: doc, folderID: folder.id, indent: 24)
                            .environmentObject(viewModel)
                    }
                }
            }
        }
    }
}

// MARK: - Recursive subfolder tree for sidebar

struct SidebarSubfolderRow: View {
    let folderURL: URL
    let depth: Int
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isExpanded = false

    private var allDocs: [ImageDocument] {
        let prefix = folderURL.standardized.path + "/"
        return viewModel.collection.documents.filter { $0.standardizedPath.hasPrefix(prefix) }
    }

    private var indent: CGFloat { CGFloat(20 + depth * 12) }

    private var isSelected: Bool {
        viewModel.navSelection == .subfolder(folderURL.standardized.path)
    }

    var body: some View {
        let subs = sidebarSubfolders(of: folderURL, in: allDocs)
        let direct = sidebarDirectDocs(of: folderURL, in: allDocs)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.navSelection = .subfolder(folderURL.standardized.path)
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)
                        .opacity(subs.isEmpty && direct.isEmpty ? 0 : 1)
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                    Text(folderURL.lastPathComponent)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .primary : .secondary)
                    Spacer()
                    if !allDocs.isEmpty {
                        Text("\(allDocs.count)")
                            .font(.caption2)
                            .foregroundColor(Color(NSColor.quaternaryLabelColor))
                    }
                }
                .padding(.leading, indent)
                .padding(.trailing, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 4)

            if isExpanded {
                ForEach(subs, id: \.path) { sub in
                    SidebarSubfolderRow(folderURL: sub, depth: depth + 1)
                        .environmentObject(viewModel)
                }
                ForEach(direct) { doc in
                    SidebarFileRow(doc: doc, folderID: nil, indent: indent + 14)
                        .environmentObject(viewModel)
                }
            }
        }
    }
}

struct SidebarFileRow: View {
    let doc: ImageDocument
    let folderID: UUID?
    let indent: CGFloat
    @EnvironmentObject var viewModel: ImageViewModel

    private var idx: Int { viewModel.collectionIndex(for: doc) ?? 0 }
    private var isCurrent: Bool { viewModel.collection.currentIndex == idx }

    var body: some View {
        Button {
            viewModel.selectDocument(at: idx)
        } label: {
            HStack(spacing: 5) {
                if let thumb = doc.thumbnailImage ?? doc.placeholderThumbnailImage {
                    Image(nsImage: thumb).resizable().scaledToFill()
                        .frame(width: 22, height: 15).clipped().cornerRadius(2)
                } else {
                    Image(systemName: "photo").font(.system(size: 9))
                        .foregroundColor(.secondary).frame(width: 22, height: 15)
                }
                Text(doc.filename).font(.caption2).lineLimit(1)
                    .foregroundColor(isCurrent ? .primary : .secondary)
            }
            .padding(.leading, indent)
            .padding(.trailing, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isCurrent ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
    }
}

func sidebarSubfolders(of root: URL, in docs: [ImageDocument]) -> [URL] {
    let rootPath = root.standardized.path + "/"
    var seen = Set<String>()
    var result: [URL] = []
    for doc in docs {
        let p = doc.standardizedPath
        guard p.hasPrefix(rootPath) else { continue }
        let rel = String(p.dropFirst(rootPath.count))
        guard let slash = rel.firstIndex(of: "/") else { continue }
        let subName = String(rel[..<slash])
        if seen.insert(subName).inserted {
            result.append(root.appendingPathComponent(subName))
        }
    }
    return result.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}

func sidebarDirectDocs(of root: URL, in docs: [ImageDocument]) -> [ImageDocument] {
    let rootPath = root.standardized.path + "/"
    return docs.filter { doc in
        let p = doc.standardizedPath
        guard p.hasPrefix(rootPath) else { return false }
        return !String(p.dropFirst(rootPath.count)).contains("/")
    }
}

struct VolumeRow: View {
    let volume: DetectedVolume
    let isSelected: Bool
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isHovered = false

    var body: some View {
        Button {
            viewModel.navSelection = .volume(volume.id)
        } label: {
            HStack(spacing: 4) {
                Label(volume.name, systemImage: "sdcard")
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isHovered {
                    Button {
                        viewModel.offerVolumeSync(volume)
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Synchronisieren…")
                    Button {
                        viewModel.ejectVolume(volume)
                    } label: {
                        Image(systemName: "eject")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Auswerfen")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Synchronisieren…") { viewModel.offerVolumeSync(volume) }
            Button("Auswerfen") { viewModel.ejectVolume(volume) }
        }
    }
}
