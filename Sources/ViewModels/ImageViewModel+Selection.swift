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

        let docs = collection.selectedIndices.sorted().compactMap {
            $0 < collection.documents.count ? collection.documents[$0] : nil
        }
        guard !docs.isEmpty else { return }
        let taskID = UUID()
        enqueueLoading(id: taskID, label: "In Papierkorb verschieben…", icon: "trash",
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
