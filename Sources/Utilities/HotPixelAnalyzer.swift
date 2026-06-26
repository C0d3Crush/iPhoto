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

        // --- Pass 1: decode first frame to get dimensions and single-frame noise ---
        DispatchQueue.main.async { progress("Lese erstes Frame …", 0.0) }

        guard let firstPixels = decodeFrame(url: urls[0], ciContext: ciContext),
              let (fw, fh) = frameDimensions(url: urls[0], ciContext: ciContext)
        else { return nil }

        width  = fw
        height = fh
        let count = width * height

        // single-frame mean & std (used as global noise estimate)
        let (singleMean, singleStd) = meanAndStd(firstPixels)

        // --- Pass 2: accumulate mean stack ---
        var sum = [Double](repeating: 0.0, count: count)

        for (idx, url) in urls.enumerated() {
            let pct = Double(idx) / Double(urls.count)
            DispatchQueue.main.async { progress("Frame \(idx+1)/\(urls.count) …", pct * 0.7) }

            if let pixels = decodeFrame(url: url, ciContext: ciContext) {
                let n = min(pixels.count, count)
                for i in 0..<n { sum[i] += Double(pixels[i]) }
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

    private static func frameDimensions(url: URL, ciContext: CIContext) -> (Int, Int)? {
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            return (img.width, img.height)
        }
        return nil
    }

    /// Decode one image file into a [Float] array of 16-bit grayscale values (0…65535).
    private static func decodeFrame(url: URL, ciContext: CIContext) -> [Float]? {
        // Try CIFilter for RAW first (with draft mode for speed)
        var ciImage: CIImage? = nil
        let ext = url.pathExtension.lowercased()
        let rawExtensions = ["raf","cr2","cr3","nef","arw","dng","orf","rw2","nrw","pef","srw","erf","kdc","dcr","raw","rwl","mrw","3fr","mef","iiq","x3f","srf","sr2"]

        if rawExtensions.contains(ext) {
            let filterOptions: [CIRAWFilterOption: Any] = [
                CIRAWFilterOption.allowDraftMode: true
            ]
            if let filter = CIFilter(imageURL: url, options: filterOptions) {
                ciImage = filter.outputImage
            }
        }

        // Fallback: ImageIO
        if ciImage == nil {
            let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
            if let src = CGImageSourceCreateWithURL(url as CFURL, srcOpts as CFDictionary),
               let cgImg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                ciImage = CIImage(cgImage: cgImg)
            }
        }

        guard let ci = ciImage else { return nil }

        let w = Int(ci.extent.width)
        let h = Int(ci.extent.height)
        guard w > 0, h > 0 else { return nil }

        // Draw into 16-bit grayscale CGContext
        guard let ctx = CGContext(
            data:           nil,
            width:          w,
            height:         h,
            bitsPerComponent: 16,
            bytesPerRow:    w * 2,
            space:          CGColorSpaceCreateDeviceGray(),
            bitmapInfo:     CGImageAlphaInfo.none.rawValue | CGBitmapInfo.byteOrder16Big.rawValue
        ) else { return nil }

        guard let cgImg = ciContext.createCGImage(ci, from: ci.extent) else { return nil }
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))

        guard let dataPtr = ctx.data else { return nil }
        let pixelCount = w * h
        let rawPtr = dataPtr.bindMemory(to: UInt16.self, capacity: pixelCount)
        var result = [Float](repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            // Big-endian UInt16 → swap bytes → normalize to 0…65535
            let raw = rawPtr[i]
            let swapped = (raw >> 8) | (raw << 8)
            result[i] = Float(swapped)
        }
        return result
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
