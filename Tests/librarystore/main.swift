import Foundation

// ═════════════════════════════════════════════════════════════
//  iPhoto LibraryStore Test Suite
//  JSON-Persistenz von Alben, überwachten Ordnern und
//  intelligenten Ordnern — Roundtrip, Fehlerfälle, Isolation.
// ═════════════════════════════════════════════════════════════

var passed = 0
var failed = 0

func test(_ name: String, _ block: () throws -> Void) {
    do {
        try block()
        passed += 1
        print("  PASS  \(name)")
    } catch {
        failed += 1
        print("  FAIL  \(name)  — \(error)")
    }
}

struct Fail: Error { let msg: String }

func assert(_ cond: Bool, _ msg: String = "Bedingung nicht erfüllt") throws {
    if !cond { throw Fail(msg: msg) }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") throws {
    if a != b { throw Fail(msg: "\(a) != \(b)  \(msg)") }
}

/// Frisches, isoliertes Verzeichnis pro Test.
func freshDir(name: String) -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("iphoto_librarystore_test_\(name)_\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

print("")
print(String(repeating: "═", count: 55))
print(" iPhoto LibraryStore Tests")
print(String(repeating: "═", count: 55))

// ── 1. Alben ─────────────────────────────────────────────────
print("\n[1  Alben]")
test("Alben speichern und laden (Roundtrip)") {
    let dir = freshDir(name: "albums")
    let s1 = LibraryStore(directory: dir)
    var a = Album(name: "Urlaub 2026")
    a.photoURLs = [URL(fileURLWithPath: "/tmp/a.jpg"), URL(fileURLWithPath: "/tmp/b.raf")]
    let b = Album(name: "Familie")
    s1.albums = [a, b]
    s1.saveAlbums()

    let s2 = LibraryStore(directory: dir)
    s2.loadAlbums()
    try assertEqual(s2.albums, [a, b], "Album-Roundtrip verändert Daten")
}
test("Fehlende albums.json — State bleibt leer, kein Fehler") {
    let s = LibraryStore(directory: freshDir(name: "albums_missing"))
    s.loadAlbums()
    try assertEqual(s.albums.count, 0)
}
test("Korrupte albums.json — State bleibt unverändert") {
    let dir = freshDir(name: "albums_corrupt")
    try Data("kein json {{{".utf8).write(to: dir.appendingPathComponent("albums.json"))
    let s = LibraryStore(directory: dir)
    s.albums = [Album(name: "Bestand")]
    s.loadAlbums()
    try assertEqual(s.albums.count, 1, "Korrupte Datei darf State nicht löschen")
    try assertEqual(s.albums[0].name, "Bestand")
}
test("Überschreiben: letzter Save gewinnt") {
    let dir = freshDir(name: "albums_overwrite")
    let s1 = LibraryStore(directory: dir)
    s1.albums = [Album(name: "Alt")]
    s1.saveAlbums()
    s1.albums[0].name = "Neu"
    s1.saveAlbums()

    let s2 = LibraryStore(directory: dir)
    s2.loadAlbums()
    try assertEqual(s2.albums.count, 1)
    try assertEqual(s2.albums[0].name, "Neu")
}
test("Leere Album-Liste speichern und laden") {
    let dir = freshDir(name: "albums_empty")
    let s1 = LibraryStore(directory: dir)
    s1.albums = [Album(name: "Wird gelöscht")]
    s1.saveAlbums()
    s1.albums = []
    s1.saveAlbums()

    let s2 = LibraryStore(directory: dir)
    s2.loadAlbums()
    try assertEqual(s2.albums.count, 0)
}

// ── 2. Intelligente Ordner ───────────────────────────────────
print("\n[2  Intelligente Ordner]")
test("SmartFolders speichern und laden (Roundtrip)") {
    let dir = freshDir(name: "smartfolders")
    var criterion = SmartFolderCriterion()
    criterion.attribute = .filmSimulation
    criterion.op = .isExact
    criterion.textValue = "Classic Chrome"
    var sf = SmartFolder(name: "Chrome-Bilder")
    sf.criteria = [criterion]
    sf.matchAll = true
    sf.group = "Filmsimulationen"

    let s1 = LibraryStore(directory: dir)
    s1.smartFolders = [sf]
    s1.saveSmartFolders()

    let s2 = LibraryStore(directory: dir)
    s2.loadSmartFolders()
    try assertEqual(s2.smartFolders.count, 1)
    try assertEqual(s2.smartFolders[0].id, sf.id)
    try assertEqual(s2.smartFolders[0].name, "Chrome-Bilder")
    try assertEqual(s2.smartFolders[0].group, "Filmsimulationen")
    try assertEqual(s2.smartFolders[0].matchAll, true)
    try assertEqual(s2.smartFolders[0].criteria.count, 1)
    try assertEqual(s2.smartFolders[0].criteria[0].textValue, "Classic Chrome")
}
test("Fehlende smartFolders.json — State bleibt leer") {
    let s = LibraryStore(directory: freshDir(name: "smartfolders_missing"))
    s.loadSmartFolders()
    try assertEqual(s.smartFolders.count, 0)
}

// ── 3. Überwachte Ordner ─────────────────────────────────────
print("\n[3  Überwachte Ordner]")
test("WatchedFolders speichern und laden (Roundtrip)") {
    let dir = freshDir(name: "watched")
    // init(url:) erzeugt Security-Scoped Bookmarks — im unsandboxed CLI-Binary
    // nicht möglich. Für den Persistenz-Roundtrip via Codable konstruieren.
    let id = UUID()
    let bookmark = Data("fake-bookmark-bytes".utf8)
    let json: [String: Any] = [
        "id": id.uuidString,
        "name": "Testordner",
        "bookmarkData": bookmark.base64EncodedString(),
        "autoSync": true,
        "isDefaultLibrary": true,
        "importDestinationPath": "/tmp/import",
    ]
    let wf = try JSONDecoder().decode(
        WatchedFolder.self,
        from: JSONSerialization.data(withJSONObject: json))

    let s1 = LibraryStore(directory: dir)
    s1.watchedFolders = [wf]
    s1.saveWatchedFolders()

    let s2 = LibraryStore(directory: dir)
    s2.loadWatchedFolders()
    try assertEqual(s2.watchedFolders.count, 1)
    try assertEqual(s2.watchedFolders[0].id, id)
    try assertEqual(s2.watchedFolders[0].name, "Testordner")
    try assertEqual(s2.watchedFolders[0].autoSync, true)
    try assertEqual(s2.watchedFolders[0].isDefaultLibrary, true)
    try assertEqual(s2.watchedFolders[0].importDestinationPath, "/tmp/import")
    try assertEqual(s2.watchedFolders[0].bookmarkData, bookmark)
}
test("Fehlende watchedFolders.json — State bleibt leer") {
    let s = LibraryStore(directory: freshDir(name: "watched_missing"))
    s.loadWatchedFolders()
    try assertEqual(s.watchedFolders.count, 0)
}

// ── 4. Isolation der drei Dateien ────────────────────────────
print("\n[4  Datei-Isolation]")
test("saveAlbums berührt smartFolders.json nicht") {
    let dir = freshDir(name: "isolation")
    let s1 = LibraryStore(directory: dir)
    var sf = SmartFolder(name: "Bleibt")
    sf.matchAll = true
    s1.smartFolders = [sf]
    s1.saveSmartFolders()

    s1.albums = [Album(name: "NeuesAlbum")]
    s1.saveAlbums()

    let s2 = LibraryStore(directory: dir)
    s2.loadAlbums()
    s2.loadSmartFolders()
    try assertEqual(s2.albums.count, 1)
    try assertEqual(s2.smartFolders.count, 1)
    try assertEqual(s2.smartFolders[0].name, "Bleibt")
}

// ── 5. Fehlerbehandlung ──────────────────────────────────────
print("\n[5  Fehlerbehandlung]")
test("onError feuert bei nicht beschreibbarem Verzeichnis") {
    // Pfad unter einer regulären Datei → createDirectory und write scheitern
    let blocker = FileManager.default.temporaryDirectory
        .appendingPathComponent("iphoto_librarystore_blocker_\(UUID().uuidString)")
    try Data("datei".utf8).write(to: blocker)
    let s = LibraryStore(directory: blocker.appendingPathComponent("sub"))

    var errorMessage: String?
    s.onError = { errorMessage = $0 }
    s.albums = [Album(name: "SchlägtFehl")]
    s.saveAlbums()

    // onError kommt via DispatchQueue.main.async — RunLoop kurz drehen
    let deadline = Date().addingTimeInterval(2)
    while errorMessage == nil && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    try assert(errorMessage != nil, "onError wurde nicht aufgerufen")
    try assert(errorMessage!.contains("Album-Datei"), "Meldung nennt Datei nicht: \(errorMessage!)")
}

// ── Ergebnis ─────────────────────────────────────────────────
print("")
print(String(repeating: "=", count: 55))
let total = passed + failed
print("Ergebnis: \(passed) PASS  |  \(failed) FAIL  |  \(total) gesamt")
print(String(repeating: "=", count: 55))
print("")

exit(failed == 0 ? 0 : 1)
