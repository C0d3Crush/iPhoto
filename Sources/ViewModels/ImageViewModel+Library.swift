import AppKit
import Foundation

// MARK: - Library: Navigation Context

extension ImageViewModel {

    var visibleDocuments: [ImageDocument] {
        switch navSelection {
        case .library, nil:
            return collection.documents
        case .album(let id):
            guard let album = albums.first(where: { $0.id == id }) else { return [] }
            return collection.documents.filter { album.photoURLs.contains($0.url) }
        case .folder(let id):
            guard let folder = watchedFolders.first(where: { $0.id == id }),
                  let (folderURL, stop) = folder.resolveURL() else { return [] }
            defer { stop() }
            let prefix = folderURL.standardized.path
            return collection.documents.filter { $0.url.standardized.path.hasPrefix(prefix) }
        case .smartFolder(let id):
            guard let sf = smartFolders.first(where: { $0.id == id }) else { return [] }
            return collection.documents.filter { smartFolderMatches($0, sf: sf) }
        case .volume(let id):
            guard let volume = detectedVolumes.first(where: { $0.id == id }) else { return [] }
            let prefix = volume.url.standardized.path
            return collection.documents.filter { $0.url.standardized.path.hasPrefix(prefix) }
        }
    }

    func smartFolderMatches(_ doc: ImageDocument, sf: SmartFolder) -> Bool {
        guard !sf.criteria.isEmpty else { return true }
        let results = sf.criteria.map { c -> Bool in
            switch c.attribute {
            case .flag:
                return applyEnumOp(c.op, lhs: doc.flagStatus, rhs: c.flagValue)
            case .colorLabel:
                return applyEnumOp(c.op, lhs: doc.colorLabel, rhs: c.colorValue)
            case .isRAW:
                return applyEnumOp(c.op, lhs: doc.isRAW, rhs: c.boolValue)
            case .orientation:
                let size: CGSize
                if doc.imageSize != .zero {
                    size = doc.imageSize
                } else if let entry = CatalogStore.shared.image(forPath: doc.url.path),
                          entry.width > 0, entry.height > 0 {
                    size = CGSize(width: entry.width, height: entry.height)
                } else {
                    return false
                }
                let isPortrait = size.height > size.width
                return applyEnumOp(c.op, lhs: isPortrait, rhs: c.boolValue)
            case .hdr:
                let inMemHDR = doc.metadata.first(where: { $0.key == "exif.HDR" })?.value
                let isHDR: Bool
                if let v = inMemHDR {
                    isHDR = (v == "Ja")
                } else {
                    isHDR = CatalogStore.shared.exif(forPath: doc.url.path)?.hdr ?? false
                }
                return applyEnumOp(c.op, lhs: isHDR, rhs: c.boolValue)
            case .rating:
                return applyNumericOp(c.op, value: Double(doc.rating), lo: Double(c.ratingValue), hi: Double(c.ratingValue2))
            case .iso:
                if let v = metadataDouble(doc, key: "exif.ISO", prefix: "ISO ") {
                    return applyNumericOp(c.op, value: v, lo: c.numericValue, hi: c.numericValue2)
                } else if let exif = CatalogStore.shared.exif(forPath: doc.url.path), let iso = exif.iso {
                    return applyNumericOp(c.op, value: Double(iso), lo: c.numericValue, hi: c.numericValue2)
                }
                return false
            case .focalLength:
                if let v = metadataDouble(doc, key: "exif.FocalLength", suffix: " mm") {
                    return applyNumericOp(c.op, value: v, lo: c.numericValue, hi: c.numericValue2)
                } else if let exif = CatalogStore.shared.exif(forPath: doc.url.path), let fl = exif.focalLength {
                    return applyNumericOp(c.op, value: fl, lo: c.numericValue, hi: c.numericValue2)
                }
                return false
            case .aperture:
                if let v = metadataDouble(doc, key: "exif.FNumber", prefix: "f/") {
                    return applyNumericOp(c.op, value: v, lo: c.numericValue, hi: c.numericValue2)
                } else if let exif = CatalogStore.shared.exif(forPath: doc.url.path), let ap = exif.aperture {
                    return applyNumericOp(c.op, value: ap, lo: c.numericValue, hi: c.numericValue2)
                }
                return false
            case .cameraMake:
                return applyTextOp(c.op, haystack: catalogExifString(doc, key: "tiff.Make"), needle: c.textValue)
            case .cameraModel:
                return applyTextOp(c.op, haystack: catalogExifString(doc, key: "tiff.Model"), needle: c.textValue)
            case .lens:
                return applyTextOp(c.op, haystack: catalogExifString(doc, key: "exif.LensModel"), needle: c.textValue)
            case .captureDate:
                let raw = metadataString(doc, key: "exif.DateTimeOriginal")
                let dateStr = raw.isEmpty ? (CatalogStore.shared.image(forPath: doc.url.path)?.dateTaken ?? "") : raw
                guard !dateStr.isEmpty, let date = parseExifDate(dateStr) else { return false }
                return applyDateOp(c.op, date: date, lo: c.dateValue, hi: c.dateValue2, dynamic: c.dynamicDateRange)
            case .filename:
                return applyTextOp(c.op, haystack: doc.filename, needle: c.textValue)
            case .album:
                guard let albumID = UUID(uuidString: c.textValue),
                      let album = albums.first(where: { $0.id == albumID }) else { return false }
                let inAlbum = album.photoURLs.contains(doc.url)
                return applyEnumOp(c.op, lhs: inAlbum, rhs: true)
            }
        }
        return sf.matchAll ? results.allSatisfy { $0 } : results.contains { $0 }
    }

