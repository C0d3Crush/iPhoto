import Foundation
import SQLite3

// ── Minimale Inline-Kopie von CatalogStore für den Test-Build ────────────────
// (identische Implementierung — wird zusammen mit CatalogStore.swift kompiliert)

// MARK: - Test-Harness

var passed = 0
var failed = 0

func test(_ name: String, _ block: () throws -> Void) {
    do {
        try block()
        print("  PASS  \(name)")
        passed += 1
    } catch {
        print("  FAIL  \(name)  — \(error)")
        failed += 1
    }
}

struct Fail: Error { let msg: String }
func assert(_ cond: Bool, _ msg: String = "Bedingung nicht erfüllt") throws {
    if !cond { throw Fail(msg: msg) }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") throws {
    if a != b { throw Fail(msg: "\(a) != \(b)  \(msg)") }
}

// MARK: - Hilfsfunktionen

func freshStore(name: String = "test") -> CatalogStore {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("iphoto_catalog_test_\(name)_\(Int(Date().timeIntervalSince1970))")
    return CatalogStore(dbPath: tmp.path)
}

// MARK: - Tests

print("")
print("iPhoto CatalogStore-Tests")
print(String(repeating: "=", count: 55))

// ── 1. Schema-Init ────────────────────────────────────────────
print("\n[1  Schema-Init]")
test("DB-Datei wird angelegt") {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("catalog_schema_\(Int(Date().timeIntervalSince1970)).db")
    _ = CatalogStore(dbPath: tmp.path)
    try assert(FileManager.default.fileExists(atPath: tmp.path), "DB-Datei fehlt")
}

test("Alle 4 Tabellen vorhanden") {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("catalog_tables_\(Int(Date().timeIntervalSince1970)).db")
    _ = CatalogStore(dbPath: tmp.path)
    var db: OpaquePointer?
    sqlite3_open(tmp.path, &db)
    defer { sqlite3_close(db) }
    let tables = ["images", "ratings", "albums", "album_images"]
    for t in tables {
        var s: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name='\(t)'"
        sqlite3_prepare_v2(db, sql, -1, &s, nil)
        let found = sqlite3_step(s) == SQLITE_ROW
        sqlite3_finalize(s)
        try assert(found, "Tabelle '\(t)' fehlt")
    }
}

// ── 2. Upsert Image ───────────────────────────────────────────
print("\n[2  Upsert Image]")
test("Bild einfügen und abrufen") {
    let s = freshStore(name: "upsert")
    s.upsertImage(path: "/tmp/foto.jpg", filename: "foto.jpg", isRAW: false,
                  width: 4000, height: 3000, sizeBytes: 2_000_000,
                  dateTaken: "2024:06:01 12:00:00", cameraMake: "Canon", cameraModel: "EOS R5")
    let img = s.image(forPath: "/tmp/foto.jpg")
    try assert(img != nil, "Bild nicht gefunden")
    try assertEqual(img!.filename, "foto.jpg")
    try assertEqual(img!.width, 4000)
    try assertEqual(img!.cameraMake, "Canon")
    try assertEqual(img!.cameraModel, "EOS R5")
    try assertEqual(img!.isRAW, false)
}

test("allImages() gibt eingefügte Bilder zurück") {
    let s = freshStore(name: "all")
    for i in 1...5 { s.upsertImage(path: "/tmp/img\(i).jpg", filename: "img\(i).jpg", isRAW: false) }
    let all = s.allImages()
    try assertEqual(all.count, 5)
}

// ── 3. Duplicate (Upsert = UPDATE statt Fehler) ───────────────
print("\n[3  Duplikat-Handling]")
test("Gleicher Pfad → UPDATE statt INSERT-Fehler") {
    let s = freshStore(name: "dup")
    s.upsertImage(path: "/tmp/a.jpg", filename: "a.jpg", isRAW: false, width: 100, height: 100)
    s.upsertImage(path: "/tmp/a.jpg", filename: "a.jpg", isRAW: false, width: 4000, height: 3000)
    let all = s.allImages()
    try assertEqual(all.count, 1, "Duplikat wurde eingefügt statt aktualisiert")
    try assertEqual(all[0].width, 4000, "Width nicht aktualisiert")
}

test("removeImage() entfernt Eintrag") {
    let s = freshStore(name: "rm")
    s.upsertImage(path: "/tmp/del.jpg", filename: "del.jpg", isRAW: false)
    s.removeImage(path: "/tmp/del.jpg")
    try assert(s.image(forPath: "/tmp/del.jpg") == nil, "Bild noch vorhanden nach removeImage")
}

// ── 4. Rating CRUD ───────────────────────────────────────────
print("\n[4  Rating CRUD]")
test("Rating speichern und laden") {
    let s = freshStore(name: "rating")
    s.saveRating(path: "/tmp/r.jpg", rating: 4, flag: "pick", colorLabel: "red")
    let r = s.rating(forPath: "/tmp/r.jpg")
    try assert(r != nil, "Rating nicht gefunden")
    try assertEqual(r!.rating, 4)
    try assertEqual(r!.flag, "pick")
    try assertEqual(r!.colorLabel, "red")
}

