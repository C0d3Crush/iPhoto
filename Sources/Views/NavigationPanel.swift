import SwiftUI

struct NavigationPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var showCreateAlbum = false
    @State private var showCreateFolder = false
    @State private var newAlbumName = ""
    @State private var newFolderName = ""
    @State private var renamingAlbum: Album? = nil
    @State private var renamingFolder: AlbumFolder? = nil
    @State private var renameText = ""
    @State private var smartFolderSheetItem: SmartFolderSheetItem? = nil
    @State private var isRootDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            librarySection
            albumsSection
            watchedFoldersSection
            volumesSection
            smartFoldersSection
        }
        .padding(.bottom, 8)
        .sheet(item: $smartFolderSheetItem) { item in
            SmartFolderSheet(editing: item.folder)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showCreateAlbum) {
            PanelAlbumNameSheet(
                title: "Neues Album",
                placeholder: "Albumname",
                confirmLabel: "Erstellen",
                name: $newAlbumName,
                isPresented: $showCreateAlbum
            ) { name in viewModel.createAlbum(name: name) }
        }
        .sheet(isPresented: $showCreateFolder) {
            PanelAlbumNameSheet(
                title: "Neuer Ordner",
                placeholder: "Ordnername",
                confirmLabel: "Erstellen",
                name: $newFolderName,
                isPresented: $showCreateFolder
            ) { name in viewModel.createAlbumFolder(name: name) }
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
        .sheet(item: $renamingFolder) { folder in
            PanelAlbumNameSheet(
                title: "Ordner umbenennen",
                placeholder: folder.name,
                confirmLabel: "Speichern",
                name: $renameText,
                isPresented: Binding(
                    get: { renamingFolder != nil },
                    set: { if !$0 { renamingFolder = nil } }
                )
            ) { name in viewModel.renameAlbumFolder(folder, to: name) }
        }
    }

    // MARK: - Sections

    @ViewBuilder private var librarySection: some View {
        panelSectionHeader("Bibliothek")
        panelNavRow(label: "Library", icon: "photo.stack",
                    isSelected: viewModel.navSelection == .library || viewModel.navSelection == nil) {
            viewModel.navSelection = .library
        }
    }

    @ViewBuilder private var albumsSection: some View {
        panelSectionHeader("Alben", trailing: AnyView(albumsAddMenu))
        // Root-Ebene: Folders zuerst, dann parentlose Alben. Drop-Zone promotet
        // per Drag zurück auf Root (parentID = nil).
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.childFolders(of: nil)) { folder in
                PanelAlbumFolderRow(folder: folder, depth: 0,
                                    renamingFolder: $renamingFolder,
                                    renameText: $renameText)
                    .environmentObject(viewModel)
            }
            ForEach(viewModel.childAlbums(of: nil)) { album in
                PanelAlbumRow(album: album, depth: 0,
                              isSelected: viewModel.navSelection == .album(album.id),
                              renamingAlbum: $renamingAlbum,
                              renameText: $renameText)
                    .environmentObject(viewModel)
            }
        }
        .background(isRootDropTargeted ? Color.accentColor.opacity(0.06) : Color.clear)
        .onDrop(of: [AlbumTreeDrag.uti], isTargeted: $isRootDropTargeted) { providers in
            AlbumTreeDrag.handle(providers: providers, viewModel: viewModel, targetFolderID: nil)
            return true
        }
    }

    private var albumsAddMenu: some View {
        Menu {
            Button("Neues Album…") { newAlbumName = ""; showCreateAlbum = true }
            Button("Neuer Ordner…") { newFolderName = ""; showCreateFolder = true }
        } label: {
            Image(systemName: "plus").font(.caption)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .frame(width: 20)
    }

    @ViewBuilder private var watchedFoldersSection: some View {
        panelSectionHeader("Ordner", trailing: AnyView(
            Button(action: { viewModel.addFolderDialog() }) {
                Image(systemName: "plus").font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        ))
        if !viewModel.activity.importProgress.isEmpty {
            ImportProgressBanner()
                .environmentObject(viewModel)
        }
        ForEach(viewModel.library.watchedFolders) { folder in
            watchedFolderRow(folder)
        }
    }

    @ViewBuilder private func watchedFolderRow(_ folder: WatchedFolder) -> some View {
        PanelFolderRow(folder: folder,
                       isSelected: viewModel.navSelection == .folder(folder.id))
            .environmentObject(viewModel)
            .contextMenu { watchedFolderContextMenu(folder) }
    }

    @ViewBuilder private func watchedFolderContextMenu(_ folder: WatchedFolder) -> some View {
        Button {
            viewModel.toggleAutoSync(for: folder)
        } label: {
            Label(
                folder.autoSync ? "Auto-Sync deaktivieren" : "Auto-Sync bei Einführen",
                systemImage: folder.autoSync ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath"
            )
        }
        Divider()
        if !folder.isRemovableMedia {
            Button {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.canCreateDirectories = true
                panel.title = "Importziel wählen"
                panel.prompt = "Auswählen"
                if panel.runModal() == .OK, let url = panel.url {
                    viewModel.setImportDestination(for: folder, path: url.path)
                }
            } label: {
                Label("Importziel festlegen…", systemImage: "folder.badge.plus")
            }
        }
        if folder.isRemovableMedia || folder.importDestinationPath != nil {
            Button {
                viewModel.importImages(from: folder)
            } label: {
                Label("Jetzt importieren", systemImage: "arrow.down.circle")
            }
            .disabled(!folder.isAvailable || viewModel.activity.importProgress[folder.id] != nil)
            if !folder.isRemovableMedia {
                Button {
                    viewModel.setImportDestination(for: folder, path: nil)
                } label: {
                    Label("Importziel entfernen", systemImage: "folder.badge.minus")
                }
            }
        }
        Divider()
        Button("Ordner entfernen") { viewModel.deleteWatchedFolder(folder) }
    }

    @ViewBuilder private var volumesSection: some View {
        if !viewModel.library.detectedVolumes.isEmpty {
            panelSectionHeader("Wechseldatenträger")
            ForEach(viewModel.library.detectedVolumes) { volume in
                PanelVolumeRow(volume: volume,
                               isSelected: viewModel.navSelection == .volume(volume.id))
                    .environmentObject(viewModel)
            }
        }
    }

    @ViewBuilder private var smartFoldersSection: some View {
        panelSectionHeader("Intelligente Ordner", trailing: AnyView(
            Button(action: { smartFolderSheetItem = SmartFolderSheetItem(folder: nil) }) {
                Image(systemName: "plus").font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        ))
        ForEach(viewModel.library.smartFolders) { sf in
            smartFolderRow(sf)
        }
    }

    @ViewBuilder private func smartFolderRow(_ sf: SmartFolder) -> some View {
        panelNavRow(
            label: sf.name,
            icon: "folder.badge.gearshape",
            isSelected: viewModel.navSelection == .smartFolder(sf.id)
        ) {
            viewModel.navSelection = .smartFolder(sf.id)
        }
        .contextMenu {
            Button("Bearbeiten") { smartFolderSheetItem = SmartFolderSheetItem(folder: sf) }
            Divider()
            Button("Löschen") { viewModel.deleteSmartFolder(sf) }
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
    let depth: Int
    let isSelected: Bool
    @Binding var renamingAlbum: Album?
    @Binding var renameText: String
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isTargeted = false

    private var indent: CGFloat { CGFloat(depth) * 14 }

    var body: some View {
        Button(action: { viewModel.selectAlbum(album) }) {
            Label(album.name, systemImage: isTargeted ? "rectangle.stack.fill" : "rectangle.stack")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10 + indent)
                .padding(.trailing, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor.opacity(0.2) : (isTargeted ? Color.accentColor.opacity(0.1) : Color.clear))
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .contextMenu {
            Button("Umbenennen…") {
                renameText = album.name
                renamingAlbum = album
            }
            Divider()
            albumMoveMenu(for: album)
            Divider()
            Button("Löschen") { viewModel.deleteAlbum(album) }
        }
        .onDrag {
            NSItemProvider(object: AlbumTreeDrag.encode(.album(album.id)) as NSString)
        }
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

    @ViewBuilder
    private func albumMoveMenu(for album: Album) -> some View {
        Menu("Verschieben nach…") {
            Button("Root-Ebene") { viewModel.moveAlbum(album, into: nil) }
                .disabled(album.parentID == nil)
            Divider()
            ForEach(viewModel.library.albumFolders) { folder in
                Button(folder.name) { viewModel.moveAlbum(album, into: folder.id) }
                    .disabled(album.parentID == folder.id)
            }
        }
    }
}

// MARK: - AlbumFolder row (rekursiv)

private struct PanelAlbumFolderRow: View {
    let folder: AlbumFolder
    let depth: Int
    @Binding var renamingFolder: AlbumFolder?
    @Binding var renameText: String
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isExpanded: Bool = true
    @State private var isDropTargeted = false

    private var indent: CGFloat { CGFloat(depth) * 14 }
    private var isSelected: Bool { viewModel.navSelection == .albumFolder(folder.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.selectAlbumFolder(folder)
            } label: {
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Label(folder.name, systemImage: isExpanded ? "folder.fill" : "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 6 + indent)
                .padding(.trailing, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.2)
                        : (isDropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
                )
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 4)
            .contextMenu {
                Button("Umbenennen…") {
                    renameText = folder.name
                    renamingFolder = folder
                }
                Divider()
                folderMoveMenu(for: folder)
                Divider()
                Button("Ordner löschen") { viewModel.deleteAlbumFolder(folder) }
            }
            .onDrag {
                NSItemProvider(object: AlbumTreeDrag.encode(.folder(folder.id)) as NSString)
            }
            .onDrop(of: [AlbumTreeDrag.uti], isTargeted: $isDropTargeted) { providers in
                AlbumTreeDrag.handle(providers: providers, viewModel: viewModel, targetFolderID: folder.id)
                return true
            }

            if isExpanded {
                ForEach(viewModel.childFolders(of: folder.id)) { sub in
                    PanelAlbumFolderRow(folder: sub, depth: depth + 1,
                                        renamingFolder: $renamingFolder,
                                        renameText: $renameText)
                        .environmentObject(viewModel)
                }
                ForEach(viewModel.childAlbums(of: folder.id)) { album in
                    PanelAlbumRow(album: album, depth: depth + 1,
                                  isSelected: viewModel.navSelection == .album(album.id),
                                  renamingAlbum: .constant(nil),
                                  renameText: .constant(""))
                        .environmentObject(viewModel)
                }
            }
        }
    }

    @ViewBuilder
    private func folderMoveMenu(for folder: AlbumFolder) -> some View {
        Menu("Verschieben nach…") {
            Button("Root-Ebene") { viewModel.moveAlbumFolder(folder, into: nil) }
                .disabled(folder.parentID == nil)
            Divider()
            ForEach(viewModel.library.albumFolders) { target in
                Button(target.name) { viewModel.moveAlbumFolder(folder, into: target.id) }
                    .disabled(target.id == folder.id || folder.parentID == target.id)
            }
        }
    }
}

// MARK: - Album/Folder drag-payload

enum AlbumTreeDrag {
    /// Custom Plain-Text-Payload. Ein eigenes UTI würde saubere Trennung von
    /// public.file-url erlauben, verlangt aber Info.plist-Registrierung —
    /// mit Prefix-Marker (`album:` / `folder:`) im UTF8-String bleibt es simpel.
    static let uti = "public.utf8-plain-text"

    enum Payload {
        case album(UUID)
        case folder(UUID)
    }

    static func encode(_ payload: Payload) -> String {
        switch payload {
        case .album(let id):  return "iphoto-album:\(id.uuidString)"
        case .folder(let id): return "iphoto-folder:\(id.uuidString)"
        }
    }

    static func decode(_ s: String) -> Payload? {
        if s.hasPrefix("iphoto-album:"),
           let uuid = UUID(uuidString: String(s.dropFirst("iphoto-album:".count))) {
            return .album(uuid)
        }
        if s.hasPrefix("iphoto-folder:"),
           let uuid = UUID(uuidString: String(s.dropFirst("iphoto-folder:".count))) {
            return .folder(uuid)
        }
        return nil
    }

    static func handle(providers: [NSItemProvider],
                       viewModel: ImageViewModel,
                       targetFolderID: UUID?) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: uti, options: nil) { item, _ in
                let string: String? = {
                    if let s = item as? String { return s }
                    if let d = item as? Data { return String(data: d, encoding: .utf8) }
                    return nil
                }()
                guard let s = string, let payload = decode(s) else { return }
                DispatchQueue.main.async {
                    switch payload {
                    case .album(let id):
                        if let album = viewModel.library.albums.first(where: { $0.id == id }) {
                            viewModel.moveAlbum(album, into: targetFolderID)
                        }
                    case .folder(let id):
                        if let folder = viewModel.library.albumFolders.first(where: { $0.id == id }) {
                            viewModel.moveAlbumFolder(folder, into: targetFolderID)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Import progress banner

private struct ImportProgressBanner: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.activity.importProgress.values.enumerated()), id: \.offset) { _, prog in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                        Text("Importiere \(prog.folderName)")
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(prog.completed)/\(prog.total)")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: prog.total > 0 ? Double(prog.completed) / Double(prog.total) : 0)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.08))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.accentColor.opacity(0.15)),
                    alignment: .bottom
                )
            }
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
        if folder.isDefaultLibrary { return "photo.on.rectangle" }
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
                        if folder.autoSync && folder.importDestinationPath == nil && !isRemovable {
                            Text("Kein Importziel — Bilder nicht lokal gespeichert")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        if let prog = viewModel.activity.importProgress[folder.id] {
                            HStack(spacing: 4) {
                                ProgressView(value: prog.total > 0 ? Double(prog.completed) / Double(prog.total) : 0)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .frame(maxWidth: 80)
                                Text("\(prog.completed)/\(prog.total)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else if isRemovable && viewModel.activity.completedImports.contains(folder.id) {
                            Button {
                                viewModel.wipeFolder(folder)
                            } label: {
                                Label("Karte leeren", systemImage: "trash")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else if let destPath = folder.importDestinationPath {
                            Text("→ \(URL(fileURLWithPath: destPath).lastPathComponent)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
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

private struct PanelVolumeRow: View {
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
