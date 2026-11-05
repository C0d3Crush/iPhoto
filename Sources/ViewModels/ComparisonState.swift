import Foundation
import Combine

/// Isolierter State für den Bildvergleichs-Modus (Duell-Ansicht).
/// Zuvor lag der State direkt auf ImageViewModel — Extraktion senkt die VM-Komplexität
/// und macht die Verantwortlichkeit explizit. Änderungen werden von der VM per
/// objectWillChange-Forwarding an Views weitergereicht.
///
/// Main-Thread-Invariante: analog zu ImageCollection/ImageViewModel — Schreibzugriffe
/// nur auf dem Main-Thread. `ensureComparePreview` schreibt `loadInFlight` bereits
/// via DispatchQueue.main.async zurück.
final class ComparisonState: ObservableObject {
    @Published var active: Bool = false                 { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var leftID: UUID? = nil                  { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var rightID: UUID? = nil                 { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var dailyCount: Int = ComparisonState.loadDailyCount() { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    var loadInFlight: Set<URL> = []
    var lastPair: Set<UUID> = []

    static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static func loadDailyCount() -> Int {
        let today = todayString()
        let storedDate = UserDefaults.standard.string(forKey: "compare.dailyDate") ?? ""
        if storedDate != today {
            UserDefaults.standard.set(0, forKey: "compare.dailyCount")
            UserDefaults.standard.set(today, forKey: "compare.dailyDate")
            return 0
        }
        return UserDefaults.standard.integer(forKey: "compare.dailyCount")
    }
}
