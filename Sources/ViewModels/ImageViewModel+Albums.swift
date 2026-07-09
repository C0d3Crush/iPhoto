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
                    self.loadThumbnails()
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
        albums.append(album)
        saveAlbums()
        CatalogStore.shared.saveAlbum(id: album.id.uuidString, name: album.name)
        navSelection = .album(album.id) as NavSelection?
        syncAlbumToFilesystem(album)
    }

    func deleteAlbum(_ album: Album) {
        removeAlbumFromFilesystem(album)
        albums.removeAll { $0.id == album.id }
        if navSelection == .album(album.id) { navSelection = .library as NavSelection? }
        saveAlbums()
        CatalogStore.shared.deleteAlbum(id: album.id.uuidString)
    }

    func renameAlbum(_ album: Album, to name: String) {
        guard let idx = albums.firstIndex(where: { $0.id == album.id }) else { return }
        let oldDir = albumSystemPath(for: album)
        albums[idx].name = name
        saveAlbums()
        CatalogStore.shared.saveAlbum(id: album.id.uuidString, name: name)
        syncAlbumToFilesystem(albums[idx], removingOldAt: oldDir)
    }

    func addToAlbum(_ document: ImageDocument, albumID: UUID) {
        guard let idx = albums.firstIndex(where: { $0.id == albumID }) else { return }
        guard !albums[idx].photoURLs.contains(document.url) else { return }
        albums[idx].photoURLs.append(document.url)
        saveAlbums()
        CatalogStore.shared.addImage(path: document.url.path, toAlbum: albumID.uuidString,
                                     order: albums[idx].photoURLs.count - 1)
        syncAlbumToFilesystem(albums[idx])
    }

    func addSelectedToAlbum(albumID: UUID) {
        guard let idx = albums.firstIndex(where: { $0.id == albumID }) else { return }
        for colIdx in collection.selectedIndices {
            guard colIdx < collection.documents.count else { continue }
            let url = collection.documents[colIdx].url
            guard !albums[idx].photoURLs.contains(url) else { continue }
            albums[idx].photoURLs.append(url)
            CatalogStore.shared.addImage(path: url.path, toAlbum: albumID.uuidString,
                                         order: albums[idx].photoURLs.count - 1)
        }
        saveAlbums()
        syncAlbumToFilesystem(albums[idx])
    }

    func removeFromAlbum(_ document: ImageDocument, albumID: UUID) {
        guard let idx = albums.firstIndex(where: { $0.id == albumID }) else { return }
        albums[idx].photoURLs.removeAll { $0 == document.url }
        saveAlbums()
        CatalogStore.shared.removeImage(path: document.url.path, fromAlbum: albumID.uuidString)
        syncAlbumToFilesystem(albums[idx])
    }

    private var albumsFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("albums.json")
    }

    func loadAlbums() {
        guard let data = try? Data(contentsOf: albumsFileURL),
              let decoded = try? JSONDecoder().decode([Album].self, from: data) else { return }
        albums = decoded
        // Backward compat: create filesystem directories for all existing albums
        for album in albums { syncAlbumToFilesystem(album) }
    }

    func saveAlbums() {
        guard let data = try? JSONEncoder().encode(albums) else { return }
        persistFileData(data, to: albumsFileURL, description: "Album-Datei")
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

            let targetPaths = Set(photoURLs.map { $0.standardized.path })

            // Remove stale symlinks
            if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
                for link in contents {
                    guard (try? link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true else { continue }
                    let target = (try? fm.destinationOfSymbolicLink(atPath: link.path)).map {
                        URL(fileURLWithPath: $0).standardized.path
                    }
                    if target.map({ !targetPaths.contains($0) }) ?? true {
                        try? fm.removeItem(at: link)
                    }
                }
            }

            // Add new symlinks
            var existingLinks = Set((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [])
            for photoURL in photoURLs {
                var linkName = photoURL.lastPathComponent
                var counter  = 1
                while existingLinks.contains(linkName) {
                    let base = (photoURL.lastPathComponent as NSString).deletingPathExtension
                    let ext  = (photoURL.lastPathComponent as NSString).pathExtension
                    linkName = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
                    counter += 1
                }
                let linkURL = dir.appendingPathComponent(linkName)
                if !fm.fileExists(atPath: linkURL.path, isDirectory: nil) {
                    try? fm.createSymbolicLink(at: linkURL, withDestinationURL: photoURL)
                    existingLinks.insert(linkName)
                }
            }
            Log.info("Album Filesystem-Sync: \"\(album.name)\" → \(photoURLs.count) Symlinks in \(dir.path)")
        }
    }

    private func removeAlbumFromFilesystem(_ album: Album) {
        let dir = albumSystemPath(for: album)
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: dir)
        }
    }
}
