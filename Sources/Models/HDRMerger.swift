import CoreGraphics
import Foundation

// Exposure-normiertes HDR-Merge (physikalisch korrekt):
//
// 1. Bilder werden als Float32 in linearem sRGB gerendert (kein Gamma-Fehler)
// 2. Jedes Bild wird per EV-Offset auf eine gemeinsame Referenzbelichtung normiert
//    (pixel_ref = pixel_linear * 2^(-ev))
// 3. Gewicht = Gaußglocke auf die ORIGINAL-Helligkeit (vor EV-Scaling) → erkennt
//    gut belichtete Pixel; geclippte (>0.95) und zu dunkle (<0.02) Pixel werden verworfen
// 4. Gewichteter Durchschnitt in linearem Licht
// 5. Extended-Reinhard-Tone-Mapping mit Exposure-Kompensation → mittleres Grau bleibt
//    auf seinem Originalwert; Highlights werden sanft komprimiert
// 6. sRGB-Gamma-Kodierung für die Ausgabe

struct HDRMerger {

    static let maxDimension = 4000

    struct Options {
        // Breite der Gaußglocke (in linearem Licht, Mitte = 0.18 = fotographisches Mittelgrau).
        // Kleiner = nur perfekt belichtete Pixel; größer = mehr Bilder tragen bei.
        var sigma: Float = 0.25
    }

    // evOffsets[i] = EXIF ExposureBiasValue des i-ten Bildes (z.B. -2.0, 0.0, +2.0)
    static func merge(cgImages: [CGImage], evOffsets: [Double], options: Options = Options()) -> CGImage? {
        guard cgImages.count >= 2, cgImages.count == evOffsets.count else { return nil }
        guard let (w, h) = targetSize(for: cgImages) else { return nil }

        let n = w * h
        var accR = [Float](repeating: 0, count: n)
        var accG = [Float](repeating: 0, count: n)
        var accB = [Float](repeating: 0, count: n)
        var accW = [Float](repeating: 0, count: n)

        // Fallback-Akkumulator für Pixel, die in allen Bildern geclippt/zerdrückt sind
        var fbR = [Float](repeating: 0, count: n)
        var fbG = [Float](repeating: 0, count: n)
        var fbB = [Float](repeating: 0, count: n)
        var fbN = [Int](repeating: 0, count: n)

        let sig2 = 2 * options.sigma * options.sigma

        for (image, ev) in zip(cgImages, evOffsets) {
            guard let pixels = rasterizeLinear(image, width: w, height: h) else { continue }
            let evScale = Float(pow(2.0, -ev))  // normiert auf 0-EV-Referenz

            for i in 0..<n {
                let r = pixels[i * 4 + 0]
                let g = pixels[i * 4 + 1]
                let b = pixels[i * 4 + 2]
                let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b

                // Immer in Fallback speichern (normiert)
                fbR[i] += r * evScale
                fbG[i] += g * evScale
                fbB[i] += b * evScale
                fbN[i] += 1

                // Geclippte/zerdrückte Pixel bekommen kein Gewicht im Hauptakkumulator
                guard lum > 0.02 && lum < 0.95 else { continue }

                // Well-exposedness: Gaußglocke auf lineare Helligkeit (Mitte = 0.18)
                let diff = lum - 0.18
                let weight = exp(-diff * diff / sig2)

                accR[i] += r * evScale * weight
                accG[i] += g * evScale * weight
                accB[i] += b * evScale * weight
                accW[i] += weight
            }
        }

        // White-Point: maximaler sinnvoller Helligkeitswert nach EV-Normierung.
        // = 2^|minEV| (Highlight aus der dunkelsten Belichtung, z.B. 2^4 = 16 für -4EV)
        let maxAbsEV = evOffsets.map { abs($0) }.max() ?? 4.0
        let lWhite = Float(pow(2.0, maxAbsEV))

        // Exposure-Kompensation: Reinhard dunkelt Mitteltöne leicht ab.
        // Faktor 1/0.82 ≈ 1.22 stellt sicher, dass 0.18 linear nach Reinhard wieder 0.18 ergibt.
        let expComp: Float = 1.0 / 0.82

        var output = [UInt8](repeating: 255, count: n * 4)
        for i in 0..<n {
            let r: Float
            let g: Float
            let b: Float

            if accW[i] > 1e-6 {
                r = accR[i] / accW[i]
                g = accG[i] / accW[i]
                b = accB[i] / accW[i]
            } else if fbN[i] > 0 {
                // Kein gut belichteter Pixel in irgendeinem Bild → Fallback-Mittel
                let n = Float(fbN[i])
                r = fbR[i] / n
                g = fbG[i] / n
                b = fbB[i] / n
            } else {
                r = 0; g = 0; b = 0
            }

            // Extended Reinhard auf Luminanz (erhält Sättigung besser als per-Kanal)
            let lum = max(0.2126 * r + 0.7152 * g + 0.0722 * b, 1e-6)
            let lumIn = lum * expComp
            let lumOut = lumIn * (1 + lumIn / (lWhite * lWhite)) / (1 + lumIn)
            let scale = lumOut / lum

            output[i * 4 + 0] = toByte(toSRGB(r * scale))
            output[i * 4 + 1] = toByte(toSRGB(g * scale))
            output[i * 4 + 2] = toByte(toSRGB(b * scale))
            output[i * 4 + 3] = 255
        }

        return makeCGImage(pixels: output, width: w, height: h)
    }

    // MARK: - Helpers

    private static func targetSize(for images: [CGImage]) -> (Int, Int)? {
        guard let first = images.first else { return nil }
        var w = first.width, h = first.height
        let longest = max(w, h)
        if longest > maxDimension {
            let s = Double(maxDimension) / Double(longest)
            w = max(1, Int(Double(w) * s))
            h = max(1, Int(Double(h) * s))
        }
        return (w, h)
    }

    // Rendert als Float32 RGBA in linearem sRGB (kein Gamma).
    private static func rasterizeLinear(_ image: CGImage, width: Int, height: Int) -> [Float]? {
        guard let linearSpace = CGColorSpace(name: CGColorSpace.linearSRGB) else { return nil }
        let stride = width * 4 * MemoryLayout<Float>.size
        var data = [Float](repeating: 0, count: height * width * 4)
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGBitmapInfo.floatComponents.rawValue |
            CGImageAlphaInfo.noneSkipLast.rawValue |
            CGBitmapInfo.byteOrder32Little.rawValue
        )
        guard let ctx = CGContext(
            data: &data,
            width: width, height: height,
            bitsPerComponent: 32, bytesPerRow: stride,
            space: linearSpace, bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    // sRGB-Gamma-Kodierung (IEC 61966-2-1)
    private static func toSRGB(_ linear: Float) -> Float {
        let c = max(0, linear)
        return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0 / 2.4) - 0.055
    }

    private static func toByte(_ v: Float) -> UInt8 {
        UInt8(max(0, min(255, v * 255 + 0.5)))
    }

    private static func makeCGImage(pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        let stride = width * 4
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: stride,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil,
            shouldInterpolate: true, intent: .perceptual
        )
    }
}
