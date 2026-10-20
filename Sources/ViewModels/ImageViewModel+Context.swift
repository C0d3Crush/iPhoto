import AppKit
import Foundation

// MARK: - Sort Criterion

enum SortCriterion: String, CaseIterable {
    case filenameAsc  = "filenameAsc"
    case filenameDesc = "filenameDesc"
    case dateAsc      = "dateAsc"
    case dateDesc     = "dateDesc"
    case ratingDesc   = "ratingDesc"
    case random       = "random"

    var displayName: String {
        switch self {
        case .filenameAsc:  return "Name ↑"
        case .filenameDesc: return "Name ↓"
        case .dateAsc:      return "Datum ↑"
        case .dateDesc:     return "Datum ↓"
        case .ratingDesc:   return "Bewertung"
        case .random:       return "Zufall"
        }
    }

    var icon: String {
        switch self {
        case .filenameAsc:  return "textformat.abc"
        case .filenameDesc: return "textformat.abc"
        case .dateAsc:      return "calendar.badge.clock"
        case .dateDesc:     return "calendar.badge.clock"
        case .ratingDesc:   return "star"
        case .random:       return "shuffle"
        }
    }
}

// MARK: - Library: Navigation Context

extension ImageViewModel {

    var visibleDocuments: [ImageDocument] {
        // Cache-Properties sind nicht lock-geschützt — Zugriff nur vom Main-Thread
        // (gleiche Invariante wie ImageCollection, crasht sofort statt still zu korrumpieren).
        dispatchPrecondition(condition: .onQueue(.main))
        let key = VisibleOrderKey(count: collection.documents.count, nav: navSelection,
                                  sort: sortCriterion, shuffle: shuffledOrder,
                                  version: visibleOrderVersion, expanded: expandedStacks)
        if key == visibleOrderCacheKey, let order = visibleOrderCache {
            if let resolved = visibleResolvedCache,
               visibleResolvedRevision == collection.documentsRevision {
                return resolved
            }
            let byID = Dictionary(collection.documents.map { ($0.id, $0) },
                                  uniquingKeysWith: { a, _ in a })
            let resolved = order.compactMap { byID[$0] }
            visibleResolvedCache = resolved
            visibleResolvedRevision = collection.documentsRevision
            visiblePositionCache = Self.buildPositions(resolved)
            return resolved
        }
        let result = computeVisibleDocuments()
        visibleOrderCache = result.map { $0.id }
        visibleOrderCacheKey = key
        visibleResolvedCache = result
        visibleResolvedRevision = collection.documentsRevision
        visiblePositionCache = Self.buildPositions(result)
        return result
    }

    func invalidateVisibleOrder() {
        visibleOrderVersion &+= 1
        visiblePositionCache = nil
    }

    private static func buildPositions(_ docs: [ImageDocument]) -> [UUID: Int] {
        var m: [UUID: Int] = [:]
        m.reserveCapacity(docs.count)
        for (i, d) in docs.enumerated() { m[d.id] = i }
        return m
    }

    // O(1)-Lookup: Index eines Dokuments in visibleDocuments. Baut den Cache lazy
    // auf, falls er noch nicht existiert (erster Aufruf nach invalidateVisibleOrder).
    // Ersatz für `visibleDocuments.firstIndex(where: { $0.id == id })` in Hot-Paths.
    func visiblePosition(for id: UUID) -> Int? {
        dispatchPrecondition(condition: .onQueue(.main))
        if let cache = visiblePositionCache { return cache[id] }
        _ = visibleDocuments  // triggert Cache-Aufbau
        return visiblePositionCache?[id]
    }