    private func applyEnumOp<T: Equatable>(_ op: SmartFolderOperator, lhs: T, rhs: T) -> Bool {
        switch op {
        case .isExact: return lhs == rhs
        case .isNot:   return lhs != rhs
        default:       return false
        }
    }

    private func applyNumericOp(_ op: SmartFolderOperator, value: Double, lo: Double, hi: Double) -> Bool {
        switch op {
        case .isExact:     return value == lo
        case .isNot:       return value != lo
        case .greaterThan: return value > lo
        case .lessThan:    return value < lo
        case .inRange:     return value >= lo && value <= hi
        default:           return false
        }
    }

    private func applyTextOp(_ op: SmartFolderOperator, haystack: String, needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        switch op {
        case .contains:    return haystack.localizedCaseInsensitiveContains(needle)
        case .notContains: return !haystack.localizedCaseInsensitiveContains(needle)
        case .isExact:     return haystack.localizedCaseInsensitiveCompare(needle) == .orderedSame
        case .isNot:       return haystack.localizedCaseInsensitiveCompare(needle) != .orderedSame
        case .beginsWith:  return haystack.lowercased().hasPrefix(needle.lowercased())
        case .endsWith:    return haystack.lowercased().hasSuffix(needle.lowercased())
        default:           return false
        }
    }

    private func metadataString(_ doc: ImageDocument, key: String) -> String {
        doc.metadata.first(where: { $0.key == key })?.value ?? ""
    }

    private func catalogExifString(_ doc: ImageDocument, key: String) -> String {
        let inMem = metadataString(doc, key: key)
        if !inMem.isEmpty { return inMem }
        let exif = CatalogStore.shared.exif(forPath: doc.url.path)
        switch key {
        case "tiff.Make":       return CatalogStore.shared.image(forPath: doc.url.path)?.cameraMake ?? ""
        case "tiff.Model":      return CatalogStore.shared.image(forPath: doc.url.path)?.cameraModel ?? ""
        case "exif.LensModel":  return exif?.lensModel ?? ""
        default:                return ""
        }
    }

    private func parseExifDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f.date(from: s)
    }

    private func applyDateOp(_ op: SmartFolderOperator, date: Date, lo: Date, hi: Date, dynamic: DynamicDateRange) -> Bool {
        switch op {
        case .isBefore:    return date < lo
        case .isAfter:     return date > lo
        case .inDateRange: return date >= lo && date <= hi
        case .isDynamic:   return dynamic.matches(date)
        default:           return false
        }
    }

    private func metadataDouble(_ doc: ImageDocument, key: String, prefix: String = "", suffix: String = "") -> Double? {
        guard let raw = doc.metadata.first(where: { $0.key == key })?.value else { return nil }
        var s = raw
        if !prefix.isEmpty, s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)) }
        if !suffix.isEmpty, s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)) }
        return Double(s.trimmingCharacters(in: .whitespaces))
    }

    // Re-evaluates current selection against the active context filter.
    // Call after any change that might invalidate the current document (e.g. SmartFolder edit).
    func revalidateSelectionForCurrentContext() {
        let visible = visibleDocuments
        let curInVisible = collection.currentDocument.map { doc in
            visible.contains(where: { $0.id == doc.id })
        } ?? false
        guard !curInVisible else { return }

        // Nächstbestes Bild: das im Collection-Index direkt nach dem entfernten,
        // Fallback auf das davor.
        let removedIdx = collection.currentIndex
        let candidates = visible.compactMap { doc -> (doc: ImageDocument, colIdx: Int)? in
            guard let i = collectionIndex(for: doc) else { return nil }
            return (doc, i)
        }
        let next = candidates.filter { $0.colIdx > removedIdx }.min(by: { $0.colIdx < $1.colIdx })
                ?? candidates.filter { $0.colIdx < removedIdx }.max(by: { $0.colIdx < $1.colIdx })

        if let best = next {
            collection.select(index: best.colIdx)
            loadCurrentImage()
        } else {
            collection.selectedIndices = []
        }
    }
}

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

// MARK: - Smart Folders

extension ImageViewModel {

