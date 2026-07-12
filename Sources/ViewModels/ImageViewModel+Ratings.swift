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
            persistRating(at: idx)
        }
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
        for idx in indices {
            collection.documents[idx].rating = r
            persistRating(at: idx)
        }
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
            persistRating(at: idx)
        }
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
            persistRating(at: idx)
            applyFinderColorLabel(newLabel, to: collection.documents[idx].url)
        }
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
}
