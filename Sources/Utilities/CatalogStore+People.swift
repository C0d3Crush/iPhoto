import Foundation
import SQLite3
import CoreGraphics

// MARK: - Gesichtserkennung / People

extension CatalogStore {

    // Idempotente Migration: legt faces- und people-Tabellen an und ergänzt face_scanned-Spalte.
    // Wird von createSchema() einmalig beim App-Start aufgerufen.
    func migrateFaceColumns() {
        exec("ALTER TABLE images ADD COLUMN face_scanned INTEGER NOT NULL DEFAULT 0")
        exec("CREATE INDEX IF NOT EXISTS idx_images_face_scanned ON images(face_scanned)")

        exec("""
        CREATE TABLE IF NOT EXISTS faces (
            id          TEXT PRIMARY KEY,
            image_path  TEXT NOT NULL,
            bbox_x      REAL NOT NULL,
            bbox_y      REAL NOT NULL,
            bbox_w      REAL NOT NULL,
            bbox_h      REAL NOT NULL,
            confidence  REAL NOT NULL DEFAULT 0,
            cluster_id  TEXT,
            embedding   BLOB
        )
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_faces_image_path ON faces(image_path)")
        exec("CREATE INDEX IF NOT EXISTS idx_faces_cluster_id ON faces(cluster_id)")

        exec("""
        CREATE TABLE IF NOT EXISTS people (
            id            TEXT PRIMARY KEY,
            name          TEXT,
            cover_face_id TEXT
        )
        """)
    }

    // MARK: - Face CRUD

    func insertFaces(_ faces: [FaceRecord]) {
        guard !faces.isEmpty else { return }
        queue.sync {
            exec("BEGIN")
            let stmt = prepare("""
                INSERT OR REPLACE INTO faces (id, image_path, bbox_x, bbox_y, bbox_w, bbox_h, confidence, cluster_id, embedding)
                VALUES (?,?,?,?,?,?,?,?,?)
            """)
            for f in faces {
                sqlite3_reset(stmt)
                bind(stmt, 1, f.id)
                bind(stmt, 2, f.imagePath)
                sqlite3_bind_double(stmt, 3, Double(f.bbox.origin.x))
                sqlite3_bind_double(stmt, 4, Double(f.bbox.origin.y))
                sqlite3_bind_double(stmt, 5, Double(f.bbox.width))
                sqlite3_bind_double(stmt, 6, Double(f.bbox.height))
                sqlite3_bind_double(stmt, 7, Double(f.confidence))
                if let cid = f.clusterID { bind(stmt, 8, cid) } else { sqlite3_bind_null(stmt, 8) }
                if let emb = f.embeddingData {
                    emb.withUnsafeBytes { ptr in
                        sqlite3_bind_blob(stmt, 9, ptr.baseAddress, Int32(emb.count), sqliteTransient)
                    }
                } else {
                    sqlite3_bind_null(stmt, 9)
                }
                step(stmt)
            }
            sqlite3_finalize(stmt)
            exec("COMMIT")
        }
    }

    func markFaceScanned(path: String) {
        queue.sync {
            let stmt = prepare("UPDATE images SET face_scanned=1 WHERE path=?")
            bind(stmt, 1, path)
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    func pathsNeedingFaceScan() -> [String] {
        queue.sync {
            let stmt = prepare("SELECT path FROM images WHERE face_scanned=0 ORDER BY filename")
            var out: [String] = []
            while step(stmt) == SQLITE_ROW {
                out.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    func faces(forPath path: String) -> [FaceRecord] {
        queue.sync { loadFaces(where: "image_path=?", binding: { bind($0, 1, path) }) }
    }

    func allFaces() -> [FaceRecord] {
        queue.sync { loadFaces(where: nil, binding: { _ in () }) }
    }

    func updateFaceCluster(faceID: String, clusterID: String?) {
        queue.sync {
            let stmt = prepare("UPDATE faces SET cluster_id=? WHERE id=?")
            if let cid = clusterID { bind(stmt, 1, cid) } else { sqlite3_bind_null(stmt, 1) }
            bind(stmt, 2, faceID)
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    func deleteFaces(forPath path: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM faces WHERE image_path=?")
            bind(stmt, 1, path)
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    // MARK: - People CRUD

    func insertPerson(_ person: PersonRecord) {
        queue.sync {
            let stmt = prepare("INSERT OR REPLACE INTO people (id, name, cover_face_id) VALUES (?,?,?)")
            bind(stmt, 1, person.id)
            if let n = person.name { bind(stmt, 2, n) } else { sqlite3_bind_null(stmt, 2) }
            if let c = person.coverFaceID { bind(stmt, 3, c) } else { sqlite3_bind_null(stmt, 3) }
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    func updatePerson(_ person: PersonRecord) {
        insertPerson(person)
    }

    func deletePerson(id: String) {
        queue.sync {
            let stmt = prepare("UPDATE faces SET cluster_id=NULL WHERE cluster_id=?")
            bind(stmt, 1, id); step(stmt); sqlite3_finalize(stmt)
            let stmt2 = prepare("DELETE FROM people WHERE id=?")
            bind(stmt2, 1, id); step(stmt2); sqlite3_finalize(stmt2)
        }
    }

    func allPeople() -> [PersonRecord] {
        queue.sync {
            let stmt = prepare("SELECT id, name, cover_face_id FROM people ORDER BY name")
            var out: [PersonRecord] = []
            while step(stmt) == SQLITE_ROW {
                let id   = String(cString: sqlite3_column_text(stmt, 0))
                let name: String? = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 1))
                let cov: String?  = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 2))
                out.append(PersonRecord(id: id, name: name, coverFaceID: cov))
            }
            sqlite3_finalize(stmt); return out
        }
    }

    // MARK: - Helpers

    private func loadFaces(where condition: String?, binding: (OpaquePointer?) -> Void) -> [FaceRecord] {
        let sql = "SELECT id, image_path, bbox_x, bbox_y, bbox_w, bbox_h, confidence, cluster_id, embedding FROM faces"
            + (condition.map { " WHERE \($0)" } ?? "")
        let stmt = prepare(sql)
        binding(stmt)
        var out: [FaceRecord] = []
        while step(stmt) == SQLITE_ROW {
            let id        = String(cString: sqlite3_column_text(stmt, 0))
            let path      = String(cString: sqlite3_column_text(stmt, 1))
            let bx        = sqlite3_column_double(stmt, 2)
            let by        = sqlite3_column_double(stmt, 3)
            let bw        = sqlite3_column_double(stmt, 4)
            let bh        = sqlite3_column_double(stmt, 5)
            let conf      = Float(sqlite3_column_double(stmt, 6))
            let cid: String? = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 7))
            var emb: Data? = nil
            if sqlite3_column_type(stmt, 8) != SQLITE_NULL,
               let ptr = sqlite3_column_blob(stmt, 8) {
                let len = Int(sqlite3_column_bytes(stmt, 8))
                emb = Data(bytes: ptr, count: len)
            }
            let bbox = CGRect(x: bx, y: by, width: bw, height: bh)
            out.append(FaceRecord(id: id, imagePath: path, clusterID: cid, bbox: bbox, confidence: conf, embeddingData: emb))
        }
        sqlite3_finalize(stmt)
        return out
    }
}
