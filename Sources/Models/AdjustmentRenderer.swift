import AppKit
import CoreImage

/// Wiederverwendbare Anpassungs-Pipeline — von der Vorschau (ImageViewModel)
/// und vom Export (volle Auflösung) gemeinsam genutzt.
enum AdjustmentRenderer {

    static let context: CIContext = {
        var opts: [CIContextOption: Any] = [.useSoftwareRenderer: false]
        if let linearSRGB = CGColorSpace(name: CGColorSpace.linearSRGB) {
            opts[.workingColorSpace] = linearSRGB
        }
        opts[.workingFormat] = CIFormat.RGBAh
        return CIContext(options: opts)
    }()

    struct RAWResult {
        let image: CIImage
        let exposureApplied: Bool
        let wbApplied: Bool
    }

    // MARK: - Komplette Pipeline

    /// Wendet alle Filterstufen (ohne RAW-Dekodierung) auf ein CIImage an.
    static func pipeline(_ input: CIImage, snap: AdjustmentState,
                         exposureApplied: Bool, wbApplied: Bool) -> CIImage {
        var ci = input
        ci = applyLensCorrections(ci, snap: snap)
        ci = applyToneAndColor(ci, snap: snap, exposureApplied: exposureApplied, wbApplied: wbApplied)
        ci = applyOkLabAdjustments(ci, snap: snap)
        ci = applyNoiseAndSharpening(ci, snap: snap)
        ci = applyDetailAndHaze(ci, snap: snap)
        ci = applyRGBCurvesLUT(ci, snap: snap)
        if !snap.localAdjustments.isEmpty { ci = applyLocalAdjustments(snap.localAdjustments, to: ci) }
        ci = applyGeometryAndCrop(ci, snap: snap)
        return ci
    }

    /// Rendert ein Dokument mit Anpassungen in voller Auflösung (für Export).
    static func renderForExport(document: ImageDocument, adjustments snap: AdjustmentState) throws -> CGImage {
        var ci: CIImage
        var exposureApplied = false
        var wbApplied = false

        if document.isRAW,
           let raw = rawPipeline(url: document.url, snap: snap, scale: 1.0, draftMode: false) {
            ci = raw.image
            exposureApplied = raw.exposureApplied
            wbApplied = raw.wbApplied
        } else {
            let cg: CGImage
            if let cached = document.cgImage {
                cg = cached
            } else {
                cg = try RAWImageDecoder.decode(url: document.url)
            }
            ci = CIImage(cgImage: cg)
        }

        ci = pipeline(ci, snap: snap, exposureApplied: exposureApplied, wbApplied: wbApplied)

        guard let out = context.createCGImage(ci, from: ci.extent) else {
            throw ExportError.cannotLoadImage(document.filename)
        }
        return out
    }

    // MARK: - RAW-Dekodierung mit Belichtung/Weißabgleich

    static func rawPipeline(url: URL, snap: AdjustmentState,
                            scale: Double, draftMode: Bool) -> RAWResult? {
        let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
        defer { stopAccess() }
        guard let rf = CIFilter(imageURL: accessURL, options: nil) else { return nil }

        let keys = rf.inputKeys
        if keys.contains(kCIInputEVKey as String) {
            rf.setValue(Float(snap.exposure), forKey: kCIInputEVKey)
        }
        if keys.contains("inputAllowDraftMode") {
            rf.setValue(draftMode, forKey: "inputAllowDraftMode")
        }
        if scale < 1.0, keys.contains("inputScaleFactor") {
            rf.setValue(Float(scale), forKey: "inputScaleFactor")
        }
        var wbApplied = false
        if snap.warmth != 0 || snap.tint != 0 {
            let kelvin  = Float(6500.0 - snap.warmth * 50.0)
            let tintVal = Float(-snap.tint * 3.0)
            if keys.contains("inputNeutralTemperature") { rf.setValue(kelvin,  forKey: "inputNeutralTemperature") }
            if keys.contains("inputNeutralTint")        { rf.setValue(tintVal, forKey: "inputNeutralTint") }
            wbApplied = true
        }
        guard let rawCI = rf.outputImage else { return nil }
        return RAWResult(image: rawCI, exposureApplied: true, wbApplied: wbApplied)
    }

    // MARK: - Pipeline-Stufen

