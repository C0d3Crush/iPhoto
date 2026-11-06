import Foundation
import SQLite3

// Integritäts-Check: findet Zeilen in abgeleiteten Tabellen (Bewertungen, Papierkorb,
// Album-Zuordnungen, Anpassungen, Gesichter), deren image_path keinen Eintrag mehr in
// `images` hat, sowie Album-Zuordnungen auf gelöschte Alben. Entsteht z. B. nach
// manuellem Entfernen von Katalog-Einträgen oder abgebrochenen Migrationen.
// Ein SELECT pro Tabelle (NOT IN mit Subquery → SQLite baut einen temporären Index,
// O(N log N)), alles in einem queue.sync — kein Per-Row-Roundtrip.
extension CatalogStore {

    /// (Kategorie, Tabelle, Spalte, Referenz-Subquery). Reihenfolge = Ausgabereihenfolge.
    static let orphanChecks: [(key: String, table: String, column: String, ref: String)] = [
        ("ratings",     "ratings",      "image_path", "SELECT path FROM images"),
        ("trash",       "trash",        "image_path", "SELECT path FROM images"),
        ("album_images","album_images", "image_path", "SELECT path FROM images"),
        ("album_refs",  "album_images", "album_id",   "SELECT id FROM albums"),
        ("adjustments", "adjustments",  "image_path", "SELECT path FROM images"),
        ("faces",       "faces",        "image_path", "SELECT path FROM images"),
    ]

    /// Kategorie → sortierte, eindeutige verwaiste Schlüssel (Pfad bzw. Album-ID).
    func orphanRows() -> [String: [String]] {
        queue.sync {
            var result: [String: [String]] = [:]
            for c in CatalogStore.orphanChecks {
                let sql = "SELECT DISTINCT \(c.column) FROM \(c.table) WHERE \(c.column) NOT IN (\(c.ref)) ORDER BY \(c.column)"
                var keys: [String] = []
                if let s = prepare(sql) {
                    while sqlite3_step(s) == SQLITE_ROW {
                        if let t = sqlite3_column_text(s, 0) { keys.append(String(cString: t)) }
                    }
                    sqlite3_finalize(s)
                }
                result[c.key] = keys
            }
            return result
        }
    }

    /// Löscht alle verwaisten Zeilen in einer Transaktion. Rückgabe: Kategorie → gelöschte Zeilen.
    @discardableResult
    func deleteOrphanRows() -> [String: Int] {
        queue.sync {
            var result: [String: Int] = [:]
            exec("BEGIN")
            for c in CatalogStore.orphanChecks {
                // db ist private im Haupttyp → Zeilen vorher zählen statt sqlite3_changes().
                let whereSQL = "WHERE \(c.column) NOT IN (\(c.ref))"
                var n = 0
                if let s = prepare("SELECT COUNT(*) FROM \(c.table) \(whereSQL)") {
                    if sqlite3_step(s) == SQLITE_ROW { n = Int(sqlite3_column_int64(s, 0)) }
                    sqlite3_finalize(s)
                }
                if n > 0 { exec("DELETE FROM \(c.table) \(whereSQL)") }
                result[c.key] = n
            }
            exec("COMMIT")
            return result
        }
    }
}
