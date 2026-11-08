import Foundation

// MARK: - Album-Ordner (Container für Alben und weitere AlbumFolders)
//
// AlbumFolder hat selbst keine Fotos — Klick auf einen Ordner aggregiert alle
// Fotos aus enthaltenen Alben rekursiv (siehe ImageViewModel+Context.swift).
// Fürs Filesystem-Sync (Symlink-Ordner unter ~/Pictures/iPhoto/Alben/) verwenden
// wir nur die Album-Namen — Ordner sind eine UI-Ebene, kein Ordnungssystem auf Disk.

extension ImageViewModel {

    // MARK: - Read helpers

    /// Direkte Kind-Ordner eines Ordners (nil = Root-Ebene).
    func childFolders(of parentID: UUID?) -> [AlbumFolder] {
        library.albumFolders
            .filter { $0.parentID == parentID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Direkte Kind-Alben eines Ordners (nil = Root-Ebene).
    func childAlbums(of parentID: UUID?) -> [Album] {
        library.albums
            .filter { $0.parentID == parentID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Alle Album-IDs unterhalb eines Ordners (rekursiv). Wird von visibleDocuments
    /// genutzt, um beim Klick auf einen Ordner alle Fotos zu aggregieren.
    /// Cycle-safe durch Visited-Set — sollte durch die Move-API zwar nie eintreten,
    /// aber verhindert Endlosschleifen bei manipulierter JSON.
    func collectDescendantAlbumIDs(folderID: UUID) -> Set<UUID> {
        var albumIDs = Set<UUID>()
        var visitedFolders = Set<UUID>()
        var stack: [UUID] = [folderID]
        while let current = stack.popLast() {
            guard visitedFolders.insert(current).inserted else { continue }
            for album in library.albums where album.parentID == current {
                albumIDs.insert(album.id)
            }
            for sub in library.albumFolders where sub.parentID == current {
                stack.append(sub.id)
            }
        }
        return albumIDs
    }

    // MARK: - Create / Rename / Delete

    func createAlbumFolder(name: String, parentID: UUID? = nil) {
        let folder = AlbumFolder(name: name, parentID: parentID)
        library.albumFolders.append(folder)
        library.saveAlbumFolders()
        navSelection = .albumFolder(folder.id) as NavSelection?
    }

    func renameAlbumFolder(_ folder: AlbumFolder, to name: String) {
        guard let idx = library.albumFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        library.albumFolders[idx].name = name
        library.saveAlbumFolders()
    }

    /// Löscht einen Ordner. Enthaltene Alben und Sub-Ordner werden auf den Parent
    /// des gelöschten Ordners hochgezogen (verhindert Datenverlust — Nutzer erwartet
    /// „Ordner weg", nicht „Alben weg").
    func deleteAlbumFolder(_ folder: AlbumFolder) {
        let newParent = folder.parentID
        var albums = library.albums
        for i in albums.indices where albums[i].parentID == folder.id {
            albums[i].parentID = newParent
        }
        library.albums = albums
        var folders = library.albumFolders
        for i in folders.indices where folders[i].parentID == folder.id {
            folders[i].parentID = newParent
        }
        folders.removeAll { $0.id == folder.id }
        library.albumFolders = folders
        if navSelection == .albumFolder(folder.id) { navSelection = .library as NavSelection? }
        library.saveAlbumFolders()
        library.saveAlbums()
    }

    // MARK: - Move

    /// Verschiebt ein Album in einen Ordner (nil = Root).
    func moveAlbum(_ album: Album, into newParentID: UUID?) {
        guard let idx = library.albums.firstIndex(where: { $0.id == album.id }) else { return }
        guard library.albums[idx].parentID != newParentID else { return }
        // Ziel-Ordner muss existieren (oder nil sein).
        if let parent = newParentID,
           !library.albumFolders.contains(where: { $0.id == parent }) { return }
        library.albums[idx].parentID = newParentID
        library.saveAlbums()
    }

    /// Verschiebt einen Ordner in einen anderen (nil = Root). Verhindert Zyklen:
    /// ein Ordner darf nicht in sich selbst oder einen seiner Nachfahren verschoben werden.
    func moveAlbumFolder(_ folder: AlbumFolder, into newParentID: UUID?) {
        guard let idx = library.albumFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        guard library.albumFolders[idx].parentID != newParentID else { return }
        if let parent = newParentID {
            // Ziel muss existieren
            guard library.albumFolders.contains(where: { $0.id == parent }) else { return }
            // Zyklus-Schutz: Nachfahren dürfen nicht Vorfahre werden
            if parent == folder.id { return }
            let descendants = collectDescendantFolderIDs(folderID: folder.id)
            if descendants.contains(parent) { return }
        }
        library.albumFolders[idx].parentID = newParentID
        library.saveAlbumFolders()
    }

    private func collectDescendantFolderIDs(folderID: UUID) -> Set<UUID> {
        var result = Set<UUID>()
        var stack: [UUID] = [folderID]
        while let cur = stack.popLast() {
            for f in library.albumFolders where f.parentID == cur {
                if result.insert(f.id).inserted { stack.append(f.id) }
            }
        }
        return result
    }

    // MARK: - Selection

    func selectAlbumFolder(_ folder: AlbumFolder) {
        navSelection = .albumFolder(folder.id)
    }
}
