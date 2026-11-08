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
        guard !library.watchedFolders.contains(where: { $0.resolveURL()?.url.standardized == url.standardized }) else { return }
        guard let folder = try? WatchedFolder(url: url) else { return }
        library.watchedFolders.append(folder)
        if folder.isRemovableMedia {
            let libraryPath = FileManager.default
                .urls(for: .picturesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("iPhoto").path
            library.watchedFolders[library.watchedFolders.count - 1].importDestinationPath = libraryPath
        }
        library.saveWatchedFolders()
        syncFolder(folder)
        startWatching(folder)
        rebuildWatchedFolderPathCache()
        navSelection = .folder(folder.id)
    }

    func deleteWatchedFolder(_ folder: WatchedFolder) {
        guard !folder.isDefaultLibrary else { return }
        stopWatching(folder)
        syncedFolderIDs.remove(folder.id)
        library.watchedFolders.removeAll { $0.id == folder.id }
        if let (folderURL, stop) = folder.resolveURL() {
            let prefix = folderURL.standardized.path
            stop()
            collection.documents.removeAll { $0.standardizedPath.hasPrefix(prefix) }
        }
        if navSelection == .folder(folder.id) { navSelection = .library }
        library.saveWatchedFolders()
        rebuildWatchedFolderPathCache()
    }

    func toggleAutoSync(for folder: WatchedFolder) {
        guard let idx = library.watchedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        library.watchedFolders[idx].autoSync.toggle()
        library.saveWatchedFolders()
    }

    func setImportDestination(for folder: WatchedFolder, path: String?) {
        guard let idx = library.watchedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        library.watchedFolders[idx].importDestinationPath = path
        library.saveWatchedFolders()

        guard let path = path else { return }
        let destURL = URL(fileURLWithPath: path)
        let alreadyWatched = library.watchedFolders.contains {
            $0.bookmarkPath.map { URL(fileURLWithPath: $0).standardized } == destURL.standardized
        }
        guard !alreadyWatched, let destFolder = try? WatchedFolder(url: destURL) else { return }
        library.watchedFolders.append(destFolder)
        library.saveWatchedFolders()
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
        activity.importProgress[folderID] = BackgroundActivityState.ImportProgress(folderName: folderName, completed: 0, total: 0)
        activity.enqueue(id: folderID, label: "Synchronisiere \"\(folderName)\"",
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
                    self.activity.importProgress.removeValue(forKey: folderID)
                    self.activity.dequeue(id: folderID)
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

            // Dedup by name + size; rename on name collision with different content
            var filesToCopy: [(src: URL, dest: URL)] = []
            for file in sourceFiles {
                let srcSize = (try? fm.attributesOfItem(atPath: file.path))?[.size] as? Int ?? -1
                let destExact = destURL.appendingPathComponent(file.lastPathComponent)
                if fm.fileExists(atPath: destExact.path) {
                    let dstSize = (try? fm.attributesOfItem(atPath: destExact.path))?[.size] as? Int ?? -2
                    if srcSize == dstSize { continue }  // already present
                    var suffix = 1
                    var uniqueDest: URL
                    let base = (file.lastPathComponent as NSString).deletingPathExtension
                    let ext  = (file.lastPathComponent as NSString).pathExtension
                    repeat {
                        let name = ext.isEmpty ? "\(base)_\(suffix)" : "\(base)_\(suffix).\(ext)"
                        uniqueDest = destURL.appendingPathComponent(name)
                        suffix += 1
                    } while fm.fileExists(atPath: uniqueDest.path)
                    filesToCopy.append((src: file, dest: uniqueDest))
                } else {
                    filesToCopy.append((src: file, dest: destExact))
                }
            }

            DispatchQueue.main.async {
                self.activity.importProgress[folderID] = BackgroundActivityState.ImportProgress(folderName: folderName, completed: 0, total: filesToCopy.count)
                self.activity.update(id: folderID, done: 0, total: filesToCopy.count)
            }

            var completed = 0
            var failedCount = 0
            var newURLs: [URL] = []
            for (src, dest) in filesToCopy {
                if (try? fm.copyItem(at: src, to: dest)) != nil {
                    newURLs.append(dest)
                } else {
                    failedCount += 1
                }
                completed += 1
                let c = completed
                DispatchQueue.main.async {
                    self.activity.importProgress[folderID] = BackgroundActivityState.ImportProgress(folderName: folderName, completed: c, total: filesToCopy.count)
                    self.activity.update(id: folderID, done: c, total: filesToCopy.count)
                }
            }

            DispatchQueue.main.async {
                self.activity.importProgress.removeValue(forKey: folderID)
                self.activity.dequeue(id: folderID)
                if !newURLs.isEmpty {
                    self.importFiles(newURLs, selectFirst: false)
                    if failedCount == 0 {
                        self.activity.completedImports.insert(folderID)
                    }
                }
            }
        }
    }

    func wipeFolder(_ folder: WatchedFolder) {
        guard folder.isRemovableMedia,
              let (sourceURL, stop) = folder.resolveURL() else { return }

        let taskID = UUID()
        activity.enqueue(id: taskID, label: "Karte prüfen …", icon: "sdcard", done: 0, total: 0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { stop(); return }
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: sourceURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { stop(); DispatchQueue.main.async { self.activity.dequeue(id: taskID) }; return }

            var imageFiles: [URL] = []
            for case let fileURL as URL in enumerator {
                if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                   ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    imageFiles.append(fileURL)
                }
            }

            var missingCount = 0
            if let destURL = folder.importDestinationURL {
                // A file is "missing" if no same-name+same-size copy exists in dest
                for file in imageFiles {
                    let srcSize = (try? fm.attributesOfItem(atPath: file.path))?[.size] as? Int ?? -1
                    let destFile = destURL.appendingPathComponent(file.lastPathComponent)
                    if fm.fileExists(atPath: destFile.path) {
                        let dstSize = (try? fm.attributesOfItem(atPath: destFile.path))?[.size] as? Int ?? -2
                        if srcSize == dstSize { continue }
                    }
                    missingCount += 1
                }
            }
            stop()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.activity.dequeue(id: taskID)
                guard !imageFiles.isEmpty else { self.activity.completedImports.remove(folder.id); return }

                if missingCount > 0 {
                    let a = NSAlert()
                    a.messageText = "\(missingCount) Bilder nicht importiert!"
                    a.informativeText = "\(missingCount) von \(imageFiles.count) Bilddateien auf der Karte wurden nicht in den Zielordner importiert. Bitte den Import erneut ausführen, bevor die Karte geleert wird."
                    a.addButton(withTitle: "OK")
                    a.alertStyle = .critical
                    a.runModal()
                    return
                }

                let confirm = NSAlert()
                confirm.messageText = "\(imageFiles.count) Bilddateien von \"\(folder.name)\" löschen?"
                confirm.informativeText = "Alle Bilddateien auf dem Speichermedium werden unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden."
                confirm.addButton(withTitle: "Löschen")
                confirm.addButton(withTitle: "Abbrechen")
                confirm.alertStyle = .critical
                guard confirm.runModal() == .alertFirstButtonReturn else { return }

                let deleteID = UUID()
                self.activity.enqueue(id: deleteID, label: "Karte leeren …", icon: "sdcard", done: 0, total: imageFiles.count)
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    var failed = 0
                    for (i, file) in imageFiles.enumerated() {
                        if (try? FileManager.default.removeItem(at: file)) == nil { failed += 1 }
                        let done = i + 1
                        DispatchQueue.main.async { self?.activity.update(id: deleteID, done: done, total: imageFiles.count) }
                    }
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.activity.dequeue(id: deleteID)
                        self.activity.completedImports.remove(folder.id)
                        if failed > 0 {
                            let err = NSAlert()
                            err.messageText = "\(failed) Dateien konnten nicht gelöscht werden"
                            err.informativeText = "Möglicherweise fehlen Schreibrechte auf dem Speichermedium."
                            err.alertStyle = .warning
                            err.addButton(withTitle: "OK")
                            err.runModal()
                        }
                    }
                }
            }
        }
    }

    func loadContentForSelection(_ selection: NavSelection?) {
        // In project mode watched folders are intentionally excluded
        guard !isProjectMode else { return }
        let foldersToLoad: [WatchedFolder]
        switch selection {
        case .library, nil:
            foldersToLoad = library.watchedFolders.filter { !syncedFolderIDs.contains($0.id) }
        case .folder(let id):
            foldersToLoad = library.watchedFolders.filter { $0.id == id && !syncedFolderIDs.contains($0.id) }
        case .album, .albumFolder:
            foldersToLoad = library.watchedFolders.filter { !syncedFolderIDs.contains($0.id) }
        case .smartFolder(let id):
            foldersToLoad = library.watchedFolders.filter { !syncedFolderIDs.contains($0.id) }
            if let sf = library.smartFolders.first(where: { $0.id == id }) {
                syncSmartFolderToFilesystem(sf)
            }
        case .volume(let id):
            if let vol = library.detectedVolumes.first(where: { $0.id == id }) {
                syncVolume(vol)
            }
            foldersToLoad = []
        case .trash, .backup:
            foldersToLoad = []
        case .duplicates, .similar, .similarGroup, .blurry, .underexposed, .overexposed, .closedEyes, .eloRange, .people, .personDetail, .projectFolder, .subfolder:
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
        DispatchQueue.main.async { self.activity.enqueue(id: folderID, label: "Lade \"\(folderName)\"", icon: "folder", done: 0, total: 0) }
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
                if lastName == SmartFolderFileSync.systemFolderName ||
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
            // Set-Abgleich außerhalb des Filters — found.map im Closure war O(N×M)
            // und blockierte den Main-Thread bei großen Bibliotheken sekundenlang.
            let foundPaths = Set(found.map { $0.standardized.path })
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let removeIDs = Set(self.collection.documents.compactMap { doc -> UUID? in
                    let p = doc.url.standardized.path
                    return p.hasPrefix(folderPrefix) && !foundPaths.contains(p) ? doc.id : nil
                })
                self.collection.documents.removeAll { removeIDs.contains($0.id) }
                self.importFiles(found, selectFirst: false)
                self.activity.dequeue(id: folderID)
            }
        }
    }

    private func startWatching(_ folder: WatchedFolder) {
        guard let (folderURL, stop) = folder.resolveURL() else { return }
        let rootPath = folderURL.path
        stop()

        // Collect root + all current subdirectories so deep changes are detected.
        var paths = [rootPath]
        if let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let url as URL in enumerator {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    paths.append(url.path)
                }
            }
        }

        var sources: [DispatchSourceFileSystemObject] = []
        for path in paths {
            let fd = open(path, O_EVTONLY)
            guard fd != -1 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .global(qos: .utility)
            )
            // Debounce: Batch-Löschen/-Kopieren feuert pro Datei ein Event.
            source.setEventHandler { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.folderSyncDebounce[folder.id]?.cancel()
                    let work = DispatchWorkItem { [weak self] in
                        guard let self = self,
                              let f = self.library.watchedFolders.first(where: { $0.id == folder.id }) else { return }
                        self.folderSyncDebounce[folder.id] = nil
                        self.syncFolder(f)
                        // Refresh subdirectory watchers in case new subdirs appeared.
                        self.stopWatching(folder)
                        self.startWatching(folder)
                    }
                    self.folderSyncDebounce[folder.id] = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
                }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }
        folderWatchers[folder.id] = sources
    }

    private func stopWatching(_ folder: WatchedFolder) {
        folderWatchers[folder.id]?.forEach { $0.cancel() }
        folderWatchers[folder.id] = nil
    }

    // MARK: - Project folder watching (#71)

    func startWatchingProjectFolder(_ folderURL: URL) {
        let key = folderURL.standardized.path
        projectFolderWatchers[key]?.forEach { $0.cancel() }

        var paths = [key]
        if let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let url as URL in enumerator {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    paths.append(url.standardized.path)
                }
            }
        }

        var sources: [DispatchSourceFileSystemObject] = []
        for path in paths {
            let fd = open(path, O_EVTONLY)
            guard fd != -1 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .global(qos: .utility)
            )
            source.setEventHandler { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self, self.isProjectMode else { return }
                    self.projectFolderSyncDebounce[key]?.cancel()
                    let work = DispatchWorkItem { [weak self] in
                        guard let self = self, self.isProjectMode else { return }
                        self.projectFolderSyncDebounce[key] = nil
                        self.scanProjectFolder(folderURL)
                        self.stopWatchingProjectFolder(key)
                        self.startWatchingProjectFolder(folderURL)
                        // Refresh sidebar subdirectory list
                        DispatchQueue.global(qos: .utility).async {
                            let fm = FileManager.default
                            let entries = (try? fm.contentsOfDirectory(
                                at: folderURL,
                                includingPropertiesForKeys: [.isDirectoryKey],
                                options: [.skipsHiddenFiles]
                            )) ?? []
                            let subdirs = entries
                                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                // Merge: add new subdirs, keep existing order
                                let existing = Set(self.projectSubdirectories.map { $0.standardized.path })
                                let new = subdirs.filter { !existing.contains($0.standardized.path) }
                                self.projectSubdirectories.append(contentsOf: new)
                            }
                        }
                    }
                    self.projectFolderSyncDebounce[key] = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
                }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }
        projectFolderWatchers[key] = sources
    }

    private func stopWatchingProjectFolder(_ key: String) {
        projectFolderWatchers[key]?.forEach { $0.cancel() }
        projectFolderWatchers[key] = nil
    }

    func stopAllProjectFolderWatchers() {
        projectFolderSyncDebounce.values.forEach { $0.cancel() }
        projectFolderSyncDebounce = [:]
        projectFolderWatchers.values.forEach { $0.forEach { $0.cancel() } }
        projectFolderWatchers = [:]
    }

    func setupWatchedFolders() {
        ensureDefaultLibraryFolder()
        for folder in library.watchedFolders {
            startWatching(folder)
        }
        rebuildWatchedFolderPathCache()
    }

    func rebuildWatchedFolderPathCache() {
        var cache: [UUID: String] = [:]
        for folder in library.watchedFolders {
            if let (url, stop) = folder.resolveURL() {
                cache[folder.id] = url.standardized.path
                stop()
            }
        }
        watchedFolderPathCache = cache
    }

    private func ensureDefaultLibraryFolder() {
        let fm = FileManager.default
        let picturesURL = fm.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        let libraryURL  = picturesURL.appendingPathComponent("iPhoto")

        try? fm.createDirectory(at: libraryURL, withIntermediateDirectories: true)

        let libraryPath = libraryURL.standardized.path
        let alreadyWatched = library.watchedFolders.contains { $0.bookmarkPath == libraryPath || $0.isDefaultLibrary }
        guard !alreadyWatched else { return }

        guard var folder = try? WatchedFolder(url: libraryURL) else { return }
        folder.isDefaultLibrary = true
        folder.name = "iPhoto-Bibliothek"
        library.watchedFolders.insert(folder, at: 0)
        library.saveWatchedFolders()
    }

}
