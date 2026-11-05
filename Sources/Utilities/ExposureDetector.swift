import CoreGraphics

struct ExposureDetector {
    static let defaultShadowClipThreshold: Double = 0.06
    static let defaultHighlightClipThreshold: Double = 0.06
    static let shadowClipLevel: UInt8 = 12
    static let highlightClipLevel: UInt8 = 243

    struct Result {
        let underRatio: Double
        let overRatio: Double
    }

    // Histogramm-Clipping via Rust-Core (iphoto_rs). CGContext-Render bleibt in Swift;
    // Histogramm-Akkumulation und Ratio-Berechnung laufen in exposure.rs.
    static func analyze(from image: CGImage) -> Result {
        let maxDim = 512
        let w0 = image.width, h0 = image.height
        guard w0 > 0, h0 > 0 else { return Result(underRatio: 0, overRatio: 0) }

        let scale = min(1.0, Double(maxDim) / Double(max(w0, h0)))
        let w = max(1, Int(Double(w0) * scale))
        let h = max(1, Int(Double(h0) * scale))

        var gray = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(
            data: &gray, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return Result(underRatio: 0, overRatio: 0) }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        var under: Double = 0
        var over: Double = 0
        iphoto_exposure_analyze(gray, UInt32(w), UInt32(h),
                                shadowClipLevel, highlightClipLevel,
                                &under, &over)
        return Result(underRatio: under, overRatio: over)
    }
}