test("Rating überschreiben") {
    let s = freshStore(name: "rating_upd")
    s.saveRating(path: "/tmp/r.jpg", rating: 2, flag: "none", colorLabel: "none")
    s.saveRating(path: "/tmp/r.jpg", rating: 5, flag: "reject", colorLabel: "green")
    let r = s.rating(forPath: "/tmp/r.jpg")!
    try assertEqual(r.rating, 5)
    try assertEqual(r.flag, "reject")
}

test("removeRating() löscht Eintrag") {
    let s = freshStore(name: "rating_del")
    s.saveRating(path: "/tmp/r.jpg", rating: 3, flag: "none", colorLabel: "none")
    s.removeRating(path: "/tmp/r.jpg")
    try assert(s.rating(forPath: "/tmp/r.jpg") == nil, "Rating noch vorhanden")
}

// ── 5. Album CRUD ────────────────────────────────────────────
print("\n[5  Album CRUD]")
test("Album erstellen und auflisten") {
    let s = freshStore(name: "album")
    s.saveAlbum(id: "abc-123", name: "Urlaub")
    let all = s.allAlbums()
    try assertEqual(all.count, 1)
    try assertEqual(all[0].name, "Urlaub")
}

test("Fotos zu Album hinzufügen und abrufen") {
    let s = freshStore(name: "album_imgs")
    s.saveAlbum(id: "alb1", name: "Sommer")
    s.addImage(path: "/tmp/a.jpg", toAlbum: "alb1", order: 0)
    s.addImage(path: "/tmp/b.jpg", toAlbum: "alb1", order: 1)
    let paths = s.images(inAlbum: "alb1")
    try assertEqual(paths.count, 2)
    try assert(paths.contains("/tmp/a.jpg"))
    try assert(paths.contains("/tmp/b.jpg"))
}

test("Foto aus Album entfernen") {
    let s = freshStore(name: "album_rm")
    s.saveAlbum(id: "alb2", name: "Winter")
    s.addImage(path: "/tmp/x.jpg", toAlbum: "alb2", order: 0)
    s.addImage(path: "/tmp/y.jpg", toAlbum: "alb2", order: 1)
    s.removeImage(path: "/tmp/x.jpg", fromAlbum: "alb2")
    let paths = s.images(inAlbum: "alb2")
    try assertEqual(paths.count, 1)
    try assertEqual(paths[0], "/tmp/y.jpg")
}

test("Album löschen entfernt auch album_images (ON DELETE CASCADE)") {
    let s = freshStore(name: "album_del")
    s.saveAlbum(id: "alb3", name: "ZuLöschen")
    s.addImage(path: "/tmp/z.jpg", toAlbum: "alb3", order: 0)
    s.deleteAlbum(id: "alb3")
    try assertEqual(s.allAlbums().count, 0)
    try assertEqual(s.images(inAlbum: "alb3").count, 0, "album_images nicht kaskadiert gelöscht")
}

test("Album umbenennen (saveAlbum mit gleicher ID)") {
    let s = freshStore(name: "album_rename")
    s.saveAlbum(id: "alb4", name: "Alt")
    s.saveAlbum(id: "alb4", name: "Neu")
    let all = s.allAlbums()
    try assertEqual(all.count, 1)
    try assertEqual(all[0].name, "Neu")
}

// ── 6. Suche ────────────────────────────────────────────────
print("\n[6  Suche]")
test("Textsuche nach Dateiname") {
    let s = freshStore(name: "search")
    s.upsertImage(path: "/tmp/london_01.jpg", filename: "london_01.jpg", isRAW: false)
    s.upsertImage(path: "/tmp/paris_01.jpg",  filename: "paris_01.jpg",  isRAW: false)
    s.upsertImage(path: "/tmp/berlin_01.jpg", filename: "berlin_01.jpg", isRAW: false)
    let r = s.search(query: "london")
    try assertEqual(r.count, 1)
    try assertEqual(r[0].filename, "london_01.jpg")
}

test("Flag-Filter") {
    let s = freshStore(name: "flag")
    s.upsertImage(path: "/tmp/pick1.jpg", filename: "pick1.jpg", isRAW: false)
    s.upsertImage(path: "/tmp/pick2.jpg", filename: "pick2.jpg", isRAW: false)
    s.upsertImage(path: "/tmp/none.jpg",  filename: "none.jpg",  isRAW: false)
    s.saveRating(path: "/tmp/pick1.jpg", rating: 0, flag: "pick", colorLabel: "none")
    s.saveRating(path: "/tmp/pick2.jpg", rating: 0, flag: "pick", colorLabel: "none")
    s.saveRating(path: "/tmp/none.jpg",  rating: 0, flag: "none", colorLabel: "none")
    let picks = s.images(flaggedAs: "pick")
    try assertEqual(picks.count, 2)
}

