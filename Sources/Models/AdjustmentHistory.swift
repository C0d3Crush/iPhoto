import Foundation

/// Undo/Redo-Historie für Anpassungen — pure Wertlogik ohne UI-/Combine-Abhängigkeiten,
/// dadurch isoliert testbar (Tests/run_adjustments.sh). Der Besitzer (ImageViewModel)
/// hält den *aktuellen* Zustand selbst; die Historie verwaltet nur committete Stände.
struct AdjustmentHistory: Equatable {
    private(set) var undoStack: [AdjustmentState] = []
    private(set) var redoStack: [AdjustmentState] = []
    private(set) var lastCommitted = AdjustmentState()

    /// Begrenzung analog zum bisherigen Verhalten: älteste Einträge fallen heraus.
    static let maxDepth = 50

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Historie verwerfen und auf einen frisch geladenen Stand setzen (Bildwechsel).
    mutating func reset(to state: AdjustmentState) {
        undoStack.removeAll()
        redoStack.removeAll()
        lastCommitted = state
    }

    /// Neuen Stand committen. Unveränderte Stände werden ignoriert (kein Undo-Schritt).
    /// Ein Commit verwirft die Redo-Historie.
    @discardableResult
    mutating func commit(_ newState: AdjustmentState) -> Bool {
        guard newState != lastCommitted else { return false }
        undoStack.append(lastCommitted)
        redoStack.removeAll()
        lastCommitted = newState
        if undoStack.count > Self.maxDepth { undoStack.removeFirst() }
        return true
    }

    /// Liefert den vorherigen Stand oder nil, wenn nichts rückgängig zu machen ist.
    mutating func undo() -> AdjustmentState? {
        guard let prev = undoStack.popLast() else { return nil }
        redoStack.append(lastCommitted)
        lastCommitted = prev
        return prev
    }

    /// Liefert den nächsten Stand oder nil, wenn nichts wiederherzustellen ist.
    mutating func redo() -> AdjustmentState? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(lastCommitted)
        lastCommitted = next
        return next
    }
}
