import Foundation
import SQLite3

// MARK: - Value Types

struct CatalogImage {
    let id: String
    let path: String
    let filename: String
    let sizeBytes: Int64
    let width: Int
    let height: Int
    let dateTaken: String?
    let cameraMake: String?
    let cameraModel: String?
    let isRAW: Bool
    let importedAt: String
}

// MARK: - CatalogStore

final class CatalogStore {
    static let shared = CatalogStore()

    private var db: OpaquePointer?
    // Serial queue serialises all DB access; WAL lets concurrent readers not block writers.
    let queue = DispatchQueue(label: "com.c0d3cru5h.iphoto.catalog", qos: .utility)
    private let dbPath: String

    // In-memory EXIF cache — avoids queue.sync SQLite reads from the main thread during
    // smartFolderMatches, which was causing 300+ serialised DB queries per SwiftUI re-render.
    private var exifCache: [String: (focalLength: Double?, iso: Int?, aperture: Double?, lensModel: String?, hdr: Bool, filmSimulation: String?, sequenceNumber: Int?, autoBracketing: Bool)] = [:]
    // Auch Fehlschläge cachen: Bilder, die (noch) nicht im Katalog sind, lösten sonst
    // bei jeder visibleDocuments-Neuberechnung einen queue.sync-SQLite-SELECT pro Bild aus.
    private var exifCacheMisses = Set<String>()
    private let exifCacheLock = NSLock()

    // JSON-Legacy-Migration nur für den Standard-Katalog — injizierte Pfade (Tests)
    // dürfen nicht die echten albums.json des Nutzers importieren.
    private let isDefaultCatalog: Bool

    init(dbPath: String? = nil) {
        if let p = dbPath {
            self.dbPath = p
            self.isDefaultCatalog = false
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("iPhoto")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.dbPath = dir.appendingPathComponent("catalog.db").path
            self.isDefaultCatalog = true
        }
        queue.sync { self.open() }
        // Nach erfolgreichem open() den Katalog sichern — schützt vor stiller Korruption.
        // Testpfade (dbPath != nil) ausnehmen, damit Testläufe nicht die echten Backups überschreiben.
        if isDefaultCatalog { scheduleStartupBackup() }
    }

    deinit { sqlite3_close(db) }

    // MARK: - Setup

    private func open() {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { return }
        exec("PRAGMA journal_mode=WAL")
        exec("PRAGMA foreign_keys=ON")
        createSchema()
        if isDefaultCatalog { migrateFromJSON() }
        loadExifCache()
        loadMotifCache()
    }

