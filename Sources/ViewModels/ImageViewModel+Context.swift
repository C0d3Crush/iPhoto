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
        let filtered: [ImageDocument]
        switch navSelection {
        case .library, nil:
            filtered = collection.documents
        case .album(let id):
            guard let album = albums.first(where: { $0.id == id }) else { return [] }
            filtered = collection.documents.filter { album.photoURLs.contains($0.url) }
        case .folder(let id):
            guard let folder = watchedFolders.first(where: { $0.id == id }),
                  let (folderURL, stop) = folder.resolveURL() else { return [] }
            defer { stop() }
            let prefix = folderURL.standardized.path
            filtered = collection.documents.filter { $0.url.standardized.path.hasPrefix(prefix) }
        case .smartFolder(let id):
            guard let sf = smartFolders.first(where: { $0.id == id }) else { return [] }
            filtered = collection.documents.filter { smartFolderMatches($0, sf: sf) }
        case .volume(let id):
            guard let volume = detectedVolumes.first(where: { $0.id == id }) else { return [] }
            let prefix = volume.url.standardized.path
            filtered = collection.documents.filter { $0.url.standardized.path.hasPrefix(prefix) }
        }
        return applySortCriterion(to: filtered)
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

    func smartFolderMatches(_ doc: ImageDocument, sf: SmartFolder) -> Bool {
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
            case .album:
                guard let albumID = UUID(uuidString: c.textValue),
                      let album = albums.first(where: { $0.id == albumID }) else { return false }
                let inAlbum = album.photoURLs.contains(doc.url)
                return applyEnumOp(c.op, lhs: inAlbum, rhs: true)
            }
        }
        return sf.matchAll ? results.allSatisfy { $0 } : results.contains { $0 }
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
