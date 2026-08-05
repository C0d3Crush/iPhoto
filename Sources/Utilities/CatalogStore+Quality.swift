import Foundation
import SQLite3

// MARK: - Quality Scores & Overrides
//
// Persistiert die pro-Bild-Qualitätsanalyse (Blur, Über-/Unterbelichtung) plus pHash für
// Similarity. Overrides speichern Nutzer-Korrekturen ("Bild ist doch nicht unscharf"), damit
// diese über Sessions hinweg respektiert werden.
//
// In-Memory-Cache analog zum EXIF-Cache: Views (BlurryView, ExposureView) fragen pro Render
// hunderte Pfade ab; ohne Cache wären das serialisierte queue.sync-SQLite-SELECTs pro Bild.

struct QualityRecord {
    let blurScore: Double?
    let underRatio: Double?
    let overRatio: Double?
    let phash: UInt64?
    let phashV: UInt64?
    let blurOverride: Bool
    let underOverride: Bool
    let overOverride: Bool
    let scanned: Bool
}

extension CatalogStore {

    // Cache-Speicher liegt als statisches Dictionary im shared-Objekt; da CatalogStore ein
    // Singleton ist, teilen sich alle Caller den gleichen Cache. Zugriff serialisiert über
    // die bestehende queue, weil Reads/Writes von verschiedenen Threads kommen können.
    private static var qualityCache: [String: QualityRecord] = [:]
    private static var qualityCacheMisses = Set<String>()
    private static let qualityCacheLock = NSLock()

    func upsertQuality(path: String, blurScore: Double?, underRatio: Double?, overRatio: Double?, phash: UInt64?, phashV: UInt64?) {
        queue.sync {
            let stmt = prepare("""
                UPDATE images SET blur_score=?, under_ratio=?, over_ratio=?, phash=?, phash_v=?, quality_scanned=1
                WHERE path=?
            """)
            if let v = blurScore { sqlite3_bind_double(stmt, 1, v) } else { sqlite3_bind_null(stmt, 1) }
            if let v = underRatio { sqlite3_bind_double(stmt, 2, v) } else { sqlite3_bind_null(stmt, 2) }
            if let v = overRatio { sqlite3_bind_double(stmt, 3, v) } else { sqlite3_bind_null(stmt, 3) }
            if let v = phash { sqlite3_bind_int64(stmt, 4, Int64(bitPattern: v)) } else { sqlite3_bind_null(stmt, 4) }
            if let v = phashV { sqlite3_bind_int64(stmt, 5, Int64(bitPattern: v)) } else { sqlite3_bind_null(stmt, 5) }
            bind(stmt, 6, path)
            step(stmt); sqlite3_finalize(stmt)
        }
        Self.qualityCacheLock.lock()
        let existing = Self.qualityCache[path]
        Self.qualityCache[path] = QualityRecord(
            blurScore: blurScore, underRatio: underRatio, overRatio: overRatio, phash: phash, phashV: phashV,
            blurOverride: existing?.blurOverride ?? false,
            underOverride: existing?.underOverride ?? false,
            overOverride: existing?.overOverride ?? false,
            scanned: true
        )
        Self.qualityCacheMisses.remove(path)
        Self.qualityCacheLock.unlock()
    }

    func setQualityOverride(path: String, blur: Bool? = nil, under: Bool? = nil, over: Bool? = nil) {
        queue.sync {
            var sets: [String] = []
            if blur  != nil { sets.append("blur_override=?") }
            if under != nil { sets.append("under_override=?") }
            if over  != nil { sets.append("over_override=?") }
            guard !sets.isEmpty else { return }
            let stmt = prepare("UPDATE images SET \(sets.joined(separator: ",")) WHERE path=?")
            var i: Int32 = 1
            if let v = blur  { sqlite3_bind_int(stmt, i, v ? 1 : 0); i += 1 }
            if let v = under { sqlite3_bind_int(stmt, i, v ? 1 : 0); i += 1 }
            if let v = over  { sqlite3_bind_int(stmt, i, v ? 1 : 0); i += 1 }
            bind(stmt, i, path)
            step(stmt); sqlite3_finalize(stmt)
        }
        Self.qualityCacheLock.lock()
        let existing = Self.qualityCache[path] ?? QualityRecord(
            blurScore: nil, underRatio: nil, overRatio: nil, phash: nil, phashV: nil,
            blurOverride: false, underOverride: false, overOverride: false, scanned: false
        )
        Self.qualityCache[path] = QualityRecord(
            blurScore: existing.blurScore, underRatio: existing.underRatio,
            overRatio: existing.overRatio, phash: existing.phash, phashV: existing.phashV,
            blurOverride: blur ?? existing.blurOverride,
            underOverride: under ?? existing.underOverride,
            overOverride: over ?? existing.overOverride,
            scanned: existing.scanned
        )
        Self.qualityCacheMisses.remove(path)
        Self.qualityCacheLock.unlock()
    }

