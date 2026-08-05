import SwiftUI

private let kSmartFolderIDType = "com.c0d3cru5h.iphoto.smartfolder-id"

struct NavSidebarView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""
    @State private var renamingAlbum: Album? = nil
    @State private var renameText = ""
    @State private var smartFolderSheetItem: SmartFolderSheetItem? = nil
    @State private var albumsCollapsed = false
    @State private var smartFoldersCollapsed = false
    @State private var collapsedGroups: Set<String> = []
    @State private var movingFolder: SmartFolder? = nil
    @State private var renamingGroupName: String? = nil
    @State private var renameGroupText = ""
    @State private var dropTargetGroups: Set<String> = []
    @State private var dropOnUngrouped: Bool = false
    private func loadSmartFolderID(from providers: [NSItemProvider], completion: @escaping (SmartFolder?) -> Void) {
        providers.first?.loadDataRepresentation(forTypeIdentifier: kSmartFolderIDType) { data, _ in
            guard let data = data,
                  let idStr = String(data: data, encoding: .utf8),
                  let id = UUID(uuidString: idStr) else { completion(nil); return }
            DispatchQueue.main.async {
                completion(self.viewModel.library.smartFolders.first(where: { $0.id == id }))
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isStartupLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text("Bibliothek wird geladen…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                Divider()
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Bibliothek")
                    navRow(
                        label: "Library",
                        icon: "photo.stack",
                        isSelected: viewModel.navSelection == .library || viewModel.navSelection == nil
                    ) {
                        viewModel.navSelection = .library
                    }
                    navRow(
                        label: "Bildvergleich",
                        icon: "arrow.left.arrow.right",
                        isSelected: viewModel.compare.active
                    ) {
                        viewModel.toggleCompareMode()
                    }
                    albumsSection
                    smartFoldersSection
                    volumesSection
                    trashSection
                    duplicatesSection
                    blurrySection
                }
                .padding(.vertical, 8)
            }

            if !viewModel.activity.loadingQueue.isEmpty {
                Divider()
                LoadingBar(activity: viewModel.activity)
            } else if let summary = viewModel.activity.loadingSummary {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(summary)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor))
                .transition(.opacity)
            }
        }
        .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(item: $smartFolderSheetItem) { item in
            SmartFolderSheet(editing: item.folder)
                .environmentObject(viewModel)
        }
        .sheet(item: $movingFolder) { sf in
            MoveToGroupSheet(folder: sf)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: Binding(
            get: { renamingGroupName != nil },
            set: { if !$0 { renamingGroupName = nil } }
        )) {
            GroupRenameSheet(
                oldName: renamingGroupName ?? "",
                name: $renameGroupText,
                isPresented: Binding(
                    get: { renamingGroupName != nil },
                    set: { if !$0 { renamingGroupName = nil } }
                )
            )
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showCreateAlbum) {
            AlbumNameSheet(
                title: "Neues Album",
                placeholder: "Albumname",
                confirmLabel: "Erstellen",
                name: $newAlbumName,
                isPresented: $showCreateAlbum
            ) { name in viewModel.createAlbum(name: name) }
        }
        .sheet(item: $renamingAlbum) { album in
            AlbumNameSheet(
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

    @ViewBuilder
    private func smartFolderRow(_ sf: SmartFolder, indented: Bool = false) -> some View {
        let count = viewModel.smartFolderCounts[sf.id] ?? 0
        // Button + onDrag conflict: button gesture swallows the drag.
        // Using plain view + onTapGesture allows onDrag to work correctly.
        HStack(spacing: 4) {
            Label(sf.name, systemImage: "folder.badge.gearshape")
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 2)
            }
        }
        .padding(.horizontal, indented ? 24 : 10)
        .padding(.vertical, 5)
        .background(viewModel.navSelection == .smartFolder(sf.id) ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .padding(.horizontal, 4)
        .onTapGesture { viewModel.navSelection = .smartFolder(sf.id) }
        .onDrag {
            let provider = NSItemProvider()
            let idData = sf.id.uuidString.data(using: .utf8) ?? Data()
            provider.registerDataRepresentation(forTypeIdentifier: kSmartFolderIDType,
                                                visibility: .all) { completion in
                completion(idData, nil)
                return nil
            }
            return provider
        }
        .contextMenu {
            Button("Bearbeiten") { smartFolderSheetItem = SmartFolderSheetItem(folder: sf) }
            Button("In Gruppe verschieben") { movingFolder = sf }
            Divider()
            Button("Löschen") { viewModel.deleteSmartFolder(sf) }
        }
    }

    @ViewBuilder private var albumsSection: some View {
        collapsibleSectionHeader("Alben", isCollapsed: albumsCollapsed,
            onToggle: { withAnimation(.easeInOut(duration: 0.18)) { albumsCollapsed.toggle() } },
            trailing: AnyView(
                Button(action: { newAlbumName = ""; showCreateAlbum = true }) {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            ))
        if !albumsCollapsed {
            ForEach(viewModel.library.albums) { album in
                AlbumRow(album: album, isSelected: viewModel.navSelection == .album(album.id))
                    .environmentObject(viewModel)
                    .contextMenu {
                        Button("Umbenennen") { renameText = album.name; renamingAlbum = album }
                        Divider()
                        Button("Album löschen") { viewModel.deleteAlbum(album) }
                    }
            }
        }
    }

    @ViewBuilder private var smartFoldersSection: some View {
        collapsibleSectionHeader("Intelligente Ordner", isCollapsed: smartFoldersCollapsed,
            onToggle: { withAnimation(.easeInOut(duration: 0.18)) { smartFoldersCollapsed.toggle() } },
            trailing: AnyView(
                HStack(spacing: 4) {
                    Button(action: { viewModel.createFilmSimulationSmartFolders() }) {
                        Image(systemName: "camera.filters").font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Filmsimulationsordner automatisch erstellen")
                    Button(action: { smartFolderSheetItem = SmartFolderSheetItem(folder: nil) }) {
                        Image(systemName: "plus").font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            ))
            .background(dropOnUngrouped ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .onDrop(of: [kSmartFolderIDType],
                    isTargeted: Binding(
                        get: { dropOnUngrouped },
                        set: { dropOnUngrouped = $0 }
                    )) { providers in
                loadSmartFolderID(from: providers) { sf in
                    guard let sf = sf else { return }
                    viewModel.moveSmartFolder(sf, toGroup: nil)
                }
                return true
            }
        if !smartFoldersCollapsed {
            smartFoldersContent
        }
    }

    @ViewBuilder private var smartFoldersContent: some View {
        ForEach(viewModel.library.smartFolders.filter { $0.group == nil || $0.group?.isEmpty == true }) { sf in
            smartFolderRow(sf)
        }
        let groups = Array(Set(viewModel.library.smartFolders.compactMap { $0.group }.filter { !$0.isEmpty })).sorted()
        ForEach(groups, id: \.self) { groupName in
            groupHeaderRow(groupName)
            if !collapsedGroups.contains(groupName) {
                ForEach(viewModel.library.smartFolders.filter { $0.group == groupName }) { sf in
                    smartFolderRow(sf, indented: true)
                }
            }
        }
    }

    @ViewBuilder private func groupHeaderRow(_ groupName: String) -> some View {
        let isDropTarget = dropTargetGroups.contains(groupName)
        Button(action: {
            if collapsedGroups.contains(groupName) { collapsedGroups.remove(groupName) }
            else { collapsedGroups.insert(groupName) }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(collapsedGroups.contains(groupName) ? 0 : 90))
                    .frame(width: 12)
                Label(groupName, systemImage: "folder")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(isDropTarget ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .onDrop(of: [kSmartFolderIDType],
                isTargeted: Binding(
                    get: { dropTargetGroups.contains(groupName) },
                    set: { v in
                        if v { dropTargetGroups.insert(groupName) }
                        else { dropTargetGroups.remove(groupName) }
                    }
                )) { providers in
            loadSmartFolderID(from: providers) { sf in
                guard let sf = sf else { return }
                viewModel.moveSmartFolder(sf, toGroup: groupName)
            }
            return true
        }
        .contextMenu {
            Button("Umbenennen") { renameGroupText = groupName; renamingGroupName = groupName }
            Button("Auflösen") { viewModel.dissolveGroup(groupName) }
        }
    }

    @ViewBuilder private var volumesSection: some View {
        if !viewModel.library.detectedVolumes.isEmpty {
            sectionHeader("Wechseldatenträger")
            ForEach(viewModel.library.detectedVolumes) { volume in
                VolumeRow(volume: volume, isSelected: viewModel.navSelection == .volume(volume.id))
                    .environmentObject(viewModel)
            }
        }
    }

    @ViewBuilder
    private func collapsibleSectionHeader(_ title: String, isCollapsed: Bool, onToggle: @escaping () -> Void, trailing: AnyView? = nil) -> some View {
        HStack(spacing: 4) {
            Button(action: onToggle) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        .frame(width: 10)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, trailing: AnyView? = nil) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    @ViewBuilder private var trashSection: some View {
        sectionHeader("Papierkorb")
        Button(action: { viewModel.navSelection = .trash }) {
            HStack(spacing: 4) {
                Label("Papierkorb", systemImage: viewModel.trashedCount > 0 ? "trash.fill" : "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if viewModel.trashedCount > 0 {
                    Text("\(viewModel.trashedCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(viewModel.navSelection == .trash ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .contextMenu {
            Button("Papierkorb leeren…") { viewModel.emptyTrash() }
                .disabled(viewModel.trashedCount == 0)
        }
    }

    @ViewBuilder private var duplicatesSection: some View {
        sectionHeader("Duplikate")
        Button(action: { viewModel.navSelection = .duplicates }) {
            HStack(spacing: 4) {
                Label("Duplikate", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !viewModel.quality.duplicateGroups.isEmpty {
                    Text("\(viewModel.quality.duplicateGroups.count)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange)
                        .cornerRadius(4)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(viewModel.navSelection == .duplicates ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .contextMenu {
            Button("Neu scannen") { viewModel.detectDuplicates() }
        }

        Button(action: { viewModel.navSelection = .similar }) {
            HStack(spacing: 4) {
                Label("Ähnliche Bilder", systemImage: "square.on.square.dashed")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !viewModel.quality.similarGroups.isEmpty {
                    Text("\(viewModel.quality.similarGroups.count)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.blue)
                        .cornerRadius(4)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(viewModel.navSelection == .similar ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .contextMenu {
            Button("Neu gruppieren") { viewModel.detectSimilarImages() }
        }
    }

    @ViewBuilder private var blurrySection: some View {
        sectionHeader("Qualität")
        Button(action: { viewModel.navSelection = .blurry }) {
            HStack(spacing: 4) {
                Label("Unscharf", systemImage: "drop.triangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !viewModel.quality.blurryDocuments.isEmpty {
                    Text("\(viewModel.quality.blurryDocuments.count)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.purple)
                        .cornerRadius(4)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(viewModel.navSelection == .blurry ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .contextMenu {
            Button("Neu scannen") { viewModel.detectBlurryImages() }
        }

        Button(action: { viewModel.navSelection = .underexposed }) {
            HStack(spacing: 4) {
                Label("Unterbelichtet", systemImage: "moon.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !viewModel.quality.underexposedDocuments.isEmpty {
                    Text("\(viewModel.quality.underexposedDocuments.count)")
                        .font(.caption2).foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.purple).cornerRadius(4)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(viewModel.navSelection == .underexposed ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle()).padding(.horizontal, 4)
        .contextMenu { Button("Neu scannen") { viewModel.detectExposureIssues() } }

        Button(action: { viewModel.navSelection = .overexposed }) {
            HStack(spacing: 4) {
                Label("Überbelichtet", systemImage: "sun.max.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !viewModel.quality.overexposedDocuments.isEmpty {
                    Text("\(viewModel.quality.overexposedDocuments.count)")
                        .font(.caption2).foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.yellow.opacity(0.9)).cornerRadius(4)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(viewModel.navSelection == .overexposed ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle()).padding(.horizontal, 4)
        .contextMenu { Button("Neu scannen") { viewModel.detectExposureIssues() } }
    }

    private func navRow(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

private struct AlbumRow: View {
    let album: Album
    let isSelected: Bool
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isTargeted = false

    var body: some View {
        Button(action: { viewModel.selectAlbum(album) }) {
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
                    } else if let doc = viewModel.collection.documents.first(where: { $0.url == url }) {
                        viewModel.addToAlbum(doc, albumID: album.id)
                    }
                }
            }
            return true
        }
    }
}

private struct FolderRow: View {
    let folder: WatchedFolder
    let isSelected: Bool
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isExpanded: Bool = false

    private var folderImages: [ImageDocument] {
        guard let folderURL = folder.resolveURL()?.url else { return [] }
        let prefix = folderURL.standardized.path
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
                    let count = folderImages.count
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

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(folderImages) { doc in
                        let idx = viewModel.collectionIndex(for: doc) ?? 0
                        let isCurrent = viewModel.collection.currentIndex == idx && isSelected
                        Button {
                            if viewModel.navSelection != .folder(folder.id) {
                                viewModel.navSelection = .folder(folder.id)
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
                            .padding(.leading, 28)
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
            }
        }
    }
}

private struct VolumeRow: View {
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

private struct AlbumNameSheet: View {
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

// MARK: - MoveToGroupSheet

private struct MoveToGroupSheet: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @Environment(\.presentationMode) private var presentationMode

    let folder: SmartFolder
    @State private var newGroupName = ""

    private var existingGroups: [String] {
        Array(Set(viewModel.library.smartFolders.compactMap { $0.group }.filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("In Gruppe verschieben")
                .font(.headline)

            if !existingGroups.isEmpty {
                Text("Vorhandene Gruppen:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(existingGroups, id: \.self) { grp in
                        Button(action: {
                            viewModel.moveSmartFolder(folder, toGroup: grp)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: folder.group == grp ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(folder.group == grp ? .accentColor : .secondary)
                                Text(grp)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(folder.group == grp ? Color.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Divider()
            }

            Text("Neue Gruppe erstellen:")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("Gruppenname", text: $newGroupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Erstellen") {
                    let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    viewModel.moveSmartFolder(folder, toGroup: trimmed)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if folder.group != nil {
                Divider()
                Button("Aus Gruppe entfernen") {
                    viewModel.moveSmartFolder(folder, toGroup: nil)
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Color(NSColor.systemRed))
            }

            HStack {
                Spacer()
                Button("Abbrechen") { presentationMode.wrappedValue.dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

// MARK: - GroupRenameSheet

private struct GroupRenameSheet: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let oldName: String
    @Binding var name: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Gruppe umbenennen").font(.headline)
            TextField("Gruppenname", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 240)
            HStack(spacing: 12) {
                Button("Abbrechen") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Umbenennen") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    viewModel.renameGroup(oldName, to: trimmed)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }
}
