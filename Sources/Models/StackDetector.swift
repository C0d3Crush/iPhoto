import Foundation

// Erkennt Serienbild-/Bracketing-Stapel (Fuji BKT & CH/CL) aus Sequenznummern.
// Pure Logik ohne ViewModel-/Katalog-Abhängigkeiten — testbar via Tests/run_stacking.sh.
struct StackDetector {
    struct Item {
        let id: UUID
        let filename: String
        // Fuji MakerNote 0x1101: 0 = Einzelbild, 1…n = Position in BKT-/CH-/CL-Serie
        let seq: Int
    }

    struct Result {
        var counts: [UUID: Int] = [:]
        var leaderByMember: [UUID: UUID] = [:]
        var membersByLeader: [UUID: [UUID]] = [:]
    }

    // Erkennt Stapel über die Dateinamens-Reihenfolge (= Aufnahmereihenfolge):
    // aufeinanderfolgende Bilder mit seq ≥ 1 und nicht-fallender Sequenz bilden einen Lauf
    // (nicht-fallend statt strikt steigend deckt RAF+JPEG-Paare 1,1,2,2,… ab);
    // seq == 0 oder Sequenz-Reset (…7 → 1) beendet den Lauf. Läufe ≥ 2 werden Stapel.
    static func detect(_ items: [Item]) -> Result {
        let byName = items.sorted {
            $0.filename.localizedStandardCompare($1.filename) == .orderedAscending
        }
        var result = Result()
        var run: [(id: UUID, seq: Int)] = []
        func closeRun() {
            if run.count >= 2 {
                let leaderID = run[0].id
                result.counts[leaderID] = run.count
                for m in run { result.leaderByMember[m.id] = leaderID }
                result.membersByLeader[leaderID] = run.map { $0.id }
            }
            run.removeAll()
        }
        for item in byName {
            if item.seq >= 1 {
                if let last = run.last, item.seq < last.seq { closeRun() }
                run.append((item.id, item.seq))
            } else {
                closeRun()
            }
        }
        closeRun()
        return result
    }

    // Anzeige-Reihenfolge: eingeklappte Nicht-Anführer entfallen; bei aufgeklapptem
    // Stapel folgen die Mitglieder direkt hinter dem Anführer.
    static func displayIDs(sortedIDs: [UUID], result: Result, expandedLeaders: Set<UUID>) -> [UUID] {
        var out: [UUID] = []
        for id in sortedIDs {
            if let leaderID = result.leaderByMember[id], leaderID != id { continue }
            out.append(id)
            if result.counts[id] != nil, expandedLeaders.contains(id),
               let members = result.membersByLeader[id] {
                out += members.dropFirst()
            }
        }
        return out
    }
}