    private func computeVisibleDocuments() -> [ImageDocument] {
        let filtered: [ImageDocument]
        // Interner Papierkorb: getrashte Bilder erscheinen nur im Trash-Tab
        let docs = collection.documents.filter { !$0.isTrashed }
        switch navSelection {
        case .library, nil:
            filtered = docs
        case .album(let id):
            guard let album = library.albums.first(where: { $0.id == id }) else { return [] }
            filtered = docs.filter { album.photoURLs.contains($0.url) }
        case .albumFolder(let id):
            // Rekursiv alle Fotos aus Alben unterhalb dieses Ordners aggregieren.
            // Duplikate zwischen Alben werden ausgeblendet (Set-Union der URLs).
            let descendantAlbumIDs = collectDescendantAlbumIDs(folderID: id)
            var unionURLs = Set<URL>()
            for album in library.albums where descendantAlbumIDs.contains(album.id) {
                for url in album.photoURLs { unionURLs.insert(url) }
            }
            filtered = docs.filter { unionURLs.contains($0.url) }
        case .folder(let id):
            guard let folder = library.watchedFolders.first(where: { $0.id == id }),
                  let (folderURL, stop) = folder.resolveURL() else { return [] }
            defer { stop() }
            let prefix = folderURL.standardized.path
            filtered = docs.filter { $0.url.standardized.path.hasPrefix(prefix) }
        case .smartFolder(let id):
            guard let sf = library.smartFolders.first(where: { $0.id == id }) else { return [] }
            let matched = docs.filter { smartFolderMatches($0, sf: sf) }
            filtered = applySmartFolderLimit(matched, sf: sf)
        case .volume(let id):
            guard let volume = library.detectedVolumes.first(where: { $0.id == id }) else { return [] }
            let prefix = volume.url.standardized.path
            filtered = docs.filter { $0.url.standardized.path.hasPrefix(prefix) }
        case .trash:
            filtered = collection.documents.filter { $0.isTrashed }
        case .duplicates:
            filtered = docs
        case .similar:
            filtered = docs
        case .similarGroup(let idx):
            // Gruppe-als-Album: main viewer scoped auf diese Similar-Cluster —
            // Pfeiltasten navigieren nur innerhalb. Index out-of-range (Gruppen
            // wurden zwischenzeitlich neu berechnet) → leere Auswahl statt Crash.
            let groups = quality.similarGroups
            guard idx >= 0, idx < groups.count else { return [] }
            let groupIDs = Set(groups[idx].map { $0.id })
            filtered = docs.filter { groupIDs.contains($0.id) }
        case .blurry:
            let ids = Set(quality.blurryDocuments.map { $0.id })
            filtered = docs.filter { ids.contains($0.id) }
        case .underexposed:
            let ids = Set(quality.underexposedDocuments.map { $0.id })
            filtered = docs.filter { ids.contains($0.id) }
        case .overexposed:
            let ids = Set(quality.overexposedDocuments.map { $0.id })
            filtered = docs.filter { ids.contains($0.id) }
        case .closedEyes:
            let ids = Set(quality.closedEyeDocuments.map { $0.id })
            filtered = docs.filter { ids.contains($0.id) }
        case .eloRange(let lo, let hi):
            filtered = docs.filter { $0.elo >= lo && $0.elo <= hi }
        }
        return applyStacking(to: applySortCriterion(to: filtered))
    }

    // MARK: - Serienbild-/Bracketing-Stapel

    // Fuji MakerNote 0x1101: 0 = Einzelbild, 1…n = Position in BKT-/CH-/CL-Serie.
    func sequenceNumber(for doc: ImageDocument) -> Int {
        if let v = doc.metadata.first(where: { $0.key == "exif.SequenceNumber" })?.value,
           let n = Int(v) { return n }
        return CatalogStore.shared.exif(forPath: doc.url.path)?.sequenceNumber ?? 0
    }

