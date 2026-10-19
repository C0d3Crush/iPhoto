import Foundation
import SQLite3

// MARK: - Motif Tags
//
// Persistiert automatisch erkannte Motive (VNClassifyImageRequest) pro Bild.
// motif_tags: kommagetrennte Identifier-Liste (z.B. "sky,cloud,nature").
// In-Memory-Cache analog zu Quality: SmartFolder-Matching läuft pro Render
// über alle Bilder — ohne Cache wären das hunderte queue.sync-SQLite-SELECTs.

extension CatalogStore {

    private static var motifCache: [String: [String]] = [:]
    private static var motifCacheMisses = Set<String>()
    private static let motifCacheLock = NSLock()

    // MARK: - Migration (aufgerufen aus createSchema)

    func migrateMotifColumns() {
        exec("ALTER TABLE images ADD COLUMN motif_tags TEXT")
        if exec("ALTER TABLE images ADD COLUMN motif_scanned INTEGER NOT NULL DEFAULT 0") {
            exec("CREATE INDEX IF NOT EXISTS idx_images_motif_scanned ON images(motif_scanned)")
        }
    }

    // MARK: - Write

    func upsertMotifs(path: String, tags: [String]) {
        let tagsStr = tags.joined(separator: ",")
        queue.sync {
            let stmt = prepare("UPDATE images SET motif_tags=?, motif_scanned=1 WHERE path=?")
            bind(stmt, 1, tagsStr)
            bind(stmt, 2, path)
            step(stmt); sqlite3_finalize(stmt)
        }
        Self.motifCacheLock.lock()
        Self.motifCache[path] = tags
        Self.motifCacheMisses.remove(path)
        Self.motifCacheLock.unlock()
    }

    // MARK: - Read

    func motifs(forPath path: String) -> [String]? {
        Self.motifCacheLock.lock()
        let cached = Self.motifCache[path]
        let knownMiss = Self.motifCacheMisses.contains(path)
        Self.motifCacheLock.unlock()
        if let hit = cached { return hit }
        if knownMiss { return nil }
        return queue.sync {
            let stmt = prepare("SELECT motif_tags, motif_scanned FROM images WHERE path=?")
            bind(stmt, 1, path)
            guard step(stmt) == SQLITE_ROW else {
                sqlite3_finalize(stmt)
                Self.motifCacheLock.lock()
                Self.motifCacheMisses.insert(path)
                Self.motifCacheLock.unlock()
                return nil
            }
            let scanned = sqlite3_column_int(stmt, 1) != 0
            let tagsRaw: String? = sqlite3_column_type(stmt, 0) == SQLITE_NULL ? nil
                : String(cString: sqlite3_column_text(stmt, 0))
            sqlite3_finalize(stmt)
            guard scanned else {
                Self.motifCacheLock.lock()
                Self.motifCacheMisses.insert(path)
                Self.motifCacheLock.unlock()
                return nil
            }
            let tags = tagsRaw.map { $0.isEmpty ? [] : $0.split(separator: ",").map(String.init) } ?? []
            Self.motifCacheLock.lock()
            Self.motifCache[path] = tags
            Self.motifCacheLock.unlock()
            return tags
        }
    }

    func pathsNeedingMotifScan() -> [String] {
        queue.sync {
            let stmt = prepare("SELECT path FROM images WHERE motif_scanned=0 ORDER BY filename")
            var out: [String] = []
            while step(stmt) == SQLITE_ROW {
                out.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    // Wird nur aus open() heraus aufgerufen — open() läuft bereits innerhalb von
    // queue.sync, daher hier kein erneutes queue.sync (sonst Deadlock).
    func loadMotifCache() {
        let stmt = prepare("SELECT path, motif_tags FROM images WHERE motif_scanned=1")
        var rows: [(String, String?)] = []
        while step(stmt) == SQLITE_ROW {
            let path = String(cString: sqlite3_column_text(stmt, 0))
            let tags: String? = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil
                : String(cString: sqlite3_column_text(stmt, 1))
            rows.append((path, tags))
        }
        sqlite3_finalize(stmt)
        Self.motifCacheLock.lock()
        for (path, raw) in rows {
            Self.motifCache[path] = raw.map { $0.isEmpty ? [] : $0.split(separator: ",").map(String.init) } ?? []
        }
        Self.motifCacheLock.unlock()
    }
}
