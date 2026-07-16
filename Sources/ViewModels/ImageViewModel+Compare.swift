import AppKit
import Foundation

// MARK: - Bildvergleich (Duell-Modus)

enum CompareVerdict {
    case left, right, equal
}

extension ImageViewModel {

    func toggleCompareMode() {
        if compareModeActive {
            stopCompareMode()
        } else {
            startCompareMode()
        }
    }

    func startCompareMode() {
        compareModeActive = true
        nextComparePair()
    }

    func stopCompareMode() {
        compareModeActive = false
        compareLeftID = nil
        compareRightID = nil
        lastComparePair = []
    }

    var compareLeftDocument: ImageDocument? {
        guard let id = compareLeftID else { return nil }
        return collection.documents.first(where: { $0.id == id })
    }

    var compareRightDocument: ImageDocument? {
        guard let id = compareRightID else { return nil }
        return collection.documents.first(where: { $0.id == id })
    }

    /// Wählt das nächste Paar: bevorzugt zwei Bilder mit gleicher Sternezahl,
    /// damit das Duell die Rangfolge innerhalb einer Stufe verfeinert.
    func nextComparePair() {
        let candidates = visibleDocuments
        guard candidates.count >= 2 else {
            compareLeftID = nil
            compareRightID = nil
            return
        }

        var groups = Dictionary(grouping: candidates, by: { $0.rating })
            .values.filter { $0.count >= 2 }
        // Zuletzt gezeigtes Paar nicht sofort wiederholen, wenn Alternativen existieren
        if candidates.count > 2 {
            groups = groups.map { group -> [ImageDocument] in
                group.count == 2 && Set(group.map { $0.id }) == lastComparePair ? [] : group
            }.filter { $0.count >= 2 }
        }

        let pool = groups.randomElement() ?? candidates
        var pair = Array(pool.shuffled().prefix(2))
        if candidates.count > 2 && Set(pair.map { $0.id }) == lastComparePair {
            pair = Array(candidates.shuffled().prefix(2))
        }
        guard pair.count == 2 else { return }

        compareLeftID = pair[0].id
        compareRightID = pair[1].id
        lastComparePair = Set(pair.map { $0.id })
        ensureComparePreview(for: pair[0])
        ensureComparePreview(for: pair[1])
    }

    /// Gewinner steigt eine Sternstufe (max. 5); steht er schon bei 5,
    /// wird stattdessen der Verlierer eine Stufe gesenkt (min. 0).
    func resolveCompare(_ verdict: CompareVerdict) {
        defer { nextComparePair() }
        guard verdict != .equal,
              let left = compareLeftDocument,
              let right = compareRightDocument else { return }
        let winner = verdict == .left ? left : right
        let loser = verdict == .left ? right : left
        if winner.rating < 5 {
            applyCompareRating(winner.rating + 1, to: winner.id)
        } else if loser.rating > 0 {
            applyCompareRating(loser.rating - 1, to: loser.id)
        }
    }

    private func applyCompareRating(_ r: Int, to id: UUID) {
        guard let idx = collection.documents.firstIndex(where: { $0.id == id }) else { return }
        collection.documents[idx].rating = r
        invalidateVisibleOrder()
        let doc = collection.documents[idx]
        let entry = RatingEntry(rating: doc.rating, flagStatus: doc.flagStatus, colorLabel: doc.colorLabel)
        RatingStore.shared.save(entry, for: doc.url)
        CatalogStore.shared.saveRating(path: doc.url.path, rating: doc.rating,
                                       flag: doc.flagStatus.rawValue, colorLabel: doc.colorLabel.rawValue)
    }

    private func ensureComparePreview(for doc: ImageDocument) {
        guard doc.cgImage == nil, doc.previewImage == nil else { return }
        let url = doc.url
        guard !compareLoadInFlight.contains(url) else { return }
        compareLoadInFlight.insert(url)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            autoreleasepool {
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                let preview = try? RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 1500)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.compareLoadInFlight.remove(url)
                    guard let preview = preview,
                          let idx = self.collection.documents.firstIndex(where: { $0.url == url }),
                          self.collection.documents[idx].previewImage == nil else { return }
                    self.collection.documents[idx].previewImage = preview
                }
            }
        }
    }
}