    // Stapel-Erkennung: pure Logik in StackDetector (siehe dort), hier nur Anbindung an
    // ViewModel-State (stackCounts, expandedStacks) und Rückabbildung IDs → Dokumente.
    private func applyStacking(to sorted: [ImageDocument]) -> [ImageDocument] {
        let seqs = sorted.map { sequenceNumber(for: $0) }
        // Ohne Serienbilder den teuren localizedStandardCompare-Sort komplett überspringen.
        guard seqs.contains(where: { $0 >= 1 }) else {
            stackCounts = [:]
            stackLeaderByMember = [:]
            stackMembersByLeader = [:]
            bestInStackIDs = []
            return sorted
        }
        let items = zip(sorted, seqs).map {
            StackDetector.Item(id: $0.id, filename: $0.filename, seq: $1)
        }
        let r = StackDetector.detect(items)
        stackCounts = r.counts
        stackLeaderByMember = r.leaderByMember
        stackMembersByLeader = r.membersByLeader
        bestInStackIDs = computeBestInStackIDs(from: sorted, membersByLeader: r.membersByLeader)
        guard !r.counts.isEmpty else { return sorted }

        let byID = Dictionary(sorted.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let expandedLeaders = Set(r.counts.keys.filter { id in
            byID[id].map { expandedStacks.contains($0.url.path) } ?? false
        })
        let orderedIDs = StackDetector.displayIDs(sortedIDs: sorted.map { $0.id },
                                                  result: r, expandedLeaders: expandedLeaders)
        return orderedIDs.compactMap { byID[$0] }
    }

    func isStackExpanded(_ doc: ImageDocument) -> Bool {
        expandedStacks.contains(doc.url.path)
    }

    private func computeBestInStackIDs(from docs: [ImageDocument],
                                        membersByLeader: [UUID: [UUID]]) -> Set<UUID> {
        var result = Set<UUID>()
        let byID = Dictionary(docs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for (_, memberIDs) in membersByLeader {
            guard memberIDs.count >= 2 else { continue }
            let scanned = memberIDs.compactMap { byID[$0] }.filter { ($0.blurScore ?? 0) > 0 }
            guard scanned.count >= 2 else { continue }
            let sorted = scanned.sorted { ($0.blurScore ?? 0) > ($1.blurScore ?? 0) }
            if (sorted[0].blurScore ?? 0) / (sorted[1].blurScore ?? 1) > 1.15 {
                result.insert(sorted[0].id)
            }
        }
        return result
    }

    /// Alle Mitglieder (inkl. Anführer), wenn doc der Anführer eines eingeklappten
    /// Stapels ist — Aktionen (Löschen, Bewerten, …) wirken dann auf den ganzen Stapel.
    func collapsedStackMembers(for doc: ImageDocument) -> [ImageDocument]? {
        guard stackCounts[doc.id] != nil, !isStackExpanded(doc),
              let ids = stackMembersByLeader[doc.id], ids.count >= 2 else { return nil }
        let byID = Dictionary(collection.documents.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let members = ids.compactMap { byID[$0] }
        return members.count >= 2 ? members : nil
    }

    func toggleStack(leader: ImageDocument) {
        let key = leader.url.path
        if expandedStacks.contains(key) {
            // Beim Zuklappen: Ist das aktuelle Bild ein Mitglied, den Anführer selektieren,
            // sonst laufen next()/previous() ins Leere.
            if let cur = collection.currentDocument,
               stackLeaderByMember[cur.id] == leader.id, cur.id != leader.id,
               let idx = collectionIndex(for: leader) {
                collection.select(index: idx)
                loadCurrentImage()
            }
            expandedStacks.remove(key)
        } else {
            expandedStacks.insert(key)
        }
        objectWillChange.send()
    }

    func applySortCriterion(to docs: [ImageDocument]) -> [ImageDocument] {
        switch sortCriterion {
        case .filenameAsc:
            return docs.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        case .filenameDesc:
            return docs.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedDescending }
        case .dateAsc:
            return docs.sorted { dateSortKey($0) < dateSortKey($1) }
        case .dateDesc:
            return docs.sorted { dateSortKey($0) > dateSortKey($1) }
        case .ratingDesc:
            return docs.sorted { ($0.rating, $0.filename) > ($1.rating, $1.filename) }
        case .random:
            let orderMap = Dictionary(uniqueKeysWithValues: shuffledOrder.enumerated().map { ($1, $0) })
            return docs.sorted {
                (orderMap[$0.id] ?? Int.max) < (orderMap[$1.id] ?? Int.max)
            }
        }
    }

    private func dateSortKey(_ doc: ImageDocument) -> String {
        // Try in-memory EXIF first, then catalog, then filename as fallback
        if let v = doc.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value, !v.isEmpty {
            return v
        }
        if let d = CatalogStore.shared.image(forPath: doc.url.path)?.dateTaken { return d }
        return doc.filename
    }

    func applyRandomShuffle() {
        shuffledOrder = visibleDocuments.map { $0.id }.shuffled()
    }

    func scheduleSmartFolderCountRefresh() {
        guard !sfCountRefreshScheduled else { return }
        sfCountRefreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.sfCountRefreshScheduled = false
            let docs = self.collection.documents
            let folders = self.library.smartFolders
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                var counts: [UUID: Int] = [:]
                for sf in folders {
                    counts[sf.id] = docs.reduce(0) { $0 + (self.smartFolderMatches($1, sf: sf) ? 1 : 0) }
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, counts != self.smartFolderCounts else { return }
                    self.objectWillChange.send()
                    self.smartFolderCounts = counts
                }
            }
        }
    }

