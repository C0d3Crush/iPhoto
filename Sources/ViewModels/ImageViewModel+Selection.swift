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
        let count = docs.count

        let picks = docs.filter { $0.flagStatus == .pick }
        let alert = NSAlert()
        if picks.isEmpty {
            alert.messageText = count == 1 ? "Datei in den Papierkorb?" : "\(count) Dateien in den Papierkorb?"
            alert.informativeText = count == 1
                ? "Das Bild wird in den iPhoto-Papierkorb verschoben und kann dort wiederhergestellt werden."
                : "Die \(count) Bilder werden in den iPhoto-Papierkorb verschoben und können dort wiederhergestellt werden."
            alert.addButton(withTitle: "In Papierkorb")
            alert.alertStyle = .warning
        } else {
            alert.messageText = picks.count == 1
                ? "Ein Bild ist als Pick markiert!"
                : "\(picks.count) Bilder sind als Pick markiert!"
            let names = picks.prefix(3).map { $0.filename }.joined(separator: ", ")
                + (picks.count > 3 ? ", …" : "")
            alert.informativeText = count == 1
                ? "„\(names)“ ist als Pick markiert. Trotzdem in den Papierkorb verschieben?"
                : "Von den \(count) Dateien sind als Pick markiert: \(names). Trotzdem alle \(count) in den Papierkorb verschieben?"
            alert.addButton(withTitle: "Trotzdem in Papierkorb")
            alert.alertStyle = .critical
        }
        alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        moveToAppTrash(docs)
    }

    // MARK: - Interner Papierkorb

    var trashedCount: Int {
        collection.documents.reduce(0) { $0 + ($1.isTrashed ? 1 : 0) }
    }

    /// Markiert Bilder als getrasht — Dateien bleiben auf dem Datenträger, sind
    /// aber nur noch im Trash-Tab sichtbar und dort wiederherstellbar.
    func moveToAppTrash(_ docs: [ImageDocument]) {
        guard !docs.isEmpty else { return }
        let prev = visibleDocuments
        let ids = Set(docs.map { $0.id })
        for i in collection.documents.indices where ids.contains(collection.documents[i].id) {
            collection.documents[i].isTrashed = true
        }
        CatalogStore.shared.setTrashed(paths: docs.map { $0.url.path }, true)
        collection.selectedIndices = []
        invalidateVisibleOrder()
        selectNeighborAfterExclusion(previousVisible: prev, excludedIDs: ids)
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
        let count = docs.count
        let alert = NSAlert()
        alert.messageText = count == 1 ? "Datei endgültig löschen?" : "\(count) Dateien endgültig löschen?"
        alert.informativeText = count == 1
            ? "Die Originaldatei wird aus iPhoto entfernt und in den macOS-Papierkorb verschoben."
            : "Die \(count) Originaldateien werden aus iPhoto entfernt und in den macOS-Papierkorb verschoben."
        alert.addButton(withTitle: "Endgültig löschen")
        alert.addButton(withTitle: "Abbrechen")
        alert.alertStyle = .critical
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let taskID = UUID()
        enqueueLoading(id: taskID, label: "Endgültig löschen…", icon: "trash",
                       done: 0, total: docs.count, summaryVerb: "gelöscht")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var trashedIDs: Set<UUID> = []
            for (i, doc) in docs.enumerated() {
                let (accessURL, stop) = BookmarkStore.shared.access(url: doc.url)
                try? FileManager.default.trashItem(at: accessURL, resultingItemURL: nil)
                stop()
                trashedIDs.insert(doc.id)
                let done = i + 1
                DispatchQueue.main.async { self?.updateLoading(id: taskID, done: done, total: docs.count) }
            }
            CatalogStore.shared.setTrashed(paths: docs.map { $0.url.path }, false)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.collection.documents.removeAll { trashedIDs.contains($0.id) }
                self.collection.selectedIndices = []
                if !self.collection.documents.isEmpty {
                    let newIdx = min(self.collection.currentIndex, self.collection.documents.count - 1)
                    self.collection.currentIndex = newIdx
                    self.collection.selectedIndices = [newIdx]
                    self.loadCurrentImage()
                }
                self.dequeueLoading(id: taskID)
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
