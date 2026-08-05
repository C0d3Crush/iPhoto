import Foundation

// Gruppiert Bilder anhand ihres pHash (dHash) mit Hamming-Distanz.
//
// Use Case (Nutzer-Wunsch v1.7.0): "Ich mache oft einige Bilder mit verschienden
// Einstellungen wie Kelvin oder Helligkeit … ich will an der linken Seite so n
// Feature das ähnliche Bilder gruppiert werden."
//
// dHash ist invariant gegen Helligkeit/WB — genau richtig für Bracketing-Serien.
//
// Historisch: v1.7.0 nutzte Union-Find — das erzeugte transitive Ketten (A~B, B~C, C~D
// werden alle in einer Gruppe zusammengefasst, auch wenn d(A,D) sehr groß ist).
// Bei dunklen/kontrastarmen Bildern führte das zu Riesen-Clustern völlig unähnlicher Bilder.
// Ab v1.9.1: seed-and-pull — jede Gruppe hat einen Seed, alle Mitglieder liegen innerhalb
// `maxDistance` vom Seed. Cluster-Durchmesser damit ≤ 2·maxDistance (Dreiecksungleichung).

struct SimilarityGrouper {
    /// Standard-Distanz für 64-Bit dHash. 8 Bits = 12,5 % Unterschied — eng genug, dass
    /// unähnliche Motive nicht zusammengezogen werden, weit genug für Bracketing-Serien.
    static let defaultMaxHammingDistance = 8

    /// Gruppen ähnlicher Bilder (Größe ≥ 2). Jede Gruppe: Seed + alle Docs mit
    /// Hamming-Distanz ≤ maxDistance zum Seed. Sortierung nach filename bestimmt den
    /// Seed deterministisch (erster nicht-verarbeiteter Doc der sortierten Liste).
    static func groups(from docs: [ImageDocument], maxDistance: Int = defaultMaxHammingDistance) -> [[ImageDocument]] {
        let hashed = docs
            .compactMap { doc -> (ImageDocument, UInt64)? in
                guard let h = doc.phash else { return nil }
                return (doc, h)
            }
            .sorted { $0.0.filename < $1.0.filename }
        guard hashed.count > 1 else { return [] }

        var claimed = [Bool](repeating: false, count: hashed.count)
        var result: [[ImageDocument]] = []

        for i in 0..<hashed.count where !claimed[i] {
            let seedHash = hashed[i].1
            var group: [ImageDocument] = [hashed[i].0]
            claimed[i] = true
            for j in (i + 1)..<hashed.count where !claimed[j] {
                let d = (seedHash ^ hashed[j].1).nonzeroBitCount
                if d <= maxDistance {
                    group.append(hashed[j].0)
                    claimed[j] = true
                }
            }
            if group.count > 1 {
                result.append(group.sorted { $0.filename < $1.filename })
            }
        }

        return result.sorted { $0[0].filename < $1[0].filename }
    }
}
