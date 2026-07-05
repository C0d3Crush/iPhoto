import Accelerate
import CoreGraphics
import Foundation

// Mertens Exposure Fusion mit Laplacian-Pyramid-Blending (Mertens et al. 2007/2009).
//
// IMPLEMENTIERUNGSDETAILS:
//
// 1. sRGB (gamma) Farbraum:
//    Bilder werden als gamma-kodiertes sRGB verarbeitet — genau wie im Original-Paper
//    und in OpenCV MergeMertens. Well-Exposedness σ=0.2 zentriert auf 0.5 (Mittlton).
//    In linearem Licht wäre σ=0.2 viel zu breit und würde helle Pixel bevorzugen.
//
// 2. Guided Image Filter für Gewichtskarten (He et al. 2013):
//    Rohe Gewichtskarten haben scharfe Sprünge an Helligkeitsgrenzen. Der Guided
//    Filter glättet sie edge-aware — Übergänge folgen Bildkanten statt eigene
//    Halo-Formen zu erzeugen. Implementiert als O(N) Box-Blur-Approximation.
//
// 3. Edge-Extended Laplacian (Randpixel):
//    Randpixel haben keinen Nachbarn auf einer Seite; wird mit Null aufgefüllt
//    statt Edge-Extension, entstehen künstliche Kanten am Bildrand.
//
// Kein EV-Wert nötig — der Algorithmus wählt automatisch die bestbelichteten Pixel.

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

        // Alle Bilder als Float32 in sRGB (gamma) rastern — Mertens-Paper-konform
        var rasters: [[Float]] = []
        for image in cgImages {
            if let px = rasterizeSRGB(image, width: W, height: H) {
                rasters.append(px)
            }
        }
        guard rasters.count >= 2 else { return nil }
        let N = rasters.count

        // Graustufenbilder — Guide für den Guided Filter
        let grayImages = rasters.map { computeGrayscale($0, n: W * H) }

        // Gewichtskarten (Kontrast × Sättigung × Well-Exposedness)
        var weights: [[Float]] = zip(rasters, grayImages).map {
            computeWeight($0, gray: $1, w: W, h: H, options: options)
        }

        // Guided Image Filter (He et al. 2013) — edge-aware Glättung der Gewichtskarten.
        // Radius skaliert mit Auflösung (≈1% der kürzeren Seite, mind. 10 px).
        // ε = 0.01: Kanten (hohe Varianz) → Gewicht folgt Bildkante. Flächen → geglättet.
        let gfRadius = max(10, min(W, H) / 100)
        let gfEps: Float = 0.01
        for k in 0..<N {
            weights[k] = guidedFilter(weights[k], guide: grayImages[k],
                                      w: W, h: H, radius: gfRadius, eps: gfEps)
        }

        // Normieren nach Guided Filter (GF verändert absolute Werte — danach neu normieren)
        normalizeWeights(&weights, n: W * H)

        // Output-Pyramide (3 Kanäle, L+1 Level) mit 0 initialisieren
        var outR: [[Float]] = sizes.map { [Float](repeating: 0, count: $0.w * $0.h) }
        var outG: [[Float]] = sizes.map { [Float](repeating: 0, count: $0.w * $0.h) }
        var outB: [[Float]] = sizes.map { [Float](repeating: 0, count: $0.w * $0.h) }

        for k in 0..<N {
            accumulateImage(rasters[k], weight: weights[k],
                            outR: &outR, outG: &outG, outB: &outB,
                            sizes: sizes, W: W, H: H, L: L)
        }

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

            let rNext = downsampleHalf(gaussianBlur(r, w: sw, h: sh), sw: sw, sh: sh, dw: dw, dh: dh)
            let gNext = downsampleHalf(gaussianBlur(g, w: sw, h: sh), sw: sw, sh: sh, dw: dw, dh: dh)
            let bNext = downsampleHalf(gaussianBlur(b, w: sw, h: sh), sw: sw, sh: sh, dw: dw, dh: dh)
            let wNext = downsampleHalf(gaussianBlur(w, w: sw, h: sh), sw: sw, sh: sh, dw: dw, dh: dh)

            let rUp = upsample(rNext, srcW: dw, srcH: dh, dstW: sw, dstH: sh)
            let gUp = upsample(gNext, srcW: dw, srcH: dh, dstW: sw, dstH: sh)
            let bUp = upsample(bNext, srcW: dw, srcH: dh, dstW: sw, dstH: sh)

            let pn = sw * sh
            for i in 0..<pn {
                outR[l][i] += w[i] * (r[i] - rUp[i])
                outG[l][i] += w[i] * (g[i] - gUp[i])
                outB[l][i] += w[i] * (b[i] - bUp[i])
            }

            r = rNext; g = gNext; b = bNext; w = wNext
        }

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

    private static func computeGrayscale(_ rgba: [Float], n: Int) -> [Float] {
        var gray = [Float](repeating: 0, count: n)
        for i in 0..<n {
            gray[i] = 0.2126 * rgba[i*4] + 0.7152 * rgba[i*4+1] + 0.0722 * rgba[i*4+2]
        }
        return gray
    }

    private static func computeWeight(_ rgba: [Float], gray: [Float], w: Int, h: Int,
                                       options: Options) -> [Float] {
        let n = w * h
        let contrast = absLaplacian(gray, w: w, h: h)

        var result = [Float](repeating: 0, count: n)
        let sig2: Float = 0.08  // 2 × 0.2² — kanonischer Mertens-Wert (für sRGB gamma)
        let expCenter: Float = 0.5  // Mittlton im gamma-kodierten sRGB

        for i in 0..<n {
            let r = rgba[i*4], g = rgba[i*4+1], b = rgba[i*4+2]
            let mu = (r + g + b) * (1.0/3.0)
            let sat = sqrt(((r-mu)*(r-mu) + (g-mu)*(g-mu) + (b-mu)*(b-mu)) * (1.0/3.0))

            let er = exp(-(r - expCenter)*(r - expCenter) / sig2)
            let eg = exp(-(g - expCenter)*(g - expCenter) / sig2)
            let eb = exp(-(b - expCenter)*(b - expCenter) / sig2)

            let c = max(contrast[i], 1e-6)
            let s = max(sat, 1e-6)
            let e = max(er * eg * eb, 1e-6)

            result[i] = (options.contrastWeight == 1 ? c : pow(c, options.contrastWeight))
                      * (options.saturationWeight == 1 ? s : pow(s, options.saturationWeight))
                      * (options.exposednessWeight == 1 ? e : pow(e, options.exposednessWeight))
        }
        return result
    }

    // Randpixel per Edge-Extension statt 0 — verhindert künstliche Kanten am Bildrand
    private static func absLaplacian(_ plane: [Float], w: Int, h: Int) -> [Float] {
        var out = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let c   = plane[y * w + x]
                let top = plane[max(y-1, 0) * w + x]
                let bot = plane[min(y+1, h-1) * w + x]
                let lft = plane[y * w + max(x-1, 0)]
                let rgt = plane[y * w + min(x+1, w-1)]
                out[y * w + x] = abs(top + bot + lft + rgt - 4 * c)
            }
        }
        return out
    }

    private static func normalizeWeights(_ maps: inout [[Float]], n: Int) {
        let N = maps.count
        let eps: Float = 1e-6
        var sumMap = [Float](repeating: eps, count: n)
        for k in 0..<N { for i in 0..<n { sumMap[i] += maps[k][i] } }
        for k in 0..<N { for i in 0..<n { maps[k][i] /= sumMap[i] } }
    }

    // MARK: - Guided Image Filter (He et al. 2013)
    //
    // Glättet Gewichtskarte p edge-aware anhand Graustufenbild I.
    // Lokales lineares Modell: q_i = a_k · I_i + b_k  ∀i ∈ window k
    //   a_k = Cov(I,p) / (Var(I) + ε)   — groß an Kanten, klein in Flächen
    //   b_k = mean(p) − a_k · mean(I)
    // Output q = mean(a) · I + mean(b)  — über alle Fenster gemittelt.
    // An Kanten (Var(I) >> ε): a ≈ 1, Gewicht folgt Bildkante → kein Halo.
    // In Flächen (Var(I) << ε): a ≈ 0, b ≈ mean(p) → geglättet.

    private static func guidedFilter(_ p: [Float], guide I: [Float], w: Int, h: Int,
                                      radius r: Int, eps: Float) -> [Float] {
        let n = w * h
        var II = [Float](repeating: 0, count: n)
        var IP = [Float](repeating: 0, count: n)
        for i in 0..<n { II[i] = I[i] * I[i]; IP[i] = I[i] * p[i] }

        let mI  = boxBlur(I,  w: w, h: h, r: r)
        let mP  = boxBlur(p,  w: w, h: h, r: r)
        let mII = boxBlur(II, w: w, h: h, r: r)
        let mIP = boxBlur(IP, w: w, h: h, r: r)

        var a = [Float](repeating: 0, count: n)
        var b = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let varI = mII[i] - mI[i] * mI[i]
            a[i] = (mIP[i] - mI[i] * mP[i]) / (varI + eps)
            b[i] = mP[i] - a[i] * mI[i]
        }

        let mA = boxBlur(a, w: w, h: h, r: r)
        let mB = boxBlur(b, w: w, h: h, r: r)

        var q = [Float](repeating: 0, count: n)
        for i in 0..<n { q[i] = max(0, mA[i] * I[i] + mB[i]) }
        return q
    }

    // O(N) Box-Blur: separable 1D-Faltung mit Einheitskern (äquivalent zu vImageBoxConvolve).
    // Zwei Passes (H + V) via vImageConvolve_PlanarF — Radius-unabhängige Laufzeit.
    private static func boxBlur(_ plane: [Float], w: Int, h: Int, r: Int) -> [Float] {
        let rowBytes = w * MemoryLayout<Float>.size
        let n = w * h
        let kLen = r * 2 + 1
        let kernel = [Float](repeating: 1.0 / Float(kLen), count: kLen)
        let ku32 = UInt32(kLen)
        var src = plane
        var tmp = [Float](repeating: 0, count: n)
        var dst = [Float](repeating: 0, count: n)

        // Horizontaler Pass: src → tmp
        src.withUnsafeMutableBufferPointer { sp in
            tmp.withUnsafeMutableBufferPointer { tp in
                var s = vImage_Buffer(data: UnsafeMutableRawPointer(sp.baseAddress!),
                                      height: UInt(h), width: UInt(w), rowBytes: rowBytes)
                var d = vImage_Buffer(data: UnsafeMutableRawPointer(tp.baseAddress!),
                                      height: UInt(h), width: UInt(w), rowBytes: rowBytes)
                kernel.withUnsafeBufferPointer { k in
                    vImageConvolve_PlanarF(&s, &d, nil, 0, 0, k.baseAddress!, 1, ku32, 0,
                                          vImage_Flags(kvImageEdgeExtend))
                }
            }
        }
        // Vertikaler Pass: tmp → dst
        tmp.withUnsafeMutableBufferPointer { sp in
            dst.withUnsafeMutableBufferPointer { dp in
                var s = vImage_Buffer(data: UnsafeMutableRawPointer(sp.baseAddress!),
                                      height: UInt(h), width: UInt(w), rowBytes: rowBytes)
                var d = vImage_Buffer(data: UnsafeMutableRawPointer(dp.baseAddress!),
                                      height: UInt(h), width: UInt(w), rowBytes: rowBytes)
                kernel.withUnsafeBufferPointer { k in
                    vImageConvolve_PlanarF(&s, &d, nil, 0, 0, k.baseAddress!, ku32, 1, 0,
                                          vImage_Flags(kvImageEdgeExtend))
                }
            }
        }
        return dst
    }

    // MARK: - Pyramidenoperationen

    private static func gaussianBlur(_ plane: [Float], w: Int, h: Int) -> [Float] {
        guard w >= 5 && h >= 5 else { return plane }
        let n = w * h
        let rowBytes = w * MemoryLayout<Float>.size
        let kernel: [Float] = [1/16.0, 4/16.0, 6/16.0, 4/16.0, 1/16.0]

        var buf0 = plane
        var buf1 = [Float](repeating: 0, count: n)

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
            let sy0 = min(y * 2,     sh - 1)
            let sy1 = min(y * 2 + 1, sh - 1)
            for x in 0..<dw {
                let sx0 = min(x * 2,     sw - 1)
                let sx1 = min(x * 2 + 1, sw - 1)
                dst[y * dw + x] = (plane[sy0 * sw + sx0] + plane[sy0 * sw + sx1]
                                 + plane[sy1 * sw + sx0] + plane[sy1 * sw + sx1]) * 0.25
            }
        }
        return dst
    }

    private static func upsample(_ plane: [Float], srcW: Int, srcH: Int, dstW: Int, dstH: Int) -> [Float] {
        let srcRowBytes = srcW * MemoryLayout<Float>.size
        let dstRowBytes = dstW * MemoryLayout<Float>.size
        var dst = [Float](repeating: 0, count: dstW * dstH)
        var src = plane
        src.withUnsafeMutableBufferPointer { sp in
            dst.withUnsafeMutableBufferPointer { dp in
                var s = vImage_Buffer(data: UnsafeMutableRawPointer(sp.baseAddress!),
                                      height: UInt(srcH), width: UInt(srcW), rowBytes: srcRowBytes)
                var d = vImage_Buffer(data: UnsafeMutableRawPointer(dp.baseAddress!),
                                      height: UInt(dstH), width: UInt(dstW), rowBytes: dstRowBytes)
                // Bilinear: kein Ringing/Halo wie beim Lanczos-Filter
                vImageScale_PlanarF(&s, &d, nil, vImage_Flags(kvImageNoFlags))
            }
        }
        return dst
    }

    // MARK: - Rastern & Ausgabe

    // sRGB (gamma) — Mertens-Paper-konform; Werte in [0,1] gamma-kodiert.
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
            // Daten sind bereits in sRGB (gamma) — direkt clampan, keine weitere Konvertierung
            rgba[i*4+0] = UInt8(max(0, min(255, r[i] * 255 + 0.5)))
            rgba[i*4+1] = UInt8(max(0, min(255, g[i] * 255 + 0.5)))
            rgba[i*4+2] = UInt8(max(0, min(255, b[i] * 255 + 0.5)))
            rgba[i*4+3] = 255
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width, height: height,
                       bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4,
                       space: space,
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
        let minDim = min(w, h)
        // Mindestens 3 Level, maximal 8; Grobstes Level ≥ 16px breit
        return min(8, max(3, Int(log2(Double(minDim) / 16.0))))
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

}