    func smartFolderMatches(_ doc: ImageDocument, sf: SmartFolder) -> Bool {
        smartFolderMatches(doc, sf: sf, visiting: [sf.id])
    }

    private func smartFolderMatches(_ doc: ImageDocument, sf: SmartFolder, visiting: Set<UUID>) -> Bool {
        guard !sf.criteria.isEmpty else { return true }
        let results = sf.criteria.map { c -> Bool in
            switch c.attribute {
            case .flag:
                return applyEnumOp(c.op, lhs: doc.flagStatus, rhs: c.flagValue)
            case .colorLabel:
                return applyEnumOp(c.op, lhs: doc.colorLabel, rhs: c.colorValue)
            case .isRAW:
                return applyEnumOp(c.op, lhs: doc.isRAW, rhs: c.boolValue)
            case .orientation:
                let size: CGSize
                if doc.imageSize != .zero {
                    size = doc.imageSize
                } else if let entry = CatalogStore.shared.image(forPath: doc.url.path),
                          entry.width > 0, entry.height > 0 {
                    size = CGSize(width: entry.width, height: entry.height)
                } else {
                    return false
                }
                let isPortrait = size.height > size.width
                return applyEnumOp(c.op, lhs: isPortrait, rhs: c.boolValue)
            case .hdr:
                let inMemHDR = doc.metadata.first(where: { $0.key == "exif.HDR" })?.value
                let isHDR: Bool
                if let v = inMemHDR {
                    isHDR = (v == "Ja")
                } else {
                    isHDR = CatalogStore.shared.exif(forPath: doc.url.path)?.hdr ?? false
                }
                return applyEnumOp(c.op, lhs: isHDR, rhs: c.boolValue)
            case .rating:
                return applyNumericOp(c.op, value: Double(doc.rating), lo: Double(c.ratingValue), hi: Double(c.ratingValue2))
            case .eloRating:
                return applyNumericOp(c.op, value: doc.elo, lo: c.numericValue, hi: c.numericValue2)
            case .iso:
                if let v = metadataDouble(doc, key: "exif.ISO", prefix: "ISO ") {
                    return applyNumericOp(c.op, value: v, lo: c.numericValue, hi: c.numericValue2)
                } else if let exif = CatalogStore.shared.exif(forPath: doc.url.path), let iso = exif.iso {
                    return applyNumericOp(c.op, value: Double(iso), lo: c.numericValue, hi: c.numericValue2)
                }
                return false
            case .focalLength:
                if let v = metadataDouble(doc, key: "exif.FocalLength", suffix: " mm") {
                    return applyNumericOp(c.op, value: v, lo: c.numericValue, hi: c.numericValue2)
                } else if let exif = CatalogStore.shared.exif(forPath: doc.url.path), let fl = exif.focalLength {
                    return applyNumericOp(c.op, value: fl, lo: c.numericValue, hi: c.numericValue2)
                }
                return false
            case .aperture:
                if let v = metadataDouble(doc, key: "exif.FNumber", prefix: "f/") {
                    return applyNumericOp(c.op, value: v, lo: c.numericValue, hi: c.numericValue2)
                } else if let exif = CatalogStore.shared.exif(forPath: doc.url.path), let ap = exif.aperture {
                    return applyNumericOp(c.op, value: ap, lo: c.numericValue, hi: c.numericValue2)
                }
                return false
            case .filmSimulation:
                return applyTextOp(c.op, haystack: catalogExifString(doc, key: "exif.FilmSimulation"), needle: c.textValue)
            case .cameraMake:
                return applyTextOp(c.op, haystack: catalogExifString(doc, key: "tiff.Make"), needle: c.textValue)
            case .cameraModel:
                return applyTextOp(c.op, haystack: catalogExifString(doc, key: "tiff.Model"), needle: c.textValue)
            case .lens:
                return applyTextOp(c.op, haystack: catalogExifString(doc, key: "exif.LensModel"), needle: c.textValue)
            case .captureDate:
                let raw = metadataString(doc, key: "exif.DateTimeOriginal")
                let dateStr = raw.isEmpty ? (CatalogStore.shared.image(forPath: doc.url.path)?.dateTaken ?? "") : raw
                guard !dateStr.isEmpty, let date = parseExifDate(dateStr) else { return false }
                return applyDateOp(c.op, date: date, lo: c.dateValue, hi: c.dateValue2, dynamic: c.dynamicDateRange)
            case .filename:
                return applyTextOp(c.op, haystack: doc.filename, needle: c.textValue)
            case .motif:
                let tags: [String]
                if doc.motifScanned {
                    tags = doc.motifTags ?? []
                } else if let stored = CatalogStore.shared.motifs(forPath: doc.url.path) {
                    tags = stored
                } else {
                    return false
                }
                let needle = c.textValue.lowercased()
                let hasMotif = tags.contains { $0.contains(needle) || needle.contains($0) }
                switch c.op {
                case .isExact: return hasMotif
                case .isNot:   return !hasMotif
                default:       return hasMotif
                }
            case .album:
                guard let albumID = UUID(uuidString: c.textValue),
                      let album = library.albums.first(where: { $0.id == albumID }) else { return false }
                let inAlbum = album.photoURLs.contains(doc.url)
                return applyEnumOp(c.op, lhs: inAlbum, rhs: true)
            case .smartFolderRef:
                guard let refID = UUID(uuidString: c.textValue),
                      !visiting.contains(refID),
                      let refSf = library.smartFolders.first(where: { $0.id == refID }) else {
                    return c.op == .isNot
                }
                let isInRef = smartFolderMatches(doc, sf: refSf, visiting: visiting.union([refID]))
                return applyEnumOp(c.op, lhs: isInRef, rhs: true)
            }
        }
        return sf.matchAll ? results.allSatisfy { $0 } : results.contains { $0 }
    }

