import CoreGraphics
import Vision
import Foundation

// Erkennt Gesichter in einem CGImage via VNDetectFaceLandmarksRequest Rev3.
// Gibt für jedes erkannte Gesicht eine FaceRecord zurück, inklusive:
// - bbox: normalisierte CGRect, top-left-Ursprung (Vision liefert bottom-left → wird geflippt)
// - embeddingData: 128 × Float32 = 512 Bytes (FaceEmbedder.compute)
//
// Perf: ~80–200 ms pro 512px Thumbnail auf M1 — akzeptabel im Background-Scan,
//        nicht im Render-Pfad verwenden.

struct FaceDetector {
    static func detect(in image: CGImage, imagePath: String) -> [FaceRecord] {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        guard let observations = request.results as? [VNFaceObservation], !observations.isEmpty else {
            return []
        }
        return observations.map { obs in
            // Vision: bottom-left origin → flip Y to top-left
            let vb = obs.boundingBox
            let bbox = CGRect(x: vb.origin.x,
                              y: 1.0 - vb.origin.y - vb.height,
                              width: vb.width,
                              height: vb.height)
            let embedding = obs.landmarks.map { FaceEmbedder.compute(landmarks: $0, bbox: vb) }
            let embeddingData = embedding.flatMap { $0 } // Data? from optional
            return FaceRecord(
                id: UUID().uuidString,
                imagePath: imagePath,
                clusterID: nil,
                bbox: bbox,
                confidence: Float(obs.confidence),
                embeddingData: embeddingData
            )
        }
    }
}

// Berechnet ein 128-Float-Embedding aus Vision-Landmarks.
// 64 Punkte aus allPoints, normalisiert relativ zur inter-okularen Distanz und Mitte.
// Weniger Punkte → mit 0 aufgefüllt. Ergebnis: 128 × Float32 = 512 Bytes.

struct FaceEmbedder {
    static func compute(landmarks: VNFaceLandmarks2D, bbox: CGRect) -> Data {
        var floats = [Float](repeating: 0, count: 128)

        guard let allPts = landmarks.allPoints?.normalizedPoints, !allPts.isEmpty else {
            return floats.withUnsafeBytes { Data($0) }
        }

        // Referenzpunkte für Normalisierung: Mittelpunkte beider Augen
        let leftCenter  = centroid(landmarks.leftEye?.normalizedPoints ?? [])
        let rightCenter = centroid(landmarks.rightEye?.normalizedPoints ?? [])
        let midX = Float((leftCenter.x + rightCenter.x) / 2)
        let midY = Float((leftCenter.y + rightCenter.y) / 2)
        let ior  = Float(hypot(rightCenter.x - leftCenter.x, rightCenter.y - leftCenter.y))
        let scale: Float = ior > 0 ? 1.0 / ior : 1.0

        let take = min(64, allPts.count)
        for i in 0..<take {
            floats[i * 2]     = (Float(allPts[i].x) - midX) * scale
            floats[i * 2 + 1] = (Float(allPts[i].y) - midY) * scale
        }
        return floats.withUnsafeBytes { Data($0) }
    }

    private static func centroid(_ pts: [CGPoint]) -> CGPoint {
        guard !pts.isEmpty else { return .zero }
        let sx = pts.reduce(0.0) { $0 + $1.x }
        let sy = pts.reduce(0.0) { $0 + $1.y }
        return CGPoint(x: sx / CGFloat(pts.count), y: sy / CGFloat(pts.count))
    }
}
