import Foundation
import SQLite3

// Automatische Backups des SQLite-Katalogs.
// Motivation: Der Katalog hält Ratings, Alben, Anpassungen und den EXIF-Cache — bei stiller
// Korruption wäre die gesamte Bearbeitungshistorie verloren. VACUUM INTO erzeugt eine saubere,
// in sich geschlossene Kopie und berücksichtigt WAL-Zustand korrekt.
extension CatalogStore {

    private static let backupsToKeep = 5
    private static let backupsDirName = "backups"

    /// Wird nach erfolgreichem open() (loadExifCache validiert Reads) aus dem Hintergrund aufgerufen.
    /// Läuft auf `queue`, damit VACUUM INTO nicht mit Writes kollidiert. Blockiert nie das UI.
    func scheduleStartupBackup() {
        queue.async { [weak self] in
            self?.performBackup()
            self?.pruneOldBackups()
        }
    }

    func exportTo(path: String) -> Bool {
        queue.sync {
            let escaped = path.replacingOccurrences(of: "'", with: "''")
            return exec("VACUUM INTO '\(escaped)'")
        }
    }

    /// Triggers an on-demand backup. Returns the backup file path on success, nil on failure.
    func backupNow() -> String? {
        guard let backupsDir = backupsDirectory() else { return nil }
        let stamp = timestampForFilename()
        let target = backupsDir.appendingPathComponent("catalog-\(stamp).db").path
        let escaped = target.replacingOccurrences(of: "'", with: "''")
        guard exec("VACUUM INTO '\(escaped)'") else { return nil }
        pruneOldBackups()
        return target
    }

    private func performBackup() {
        guard let backupsDir = backupsDirectory() else { return }
        let stamp = timestampForFilename()
        let target = backupsDir.appendingPathComponent("catalog-\(stamp).db").path
        // SQLite-String-Escape: einfache Anführungszeichen verdoppeln
        let escaped = target.replacingOccurrences(of: "'", with: "''")
        let sql = "VACUUM INTO '\(escaped)'"
        if exec(sql) {
            Log.debug("Katalog-Backup erstellt: \(target)")
        } else {
            Log.error("Katalog-Backup fehlgeschlagen (VACUUM INTO): \(target)")
        }
    }

    private func pruneOldBackups() {
        guard let dir = backupsDirectory() else { return }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: dir,
                                                       includingPropertiesForKeys: [.contentModificationDateKey],
                                                       options: [.skipsHiddenFiles]) else { return }
        let dbBackups = entries.filter { $0.pathExtension == "db" && $0.lastPathComponent.hasPrefix("catalog-") }
        // Neueste zuerst — mtime als Sortierschlüssel
        let sorted = dbBackups.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
        guard sorted.count > Self.backupsToKeep else { return }
        for stale in sorted[Self.backupsToKeep...] {
            do {
                try fm.removeItem(at: stale)
                Log.debug("Altes Katalog-Backup gelöscht: \(stale.lastPathComponent)")
            } catch {
                Log.error("Konnte altes Backup nicht löschen (\(stale.lastPathComponent)): \(error.localizedDescription)")
            }
        }
    }

    private func backupsDirectory() -> URL? {
        // Backups liegen neben catalog.db unter Application Support/iPhoto/backups/
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
            .appendingPathComponent(Self.backupsDirName)
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            return base
        } catch {
            Log.error("Backup-Verzeichnis konnte nicht erstellt werden: \(error.localizedDescription)")
            return nil
        }
    }

    private func timestampForFilename() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}