    private func applySmartFolderLimit(_ docs: [ImageDocument], sf: SmartFolder) -> [ImageDocument] {
        guard sf.limitEnabled, sf.limitCount > 0, docs.count > sf.limitCount else { return docs }
        switch sf.limitSelection {
        case .random:
            return Array(docs.shuffled().prefix(sf.limitCount))
        case .highestRating:
            return Array(docs.sorted { $0.rating > $1.rating }.prefix(sf.limitCount))
        case .lowestRating:
            return Array(docs.sorted { $0.rating < $1.rating }.prefix(sf.limitCount))
        case .newest:
            return Array(docs.sorted { dateSortKey($0) > dateSortKey($1) }.prefix(sf.limitCount))
        case .oldest:
            return Array(docs.sorted { dateSortKey($0) < dateSortKey($1) }.prefix(sf.limitCount))
        }
    }

    private func applyEnumOp<T: Equatable>(_ op: SmartFolderOperator, lhs: T, rhs: T) -> Bool {
        switch op {
        case .isExact: return lhs == rhs
        case .isNot:   return lhs != rhs
        default:       return false
        }
    }

    private func applyNumericOp(_ op: SmartFolderOperator, value: Double, lo: Double, hi: Double) -> Bool {
        switch op {
        case .isExact:     return value == lo
        case .isNot:       return value != lo
        case .greaterThan: return value > lo
        case .lessThan:    return value < lo
        case .inRange:     return value >= lo && value <= hi
        default:           return false
        }
    }

