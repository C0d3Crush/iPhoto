import Foundation
import SQLite3

// MARK: - Ratings & Trash

extension CatalogStore {

    func saveRating(path: String, rating: Int, flag: String, colorLabel: String) {
        queue.sync {
            let stmt = prepare("""
                INSERT INTO ratings (image_path,rating,flag,color_label,updated_at) VALUES (?,?,?,?,?)
                ON CONFLICT(image_path) DO UPDATE SET
                    rating=excluded.rating, flag=excluded.flag,
                    color_label=excluded.color_label, updated_at=excluded.updated_at
            """)
            bind(stmt, 1, path)
            sqlite3_bind_int(stmt, 2, Int32(rating))
            bind(stmt, 3, flag); bind(stmt, 4, colorLabel); bind(stmt, 5, iso8601())
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    /// Schreibt viele Bewertungen in einer einzigen Transaktion (ein prepare, N steps) —
    /// vermeidet N einzelne Commits bei Bulk-Import/Batch-Set.
    @discardableResult
    func saveRatings(_ entries: [(path: String, rating: Int, flag: String, colorLabel: String)]) -> Bool {
        guard !entries.isEmpty else { return true }
        return queue.sync {
            guard exec("BEGIN") else { return false }
            let stmt = prepare("""
                INSERT INTO ratings (image_path,rating,flag,color_label,updated_at) VALUES (?,?,?,?,?)
                ON CONFLICT(image_path) DO UPDATE SET
                    rating=excluded.rating, flag=excluded.flag,
                    color_label=excluded.color_label, updated_at=excluded.updated_at
            """)
            let now = iso8601()
            var ok = true
            for e in entries {
                sqlite3_reset(stmt)
                bind(stmt, 1, e.path)
                sqlite3_bind_int(stmt, 2, Int32(e.rating))
                bind(stmt, 3, e.flag); bind(stmt, 4, e.colorLabel); bind(stmt, 5, now)
                if step(stmt) != SQLITE_DONE { ok = false; break }
            }
            sqlite3_finalize(stmt)
            if ok {
                guard exec("COMMIT") else { exec("ROLLBACK"); return false }
            } else {
                exec("ROLLBACK")
            }
            return ok
        }
    }

    func rating(forPath path: String) -> (rating: Int, flag: String, colorLabel: String)? {
        queue.sync {
            let stmt = prepare("SELECT rating,flag,color_label FROM ratings WHERE image_path=?")
            bind(stmt, 1, path)
            guard step(stmt) == SQLITE_ROW else { sqlite3_finalize(stmt); return nil }
            let r = (Int(sqlite3_column_int(stmt, 0)),
                     String(cString: sqlite3_column_text(stmt, 1)),
                     String(cString: sqlite3_column_text(stmt, 2)))
            sqlite3_finalize(stmt); return r
        }
    }

    func allRatings() -> [String: (rating: Int, flag: String, colorLabel: String)] {
        queue.sync {
            let stmt = prepare("SELECT image_path,rating,flag,color_label FROM ratings")
            var out: [String: (rating: Int, flag: String, colorLabel: String)] = [:]
            while step(stmt) == SQLITE_ROW {
                out[String(cString: sqlite3_column_text(stmt, 0))] =
                    (Int(sqlite3_column_int(stmt, 1)),
                     String(cString: sqlite3_column_text(stmt, 2)),
                     String(cString: sqlite3_column_text(stmt, 3)))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func ratingStats() -> (rated: Int, flagged: Int, byFlag: [String: Int], byColor: [String: Int]) {
        queue.sync {
            var rated = 0, flagged = 0
            var byFlag: [String: Int] = [:], byColor: [String: Int] = [:]
            let s1 = prepare("SELECT COUNT(*) FROM ratings WHERE rating > 0")
            if step(s1) == SQLITE_ROW { rated = Int(sqlite3_column_int(s1, 0)) }
            sqlite3_finalize(s1)
            let s2 = prepare("SELECT flag, COUNT(*) FROM ratings WHERE flag != 'none' AND flag != '' GROUP BY flag")
            while step(s2) == SQLITE_ROW {
                let f = String(cString: sqlite3_column_text(s2, 0))
                let n = Int(sqlite3_column_int(s2, 1))
                byFlag[f] = n; flagged += n
            }
            sqlite3_finalize(s2)
            let s3 = prepare("SELECT color_label, COUNT(*) FROM ratings WHERE color_label != 'none' AND color_label != '' GROUP BY color_label")
            while step(s3) == SQLITE_ROW {
                byColor[String(cString: sqlite3_column_text(s3, 0))] = Int(sqlite3_column_int(s3, 1))
            }
            sqlite3_finalize(s3)
            return (rated, flagged, byFlag, byColor)
        }
    }

    func eloCount() -> Int {
        queue.sync {
            let stmt = prepare("SELECT COUNT(*) FROM ratings WHERE elo > 0")
            let n = step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
            sqlite3_finalize(stmt); return n
        }
    }

    func ratingDistribution() -> [Int: Int] {
        queue.sync {
            let stmt = prepare("SELECT rating, COUNT(*) FROM ratings WHERE rating > 0 GROUP BY rating ORDER BY rating")
            var out: [Int: Int] = [:]
            while step(stmt) == SQLITE_ROW {
                out[Int(sqlite3_column_int(stmt, 0))] = Int(sqlite3_column_int(stmt, 1))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    // MARK: - ELO (Bildvergleich)

    /// Persistiert nur die ELO-Spalten — bewusst getrennt von saveRating(), damit
    /// ein Duell-Update nicht Sterne/Flag/Farb-Label zurücksetzt.
    func saveElo(path: String, elo: Double, eloMatches: Int) {
        queue.sync {
            let stmt = prepare("""
                INSERT INTO ratings (image_path,rating,flag,color_label,elo,elo_matches,updated_at)
                VALUES (?,0,'none','none',?,?,?)
                ON CONFLICT(image_path) DO UPDATE SET
                    elo=excluded.elo, elo_matches=excluded.elo_matches,
                    updated_at=excluded.updated_at
            """)
            bind(stmt, 1, path)
            sqlite3_bind_double(stmt, 2, elo)
            sqlite3_bind_int(stmt, 3, Int32(eloMatches))
            bind(stmt, 4, iso8601())
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    func elo(forPath path: String) -> (elo: Double, matches: Int)? {
        queue.sync {
            let stmt = prepare("SELECT elo,elo_matches FROM ratings WHERE image_path=?")
            bind(stmt, 1, path)
            guard step(stmt) == SQLITE_ROW else { sqlite3_finalize(stmt); return nil }
            let r = (sqlite3_column_double(stmt, 0), Int(sqlite3_column_int(stmt, 1)))
            sqlite3_finalize(stmt); return r
        }
    }

    func allElos() -> [String: (elo: Double, matches: Int)] {
        queue.sync {
            let stmt = prepare("SELECT image_path,elo,elo_matches FROM ratings")
            var out: [String: (elo: Double, matches: Int)] = [:]
            while step(stmt) == SQLITE_ROW {
                out[String(cString: sqlite3_column_text(stmt, 0))] =
                    (sqlite3_column_double(stmt, 1), Int(sqlite3_column_int(stmt, 2)))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func removeRating(path: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM ratings WHERE image_path=?")
            bind(stmt, 1, path); step(stmt); sqlite3_finalize(stmt)
        }
    }

    // MARK: - Trash (interner Papierkorb)

    func setTrashed(paths: [String], _ trashed: Bool) {
        guard !paths.isEmpty else { return }
        queue.sync {
            exec("BEGIN")
            for path in paths {
                let stmt = trashed
                    ? prepare("INSERT OR REPLACE INTO trash (image_path, trashed_at) VALUES (?, datetime('now'))")
                    : prepare("DELETE FROM trash WHERE image_path=?")
                bind(stmt, 1, path)
                step(stmt); sqlite3_finalize(stmt)
            }
            exec("COMMIT")
        }
    }

    func trashedPaths() -> Set<String> {
        queue.sync {
            let stmt = prepare("SELECT image_path FROM trash")
            var out = Set<String>()
            while step(stmt) == SQLITE_ROW {
                out.insert(String(cString: sqlite3_column_text(stmt, 0)))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func emptyTrash() -> Int {
        queue.sync {
            let count = trashedPathsUnsafe()
            exec("DELETE FROM trash")
            return count
        }
    }

    private func trashedPathsUnsafe() -> Int {
        let stmt = prepare("SELECT COUNT(*) FROM trash")
        let n = step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
        sqlite3_finalize(stmt); return n
    }

    // MARK: - Backed-up (Bildarchiv)

    func setBackedUp(paths: [String], _ value: Bool) {
        guard !paths.isEmpty else { return }
        queue.sync {
            exec("BEGIN")
            for path in paths {
                let stmt = value
                    ? prepare("INSERT OR REPLACE INTO backed_up(image_path, backed_at) VALUES(?, datetime('now'))")
                    : prepare("DELETE FROM backed_up WHERE image_path=?")
                bind(stmt, 1, path)
                step(stmt); sqlite3_finalize(stmt)
            }
            exec("COMMIT")
        }
    }

    func backedUpPaths() -> Set<String> {
        queue.sync {
            let stmt = prepare("SELECT image_path FROM backed_up")
            var out = Set<String>()
            while step(stmt) == SQLITE_ROW {
                out.insert(String(cString: sqlite3_column_text(stmt, 0)))
            }
            sqlite3_finalize(stmt)
            return out
        }
    }
}
