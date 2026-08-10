import CoreGraphics
import Vision

// Erkennt geschlossene Augen über die Eye-Aspect-Ratio (EAR): Höhe des Augen-Contours
// geteilt durch die Breite. Offene Augen liegen typisch bei EAR ≥ 0.22, blinzelnde/
// geschlossene bei ≤ 0.15. Vision liefert pro Auge einen Landmark-Contour mit ~6
// normalisierten Punkten — daraus (max Y − min Y) / (max X − min X).
//
// Rückgabe = kleinste EAR aller detektierten Augen im Bild (nil = kein Gesicht),
// weil ein einziger Blinzler in einem Gruppenfoto reicht, um das Bild markieren zu
// wollen. Threshold-Vergleich passiert im Aufrufer (QualityDetection).
//
// Perf-Anker: Vision-Face-Landmarks kosten ~50–150 ms pro 512 px Thumbnail — teuer,
// aber der Aufrufer läuft ohnehin nur im Background-Quality-Scan, nicht in einem
// Render-Pfad. Falls das später zu langsam wird: separate on-demand-Scan-Variante.

struct ClosedEyeDetector {
    // Voreinstellung konservativ: normale Aufnahmen liegen um 0.25–0.35, klare
    // Blinzler ≤ 0.12. Slider zieht das später nach oben, falls Nutzer strenger sein will.
    static let defaultThreshold: Double = 0.18

    static func minEyeOpenness(from image: CGImage) -> Double? {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observations = request.results as? [VNFaceObservation], !observations.isEmpty else {
            return nil
        }
        var minRatio: Double = .infinity
        for face in observations {
            guard let landmarks = face.landmarks else { continue }
            if let left  = landmarks.leftEye,  let r = eyeAspectRatio(left)  { minRatio = min(minRatio, r) }
            if let right = landmarks.rightEye, let r = eyeAspectRatio(right) { minRatio = min(minRatio, r) }
        }
        return minRatio.isFinite ? minRatio : nil
    }

    // EAR aus normalisierten Punkten (0…1 im Face-Bounding-Box). Height/Width sind
    // rein geometrisch — kein Anspruch auf pixelgenaue Landmarks, aber ausreichend
    // für "offen vs. zu"-Klassifikation über den Slider-Threshold.
    private static func eyeAspectRatio(_ region: VNFaceLandmarkRegion2D) -> Double? {
        let pts = region.normalizedPoints
        guard pts.count >= 4 else { return nil }
        var minX =  CGFloat.infinity, maxX = -CGFloat.infinity
        var minY =  CGFloat.infinity, maxY = -CGFloat.infinity
        for p in pts {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        let width  = maxX - minX
        let height = maxY - minY
        guard width > 0 else { return nil }
        return Double(height / width)
    }
}
