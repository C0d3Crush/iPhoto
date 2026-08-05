import Foundation

// Gruppiert Bilder anhand ihres pHash (dHash) mit Union-Find + Hamming-Distanz.
//
// Use Case (Nutzer-Wunsch v1.7.0): "Ich mache oft einige Bilder mit verschienden
// Einstellungen wie Kelvin oder Helligkeit … ich will an der linken Seite so n
// Feature das ähnliche Bilder gruppiert werden."
//
// dHash ist invariant gegen Helligkeit/WB — genau richtig für Bracketing-Serien.
//
// Komplexität: O(N²) im Worst Case. Für persönliche Libraries (<10k Bilder) sind das
// ~10⁸ Bitcount-Ops → wenige hundert ms auf einer modernen CPU. Falls das mal knapp
// wird, kann man auf BK-Tree oder LSH umstellen — aktuell nicht nötig.

struct SimilarityGrouper {
    /// Standard-Distanz für 64-Bit dHash. 10 Bits = 15,6 % Unterschied — konservativ genug,
    /// dass Bracketing-Serien zusammenbleiben ohne fremde Motive einzumischen.
    static let defaultMaxHammingDistance = 10

    /// Gruppen ähnlicher Bilder (Größe ≥ 2). Reine Duplikate landen ebenfalls hier —
    /// die DuplicatesView filtert exakte EXIF-Matches, hier gehts um visuelle Nähe.
    static func groups(from docs: [ImageDocument], maxDistance: Int = defaultMaxHammingDistance) -> [[ImageDocument]] {
        let hashed = docs.compactMap { doc -> (ImageDocument, UInt64)? in
            guard let h = doc.phash else { return nil }
            return (doc, h)
        }
        guard hashed.count > 1 else { return [] }

        var parent = Array(0..<hashed.count)
        func find(_ x: Int) -> Int {
            var r = x
            while parent[r] != r { r = parent[r] }
            var i = x
            while parent[i] != r { let next = parent[i]; parent[i] = r; i = next }
            return r
        }
        func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[rb] = ra }
        }

        for i in 0..<hashed.count {
            let hi = hashed[i].1
            for j in (i + 1)..<hashed.count {
                let d = (hi ^ hashed[j].1).nonzeroBitCount
                if d <= maxDistance { union(i, j) }
            }
        }

        var buckets: [Int: [ImageDocument]] = [:]
        for i in 0..<hashed.count {
            buckets[find(i), default: []].append(hashed[i].0)
        }
        return buckets.values
            .filter { $0.count > 1 }
            .map { $0.sorted { $0.filename < $1.filename } }
            .sorted { $0[0].filename < $1[0].filename }
    }
}