    private func applyTextOp(_ op: SmartFolderOperator, haystack: String, needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        switch op {
        case .contains:    return haystack.localizedCaseInsensitiveContains(needle)
        case .notContains: return !haystack.localizedCaseInsensitiveContains(needle)
        case .isExact:     return haystack.localizedCaseInsensitiveCompare(needle) == .orderedSame
        case .isNot:       return haystack.localizedCaseInsensitiveCompare(needle) != .orderedSame
        case .beginsWith:  return haystack.lowercased().hasPrefix(needle.lowercased())
        case .endsWith:    return haystack.lowercased().hasSuffix(needle.lowercased())
        default:           return false
        }
    }

    private func metadataString(_ doc: ImageDocument, key: String) -> String {
        doc.metadata.first(where: { $0.key == key })?.value ?? ""
    }

    private func catalogExifString(_ doc: ImageDocument, key: String) -> String {
        let inMem = metadataString(doc, key: key)
        if !inMem.isEmpty { return inMem }
        let exif = CatalogStore.shared.exif(forPath: doc.url.path)
        switch key {
        case "tiff.Make":             return CatalogStore.shared.image(forPath: doc.url.path)?.cameraMake ?? ""
        case "tiff.Model":            return CatalogStore.shared.image(forPath: doc.url.path)?.cameraModel ?? ""
        case "exif.LensModel":        return exif?.lensModel ?? ""
        case "exif.FilmSimulation":   return exif?.filmSimulation ?? ""
        default:                      return ""
        }
    }

    private func parseExifDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f.date(from: s)
    }

    private func applyDateOp(_ op: SmartFolderOperator, date: Date, lo: Date, hi: Date, dynamic: DynamicDateRange) -> Bool {
        switch op {
        case .isBefore:    return date < lo
        case .isAfter:     return date > lo
        case .inDateRange: return date >= lo && date <= hi
        case .isDynamic:   return dynamic.matches(date)
        default:           return false
        }
    }

    private func metadataDouble(_ doc: ImageDocument, key: String, prefix: String = "", suffix: String = "") -> Double? {
        guard let raw = doc.metadata.first(where: { $0.key == key })?.value else { return nil }
        var s = raw
        if !prefix.isEmpty, s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)) }
        if !suffix.isEmpty, s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)) }
        return Double(s.trimmingCharacters(in: .whitespaces))
    }

    // Re-evaluates current selection against the active context filter.
    // Call after any change that might invalidate the current document (e.g. SmartFolder edit).
    func revalidateSelectionForCurrentContext() {
        let visible = visibleDocuments
        let curInVisible = collection.currentDocument.map { doc in
            visible.contains(where: { $0.id == doc.id })
        } ?? false
        guard !curInVisible else { return }

        // Nächstbestes Bild: das im Collection-Index direkt nach dem entfernten,
        // Fallback auf das davor.
        let removedIdx = collection.currentIndex
        let candidates = visible.compactMap { doc -> (doc: ImageDocument, colIdx: Int)? in
            guard let i = collectionIndex(for: doc) else { return nil }
            return (doc, i)
        }
        let next = candidates.filter { $0.colIdx > removedIdx }.min(by: { $0.colIdx < $1.colIdx })
                ?? candidates.filter { $0.colIdx < removedIdx }.max(by: { $0.colIdx < $1.colIdx })

        if let best = next {
            collection.select(index: best.colIdx)
            loadCurrentImage()
        } else {
            collection.selectedIndices = []
        }
    }
}
