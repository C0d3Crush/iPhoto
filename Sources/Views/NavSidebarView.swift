import SwiftUI

private let kSmartFolderIDType = "com.c0d3cru5h.iphoto.smartfolder-id"

struct NavSidebarView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @ObservedObject private var pluginStore = PluginStore.shared
    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""
    @State private var renamingAlbum: Album? = nil
    @State private var renameText = ""
    @State private var albumDetailItem: Album? = nil
    @State private var smartFolderSheetItem: SmartFolderSheetItem? = nil
    @State private var albumsCollapsed = false
    @State private var foldersCollapsed = false
    @State private var smartFoldersCollapsed = false
    @State private var iFoldersCollapsed = false
    @State private var volumesCollapsed = false
    @State private var trashCollapsed = false
    @State private var backupCollapsed = false
    @State private var duplicatesCollapsed = false
    @State private var qualityCollapsed = false
    @State private var peopleCollapsed = false
    @State private var collapsedGroups: Set<String> = []
    @State private var movingFolder: SmartFolder? = nil
    @State private var renamingGroupName: String? = nil
    @State private var renameGroupText = ""
    @State private var dropTargetGroups: Set<String> = []
    @State private var dropOnUngrouped: Bool = false
    @State private var sectionOrder: [NavSidebarSection] = NavSidebarSection.loadOrder()
    @State private var draggingSection: NavSidebarSection?

    private static let collapseAnimation = Animation.easeInOut(duration: 0.18)

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
            // Expand button row
            HStack(spacing: 0) {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.sidebarAlbumExpanded.toggle()
                    }
                }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 10)
                        .padding(.top, 14)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Alben als Symbole anzeigen")
            }

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

            sidebarScrollView

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

            VerboseLogView()
                .environmentObject(viewModel)
        }
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(item: $albumDetailItem) { album in
            AlbumDetailSheet(album: album, isPresented: Binding(
                get: { albumDetailItem != nil },
                set: { if !$0 { albumDetailItem = nil } }
            ))
            .environmentObject(viewModel)
        }
        .sheet(item: $smartFolderSheetItem) { item in
            SmartFolderSheet(editing: item.folder, preselectedBasePath: item.preselectedBasePath)
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


    // MARK: - Scroll area

    private static let systemSections: Set<NavSidebarSection> = [.trash, .backup, .duplicates, .blurry, .people]

    @ViewBuilder private var sidebarScrollView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Project subdirectory sections (project mode only, before system divider)
                if viewModel.isProjectMode {
                    projectSubdirSections
                }
                let visibleSections = sectionOrder.filter {
                    NavSidebarSection.isVisible($0)
                    && $0 != .folders && $0 != .iFolders
                    && (!viewModel.isProjectMode || ($0 != .albums && $0 != .smartFolders))
                }
                ForEach(Array(visibleSections.enumerated()), id: \.element) { idx, section in
                    // Divider before first system section
                    if Self.systemSections.contains(section)
                        && (idx == 0 || !Self.systemSections.contains(visibleSections[idx - 1])) {
                        Divider()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    sectionView(for: section)
                        .onDrag {
                            DispatchQueue.main.async { self.draggingSection = section }
                            return NSItemProvider(object: section.rawValue as NSString)
                        }
                        .onDrop(of: ["public.text"],
                                delegate: NavSectionDropDelegate(
                                    target: section,
                                    order: $sectionOrder,
                                    dragging: $draggingSection))
                        .opacity(draggingSection == section ? 0.4 : 1.0)
                }
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .contentShape(Rectangle())
            }
            .padding(.vertical, 8)
            .padding(.trailing, 12)
        }
        .contextMenu { sidebarCreationMenu }
    }

    @ViewBuilder private var projectSubdirSections: some View {
        let subdirs = viewModel.projectSubdirectories
        if !subdirs.isEmpty {
            ForEach(subdirs, id: \.path) { dir in
                SidebarSubfolderRow(folderURL: dir, depth: 0)
                    .environmentObject(viewModel)
            }
        }
    }

    @ViewBuilder private var sidebarCreationMenu: some View {
        Button("Neues Album erstellen…") {
            newAlbumName = ""
            showCreateAlbum = true
        }
        Button("Neues iAlbum erstellen…") {
            smartFolderSheetItem = SmartFolderSheetItem(folder: nil)
        }
        Divider()
        Button("Ordner hinzufügen…") {
            viewModel.addFolderDialog()
        }
        Button("Neues iOrdner erstellen…") {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Auswählen"
            if panel.runModal() == .OK, let url = panel.url {
                smartFolderSheetItem = SmartFolderSheetItem(folder: nil, preselectedBasePath: url.standardized.path)
            }
        }
    }

    // MARK: - Section dispatcher

    @ViewBuilder
    private func sectionView(for section: NavSidebarSection) -> some View {
        switch section {
        case .library:
            Group {
                sectionHeader("Bibliothek")
                libraryCompactRow
            }
        case .albums:        albumsSection
        case .folders:       foldersSection
        case .smartFolders:
            Group {
                smartFoldersSection
                smartFolderGroupSections
            }
        case .iFolders:      iFoldersSection
        case .volumes:       volumesSection
        case .trash:         trashSection
        case .backup:        backupSection
        case .duplicates:    duplicatesSection
        case .blurry:        blurrySection
        case .people:        peopleSection
        }
    }

    // MARK: - Smart folder helpers

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
        .background((viewModel.navSelection == .smartFolder(sf.id) || viewModel.sidebarSelectedSmartFolderIDs.contains(sf.id)) ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .padding(.horizontal, 4)
        .onTapGesture {
            let shift = viewModel.lastClickModifiers.contains(.shift)
            viewModel.sidebarSelectSmartFolder(sf, extending: shift)
        }
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
            let multiSel = viewModel.sidebarSelectedSmartFolderIDs.count > 1
                && viewModel.sidebarSelectedSmartFolderIDs.contains(sf.id)
            if !multiSel {
                Button("Bearbeiten") { smartFolderSheetItem = SmartFolderSheetItem(folder: sf) }
                Button("In Gruppe verschieben") { movingFolder = sf }
                Divider()
            }
            Button(multiSel
                   ? "\(viewModel.sidebarSelectedSmartFolderIDs.count) iAlben löschen"
                   : "Löschen") {
                if multiSel { viewModel.deleteSelectedSidebarSmartFolders() }
                else { viewModel.deleteSmartFolder(sf) }
            }
        }
    }

    @ViewBuilder private var albumsSection: some View {
        collapsibleSectionHeader("Alben", isCollapsed: albumsCollapsed,
            onToggle: { withAnimation(Self.collapseAnimation) { albumsCollapsed.toggle() } },
            trailing: AnyView(
                Button(action: { newAlbumName = ""; showCreateAlbum = true }) {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            ))
        if !albumsCollapsed {
            ForEach(viewModel.library.albums) { album in
                let multiSel = viewModel.sidebarSelectedAlbumIDs.count > 1
                    && viewModel.sidebarSelectedAlbumIDs.contains(album.id)
                AlbumRow(album: album, isSelected: viewModel.navSelection == .album(album.id))
                    .environmentObject(viewModel)
                    .contextMenu {
                        if !multiSel {
                            Button("Informationen…") { albumDetailItem = album }
                            Divider()
                            Button("Umbenennen") { renameText = album.name; renamingAlbum = album }
                            Divider()
                        }
                        Button(multiSel
                               ? "\(viewModel.sidebarSelectedAlbumIDs.count) Alben löschen"
                               : "Album löschen") {
                            if multiSel { viewModel.deleteSelectedSidebarAlbums() }
                            else { viewModel.deleteAlbum(album) }
                        }
                    }
            }
        }
    }

    @ViewBuilder private var foldersSection: some View {
        let regularFolders = viewModel.library.watchedFolders.filter { !$0.isRemovableMedia && !$0.isDefaultLibrary }
        collapsibleSectionHeader("Ordner", isCollapsed: foldersCollapsed,
            onToggle: { withAnimation(Self.collapseAnimation) { foldersCollapsed.toggle() } },
            trailing: AnyView(
                Button(action: { viewModel.addFolderDialog() }) {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            ))
        if !foldersCollapsed {
            ForEach(regularFolders) { folder in
                FolderRow(folder: folder, isSelected: viewModel.navSelection == .folder(folder.id))
                    .environmentObject(viewModel)
                    .contextMenu {
                        Button("Ordner entfernen") { viewModel.deleteWatchedFolder(folder) }
                    }
            }
        }
    }

    @ViewBuilder private var iFoldersSection: some View {
        let iFolders = viewModel.library.smartFolders.filter { $0.baseFolderPath != nil }
        collapsibleSectionHeader("iOrdner", isCollapsed: iFoldersCollapsed,
            onToggle: { withAnimation(Self.collapseAnimation) { iFoldersCollapsed.toggle() } },
            trailing: AnyView(
                Button(action: {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.prompt = "Auswählen"
                    if panel.runModal() == .OK, let url = panel.url {
                        smartFolderSheetItem = SmartFolderSheetItem(folder: nil, preselectedBasePath: url.standardized.path)
                    }
                }) {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            ))
        if !iFoldersCollapsed {
            ForEach(iFolders) { sf in
                smartFolderRow(sf)
            }
        }
    }

    @ViewBuilder private var smartFoldersSection: some View {
        collapsibleSectionHeader("iAlben", isCollapsed: smartFoldersCollapsed,
            onToggle: { withAnimation(Self.collapseAnimation) { smartFoldersCollapsed.toggle() } },
            trailing: AnyView(
                Button(action: { smartFolderSheetItem = SmartFolderSheetItem(folder: nil) }) {
                    Image(systemName: "plus").font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
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
        // All smart folders (iAlben + iOrdner) that have no group
        ForEach(viewModel.library.smartFolders.filter { $0.group == nil || $0.group?.isEmpty == true }) { sf in
            smartFolderRow(sf)
        }
    }

    /// Renders each SmartFolder group as its own collapsible top-level section.
    @ViewBuilder var smartFolderGroupSections: some View {
        let iAlben = viewModel.library.smartFolders
        let groups = Array(Set(iAlben.compactMap { $0.group }.filter { !$0.isEmpty })).sorted()
        ForEach(groups, id: \.self) { groupName in
            collapsibleSectionHeader(groupName, isCollapsed: collapsedGroups.contains(groupName),
                onToggle: {
                    withAnimation(Self.collapseAnimation) {
                        if collapsedGroups.contains(groupName) { collapsedGroups.remove(groupName) }
                        else { collapsedGroups.insert(groupName) }
                    }
                })
                .onDrop(of: [kSmartFolderIDType],
                        isTargeted: Binding(
                            get: { dropTargetGroups.contains(groupName) },
                            set: { if $0 { dropTargetGroups.insert(groupName) } else { dropTargetGroups.remove(groupName) } }
                        )) { providers in
                    loadSmartFolderID(from: providers) { sf in
                        guard let sf = sf else { return }
                        viewModel.moveSmartFolder(sf, toGroup: groupName)
                    }
                    return true
                }
            if !collapsedGroups.contains(groupName) {
                ForEach(iAlben.filter { $0.group == groupName }) { sf in
                    smartFolderRow(sf)
                }
            }
        }
    }

    @ViewBuilder private var volumesSection: some View {
        let removableFolders = viewModel.library.watchedFolders.filter { $0.isRemovableMedia }
        if !viewModel.library.detectedVolumes.isEmpty || !removableFolders.isEmpty {
            collapsibleSectionHeader("Wechseldatenträger", isCollapsed: volumesCollapsed,
                onToggle: { withAnimation(Self.collapseAnimation) { volumesCollapsed.toggle() } })
            if !volumesCollapsed {
                ForEach(viewModel.library.detectedVolumes) { volume in
                    VolumeRow(volume: volume, isSelected: viewModel.navSelection == .volume(volume.id))
                        .environmentObject(viewModel)
                }
                ForEach(removableFolders) { folder in
                    FolderRow(folder: folder, isSelected: viewModel.navSelection == .folder(folder.id))
                        .environmentObject(viewModel)
                        .contextMenu {
                            Button("Ordner entfernen") { viewModel.deleteWatchedFolder(folder) }
                        }
                }
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
        .contentShape(Rectangle())
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
        .contentShape(Rectangle())
    }

    @ViewBuilder private var trashSection: some View {
        collapsibleSectionHeader("Papierkorb", isCollapsed: trashCollapsed,
            onToggle: { withAnimation(Self.collapseAnimation) { trashCollapsed.toggle() } })
        if !trashCollapsed {
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
        } // !trashCollapsed
    }

    @ViewBuilder private var backupSection: some View {
        collapsibleSectionHeader("Backup", isCollapsed: backupCollapsed,
            onToggle: { withAnimation(Self.collapseAnimation) { backupCollapsed.toggle() } })
        if !backupCollapsed {
            Button(action: { viewModel.navSelection = .backup }) {
                HStack(spacing: 4) {
                    Label("Backup", systemImage: viewModel.backedUpCount > 0
                          ? "externaldrive.badge.checkmark" : "externaldrive")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if viewModel.backedUpCount > 0 {
                        Text("\(viewModel.backedUpCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 2)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(viewModel.navSelection == .backup ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 4)
            .help("Gesicherte Bilder anzeigen (⌘B zum Sichern)")

        } // !backupCollapsed
    }

    @ViewBuilder private var duplicatesSection: some View {
        collapsibleSectionHeader("Duplikate", isCollapsed: duplicatesCollapsed,
            onToggle: { withAnimation(Self.collapseAnimation) { duplicatesCollapsed.toggle() } })
        if !duplicatesCollapsed {
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
        } // !duplicatesCollapsed
    }

    @ViewBuilder private var blurrySection: some View {
        collapsibleSectionHeader("Qualität", isCollapsed: qualityCollapsed,
            onToggle: { withAnimation(Self.collapseAnimation) { qualityCollapsed.toggle() } })
        if !qualityCollapsed {
            qualityItemRow(label: "Unscharf", icon: "drop.triangle",
                           navTarget: .blurry,
                           count: viewModel.quality.blurryDocuments.count,
                           badgeColor: .purple) { viewModel.detectBlurryImages() }
            qualityItemRow(label: "Unterbelichtet", icon: "moon.fill",
                           navTarget: .underexposed,
                           count: viewModel.quality.underexposedDocuments.count,
                           badgeColor: .purple) { viewModel.detectExposureIssues() }
            qualityItemRow(label: "Überbelichtet", icon: "sun.max.fill",
                           navTarget: .overexposed,
                           count: viewModel.quality.overexposedDocuments.count,
                           badgeColor: .yellow.opacity(0.9)) { viewModel.detectExposureIssues() }
            qualityItemRow(label: "Augen zu", icon: "eye.slash.fill",
                           navTarget: .closedEyes,
                           count: viewModel.quality.closedEyeDocuments.count,
                           badgeColor: .pink) { viewModel.detectClosedEyes() }
        } // !qualityCollapsed
    }

    private func qualityItemRow(
        label: String,
        icon: String,
        navTarget: NavSelection,
        count: Int,
        badgeColor: Color,
        onRescan: @escaping () -> Void
    ) -> some View {
        Button(action: { viewModel.navSelection = navTarget }) {
            HStack(spacing: 4) {
                Label(label, systemImage: icon)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2).foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(badgeColor).cornerRadius(4)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(viewModel.navSelection == navTarget ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle()).padding(.horizontal, 4)
        .contextMenu { Button("Neu scannen") { onRescan() } }
    }

    @ViewBuilder private var peopleSection: some View {
        collapsibleSectionHeader("Menschen", isCollapsed: peopleCollapsed,
            onToggle: { withAnimation(Self.collapseAnimation) { peopleCollapsed.toggle() } })
        if !peopleCollapsed {
        Button(action: { viewModel.navSelection = .people }) {
            HStack(spacing: 4) {
                Label("Personen", systemImage: "person.2")
                    .frame(maxWidth: .infinity, alignment: .leading)
                let count = viewModel.people.people.count
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(viewModel.navSelection == .people ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .contextMenu {
            Button("Scannen") { viewModel.scanFacesForLibrary() }
        }
        } // !peopleCollapsed
    }

    private var libraryCompactRow: some View {
        let isSelected = viewModel.navSelection == .library || viewModel.navSelection == nil
        let docs = Array(viewModel.collection.documents.prefix(4))
        let images = docs.compactMap { $0.thumbnailImage ?? $0.placeholderThumbnailImage }
        return Button(action: { viewModel.navSelection = .library }) {
            HStack(spacing: 8) {
                libraryMiniMosaic(images: images)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Library")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Text("\(viewModel.collection.documents.count) Fotos")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 4)
        .onAppear {
            for (i, _) in docs.enumerated() {
                viewModel.requestVisibleThumbnail(at: i)
            }
        }
    }

    @ViewBuilder
    private func libraryMiniMosaic(images: [NSImage]) -> some View {
        if images.isEmpty {
            ZStack {
                Color(NSColor.separatorColor).opacity(0.3)
                Image(systemName: "photo.stack")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
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
                VStack(spacing: 0.5) {
                    HStack(spacing: 0.5) {
                        miniTile(images.count > 0 ? images[0] : nil, size: half)
                        miniTile(images.count > 1 ? images[1] : nil, size: half)
                    }
                    HStack(spacing: 0.5) {
                        miniTile(images.count > 2 ? images[2] : nil, size: half)
                        miniTile(images.count > 3 ? images[3] : nil, size: half)
                    }
                }
            }
            .background(Color(NSColor.separatorColor).opacity(0.3))
        }
    }

    private func miniTile(_ image: NSImage?, size: CGFloat) -> some View {
        Group {
            if let img = image {
                Image(nsImage: img).resizable().scaledToFill()
                    .frame(width: size, height: size).clipped()
            } else {
                Color(NSColor.separatorColor).opacity(0.2)
                    .frame(width: size, height: size)
            }
        }
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
