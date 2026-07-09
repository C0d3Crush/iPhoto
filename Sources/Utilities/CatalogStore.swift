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
    private let queue = DispatchQueue(label: "com.c0d3cru5h.iphoto.catalog", qos: .utility)
    private let dbPath: String

    // In-memory EXIF cache — avoids queue.sync SQLite reads from the main thread during
    // smartFolderMatches, which was causing 300+ serialised DB queries per SwiftUI re-render.
    private var exifCache: [String: (focalLength: Double?, iso: Int?, aperture: Double?, lensModel: String?, hdr: Bool, filmSimulation: String?)] = [:]
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
    }

    private func loadExifCache() {
        let stmt = prepare("SELECT path, focal_length, iso, aperture, lens_model, hdr, film_simulation FROM images WHERE exif_scanned=1")
        var rows: [(String, Double?, Int?, Double?, String?, Bool, String?)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let path = String(cString: sqlite3_column_text(stmt, 0))
            let fl: Double? = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 1)
            let iso: Int?   = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2))
            let ap: Double? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 3)
            let lens: String? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 4))
            let hdr: Bool = sqlite3_column_int(stmt, 5) != 0
            let filmSim: String? = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 6))
            rows.append((path, fl, iso, ap, lens, hdr, filmSim))
        }
        sqlite3_finalize(stmt)
        exifCacheLock.lock()
        for (path, fl, iso, ap, lens, hdr, filmSim) in rows {
            exifCache[path] = (focalLength: fl, iso: iso, aperture: ap, lensModel: lens, hdr: hdr, filmSimulation: filmSim)
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

        exec("""
        CREATE TABLE IF NOT EXISTS ratings (
            image_path  TEXT PRIMARY KEY,
            rating      INTEGER NOT NULL DEFAULT 0,
            flag        TEXT NOT NULL DEFAULT 'none',
            color_label TEXT NOT NULL DEFAULT 'none',
            updated_at  TEXT NOT NULL
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
    }

    // MARK: - Migration from JSON

    private func migrateFromJSON() {
        // Only runs once — albums table empty means fresh DB
        let stmt = prepare("SELECT COUNT(*) FROM albums")
        var count: Int32 = 0
        if sqlite3_step(stmt) == SQLITE_ROW { count = sqlite3_column_int(stmt, 0) }
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
            sqlite3_step(ins); sqlite3_finalize(ins)

            for (i, url) in album.photoURLs.enumerated() {
                let ins2 = prepare("INSERT OR IGNORE INTO album_images (album_id,image_path,sort_order) VALUES (?,?,?)")
                bind(ins2, 1, aid); bind(ins2, 2, url.path)
                sqlite3_bind_int(ins2, 3, Int32(i))
                sqlite3_step(ins2); sqlite3_finalize(ins2)
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
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    func image(forPath path: String) -> CatalogImage? {
        queue.sync {
            let stmt = prepare("SELECT id,path,filename,size_bytes,width,height,date_taken,camera_make,camera_model,is_raw,imported_at FROM images WHERE path=?")
            bind(stmt, 1, path)
            guard sqlite3_step(stmt) == SQLITE_ROW else { sqlite3_finalize(stmt); return nil }
            let img = rowToImage(stmt); sqlite3_finalize(stmt); return img
        }
    }

    func allImages() -> [CatalogImage] {
        queue.sync {
            let stmt = prepare("SELECT id,path,filename,size_bytes,width,height,date_taken,camera_make,camera_model,is_raw,imported_at FROM images ORDER BY filename")
            var out: [CatalogImage] = []
            while sqlite3_step(stmt) == SQLITE_ROW { out.append(rowToImage(stmt)) }
            sqlite3_finalize(stmt); return out
        }
    }

    func removeImage(path: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM images WHERE path=?")
            bind(stmt, 1, path); sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    func upsertExif(path: String, focalLength: Double?, iso: Int?, aperture: Double?, lensModel: String?, hdr: Bool = false, filmSimulation: String? = nil) {
        queue.sync {
            let stmt = prepare("""
                UPDATE images SET focal_length=?, iso=?, aperture=?, lens_model=?, exif_scanned=1, hdr=?, film_simulation=?
                WHERE path=?
            """)
            if let v = focalLength { sqlite3_bind_double(stmt, 1, v) } else { sqlite3_bind_null(stmt, 1) }
            if let v = iso { sqlite3_bind_int(stmt, 2, Int32(v)) } else { sqlite3_bind_null(stmt, 2) }
            if let v = aperture { sqlite3_bind_double(stmt, 3, v) } else { sqlite3_bind_null(stmt, 3) }
            bindOpt(stmt, 4, lensModel)
            sqlite3_bind_int(stmt, 5, hdr ? 1 : 0)
            bindOpt(stmt, 6, filmSimulation)
            bind(stmt, 7, path)
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
        exifCacheLock.lock()
        exifCache[path] = (focalLength: focalLength, iso: iso, aperture: aperture, lensModel: lensModel, hdr: hdr, filmSimulation: filmSimulation)
        exifCacheLock.unlock()
    }

    func exif(forPath path: String) -> (focalLength: Double?, iso: Int?, aperture: Double?, lensModel: String?, hdr: Bool, filmSimulation: String?)? {
        exifCacheLock.lock()
        let cached = exifCache[path]
        exifCacheLock.unlock()
        if let hit = cached { return hit }
        return queue.sync {
            let stmt = prepare("SELECT focal_length, iso, aperture, lens_model, hdr, film_simulation FROM images WHERE path=?")
            bind(stmt, 1, path)
            guard sqlite3_step(stmt) == SQLITE_ROW else { sqlite3_finalize(stmt); return nil }
            let fl: Double? = sqlite3_column_type(stmt, 0) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 0)
            let iso: Int?  = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 1))
            let ap: Double? = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 2)
            let lens: String? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 3))
            let hdr: Bool = sqlite3_column_int(stmt, 4) != 0
            let filmSim: String? = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 5))
            sqlite3_finalize(stmt)
            return (fl, iso, ap, lens, hdr, filmSim)
        }
    }

    func allFilmSimulations() -> [String] {
        queue.sync {
            let stmt = prepare("SELECT DISTINCT film_simulation FROM images WHERE film_simulation IS NOT NULL AND film_simulation != '' ORDER BY film_simulation")
            var out: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                out.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func pathsNeedingExifScan() -> [String] {
        queue.sync {
            let stmt = prepare("SELECT path FROM images WHERE exif_scanned=0 ORDER BY filename")
            var out: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
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
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            exec("COMMIT")
        }
    }

    // MARK: - Ratings

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
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    func rating(forPath path: String) -> (rating: Int, flag: String, colorLabel: String)? {
        queue.sync {
            let stmt = prepare("SELECT rating,flag,color_label FROM ratings WHERE image_path=?")
            bind(stmt, 1, path)
            guard sqlite3_step(stmt) == SQLITE_ROW else { sqlite3_finalize(stmt); return nil }
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
            while sqlite3_step(stmt) == SQLITE_ROW {
                out[String(cString: sqlite3_column_text(stmt, 0))] =
                    (Int(sqlite3_column_int(stmt, 1)),
                     String(cString: sqlite3_column_text(stmt, 2)),
                     String(cString: sqlite3_column_text(stmt, 3)))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func removeRating(path: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM ratings WHERE image_path=?")
            bind(stmt, 1, path); sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    // MARK: - Adjustments

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
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    func loadAdjustments(path: String) -> AdjustmentState? {
        queue.sync {
            let stmt = prepare("SELECT data FROM adjustments WHERE image_path=?")
            bind(stmt, 1, path)
            guard sqlite3_step(stmt) == SQLITE_ROW,
                  let ptr = sqlite3_column_text(stmt, 0) else {
                sqlite3_finalize(stmt); return nil
            }
            let json = String(cString: ptr)
            sqlite3_finalize(stmt)
            return (try? JSONDecoder().decode(AdjustmentState.self, from: Data(json.utf8)))
        }
    }

    func deleteAdjustments(path: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM adjustments WHERE image_path=?")
            bind(stmt, 1, path); sqlite3_step(stmt); sqlite3_finalize(stmt)
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
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    func allUserPresets() -> [Preset] {
        queue.sync {
            let stmt = prepare("SELECT data FROM presets ORDER BY created_at ASC")
            var out: [Preset] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
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
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    // MARK: - Albums

    func saveAlbum(id: String, name: String) {
        queue.sync {
            let stmt = prepare("""
                INSERT INTO albums (id,name,created_at) VALUES (?,?,?)
                ON CONFLICT(id) DO UPDATE SET name=excluded.name
            """)
            bind(stmt, 1, id); bind(stmt, 2, name); bind(stmt, 3, iso8601())
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    func deleteAlbum(id: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM albums WHERE id=?")
            bind(stmt, 1, id); sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    func allAlbums() -> [(id: String, name: String)] {
        queue.sync {
            let stmt = prepare("SELECT id,name FROM albums ORDER BY name")
            var out: [(String, String)] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                out.append((String(cString: sqlite3_column_text(stmt, 0)),
                             String(cString: sqlite3_column_text(stmt, 1))))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func addImage(path: String, toAlbum albumID: String, order: Int = 0) {
        queue.sync {
            let stmt = prepare("INSERT OR IGNORE INTO album_images (album_id,image_path,sort_order) VALUES (?,?,?)")
            bind(stmt, 1, albumID); bind(stmt, 2, path)
            sqlite3_bind_int(stmt, 3, Int32(order))
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    func removeImage(path: String, fromAlbum albumID: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM album_images WHERE album_id=? AND image_path=?")
            bind(stmt, 1, albumID); bind(stmt, 2, path)
            sqlite3_step(stmt); sqlite3_finalize(stmt)
        }
    }

    func images(inAlbum albumID: String) -> [String] {
        queue.sync {
            let stmt = prepare("SELECT image_path FROM album_images WHERE album_id=? ORDER BY sort_order")
            bind(stmt, 1, albumID)
            var paths: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                paths.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
            sqlite3_finalize(stmt); return paths
        }
    }

    // MARK: - Search

    func search(query: String) -> [CatalogImage] {
        queue.sync {
            let like = "%\(query)%"
            let stmt = prepare("""
                SELECT id,path,filename,size_bytes,width,height,date_taken,camera_make,camera_model,is_raw,imported_at
                FROM images WHERE filename LIKE ? OR camera_make LIKE ? OR camera_model LIKE ? OR date_taken LIKE ?
                ORDER BY filename
            """)
            bind(stmt, 1, like); bind(stmt, 2, like); bind(stmt, 3, like); bind(stmt, 4, like)
            var out: [CatalogImage] = []
            while sqlite3_step(stmt) == SQLITE_ROW { out.append(rowToImage(stmt)) }
            sqlite3_finalize(stmt); return out
        }
    }

    func images(flaggedAs flag: String) -> [CatalogImage] {
        queue.sync {
            let stmt = prepare("""
                SELECT i.id,i.path,i.filename,i.size_bytes,i.width,i.height,
                       i.date_taken,i.camera_make,i.camera_model,i.is_raw,i.imported_at
                FROM images i JOIN ratings r ON i.path=r.image_path
                WHERE r.flag=? ORDER BY i.filename
            """)
            bind(stmt, 1, flag)
            var out: [CatalogImage] = []
            while sqlite3_step(stmt) == SQLITE_ROW { out.append(rowToImage(stmt)) }
            sqlite3_finalize(stmt); return out
        }
    }

    func images(ratedAtLeast minRating: Int) -> [CatalogImage] {
        queue.sync {
            let stmt = prepare("""
                SELECT i.id,i.path,i.filename,i.size_bytes,i.width,i.height,
                       i.date_taken,i.camera_make,i.camera_model,i.is_raw,i.imported_at
                FROM images i JOIN ratings r ON i.path=r.image_path
                WHERE r.rating>=? ORDER BY r.rating DESC, i.filename
            """)
            sqlite3_bind_int(stmt, 1, Int32(minRating))
            var out: [CatalogImage] = []
            while sqlite3_step(stmt) == SQLITE_ROW { out.append(rowToImage(stmt)) }
            sqlite3_finalize(stmt); return out
        }
    }

    // MARK: - Helpers

    // SQLITE_TRANSIENT (-1) tells SQLite to copy the string immediately during bind,
    // so the Swift string can be released by ARC before sqlite3_step is called.
    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var s: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &s, nil)
        return s
    }

    private func bind(_ s: OpaquePointer?, _ i: Int32, _ v: String) {
        sqlite3_bind_text(s, i, v, -1, sqliteTransient)
    }

    private func bindOpt(_ s: OpaquePointer?, _ i: Int32, _ v: String?) {
        if let v = v { bind(s, i, v) } else { sqlite3_bind_null(s, i) }
    }

    private func iso8601() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: Date())
    }

    private func rowToImage(_ s: OpaquePointer?) -> CatalogImage {
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
}

// Used only for JSON migration
private struct AlbumJSON: Codable {
    let id: UUID
    var name: String
    var photoURLs: [URL]
}
