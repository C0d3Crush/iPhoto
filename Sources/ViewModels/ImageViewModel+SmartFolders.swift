import AppKit
import Foundation

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

    func createFilmSimulationSmartFolders() {
        let known = CatalogStore.shared.allFilmSimulations()
        let group = "Filmsimulationen"
        var changed = 0
        for sim in known {
            guard !sim.isEmpty else { continue }
            if let idx = smartFolders.firstIndex(where: { $0.name == sim && ($0.group == nil || $0.group != group) }) {
                smartFolders[idx].group = group
                syncSmartFolderToFilesystem(smartFolders[idx])
                changed += 1
            } else if !smartFolders.contains(where: { $0.name == sim && $0.group == group }) {
                var criterion = SmartFolderCriterion()
                criterion.attribute = .filmSimulation
                criterion.op = .isExact
                criterion.textValue = sim
                var sf = SmartFolder(name: sim)
                sf.criteria = [criterion]
                sf.matchAll = true
                sf.group = group
                smartFolders.append(sf)
                syncSmartFolderToFilesystem(sf)
                changed += 1
            }
        }
        if changed > 0 { saveSmartFolders() }
    }
}
