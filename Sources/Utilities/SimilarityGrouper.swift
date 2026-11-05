import Foundation

// Gruppiert Bilder anhand von zwei orthogonalen dHash-Signalen (horizontal + vertikal)
// mit Hamming-Distanz. Bildgruppen brauchen einen Match in *beiden* Achsen.
//
// Historie:
// - v1.7.0: Union-Find über einen einzelnen dHash — transitive Ketten erzeugten
//   Riesen-Cluster.
// - v1.9.1: Seed-and-Pull statt Union-Find; nur ein Hash → dunkle/kontrastarme Motive
//   liefern immer noch viele False Positives (Hash hat zu viele identische Bits).
// - v1.9.2: Zweiter Hash (vertikale Gradienten) als unabhängige Prüfung. Beide müssen
//   innerhalb der Schwelle liegen — Bilder mit ähnlicher horizontaler Struktur, aber
//   verschiedener vertikaler Struktur (z. B. zwei nächtliche Landschaften mit anderer
//   Silhouette) werden jetzt sauber getrennt.

struct SimilarityGrouper {
    /// Standard-Distanz pro Achse (64-Bit dHash). 6 Bits = 9,4 % Unterschied. Da BEIDE
    /// Achsen matchen müssen, ist das effektiv strenger als ein einzelner Hash mit 6 Bits.
    static let defaultMaxHammingDistance = 6

    /// Gruppen ähnlicher Bilder (Größe ≥ 2). Jede Gruppe: Seed + alle Docs mit
    /// Hamming-Distanz ≤ maxDistance in beiden dHash-Achsen. Docs ohne phashV
    /// werden übersprungen (fallen in einen Rescan-Cycle, siehe Migration in
    /// CatalogStore.migrateQualityColumns).
    static func groups(from docs: [ImageDocument], maxDistance: Int = defaultMaxHammingDistance) -> [[ImageDocument]] {
        let hashed = docs
            .compactMap { doc -> (ImageDocument, UInt64, UInt64)? in
                guard let h = doc.phash, let v = doc.phashV else { return nil }
                return (doc, h, v)
            }
            .sorted { $0.0.filename < $1.0.filename }
        guard hashed.count > 1 else { return [] }

        var hashesH = hashed.map { $0.1 }
        var hashesV = hashed.map { $0.2 }
        var flatLen: UInt32 = 0

        guard let flatPtr = iphoto_phash_seed_pull_groups(
            &hashesH, &hashesV, UInt32(hashed.count), UInt32(maxDistance), &flatLen
        ), flatLen > 0 else { return [] }
        defer { iphoto_phash_groups_free(flatPtr, flatLen) }

        var result: [[ImageDocument]] = []
        var currentGroup: [ImageDocument] = []
        for i in 0..<Int(flatLen) {
            let idx = flatPtr[i]
            if idx == UInt32.max {
                if currentGroup.count > 1 {
                    result.append(currentGroup.sorted { $0.filename < $1.filename })
                }
                currentGroup = []
            } else if Int(idx) < hashed.count {
                currentGroup.append(hashed[Int(idx)].0)
            }
        }
        if currentGroup.count > 1 {
            result.append(currentGroup.sorted { $0.filename < $1.filename })
        }

        return result.sorted { $0[0].filename < $1[0].filename }
    }
}
