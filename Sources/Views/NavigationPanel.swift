import SwiftUI

struct NavigationPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""
    @State private var renamingAlbum: Album? = nil
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelSectionHeader("Bibliothek")

            panelNavRow(label: "Library", icon: "photo.stack",
                        isSelected: viewModel.navSelection == .library || viewModel.navSelection == nil) {
                viewModel.navSelection = .library
            }

            panelSectionHeader("Alben", trailing: AnyView(
                Button(action: { newAlbumName = ""; showCreateAlbum = true }) {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            ))

            ForEach(viewModel.albums) { album in
                PanelAlbumRow(album: album,
                              isSelected: viewModel.navSelection == .album(album.id))
                    .environmentObject(viewModel)
            }

            panelSectionHeader("Ordner", trailing: AnyView(
                Button(action: { viewModel.addFolderDialog() }) {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            ))

            ForEach(viewModel.watchedFolders) { folder in
                PanelFolderRow(folder: folder,
                               isSelected: viewModel.navSelection == .folder(folder.id))
                    .environmentObject(viewModel)
                    .contextMenu {
                        Button {
                            viewModel.toggleAutoSync(for: folder)
                        } label: {
                            Label(
                                folder.autoSync ? "Auto-Sync deaktivieren" : "Auto-Sync bei Einführen",
                                systemImage: folder.autoSync ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath"
                            )
                        }
                        Divider()
                        Button("Ordner entfernen") { viewModel.deleteWatchedFolder(folder) }
                    }
            }
        }
        .padding(.bottom, 8)
        .sheet(isPresented: $showCreateAlbum) {
            PanelAlbumNameSheet(
                title: "Neues Album",
                placeholder: "Albumname",
                confirmLabel: "Erstellen",
                name: $newAlbumName,
                isPresented: $showCreateAlbum
            ) { name in viewModel.createAlbum(name: name) }
        }
        .sheet(item: $renamingAlbum) { album in
            PanelAlbumNameSheet(
                title: "Umbenennen",
                placeholder: album.name,
                confirmLabel: "Speichern",
                name: $renameText,
                isPresented: Binding(
                    get: { renamingAlbum != nil },
                    set: { if !$0 { renamingAlbum = nil } }
                )
            ) { name in viewModel.renameAlbum(album, to: name) }
        }
    }

    private func panelSectionHeader(_ title: String, trailing: AnyView? = nil) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    private func panelNavRow(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
    }
}

private struct PanelAlbumRow: View {
    let album: Album
    let isSelected: Bool
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isTargeted = false

    var body: some View {
        Button(action: { viewModel.selectAlbum(album) }) {
            Label(album.name, systemImage: isTargeted ? "rectangle.stack.fill" : "rectangle.stack")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor.opacity(0.2) : (isTargeted ? Color.accentColor.opacity(0.1) : Color.clear))
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
                    } else if let doc = docs.first(where: { $0.url == url }) {
                        viewModel.addToAlbum(doc, albumID: album.id)
                    }
                }
            }
            return true
        }
    }
}

private struct PanelFolderRow: View {
    let folder: WatchedFolder
    let isSelected: Bool
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isExpanded: Bool = false

    private var resolvedURL: URL? { folder.resolveURL()?.url }

    private var allDocs: [ImageDocument] {
        guard let url = resolvedURL else { return [] }
        let prefix = url.standardized.path + "/"
        return viewModel.collection.documents.filter {
            $0.url.standardized.path.hasPrefix(prefix)
        }
    }

    private var isRemovable: Bool { folder.isRemovableMedia }
    private var isAvailable: Bool { folder.isAvailable }