test("Rating-Filter (mindestens 3 Sterne)") {
    let s = freshStore(name: "rfilter")
    s.upsertImage(path: "/tmp/hi.jpg", filename: "hi.jpg", isRAW: false)
    s.upsertImage(path: "/tmp/lo.jpg", filename: "lo.jpg", isRAW: false)
    s.saveRating(path: "/tmp/hi.jpg", rating: 4, flag: "none", colorLabel: "none")
    s.saveRating(path: "/tmp/lo.jpg", rating: 1, flag: "none", colorLabel: "none")
    let hits = s.images(ratedAtLeast: 3)
    try assertEqual(hits.count, 1)
    try assertEqual(hits[0].filename, "hi.jpg")
}

// ── 7. Performance — 10.000 Upserts ─────────────────────────
print("\n[7  Performance]")
test("10.000 Upserts in < 2 s (batchUpsertImages)") {
    let s = freshStore(name: "perf")
    let items = (0..<10_000).map { i in
        (path: "/tmp/perf_\(i).jpg", filename: "perf_\(i).jpg", isRAW: i % 5 == 0,
         width: 4000, height: 3000, sizeBytes: Int64(3_000_000),
         dateTaken: Optional<String>.none, cameraMake: Optional<String>.none, cameraModel: Optional<String>.none)
    }
    let t0 = Date()
    s.batchUpsertImages(items)
    let dt = Date().timeIntervalSince(t0)
    print(String(format: "       10.000 Batch-Upserts: %.2f s", dt))
    try assert(dt < 2.0, String(format: "Zu langsam: %.2f s > 2.0 s", dt))
    try assertEqual(s.allImages().count, 10_000)
}

// ── 8. Concurrent ────────────────────────────────────────────
print("\n[8  Concurrent (8 Threads)]")
test("8 Threads gleichzeitig schreiben und lesen — kein Crash") {
    let s = freshStore(name: "concurrent")
    let group = DispatchGroup()
    let q = DispatchQueue.global(qos: .userInitiated)
    for t in 0..<8 {
        group.enter()
        q.async {
            for i in 0..<100 {
                let path = "/tmp/t\(t)_\(i).jpg"
                s.upsertImage(path: path, filename: "t\(t)_\(i).jpg", isRAW: false)
                s.saveRating(path: path, rating: i % 6, flag: "none", colorLabel: "none")
                _ = s.image(forPath: path)
                _ = s.rating(forPath: path)
            }
            group.leave()
        }
    }
    group.wait()
    let count = s.allImages().count
    try assert(count == 800, "Erwarte 800 Bilder, got \(count)")
}

// ── 9. Leere DB / Migration ohne JSON ───────────────────────
print("\n[9  Migration]")
test("Frische DB ohne albums.json — kein Fehler, Albums leer") {
    let s = freshStore(name: "migration_empty")
    try assertEqual(s.allAlbums().count, 0, "Unerwartete Albums")
    try assertEqual(s.allImages().count, 0, "Unerwartete Bilder")
}

// ── 10. Persistenz ───────────────────────────────────────────
print("\n[10  Persistenz]")
test("Daten überleben DB-Schließen und Neu-Öffnen") {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("catalog_persist_\(Int(Date().timeIntervalSince1970)).db")
    do {
        let s = CatalogStore(dbPath: tmp.path)
        s.upsertImage(path: "/tmp/persist.jpg", filename: "persist.jpg", isRAW: true, width: 6000, height: 4000)
        s.saveRating(path: "/tmp/persist.jpg", rating: 5, flag: "pick", colorLabel: "blue")
        s.saveAlbum(id: "persist-alb", name: "BeständigesAlbum")
        s.addImage(path: "/tmp/persist.jpg", toAlbum: "persist-alb", order: 0)
    } // s wird freigegeben → sqlite3_close

    let s2 = CatalogStore(dbPath: tmp.path)
    let img = s2.image(forPath: "/tmp/persist.jpg")
    try assert(img != nil, "Bild nach Neuöffnen nicht gefunden")
    try assertEqual(img!.width, 6000)
    let r = s2.rating(forPath: "/tmp/persist.jpg")
    try assert(r != nil, "Rating nach Neuöffnen nicht gefunden")
    try assertEqual(r!.rating, 5)
    try assertEqual(r!.flag, "pick")
    let albs = s2.allAlbums()
    try assertEqual(albs.count, 1)
    try assertEqual(albs[0].name, "BeständigesAlbum")
    let paths = s2.images(inAlbum: "persist-alb")
    try assertEqual(paths.count, 1)
}

// ── Ergebnis ─────────────────────────────────────────────────
print("")
print(String(repeating: "=", count: 55))
let total = passed + failed
print("Ergebnis: \(passed) PASS  |  \(failed) FAIL  |  \(total) gesamt")
print(String(repeating: "=", count: 55))
print("")

exit(failed == 0 ? 0 : 1)
