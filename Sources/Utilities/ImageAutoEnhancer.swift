import CoreImage
import CoreGraphics
import AppKit

struct AutoLightResult {
    let exposure: Double
    let brightness: Double
    let contrast: Double
}

struct AutoColorResult {
    let saturation: Double
    let vibrance: Double
}

enum ImageAutoEnhancer {

    // MARK: - Public API

    static func analyzeLight(_ cgImage: CGImage) -> AutoLightResult {
        guard let (avgR, avgG, avgB, spread) = sampleImage(cgImage) else {
            return AutoLightResult(exposure: 0, brightness: 0, contrast: 1)
        }
        let lum = 0.2126 * avgR + 0.7152 * avgG + 0.0722 * avgB
        let ev  = lum > 0.02 ? log2(0.42 / lum) : 0.0
        let exposure = max(-2.0, min(2.0, ev))
        // Contrast: flat images (small tonal spread) get a gentle boost
        let contrast = spread < 0.45 ? min(1.5, 1.0 + (0.45 - spread) * 0.6) : 1.0
        return AutoLightResult(exposure: exposure.rounded(to: 2),
                               brightness: 0,
                               contrast: contrast.rounded(to: 2))
    }

    static func analyzeColor(_ cgImage: CGImage) -> AutoColorResult {
        guard let (r, g, b, _) = sampleImage(cgImage) else {
            return AutoColorResult(saturation: 1, vibrance: 0)
        }
        let (_, s, _) = rgbToHSB(r: r, g: g, b: b)
        // Vibrance lifts desaturated images without blowing already-saturated ones
        let vibrance = s < 0.35 ? min(0.5, (0.35 - s) * 1.5) : 0.0
        let saturation: Double = s < 0.15 ? 1.1 : 1.0
        return AutoColorResult(saturation: saturation.rounded(to: 2),
                               vibrance: vibrance.rounded(to: 2))
    }

    // MARK: - Private helpers

    // Returns (avgR, avgG, avgB, tonalSpread) by rendering a 32×32 downscale.
    // The spread is the difference between p90 and p10 luminance across the 32×32 sample.
    private static func sampleImage(_ cgImage: CGImage) -> (Double, Double, Double, Double)? {
        let size = 32
        let space = CGColorSpaceCreateDeviceRGB()
        let bmpInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: size, height: size,
                                  bitsPerComponent: 8, bytesPerRow: size * 4,
                                  space: space, bitmapInfo: bmpInfo) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = ctx.data else { return nil }
        let buf = data.bindMemory(to: UInt8.self, capacity: size * size * 4)

        var totalR = 0.0, totalG = 0.0, totalB = 0.0
        var luminances = [Double]()
        luminances.reserveCapacity(size * size)
        for i in 0..<(size * size) {
            let r = Double(buf[i * 4])     / 255
            let g = Double(buf[i * 4 + 1]) / 255
            let b = Double(buf[i * 4 + 2]) / 255
            totalR += r; totalG += g; totalB += b
            luminances.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
        }
        let n = Double(size * size)
        let sorted = luminances.sorted()
        let p10 = sorted[Int(n * 0.10)]
        let p90 = sorted[Int(n * 0.90)]
        return (totalR / n, totalG / n, totalB / n, p90 - p10)
    }

    private static func rgbToHSB(r: Double, g: Double, b: Double) -> (h: Double, s: Double, b: Double) {
        let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
        let s = maxC > 0 ? delta / maxC : 0
        return (0, s, maxC)
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (self * f).rounded() / f
    }
}
