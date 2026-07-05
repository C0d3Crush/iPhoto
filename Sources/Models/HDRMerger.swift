import Accelerate
import CoreGraphics
import Foundation

// Mertens Exposure Fusion mit Laplacian-Pyramid-Blending (Mertens et al. 2007/2009).
//
// Warum Laplacian-Pyramid statt einfacher Gewichtsmittelung:
// Ein per-Pixel gewichteter Durchschnitt im Ortsbereich erzeugt sichtbare Übergänge,
// weil die Niederfrequenz-Anteile verschiedener Belichtungen nicht übereinstimmen.
// Die Pyramid zerlegt jedes Bild in Frequenzbänder:
//   - Grobe Level (große Skala): Gewichtskarte wird viele Male geblurrt → Übergänge
//     erstrecken sich über viele Pixel → unsichtbar.
//   - Feine Level (kleine Skala): Laplacian enthält nur lokale Details, keine globale
//     Helligkeit → scharfes lokales Blending ohne Halos.
//
// Kein EV-Wert nötig — der Algorithmus wählt automatisch die bestbelichteten Pixel.
// Arbeitet in sRGB (Gamma), wie im Originalpaper spezifiziert.

struct HDRMerger {

    static let maxDimension = 4000

    struct Options {
        var contrastWeight: Float = 1.0
        var saturationWeight: Float = 1.0
        var exposednessWeight: Float = 1.0
    }

    static func merge(cgImages: [CGImage], options: Options = .init()) -> CGImage? {
        guard cgImages.count >= 2 else { return nil }
        guard let (W, H) = targetSize(for: cgImages) else { return nil }

        let L = pyramidLevels(w: W, h: H)
        let sizes = computeLevelSizes(w: W, h: H, L: L)

        // Alle Bilder als Float32-sRGB rastern
        var rasters: [[Float]] = []
        for image in cgImages {
            if let px = rasterizeSRGB(image, width: W, height: H) {
                rasters.append(px)
            }
        }
        guard rasters.count >= 2 else { return nil }
        let N = rasters.count

        // Gewichtskarten berechnen und normieren
        var weights: [[Float]] = rasters.map { computeWeight($0, w: W, h: H, options: options) }
        normalizeWeights(&weights, n: W * H)

        // Output-Pyramide (3 Kanäle, L+1 Level) mit 0 initialisieren
        var outR: [[Float]] = sizes.map { [Float](repeating: 0, count: $0.w * $0.h) }
        var outG: [[Float]] = sizes.map { [Float](repeating: 0, count: $0.w * $0.h) }
        var outB: [[Float]] = sizes.map { [Float](repeating: 0, count: $0.w * $0.h) }

        // Jedes Bild einzeln akkumulieren
        for k in 0..<N {
            accumulateImage(rasters[k], weight: weights[k],
                            outR: &outR, outG: &outG, outB: &outB,
                            sizes: sizes, W: W, H: H, L: L)
        }

        // Aus der geblendeten Pyramide rekonstruieren
        let (resR, resG, resB) = reconstruct(outR: outR, outG: outG, outB: outB, sizes: sizes, L: L)
        return makeOutput(r: resR, g: resG, b: resB, width: W, height: H)
    }

    // MARK: - Kern-Akkumulation

