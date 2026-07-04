import SwiftUI

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
                    albumsSection
                    smartFoldersSection
                    volumesSection
                }
                .padding(.vertical, 8)
            }

            if !viewModel.loadingQueue.isEmpty {
                Divider()
                LoadingBar(queue: viewModel.loadingQueue)
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
        Button(action: { viewModel.navSelection = .smartFolder(sf.id) }) {
            Label(sf.name, systemImage: "folder.badge.gearshape")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, indented ? 24 : 10)
                .padding(.vertical, 5)
                .background(viewModel.navSelection == .smartFolder(sf.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .onDrag { NSItemProvider(object: sf.id.uuidString as NSString) }
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
            ForEach(viewModel.albums) { album in
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
                Button(action: { smartFolderSheetItem = SmartFolderSheetItem(folder: nil) }) {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            ))
            .background(dropOnUngrouped ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .onDrop(of: ["public.plain-text"],
                    isTargeted: Binding(
                        get: { dropOnUngrouped },
                        set: { dropOnUngrouped = $0 }
                    )) { providers in
                providers.first?.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
                    guard let data = item as? Data,
                          let idStr = String(data: data, encoding: .utf8),
                          let id = UUID(uuidString: idStr),
                          let sf = viewModel.smartFolders.first(where: { $0.id == id }) else { return }
                    DispatchQueue.main.async { viewModel.moveSmartFolder(sf, toGroup: nil) }
                }
                return true
            }
        if !smartFoldersCollapsed {
            smartFoldersContent
        }
    }

    @ViewBuilder private var smartFoldersContent: some View {
        ForEach(viewModel.smartFolders.filter { $0.group == nil || $0.group?.isEmpty == true }) { sf in
            smartFolderRow(sf)
        }
        let groups = Array(Set(viewModel.smartFolders.compactMap { $0.group }.filter { !$0.isEmpty })).sorted()
        ForEach(groups, id: \.self) { groupName in
            groupHeaderRow(groupName)
            if !collapsedGroups.contains(groupName) {
                ForEach(viewModel.smartFolders.filter { $0.group == groupName }) { sf in
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
        .onDrop(of: ["public.plain-text"],
                isTargeted: Binding(
                    get: { dropTargetGroups.contains(groupName) },
                    set: { v in
                        if v { dropTargetGroups.insert(groupName) }
                        else { dropTargetGroups.remove(groupName) }
                    }
                )) { providers in
            providers.first?.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
                guard let data = item as? Data,
                      let idStr = String(data: data, encoding: .utf8),
                      let id = UUID(uuidString: idStr),
                      let sf = viewModel.smartFolders.first(where: { $0.id == id }) else { return }
                DispatchQueue.main.async { viewModel.moveSmartFolder(sf, toGroup: groupName) }
            }
            return true
        }
        .contextMenu {
            Button("Umbenennen") { renameGroupText = groupName; renamingGroupName = groupName }
            Button("Auflösen") { viewModel.dissolveGroup(groupName) }
        }
    }

    @ViewBuilder private var volumesSection: some View {
        if !viewModel.detectedVolumes.isEmpty {
            sectionHeader("Wechseldatenträger")
            ForEach(viewModel.detectedVolumes) { volume in
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
        Array(Set(viewModel.smartFolders.compactMap { $0.group }.filter { !$0.isEmpty })).sorted()
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
