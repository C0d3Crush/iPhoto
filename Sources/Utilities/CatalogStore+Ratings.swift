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
}