    private static func accumulateImage(_ rgba: [Float], weight wt: [Float],
                                         outR: inout [[Float]], outG: inout [[Float]], outB: inout [[Float]],
                                         sizes: [LevelSize], W: Int, H: Int, L: Int) {
        let n0 = W * H
        var r = extractChannel(rgba, ch: 0, n: n0)
        var g = extractChannel(rgba, ch: 1, n: n0)
        var b = extractChannel(rgba, ch: 2, n: n0)
        var w = wt

        for l in 0..<L {
            let sw = sizes[l].w, sh = sizes[l].h
            let dw = sizes[l+1].w, dh = sizes[l+1].h

            // Gauß-Blur → Downsample für nächstes Level
            let rNext = downsampleHalf(gaussianBlur(r, w: sw, h: sh), sw: sw, sh: sh, dw: dw, dh: dh)
            let gNext = downsampleHalf(gaussianBlur(g, w: sw, h: sh), sw: sw, sh: sh, dw: dw, dh: dh)
            let bNext = downsampleHalf(gaussianBlur(b, w: sw, h: sh), sw: sw, sh: sh, dw: dw, dh: dh)
            let wNext = downsampleHalf(gaussianBlur(w, w: sw, h: sh), sw: sw, sh: sh, dw: dw, dh: dh)

            // Nächstes Level hochskalieren → Laplacian-Differenz
            let rUp = upsample(rNext, srcW: dw, srcH: dh, dstW: sw, dstH: sh)
            let gUp = upsample(gNext, srcW: dw, srcH: dh, dstW: sw, dstH: sh)
            let bUp = upsample(bNext, srcW: dw, srcH: dh, dstW: sw, dstH: sh)

            // LF[l] += weight * (aktuell − upsample(nächstes))
            let pn = sw * sh
            for i in 0..<pn {
                outR[l][i] += w[i] * (r[i] - rUp[i])
                outG[l][i] += w[i] * (g[i] - gUp[i])
                outB[l][i] += w[i] * (b[i] - bUp[i])
            }

            r = rNext; g = gNext; b = bNext; w = wNext
        }

        // Gröbstes Level: Gauß-Rest direkt akkumulieren
        let cn = sizes[L].w * sizes[L].h
        for i in 0..<cn {
            outR[L][i] += w[i] * r[i]
            outG[L][i] += w[i] * g[i]
            outB[L][i] += w[i] * b[i]
        }
    }

    // MARK: - Rekonstruktion

    private static func reconstruct(outR: [[Float]], outG: [[Float]], outB: [[Float]],
                                     sizes: [LevelSize], L: Int) -> ([Float], [Float], [Float]) {
        var resR = outR[L]
        var resG = outG[L]
        var resB = outB[L]

        for l in stride(from: L - 1, through: 0, by: -1) {
            let lw = sizes[l].w, lh = sizes[l].h
            let sw = sizes[l + 1].w, sh = sizes[l + 1].h
            let rUp = upsample(resR, srcW: sw, srcH: sh, dstW: lw, dstH: lh)
            let gUp = upsample(resG, srcW: sw, srcH: sh, dstW: lw, dstH: lh)
            let bUp = upsample(resB, srcW: sw, srcH: sh, dstW: lw, dstH: lh)
            let pn = lw * lh
            var newR = [Float](repeating: 0, count: pn)
            var newG = [Float](repeating: 0, count: pn)
            var newB = [Float](repeating: 0, count: pn)
            for i in 0..<pn {
                newR[i] = rUp[i] + outR[l][i]
                newG[i] = gUp[i] + outG[l][i]
                newB[i] = bUp[i] + outB[l][i]
            }
            resR = newR; resG = newG; resB = newB
        }
        return (resR, resG, resB)
    }

    // MARK: - Gewichtskarten

    private static func computeWeight(_ rgba: [Float], w: Int, h: Int, options: Options) -> [Float] {
        let n = w * h
        var gray = [Float](repeating: 0, count: n)
        for i in 0..<n {
            gray[i] = 0.2126 * rgba[i*4] + 0.7152 * rgba[i*4+1] + 0.0722 * rgba[i*4+2]
        }
        let contrast = absLaplacian(gray, w: w, h: h)

        var result = [Float](repeating: 0, count: n)
        let sig2: Float = 0.08  // 2 × 0.2² — kanonischer Mertens-Wert

        for i in 0..<n {
            let r = rgba[i*4], g = rgba[i*4+1], b = rgba[i*4+2]
            let mu = (r + g + b) * (1.0/3.0)

            // Sättigung: Standardabweichung der Kanäle
            let sat = sqrt(((r-mu)*(r-mu) + (g-mu)*(g-mu) + (b-mu)*(b-mu)) * (1.0/3.0))

            // Well-Exposedness: Gaußglocke pro Kanal, zentriert bei 0.5
            let er = exp(-(r-0.5)*(r-0.5)/sig2)
            let eg = exp(-(g-0.5)*(g-0.5)/sig2)
            let eb = exp(-(b-0.5)*(b-0.5)/sig2)

            let c = max(contrast[i], 1e-6)
            let s = max(sat, 1e-6)
            let e = max(er * eg * eb, 1e-6)

            result[i] = (options.contrastWeight == 1 ? c : pow(c, options.contrastWeight))
                      * (options.saturationWeight == 1 ? s : pow(s, options.saturationWeight))
                      * (options.exposednessWeight == 1 ? e : pow(e, options.exposednessWeight))
        }
        return result
    }