    private func loadExifCache() {
        let stmt = prepare("SELECT path, focal_length, iso, aperture, lens_model, hdr, film_simulation, sequence_number, auto_bracket FROM images WHERE exif_scanned=1")
        var rows: [(String, Double?, Int?, Double?, String?, Bool, String?, Int?, Bool)] = []
        while step(stmt) == SQLITE_ROW {
            let path = String(cString: sqlite3_column_text(stmt, 0))
            let fl: Double? = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 1)
            let iso: Int?   = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2))
            let ap: Double? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 3)
            let lens: String? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 4))
            let hdr: Bool = sqlite3_column_int(stmt, 5) != 0
            let filmSim: String? = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 6))
            let seq: Int? = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 7))
            let bkt: Bool = sqlite3_column_int(stmt, 8) != 0
            rows.append((path, fl, iso, ap, lens, hdr, filmSim, seq, bkt))
        }
        sqlite3_finalize(stmt)
        exifCacheLock.lock()
        for (path, fl, iso, ap, lens, hdr, filmSim, seq, bkt) in rows {
            exifCache[path] = (focalLength: fl, iso: iso, aperture: ap, lensModel: lens, hdr: hdr, filmSimulation: filmSim, sequenceNumber: seq, autoBracketing: bkt)
        }
        exifCacheLock.unlock()
    }

    private func createSchema() {
        exec("""
        CREATE TABLE IF NOT EXISTS images (
            id           TEXT PRIMARY KEY,
            path         TEXT NOT NULL UNIQUE,
            filename     TEXT NOT NULL,
            size_bytes   INTEGER,
            width        INTEGER,
            height       INTEGER,
            date_taken   TEXT,
            camera_make  TEXT,
            camera_model TEXT,
            is_raw       INTEGER NOT NULL DEFAULT 0,
            imported_at  TEXT NOT NULL
        )
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_images_path     ON images(path)")
        exec("CREATE INDEX IF NOT EXISTS idx_images_filename ON images(filename)")
        migrateExifColumns()
        migrateQualityColumns()
        migrateMotifColumns()
        migrateFaceColumns()

        exec("""
        CREATE TABLE IF NOT EXISTS ratings (
            image_path  TEXT PRIMARY KEY,
            rating      INTEGER NOT NULL DEFAULT 0,
            flag        TEXT NOT NULL DEFAULT 'none',
            color_label TEXT NOT NULL DEFAULT 'none',
            updated_at  TEXT NOT NULL
        )
        """)
        migrateEloColumns()

        exec("""
        CREATE TABLE IF NOT EXISTS trash (
            image_path TEXT PRIMARY KEY,
            trashed_at TEXT NOT NULL
        )
        """)

        exec("""
        CREATE TABLE IF NOT EXISTS albums (
            id         TEXT PRIMARY KEY,
            name       TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        """)

        exec("""
        CREATE TABLE IF NOT EXISTS album_images (
            album_id   TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
            image_path TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (album_id, image_path)
        )
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_album_images_id ON album_images(album_id)")

        exec("""
        CREATE TABLE IF NOT EXISTS adjustments (
            image_path TEXT PRIMARY KEY,
            data       TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """)

        exec("""
        CREATE TABLE IF NOT EXISTS presets (
            id         TEXT PRIMARY KEY,
            name       TEXT NOT NULL,
            author     TEXT,
            data       TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        """)
    }

    // v1.19.0: ELO-Rating aus Bildvergleich. Getrennt von rating (Sternen) — Sterne
    // sind manuelle Nutzerbewertung, ELO ist paarweise ausgeduellter Ranking-Score.
    // Alle bestehenden Zeilen bekommen den Standard-Baseline 1500 / 0 Matches.
    private func migrateEloColumns() {
        exec("ALTER TABLE ratings ADD COLUMN elo REAL NOT NULL DEFAULT 1500")
        exec("ALTER TABLE ratings ADD COLUMN elo_matches INTEGER NOT NULL DEFAULT 0")
        exec("CREATE INDEX IF NOT EXISTS idx_ratings_elo ON ratings(elo)")
    }

    private func migrateExifColumns() {
        let cols = ["focal_length REAL", "iso INTEGER", "aperture REAL", "lens_model TEXT", "exif_scanned INTEGER NOT NULL DEFAULT 0"]
        for col in cols {
            exec("ALTER TABLE images ADD COLUMN \(col)")
        }
        // hdr added in 0.63.0 — reset exif_scanned to trigger rescan so existing photos get HDR detection
        if exec("ALTER TABLE images ADD COLUMN hdr INTEGER NOT NULL DEFAULT 0") {
            exec("UPDATE images SET exif_scanned=0")
        }
        exec("CREATE INDEX IF NOT EXISTS idx_images_exif_scanned ON images(exif_scanned)")
        // 0.64.x: Fujifilm MakerNote parser fixed — reset RAF files once so they get re-scanned
        let hdrParserVersion = UserDefaults.standard.integer(forKey: "hdrParserVersion")
        if hdrParserVersion < 2 {
            exec("UPDATE images SET exif_scanned=0 WHERE lower(path) LIKE '%.raf'")
            UserDefaults.standard.set(2, forKey: "hdrParserVersion")
        }
        // film_simulation added — reset Fuji files to trigger rescan
        if exec("ALTER TABLE images ADD COLUMN film_simulation TEXT") {
            exec("UPDATE images SET exif_scanned=0 WHERE lower(path) LIKE '%.raf' OR lower(path) LIKE '%.jpg' OR lower(path) LIKE '%.jpeg'")
        }
        // 0.79.3: Brute-force "FUJIFILM"-Signatursuche — alle Fuji-Dateien neu scannen
        // 0.80.0: tag 0x1003 (B&W/Acros) + neue Codes 0x0120/0x0501 — Fuji-Dateien neu scannen
        let filmSimParserVersion = UserDefaults.standard.integer(forKey: "filmSimParserVersion")
        if filmSimParserVersion < 4 {
            exec("UPDATE images SET exif_scanned=0 WHERE lower(path) LIKE '%.raf' OR lower(path) LIKE '%.jpg' OR lower(path) LIKE '%.jpeg'")
            UserDefaults.standard.set(4, forKey: "filmSimParserVersion")
        }
        // 0.85.0: Serienbild-/Bracketing-Tags (0x1100/0x1101) — Fuji-Dateien neu scannen
        exec("ALTER TABLE images ADD COLUMN sequence_number INTEGER")
        exec("ALTER TABLE images ADD COLUMN auto_bracket INTEGER NOT NULL DEFAULT 0")
        let burstParserVersion = UserDefaults.standard.integer(forKey: "burstParserVersion")
        if burstParserVersion < 1 {
            exec("UPDATE images SET exif_scanned=0 WHERE lower(path) LIKE '%.raf' OR lower(path) LIKE '%.jpg' OR lower(path) LIKE '%.jpeg'")
            UserDefaults.standard.set(1, forKey: "burstParserVersion")
        }
    }

    // v1.7.0: Qualitätsflags (Blur/Belichtung) + Overrides persistieren.
    // blur_override/under_override/over_override: 0=nichts, 1=Nutzer sagt "doch ok" (Bild aus der Kategorie ausschließen).
    // phash: 64-Bit perceptual hash für Similarity-Grouping.
    // v1.9.0: duplicate_group_id / similar_group_id persistieren Gruppen-Membership —
    // spart Re-Berechnung beim App-Start (vor allem Similarity mit Union-Find über
    // hunderte pHashes).
    private func migrateQualityColumns() {
        let cols = [
            "blur_score REAL",
            "under_ratio REAL",
            "over_ratio REAL",
            "phash INTEGER",
            // v1.9.2: zweiter Hash (vertikale Gradienten) für Similarity-Grouping.
            // Alte Records ohne phash_v werden über die UPDATE unten für Rescan markiert.
            "phash_v INTEGER",
            "blur_override INTEGER NOT NULL DEFAULT 0",
            "under_override INTEGER NOT NULL DEFAULT 0",
            "over_override INTEGER NOT NULL DEFAULT 0",
            "quality_scanned INTEGER NOT NULL DEFAULT 0",
            "duplicate_group_id INTEGER",
            "similar_group_id INTEGER"
        ]
        for col in cols {
            exec("ALTER TABLE images ADD COLUMN \(col)")
        }
        exec("CREATE INDEX IF NOT EXISTS idx_images_quality_scanned ON images(quality_scanned)")
        exec("CREATE INDEX IF NOT EXISTS idx_images_duplicate_group ON images(duplicate_group_id)")
        exec("CREATE INDEX IF NOT EXISTS idx_images_similar_group   ON images(similar_group_id)")
        // Records aus früheren Versionen ohne phash_v: Rescan markieren, damit der
        // Similarity-Grouper mit beiden Hashes arbeiten kann. Idempotent — no-op
        // sobald alle Bilder den zweiten Hash haben.
        exec("UPDATE images SET quality_scanned=0 WHERE quality_scanned=1 AND phash_v IS NULL")
        // v1.17.0: Closed-Eye-Detektion. NULL = kein Gesicht erkannt, sonst kleinste
        // Eye-Aspect-Ratio aller Augen im Bild. Rescan-Trigger einmalig, damit bereits
        // gescannte Bilder das neue Signal bekommen.
        let hasEyeCol = exec("ALTER TABLE images ADD COLUMN eye_openness REAL")
        exec("ALTER TABLE images ADD COLUMN eyes_closed_override INTEGER NOT NULL DEFAULT 0")
        if hasEyeCol {
            exec("UPDATE images SET quality_scanned=0")
        }
    }

    // MARK: - Migration from JSON

    private func migrateFromJSON() {
        // Only runs once — albums table empty means fresh DB
        let stmt = prepare("SELECT COUNT(*) FROM albums")
        var count: Int32 = 0
        if step(stmt) == SQLITE_ROW { count = sqlite3_column_int(stmt, 0) }
        sqlite3_finalize(stmt)
        guard count == 0 else { return }

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        let albumsFile = dir.appendingPathComponent("albums.json")
        guard let data = try? Data(contentsOf: albumsFile),
              let albums = try? JSONDecoder().decode([AlbumJSON].self, from: data),
              !albums.isEmpty else { return }

        exec("BEGIN")
        for album in albums {
            let aid = album.id.uuidString
            let ins = prepare("INSERT OR IGNORE INTO albums (id,name,created_at) VALUES (?,?,?)")
            bind(ins, 1, aid); bind(ins, 2, album.name); bind(ins, 3, iso8601())
            step(ins); sqlite3_finalize(ins)

            for (i, url) in album.photoURLs.enumerated() {
                let ins2 = prepare("INSERT OR IGNORE INTO album_images (album_id,image_path,sort_order) VALUES (?,?,?)")
                bind(ins2, 1, aid); bind(ins2, 2, url.path)
                sqlite3_bind_int(ins2, 3, Int32(i))
                step(ins2); sqlite3_finalize(ins2)
            }
        }
        exec("COMMIT")
    }

    // MARK: - Images

    func upsertImage(path: String, filename: String, isRAW: Bool,
                     width: Int = 0, height: Int = 0, sizeBytes: Int64 = 0,
                     dateTaken: String? = nil, cameraMake: String? = nil, cameraModel: String? = nil) {
        queue.sync {
            let stmt = prepare("""
                INSERT INTO images (id,path,filename,size_bytes,width,height,date_taken,camera_make,camera_model,is_raw,imported_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(path) DO UPDATE SET
                    filename=excluded.filename, size_bytes=excluded.size_bytes,
                    width=excluded.width, height=excluded.height,
                    date_taken=excluded.date_taken, camera_make=excluded.camera_make,
                    camera_model=excluded.camera_model, is_raw=excluded.is_raw
            """)
            bind(stmt, 1, UUID().uuidString)
            bind(stmt, 2, path)
            bind(stmt, 3, filename)
            sqlite3_bind_int64(stmt, 4, sizeBytes)
            sqlite3_bind_int(stmt, 5, Int32(width))
            sqlite3_bind_int(stmt, 6, Int32(height))
            bindOpt(stmt, 7, dateTaken)
            bindOpt(stmt, 8, cameraMake)
            bindOpt(stmt, 9, cameraModel)
            sqlite3_bind_int(stmt, 10, isRAW ? 1 : 0)
            bind(stmt, 11, iso8601())
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    func image(forPath path: String) -> CatalogImage? {
        queue.sync {
            let stmt = prepare("SELECT id,path,filename,size_bytes,width,height,date_taken,camera_make,camera_model,is_raw,imported_at FROM images WHERE path=?")
            bind(stmt, 1, path)
            guard step(stmt) == SQLITE_ROW else { sqlite3_finalize(stmt); return nil }
            let img = rowToImage(stmt); sqlite3_finalize(stmt); return img
        }
    }

    func allImages() -> [CatalogImage] {
        queue.sync {
            let stmt = prepare("SELECT id,path,filename,size_bytes,width,height,date_taken,camera_make,camera_model,is_raw,imported_at FROM images ORDER BY filename")
            var out: [CatalogImage] = []
            while step(stmt) == SQLITE_ROW { out.append(rowToImage(stmt)) }
            sqlite3_finalize(stmt); return out
        }
    }

    func allImagesWithSeqNumbers() -> [(path: String, filename: String, seq: Int)] {
        queue.sync {
            let stmt = prepare("""
                SELECT path, filename, sequence_number FROM images
                WHERE sequence_number IS NOT NULL AND sequence_number > 0
                ORDER BY filename
            """)
            var out: [(path: String, filename: String, seq: Int)] = []
            while step(stmt) == SQLITE_ROW {
                let p = String(cString: sqlite3_column_text(stmt, 0))
                let f = String(cString: sqlite3_column_text(stmt, 1))
                let s = Int(sqlite3_column_int(stmt, 2))
                out.append((path: p, filename: f, seq: s))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func removeImage(path: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM images WHERE path=?")
            bind(stmt, 1, path); step(stmt); sqlite3_finalize(stmt)
        }
    }

    func upsertExif(path: String, focalLength: Double?, iso: Int?, aperture: Double?, lensModel: String?, hdr: Bool = false, filmSimulation: String? = nil, sequenceNumber: Int? = nil, autoBracketing: Bool = false) {
        queue.sync {
            let stmt = prepare("""
                UPDATE images SET focal_length=?, iso=?, aperture=?, lens_model=?, exif_scanned=1, hdr=?, film_simulation=?, sequence_number=?, auto_bracket=?
                WHERE path=?
            """)
            if let v = focalLength { sqlite3_bind_double(stmt, 1, v) } else { sqlite3_bind_null(stmt, 1) }
            if let v = iso { sqlite3_bind_int(stmt, 2, Int32(v)) } else { sqlite3_bind_null(stmt, 2) }
            if let v = aperture { sqlite3_bind_double(stmt, 3, v) } else { sqlite3_bind_null(stmt, 3) }
            bindOpt(stmt, 4, lensModel)
            sqlite3_bind_int(stmt, 5, hdr ? 1 : 0)
            bindOpt(stmt, 6, filmSimulation)
            if let v = sequenceNumber { sqlite3_bind_int(stmt, 7, Int32(v)) } else { sqlite3_bind_null(stmt, 7) }
            sqlite3_bind_int(stmt, 8, autoBracketing ? 1 : 0)
            bind(stmt, 9, path)
            step(stmt); sqlite3_finalize(stmt)
        }
        exifCacheLock.lock()
        exifCache[path] = (focalLength: focalLength, iso: iso, aperture: aperture, lensModel: lensModel, hdr: hdr, filmSimulation: filmSimulation, sequenceNumber: sequenceNumber, autoBracketing: autoBracketing)
        exifCacheMisses.remove(path)
        exifCacheLock.unlock()
    }

    // Invalidiert den in-memory EXIF-Cache für einen Pfad. Aufrufer nach jedem
    // externen EXIF-Write (MetadataService.writePhotoMetadata), damit der nächste
    // exif(forPath:) frisch aus DB liest statt einen stale Cache-Wert zu liefern.
    // Zusätzlich Pfad für Rescan markieren, damit scanExifForLibrary die Datei
    // beim nächsten Lauf neu einliest und die DB-Werte synct.
    func invalidateExifCache(path: String) {
        exifCacheLock.lock()
        exifCache.removeValue(forKey: path)
        exifCacheMisses.remove(path)
        exifCacheLock.unlock()
        queue.async { [weak self] in
            guard let self = self else { return }
            let stmt = self.prepare("UPDATE images SET exif_scanned=0 WHERE path=?")
            self.bind(stmt, 1, path); self.step(stmt); sqlite3_finalize(stmt)
        }
    }

    func exif(forPath path: String) -> (focalLength: Double?, iso: Int?, aperture: Double?, lensModel: String?, hdr: Bool, filmSimulation: String?, sequenceNumber: Int?, autoBracketing: Bool)? {
        exifCacheLock.lock()
        let cached = exifCache[path]
        let knownMiss = exifCacheMisses.contains(path)
        exifCacheLock.unlock()
        if let hit = cached { return hit }
        if knownMiss { return nil }
        return queue.sync {
            let stmt = prepare("SELECT focal_length, iso, aperture, lens_model, hdr, film_simulation, sequence_number, auto_bracket FROM images WHERE path=?")
            bind(stmt, 1, path)
            guard step(stmt) == SQLITE_ROW else {
                sqlite3_finalize(stmt)
                exifCacheLock.lock()
                exifCacheMisses.insert(path)
                exifCacheLock.unlock()
                return nil
            }
            let fl: Double? = sqlite3_column_type(stmt, 0) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 0)
            let iso: Int?  = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 1))
            let ap: Double? = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 2)
            let lens: String? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 3))
            let hdr: Bool = sqlite3_column_int(stmt, 4) != 0
            let filmSim: String? = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 5))
            let seq: Int? = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 6))
            let bkt: Bool = sqlite3_column_int(stmt, 7) != 0
            sqlite3_finalize(stmt)
            let row = (focalLength: fl, iso: iso, aperture: ap, lensModel: lens, hdr: hdr, filmSimulation: filmSim, sequenceNumber: seq, autoBracketing: bkt)
            exifCacheLock.lock()
            exifCache[path] = row
            exifCacheLock.unlock()
            return row
        }
    }

    func allFilmSimulations() -> [String] {
        queue.sync {
            let stmt = prepare("SELECT DISTINCT film_simulation FROM images WHERE film_simulation IS NOT NULL AND film_simulation != '' ORDER BY film_simulation")
            var out: [String] = []
            while step(stmt) == SQLITE_ROW {
                out.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func pathsNeedingExifScan() -> [String] {
        queue.sync {
            let stmt = prepare("SELECT path FROM images WHERE exif_scanned=0 ORDER BY filename")
            var out: [String] = []
            while step(stmt) == SQLITE_ROW {
                out.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    // Bulk-insert inside a single transaction — several orders of magnitude faster than N individual calls.
    func batchUpsertImages(_ items: [(path: String, filename: String, isRAW: Bool,
                                      width: Int, height: Int, sizeBytes: Int64,
                                      dateTaken: String?, cameraMake: String?, cameraModel: String?)]) {
        queue.sync {
            exec("BEGIN")
            let stmt = prepare("""
                INSERT INTO images (id,path,filename,size_bytes,width,height,date_taken,camera_make,camera_model,is_raw,imported_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(path) DO UPDATE SET
                    filename=excluded.filename, size_bytes=excluded.size_bytes,
                    width=excluded.width, height=excluded.height,
                    date_taken=excluded.date_taken, camera_make=excluded.camera_make,
                    camera_model=excluded.camera_model, is_raw=excluded.is_raw
            """)
            let now = iso8601()
            for item in items {
                sqlite3_reset(stmt)
                bind(stmt, 1, UUID().uuidString)
                bind(stmt, 2, item.path)
                bind(stmt, 3, item.filename)
                sqlite3_bind_int64(stmt, 4, item.sizeBytes)
                sqlite3_bind_int(stmt, 5, Int32(item.width))
                sqlite3_bind_int(stmt, 6, Int32(item.height))
                bindOpt(stmt, 7, item.dateTaken)
                bindOpt(stmt, 8, item.cameraMake)
                bindOpt(stmt, 9, item.cameraModel)
                sqlite3_bind_int(stmt, 10, item.isRAW ? 1 : 0)
                bind(stmt, 11, now)
                step(stmt)
            }
            sqlite3_finalize(stmt)
            exec("COMMIT")
        }
    }


    // MARK: - Helpers

    // SQLITE_TRANSIENT (-1) tells SQLite to copy the string immediately during bind,
    // so the Swift string can be released by ARC before sqlite3_step is called.
    let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    @discardableResult
    func exec(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    func prepare(_ sql: String) -> OpaquePointer? {
        var s: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &s, nil) != SQLITE_OK {
            Log.error("SQLite prepare fehlgeschlagen: \(String(cString: sqlite3_errmsg(db))) — SQL: \(sql.prefix(80))")
        }
        return s
    }

    // Ersetzt rohes sqlite3_step: SQLITE_ERROR/SQLITE_CORRUPT etc. werden geloggt statt still ignoriert.
    @discardableResult
    func step(_ s: OpaquePointer?) -> Int32 {
        let rc = sqlite3_step(s)
        if rc != SQLITE_ROW && rc != SQLITE_DONE {
            Log.error("SQLite step fehlgeschlagen (rc=\(rc)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return rc
    }

    func bind(_ s: OpaquePointer?, _ i: Int32, _ v: String) {
        sqlite3_bind_text(s, i, v, -1, sqliteTransient)
    }

    func bindOpt(_ s: OpaquePointer?, _ i: Int32, _ v: String?) {
        if let v = v { bind(s, i, v) } else { sqlite3_bind_null(s, i) }
    }

    func iso8601() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: Date())
    }

    func rowToImage(_ s: OpaquePointer?) -> CatalogImage {
        func str(_ i: Int32) -> String { String(cString: sqlite3_column_text(s, i)) }
        func opt(_ i: Int32) -> String? {
            sqlite3_column_type(s, i) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(s, i))
        }
        return CatalogImage(
            id: str(0), path: str(1), filename: str(2),
            sizeBytes: sqlite3_column_int64(s, 3),
            width: Int(sqlite3_column_int(s, 4)), height: Int(sqlite3_column_int(s, 5)),
            dateTaken: opt(6), cameraMake: opt(7), cameraModel: opt(8),
            isRAW: sqlite3_column_int(s, 9) != 0,
            importedAt: str(10)
        )
    }

    // MARK: - SmartFolder SQL queries

    /// Executes the SmartFolder SQL and returns matching paths in ORDER BY order.
    /// Returns nil when the SmartFolder contains runtime-only criteria (colorRatio, smartFolderRef)
    /// that cannot be expressed in SQL — caller should fall back to in-memory filtering.
    func orderedPathsForSmartFolder(_ sf: SmartFolder) -> [String]? {
        guard !SmartFolderSQLGenerator.hasRuntimeOnlyCriteria(sf) else { return nil }
        let sql = SmartFolderSQLGenerator.generate(for: sf)
        return queue.sync {
            guard let stmt = prepare(sql) else { return [] }
            var paths: [String] = []
            while step(stmt) == SQLITE_ROW {
                if let cstr = sqlite3_column_text(stmt, 0) {
                    paths.append(String(cString: cstr))
                }
            }
            sqlite3_finalize(stmt)
            return paths
        }
    }

    /// COUNT(*) query for sidebar badge — no LIMIT/ORDER BY, returns nil on runtime-only criteria.
    func countForSmartFolder(_ sf: SmartFolder) -> Int? {
        guard !SmartFolderSQLGenerator.hasRuntimeOnlyCriteria(sf) else { return nil }
        let sql = SmartFolderSQLGenerator.generateCount(for: sf)
        return queue.sync {
            guard let stmt = prepare(sql) else { return nil }
            defer { sqlite3_finalize(stmt) }
            return step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : nil
        }
    }
}

// Used only for JSON migration
private struct AlbumJSON: Codable {
    let id: UUID
    var name: String
    var photoURLs: [URL]
}
