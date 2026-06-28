import CoreGraphics
import AppKit
import Accelerate

final class AnalysisEngine: ObservableObject {
    @Published var histogramImage: CGImage?
    @Published var waveformImage: CGImage?
    @Published var rgbParadeImage: CGImage?

    private var token: UUID = UUID()

    func clear() {
        token = UUID()
        histogramImage = nil
        waveformImage  = nil
        rgbParadeImage = nil
    }

    func analyze(_ source: CGImage) {
        let currentToken = UUID()
        token = currentToken

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let t0 = Date()
            let scopeW = 256
            let aspect = CGFloat(source.height) / max(1, CGFloat(source.width))
            let scopeH = max(1, min(200, Int(CGFloat(scopeW) * aspect)))

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapFlags = CGImageAlphaInfo.premultipliedLast.rawValue

            var scaled = [UInt8](repeating: 0, count: scopeW * scopeH * 4)
            guard let ctx = CGContext(data: &scaled, width: scopeW, height: scopeH,
                                      bitsPerComponent: 8, bytesPerRow: scopeW * 4,
                                      space: colorSpace, bitmapInfo: bitmapFlags) else { return }
            ctx.draw(source, in: CGRect(x: 0, y: 0, width: scopeW, height: scopeH))

            // vImage SIMD histogram for R/G/B channels
            var rHist = [vImagePixelCount](repeating: 0, count: 256)
            var gHist = [vImagePixelCount](repeating: 0, count: 256)
            var bHist = [vImagePixelCount](repeating: 0, count: 256)
            var aHist = [vImagePixelCount](repeating: 0, count: 256)
            scaled.withUnsafeMutableBytes { rawPtr in
                var vBuf = vImage_Buffer(data: rawPtr.baseAddress,
                                         height: vImagePixelCount(scopeH),
                                         width: vImagePixelCount(scopeW),
                                         rowBytes: scopeW * 4)
                rHist.withUnsafeMutableBufferPointer { rp in
                    gHist.withUnsafeMutableBufferPointer { gp in
                        bHist.withUnsafeMutableBufferPointer { bp in
                            aHist.withUnsafeMutableBufferPointer { ap in
                                var ptrs: [UnsafeMutablePointer<vImagePixelCount>?] = [
                                    rp.baseAddress, gp.baseAddress, bp.baseAddress, ap.baseAddress
                                ]
                                vImageHistogramCalculation_ARGB8888(&vBuf, &ptrs, 0)
                            }
                        }
                    }
                }
            }
            let rBins = rHist.map { Int($0) }
            let gBins = gHist.map { Int($0) }
            let bBins = bHist.map { Int($0) }

            // Per-pixel pass: luma histogram + waveform accumulation
            var lBins = [Int](repeating: 0, count: 256)
            let outH = 200
            var lumaAcc = [Float](repeating: 0, count: scopeW * outH)
            var rAcc    = [Float](repeating: 0, count: scopeW * outH)
            var gAcc    = [Float](repeating: 0, count: scopeW * outH)
            var bAcc    = [Float](repeating: 0, count: scopeW * outH)

            for row in 0..<scopeH {
                for col in 0..<scopeW {
                    let base = row * scopeW * 4 + col * 4
                    let r = Float(scaled[base])   / 255
                    let g = Float(scaled[base+1]) / 255
                    let b = Float(scaled[base+2]) / 255
                    let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                    lBins[min(255, Int(luma * 255))] += 1

                    func acc(_ v: Float, buf: inout [Float]) {
                        let y = min(outH - 1, Int((1 - v) * Float(outH - 1)))
                        buf[y * scopeW + col] += 1
                    }
                    acc(luma, buf: &lumaAcc)
                    acc(r,    buf: &rAcc)
                    acc(g,    buf: &gAcc)
                    acc(b,    buf: &bAcc)
                }
            }

            let tAnalysis = Date().timeIntervalSince(t0)
            let hist   = Self.renderHistogram(r: rBins, g: gBins, b: bBins, luma: lBins)
            let wave   = Self.renderScope(lumaAcc, w: scopeW, h: outH, cr: 1, cg: 1, cb: 1)
            let parade = Self.renderParade(r: rAcc, g: gAcc, b: bAcc, w: scopeW, h: outH)
            let tTotal = Date().timeIntervalSince(t0)
            Log.debug(String(format: "analyse: %.1f ms (pixel-pass), %.1f ms (gesamt inkl. render)",
                             tAnalysis * 1000, tTotal * 1000))

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.token == currentToken else { return }
                self.histogramImage = hist
                self.waveformImage  = wave
                self.rgbParadeImage = parade
            }
        }
    }

    // MARK: - Rendering

    private static func renderHistogram(r: [Int], g: [Int], b: [Int], luma: [Int]) -> CGImage? {
        let w = 256, h = 128
        let maxVal = max(1, [r, g, b, luma].flatMap { $0 }.max()!)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapFlags = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: colorSpace, bitmapInfo: bitmapFlags)
        else { return nil }

        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setBlendMode(CGBlendMode.screen)

        let channels: [(bins: [Int], red: CGFloat, green: CGFloat, blue: CGFloat)] = [
            (luma, 0.6, 0.6, 0.6),
            (r,    1,   0,   0  ),
            (g,    0,   1,   0  ),
            (b,    0,   0,   1  )
        ]
        for ch in channels {
            ctx.setFillColor(CGColor(red: ch.red, green: ch.green, blue: ch.blue, alpha: 0.85))
            let barW = CGFloat(w) / 256.0
            for i in 0..<256 {
                let barH = CGFloat(ch.bins[i]) / CGFloat(maxVal) * CGFloat(h)
                guard barH > 0 else { continue }
                ctx.fill(CGRect(x: CGFloat(i) * barW, y: 0, width: barW, height: barH))
            }
        }
        return ctx.makeImage()
    }

    private static func renderScope(_ acc: [Float], w: Int, h: Int,
                                    cr: Float, cg: Float, cb: Float) -> CGImage? {
        let maxVal = acc.max() ?? 1
        guard maxVal > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) {
            let v = min(1.0, acc[i] / maxVal * 5.0)
            let base = i * 4
            pixels[base]   = UInt8(cr * v * 255)
            pixels[base+1] = UInt8(cg * v * 255)
            pixels[base+2] = UInt8(cb * v * 255)
            pixels[base+3] = 255
        }
        return makeCGImage(pixels: pixels, width: w, height: h)
    }

    private static func renderParade(r: [Float], g: [Float], b: [Float], w: Int, h: Int) -> CGImage? {
        let gapH   = 3
        let outH   = h * 3 + gapH * 2
        let maxVal = max(1.0, [r, g, b].flatMap { $0 }.max()!)
        var pixels = [UInt8](repeating: 0, count: w * outH * 4)

        let channels: [(acc: [Float], cr: Float, cg: Float, cb: Float, yOff: Int)] = [
            (r, 1, 0, 0, 0),
            (g, 0, 1, 0, h + gapH),
            (b, 0, 0, 1, (h + gapH) * 2)
        ]
        for ch in channels {
            for row in 0..<h {
                for col in 0..<w {
                    let v = min(1.0, ch.acc[row * w + col] / maxVal * 5.0)
                    guard v > 0 else { continue }
                    let base = ((ch.yOff + row) * w + col) * 4
                    pixels[base]   = UInt8(ch.cr * v * 255)
                    pixels[base+1] = UInt8(ch.cg * v * 255)
                    pixels[base+2] = UInt8(ch.cb * v * 255)
                    pixels[base+3] = 255
                }
            }
        }
        return makeCGImage(pixels: pixels, width: w, height: outH)
    }

    private static func makeCGImage(pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo,
                       provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }
}
