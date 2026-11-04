import CoreGraphics
import Vision
import Foundation

// Erkennt Gesichter via VNDetectFaceRectanglesRequest und berechnet pro Face einen
// VNGenerateImageFeaturePrintRequest-Embedding aus dem Face-Crop.
//
// VNFeaturePrint (macOS 10.15+) nutzt ein internes MobileNet/ResNet-Modell —
// viel diskriminativer als reine Landmark-Positionen. Gleiche Person < 0.35,
// verschiedene Personen > 0.55 (Cosinus-Distanz).
//
// Perf: ~100–300 ms pro Bild (Detect + FeaturePrint) @ 512px Thumbnail.

struct FaceDetector {
    static func detect(in image: CGImage, imagePath: String) -> [FaceRecord] {
        // Schritt 1: Gesichts-Bounding-Boxes
        let detectRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do { try handler.perform([detectRequest]) } catch { return [] }
        guard let observations = detectRequest.results as? [VNFaceObservation],
              !observations.isEmpty else { return [] }

        return observations.compactMap { obs -> FaceRecord? in
            // Vision: bottom-left origin → flip Y → top-left origin
            let vb = obs.boundingBox
            let bbox = CGRect(x: vb.origin.x,
                              y: 1.0 - vb.origin.y - vb.height,
                              width: vb.width,
                              height: vb.height)

            // Schritt 2: Face-Crop + VNFeaturePrint-Embedding
            let embedding = featurePrintEmbedding(image: image, visionBBox: vb)

            return FaceRecord(
                id: UUID().uuidString,
                imagePath: imagePath,
                clusterID: nil,
                bbox: bbox,
                confidence: Float(obs.confidence),
                embeddingData: embedding
            )
        }
    }

    // Schneidet Face-Region aus dem Bild (mit 20% Rand) und berechnet
    // VNGenerateImageFeaturePrintRequest darauf. Gibt nil bei Fehler zurück.
    private static func featurePrintEmbedding(image: CGImage, visionBBox vb: CGRect) -> Data? {
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)

        // Vision bbox: bottom-left origin, in [0,1]. In Pixel umrechnen + Rand.
        let pad: CGFloat = 0.2
        let fx = max(0, (vb.origin.x - pad * vb.width) * w)
        let fy = max(0, (1.0 - vb.origin.y - vb.height - pad * vb.height) * h)
        let fw = min(w - fx, (vb.width  + 2 * pad * vb.width)  * w)
        let fh = min(h - fy, (vb.height + 2 * pad * vb.height) * h)
        guard fw > 8, fh > 8,
              let crop = image.cropping(to: CGRect(x: fx, y: fy, width: fw, height: fh)) else {
            return nil
        }

        let fpRequest = VNGenerateImageFeaturePrintRequest()
        let fpHandler = VNImageRequestHandler(cgImage: crop, orientation: .up, options: [:])
        do { try fpHandler.perform([fpRequest]) } catch { return nil }
        guard let obs = fpRequest.results?.first as? VNFeaturePrintObservation else { return nil }
        return obs.data
    }
}
