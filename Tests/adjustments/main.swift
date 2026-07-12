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

func state(exposure: Double = 0, turns: Int = 0) -> AdjustmentState {
    var s = AdjustmentState()
    s.exposure = exposure
    s.turns = turns
    return s
}

print("")
print("iPhoto AdjustmentHistory-Tests")
print(String(repeating: "=", count: 55))

// ── 1. Commit ────────────────────────────────────────────────
print("\n[1  Commit]")

test("Commit eines neuen Stands legt Undo-Schritt an") {
    var h = AdjustmentHistory()
    try assert(h.commit(state(exposure: 1)), "Commit muss true liefern")
    try assert(h.canUndo)
    try assertEqual(h.lastCommitted, state(exposure: 1))
}

test("Commit eines unveränderten Stands wird ignoriert") {
    var h = AdjustmentHistory()
    h.commit(state(exposure: 1))
    try assert(!h.commit(state(exposure: 1)), "Doppelter Commit muss false liefern")
    try assertEqual(h.undoStack.count, 1)
}

test("Commit verwirft die Redo-Historie") {
    var h = AdjustmentHistory()
    h.commit(state(exposure: 1))
    _ = h.undo()
    try assert(h.canRedo)
    h.commit(state(exposure: 2))
    try assert(!h.canRedo, "Redo muss nach Commit leer sein")
}

// ── 2. Undo / Redo ───────────────────────────────────────────
print("\n[2  Undo / Redo]")

test("Undo liefert den vorherigen Stand") {
    var h = AdjustmentHistory()
    h.commit(state(exposure: 1))
    h.commit(state(exposure: 2))
    try assertEqual(h.undo(), state(exposure: 1))
    try assertEqual(h.lastCommitted, state(exposure: 1))
}

test("Undo auf leerer Historie liefert nil") {
    var h = AdjustmentHistory()
    try assert(h.undo() == nil)
    try assert(!h.canUndo && !h.canRedo)
}

test("Redo stellt den rückgängig gemachten Stand wieder her") {
    var h = AdjustmentHistory()
    h.commit(state(exposure: 1))
    _ = h.undo()
    try assertEqual(h.redo(), state(exposure: 1))
    try assert(!h.canRedo)
}

test("Redo ohne vorheriges Undo liefert nil") {
    var h = AdjustmentHistory()
    h.commit(state(exposure: 1))
    try assert(h.redo() == nil)
}

test("Undo/Redo-Roundtrip über mehrere Schritte ist verlustfrei") {
    var h = AdjustmentHistory()
    for i in 1...5 { h.commit(state(exposure: Double(i))) }
    for i in stride(from: 4, through: 0, by: -1) {
        try assertEqual(h.undo(), state(exposure: Double(i)))
    }
    try assert(!h.canUndo)
    for i in 1...5 {
        try assertEqual(h.redo(), state(exposure: Double(i)))
    }
    try assert(!h.canRedo)
    try assertEqual(h.lastCommitted, state(exposure: 5))
}

test("Rotation (turns) läuft durch Undo korrekt zurück") {
    var h = AdjustmentHistory()
    h.commit(state(turns: 1))
    h.commit(state(turns: 2))
    try assertEqual(h.undo()?.turns, 1)
    try assertEqual(h.undo()?.turns, 0)
}

// ── 3. Tiefenbegrenzung ──────────────────────────────────────
print("\n[3  Tiefenbegrenzung]")

test("Undo-Stack ist auf maxDepth begrenzt, älteste Einträge fallen heraus") {
    var h = AdjustmentHistory()
    for i in 1...(AdjustmentHistory.maxDepth + 10) {
        h.commit(state(exposure: Double(i)))
    }
    try assertEqual(h.undoStack.count, AdjustmentHistory.maxDepth)
    // Ältester verbliebener Eintrag: Stand vor dem letzten maxDepth-Commit
    try assertEqual(h.undoStack.first, state(exposure: 10))
}

// ── 4. Reset ─────────────────────────────────────────────────
print("\n[4  Reset]")

test("Reset verwirft beide Stacks und setzt lastCommitted") {
    var h = AdjustmentHistory()
    h.commit(state(exposure: 1))
    _ = h.undo()
    h.reset(to: state(exposure: 9))
    try assert(!h.canUndo && !h.canRedo)
    try assertEqual(h.lastCommitted, state(exposure: 9))
}

// ── Ergebnis ─────────────────────────────────────────────────
print("")
print(String(repeating: "=", count: 55))
print("Ergebnis: \(passed) PASS  |  \(failed) FAIL  |  \(passed + failed) gesamt")
print(String(repeating: "=", count: 55))
exit(failed == 0 ? 0 : 1)
