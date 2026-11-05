import CoreGraphics

struct ExposureDetector {
    static let defaultShadowClipThreshold: Double = 0.06
    static let defaultHighlightClipThreshold: Double = 0.06
    static let shadowClipLevel: Int = 12
    static let highlightClipLevel: Int = 243

    struct Result {
        let underRatio: Double
        let overRatio: Double
    }

    // Canonical method: derives over/under ratios directly from a 256-bin luma histogram.
    // Consistent with what HistogramView displays — same bins, same thresholds.
    static func analyze(lumaHistogram bins: [Int]) -> Result {
        guard bins.count == 256 else { return Result(underRatio: 0, overRatio: 0) }
        let total = bins.reduce(0, +)
        guard total > 0 else { return Result(underRatio: 0, overRatio: 0) }
        let under = bins[0..<shadowClipLevel].reduce(0, +)
        let over  = bins[(highlightClipLevel + 1)..<256].reduce(0, +)
        return Result(underRatio: Double(under) / Double(total),
                      overRatio:  Double(over)  / Double(total))
    }

    // Convenience: renders image to RGBA, builds BT.709 luma histogram (identical to
    // AnalysisEngine/waveform.rs), then delegates to analyze(lumaHistogram:).
    static func analyze(from image: CGImage) -> Result {
        let maxDim = 256
        let w0 = image.width, h0 = image.height
        guard w0 > 0, h0 > 0 else { return Result(underRatio: 0, overRatio: 0) }
        let scale = min(1.0, Double(maxDim) / Double(max(w0, h0)))
        let w = max(1, Int(Double(w0) * scale))
        let h = max(1, Int(Double(h0) * scale))

        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &rgba, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Result(underRatio: 0, overRatio: 0) }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        // BT.709 luma — integer weights matching waveform.rs: (R·218 + G·732 + B·74 + 512) >> 10
        var bins = [Int](repeating: 0, count: 256)
        var i = 0
        while i < rgba.count {
            let r = UInt32(rgba[i]), g = UInt32(rgba[i+1]), b = UInt32(rgba[i+2])
            let y = Int((r * 218 + g * 732 + b * 74 + 512) >> 10)
            bins[min(y, 255)] += 1
            i += 4
        }
        return analyze(lumaHistogram: bins)
    }
}
