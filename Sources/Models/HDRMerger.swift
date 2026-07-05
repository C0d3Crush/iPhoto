import CoreGraphics
import Foundation

// Mertens Exposure Fusion: Belichtungsreihen werden pixelweise nach "gut belichtet"-Gewicht
// zusammengeführt. Ergebnis ist ein LDR-Bild mit maximalem Detailerhalt über alle Lichter.
struct HDRMerger {

    static let maxDimension = 4000

    struct Options {
        // Breite der Gaußglocke um mittlere Helligkeit (0.5).
        // Kleinere Werte = enger, bevorzugt exakt mittelgrau belichtete Pixel.
        var sigma: Float = 0.2
    }

    static func merge(cgImages: [CGImage], options: Options = Options()) -> CGImage? {
        guard cgImages.count >= 2 else { return nil }
        guard let (w, h) = targetSize(for: cgImages) else { return nil }

        let n = w * h
        var sumR = [Float](repeating: 0, count: n)
        var sumG = [Float](repeating: 0, count: n)
        var sumB = [Float](repeating: 0, count: n)
        var sumW = [Float](repeating: 0, count: n)

        let sigmaFactor = 2 * options.sigma * options.sigma

        for image in cgImages {
            guard let pixels = rasterize(image, width: w, height: h) else { continue }
            for i in 0..<n {
                let r = Float(pixels[i * 4 + 0]) / 255.0
                let g = Float(pixels[i * 4 + 1]) / 255.0
                let b = Float(pixels[i * 4 + 2]) / 255.0
                let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
                let diff = lum - 0.5
                let w = max(exp(-diff * diff / sigmaFactor), 1e-6)
                sumR[i] += r * w
                sumG[i] += g * w
                sumB[i] += b * w
                sumW[i] += w
            }
        }

        var output = [UInt8](repeating: 255, count: n * 4)
        for i in 0..<n {
            let wt = sumW[i]
            output[i * 4 + 0] = byte(sumR[i] / wt)
            output[i * 4 + 1] = byte(sumG[i] / wt)
            output[i * 4 + 2] = byte(sumB[i] / wt)
            output[i * 4 + 3] = 255
        }

        return makeCGImage(pixels: output, width: w, height: h)
    }

    // MARK: - Helpers

    private static func targetSize(for images: [CGImage]) -> (Int, Int)? {
        guard let first = images.first else { return nil }
        var w = first.width
        var h = first.height
        let longest = max(w, h)
        if longest > maxDimension {
            let scale = Double(maxDimension) / Double(longest)
            w = max(1, Int(Double(w) * scale))
            h = max(1, Int(Double(h) * scale))
        }
        return (w, h)
    }

    private static func rasterize(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        let stride = width * 4
        var data = [UInt8](repeating: 0, count: height * stride)
        guard let ctx = CGContext(
            data: &data,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: stride,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    private static func byte(_ v: Float) -> UInt8 {
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
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .perceptual
        )
    }
}
