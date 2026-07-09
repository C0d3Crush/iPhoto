import AppKit
import Foundation

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
