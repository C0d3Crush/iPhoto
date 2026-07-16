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

    /// Ziel-Verteilung der Sterne (Gauß-artig): 1★ 10 %, 2★ 20 %, 3★ 40 %, 4★ 20 %, 5★ 10 %.
    /// Unbewertete (0★) haben Ziel 0 % — sie werden bevorzugt verglichen und einsortiert.
    static let compareRatingTargets: [Int: Double] = [0: 0.0, 1: 0.10, 2: 0.20, 3: 0.40, 4: 0.20, 5: 0.10]

    /// Wählt das nächste Paar aus einer Sternstufe, die über ihrem Ziel-Anteil liegt —
    /// Duelle dort verschieben Bilder in Nachbarstufen und nähern die Verteilung dem Ziel an.
    func nextComparePair() {
        let candidates = visibleDocuments
        guard candidates.count >= 2 else {
            compareLeftID = nil
            compareRightID = nil
            return
        }

        var groups = Dictionary(grouping: candidates, by: { $0.rating })
            .filter { $0.value.count >= 2 }
        // Zuletzt gezeigtes Paar nicht sofort wiederholen, wenn Alternativen existieren
        if candidates.count > 2 {
            groups = groups.mapValues { group -> [ImageDocument] in
                group.count == 2 && Set(group.map { $0.id }) == lastComparePair ? [] : group
            }.filter { $0.value.count >= 2 }
        }

        // Übervolle Stufen gewichtet nach ihrem Überschuss auslosen
        let total = Double(candidates.count)
        let overfull = groups.compactMap { rating, docs -> (docs: [ImageDocument], weight: Double)? in
            let excess = Double(docs.count) / total - (Self.compareRatingTargets[rating] ?? 0)
            return excess > 0 ? (docs, excess) : nil
        }
        let pool: [ImageDocument]
        if !overfull.isEmpty {
            var r = Double.random(in: 0..<overfull.reduce(0) { $0 + $1.weight })
            var chosen = overfull[0].docs
            for entry in overfull {
                r -= entry.weight
                if r < 0 { chosen = entry.docs; break }
            }
            pool = chosen
        } else {
            pool = groups.values.randomElement() ?? candidates
        }

        var pair = Array(pool.shuffled().prefix(2))
        if candidates.count > 2 && Set(pair.map { $0.id }) == lastComparePair {
            pair = Array(candidates.shuffled().prefix(2))
        }
        guard pair.count == 2 else { return }

        compareLeftID = pair[0].id
        compareRightID = pair[1].id
        lastComparePair = Set(pair.map { $0.id })
        ensureComparePreview(forID: pair[0].id)
        ensureComparePreview(forID: pair[1].id)
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

    private func ensureComparePreview(forID id: UUID) {
        // Frisch aus der Collection auflösen — Kopien aus visibleDocuments können veraltet sein
        guard let doc = collection.documents.first(where: { $0.id == id }),
              doc.cgImage == nil, doc.previewImage == nil else { return }
        let url = doc.url
        guard !compareLoadInFlight.contains(url) else { return }
        compareLoadInFlight.insert(url)
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
