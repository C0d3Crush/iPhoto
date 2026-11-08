import AppKit
import Foundation

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
            if !multi {
                if let members = collapsedStackMembers(for: doc) {
                    collection.selectedIndices = Set(members.compactMap { collectionIndex(for: $0) })
                    collection.currentIndex = idx
                } else {
                    collection.select(index: idx)
                }
            }
        }
        confirmTrashFiles()
    }

    private func confirmTrashFiles() {
        let docs = collection.selectedIndices.sorted().compactMap {
            $0 < collection.documents.count ? collection.documents[$0] : nil
        }
        guard !docs.isEmpty else { return }

        // Im Trash-Tab: endgültig löschen, sonst in den internen Papierkorb
        if navSelection == .trash {
            deletePermanently(docs)
            return
        }
        // Pick-geschützt: enthält die Auswahl ein Pick, wird komplett blockiert.
        if showPickBlockedAlertIfNeeded(docs) { return }
        let count = docs.count

        let alert = NSAlert()
        alert.messageText = count == 1 ? "Datei in den Papierkorb?" : "\(count) Dateien in den Papierkorb?"
        alert.informativeText = count == 1
            ? "Das Bild wird in den iPhoto-Papierkorb verschoben und kann dort wiederhergestellt werden."
            : "Die \(count) Bilder werden in den iPhoto-Papierkorb verschoben und können dort wiederhergestellt werden."
        alert.addButton(withTitle: "In Papierkorb")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        moveToAppTrash(docs)
    }

    /// Zentraler Pick-Schutz: enthält `docs` mindestens ein als Pick markiertes Bild,
    /// wird ein Hinweis-Alert gezeigt und `true` zurückgegeben — die Operation muss
    /// dann abgebrochen werden. Sonst `false` und der Aufrufer fährt fort.
    @discardableResult
    func showPickBlockedAlertIfNeeded(_ docs: [ImageDocument]) -> Bool {
        let picks = docs.filter { $0.flagStatus == .pick }
        guard !picks.isEmpty else { return false }
        let alert = NSAlert()
        alert.messageText = picks.count == 1
            ? "Bild ist als Pick markiert"
            : "\(picks.count) Bilder sind als Pick markiert"
        let names = picks.prefix(3).map { $0.filename }.joined(separator: ", ")
            + (picks.count > 3 ? ", …" : "")
        alert.informativeText = picks.count == 1
            ? "„\(names)“ kann nicht gelöscht werden. Entferne zuerst die Pick-Markierung."
            : "Die folgenden Bilder können nicht gelöscht werden: \(names). Entferne zuerst die Pick-Markierung."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        alert.runModal()
        return true
    }

    // MARK: - Interner Papierkorb

    var trashedCount: Int {
        collection.documents.reduce(0) { $0 + ($1.isTrashed ? 1 : 0) }
    }

    /// Markiert Bilder als getrasht — Dateien bleiben auf dem Datenträger, sind
    /// aber nur noch im Trash-Tab sichtbar und dort wiederherstellbar.
    func moveToAppTrash(_ docs: [ImageDocument]) {
        guard !docs.isEmpty else { return }
        // Pick-Schutz: als Pick markierte Bilder blockieren die gesamte Operation.
        if showPickBlockedAlertIfNeeded(docs) { return }
        let prev = visibleDocuments
        let paths = docs.map { $0.url.path }
        trashUndoStack.append(paths)
        if trashUndoStack.count > 20 { trashUndoStack.removeFirst() }
        let ids = Set(docs.map { $0.id })
        for i in collection.documents.indices where ids.contains(collection.documents[i].id) {
            collection.documents[i].isTrashed = true
        }
        CatalogStore.shared.setTrashed(paths: paths, true)
        collection.selectedIndices = []
        invalidateVisibleOrder()
        if compare.active, let l = compare.leftID, let r = compare.rightID,
           ids.contains(l) || ids.contains(r) {
            nextComparePair()
        }
        selectNeighborAfterExclusion(previousVisible: prev, excludedIDs: ids)
    }

    func undoTrash() {
        guard let paths = trashUndoStack.popLast(), !paths.isEmpty else { return }
        let pathSet = Set(paths)
        let docs = collection.documents.filter { pathSet.contains($0.url.path) && $0.isTrashed }
        guard !docs.isEmpty else { return }
        restoreFromTrash(docs)
    }

    func restoreFromTrash(_ docs: [ImageDocument]) {
        guard !docs.isEmpty else { return }
        let prev = visibleDocuments
        let ids = Set(docs.map { $0.id })
        for i in collection.documents.indices where ids.contains(collection.documents[i].id) {
            collection.documents[i].isTrashed = false
        }
        CatalogStore.shared.setTrashed(paths: docs.map { $0.url.path }, false)
        collection.selectedIndices = []
        invalidateVisibleOrder()
        selectNeighborAfterExclusion(previousVisible: prev, excludedIDs: ids)
    }

    func emptyTrash() {
        deletePermanently(collection.documents.filter { $0.isTrashed })
    }

    /// Verschiebt die Originaldateien in den macOS-Papierkorb und entfernt sie aus iPhoto.
    func deletePermanently(_ docs: [ImageDocument]) {
        guard !docs.isEmpty else { return }
        // Pick-Schutz gilt auch für endgültiges Löschen (aus dem Papierkorb).
        if showPickBlockedAlertIfNeeded(docs) { return }
        let count = docs.count
        let willBackup = backupSettings.backupBeforeDelete
        let alert = NSAlert()
        alert.messageText = count == 1 ? "Datei endgültig löschen?" : "\(count) Dateien endgültig löschen?"
        if willBackup {
            alert.informativeText = count == 1
                ? "Die Originaldatei wird zuerst gesichert, dann aus iPhoto entfernt und in den macOS-Papierkorb verschoben."
                : "Die \(count) Originaldateien werden zuerst gesichert, dann aus iPhoto entfernt und in den macOS-Papierkorb verschoben."
        } else {
            alert.informativeText = count == 1
                ? "Die Originaldatei wird aus iPhoto entfernt und in den macOS-Papierkorb verschoben."
                : "Die \(count) Originaldateien werden aus iPhoto entfernt und in den macOS-Papierkorb verschoben."
        }
        alert.addButton(withTitle: "Endgültig löschen")
        alert.addButton(withTitle: "Abbrechen")
        alert.alertStyle = .critical
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let taskID = UUID()
        let label = willBackup ? "Sichern & löschen…" : "Endgültig löschen…"
        activity.enqueue(id: taskID, label: label, icon: "trash",
                       done: 0, total: docs.count, summaryVerb: "gelöscht")

        let settings = backupSettings
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var trashedIDs: Set<UUID> = []
            var writtenInBatch = Set<String>()
            let (backupRoot, stopBackup) = willBackup ? settings.resolveDestination() : (URL(fileURLWithPath: "/"), {})
            defer { if willBackup { stopBackup() } }
            for (i, doc) in docs.enumerated() {
                let (accessURL, stop) = BookmarkStore.shared.access(url: doc.url)
                if willBackup {
                    _ = BackupService.backup(source: accessURL, root: backupRoot, settings: settings, writtenInBatch: &writtenInBatch)
                }
                try? FileManager.default.trashItem(at: accessURL, resultingItemURL: nil)
                stop()
                trashedIDs.insert(doc.id)
                let done = i + 1
                DispatchQueue.main.async { self?.activity.update(id: taskID, done: done, total: docs.count) }
            }
            CatalogStore.shared.setTrashed(paths: docs.map { $0.url.path }, false)
            let deletedURLs = Set(docs.map { $0.url })
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.collection.documents.removeAll { trashedIDs.contains($0.id) }
                self.removeURLsFromAllAlbums(deletedURLs)
                self.collection.selectedIndices = []
                if !self.collection.documents.isEmpty {
                    let newIdx = min(self.collection.currentIndex, self.collection.documents.count - 1)
                    self.collection.currentIndex = newIdx
                    self.collection.selectedIndices = [newIdx]
                    self.loadCurrentImage()
                }
                self.activity.dequeue(id: taskID)
            }
        }
    }

    /// Selektiert nach dem Ausblenden von Bildern den nächsten sichtbaren Nachbarn.
    private func selectNeighborAfterExclusion(previousVisible: [ImageDocument], excludedIDs: Set<UUID>) {
        let newVisible = visibleDocuments
        guard let cur = collection.currentDocument else { return }
        guard excludedIDs.contains(cur.id) else {
            if let idx = collectionIndex(for: cur) { collection.selectedIndices = [idx] }
            return
        }
        guard !newVisible.isEmpty else { return }
        let pos = previousVisible.firstIndex(where: { $0.id == cur.id }) ?? 0
        let nextDoc = newVisible[min(pos, newVisible.count - 1)]
        if let nextIdx = collectionIndex(for: nextDoc) {
            collection.select(index: nextIdx)
            loadCurrentImage()
        }
    }

    func toggleSelection(at index: Int) {
        sidebarNavigationFocused = false
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
        var indices = Set<Int>()
        for doc in visibleDocuments {
            if let members = collapsedStackMembers(for: doc) {
                for m in members {
                    if let idx = collectionIndex(for: m) { indices.insert(idx) }
                }
            } else if let idx = collectionIndex(for: doc) {
                indices.insert(idx)
            }
        }
        collection.selectedIndices = indices
    }

    func extendSelectionToNext() {
        let visible = visibleDocuments
        guard let cur = collection.currentDocument,
              let visPos = visiblePosition(for: cur.id),
              visPos + 1 < visible.count,
              let nextIdx = collectionIndex(for: visible[visPos + 1]) else { return }
        extendSelection(to: nextIdx)
    }

    func navigateByRow(forward: Bool) {
        let cols = max(1, gridColumnCount)
        let visible = visibleDocuments
        guard let cur = collection.currentDocument,
              let visPos = visiblePosition(for: cur.id) else { return }
        let target = forward ? visPos + cols : visPos - cols
        guard target >= 0 && target < visible.count,
              let idx = collectionIndex(for: visible[target]) else { return }
        selectDocument(at: idx)
    }

    func extendSelectionByRow(forward: Bool) {
        let cols = max(1, gridColumnCount)
        let visible = visibleDocuments
        guard let cur = collection.currentDocument,
              let visPos = visiblePosition(for: cur.id) else { return }
        let target = forward ? visPos + cols : visPos - cols
        guard target >= 0 && target < visible.count,
              let idx = collectionIndex(for: visible[target]) else { return }
        extendSelection(to: idx)
    }

    func extendSelectionToPrevious() {
        let visible = visibleDocuments
        guard let cur = collection.currentDocument,
              let visPos = visiblePosition(for: cur.id),
              visPos > 0,
              let prevIdx = collectionIndex(for: visible[visPos - 1]) else { return }
        extendSelection(to: prevIdx)
    }

    // MARK: - Sidebar navigation + multi-select

    func sidebarSelectAlbum(_ album: Album, extending: Bool) {
        sidebarNavigationFocused = true
        if extending, let anchor = sidebarAnchorAlbumID,
           let anchorIdx = library.albums.firstIndex(where: { $0.id == anchor }),
           let targetIdx = library.albums.firstIndex(where: { $0.id == album.id }) {
            let lo = min(anchorIdx, targetIdx), hi = max(anchorIdx, targetIdx)
            sidebarSelectedAlbumIDs = Set(library.albums[lo...hi].map { $0.id })
        } else {
            sidebarSelectedAlbumIDs = [album.id]
            sidebarAnchorAlbumID = album.id
        }
        sidebarSelectedSmartFolderIDs = []
        selectAlbum(album)
    }

    func sidebarSelectSmartFolder(_ sf: SmartFolder, extending: Bool) {
        sidebarNavigationFocused = true
        let flat = flatSidebarSmartFolders()
        if extending, let anchor = sidebarAnchorSmartFolderID,
           let anchorIdx = flat.firstIndex(where: { $0.id == anchor }),
           let targetIdx = flat.firstIndex(where: { $0.id == sf.id }) {
            let lo = min(anchorIdx, targetIdx), hi = max(anchorIdx, targetIdx)
            sidebarSelectedSmartFolderIDs = Set(flat[lo...hi].map { $0.id })
        } else {
            sidebarSelectedSmartFolderIDs = [sf.id]
            sidebarAnchorSmartFolderID = sf.id
        }
        sidebarSelectedAlbumIDs = []
        navSelection = .smartFolder(sf.id)
    }

    func navigateSidebarAlbum(forward: Bool, extending: Bool) {
        guard case .album(let id) = navSelection,
              let idx = library.albums.firstIndex(where: { $0.id == id }) else { return }
        let target = forward ? idx + 1 : idx - 1
        guard target >= 0, target < library.albums.count else { return }
        sidebarSelectAlbum(library.albums[target], extending: extending)
    }

    func navigateSidebarSmartFolder(forward: Bool, extending: Bool) {
        let flat = flatSidebarSmartFolders()
        guard case .smartFolder(let id) = navSelection,
              let idx = flat.firstIndex(where: { $0.id == id }) else { return }
        let target = forward ? idx + 1 : idx - 1
        guard target >= 0, target < flat.count else { return }
        sidebarSelectSmartFolder(flat[target], extending: extending)
    }

    func flatSidebarSmartFolders() -> [SmartFolder] {
        var result = library.smartFolders.filter { $0.group == nil || $0.group?.isEmpty == true }
        let groups = Array(Set(library.smartFolders.compactMap { $0.group }.filter { !$0.isEmpty })).sorted()
        for group in groups {
            result += library.smartFolders.filter { $0.group == group }
        }
        return result
    }

    func removeDocument(_ doc: ImageDocument) {
        guard let idx = collection.documentIndexByID[doc.id] else { return }
        if collection.selectedIndices.contains(idx) && collection.selectedIndices.count > 1 {
            removeSelected()
            return
        }
        if let members = collapsedStackMembers(for: doc) {
            switch navSelection {
            case .album(let id):
                for m in members { removeFromAlbum(m, albumID: id) }
            default:
                collection.selectedIndices = Set(members.compactMap { collectionIndex(for: $0) })
                collection.currentIndex = idx
                confirmTrashFiles()
            }
            return
        }
        switch navSelection {
        case .album(let id):
            removeFromAlbum(doc, albumID: id)
        default:
            collection.select(index: idx)
            confirmTrashFiles()
        }
    }

    func showInFinder(_ doc: ImageDocument) {
        NSWorkspace.shared.activateFileViewerSelecting([doc.url])
    }
}
