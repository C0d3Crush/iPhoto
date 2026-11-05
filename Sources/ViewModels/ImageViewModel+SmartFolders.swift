import AppKit
import Foundation

// MARK: - Smart Folders

extension ImageViewModel {

    func createSmartFolder(_ sf: SmartFolder) {
        library.smartFolders.append(sf)
        library.saveSmartFolders()
        navSelection = .smartFolder(sf.id)
        syncSmartFolderToFilesystem(sf)
    }

    func deleteSmartFolder(_ sf: SmartFolder) {
        DispatchQueue.global(qos: .utility).async {
            SmartFolderFileSync.remove(sf)
        }
        library.smartFolders.removeAll { $0.id == sf.id }
        if navSelection == .smartFolder(sf.id) { navSelection = .library }
        library.saveSmartFolders()
    }

    func deleteSelectedSidebarSmartFolders() {
        let ids = sidebarSelectedSmartFolderIDs
        guard ids.count > 1 else { return }
        let toDelete = library.smartFolders.filter { ids.contains($0.id) }
        DispatchQueue.global(qos: .utility).async {
            toDelete.forEach { SmartFolderFileSync.remove($0) }
        }
        library.smartFolders.removeAll { ids.contains($0.id) }
        if case .smartFolder(let id) = navSelection, ids.contains(id) { navSelection = .library }
        library.saveSmartFolders()
        sidebarSelectedSmartFolderIDs = []
        sidebarAnchorSmartFolderID = nil
    }

    func updateSmartFolder(_ sf: SmartFolder) {
        guard let idx = library.smartFolders.firstIndex(where: { $0.id == sf.id }) else { return }
        let old = library.smartFolders[idx]
        let oldDir: URL? = (old.name != sf.name || old.group != sf.group)
            ? SmartFolderFileSync.systemPath(for: old)
            : nil
        let oldGroup = old.group
        library.smartFolders[idx] = sf
        library.saveSmartFolders()
        syncSmartFolderToFilesystem(sf, removingOldAt: oldDir)
        if let grp = oldGroup, grp != sf.group {
            DispatchQueue.global(qos: .utility).async {
                SmartFolderFileSync.removeGroupDirIfEmpty(grp)
            }
        }
        if case .smartFolder(let selectedID) = navSelection, selectedID == sf.id {
            revalidateSelectionForCurrentContext()
        }
    }

    // MARK: - Smart Folder Group Operations

    func moveSmartFolder(_ sf: SmartFolder, toGroup group: String?) {
        guard let idx = library.smartFolders.firstIndex(where: { $0.id == sf.id }) else { return }
        let old = library.smartFolders[idx]
        let oldDir = SmartFolderFileSync.systemPath(for: old)
        let oldGroup = old.group
        library.smartFolders[idx].group = group
        library.saveSmartFolders()
        syncSmartFolderToFilesystem(library.smartFolders[idx], removingOldAt: oldDir)
        if let grp = oldGroup {
            DispatchQueue.global(qos: .utility).async {
                SmartFolderFileSync.removeGroupDirIfEmpty(grp)
            }
        }
    }

    func renameGroup(_ oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != oldName else { return }
        for idx in library.smartFolders.indices where library.smartFolders[idx].group == oldName {
            library.smartFolders[idx].group = trimmed
        }
        library.saveSmartFolders()
        DispatchQueue.global(qos: .utility).async {
            SmartFolderFileSync.moveGroupDir(from: oldName, to: trimmed)
        }
        // Re-sync all smart folders in the renamed group
        for sf in library.smartFolders where sf.group == trimmed {
            syncSmartFolderToFilesystem(sf)
        }
    }

    func dissolveGroup(_ groupName: String) {
        for idx in library.smartFolders.indices where library.smartFolders[idx].group == groupName {
            let old = library.smartFolders[idx]
            let oldDir = SmartFolderFileSync.systemPath(for: old)
            library.smartFolders[idx].group = nil
            syncSmartFolderToFilesystem(library.smartFolders[idx], removingOldAt: oldDir)
        }
        library.saveSmartFolders()
        DispatchQueue.global(qos: .utility).async {
            SmartFolderFileSync.removeGroupDir(groupName)
        }
    }

    // MARK: - Smart Folder Filesystem Sync

    func syncSmartFolderToFilesystem(_ sf: SmartFolder, removingOldAt oldDir: URL? = nil) {
        // Filter on the calling thread (always main) — collection.documents must not be
        // read from a background thread while main writes it (data race → SIGSEGV).
        let matchDocURLs = collection.documents.filter { smartFolderMatches($0, sf: sf) }.map { $0.url }
        DispatchQueue.global(qos: .utility).async {
            SmartFolderFileSync.sync(sf, matchingURLs: matchDocURLs, removingOldAt: oldDir)
        }
    }

    func createFilmSimulationSmartFolders() {
        let known = CatalogStore.shared.allFilmSimulations()
        let group = "Filmsimulationen"
        var changed = 0
        for sim in known {
            guard !sim.isEmpty else { continue }
            if let idx = library.smartFolders.firstIndex(where: { $0.name == sim && ($0.group == nil || $0.group != group) }) {
                library.smartFolders[idx].group = group
                syncSmartFolderToFilesystem(library.smartFolders[idx])
                changed += 1
            } else if !library.smartFolders.contains(where: { $0.name == sim && $0.group == group }) {
                var criterion = SmartFolderCriterion()
                criterion.attribute = .filmSimulation
                criterion.op = .isExact
                criterion.textValue = sim
                var sf = SmartFolder(name: sim)
                sf.criteria = [criterion]
                sf.matchAll = true
                sf.group = group
                library.smartFolders.append(sf)
                syncSmartFolderToFilesystem(sf)
                changed += 1
            }
        }
        if changed > 0 { library.saveSmartFolders() }
    }
}
