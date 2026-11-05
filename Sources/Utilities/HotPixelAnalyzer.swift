import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import AppKit

struct HotPixelAnalyzer {

    // MARK: - Public API

    static func analyze(
        urls: [URL],
        progress: @escaping (String, Double) -> Void
    ) -> HotPixelResult? {

        guard !urls.isEmpty else { return nil }

        let ciContext = sharedSRGBCIContext
        var width = 0
        var height = 0
        var count = 0

        DispatchQueue.main.async { progress("Lese erstes Frame …", 0.0) }

        guard let first = decodeFrame(url: urls[0], ciContext: ciContext) else { return nil }

        width  = first.w
        height = first.h
        count  = width * height

        // Einzelframe-Statistik für Threshold (via Rust iphoto_mean_std)
        var singleFrameSum = [Float](repeating: 0.0, count: count)
        let firstCount = min(first.rgba.count / 4, count)
        first.rgba.withUnsafeBufferPointer { ptr in
            iphoto_hotpixel_accumulate(&singleFrameSum, ptr.baseAddress!, UInt32(firstCount))
        }
        var singleMean: Float = 0, singleStd: Float = 0
        iphoto_mean_std(singleFrameSum, UInt32(count), &singleMean, &singleStd)

        // --- Pass 2: mean-stack akkumulieren (Rust, rayon-parallel pro Frame) ---
        var sum = [Float](repeating: 0.0, count: count)
        first.rgba.withUnsafeBufferPointer { ptr in
            iphoto_hotpixel_accumulate(&sum, ptr.baseAddress!, UInt32(firstCount))
        }

        for (idx, url) in urls.enumerated().dropFirst() {
            let pct = Double(idx) / Double(urls.count)
            DispatchQueue.main.async { progress("Frame \(idx+1)/\(urls.count) …", pct * 0.7) }

            if let frame = decodeFrame(url: url, ciContext: ciContext) {
                let n = min(frame.rgba.count / 4, count)
                frame.rgba.withUnsafeBufferPointer { ptr in
                    iphoto_hotpixel_accumulate(&sum, ptr.baseAddress!, UInt32(n))
                }
            }
        }

        let frameCount = urls.count
        var meanFrame = sum.map { $0 / Float(frameCount) }

        let threshold = singleMean + 5.0 * singleStd

        DispatchQueue.main.async { progress("Suche Hot Pixel …", 0.75) }

        // --- Hot-Pixel-Suche via Rust ---
        var hotCount: UInt32 = 0
        let hotPixels: [(x: Int, y: Int, value: Float)]
        if let ptr = meanFrame.withUnsafeMutableBufferPointer({ buf in
            iphoto_hotpixel_find(buf.baseAddress!, UInt32(count), UInt32(width),
                                  threshold, &hotCount)
        }) {
            hotPixels = (0..<Int(hotCount)).map { i in
                let hp = ptr[i]
                return (x: Int(hp.x), y: Int(hp.y), value: hp.value)
            }
            iphoto_hotpixel_free(ptr, hotCount)
        } else {
            hotPixels = []
        }

        // --- Cluster-Grid (20×20) ---
        let gridCols = 20, gridRows = 20
        var clusterGrid = [[Int]](repeating: [Int](repeating: 0, count: gridCols), count: gridRows)
        for hp in hotPixels {
            let col = min(Int(Double(hp.x) / Double(width)  * Double(gridCols)), gridCols - 1)
            let row = min(Int(Double(hp.y) / Double(height) * Double(gridRows)), gridRows - 1)
            clusterGrid[row][col] += 1
        }

        // --- Sample Distribution (max 50k Werte aus meanFrame) ---
        let sample: [Float]
        if count <= 50_000 {
            sample = meanFrame
        } else {
            let step = count / 50_000
            var s: [Float] = []
            s.reserveCapacity(50_000)
            var i = 0
            while i < count { s.append(meanFrame[i]); i += step }
            sample = s
        }

        DispatchQueue.main.async { progress("Fertig", 1.0) }

        let (grade, gradeLabel) = HotPixelResult.severity(hotPixels.count)
        return HotPixelResult(
            frameCount:         frameCount,
            sensorWidth:        width,
            sensorHeight:       height,
            hotPixels:          hotPixels,
            hotCount:           hotPixels.count,
            threshold:          threshold,
            darkMean:           singleMean,
            darkStd:            singleStd,
            grade:              grade,
            gradeLabel:         gradeLabel,
            clusterGrid:        clusterGrid,
            sampleDistribution: sample
        )
    }

    // MARK: - Private helpers

    // Gibt RGBA-U8-Rohdaten zurück — CGContext bleibt in Swift (Apple-Framework).
    // Rec.709-Luminanz und Akkumulation übernimmt Rust (iphoto_hotpixel_accumulate).
    private static func decodeFrame(url: URL, ciContext: CIContext) -> (rgba: [UInt8], w: Int, h: Int)? {
        var ciImage: CIImage?

        let ext = url.pathExtension.lowercased()
        let rawExtensions: Set<String> = ["raf","cr2","cr3","nef","arw","dng","orf","rw2",
                                          "nrw","pef","srw","erf","kdc","dcr","raw","rwl",
                                          "mrw","3fr","mef","iiq","x3f","srf","sr2"]

        if rawExtensions.contains(ext) {
            if let filter = CIFilter(imageURL: url, options: nil) {
                let keys = filter.inputKeys
                if keys.contains("inputAllowDraftMode")  { filter.setValue(true,       forKey: "inputAllowDraftMode") }
                if keys.contains("inputScaleFactor")     { filter.setValue(Float(0.25),forKey: "inputScaleFactor") }
                ciImage = filter.outputImage
            }
        }

        if ciImage == nil {
            let skipImageIO = (ext == "raf") && {
                if #available(macOS 12.0, *) { return false } else { return true }
            }()
            if !skipImageIO {
                let opts = [kCGImageSourceShouldCache: false] as CFDictionary
                if let src = CGImageSourceCreateWithURL(url as CFURL, opts),
                   let cg  = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                    ciImage = CIImage(cgImage: cg)
                }
            }
        }

        if let ci = ciImage,
           let cg = ciContext.createCGImage(ci, from: ci.extent) {
            return pixelsFromCGImage(cg)
        }

        if let cg = try? RAWImageDecoder.decode(url: url) {
            return pixelsFromCGImage(cg)
        }

        return nil
    }

    private static func pixelsFromCGImage(_ cgImg: CGImage) -> (rgba: [UInt8], w: Int, h: Int)? {
        let w = cgImg.width, h = cgImg.height
        guard w > 0, h > 0 else { return nil }
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &rgba, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (rgba, w, h)
    }
}
