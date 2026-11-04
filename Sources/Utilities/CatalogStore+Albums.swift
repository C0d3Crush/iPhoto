import Foundation
import SQLite3

// MARK: - Albums & Search

extension CatalogStore {

    func saveAlbum(id: String, name: String) {
        queue.sync {
            let stmt = prepare("""
                INSERT INTO albums (id,name,created_at) VALUES (?,?,?)
                ON CONFLICT(id) DO UPDATE SET name=excluded.name
            """)
            bind(stmt, 1, id); bind(stmt, 2, name); bind(stmt, 3, iso8601())
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    func deleteAlbum(id: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM albums WHERE id=?")
            bind(stmt, 1, id); step(stmt); sqlite3_finalize(stmt)
        }
    }

    func allAlbums() -> [(id: String, name: String)] {
        queue.sync {
            let stmt = prepare("SELECT id,name FROM albums ORDER BY name")
            var out: [(String, String)] = []
            while step(stmt) == SQLITE_ROW {
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
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    func removeImage(path: String, fromAlbum albumID: String) {
        queue.sync {
            let stmt = prepare("DELETE FROM album_images WHERE album_id=? AND image_path=?")
            bind(stmt, 1, albumID); bind(stmt, 2, path)
            step(stmt); sqlite3_finalize(stmt)
        }
    }

    func images(inAlbum albumID: String) -> [String] {
        queue.sync {
            let stmt = prepare("SELECT image_path FROM album_images WHERE album_id=? ORDER BY sort_order")
            bind(stmt, 1, albumID)
            var paths: [String] = []
            while step(stmt) == SQLITE_ROW {
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
            while step(stmt) == SQLITE_ROW { out.append(rowToImage(stmt)) }
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
            while step(stmt) == SQLITE_ROW { out.append(rowToImage(stmt)) }
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
            while step(stmt) == SQLITE_ROW { out.append(rowToImage(stmt)) }
            sqlite3_finalize(stmt); return out
        }
    }

    func images(withColorLabel color: String) -> [CatalogImage] {
        queue.sync {
            let stmt = prepare("""
                SELECT i.id,i.path,i.filename,i.size_bytes,i.width,i.height,
                       i.date_taken,i.camera_make,i.camera_model,i.is_raw,i.imported_at
                FROM images i JOIN ratings r ON i.path=r.image_path
                WHERE r.color_label=? ORDER BY i.filename
            """)
            bind(stmt, 1, color)
            var out: [CatalogImage] = []
            while step(stmt) == SQLITE_ROW { out.append(rowToImage(stmt)) }
            sqlite3_finalize(stmt); return out
        }
    }

    func vacuum() {
        queue.sync { exec("VACUUM") }
    }
}