    static func applyLensCorrections(_ ci: CIImage, snap: AdjustmentState) -> CIImage {
        var out = ci
        if snap.caAmount > 0, let k = LensFilters.caKernel,
           let result = k.apply(extent: out.extent, roiCallback: { _, r in r }, arguments: [out, Float(snap.caAmount)]) {
            out = result
        }
        if snap.distortion != 0, let k = LensFilters.distortKernel {
            let k1  = Float(-snap.distortion * 0.003)
            let ext = CIVector(cgRect: out.extent)
            if let result = k.apply(extent: out.extent,
                                    roiCallback: { _, r in r.insetBy(dx: -4, dy: -4) },
                                    image: out, arguments: [ext, k1]) {
                out = result.cropped(to: out.extent)
            }
        }
        return out
    }

    static func applyToneAndColor(_ ci: CIImage, snap: AdjustmentState,
                                  exposureApplied: Bool, wbApplied: Bool) -> CIImage {
        var out = ci
        if !exposureApplied, snap.exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(snap.exposure, forKey: kCIInputEVKey)
            if let r = f.outputImage { out = r }
        }
        if snap.brightness != 0 || snap.contrast != 1 || snap.saturation != 1,
           let f = CIFilter(name: "CIColorControls") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(snap.brightness, forKey: kCIInputBrightnessKey)
            f.setValue(snap.contrast,   forKey: kCIInputContrastKey)
            f.setValue(snap.saturation, forKey: kCIInputSaturationKey)
            if let r = f.outputImage { out = r }
        }
        if !wbApplied, snap.warmth != 0 || snap.tint != 0, let f = CIFilter(name: "CITemperatureAndTint") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            f.setValue(CIVector(x: CGFloat(6500 - snap.warmth * 50), y: CGFloat(-snap.tint * 3)),
                       forKey: "inputTargetNeutral")
            if let r = f.outputImage { out = r }
        }
        if snap.dehaze != 0, let f = CIFilter(name: "CIColorControls") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(-snap.dehaze * 0.05,      forKey: kCIInputBrightnessKey)
            f.setValue(1.0 + snap.dehaze * 0.25, forKey: kCIInputContrastKey)
            f.setValue(1.0,                      forKey: kCIInputSaturationKey)
            if let r = f.outputImage { out = r }
        }
        return out
    }

    static func applyNoiseAndSharpening(_ ci: CIImage, snap: AdjustmentState) -> CIImage {
        var out = ci
        if snap.lumaNoise > 0, let f = CIFilter(name: "CINoiseReduction") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(snap.lumaNoise * 0.001, forKey: "inputNoiseLevel")
            f.setValue(0.4, forKey: kCIInputSharpnessKey)
            if let r = f.outputImage { out = r }
        }
        if snap.colorNoise > 0, let blurF = CIFilter(name: "CIGaussianBlur") {
            blurF.setValue(out, forKey: kCIInputImageKey)
            blurF.setValue(snap.colorNoise * 0.25, forKey: kCIInputRadiusKey)
            if let blurred = blurF.outputImage?.cropped(to: out.extent),
               let blendF  = CIFilter(name: "CILuminosityBlendMode") {
                blendF.setValue(out,     forKey: kCIInputImageKey)
                blendF.setValue(blurred, forKey: kCIInputBackgroundImageKey)
                if let r = blendF.outputImage { out = r }
            }
        }
        if snap.sharpenAmount > 0, let f = CIFilter(name: "CIUnsharpMask") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(snap.sharpenRadius,         forKey: kCIInputRadiusKey)
            f.setValue(snap.sharpenAmount / 100.0, forKey: kCIInputIntensityKey)
            if let r = f.outputImage { out = r }
        }
        return out
    }

    static func applyDetailAndHaze(_ ci: CIImage, snap: AdjustmentState) -> CIImage {
        var out = ci
        if snap.clarity != 0, let f = CIFilter(name: "CIUnsharpMask") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(20.0, forKey: kCIInputRadiusKey)
            f.setValue(Swift.max(0, snap.clarity) * 2.0, forKey: kCIInputIntensityKey)
            if let r = f.outputImage { out = r }
        }
        if snap.texture != 0, let f = CIFilter(name: "CIUnsharpMask") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(4.0, forKey: kCIInputRadiusKey)
            f.setValue(Swift.max(0, snap.texture) * 2.5, forKey: kCIInputIntensityKey)
            if let r = f.outputImage { out = r }
        }
        return out
    }

    static func applyRGBCurvesLUT(_ ci: CIImage, snap: AdjustmentState) -> CIImage {
        var out = ci

        let curveDef = zip(snap.curvePoints, CurvesView.defaultPoints)
            .allSatisfy { abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001 }
        if !curveDef, let f = CIFilter(name: "CIToneCurve") {
            f.setValue(out, forKey: kCIInputImageKey)
            for (i, pt) in snap.curvePoints.enumerated() {
                f.setValue(CIVector(x: pt.x, y: pt.y), forKey: "inputPoint\(i)")
            }
            if let r = f.outputImage { out = r }
        }

        let rDef = isDefaultCurve(snap.curveR)
        let gDef = isDefaultCurve(snap.curveG)
        let bDef = isDefaultCurve(snap.curveB)
        guard !rDef || !gDef || !bDef else { return out }

        let lutR = CurvesView.evaluateSpline(snap.curveR)
        let lutG = CurvesView.evaluateSpline(snap.curveG)
        let lutB = CurvesView.evaluateSpline(snap.curveB)
        let size = 32
        var cubeData = [Float]()
        cubeData.reserveCapacity(size * size * size * 4)
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    cubeData.append(Float(lutR[Swift.min(255, r * 255 / (size - 1))]))
                    cubeData.append(Float(lutG[Swift.min(255, g * 255 / (size - 1))]))
                    cubeData.append(Float(lutB[Swift.min(255, b * 255 / (size - 1))]))
                    cubeData.append(1.0)
                }
            }
        }
        if let f = CIFilter(name: "CIColorCube") {
            f.setValue(size, forKey: "inputCubeDimension")
            f.setValue(Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size) as NSData,
                       forKey: "inputCubeData")
            f.setValue(out, forKey: kCIInputImageKey)
            if let r = f.outputImage { out = r }
        }
        return out
    }

    static func applyOkLabAdjustments(_ ci: CIImage, snap: AdjustmentState) -> CIImage {
        guard snap.vibrance != 0.0 || snap.hue != 0.0 else { return ci }
        let size = 32
        var cubeData = [Float](repeating: 0, count: size * size * size * 4)
        iphoto_oklab_lut(Float(snap.vibrance), Float(snap.hue), &cubeData, UInt32(size))
        guard let f = CIFilter(name: "CIColorCube") else { return ci }
        f.setValue(size, forKey: "inputCubeDimension")
        f.setValue(Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size) as NSData,
                   forKey: "inputCubeData")
        f.setValue(ci, forKey: kCIInputImageKey)
        return f.outputImage ?? ci
    }

    static func applyGeometryAndCrop(_ ci: CIImage, snap: AdjustmentState) -> CIImage {
        var out = ci
        let normalizedTurns = ((snap.turns % 4) + 4) % 4
        if normalizedTurns != 0 {
            let angle = -CGFloat(normalizedTurns) * (.pi / 2)
            let cx = out.extent.midX, cy = out.extent.midY
            var t = CGAffineTransform(translationX: cx, y: cy)
            t = t.rotated(by: angle)
            t = t.translatedBy(x: -cx, y: -cy)
            let rotated = out.transformed(by: t)
            out = rotated.transformed(by: CGAffineTransform(translationX: -rotated.extent.minX,
                                                             y: -rotated.extent.minY))
        }
        if snap.rotation != 0 {
            let angle = CGFloat(snap.rotation) * .pi / 180.0
            let cx = out.extent.midX, cy = out.extent.midY
            var t = CGAffineTransform(translationX: cx, y: cy)
            t = t.rotated(by: angle)
            t = t.translatedBy(x: -cx, y: -cy)
            let rotated = out.transformed(by: t)
            out = rotated.transformed(by: CGAffineTransform(translationX: -rotated.extent.minX,
                                                             y: -rotated.extent.minY))
        }
        let identityRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        if !snap.cropRect.equalTo(identityRect) {
            let ext = out.extent
            let px = CGRect(x: ext.minX + snap.cropRect.minX * ext.width,
                            y: ext.minY + (1.0 - snap.cropRect.maxY) * ext.height,
                            width:  snap.cropRect.width  * ext.width,
                            height: snap.cropRect.height * ext.height)
            let cropped = out.cropped(to: px)
            out = cropped.transformed(by: CGAffineTransform(translationX: -cropped.extent.minX,
                                                             y: -cropped.extent.minY))
        }
        if snap.vignetteAmount != 0, let f = CIFilter(name: "CIVignetteEffect") {
            let center = CIVector(x: out.extent.midX, y: out.extent.midY)
            let radius = hypot(out.extent.width, out.extent.height) * CGFloat(snap.vignetteRadius)
            f.setValue(out,                          forKey: kCIInputImageKey)
            f.setValue(center,                       forKey: kCIInputCenterKey)
            f.setValue(radius,                       forKey: kCIInputRadiusKey)
            f.setValue(-snap.vignetteAmount / 100.0, forKey: kCIInputIntensityKey)
            f.setValue(0.5,                          forKey: "inputFalloff")
            if let r = f.outputImage { out = r }
        }
        return out
    }

    // MARK: - Lokale Anpassungen

    static func applyLocalAdjustments(_ locals: [LocalAdjustment], to ci: CIImage) -> CIImage {
        var result = ci
        let ext = ci.extent

        for adj in locals {
            guard !adj.delta.isNeutral else { continue }
            guard var mask = buildMask(adj.mask, extent: ext) else { continue }

            if adj.intensity < 1.0, let f = CIFilter(name: "CIColorMatrix") {
                let v = CGFloat(adj.intensity)
                f.setValue(mask, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: v, y: 0, z: 0, w: 0), forKey: "inputRVector")
                f.setValue(CIVector(x: 0, y: v, z: 0, w: 0), forKey: "inputGVector")
                f.setValue(CIVector(x: 0, y: 0, z: v, w: 0), forKey: "inputBVector")
                f.setValue(CIVector(x: 0, y: 0, z: 0, w: v), forKey: "inputAVector")
                if let out = f.outputImage { mask = out }
            }
            if adj.inverted, let f = CIFilter(name: "CIColorInvert") {
                f.setValue(mask, forKey: kCIInputImageKey)
                if let out = f.outputImage { mask = out }
            }
            mask = mask.cropped(to: ext)

            var deltaCI = result
            let d = adj.delta
            if d.exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
                f.setValue(deltaCI, forKey: kCIInputImageKey)
                f.setValue(d.exposure, forKey: kCIInputEVKey)
                if let out = f.outputImage { deltaCI = out }
            }
            if d.brightness != 0 || d.contrast != 1.0 || d.saturation != 1.0,
               let f = CIFilter(name: "CIColorControls") {
                f.setValue(deltaCI, forKey: kCIInputImageKey)
                f.setValue(d.brightness, forKey: kCIInputBrightnessKey)
                f.setValue(d.contrast,   forKey: kCIInputContrastKey)
                f.setValue(d.saturation, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { deltaCI = out }
            }
            if (d.warmth != 0 || d.tint != 0), let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(deltaCI, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: CGFloat(6500 - d.warmth * 50), y: CGFloat(-d.tint * 3)),
                           forKey: "inputTargetNeutral")
                if let out = f.outputImage { deltaCI = out }
            }
            if let blend = CIFilter(name: "CIBlendWithMask") {
                blend.setValue(result,  forKey: kCIInputBackgroundImageKey)
                blend.setValue(deltaCI, forKey: kCIInputImageKey)
                blend.setValue(mask,    forKey: kCIInputMaskImageKey)
                if let out = blend.outputImage { result = out }
            }
        }
        return result
    }

    static func buildMask(_ shape: MaskShape, extent: CGRect) -> CIImage? {
        let w = extent.width, h = extent.height
        switch shape {
        case .linearGradient(let sx, let sy, let ex, let ey):
            guard let f = CIFilter(name: "CILinearGradient") else { return nil }
            f.setValue(CIVector(x: extent.minX + CGFloat(sx) * w, y: extent.minY + (1 - CGFloat(sy)) * h), forKey: "inputPoint0")
            f.setValue(CIVector(x: extent.minX + CGFloat(ex) * w, y: extent.minY + (1 - CGFloat(ey)) * h), forKey: "inputPoint1")
            f.setValue(CIColor.white, forKey: "inputColor0")
            f.setValue(CIColor.black, forKey: "inputColor1")
            return f.outputImage
        case .radialGradient(let cx, let cy, let r, let feather):
            guard let f = CIFilter(name: "CIRadialGradient") else { return nil }
            let center = CIVector(x: extent.minX + CGFloat(cx) * w, y: extent.minY + (1 - CGFloat(cy)) * h)
            let innerR = CGFloat(r) * min(w, h)
            f.setValue(center, forKey: "inputCenter")
            f.setValue(innerR, forKey: "inputRadius0")
            f.setValue(innerR * CGFloat(1 + max(0.01, feather)), forKey: "inputRadius1")
            f.setValue(CIColor.white, forKey: "inputColor0")
            f.setValue(CIColor.black, forKey: "inputColor1")
            return f.outputImage
        }
    }

    static func isDefaultCurve(_ pts: [CGPoint]) -> Bool {
        zip(pts, CurvesView.defaultPoints).allSatisfy { abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001 }
    }
}
