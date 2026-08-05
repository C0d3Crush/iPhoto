import AppKit
import Foundation

// MARK: - Bildvergleich (Duell-Modus)

enum CompareVerdict {
    case left, right, equal
}

extension ImageViewModel {

    func toggleCompareMode() {
        if compare.active {
            stopCompareMode()
        } else {
            startCompareMode()
        }
    }

    func startCompareMode() {
        compare.active = true
        nextComparePair()
    }

    func stopCompareMode() {
        compare.active = false
        compare.leftID = nil
        compare.rightID = nil
        compare.lastPair = []
    }

    var compareLeftDocument: ImageDocument? {
        guard let id = compare.leftID else { return nil }
        return collection.documents.first(where: { $0.id == id && !$0.isTrashed })
    }

    var compareRightDocument: ImageDocument? {
        guard let id = compare.rightID else { return nil }
        return collection.documents.first(where: { $0.id == id && !$0.isTrashed })
    }

    /// Ziel-Verteilung der Sterne (Gauß-artig): 1★ 10 %, 2★ 20 %, 3★ 40 %, 4★ 20 %, 5★ 10 %.
    /// Unbewertete (0★) haben Ziel 0 % — sie werden bevorzugt verglichen und einsortiert.
    static let compareRatingTargets: [Int: Double] = [0: 0.0, 1: 0.10, 2: 0.20, 3: 0.40, 4: 0.20, 5: 0.10]

    /// Wählt das nächste Paar aus einer Sternstufe, die über ihrem Ziel-Anteil liegt —
    /// Duelle dort verschieben Bilder in Nachbarstufen und nähern die Verteilung dem Ziel an.
    func nextComparePair() {
        let candidates = visibleDocuments.filter { !$0.isTrashed }
        guard candidates.count >= 2 else {
            compare.leftID = nil
            compare.rightID = nil
            return
        }

        var groups = Dictionary(grouping: candidates, by: { $0.rating })
            .filter { $0.value.count >= 2 }
        // Zuletzt gezeigtes Paar nicht sofort wiederholen, wenn Alternativen existieren
        if candidates.count > 2 {
            groups = groups.mapValues { group -> [ImageDocument] in
                group.count == 2 && Set(group.map { $0.id }) == compare.lastPair ? [] : group
            }.filter { $0.value.count >= 2 }
        }

        // Immer die Stufe mit dem größten Überschuss gegenüber der Gauß-Zielkurve wählen
        let total = Double(candidates.count)
        let worst = groups.max(by: { a, b in
            let excessA = Double(a.value.count) / total - (Self.compareRatingTargets[a.key] ?? 0)
            let excessB = Double(b.value.count) / total - (Self.compareRatingTargets[b.key] ?? 0)
            return excessA < excessB
        })
        let pool = worst?.value ?? candidates

        var pair = Array(pool.shuffled().prefix(2))
        if candidates.count > 2 && Set(pair.map { $0.id }) == compare.lastPair {
            pair = Array(candidates.shuffled().prefix(2))
        }
        guard pair.count == 2 else { return }

        compare.leftID = pair[0].id
        compare.rightID = pair[1].id
        compare.lastPair = Set(pair.map { $0.id })
        ensureComparePreview(forID: pair[0].id)
        ensureComparePreview(forID: pair[1].id)
    }

    /// Zufällig steigt der Gewinner eine Stufe ODER der Verlierer sinkt eine Stufe.
    /// Bei Gewinner auf 5 wird immer gesenkt, bei Verlierer auf 0 immer erhöht.
    func resolveCompare(_ verdict: CompareVerdict) {
        defer { nextComparePair() }
        guard verdict != .equal,
              let left = compareLeftDocument,
              let right = compareRightDocument else { return }
        let winner = verdict == .left ? left : right
        let loser = verdict == .left ? right : left

        let canPromote = winner.rating < 5
        let canDemote = loser.rating > 0
        switch (canPromote, canDemote) {
        case (true, true):
            if Bool.random() {
                applyCompareRating(winner.rating + 1, to: winner.id)
            } else {
                applyCompareRating(loser.rating - 1, to: loser.id)
            }
        case (true, false):
            applyCompareRating(winner.rating + 1, to: winner.id)
        case (false, true):
            applyCompareRating(loser.rating - 1, to: loser.id)
        case (false, false):
            break
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

    private func ensureComparePreview(forID id: UUID) {
        // Frisch aus der Collection auflösen — Kopien aus visibleDocuments können veraltet sein
        guard let doc = collection.documents.first(where: { $0.id == id }),
              doc.cgImage == nil, doc.previewImage == nil else { return }
        let url = doc.url
        guard !compare.loadInFlight.contains(url) else { return }
        compare.loadInFlight.insert(url)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            autoreleasepool {
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                let preview: CGImage?
                do {
                    preview = try RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 1500)
                } catch {
                    Log.error("Vergleichs-Preview fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                    preview = nil
                }
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.compare.loadInFlight.remove(url)
                    guard let preview = preview,
                          let idx = self.collection.documents.firstIndex(where: { $0.url == url }),
                          self.collection.documents[idx].previewImage == nil else { return }
                    self.collection.documents[idx].previewImage = preview
                }
            }
        }
    }
}