    func createSmartFolder(_ sf: SmartFolder) {
        smartFolders.append(sf)
        saveSmartFolders()
        navSelection = .smartFolder(sf.id)
        syncSmartFolderToFilesystem(sf)
    }

    func deleteSmartFolder(_ sf: SmartFolder) {
        removeSmartFolderFromFilesystem(sf)
        smartFolders.removeAll { $0.id == sf.id }
        if navSelection == .smartFolder(sf.id) { navSelection = .library }
        saveSmartFolders()
    }

    func updateSmartFolder(_ sf: SmartFolder) {
        guard let idx = smartFolders.firstIndex(where: { $0.id == sf.id }) else { return }
        let old = smartFolders[idx]
        let oldDir: URL? = (old.name != sf.name || old.group != sf.group)
            ? smartFolderSystemPath(for: old)
            : nil
        let oldGroup = old.group
        smartFolders[idx] = sf
        saveSmartFolders()
        syncSmartFolderToFilesystem(sf, removingOldAt: oldDir)
        // Clean up empty old group directory in BG if group changed
        if let grp = oldGroup, grp != sf.group {
            let groupDir = smartFoldersSystemRoot.appendingPathComponent(grp)
            DispatchQueue.global(qos: .utility).async {
                let fm = FileManager.default
                if let contents = try? fm.contentsOfDirectory(atPath: groupDir.path), contents.isEmpty {
                    try? fm.removeItem(at: groupDir)
                }
            }
        }
        if case .smartFolder(let selectedID) = navSelection, selectedID == sf.id {
            revalidateSelectionForCurrentContext()
        }
    }

    // MARK: - Smart Folder Group Operations

    func moveSmartFolder(_ sf: SmartFolder, toGroup group: String?) {
        guard let idx = smartFolders.firstIndex(where: { $0.id == sf.id }) else { return }
        let old = smartFolders[idx]
        let oldDir = smartFolderSystemPath(for: old)
        let oldGroup = old.group
        smartFolders[idx].group = group
        saveSmartFolders()
        syncSmartFolderToFilesystem(smartFolders[idx], removingOldAt: oldDir)
        // Remove empty old group dir
        if let grp = oldGroup {
            let groupDir = smartFoldersSystemRoot.appendingPathComponent(grp)
            DispatchQueue.global(qos: .utility).async {
                let fm = FileManager.default
                if let contents = try? fm.contentsOfDirectory(atPath: groupDir.path), contents.isEmpty {
                    try? fm.removeItem(at: groupDir)
                }
            }
        }
    }