    private static func absLaplacian(_ plane: [Float], w: Int, h: Int) -> [Float] {
        var out = [Float](repeating: 0, count: w * h)
        for y in 1..<(h-1) {
            for x in 1..<(w-1) {
                let c = plane[y*w + x]
                out[y*w + x] = abs(plane[(y-1)*w+x] + plane[(y+1)*w+x]
                                 + plane[y*w+(x-1)] + plane[y*w+(x+1)] - 4*c)
            }
        }
        return out
    }

    private static func normalizeWeights(_ maps: inout [[Float]], n: Int) {
        let N = maps.count
        let eps: Float = 1e-6
        var sumMap = [Float](repeating: eps, count: n)
        for k in 0..<N {
            for i in 0..<n { sumMap[i] += maps[k][i] }
        }
        for k in 0..<N {
            for i in 0..<n { maps[k][i] /= sumMap[i] }
        }
    }

    // MARK: - Pyramidenoperationen (vImage)

    private static func gaussianBlur(_ plane: [Float], w: Int, h: Int) -> [Float] {
        guard w >= 5 && h >= 5 else { return plane }
        let n = w * h
        let rowBytes = w * MemoryLayout<Float>.size
        let kernel: [Float] = [1/16.0, 4/16.0, 6/16.0, 4/16.0, 1/16.0]

        var buf0 = plane                           // Ergebnis landet hier
        var buf1 = [Float](repeating: 0, count: n) // Zwischenpuffer

        // Horizontaler Pass: buf0 → buf1
        buf0.withUnsafeMutableBufferPointer { src in
            buf1.withUnsafeMutableBufferPointer { dst in
                var s = vImage_Buffer(data: UnsafeMutableRawPointer(src.baseAddress!),
                                      height: UInt(h), width: UInt(w), rowBytes: rowBytes)
                var d = vImage_Buffer(data: UnsafeMutableRawPointer(dst.baseAddress!),
                                      height: UInt(h), width: UInt(w), rowBytes: rowBytes)
                kernel.withUnsafeBufferPointer { k in
                    vImageConvolve_PlanarF(&s, &d, nil, 0, 0, k.baseAddress!, 1, 5, 0,
                                          vImage_Flags(kvImageEdgeExtend))
                }
            }
        }

        // Vertikaler Pass: buf1 → buf0
        buf1.withUnsafeMutableBufferPointer { src in
            buf0.withUnsafeMutableBufferPointer { dst in
                var s = vImage_Buffer(data: UnsafeMutableRawPointer(src.baseAddress!),
                                      height: UInt(h), width: UInt(w), rowBytes: rowBytes)
                var d = vImage_Buffer(data: UnsafeMutableRawPointer(dst.baseAddress!),
                                      height: UInt(h), width: UInt(w), rowBytes: rowBytes)
                kernel.withUnsafeBufferPointer { k in
                    vImageConvolve_PlanarF(&s, &d, nil, 0, 0, k.baseAddress!, 5, 1, 0,
                                          vImage_Flags(kvImageEdgeExtend))
                }
            }
        }
        return buf0
    }

