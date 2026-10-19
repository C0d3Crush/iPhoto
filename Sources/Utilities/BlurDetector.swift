import CoreGraphics

struct BlurDetector {
    static let defaultThreshold: Double = 120.0

    // Laplacian-Varianz via Rust-Core (iphoto_rs). CGContext-Render bleibt in Swift
    // weil CGColorSpaceCreateDeviceGray() Apple-Framework benötigt; die eigentliche
    // Rechenarbeit (3×3 Laplacian + Varianz) läuft in blur.rs.
    static func score(from image: CGImage) -> Double {
        let maxDim = 512
        let w0 = image.width, h0 = image.height
        guard w0 > 0, h0 > 0 else { return 0 }

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
        ) else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        return iphoto_blur_score(gray, UInt32(w), UInt32(h))
    }
}
