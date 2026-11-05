import Foundation

// Complete-Linkage-Clustering auf VNFeaturePrint-Embeddings (2048×Float32, 8 KB/Face).
//
// Distanzmetrik: Cosinus-Distanz (1 − cos_sim), normalisiert auf [0, 1].
// Linkage: Complete-Linkage — zwei Cluster werden nur zusammengeführt, wenn
// ALLE Paare (a ∈ A, b ∈ B) mit Abstand ≤ epsilon. Verhindert das "Chaining"-Artefakt
// von DBSCAN, bei dem ein Brückenpunkt zwei weit auseinanderliegende Gruppen verbindet.
//
// Epsilon 0.12: typische same-person Paare aus modernen Farbfotos < 0.10,
// cross-person Paare > 0.15. Nutzer kann falsche Gruppen manuell trennen.
//
// Komplexität: O(N³) im Worst Case — bei 500 Faces (~250K Paare × N Merge-Schritten)
// praktisch < 1 s für normale Bibliotheksgrößen. Bei > 5000 Faces: DB-seitig batchen.

struct FaceClusterer {
    static let defaultEpsilon: Float = 0.12
    static let defaultMinPts: Int    = 1

    // Gibt [faceID: clusterIndex] zurück.
    static func cluster(faces: [FaceRecord],
                        epsilon: Float = defaultEpsilon,
                        minPts: Int    = defaultMinPts) -> [String: Int] {
        guard !faces.isEmpty else { return [:] }

        let embeddings = faces.map { extractEmbedding($0) }
        let n = faces.count

        // Distanzmatrix vorberechnen
        var dist = [[Float]](repeating: [Float](repeating: 0, count: n), count: n)
        for i in 0..<n {
            for j in (i+1)..<n {
                let d = cosineDistance(embeddings[i], embeddings[j])
                dist[i][j] = d
                dist[j][i] = d
            }
        }

        // Start: jeder Face ist sein eigener Cluster
        var memberOf = Array(0..<n)          // memberOf[i] = Cluster-ID von Face i
        var clusters = [Int: [Int]]()        // cluster-ID → Liste der Face-Indizes
        for i in 0..<n { clusters[i] = [i] }

        // Complete-Linkage: maximale Distanz zwischen zwei Clustern
        func completeLink(_ a: [Int], _ b: [Int]) -> Float {
            var maxD: Float = 0
            for i in a {
                for j in b {
                    let d = dist[i][j]
                    if d > maxD { maxD = d }
                }
            }
            return maxD
        }

        // Iterativ nächste Cluster-Paare zusammenführen
        var changed = true
        while changed {
            changed = false
            let ids = Array(clusters.keys)
            var bestDist: Float = epsilon
            var bestA = -1, bestB = -1

            for ai in 0..<ids.count {
                for bi in (ai+1)..<ids.count {
                    let d = completeLink(clusters[ids[ai]]!, clusters[ids[bi]]!)
                    if d < bestDist {
                        bestDist = d
                        bestA = ids[ai]
                        bestB = ids[bi]
                    }
                }
            }

            if bestA >= 0 {
                var merged = clusters[bestA]!
                merged.append(contentsOf: clusters[bestB]!)
                clusters[bestA] = merged
                clusters.removeValue(forKey: bestB)
                for i in clusters[bestA]! { memberOf[i] = bestA }
                changed = true
            }
        }

        // Cluster-IDs auf 0..N normieren
        var idMap = [Int: Int]()
        var nextId = 0
        var result = [String: Int]()
        for (i, face) in faces.enumerated() {
            let cid = memberOf[i]
            if idMap[cid] == nil { idMap[cid] = nextId; nextId += 1 }
            result[face.id] = idMap[cid]!
        }
        return result
    }

    // MARK: - Helpers

    static func extractEmbedding(_ face: FaceRecord) -> [Float] {
        guard let data = face.embeddingData, data.count >= 4, data.count % 4 == 0 else {
            return []
        }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    static func cosineDistance(_ a: [Float], _ b: [Float]) -> Float {
        guard !a.isEmpty, !b.isEmpty else { return 1.0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        let len = min(a.count, b.count)
        for i in 0..<len {
            dot += a[i] * b[i]
            na  += a[i] * a[i]
            nb  += b[i] * b[i]
        }
        guard na > 0, nb > 0 else { return 1.0 }
        return max(0, 1.0 - dot / (na.squareRoot() * nb.squareRoot()))
    }
}
