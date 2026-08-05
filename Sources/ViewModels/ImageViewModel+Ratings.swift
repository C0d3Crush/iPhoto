import AppKit
import Foundation

// MARK: - Ratings, Flags, Color Labels

extension ImageViewModel {

    func setRating(_ r: Int) {
        let prev = visibleDocuments
        let idx = collection.currentIndex
        guard idx < collection.documents.count else { return }
        collection.documents[idx].rating = r
        persistRating(at: idx)
        advanceIfCurrentExcluded(previousVisible: prev)
    }

    func toggleFlag(_ flag: FlagStatus) {
        let prev = visibleDocuments
        let indices = collection.selectedIndices.isEmpty
            ? (collection.currentIndex < collection.documents.count ? [collection.currentIndex] : [])
            : Array(collection.selectedIndices)
        guard !indices.isEmpty else { return }
        let allSet = indices.allSatisfy { collection.documents[$0].flagStatus == flag }
        let newStatus: FlagStatus = allSet ? .none : flag
        for idx in indices {
            collection.documents[idx].flagStatus = newStatus
        }
        persistRatings(at: indices, label: "Markierungen speichern…", icon: "flag.fill")
        advanceIfCurrentExcluded(previousVisible: prev)
    }

    func setColorLabel(_ label: ColorLabel) {
        let prev = visibleDocuments
        let idx = collection.currentIndex
        guard idx < collection.documents.count else { return }
        let cur = collection.documents[idx].colorLabel
        let newLabel: ColorLabel = (cur == label) ? .none : label
        collection.documents[idx].colorLabel = newLabel
        persistRating(at: idx)
        applyFinderColorLabel(newLabel, to: collection.documents[idx].url)
        advanceIfCurrentExcluded(previousVisible: prev)
    }

    func advanceIfCurrentExcluded(previousVisible: [ImageDocument]) {
        guard case .smartFolder = navSelection else { return }
        guard let cur = collection.currentDocument else { return }
        let newVisible = visibleDocuments
        guard !newVisible.contains(where: { $0.id == cur.id }) else { return }
        guard let pos = previousVisible.firstIndex(where: { $0.id == cur.id }) else { return }
        let targetPos = min(pos, newVisible.count - 1)
        guard targetPos >= 0 else { return }
        let nextDoc = newVisible[targetPos]
        guard let nextIdx = collectionIndex(for: nextDoc) else { return }
        collection.select(index: nextIdx)
        loadCurrentImage()
    }

    private func affectedIndices(for doc: ImageDocument) -> [Int] {
        guard let idx = collection.documents.firstIndex(where: { $0.id == doc.id }) else { return [] }
        if collection.selectedIndices.contains(idx) && collection.selectedIndices.count > 1 {
            return Array(collection.selectedIndices).filter { $0 < collection.documents.count }
        }
        if let members = collapsedStackMembers(for: doc) {
            return members.compactMap { collectionIndex(for: $0) }
        }
        return [idx]
    }

    func setRating(_ r: Int, for doc: ImageDocument) {
        let prev = visibleDocuments
        let indices = affectedIndices(for: doc)
        guard !indices.isEmpty else { return }
        for idx in indices {
            collection.documents[idx].rating = r
        }
        persistRatings(at: indices, label: "Bewertungen speichern…", icon: "star.fill")
        advanceIfCurrentExcluded(previousVisible: prev)
    }

    func setFlagStatus(_ flag: FlagStatus, for doc: ImageDocument) {
        let prev = visibleDocuments
        let indices = affectedIndices(for: doc)
        guard !indices.isEmpty else { return }
        let allSet = indices.allSatisfy { collection.documents[$0].flagStatus == flag }
        let newStatus: FlagStatus = allSet ? .none : flag
        for idx in indices {
            collection.documents[idx].flagStatus = newStatus
        }
        persistRatings(at: indices, label: "Markierungen speichern…", icon: "flag.fill")
        advanceIfCurrentExcluded(previousVisible: prev)
    }

    func setColorLabel(_ label: ColorLabel, for doc: ImageDocument) {
        let prev = visibleDocuments
        let indices = affectedIndices(for: doc)
        guard !indices.isEmpty else { return }
        let allSet = indices.allSatisfy { collection.documents[$0].colorLabel == label }
        let newLabel: ColorLabel = allSet ? .none : label
        for idx in indices {
            collection.documents[idx].colorLabel = newLabel
            applyFinderColorLabel(newLabel, to: collection.documents[idx].url)
        }
        persistRatings(at: indices, label: "Farb-Labels speichern…", icon: "tag.fill")
        advanceIfCurrentExcluded(previousVisible: prev)
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
        invalidateVisibleOrder()
        let doc = collection.documents[idx]
        let entry = RatingEntry(rating: doc.rating, flagStatus: doc.flagStatus, colorLabel: doc.colorLabel)
        RatingStore.shared.save(entry, for: doc.url)
        CatalogStore.shared.saveRating(path: doc.url.path, rating: doc.rating,
                                       flag: doc.flagStatus.rawValue, colorLabel: doc.colorLabel.rawValue)
    }

    /// Persistiert Ratings/Flags/Farb-Labels für mehrere Indizes. Bei kleinen Mengen
    /// synchron, bei größeren asynchron mit Fortschrittsanzeige im Ladebalken.
    func persistRatings(at indices: [Int], label: String, icon: String) {
        guard !indices.isEmpty else { return }
        invalidateVisibleOrder()
        struct Snap { let url: URL; let entry: RatingEntry; let path: String; let rating: Int; let flag: String; let colorLabel: String }
        let snaps: [Snap] = indices.compactMap { idx in
            guard idx < collection.documents.count else { return nil }
            let doc = collection.documents[idx]
            let entry = RatingEntry(rating: doc.rating, flagStatus: doc.flagStatus, colorLabel: doc.colorLabel)
            return Snap(url: doc.url, entry: entry, path: doc.url.path,
                        rating: doc.rating, flag: doc.flagStatus.rawValue, colorLabel: doc.colorLabel.rawValue)
        }
        guard snaps.count >= 20 else {
            for s in snaps {
                RatingStore.shared.save(s.entry, for: s.url)
                CatalogStore.shared.saveRating(path: s.path, rating: s.rating, flag: s.flag, colorLabel: s.colorLabel)
            }
            return
        }
        let taskID = UUID()
        activity.enqueue(id: taskID, label: label, icon: icon,
                         done: 0, total: snaps.count, summaryVerb: "gespeichert")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for (i, s) in snaps.enumerated() {
                RatingStore.shared.save(s.entry, for: s.url)
                CatalogStore.shared.saveRating(path: s.path, rating: s.rating, flag: s.flag, colorLabel: s.colorLabel)
                let done = i + 1
                if done % 10 == 0 || done == snaps.count {
                    DispatchQueue.main.async {
                        self?.activity.update(id: taskID, done: done, total: snaps.count)
                    }
                }
            }
            DispatchQueue.main.async {
                self?.activity.dequeue(id: taskID)
            }
        }
    }
}
