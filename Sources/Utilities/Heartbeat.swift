import Foundation

/// Periodischer Lebenszeichen-Logger zur Diagnose von SIGKILL-Abstürzen (OOM, Force-Quit),
/// die keinen [SIGNAL]-Eintrag hinterlassen können. Läuft auf einem Background-Timer,
/// damit er auch bei blockiertem Main-Thread weiter schreibt:
/// - Speicherverbrauch wächst vor dem Ende  → OOM-Kill
/// - "main blockiert seit Ns" vor dem Ende  → UI-Freeze + Force-Quit durch den Nutzer
final class Heartbeat {
    static let shared = Heartbeat()

    private let interval: TimeInterval = 10
    private let queue = DispatchQueue(label: "iphoto.heartbeat", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var lastMainPong = Date()
    private let pongLock = NSLock()

    private init() {}

    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        // Ping the main thread; the pong timestamp lags if it is blocked.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pongLock.lock()
            self.lastMainPong = Date()
            self.pongLock.unlock()
        }

        pongLock.lock()
        let mainLag = Date().timeIntervalSince(lastMainPong)
        pongLock.unlock()

        let mem = Heartbeat.memoryFootprintMB()
        let memText = mem.map { String(format: "%.0f MB", $0) } ?? "?"
        if mainLag > interval * 1.5 {
            Log.info("[HEARTBEAT] mem=\(memText), main blockiert seit \(Int(mainLag))s")
        } else {
            Log.info("[HEARTBEAT] mem=\(memText), main ok")
        }
    }

    /// phys_footprint entspricht der "Speicher"-Spalte des Aktivitätsmonitors.
    static func memoryFootprintMB() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Double(info.phys_footprint) / 1_048_576
    }
}
