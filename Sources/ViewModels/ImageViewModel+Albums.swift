import AppKit
import Foundation

// MARK: - Albums

extension ImageViewModel {

    func selectAlbum(_ album: Album) {
        Log.info("Album gewählt: '\(album.name)' (\(album.photoURLs.count) Fotos)")
        let albumID = album.id
        let photoURLs = album.photoURLs

        navSelection = .album(albumID)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let missing = photoURLs.filter { url in
                !self.collection.documents.contains(where: { $0.url == url })
            }
            if !missing.isEmpty {
                Log.info("Importiere \(missing.count) fehlende Album-Fotos")
                let newDocs = missing
                    .filter { self.isSupportedFormat($0) }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                    .map { ImageDocument(url: $0) }
                if !newDocs.isEmpty {
                    self.collection.appendDocuments(newDocs)
                }
            }

            if let firstURL = photoURLs.first,
               let idx = self.collection.documents.firstIndex(where: { $0.url == firstURL }) {
                Log.info("Wähle erstes Album-Foto bei Index \(idx)")
                self.collection.select(index: idx)
                self.loadCurrentImage()
            }
        }
    }

    func createAlbum(name: String) {
        let album = Album(name: name)
        library.albums.append(album)
        library.saveAlbums()
        CatalogStore.shared.saveAlbum(id: album.id.uuidString, name: album.name)
        navSelection = .album(album.id) as NavSelection?
        syncAlbumToFilesystem(album)
    }

    func deleteAlbum(_ album: Album) {
        removeAlbumFromFilesystem(album)
        library.albums.removeAll { $0.id == album.id }
        if navSelection == .album(album.id) { navSelection = .library as NavSelection? }
        library.saveAlbums()
        CatalogStore.shared.deleteAlbum(id: album.id.uuidString)
    }

    func deleteSelectedSidebarAlbums() {
        let ids = sidebarSelectedAlbumIDs
        guard ids.count > 1 else { return }
        let toDelete = library.albums.filter { ids.contains($0.id) }
        for album in toDelete {
            removeAlbumFromFilesystem(album)
            CatalogStore.shared.deleteAlbum(id: album.id.uuidString)
        }
        library.albums.removeAll { ids.contains($0.id) }
        if case .album(let id) = navSelection, ids.contains(id) { navSelection = .library }
        library.saveAlbums()
        sidebarSelectedAlbumIDs = []
        sidebarAnchorAlbumID = nil
    }

    func renameAlbum(_ album: Album, to name: String) {
        guard let idx = library.albums.firstIndex(where: { $0.id == album.id }) else { return }
        let oldDir = albumSystemPath(for: album)
        library.albums[idx].name = name
        library.saveAlbums()
        CatalogStore.shared.saveAlbum(id: album.id.uuidString, name: name)
        syncAlbumToFilesystem(library.albums[idx], removingOldAt: oldDir)
    }

    func setCoverPhoto(_ url: URL, forAlbum album: Album) {
        guard let idx = library.albums.firstIndex(where: { $0.id == album.id }) else { return }
        library.albums[idx].coverPhotoURL = url
        library.saveAlbums()
    }

    func updateAlbum(_ album: Album, name: String, description: String?) {
        guard let idx = library.albums.firstIndex(where: { $0.id == album.id }) else { return }
        let nameChanged = library.albums[idx].name != name
        let oldDir = nameChanged ? albumSystemPath(for: library.albums[idx]) : nil
        library.albums[idx].name = name
        library.albums[idx].albumDescription = description?.isEmpty == false ? description : nil
        library.saveAlbums()
        if nameChanged {
            CatalogStore.shared.saveAlbum(id: album.id.uuidString, name: name)
            syncAlbumToFilesystem(library.albums[idx], removingOldAt: oldDir)
        }
    }

    func addToAlbum(_ document: ImageDocument, albumID: UUID) {
        guard let idx = library.albums.firstIndex(where: { $0.id == albumID }) else { return }
        guard !library.albums[idx].photoURLs.contains(document.url) else { return }
        library.albums[idx].photoURLs.append(document.url)
        library.saveAlbums()
        CatalogStore.shared.addImage(path: document.url.path, toAlbum: albumID.uuidString,
                                     order: library.albums[idx].photoURLs.count - 1)
        syncAlbumToFilesystem(library.albums[idx])
    }

    func addSelectedToAlbum(albumID: UUID) {
        guard let idx = library.albums.firstIndex(where: { $0.id == albumID }) else { return }
        for colIdx in collection.selectedIndices {
            guard colIdx < collection.documents.count else { continue }
            let url = collection.documents[colIdx].url
            guard !library.albums[idx].photoURLs.contains(url) else { continue }
            library.albums[idx].photoURLs.append(url)
            CatalogStore.shared.addImage(path: url.path, toAlbum: albumID.uuidString,
                                         order: library.albums[idx].photoURLs.count - 1)
        }
        library.saveAlbums()
        syncAlbumToFilesystem(library.albums[idx])
    }

    func removeFromAlbum(_ document: ImageDocument, albumID: UUID) {
        guard let idx = library.albums.firstIndex(where: { $0.id == albumID }) else { return }
        library.albums[idx].photoURLs.removeAll { $0 == document.url }
        library.saveAlbums()
        CatalogStore.shared.removeImage(path: document.url.path, fromAlbum: albumID.uuidString)
        syncAlbumToFilesystem(library.albums[idx])
    }

    func removeURLsFromAllAlbums(_ urls: Set<URL>) {
        var changed = false
        for idx in library.albums.indices {
            let before = library.albums[idx].photoURLs.count
            library.albums[idx].photoURLs.removeAll { urls.contains($0) }
            if library.albums[idx].photoURLs.count != before { changed = true }
        }
        if changed { library.saveAlbums() }
    }

    func purgeStaleAlbumReferences() {
        var changed = false
        for idx in library.albums.indices {
            let before = library.albums[idx].photoURLs.count
            library.albums[idx].photoURLs.removeAll { !FileManager.default.fileExists(atPath: $0.path) }
            if library.albums[idx].photoURLs.count != before { changed = true }
        }
        if changed { library.saveAlbums() }
    }

    // MARK: - Album Filesystem Sync

    static let albumsSystemFolderName = "Alben"

    var albumsSystemRoot: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
            .appendingPathComponent(Self.albumsSystemFolderName)
    }

    func albumSystemPath(for album: Album) -> URL {
        albumsSystemRoot.appendingPathComponent(album.name)
    }

    // Manifest maps source-path → dest-filename so we never compare file content.
    private static let manifestFilename = ".iphoto_manifest.json"

    private func loadManifest(at dir: URL) -> [String: String] {
        let url = dir.appendingPathComponent(Self.manifestFilename)
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }

    private func saveManifest(_ manifest: [String: String], at dir: URL) {
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: dir.appendingPathComponent(Self.manifestFilename))
    }

    func syncAlbumToFilesystem(_ album: Album, removingOldAt oldDir: URL? = nil) {
        let photoURLs = album.photoURLs
        let dir = albumSystemPath(for: album)
        let capturedOld = oldDir

        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            if let old = capturedOld {
                try? fm.removeItem(at: old)
            }
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

            var manifest = self.loadManifest(at: dir)
            let wantedPaths = Set(photoURLs.map { $0.standardized.path })

            // Remove dest files whose source is no longer in the album
            for (srcPath, destName) in manifest where !wantedPaths.contains(srcPath) {
                try? fm.removeItem(at: dir.appendingPathComponent(destName))
                manifest.removeValue(forKey: srcPath)
            }
            // Migrate any old symlinks to real files (backward compat)
            if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
                for link in contents where link.lastPathComponent != Self.manifestFilename {
                    guard (try? link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true else { continue }
                    if let dest = try? fm.destinationOfSymbolicLink(atPath: link.path) {
                        let srcURL = URL(fileURLWithPath: dest).standardized
                        try? fm.removeItem(at: link)
                        if wantedPaths.contains(srcURL.path) {
                            try? fm.copyItem(at: srcURL, to: link)
                        }
                    } else {
                        try? fm.removeItem(at: link)
                    }
                }
            }

            // Copy photos not yet in manifest (or claim pre-existing files for migration)
            var usedNames = Set(manifest.values)
            for photoURL in photoURLs {
                let srcPath = photoURL.standardized.path
                if let destName = manifest[srcPath] {
                    let destURL = dir.appendingPathComponent(destName)
                    if fm.fileExists(atPath: destURL.path) {
                        // Re-copy only if source was modified after the destination (stale copy).
                        let srcMtime = (try? fm.attributesOfItem(atPath: srcPath))?[.modificationDate] as? Date
                        let dstMtime = (try? fm.attributesOfItem(atPath: destURL.path))?[.modificationDate] as? Date
                        if let s = srcMtime, let d = dstMtime, s <= d { continue }
                        // Fall through to re-copy.
                        try? fm.removeItem(at: destURL)
                    }
                }
                // Find a unique dest filename
                var destName = photoURL.lastPathComponent
                var counter  = 1
                while usedNames.contains(destName) {
                    let base = (photoURL.lastPathComponent as NSString).deletingPathExtension
                    let ext  = (photoURL.lastPathComponent as NSString).pathExtension
                    destName = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
                    counter += 1
                }
                let destURL = dir.appendingPathComponent(destName)
                if fm.fileExists(atPath: destURL.path) {
                    // Pre-existing file (from old sync) — claim it without re-copying
                    manifest[srcPath] = destName
                    usedNames.insert(destName)
                } else if (try? fm.copyItem(at: photoURL, to: destURL)) != nil {
                    manifest[srcPath] = destName
                    usedNames.insert(destName)
                }
            }

            self.saveManifest(manifest, at: dir)
            Log.info("Album Filesystem-Sync: \"\(album.name)\" → \(photoURLs.count) Dateien in \(dir.path)")
        }
    }

    private func removeAlbumFromFilesystem(_ album: Album) {
        let dir = albumSystemPath(for: album)
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: dir)
        }
    }
}