    func renameGroup(_ oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != oldName else { return }
        let oldGroupDir = smartFoldersSystemRoot.appendingPathComponent(oldName)
        let newGroupDir = smartFoldersSystemRoot.appendingPathComponent(trimmed)
        for idx in smartFolders.indices where smartFolders[idx].group == oldName {
            smartFolders[idx].group = trimmed
        }
        saveSmartFolders()
        // Move entire group directory on filesystem
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            if fm.fileExists(atPath: oldGroupDir.path) {
                try? fm.moveItem(at: oldGroupDir, to: newGroupDir)
            }
        }
        // Re-sync all smart folders in the renamed group
        for sf in smartFolders where sf.group == trimmed {
            syncSmartFolderToFilesystem(sf)
        }
    }

    func dissolveGroup(_ groupName: String) {
        for idx in smartFolders.indices where smartFolders[idx].group == groupName {
            let old = smartFolders[idx]
            let oldDir = smartFolderSystemPath(for: old)
            smartFolders[idx].group = nil
            syncSmartFolderToFilesystem(smartFolders[idx], removingOldAt: oldDir)
        }
        saveSmartFolders()
        // Remove the (now-empty) group directory
        let groupDir = smartFoldersSystemRoot.appendingPathComponent(groupName)
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: groupDir)
        }
    }

    // MARK: - Smart Folder Filesystem Sync

    static let smartFoldersSystemFolderName = "Intelligente Ordner"

    var smartFoldersSystemRoot: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
            .appendingPathComponent(Self.smartFoldersSystemFolderName)
    }

    func smartFolderSystemPath(for sf: SmartFolder) -> URL {
        if let grp = sf.group, !grp.isEmpty {
            return smartFoldersSystemRoot.appendingPathComponent(grp).appendingPathComponent(sf.name)
        }
        return smartFoldersSystemRoot.appendingPathComponent(sf.name)
    }

    func syncSmartFolderToFilesystem(_ sf: SmartFolder, removingOldAt oldDir: URL? = nil) {
        // Filter on the calling thread (always main) — collection.documents must not be
        // read from a background thread while main writes it (data race → SIGSEGV).
        let matchURLs    = Set(collection.documents.filter { smartFolderMatches($0, sf: sf) }.map { $0.url.standardized.path })
        let matchDocURLs = collection.documents.filter { smartFolderMatches($0, sf: sf) }.map { $0.url }
        let sfName       = sf.name
        let dir          = smartFolderSystemPath(for: sf)
        let capturedOld  = oldDir

        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            if let old = capturedOld {
                try? fm.removeItem(at: old)
                // Remove empty parent group dir of old location
                let oldParent = old.deletingLastPathComponent()
                if oldParent.path != self.smartFoldersSystemRoot.path,
                   let contents = try? fm.contentsOfDirectory(atPath: oldParent.path),
                   contents.isEmpty {
                    try? fm.removeItem(at: oldParent)
                }
            }
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

            // Veraltete Symlinks entfernen
            if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
                for link in contents {
                    guard (try? link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true else { continue }
                    let target = (try? fm.destinationOfSymbolicLink(atPath: link.path)).map {
                        URL(fileURLWithPath: $0).standardized.path
                    }
                    if target.map({ !matchURLs.contains($0) }) ?? true {
                        try? fm.removeItem(at: link)
                    }
                }
            }

            // Neue Symlinks anlegen
            var existingLinks = Set((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [])
            for docURL in matchDocURLs {
                var linkName = docURL.lastPathComponent
                var counter  = 1
                while existingLinks.contains(linkName) {
                    let base = (docURL.lastPathComponent as NSString).deletingPathExtension
                    let ext  = (docURL.lastPathComponent as NSString).pathExtension
                    linkName = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
                    counter += 1
                }
                let linkURL = dir.appendingPathComponent(linkName)
                if !fm.fileExists(atPath: linkURL.path, isDirectory: nil) {
                    try? fm.createSymbolicLink(at: linkURL, withDestinationURL: docURL)
                    existingLinks.insert(linkName)
                }
            }
            Log.info("iOrdner Filesystem-Sync: \"\(sfName)\" → \(matchDocURLs.count) Symlinks in \(dir.path)")
        }
    }

    private func removeSmartFolderFromFilesystem(_ sf: SmartFolder) {
        let dir = smartFolderSystemPath(for: sf)
        let groupDir: URL? = sf.group.flatMap { grp in
            grp.isEmpty ? nil : smartFoldersSystemRoot.appendingPathComponent(grp)
        }
        try? FileManager.default.removeItem(at: dir)
        // Remove empty group dir
        if let gd = groupDir {
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(atPath: gd.path), contents.isEmpty {
                try? fm.removeItem(at: gd)
            }
        }
    }

    private var smartFoldersFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("smartFolders.json")
    }

    func loadSmartFolders() {
        guard let data = try? Data(contentsOf: smartFoldersFileURL),
              let decoded = try? JSONDecoder().decode([SmartFolder].self, from: data) else { return }
        smartFolders = decoded
    }

    func saveSmartFolders() {
        guard let data = try? JSONEncoder().encode(smartFolders) else { return }
        persistFileData(data, to: smartFoldersFileURL, description: "SmartFolder-Datei")
    }
}

// MARK: - Watched Folders

extension ImageViewModel {

    func addFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Ordner hinzufügen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !watchedFolders.contains(where: { $0.resolveURL()?.url.standardized == url.standardized }) else { return }
        guard let folder = try? WatchedFolder(url: url) else { return }
        watchedFolders.append(folder)
        if folder.isRemovableMedia {
            let libraryPath = FileManager.default
                .urls(for: .picturesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("iPhoto").path
            watchedFolders[watchedFolders.count - 1].importDestinationPath = libraryPath
        }
        saveWatchedFolders()
        syncFolder(folder)
        startWatching(folder)
        navSelection = .folder(folder.id)
    }

    func deleteWatchedFolder(_ folder: WatchedFolder) {
        guard !folder.isDefaultLibrary else { return }
        stopWatching(folder)
        syncedFolderIDs.remove(folder.id)
        watchedFolders.removeAll { $0.id == folder.id }
        if let (folderURL, stop) = folder.resolveURL() {
            let prefix = folderURL.standardized.path
            stop()
            collection.documents.removeAll { $0.url.standardized.path.hasPrefix(prefix) }
        }
        if navSelection == .folder(folder.id) { navSelection = .library }
        saveWatchedFolders()
    }

    func toggleAutoSync(for folder: WatchedFolder) {
        guard let idx = watchedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        watchedFolders[idx].autoSync.toggle()
        saveWatchedFolders()
    }

    func setImportDestination(for folder: WatchedFolder, path: String?) {
        guard let idx = watchedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        watchedFolders[idx].importDestinationPath = path
        saveWatchedFolders()

        guard let path = path else { return }
        let destURL = URL(fileURLWithPath: path)
        let alreadyWatched = watchedFolders.contains {
            $0.bookmarkPath.map { URL(fileURLWithPath: $0).standardized } == destURL.standardized
        }
        guard !alreadyWatched, let destFolder = try? WatchedFolder(url: destURL) else { return }
        watchedFolders.append(destFolder)
        saveWatchedFolders()
        syncFolder(destFolder)
        startWatching(destFolder)
    }

