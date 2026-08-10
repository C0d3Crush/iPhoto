import Accelerate
import CoreGraphics
import Foundation

// Bündelt Blur/Belichtung/pHash pro Bild, sodass der teure Decode nur einmal passiert.
// Der Aufrufer (ImageViewModel+QualityScan) läuft auf einem Background-Queue.
//
// Trennung von BlurDetector/ExposureDetector: die einzelnen Detector-Utilities bleiben
// bestehen (werden von Views weiter für Ad-hoc-Scans genutzt); dieser Assessor ist die
// gebündelte Version für den Import-Hook.

struct QualityAssessor {
    struct Result {
        let blurScore: Double
        let underRatio: Double
        let overRatio: Double
        let phash: UInt64          // horizontale Gradienten (dHash)
        let phashV: UInt64         // vertikale Gradienten (dHash) — orthogonaler Zweitsignal
        // Kleinste Eye-Aspect-Ratio aller erkannten Gesichter — nil = kein Gesicht.
        let eyeOpenness: Double?
    }

    static func assess(url: URL) -> Result? {
        let cg: CGImage?
        do {
            cg = try RAWImageDecoder.thumbnail(url: url, maxDimension: 512)
        } catch {
            cg = nil
        }
        guard let img = cg else { return nil }
        return assess(image: img)
    }

    // Kann auch mit einem bereits dekodierten CGImage aufgerufen werden (z. B. wenn ein
    // Thumbnail schon im Speicher liegt) — spart den Decode-Roundtrip.
    static func assess(image: CGImage) -> Result {
        let blur = BlurDetector.score(from: image)
        let expo = ExposureDetector.analyze(from: image)
        let (hashH, hashV) = PerceptualHash.dHashPair(from: image)
        let eyeOpenness = ClosedEyeDetector.minEyeOpenness(from: image)
        return Result(blurScore: blur, underRatio: expo.underRatio, overRatio: expo.overRatio,
                      phash: hashH, phashV: hashV, eyeOpenness: eyeOpenness)
    }
}

// dHash: 9×8 Grauwerte → 64 Bits (horizontal), plus 8×9 → 64 Bits (vertikal).
// Invariant gegenüber Helligkeit/WB-Änderungen (nur Gradienten zählen) — ideal für
// Bracketing-Erkennung. Zwei Achsen: bei dunklen Motiven produziert ein 9×8 dHash
// viele identische Bits (Flächen ohne Struktur). Der zweite Hash entlang der
// anderen Achse gibt Grouping-Code eine unabhängige Prüfung — Bilder gelten nur
// dann als ähnlich, wenn beide Hashes matchen.
struct PerceptualHash {
    static func dHash(from image: CGImage) -> UInt64 {
        return dHashPair(from: image).0
    }

    static func dHashPair(from image: CGImage) -> (UInt64, UInt64) {
        // 9×9 Grauwertraster: aus einem einzigen Downscale beide Hashes ableiten.
        // Vorher: zweimal getrennter Downscale → doppelter Rendering-Aufwand.
        let side = 9, n = side * side
        var gray = [UInt8](repeating: 0, count: n)
        guard let ctx = CGContext(
            data: &gray, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return (0, 0) }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        var hashH: UInt64 = 0
        var bitH = 0
        for y in 0..<8 {
            for x in 0..<8 {
                if gray[y * side + x] > gray[y * side + x + 1] {
                    hashH |= (1 << bitH)
                }
                bitH += 1
            }
        }

        var hashV: UInt64 = 0
        var bitV = 0
        for x in 0..<8 {
            for y in 0..<8 {
                if gray[y * side + x] > gray[(y + 1) * side + x] {
                    hashV |= (1 << bitV)
                }
                bitV += 1
            }
        }
        return (hashH, hashV)
    }

    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }
}
