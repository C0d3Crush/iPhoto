import AppKit
import Foundation

// MARK: - Bildvergleich (Duell-Modus, ELO-basiert)

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
        return collection.documents.first(where: { $0.id == id && !$0.isTrashed && !$0.isBackedUp })
    }

    var compareRightDocument: ImageDocument? {
        guard let id = compare.rightID else { return nil }
        return collection.documents.first(where: { $0.id == id && !$0.isTrashed && !$0.isBackedUp })
    }

    // MARK: ELO-Verteilung

    /// Buckets für die Histogramm-Anzeige. Klassisches ELO-Raster mit 6 Stufen
    /// um die Baseline 1500 — ähnliche Optik wie das alte 0-5-Sterne-Histogramm.
    struct EloBucket: Identifiable {
        let id: Int
        let range: Range<Double>
        let label: String
        let short: String
    }

    static let compareEloBuckets: [EloBucket] = [
        EloBucket(id: 0, range: -.infinity ..< 1300, label: "< 1300",     short: "1300−"),
        EloBucket(id: 1, range: 1300 ..< 1400,       label: "1300–1400", short: "1300"),
        EloBucket(id: 2, range: 1400 ..< 1500,       label: "1400–1500", short: "1400"),
        EloBucket(id: 3, range: 1500 ..< 1600,       label: "1500–1600", short: "1500"),
        EloBucket(id: 4, range: 1600 ..< 1700,       label: "1600–1700", short: "1600"),
        EloBucket(id: 5, range: 1700 ..< .infinity,  label: "≥ 1700",    short: "1700+"),
    ]

    static func bucketIndex(forElo elo: Double) -> Int {
        for b in compareEloBuckets where b.range.contains(elo) { return b.id }
        return compareEloBuckets.count - 1
    }

    // MARK: Paar-Auswahl

    /// Wählt das nächste Duell-Paar. Strategie:
    /// 1) Bevorzuge Bilder mit wenigen bisherigen Matches (neue Bilder stabilisieren
    ///    sich schnell, bestehende driften nicht unnötig).
    /// 2) Als Gegner das nächstgelegene ELO — so ergeben sich aussagekräftige
    ///    Duelle statt einseitiger Blowouts.
    func nextComparePair() {
        iphotoBreadcrumb("nextComparePair: start")
        let candidates = visibleDocuments.filter { !$0.isTrashed && !$0.isBackedUp }
        guard candidates.count >= 2 else {
            compare.leftID = nil
            compare.rightID = nil
            return
        }

        // Anchor aus dem Pool der am wenigsten gespielten Bilder wählen
        let minMatches = candidates.map(\.eloMatches).min() ?? 0
        let leastPlayed = candidates.filter { $0.eloMatches <= minMatches + 2 }
        let pool = leastPlayed.count >= 2 ? leastPlayed : candidates
        guard let anchor = pool.randomElement() else { return }

        // Partner: nächstgelegenes ELO (exkl. Anchor, möglichst nicht das letzte Paar)
        let others = candidates.filter { $0.id != anchor.id }
        let sortedByProximity = others.sorted {
            abs($0.elo - anchor.elo) < abs($1.elo - anchor.elo)
        }
        var partner = sortedByProximity.first!
        if candidates.count > 2,
           Set([anchor.id, partner.id]) == compare.lastPair,
           let alt = sortedByProximity.dropFirst().first {
            partner = alt
        }

        compare.leftID = anchor.id
        compare.rightID = partner.id
        compare.lastPair = Set([anchor.id, partner.id])
        ensureComparePreview(forID: anchor.id)
        ensureComparePreview(forID: partner.id)
    }

    // MARK: Duell auflösen

    /// ELO-Update beider Bilder nach dem Verdict. Sterne (rating) werden bewusst
    /// nicht angefasst — ELO ist ein separater Ranking-Score.
    func resolveCompare(_ verdict: CompareVerdict) {
        iphotoBreadcrumb("resolveCompare: start (\(verdict))")
        // Tageslimit prüfen (0 = unbegrenzt)
        if compareDailyLimit > 0 {
            let today = ComparisonState.todayString()
            if UserDefaults.standard.string(forKey: "compare.dailyDate") != today {
                compare.dailyCount = 0
                UserDefaults.standard.set(today, forKey: "compare.dailyDate")
            }
            if compare.dailyCount >= compareDailyLimit {
                stopCompareMode()
                return
            }
        }

        defer {
            iphotoBreadcrumb("resolveCompare: nextComparePair")
            nextComparePair()
        }
        guard let left = compareLeftDocument,
              let right = compareRightDocument else { return }

        compareUndoEntry = CompareUndoEntry(
            leftID: left.id, rightID: right.id,
            leftElo: left.elo, rightElo: right.elo,
            leftMatches: left.eloMatches, rightMatches: right.eloMatches
        )

        let leftScore: Double
        switch verdict {
        case .left:  leftScore = 1.0
        case .right: leftScore = 0.0
        case .equal: leftScore = 0.5
        }

        let (newLeft, newRight) = EloRating.update(
            leftRating: left.elo, leftMatches: left.eloMatches,
            rightRating: right.elo, rightMatches: right.eloMatches,
            leftScore: leftScore
        )
        iphotoBreadcrumb("resolveCompare: applyEloUpdate left \(left.filename)")
        applyEloUpdate(newLeft, to: left.id)
        iphotoBreadcrumb("resolveCompare: applyEloUpdate right \(right.filename)")
        applyEloUpdate(newRight, to: right.id)

        if compareDailyLimit > 0 {
            compare.dailyCount += 1
            UserDefaults.standard.set(compare.dailyCount, forKey: "compare.dailyCount")
        }
        iphotoBreadcrumb("resolveCompare: done")
    }

    // MARK: Compare Undo

    func undoCompare(_ entry: CompareUndoEntry) {
        for i in collection.documents.indices {
            let doc = collection.documents[i]
            if doc.id == entry.leftID {
                collection.documents[i].elo = entry.leftElo
                collection.documents[i].eloMatches = entry.leftMatches
                CatalogStore.shared.saveElo(path: doc.url.path, elo: entry.leftElo, eloMatches: entry.leftMatches)
            } else if doc.id == entry.rightID {
                collection.documents[i].elo = entry.rightElo
                collection.documents[i].eloMatches = entry.rightMatches
                CatalogStore.shared.saveElo(path: doc.url.path, elo: entry.rightElo, eloMatches: entry.rightMatches)
            }
        }
        invalidateVisibleOrder()
    }

    // MARK: ELO-Konvergenz

    /// Konvergenz-Faktor 0.0–1.0: wie stabil ist das ELO-Ranking.
    /// Zielwert: 20 Duelle pro Bild (K-Faktor stabilisiert sich ab ~30 Matches).
    var eloConvergenceFactor: Double {
        let docs = visibleDocuments.filter { !$0.isTrashed && !$0.isBackedUp }
        guard !docs.isEmpty else { return 0 }
        let target: Double = 20
        let sum = docs.reduce(0.0) { $0 + min(1.0, Double($1.eloMatches) / target) }
        return sum / Double(docs.count)
    }

    private func applyEloUpdate(_ newElo: Double, to id: UUID) {
        iphotoBreadcrumb("applyEloUpdate: firstIndex \(id)")
        guard let idx = collection.documentIndexByID[id] else { return }
        guard idx < collection.documents.count else { return }
        iphotoBreadcrumb("applyEloUpdate: write elo idx=\(idx)")
        var doc = collection.documents[idx]
        doc.elo = newElo
        doc.eloMatches += 1
        collection.documents[idx] = doc
        let entry = RatingEntry(rating: doc.rating, flagStatus: doc.flagStatus, colorLabel: doc.colorLabel,
                                elo: doc.elo, eloMatches: doc.eloMatches)
        iphotoBreadcrumb("applyEloUpdate: persist \(doc.filename)")
        RatingStore.shared.save(entry, for: doc.url)
        CatalogStore.shared.saveElo(path: doc.url.path, elo: doc.elo, eloMatches: doc.eloMatches)
    }

    private func ensureComparePreview(forID id: UUID) {
        // Frisch aus der Collection auflösen — Kopien aus visibleDocuments können veraltet sein
        guard let idx0 = collection.documentIndexByID[id], idx0 < collection.documents.count else { return }
        let doc = collection.documents[idx0]
        guard
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
                          let idx = self.collection.documentIndexByURL[url],
                          self.collection.documents[idx].previewImage == nil else { return }
                    var doc = self.collection.documents[idx]
                    doc.previewImage = preview
                    self.collection.documents[idx] = doc
                }
            }
        }
    }
}
