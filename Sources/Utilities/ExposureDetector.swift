import Accelerate
import CoreGraphics

struct ExposureDetector {
    static let defaultShadowClipThreshold: Double = 0.06   // 6 % Pixel unter shadowClip
    static let defaultHighlightClipThreshold: Double = 0.06 // 6 % Pixel über highlightClip
    static let shadowClipLevel: UInt8 = 12
    static let highlightClipLevel: UInt8 = 243

    struct Result {
        let underRatio: Double  // Anteil dunkel-geclippter Pixel
        let overRatio: Double   // Anteil hell-geclippter Pixel
    }

    static func analyze(from image: CGImage) -> Result {
        let maxDim = 512
        let w0 = image.width, h0 = image.height
        guard w0 > 0, h0 > 0 else { return Result(underRatio: 0, overRatio: 0) }

        let scale = min(1.0, Double(maxDim) / Double(max(w0, h0)))
        let w = max(1, Int(Double(w0) * scale))
        let h = max(1, Int(Double(h0) * scale))
        let n = w * h

        var gray = [UInt8](repeating: 0, count: n)
        guard let ctx = CGContext(
            data: &gray, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return Result(underRatio: 0, overRatio: 0) }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        var histogram = [vImagePixelCount](repeating: 0, count: 256)
        gray.withUnsafeBufferPointer { ptr in
            var buf = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: ptr.baseAddress!),
                                    height: UInt(h), width: UInt(w), rowBytes: w)
            vImageHistogramCalculation_Planar8(&buf, &histogram, vImage_Flags(kvImageNoFlags))
        }

        let total = Double(n)
        let shadow = shadowClipLevel
        let highlight = highlightClipLevel

        let underCount = histogram[0..<Int(shadow)].reduce(0, +)
        let overCount = histogram[Int(highlight)+1..<256].reduce(0, +)

        return Result(
            underRatio: Double(underCount) / total,
            overRatio:  Double(overCount)  / total
        )
    }
}