    func importImages(from folder: WatchedFolder) {
        guard let (sourceURL, stop) = folder.resolveURL() else { return }

        let destURL: URL
        if let explicit = folder.importDestinationURL {
            destURL = explicit
        } else if folder.isRemovableMedia {
            destURL = FileManager.default
                .urls(for: .picturesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("iPhoto")
            setImportDestination(for: folder, path: destURL.path)
        } else {
            return
        }

        let folderID   = folder.id
        let folderName = folder.name
        importProgress[folderID] = ImportProgress(folderName: folderName, completed: 0, total: 0)
        enqueueLoading(id: folderID, label: "Synchronisiere \"\(folderName)\"",
                       icon: "arrow.down.circle", done: 0, total: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            defer { stop() }

            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: sourceURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                DispatchQueue.main.async {
                    self.importProgress.removeValue(forKey: folderID)
                    self.dequeueLoading(id: folderID)
                }
                return
            }

            var sourceFiles: [URL] = []
            for case let fileURL as URL in enumerator {
                if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                   ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    sourceFiles.append(fileURL)
                }
            }

            try? fm.createDirectory(at: destURL, withIntermediateDirectories: true)
            let existingNames = Set((try? fm.contentsOfDirectory(atPath: destURL.path).map { $0.lowercased() }) ?? [])
            let newFiles = sourceFiles.filter { !existingNames.contains($0.lastPathComponent.lowercased()) }

            DispatchQueue.main.async {
                self.importProgress[folderID] = ImportProgress(folderName: folderName, completed: 0, total: newFiles.count)
                self.updateLoading(id: folderID, done: 0, total: newFiles.count)
            }

            var completed = 0
            var failedCount = 0
            var newURLs: [URL] = []
            for file in newFiles {
                let dest = destURL.appendingPathComponent(file.lastPathComponent)
                if (try? fm.copyItem(at: file, to: dest)) != nil {
                    newURLs.append(dest)
                } else {
                    failedCount += 1
                }
                completed += 1
                let c = completed
                DispatchQueue.main.async {
                    self.importProgress[folderID] = ImportProgress(folderName: folderName, completed: c, total: newFiles.count)
                    self.updateLoading(id: folderID, done: c, total: newFiles.count)
                }
            }

            DispatchQueue.main.async {
                self.importProgress.removeValue(forKey: folderID)
                self.dequeueLoading(id: folderID)
                if !newURLs.isEmpty {
                    self.importFiles(newURLs, selectFirst: false)
                    if failedCount == 0 {
                        self.completedImports.insert(folderID)
                    }
                }
                if self.importProgress.isEmpty {
                    self.loadThumbnails()
                }
            }
        }
    }

    func wipeFolder(_ folder: WatchedFolder) {
        guard folder.isRemovableMedia,
              let (sourceURL, stop) = folder.resolveURL() else { return }
        defer { stop() }

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        var imageFiles: [URL] = []
        for case let fileURL as URL in enumerator {
            if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
               ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                imageFiles.append(fileURL)
            }
        }
        guard !imageFiles.isEmpty else {
            completedImports.remove(folder.id)
            return
        }

        if let destURL = folder.importDestinationURL {
            let destNames = Set((try? fm.contentsOfDirectory(atPath: destURL.path).map { $0.lowercased() }) ?? [])
            let missingFiles = imageFiles.filter { !destNames.contains($0.lastPathComponent.lowercased()) }
            if !missingFiles.isEmpty {
                let alert = NSAlert()
                alert.messageText = "\(missingFiles.count) Bilder nicht importiert!"
                alert.informativeText = "\(missingFiles.count) von \(imageFiles.count) Bilddateien auf der Karte wurden nicht in den Zielordner importiert. Bitte den Import erneut ausführen, bevor die Karte geleert wird."
                alert.addButton(withTitle: "OK")
                alert.alertStyle = .critical
                alert.runModal()
                return
            }
        }

        let alert = NSAlert()
        alert.messageText = "\(imageFiles.count) Bilddateien von \"\(folder.name)\" löschen?"
        alert.informativeText = "Alle Bilddateien auf dem Speichermedium werden unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden."
        alert.addButton(withTitle: "Löschen")
        alert.addButton(withTitle: "Abbrechen")
        alert.alertStyle = .critical
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        for file in imageFiles {
            try? fm.removeItem(at: file)
        }
        completedImports.remove(folder.id)
    }

    func loadContentForSelection(_ selection: NavSelection?) {
        let foldersToLoad: [WatchedFolder]
        switch selection {
        case .library, nil:
            foldersToLoad = watchedFolders.filter { !syncedFolderIDs.contains($0.id) }
        case .folder(let id):
            foldersToLoad = watchedFolders.filter { $0.id == id && !syncedFolderIDs.contains($0.id) }
        case .album:
            foldersToLoad = watchedFolders.filter { !syncedFolderIDs.contains($0.id) }
        case .smartFolder(let id):
            foldersToLoad = watchedFolders.filter { !syncedFolderIDs.contains($0.id) }
            if let sf = smartFolders.first(where: { $0.id == id }) {
                syncSmartFolderToFilesystem(sf)
            }
        case .volume(let id):
            if let vol = detectedVolumes.first(where: { $0.id == id }) {
                syncVolume(vol)
            }
            foldersToLoad = []
        }
        for folder in foldersToLoad {
            syncedFolderIDs.insert(folder.id)
            syncFolder(folder)
        }
    }

    func syncFolder(_ folder: WatchedFolder) {
        guard let (folderURL, stop) = folder.resolveURL() else { return }
        let folderID   = folder.id
        let folderName = folder.name
        DispatchQueue.main.async { self.enqueueLoading(id: folderID, label: "Lade \"\(folderName)\"", icon: "folder", done: 0, total: 0) }
        DispatchQueue.global(qos: .utility).async {
            defer { stop() }
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return }
            var found: [URL] = []
            for case let fileURL as URL in enumerator {
                // Symlink-Verzeichnisse der virtuellen Ordner überspringen
                let lastName = fileURL.lastPathComponent
                if lastName == ImageViewModel.smartFoldersSystemFolderName ||
                   lastName == ImageViewModel.albumsSystemFolderName {
                    enumerator.skipDescendants()
                    continue
                }
                let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if vals?.isRegularFile == true,
                   vals?.isSymbolicLink != true,
                   ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    found.append(fileURL)
                }
            }
            let folderPrefix = folderURL.standardized.path
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let toRemove = self.collection.documents.filter {
                    $0.url.standardized.path.hasPrefix(folderPrefix) && !found.map { $0.standardized }.contains($0.url.standardized)
                }
                self.collection.documents.removeAll { doc in toRemove.contains(where: { $0.id == doc.id }) }
                self.importFiles(found, selectFirst: false)
                self.dequeueLoading(id: folderID)
            }
        }
    }

    private func startWatching(_ folder: WatchedFolder) {
        guard let (folderURL, stop) = folder.resolveURL() else { return }
        let fd = open(folderURL.path, O_EVTONLY)
        stop()
        guard fd != -1 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self = self,
                  let f = self.watchedFolders.first(where: { $0.id == folder.id }) else { return }
            self.syncFolder(f)
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        folderWatchers[folder.id] = source
    }

    private func stopWatching(_ folder: WatchedFolder) {
        folderWatchers[folder.id]?.cancel()
        folderWatchers[folder.id] = nil
    }

    private var watchedFoldersFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("watchedFolders.json")
    }

    func loadWatchedFolders() {
        if let data = try? Data(contentsOf: watchedFoldersFileURL),
           let decoded = try? JSONDecoder().decode([WatchedFolder].self, from: data) {
            watchedFolders = decoded
        }
        ensureDefaultLibraryFolder()
        for folder in watchedFolders {
            startWatching(folder)
        }
    }

    private func ensureDefaultLibraryFolder() {
        let fm = FileManager.default
        let picturesURL = fm.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        let libraryURL  = picturesURL.appendingPathComponent("iPhoto")

        try? fm.createDirectory(at: libraryURL, withIntermediateDirectories: true)

        let libraryPath = libraryURL.standardized.path
        let alreadyWatched = watchedFolders.contains { $0.bookmarkPath == libraryPath || $0.isDefaultLibrary }
        guard !alreadyWatched else { return }

        guard var folder = try? WatchedFolder(url: libraryURL) else { return }
        folder.isDefaultLibrary = true
        folder.name = "iPhoto-Bibliothek"
        watchedFolders.insert(folder, at: 0)
        saveWatchedFolders()
    }

    func saveWatchedFolders() {
        guard let data = try? JSONEncoder().encode(watchedFolders) else { return }
        persistFileData(data, to: watchedFoldersFileURL, description: "Ordner-Datei")
    }
}

