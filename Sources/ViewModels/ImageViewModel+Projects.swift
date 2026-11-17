import Foundation

// MARK: - Projects

extension ImageViewModel {

    func openProject(_ project: Project) {
        isProjectMode = true
        activeProjectName = project.name
        projectLoadToken = UUID()
        syncedFolderIDs = Set(library.watchedFolders.map { $0.id })
        collection.documents = []
        collection.selectedIndices = []
        collection.currentIndex = 0
        projectSubdirectories = []
        navSelection = .library
        // Discover subdirectories for sidebar sections in background — filesystem I/O off Main.
        let folderPaths = project.folderPaths
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            var subdirs: [URL] = []
            for path in folderPaths {
                let root = URL(fileURLWithPath: path)
                if let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                    let dirs = entries.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                    subdirs.append(contentsOf: dirs.sorted { $0.lastPathComponent < $1.lastPathComponent })
                }
            }
            DispatchQueue.main.async { [weak self] in self?.projectSubdirectories = subdirs }
        }
        for path in project.folderPaths {
            let url = URL(fileURLWithPath: path)
            scanProjectFolder(url)
            startWatchingProjectFolder(url)
        }
        projectInitialized = true
        let pending = pendingOpenURLs; pendingOpenURLs = []
        if !pending.isEmpty { importFiles(pending, selectFirst: true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.syncBackupCatalog()
        }
    }

    func openWithoutProject() {
        isProjectMode = false
        activeProjectName = nil
        projectLoadToken = UUID()
        projectSubdirectories = []
        syncedFolderIDs = []
        stopAllProjectFolderWatchers()
        collection.documents = []
        collection.selectedIndices = []
        collection.currentIndex = 0
        navSelection = .library
        loadContentForSelection(.library)
        restoreCatalogImages()
        projectInitialized = true
        let pending = pendingOpenURLs; pendingOpenURLs = []
        if !pending.isEmpty { importFiles(pending, selectFirst: true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.syncBackupCatalog()
        }
    }

    func scanProjectFolder(_ folderURL: URL) {
        let folderName = folderURL.lastPathComponent
        let taskID = UUID()
        let token = projectLoadToken
        DispatchQueue.main.async { self.activity.enqueue(id: taskID, label: "Lade \"\(folderName)\"", icon: "folder", done: 0, total: 0) }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                DispatchQueue.main.async { self.activity.dequeue(id: taskID) }
                return
            }
            var found: [URL] = []
            for case let fileURL as URL in enumerator {
                guard self.projectLoadToken == token else { break }
                let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if vals?.isRegularFile == true,
                   vals?.isSymbolicLink != true,
                   ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    found.append(fileURL)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.projectLoadToken == token else {
                    self?.activity.dequeue(id: taskID)
                    return
                }
                self.importFiles(found, selectFirst: false)
                self.activity.dequeue(id: taskID)
            }
        }
    }
}
