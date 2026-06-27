import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import AppKit

struct HotPixelAnalyzer {

    // MARK: - Public API

    /// Analyze a set of dark-frame image files for hot pixels.
    /// Calls `progress` on the main thread with (statusText, 0…1).
    /// Returns nil if no frames could be decoded.
    static func analyze(
        urls: [URL],
        progress: @escaping (String, Double) -> Void
    ) -> HotPixelResult? {

        guard !urls.isEmpty else { return nil }

        let ciContext = CIContext(options: [.useSoftwareRenderer: false])
        var width = 0
        var height = 0
        var count = 0

        // --- Pass 1: decode first frame to get dimensions and single-frame noise ---
        DispatchQueue.main.async { progress("Lese erstes Frame …", 0.0) }

        guard let first = decodeFrame(url: urls[0], ciContext: ciContext) else { return nil }

        width  = first.w
        height = first.h
        count  = width * height

        let (singleMean, singleStd) = meanAndStd(first.pixels)

        // --- Pass 2: accumulate mean stack (memory-efficient: one frame at a time) ---
        var sum = [Double](repeating: 0.0, count: count)
        // Accumulate first frame (already decoded)
        let firstN = min(first.pixels.count, count)
        for i in 0..<firstN { sum[i] += Double(first.pixels[i]) }

        for (idx, url) in urls.enumerated().dropFirst() {
            let pct = Double(idx) / Double(urls.count)
            DispatchQueue.main.async { progress("Frame \(idx+1)/\(urls.count) …", pct * 0.7) }

            if let frame = decodeFrame(url: url, ciContext: ciContext) {
                let n = min(frame.pixels.count, count)
                for i in 0..<n { sum[i] += Double(frame.pixels[i]) }
            }
        }

        let frameCount = urls.count
        let meanFrame: [Float] = sum.map { Float($0 / Double(frameCount)) }

        // --- Threshold ---
        let threshold = singleMean + 5.0 * singleStd

        DispatchQueue.main.async { progress("Suche Hot Pixel …", 0.75) }

        // --- Find hot pixels ---
        var hotPixels: [(x: Int, y: Int, value: Float)] = []
        for i in 0..<count {
            if meanFrame[i] > threshold {
                let x = i % width
                let y = i / width
                hotPixels.append((x: x, y: y, value: meanFrame[i]))
            }
        }
        hotPixels.sort { $0.value > $1.value }

        // --- Cluster grid (20×20) ---
        let gridCols = 20, gridRows = 20
        var clusterGrid = [[Int]](repeating: [Int](repeating: 0, count: gridCols), count: gridRows)
        for hp in hotPixels {
            let col = min(Int(Double(hp.x) / Double(width)  * Double(gridCols)), gridCols - 1)
            let row = min(Int(Double(hp.y) / Double(height) * Double(gridRows)), gridRows - 1)
            clusterGrid[row][col] += 1
        }

        // --- Sample distribution (up to 50k values from mean frame) ---
        var sample: [Float] = []
        if count <= 50_000 {
            sample = meanFrame
        } else {
            let stride = count / 50_000
            var i = 0
            while i < count { sample.append(meanFrame[i]); i += stride }
        }

        DispatchQueue.main.async { progress("Fertig", 1.0) }

        let (grade, gradeLabel) = HotPixelResult.severity(hotPixels.count)
        return HotPixelResult(
            frameCount:        frameCount,
            sensorWidth:       width,
            sensorHeight:      height,
            hotPixels:         hotPixels,
            hotCount:          hotPixels.count,
            threshold:         threshold,
            darkMean:          singleMean,
            darkStd:           singleStd,
            grade:             grade,
            gradeLabel:        gradeLabel,
            clusterGrid:       clusterGrid,
            sampleDistribution: sample
        )
    }

    // MARK: - Private helpers

    /// Decode one image file into a (pixels, width, height) tuple.
    /// Pixels are Float values in 0…65535 (linearised 16-bit grayscale).
    private static func decodeFrame(url: URL, ciContext: CIContext) -> (pixels: [Float], w: Int, h: Int)? {
        var ciImage: CIImage?

        let ext = url.pathExtension.lowercased()
        let rawExtensions: Set<String> = ["raf","cr2","cr3","nef","arw","dng","orf","rw2",
                                          "nrw","pef","srw","erf","kdc","dcr","raw","rwl",
                                          "mrw","3fr","mef","iiq","x3f","srf","sr2"]

        if rawExtensions.contains(ext) {
            // Use nil options + setValue — same pattern as ImageViewModel, avoids
            // CIRAWFilterOption dictionary issues on macOS 11.
            // Guard inputKeys before setValue: unknown keys throw NSUnknownKeyException on macOS 11.
            if let filter = CIFilter(imageURL: url, options: nil) {
                let keys = filter.inputKeys
                if keys.contains("inputAllowDraftMode") {
                    filter.setValue(true, forKey: "inputAllowDraftMode")
                }
                if keys.contains("inputScaleFactor") {
                    filter.setValue(Float(0.25), forKey: "inputScaleFactor")
                }
                ciImage = filter.outputImage
            }
        }

        // Fallback: standard ImageIO (JPEG, TIFF, PNG, …)
        if ciImage == nil {
            let opts = [kCGImageSourceShouldCache: false] as CFDictionary
            if let src = CGImageSourceCreateWithURL(url as CFURL, opts),
               let cg  = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                ciImage = CIImage(cgImage: cg)
            }
        }

        // CIFilter / CGImageSource path
        if let ci = ciImage {
            if let result = pixelsFromCIImage(ci, ciContext: ciContext) { return result }
        }

        // Final fallback: RAWImageDecoder (handles RAF via embedded JPEG on macOS 11)
        if let cgImg = try? RAWImageDecoder.decode(url: url) {
            return pixelsFromCGImage(cgImg)
        }

        return nil
    }

    private static func pixelsFromCIImage(_ ci: CIImage, ciContext: CIContext) -> (pixels: [Float], w: Int, h: Int)? {
        let w = Int(ci.extent.width)
        let h = Int(ci.extent.height)
        guard w > 0, h > 0, let cgImg = ciContext.createCGImage(ci, from: ci.extent) else { return nil }
        return pixelsFromCGImage(cgImg)
    }

    private static func pixelsFromCGImage(_ cgImg: CGImage) -> (pixels: [Float], w: Int, h: Int)? {
        let w = cgImg.width
        let h = cgImg.height
        guard w > 0, h > 0 else { return nil }

        // Render to 8-bit RGBA, then extract luminance.
        // (More compatible than 16-bit gray on macOS 11 — still fine for outlier detection.)
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data:             &rgba,
            width:            w,
            height:           h,
            bitsPerComponent: 8,
            bytesPerRow:      w * 4,
            space:            CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:       CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Rec.709 luminance, scaled to 0…65535 to match the Python script's ADU range.
        let pixels: [Float] = stride(from: 0, to: rgba.count, by: 4).map { i in
            let r = Float(rgba[i])
            let g = Float(rgba[i+1])
            let b = Float(rgba[i+2])
            return (0.2126 * r + 0.7152 * g + 0.0722 * b) * 257.0  // 255→65535
        }
        return (pixels, w, h)
    }

    /// Compute mean and standard deviation of a float array.
    private static func meanAndStd(_ values: [Float]) -> (Float, Float) {
        guard !values.isEmpty else { return (0, 0) }
        let n = Float(values.count)
        var sum: Float = 0
        for v in values { sum += v }
        let mean = sum / n
        var variance: Float = 0
        for v in values { let d = v - mean; variance += d * d }
        variance /= n
        return (mean, sqrt(variance))
    }
}