    private var folderIcon: String {
        if isRemovable {
            return isAvailable ? "externaldrive.fill" : "externaldrive.badge.exclamationmark"
        }
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
                        HStack(spacing: 4) {
                            Label(folder.name, systemImage: folderIcon)
                                .foregroundColor(isRemovable && !isAvailable ? .secondary : .primary)
                            if folder.autoSync {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 9))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        if isRemovable && !isAvailable {
                            Text("Speichermedium nicht verfügbar")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 4)

            if isExpanded, let rootURL = resolvedURL {
                let subs = navSubfolders(of: rootURL, in: allDocs)
                let direct = navDirectDocs(of: rootURL, in: allDocs)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(subs, id: \.path) { sub in
                        SubfolderTreeRow(folderURL: sub, folderID: folder.id, depth: 0)
                            .environmentObject(viewModel)
                    }
                    ForEach(direct) { doc in
                        PanelImageRow(doc: doc, folderID: folder.id, indent: 28)
                            .environmentObject(viewModel)
                    }
                }
            }
        }
    }
}

// MARK: - Recursive subfolder tree

private struct SubfolderTreeRow: View {
    let folderURL: URL
    let folderID: UUID
    let depth: Int
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isExpanded = false

    private var allDocs: [ImageDocument] {
        let prefix = folderURL.standardized.path + "/"
        return viewModel.collection.documents.filter {
            $0.url.standardized.path.hasPrefix(prefix)
        }
    }

    private var indent: CGFloat { CGFloat(16 + depth * 12) }

    var body: some View {
        let subs = navSubfolders(of: folderURL, in: allDocs)
        let direct = navDirectDocs(of: folderURL, in: allDocs)

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(folderURL.lastPathComponent)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(allDocs.count)")
                        .font(.caption2)
                        .foregroundColor(Color(NSColor.quaternaryLabelColor))
                }
                .padding(.leading, indent)
                .padding(.trailing, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 4)

            if isExpanded {
                ForEach(subs, id: \.path) { sub in
                    SubfolderTreeRow(folderURL: sub, folderID: folderID, depth: depth + 1)
                        .environmentObject(viewModel)
                }
                ForEach(direct) { doc in
                    PanelImageRow(doc: doc, folderID: folderID, indent: indent + 14)
                        .environmentObject(viewModel)
                }
            }
        }
    }
}

private struct PanelImageRow: View {
    let doc: ImageDocument
    let folderID: UUID
    let indent: CGFloat
    @EnvironmentObject var viewModel: ImageViewModel

    private var idx: Int { viewModel.collectionIndex(for: doc) ?? 0 }
    private var isCurrent: Bool {
        viewModel.collection.currentIndex == idx &&
        viewModel.navSelection == .folder(folderID)
    }

    var body: some View {
        Button {
            if viewModel.navSelection != .folder(folderID) {
                viewModel.navSelection = .folder(folderID)
            }
            viewModel.selectDocument(at: idx)
        } label: {
            HStack(spacing: 5) {
                if let thumb = doc.thumbnailImage ?? doc.placeholderThumbnailImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 22, height: 15)
                        .clipped()
                        .cornerRadius(2)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 15)
                }
                Text(doc.filename)
                    .font(.caption2)
                    .lineLimit(1)
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

// MARK: - Tree helpers

private func navSubfolders(of root: URL, in docs: [ImageDocument]) -> [URL] {
    let rootPath = root.standardized.path + "/"
    var seen = Set<String>()
    var result: [URL] = []
    for doc in docs {
        let p = doc.url.standardized.path
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

private func navDirectDocs(of root: URL, in docs: [ImageDocument]) -> [ImageDocument] {
    let rootPath = root.standardized.path + "/"
    return docs.filter { doc in
        let p = doc.url.standardized.path
        guard p.hasPrefix(rootPath) else { return false }
        return !String(p.dropFirst(rootPath.count)).contains("/")
    }
}

private struct PanelAlbumNameSheet: View {
    let title: String
    let placeholder: String
    let confirmLabel: String
    @Binding var name: String
    @Binding var isPresented: Bool
    let onConfirm: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title).font(.headline)
            TextField(placeholder, text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 240)
            HStack(spacing: 12) {
                Button("Abbrechen") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(confirmLabel) {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    onConfirm(trimmed)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }
}
