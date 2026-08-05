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
        let phash: UInt64
    }

    static func assess(url: URL) -> Result? {
        let cg: CGImage?
        do {
            cg = try RAWImageDecoder.thumbnail(url: url, maxDimension: 512)
        } catch {
            cg = nil
        }
        guard let img = cg else { return nil }
        let blur = BlurDetector.score(from: img)
        let expo = ExposureDetector.analyze(from: img)
        let hash = PerceptualHash.dHash(from: img)
        return Result(blurScore: blur, underRatio: expo.underRatio, overRatio: expo.overRatio, phash: hash)
    }

    // Kann auch mit einem bereits dekodierten CGImage aufgerufen werden (z. B. wenn ein
    // Thumbnail schon im Speicher liegt) — spart den Decode-Roundtrip.
    static func assess(image: CGImage) -> Result {
        let blur = BlurDetector.score(from: image)
        let expo = ExposureDetector.analyze(from: image)
        let hash = PerceptualHash.dHash(from: image)
        return Result(blurScore: blur, underRatio: expo.underRatio, overRatio: expo.overRatio, phash: hash)
    }
}

// dHash: 9×8 Grauwerte → 64 Bits, wobei jedes Bit angibt, ob der Pixel heller ist als sein
// rechter Nachbar. Invariant gegenüber Helligkeit/WB-Änderungen (nur Gradienten zählen) —
// ideal für Bracketing-Erkennung (siehe Nutzer-Wunsch: gleiche Szene, verschiedene Kelvin).
struct PerceptualHash {
    static func dHash(from image: CGImage) -> UInt64 {
        let w = 9, h = 8, n = w * h
        var gray = [UInt8](repeating: 0, count: n)
        guard let ctx = CGContext(
            data: &gray, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        var hash: UInt64 = 0
        var bit = 0
        for y in 0..<h {
            for x in 0..<(w - 1) {
                if gray[y * w + x] > gray[y * w + x + 1] {
                    hash |= (1 << bit)
                }
                bit += 1
            }
        }
        return hash
    }

    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }
}
