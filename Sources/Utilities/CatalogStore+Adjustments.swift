import Foundation
import SQLite3

// MARK: - Adjustments & Presets

extension CatalogStore {

    func saveAdjustments(path: String, adjustments: AdjustmentState) {
        guard let data = try? JSONEncoder().encode(adjustments),
              let json = String(data: data, encoding: .utf8) else { return }
        queue.sync {
            let stmt = self.prepare("""
                INSERT INTO adjustments (image_path, data, updated_at) VALUES (?,?,?)
                ON CONFLICT(image_path) DO UPDATE SET data=excluded.data, updated_at=excluded.updated_at
            """)
            self.bind(stmt, 1, path)
            self.bind(stmt, 2, json)
            self.bind(stmt, 3, self.iso8601())
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    /// Schreibt viele Anpassungen in einer einzigen Transaktion (ein prepare, N steps) —
    /// für Batch-Sync (CLI `adjustments copy`) statt N einzelner Commits.
    func saveAdjustments(_ entries: [(path: String, adjustments: AdjustmentState)]) {
        guard !entries.isEmpty else { return }
        let encoder = JSONEncoder()
        let encoded: [(String, String)] = entries.compactMap { e -> (String, String)? in
            guard let data = try? encoder.encode(e.adjustments),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            return (e.path, json)
        }
        queue.sync {
            exec("BEGIN")
            let stmt = prepare("""
                INSERT INTO adjustments (image_path, data, updated_at) VALUES (?,?,?)
                ON CONFLICT(image_path) DO UPDATE SET data=excluded.data, updated_at=excluded.updated_at
            """)
            let now = iso8601()
            for (path, json) in encoded {
                sqlite3_reset(stmt)
                bind(stmt, 1, path); bind(stmt, 2, json); bind(stmt, 3, now)
                step(stmt)
            }
            sqlite3_finalize(stmt)
            exec("COMMIT")
        }
    }

    func loadAdjustments(path: String) -> AdjustmentState? {
        queue.sync {
            let stmt = prepare("SELECT data FROM adjustments WHERE image_path=?")
            bind(stmt, 1, path)
            guard step(stmt) == SQLITE_ROW,
                  let ptr = sqlite3_column_text(stmt, 0) else {
                sqlite3_finalize(stmt); return nil
            }
            let json = String(cString: ptr)
            sqlite3_finalize(stmt)
            return (try? JSONDecoder().decode(AdjustmentState.self, from: Data(json.utf8)))
        }
    }

    /// Alle Pfade, für die Anpassungen gespeichert sind — für die Batch-Initialisierung
    /// des `hasPersistedAdjustments`-Flags beim Startup. Eine SQLite-Abfrage statt N.
    func allModifiedPaths() -> Set<String> {
        queue.sync {
            let stmt = prepare("SELECT image_path FROM adjustments")
            var out = Set<String>()
            while step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 0) { out.insert(String(cString: ptr)) }
            }
            sqlite3_finalize(stmt)
            return out
        }
    }

    func deleteAdjustments(path: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM adjustments WHERE image_path=?")
            bind(stmt, 1, path); step(stmt); sqlite3_finalize(stmt)
        }
    }

    // MARK: - Presets

    func savePreset(_ preset: Preset) {
        guard let data = try? JSONEncoder().encode(preset),
              let json = String(data: data, encoding: .utf8) else { return }
        queue.sync {
            let stmt = prepare("""
                INSERT INTO presets (id, name, author, data, created_at) VALUES (?,?,?,?,?)
                ON CONFLICT(id) DO UPDATE SET name=excluded.name, author=excluded.author, data=excluded.data
            """)
            bind(stmt, 1, preset.id.uuidString)
            bind(stmt, 2, preset.name)
            bindOpt(stmt, 3, preset.author)
            bind(stmt, 4, json)
            bind(stmt, 5, iso8601())
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    func allUserPresets() -> [Preset] {
        queue.sync {
            let stmt = prepare("SELECT data FROM presets ORDER BY created_at ASC")
            var out: [Preset] = []
            while step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 0) {
                    let json = String(cString: ptr)
                    if let p = try? JSONDecoder().decode(Preset.self, from: Data(json.utf8)) {
                        out.append(p)
                    }
                }
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func deletePreset(id: UUID) {
        queue.sync {
            let stmt = prepare("DELETE FROM presets WHERE id=?")
            bind(stmt, 1, id.uuidString)
            step(stmt); sqlite3_finalize(stmt)
        }
    }
}
