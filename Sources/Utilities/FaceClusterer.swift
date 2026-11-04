import Foundation

// DBSCAN-Clustering auf VNFeaturePrint-Embeddings.
//
// Distanzmetrik: Cosinus-Distanz (1 − cos_sim), normalisiert auf [0, 1].
// VNFeaturePrint (MobileNet/ResNet): gleiche Person typisch < 0.30,
// verschiedene Personen > 0.55 — epsilon 0.40 ist konservativ und vermeidet
// falsche Merges (lieber zu viele Cluster als zu wenige).
//
// minPts = 1 → jedes Gesicht landet in einem Cluster (kein Rauschen),
// UX: Nutzer sieht alle als Personen und mergt bei Bedarf manuell.
//
// Komplexität: O(N²) → bei 500 Faces ~250K Distanzen à ~512 Ops = 128M Ops, <100 ms.

struct FaceClusterer {
    static let defaultEpsilon: Float = 0.40
    static let defaultMinPts: Int    = 1

    // Gibt [faceID: clusterIndex] zurück. clusterIndex = -1 → Rauschen (nur wenn minPts > 1).
    static func cluster(faces: [FaceRecord],
                        epsilon: Float = defaultEpsilon,
                        minPts: Int    = defaultMinPts) -> [String: Int] {
        guard !faces.isEmpty else { return [:] }

        let embeddings = faces.map { extractEmbedding($0) }
        let n = faces.count
        let unvisited = -2
        var labels = [Int](repeating: unvisited, count: n)
        var clusterCount = 0

        for i in 0..<n {
            guard labels[i] == unvisited else { continue }

            var neighbors = [Int]()
            for j in 0..<n {
                if cosineDistance(embeddings[i], embeddings[j]) <= epsilon {
                    neighbors.append(j)
                }
            }

            if neighbors.count < minPts {
                labels[i] = -1  // Rauschen
                continue
            }

            labels[i] = clusterCount
            var seedSet = Set(neighbors.filter { $0 != i })
            var pending  = Array(seedSet)
            var pi = 0

            while pi < pending.count {
                let q = pending[pi]; pi += 1

                if labels[q] == -1 { labels[q] = clusterCount }
                guard labels[q] == unvisited else { continue }

                labels[q] = clusterCount
                var qNeighbors = [Int]()
                for j in 0..<n {
                    if cosineDistance(embeddings[q], embeddings[j]) <= epsilon {
                        qNeighbors.append(j)
                    }
                }
                if qNeighbors.count >= minPts {
                    for nb in qNeighbors where !seedSet.contains(nb) {
                        seedSet.insert(nb); pending.append(nb)
                    }
                }
            }
            clusterCount += 1
        }

        var result = [String: Int]()
        for (i, face) in faces.enumerated() { result[face.id] = labels[i] }
        return result
    }

    // MARK: - Helpers

    static func extractEmbedding(_ face: FaceRecord) -> [Float] {
        guard let data = face.embeddingData, data.count == 128 * 4 else {
            return [Float](repeating: 0, count: 128)
        }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    static func cosineDistance(_ a: [Float], _ b: [Float]) -> Float {
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
