import SwiftUI

struct NavSidebarView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""
    @State private var renamingAlbum: Album? = nil
    @State private var renameText = ""
    @State private var smartFolderSheetItem: SmartFolderSheetItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Bibliothek")

            navRow(
                label: "Library",
                icon: "photo.stack",
                isSelected: viewModel.navSelection == .library || viewModel.navSelection == nil
            ) {
                viewModel.navSelection = .library
            }

            sectionHeader("Alben", trailing: AnyView(
                Button(action: { newAlbumName = ""; showCreateAlbum = true }) {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            ))

            ForEach(viewModel.albums) { album in
                AlbumRow(
                    album: album,
                    isSelected: viewModel.navSelection == .album(album.id)
                )
                .environmentObject(viewModel)
                .contextMenu {
                    Button("Umbenennen") { renameText = album.name; renamingAlbum = album }
                    Divider()
                    Button("Album löschen") { viewModel.deleteAlbum(album) }
                }
            }


            sectionHeader("Intelligente Ordner", trailing: AnyView(
                Button(action: { smartFolderSheetItem = SmartFolderSheetItem(folder: nil) }) {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            ))

            ForEach(viewModel.smartFolders) { sf in
                navRow(
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

            if !viewModel.detectedVolumes.isEmpty {
                sectionHeader("Wechseldatenträger")
                ForEach(viewModel.detectedVolumes) { volume in
                    VolumeRow(volume: volume,
                              isSelected: viewModel.navSelection == .volume(volume.id))
                        .environmentObject(viewModel)
                }
            }

            Spacer()

            if !viewModel.loadingQueue.isEmpty {
                Divider()
                LoadingBar(queue: viewModel.loadingQueue)
            }
        }
        .padding(.vertical, 8)
        .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(item: $smartFolderSheetItem) { item in
            SmartFolderSheet(editing: item.folder)
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
