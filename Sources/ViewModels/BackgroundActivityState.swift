import Foundation
import Combine

/// Sichtbare Hintergrund-Aktivität: Lade-/Sync-Warteschlange (Sidebar-Fortschrittsbalken)
/// und Import-Fortschritt pro Ordner/Volume. Zugriff nur vom Main-Thread.
final class BackgroundActivityState: ObservableObject {

    struct ImportProgress {
        var folderName: String
        var completed: Int
        var total: Int
    }

    struct LoadingTask: Identifiable {
        let id: UUID
        var label: String
        var icon: String
        var done: Int
        var total: Int
        var summaryVerb: String = "geladen"
        var startedAt: Date = Date()
        var progress: Double { total > 0 ? Double(done) / Double(total) : 0 }
    }

    @Published var importProgress: [UUID: ImportProgress] = [:]
    @Published var completedImports: Set<UUID> = []
    @Published var loadingQueue: [LoadingTask] = []
    @Published var loadingSummary: String? = nil
    @Published var pausedTasks: Set<UUID> = []
    private var loadingSummaryToken = UUID()

    // Pausen-Status lock-geschützt gespiegelt: Worker-Threads dürfen @Published
    // nicht abseits des Main-Threads lesen, blockieren aber auf dieser Condition.
    private let pauseCondition = NSCondition()
    private var pausedTasksSync: Set<UUID> = []

    func togglePause(id: UUID) {
        pauseCondition.lock()
        if pausedTasksSync.contains(id) {
            pausedTasksSync.remove(id)
        } else {
            pausedTasksSync.insert(id)
        }
        pausedTasks = pausedTasksSync
        pauseCondition.broadcast()
        pauseCondition.unlock()
    }

    /// Blockiert den aufrufenden Hintergrund-Thread, solange die Aufgabe pausiert ist.
    func waitWhilePaused(id: UUID) {
        pauseCondition.lock()
        while pausedTasksSync.contains(id) { pauseCondition.wait() }
        pauseCondition.unlock()
    }

    private func clearPause(id: UUID) {
        pauseCondition.lock()
        pausedTasksSync.remove(id)
        pausedTasks = pausedTasksSync
        pauseCondition.broadcast()
        pauseCondition.unlock()
    }

    func enqueue(id: UUID, label: String, icon: String, done: Int = 0, total: Int = 0, summaryVerb: String = "geladen") {
        loadingSummary = nil
        if let idx = loadingQueue.firstIndex(where: { $0.id == id }) {
            loadingQueue[idx].label = label
            loadingQueue[idx].done  = done
            loadingQueue[idx].total = total
        } else {
            loadingQueue.append(LoadingTask(id: id, label: label, icon: icon, done: done, total: total, summaryVerb: summaryVerb))
        }
    }

    func update(id: UUID, done: Int, total: Int) {
        guard let idx = loadingQueue.firstIndex(where: { $0.id == id }) else { return }
        loadingQueue[idx].done  = done
        loadingQueue[idx].total = total
    }

    func dequeue(id: UUID) {
        clearPause(id: id)
        let finished = loadingQueue.first { $0.id == id }
        loadingQueue.removeAll { $0.id == id }
        // Nur bei vollständig abgeschlossenen Aufgaben mit bekanntem Umfang und leerer
        // Warteschlange die Zusammenfassung zeigen (nicht bei Abbruch/Fehler).
        guard loadingQueue.isEmpty, let t = finished, t.total > 0, t.done >= t.total else { return }
        let secs = Date().timeIntervalSince(t.startedAt)
        let secText = secs < 10
            ? String(format: "%.1f", secs).replacingOccurrences(of: ".", with: ",")
            : "\(Int(secs.rounded()))"
        loadingSummary = "\(t.total) \(t.total == 1 ? "Bild" : "Bilder") in \(secText) Sekunden \(t.summaryVerb)"
        let token = UUID()
        loadingSummaryToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            guard let self = self, self.loadingSummaryToken == token else { return }
            self.loadingSummary = nil
        }
    }
}
