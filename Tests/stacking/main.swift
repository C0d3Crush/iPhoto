import Foundation

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

// Erzeugt Items mit stabilen IDs; Rückgabe: (items, ids) — ids[i] gehört zu name/seq an Position i.
func makeItems(_ specs: [(name: String, seq: Int)]) -> (items: [StackDetector.Item], ids: [UUID]) {
    var items: [StackDetector.Item] = []
    var ids: [UUID] = []
    for spec in specs {
        let id = UUID()
        ids.append(id)
        items.append(StackDetector.Item(id: id, filename: spec.name, seq: spec.seq))
    }
    return (items, ids)
}

print("")
print("iPhoto StackDetector-Tests")
print(String(repeating: "=", count: 55))

// ── 1. Stapel-Erkennung ──────────────────────────────────────
print("\n[1  Stapel-Erkennung]")

test("Einfacher Lauf 1,2,3 wird ein Stapel") {
    let (items, ids) = makeItems([("a1.raf", 1), ("a2.raf", 2), ("a3.raf", 3)])
    let r = StackDetector.detect(items)
    try assertEqual(r.counts, [ids[0]: 3])
    try assertEqual(r.membersByLeader[ids[0]]!, [ids[0], ids[1], ids[2]])
    for id in ids { try assertEqual(r.leaderByMember[id]!, ids[0]) }
}

test("Nur Einzelbilder (seq 0) ergeben keine Stapel") {
    let (items, _) = makeItems([("a.raf", 0), ("b.raf", 0), ("c.raf", 0)])
    let r = StackDetector.detect(items)
    try assert(r.counts.isEmpty && r.leaderByMember.isEmpty && r.membersByLeader.isEmpty)
}

test("Lauf der Länge 1 wird kein Stapel") {
    let (items, _) = makeItems([("a.raf", 0), ("b.raf", 1), ("c.raf", 0)])
    let r = StackDetector.detect(items)
    try assert(r.counts.isEmpty, "einzelnes seq=1 darf kein Stapel sein")
}

test("Sequenz-Reset 1,2,3 → 1,2 trennt zwei Stapel") {
    let (items, ids) = makeItems([("a1.raf", 1), ("a2.raf", 2), ("a3.raf", 3),
                                  ("b1.raf", 1), ("b2.raf", 2)])
    let r = StackDetector.detect(items)
    try assertEqual(r.counts, [ids[0]: 3, ids[3]: 2])
    try assertEqual(r.leaderByMember[ids[4]]!, ids[3])
}

test("RAF+JPEG-Paare 1,1,2,2 bilden einen Stapel (nicht-fallend)") {
    let (items, ids) = makeItems([("a1.raf", 1), ("a1j.jpg", 1), ("a2.raf", 2), ("a2j.jpg", 2)])
    let r = StackDetector.detect(items)
    try assertEqual(r.counts.count, 1)
    try assertEqual(r.counts[ids[0]]!, 4)
}

test("Gleichbleibende Sequenz 2,2,2 bildet einen Stapel") {
    let (items, ids) = makeItems([("a.raf", 2), ("b.raf", 2), ("c.raf", 2)])
    let r = StackDetector.detect(items)
    try assertEqual(r.counts, [ids[0]: 3])
}

test("seq 0 unterbricht einen Lauf") {
    let (items, ids) = makeItems([("a1.raf", 1), ("a2.raf", 2), ("x.raf", 0),
                                  ("b1.raf", 1), ("b2.raf", 2)])
    let r = StackDetector.detect(items)
    try assertEqual(r.counts, [ids[0]: 2, ids[3]: 2])
    try assert(r.leaderByMember[ids[2]] == nil, "Einzelbild darf keinem Stapel angehören")
}

test("Dateinamens-Sortierung ist numerisch (IMG_9 vor IMG_10)") {
    // Eingabe absichtlich unsortiert — Anführer muss IMG_9 sein.
    let (items, ids) = makeItems([("IMG_10.raf", 2), ("IMG_9.raf", 1)])
    let r = StackDetector.detect(items)
    try assertEqual(r.counts, [ids[1]: 2])
    try assertEqual(r.membersByLeader[ids[1]]!, [ids[1], ids[0]])
}

test("Eingabe-Reihenfolge irrelevant für Erkennung") {
    let (items, ids) = makeItems([("a3.raf", 3), ("a1.raf", 1), ("a2.raf", 2)])
    let r = StackDetector.detect(items.shuffled())
    try assertEqual(r.counts, [ids[1]: 3])
}

test("Leere Eingabe") {
    let r = StackDetector.detect([])
    try assert(r.counts.isEmpty)
}

// ── 2. Anzeige-Reihenfolge ───────────────────────────────────
print("\n[2  Anzeige-Reihenfolge]")

test("Eingeklappt: nur Anführer sichtbar, Einzelbilder bleiben") {
    let (items, ids) = makeItems([("a1.raf", 1), ("a2.raf", 2), ("solo.raf", 0)])
    let r = StackDetector.detect(items)
    let out = StackDetector.displayIDs(sortedIDs: ids, result: r, expandedLeaders: [])
    try assertEqual(out, [ids[0], ids[2]])
}

test("Aufgeklappt: Mitglieder direkt hinter dem Anführer") {
    let (items, ids) = makeItems([("a1.raf", 1), ("a2.raf", 2), ("a3.raf", 3), ("solo.raf", 0)])
    let r = StackDetector.detect(items)
    let out = StackDetector.displayIDs(sortedIDs: ids, result: r, expandedLeaders: [ids[0]])
    try assertEqual(out, [ids[0], ids[1], ids[2], ids[3]])
}

test("Zwei Stapel, nur einer aufgeklappt") {
    let (items, ids) = makeItems([("a1.raf", 1), ("a2.raf", 2),
                                  ("b1.raf", 1), ("b2.raf", 2)])
    let r = StackDetector.detect(items)
    let out = StackDetector.displayIDs(sortedIDs: ids, result: r, expandedLeaders: [ids[2]])
    try assertEqual(out, [ids[0], ids[2], ids[3]])
}

test("Anzeige respektiert externe Sortierung (Anführer an seiner Sortier-Position)") {
    let (items, ids) = makeItems([("a1.raf", 1), ("a2.raf", 2), ("z.raf", 0)])
    let r = StackDetector.detect(items)
    // Externe Sortierung absteigend: z, a2, a1 — Anführer a1 erscheint an seiner Position.
    let out = StackDetector.displayIDs(sortedIDs: [ids[2], ids[1], ids[0]], result: r, expandedLeaders: [])
    try assertEqual(out, [ids[2], ids[0]])
}

test("Ohne Stapel bleibt die Reihenfolge unverändert") {
    let (items, ids) = makeItems([("a.raf", 0), ("b.raf", 0)])
    let r = StackDetector.detect(items)
    try assertEqual(StackDetector.displayIDs(sortedIDs: ids, result: r, expandedLeaders: []), ids)
}

// ── Ergebnis ─────────────────────────────────────────────────
print("")
print(String(repeating: "=", count: 55))
let total = passed + failed
print("Ergebnis: \(passed) PASS  |  \(failed) FAIL  |  \(total) gesamt")
print(String(repeating: "=", count: 55))
print("")

exit(failed == 0 ? 0 : 1)