// MARK: - Selection & Trash

extension ImageViewModel {

    func removeSelected() {
        guard !collection.selectedIndices.isEmpty else { return }
        switch navSelection {
        case .album(let id):
            for colIdx in collection.selectedIndices {
                guard colIdx < collection.documents.count else { continue }
                removeFromAlbum(collection.documents[colIdx], albumID: id)
            }
            collection.selectedIndices = []
        default:
            confirmTrashFiles()
        }
    }

    func trashDocument(_ doc: ImageDocument) {
        if let idx = collectionIndex(for: doc) {
            let multi = collection.selectedIndices.count > 1 && collection.selectedIndices.contains(idx)
            if !multi { collection.select(index: idx) }
        }
        confirmTrashFiles()
    }

    private func confirmTrashFiles() {
        let count = collection.selectedIndices.count
        let alert = NSAlert()
        alert.messageText = count == 1 ? "Datei in den Papierkorb?" : "\(count) Dateien in den Papierkorb?"
        alert.informativeText = count == 1
            ? "Die Originaldatei wird vom Datenträger in den Papierkorb verschoben."
            : "Die \(count) Originaldateien werden vom Datenträger in den Papierkorb verschoben."
        alert.addButton(withTitle: "In Papierkorb")
        alert.addButton(withTitle: "Abbrechen")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let indices = collection.selectedIndices.sorted().reversed()
        for idx in indices {
            guard idx < collection.documents.count else { continue }
            let url = collection.documents[idx].url
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            try? FileManager.default.trashItem(at: accessURL, resultingItemURL: nil)
            stop()
            collection.documents.remove(at: idx)
        }
        collection.selectedIndices = []
        if !collection.documents.isEmpty {
            let newIdx = min(collection.currentIndex, collection.documents.count - 1)
            collection.currentIndex = newIdx
            collection.selectedIndices = [newIdx]
            loadCurrentImage()
        }
    }