    private static func downsampleHalf(_ plane: [Float], sw: Int, sh: Int, dw: Int, dh: Int) -> [Float] {
        var dst = [Float](repeating: 0, count: dw * dh)
        for y in 0..<dh {
            let sy = min(y * 2, sh - 1)
            for x in 0..<dw {
                dst[y * dw + x] = plane[sy * sw + min(x * 2, sw - 1)]
            }
        }
        return dst
    }

    private static func upsample(_ plane: [Float], srcW: Int, srcH: Int, dstW: Int, dstH: Int) -> [Float] {
        let srcRowBytes = srcW * MemoryLayout<Float>.size
        let dstRowBytes = dstW * MemoryLayout<Float>.size
        var dst = [Float](repeating: 0, count: dstW * dstH)
        var src = plane  // Kopie für mutablee vImage_Buffer-Anforderung
        src.withUnsafeMutableBufferPointer { sp in
            dst.withUnsafeMutableBufferPointer { dp in
                var s = vImage_Buffer(data: UnsafeMutableRawPointer(sp.baseAddress!),
                                      height: UInt(srcH), width: UInt(srcW), rowBytes: srcRowBytes)
                var d = vImage_Buffer(data: UnsafeMutableRawPointer(dp.baseAddress!),
                                      height: UInt(dstH), width: UInt(dstW), rowBytes: dstRowBytes)
                vImageScale_PlanarF(&s, &d, nil, vImage_Flags(kvImageHighQualityResampling))
            }
        }
        return dst
    }

    // MARK: - Rastern & Ausgabe

    // Float32 in sRGB (Gamma) — wie im Mertens-Originalpaper spezifiziert.
    private static func rasterizeSRGB(_ image: CGImage, width: Int, height: Int) -> [Float]? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let rowBytes = width * 4 * MemoryLayout<Float>.size
        var data = [Float](repeating: 0, count: height * width * 4)
        let info = CGBitmapInfo(rawValue:
            CGBitmapInfo.floatComponents.rawValue |
            CGImageAlphaInfo.noneSkipLast.rawValue |
            CGBitmapInfo.byteOrder32Little.rawValue)
        guard let ctx = CGContext(data: &data, width: width, height: height,
                                   bitsPerComponent: 32, bytesPerRow: rowBytes,
                                   space: space, bitmapInfo: info.rawValue)
        else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    private static func makeOutput(r: [Float], g: [Float], b: [Float], width: Int, height: Int) -> CGImage? {
        let n = width * height
        var rgba = [UInt8](repeating: 255, count: n * 4)
        for i in 0..<n {
            rgba[i*4+0] = clampByte(r[i])
            rgba[i*4+1] = clampByte(g[i])
            rgba[i*4+2] = clampByte(b[i])
            rgba[i*4+3] = 255
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: width, height: height,
                       bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .perceptual)
    }

    // MARK: - Hilfsfunktionen

    private struct LevelSize { let w: Int; let h: Int }

    private static func computeLevelSizes(w: Int, h: Int, L: Int) -> [LevelSize] {
        var sizes = [LevelSize]()
        var cw = w, ch = h
        for _ in 0...L {
            sizes.append(LevelSize(w: cw, h: ch))
            cw = max(1, cw / 2)
            ch = max(1, ch / 2)
        }
        return sizes
    }

    private static func pyramidLevels(w: Int, h: Int) -> Int {
        min(8, Int(log2(Double(min(w, h)))))
    }

    private static func targetSize(for images: [CGImage]) -> (Int, Int)? {
        guard let first = images.first else { return nil }
        var w = first.width, h = first.height
        let longest = max(w, h)
        if longest > maxDimension {
            let s = Double(maxDimension) / Double(longest)
            w = max(1, Int(Double(w) * s))
            h = max(1, Int(Double(h) * s))
        }
        return (w, h)
    }

    private static func extractChannel(_ rgba: [Float], ch: Int, n: Int) -> [Float] {
        var plane = [Float](repeating: 0, count: n)
        for i in 0..<n { plane[i] = rgba[i*4 + ch] }
        return plane
    }

    private static func clampByte(_ v: Float) -> UInt8 {
        UInt8(max(0, min(255, v * 255 + 0.5)))
    }
}