    func quality(forPath path: String) -> QualityRecord? {
        Self.qualityCacheLock.lock()
        let cached = Self.qualityCache[path]
        let knownMiss = Self.qualityCacheMisses.contains(path)
        Self.qualityCacheLock.unlock()
        if let hit = cached { return hit }
        if knownMiss { return nil }
        return queue.sync {
            let stmt = prepare("SELECT blur_score, under_ratio, over_ratio, phash, phash_v, blur_override, under_override, over_override, quality_scanned FROM images WHERE path=?")
            bind(stmt, 1, path)
            guard step(stmt) == SQLITE_ROW else {
                sqlite3_finalize(stmt)
                Self.qualityCacheLock.lock()
                Self.qualityCacheMisses.insert(path)
                Self.qualityCacheLock.unlock()
                return nil
            }
            let bs: Double? = sqlite3_column_type(stmt, 0) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 0)
            let ur: Double? = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 1)
            let or: Double? = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 2)
            let ph: UInt64? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : UInt64(bitPattern: sqlite3_column_int64(stmt, 3))
            let phV: UInt64? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : UInt64(bitPattern: sqlite3_column_int64(stmt, 4))
            let bov = sqlite3_column_int(stmt, 5) != 0
            let uov = sqlite3_column_int(stmt, 6) != 0
            let oov = sqlite3_column_int(stmt, 7) != 0
            let scn = sqlite3_column_int(stmt, 8) != 0
            sqlite3_finalize(stmt)
            let rec = QualityRecord(blurScore: bs, underRatio: ur, overRatio: or, phash: ph, phashV: phV,
                                    blurOverride: bov, underOverride: uov, overOverride: oov, scanned: scn)
            Self.qualityCacheLock.lock()
            Self.qualityCache[path] = rec
            Self.qualityCacheLock.unlock()
            return rec
        }
    }

    // Bulk-Zugriff für Similarity-Grouping/Filter: einmal alle Records laden statt N Roundtrips.
    func allQualityRecords() -> [String: QualityRecord] {
        queue.sync {
            let stmt = prepare("SELECT path, blur_score, under_ratio, over_ratio, phash, phash_v, blur_override, under_override, over_override, quality_scanned FROM images WHERE quality_scanned=1")
            var out: [String: QualityRecord] = [:]
            while step(stmt) == SQLITE_ROW {
                let path = String(cString: sqlite3_column_text(stmt, 0))
                let bs: Double? = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 1)
                let ur: Double? = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 2)
                let or: Double? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 3)
                let ph: UInt64? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : UInt64(bitPattern: sqlite3_column_int64(stmt, 4))
                let phV: UInt64? = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : UInt64(bitPattern: sqlite3_column_int64(stmt, 5))
                let bov = sqlite3_column_int(stmt, 6) != 0
                let uov = sqlite3_column_int(stmt, 7) != 0
                let oov = sqlite3_column_int(stmt, 8) != 0
                let scn = sqlite3_column_int(stmt, 9) != 0
                out[path] = QualityRecord(blurScore: bs, underRatio: ur, overRatio: or, phash: ph, phashV: phV,
                                          blurOverride: bov, underOverride: uov, overOverride: oov, scanned: scn)
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func pathsNeedingQualityScan() -> [String] {
        queue.sync {
            let stmt = prepare("SELECT path FROM images WHERE quality_scanned=0 ORDER BY filename")
            var out: [String] = []
            while step(stmt) == SQLITE_ROW {
                out.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    // MARK: - Duplicate / Similar Group Persistence
    //
    // Speichert die von detectDuplicates bzw. detectSimilarImages ermittelten Gruppen als
    // group_id-Spalte pro Bild. Beim App-Start werden die Gruppen mit einem GROUP BY
    // rekonstruiert — deutlich billiger als Union-Find über hunderte pHashes neu zu laufen.
    //
    // API-Kontrakt: setDuplicateGroups/setSimilarGroups sind idempotent — sie NULL-en
    // vorher alle Werte, damit gelöschte oder umsortierte Gruppen nicht als Geister leben.

    func setDuplicateGroups(_ groups: [[String]]) {
        setGroups(column: "duplicate_group_id", groups: groups)
    }

    func setSimilarGroups(_ groups: [[String]]) {
        setGroups(column: "similar_group_id", groups: groups)
    }

    func loadDuplicateGroups() -> [[String]] {
        loadGroups(column: "duplicate_group_id")
    }

    func loadSimilarGroups() -> [[String]] {
        loadGroups(column: "similar_group_id")
    }

    private func setGroups(column: String, groups: [[String]]) {
        queue.sync {
            exec("BEGIN")
            exec("UPDATE images SET \(column)=NULL")
            let stmt = prepare("UPDATE images SET \(column)=? WHERE path=?")
            for (gIdx, group) in groups.enumerated() {
                let gid = Int32(gIdx + 1)
                for path in group {
                    sqlite3_reset(stmt)
                    sqlite3_bind_int(stmt, 1, gid)
                    bind(stmt, 2, path)
                    step(stmt)
                }
            }
            sqlite3_finalize(stmt)
            exec("COMMIT")
        }
    }

    private func loadGroups(column: String) -> [[String]] {
        queue.sync {
            let stmt = prepare("SELECT \(column), path FROM images WHERE \(column) IS NOT NULL ORDER BY \(column), path")
            var buckets: [Int32: [String]] = [:]
            while step(stmt) == SQLITE_ROW {
                let gid = sqlite3_column_int(stmt, 0)
                let path = String(cString: sqlite3_column_text(stmt, 1))
                buckets[gid, default: []].append(path)
            }
            sqlite3_finalize(stmt)
            return buckets.keys.sorted().compactMap { buckets[$0] }.filter { $0.count > 1 }
        }
    }
}