    func toggleSelection(at index: Int) {
        if collection.selectedIndices.contains(index) {
            collection.selectedIndices.remove(index)
            if collection.currentIndex == index {
                collection.currentIndex = collection.selectedIndices.first ?? index
            }
        } else {
            collection.selectedIndices.insert(index)
            collection.currentIndex = index
            loadCurrentImage()
        }
    }

    func extendSelection(to index: Int) {
        let visibleColIndices = visibleDocuments.compactMap { collectionIndex(for: $0) }
        guard let fromPos = visibleColIndices.firstIndex(of: collection.currentIndex),
              let toPos = visibleColIndices.firstIndex(of: index) else {
            collection.selectedIndices.insert(index)
            collection.currentIndex = index
            loadCurrentImage()
            return
        }
        let lo = min(fromPos, toPos), hi = max(fromPos, toPos)
        visibleColIndices[lo...hi].forEach { collection.selectedIndices.insert($0) }
        collection.currentIndex = index
        loadCurrentImage()
    }

    func selectAll() {
        let indices = Set(visibleDocuments.compactMap { collectionIndex(for: $0) })
        collection.selectedIndices = indices
    }

    func extendSelectionToNext() {
        let visible = visibleDocuments
        guard let cur = collection.currentDocument,
              let visPos = visible.firstIndex(where: { $0.id == cur.id }),
              visPos + 1 < visible.count,
              let nextIdx = collectionIndex(for: visible[visPos + 1]) else { return }
        extendSelection(to: nextIdx)
    }

    func extendSelectionToPrevious() {
        let visible = visibleDocuments
        guard let cur = collection.currentDocument,
              let visPos = visible.firstIndex(where: { $0.id == cur.id }),
              visPos > 0,
              let prevIdx = collectionIndex(for: visible[visPos - 1]) else { return }
        extendSelection(to: prevIdx)
    }

    func removeDocument(_ doc: ImageDocument) {
        guard let idx = collection.documents.firstIndex(where: { $0.id == doc.id }) else { return }
        if collection.selectedIndices.contains(idx) && collection.selectedIndices.count > 1 {
            removeSelected()
            return
        }
        switch navSelection {
        case .album(let id):
            removeFromAlbum(doc, albumID: id)
        default:
            let alert = NSAlert()
            alert.messageText = "Datei in den Papierkorb?"
            alert.informativeText = "Die Originaldatei wird vom Datenträger in den Papierkorb verschoben."
            alert.addButton(withTitle: "In Papierkorb")
            alert.addButton(withTitle: "Abbrechen")
            alert.alertStyle = .warning
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: doc.url)
            try? FileManager.default.trashItem(at: accessURL, resultingItemURL: nil)
            stop()
            collection.documents.remove(at: idx)
            collection.selectedIndices = []
            if !collection.documents.isEmpty {
                let newIdx = min(collection.currentIndex, collection.documents.count - 1)
                collection.currentIndex = newIdx
                collection.selectedIndices = [newIdx]
                loadCurrentImage()
            }
        }
    }

    private func affectedIndices(for doc: ImageDocument) -> [Int] {
        guard let idx = collection.documents.firstIndex(where: { $0.id == doc.id }) else { return [] }
        if collection.selectedIndices.contains(idx) && collection.selectedIndices.count > 1 {
            return Array(collection.selectedIndices).filter { $0 < collection.documents.count }
        }
        return [idx]
    }

    func showInFinder(_ doc: ImageDocument) {
        NSWorkspace.shared.activateFileViewerSelecting([doc.url])
    }
}

// MARK: - Ratings, Flags, Color Labels

extension ImageViewModel {

    func setRating(_ r: Int) {
        let idx = collection.currentIndex
        guard idx < collection.documents.count else { return }
        collection.documents[idx].rating = r
        persistRating(at: idx)
    }

    func toggleFlag(_ flag: FlagStatus) {
        let indices = collection.selectedIndices.isEmpty
            ? (collection.currentIndex < collection.documents.count ? [collection.currentIndex] : [])
            : Array(collection.selectedIndices)
        guard !indices.isEmpty else { return }
        let allSet = indices.allSatisfy { collection.documents[$0].flagStatus == flag }
        let newStatus: FlagStatus = allSet ? .none : flag
        for idx in indices {
            collection.documents[idx].flagStatus = newStatus
            persistRating(at: idx)
        }
    }

    func setColorLabel(_ label: ColorLabel) {
        let idx = collection.currentIndex
        guard idx < collection.documents.count else { return }
        let cur = collection.documents[idx].colorLabel
        let newLabel: ColorLabel = (cur == label) ? .none : label
        collection.documents[idx].colorLabel = newLabel
        persistRating(at: idx)
        applyFinderColorLabel(newLabel, to: collection.documents[idx].url)
    }

    func setRating(_ r: Int, for doc: ImageDocument) {
        let indices = affectedIndices(for: doc)
        for idx in indices {
            collection.documents[idx].rating = r
            persistRating(at: idx)
        }
    }

    func setFlagStatus(_ flag: FlagStatus, for doc: ImageDocument) {
        let indices = affectedIndices(for: doc)
        guard !indices.isEmpty else { return }
        let allSet = indices.allSatisfy { collection.documents[$0].flagStatus == flag }
        let newStatus: FlagStatus = allSet ? .none : flag
        for idx in indices {
            collection.documents[idx].flagStatus = newStatus
            persistRating(at: idx)
        }
    }

    func setColorLabel(_ label: ColorLabel, for doc: ImageDocument) {
        let indices = affectedIndices(for: doc)
        guard !indices.isEmpty else { return }
        let allSet = indices.allSatisfy { collection.documents[$0].colorLabel == label }
        let newLabel: ColorLabel = allSet ? .none : label
        for idx in indices {
            collection.documents[idx].colorLabel = newLabel
            persistRating(at: idx)
            applyFinderColorLabel(newLabel, to: collection.documents[idx].url)
        }
    }

    private func applyFinderColorLabel(_ label: ColorLabel, to url: URL) {
        DispatchQueue.global(qos: .utility).async {
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            var values = URLResourceValues()
            values.labelNumber = label.finderLabelNumber
            var mutableURL = accessURL
            try? mutableURL.setResourceValues(values)
        }
    }

    private func persistRating(at idx: Int) {
        guard idx < collection.documents.count else { return }
        let doc = collection.documents[idx]
        let entry = RatingEntry(rating: doc.rating, flagStatus: doc.flagStatus, colorLabel: doc.colorLabel)
        RatingStore.shared.save(entry, for: doc.url)
        CatalogStore.shared.saveRating(path: doc.url.path, rating: doc.rating,
                                       flag: doc.flagStatus.rawValue, colorLabel: doc.colorLabel.rawValue)
        // In einem intelligenten Ordner kann eine Metadatenänderung das Bild aus den
        // Kriterien herausfallen lassen — Fokus sofort auf das nächste Bild verschieben.
        if case .smartFolder = navSelection {
            revalidateSelectionForCurrentContext()
        }
    }

    // MARK: - Removable volume detection

    func scanForRemovableVolumes() {
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: [.volumeIsRemovableKey, .volumeNameKey],
            options: .skipsHiddenFiles
        ) else { return }
        for url in entries {
            addDetectedVolumeIfRemovable(url)
        }
    }

    func addDetectedVolumeIfRemovable(_ url: URL) {
        let vals = try? url.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeNameKey])
        guard vals?.volumeIsRemovable == true else { return }
        let name = vals?.volumeName ?? url.lastPathComponent
        let standardPath = url.standardized.path
        guard !detectedVolumes.contains(where: { $0.url.standardized.path == standardPath }) else { return }
        detectedVolumes.append(DetectedVolume(id: UUID(), name: name, url: url))
    }

    func removeDetectedVolume(at url: URL) {
        let path = url.standardized.path
        guard let idx = detectedVolumes.firstIndex(where: { $0.url.standardized.path == path }) else { return }
        let volumeID = detectedVolumes[idx].id
        detectedVolumes.remove(at: idx)
        collection.documents.removeAll { $0.url.standardized.path.hasPrefix(path) }
        if case .volume(let id) = navSelection, id == volumeID {
            navSelection = .library
        }
    }

    func syncVolume(_ volume: DetectedVolume) {
        let volumeID = volume.id
        let volumeName = volume.name
        let volumeURL = volume.url
        enqueueLoading(id: volumeID, label: "Lade \"\(volumeName)\"", icon: "sdcard", done: 0, total: 0)
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: volumeURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                DispatchQueue.main.async { self.dequeueLoading(id: volumeID) }
                return
            }
            var found: [URL] = []
            for case let fileURL as URL in enumerator {
                if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                   ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    found.append(fileURL)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.importFiles(found, selectFirst: false)
                self.dequeueLoading(id: volumeID)
            }
        }
    }

    func ejectVolume(_ volume: DetectedVolume) {
        try? NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
    }
}
