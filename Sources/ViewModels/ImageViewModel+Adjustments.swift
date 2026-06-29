import AppKit
import CoreImage

// MARK: - Adjustments Pipeline

extension ImageViewModel {

    func applyAdjustments() {
        guard hasActiveAdjustments, let source = currentImage else {
            adjustedImage = nil
            displayImageVersion = UUID()
            return
        }

        let snap = adjustments
        let token = UUID()
        adjToken = token

        let useRAWPipeline = collection.currentDocument?.isRAW ?? false
        let rawURL         = collection.currentDocument?.url
        let nativeSize     = imageSize

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var ci: CIImage
            var exposureApplied = false
            var wbApplied = false
            var stopRAWAccess: (() -> Void)? = nil

            if useRAWPipeline, let url = rawURL {
                let longestEdge  = max(nativeSize.width, nativeSize.height)
                let previewScale = longestEdge > 0 ? min(1.0, 1500.0 / Double(longestEdge)) : 1.0
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                if let rf = CIFilter(imageURL: accessURL, options: nil) {
                    let keys = rf.inputKeys
                    if keys.contains(kCIInputEVKey as String) {
                        rf.setValue(Float(snap.exposure), forKey: kCIInputEVKey)
                    }
                    if keys.contains("inputAllowDraftMode") {
                        rf.setValue(true, forKey: "inputAllowDraftMode")
                    }
                    if keys.contains("inputScaleFactor") {
                        rf.setValue(Float(previewScale), forKey: "inputScaleFactor")
                    }
                    if snap.warmth != 0 || snap.tint != 0 {
                        let kelvin  = Float(6500.0 - snap.warmth * 2500.0)
                        let tintVal = Float(-snap.tint * 150.0)
                        if keys.contains("inputNeutralTemperature") {
                            rf.setValue(kelvin,  forKey: "inputNeutralTemperature")
                        }
                        if keys.contains("inputNeutralTint") {
                            rf.setValue(tintVal, forKey: "inputNeutralTint")
                        }
                        wbApplied = true
                    }
                    if let rawCI = rf.outputImage {
                        ci = rawCI
                        exposureApplied = true
                        stopRAWAccess = stopAccess
                    } else {
                        stopAccess()
                        ci = CIImage(cgImage: source)
                    }
                } else {
                    stopAccess()
                    ci = CIImage(cgImage: source)
                }
            } else {
                ci = CIImage(cgImage: source)
            }

            // Chromatic Aberration
            if snap.caAmount > 0, let k = LensFilters.caKernel {
                if let out = k.apply(extent: ci.extent,
                                     roiCallback: { _, r in r },
                                     arguments: [ci, Float(snap.caAmount)]) { ci = out }
            }

            // Lens Distortion
            if snap.distortion != 0, let k = LensFilters.distortKernel {
                let k1  = Float(-snap.distortion * 0.003)
                let ext = CIVector(cgRect: ci.extent)
                if let out = k.apply(extent: ci.extent,
                                     roiCallback: { _, r in r.insetBy(dx: -4, dy: -4) },
                                     image: ci,
                                     arguments: [ext, k1]) {
                    ci = out.cropped(to: ci.extent)
                }
            }

            if !exposureApplied, snap.exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(snap.exposure, forKey: kCIInputEVKey)
                if let out = f.outputImage { ci = out }
            }

            if snap.brightness != 0 || snap.contrast != 1 || snap.saturation != 1,
               let f = CIFilter(name: "CIColorControls") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(snap.brightness, forKey: kCIInputBrightnessKey)
                f.setValue(snap.contrast,   forKey: kCIInputContrastKey)
                f.setValue(snap.saturation, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { ci = out }
            }

            if !wbApplied, snap.warmth != 0 || snap.tint != 0,
               let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: CGFloat(6500 - snap.warmth * 2500), y: CGFloat(-snap.tint * 150)),
                           forKey: "inputTargetNeutral")
                if let out = f.outputImage { ci = out }
            }

            if snap.lumaNoise > 0, let f = CIFilter(name: "CINoiseReduction") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(snap.lumaNoise * 0.001, forKey: "inputNoiseLevel")
                f.setValue(0.4, forKey: kCIInputSharpnessKey)
                if let out = f.outputImage { ci = out }
            }

            if snap.colorNoise > 0, let blurF = CIFilter(name: "CIGaussianBlur") {
                blurF.setValue(ci, forKey: kCIInputImageKey)
                blurF.setValue(snap.colorNoise * 0.25, forKey: kCIInputRadiusKey)
                if let blurred = blurF.outputImage?.cropped(to: ci.extent),
                   let blendF  = CIFilter(name: "CILuminosityBlendMode") {
                    blendF.setValue(ci,      forKey: kCIInputImageKey)
                    blendF.setValue(blurred, forKey: kCIInputBackgroundImageKey)
                    if let out = blendF.outputImage { ci = out }
                }
            }

            if snap.sharpenAmount > 0, let f = CIFilter(name: "CIUnsharpMask") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(snap.sharpenRadius,         forKey: kCIInputRadiusKey)
                f.setValue(snap.sharpenAmount / 100.0, forKey: kCIInputIntensityKey)
                if let out = f.outputImage { ci = out }
            }

            let curveDef = zip(snap.curvePoints, CurvesView.defaultPoints).allSatisfy {
                abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001
            }
            if !curveDef, let f = CIFilter(name: "CIToneCurve") {
                f.setValue(ci, forKey: kCIInputImageKey)
                for (i, pt) in snap.curvePoints.enumerated() {
                    f.setValue(CIVector(x: pt.x, y: pt.y), forKey: "inputPoint\(i)")
                }
                if let out = f.outputImage { ci = out }
            }

            let rDef = self.isDefaultCurve(snap.curveR)
            let gDef = self.isDefaultCurve(snap.curveG)
            let bDef = self.isDefaultCurve(snap.curveB)
            if !rDef || !gDef || !bDef {
                let lutR = CurvesView.evaluateSpline(snap.curveR)
                let lutG = CurvesView.evaluateSpline(snap.curveG)
                let lutB = CurvesView.evaluateSpline(snap.curveB)
                let size = 32
                var cubeData = [Float]()
                cubeData.reserveCapacity(size * size * size * 4)
                for b in 0..<size {
                    for g in 0..<size {
                        for r in 0..<size {
                            let ri = Swift.min(255, r * 255 / (size - 1))
                            let gi = Swift.min(255, g * 255 / (size - 1))
                            let bi = Swift.min(255, b * 255 / (size - 1))
                            cubeData.append(Float(lutR[ri]))
                            cubeData.append(Float(lutG[gi]))
                            cubeData.append(Float(lutB[bi]))
                            cubeData.append(1.0)
                        }
                    }
                }
                if let f = CIFilter(name: "CIColorCube") {
                    f.setValue(size, forKey: "inputCubeDimension")
                    f.setValue(Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size) as NSData,
                               forKey: "inputCubeData")
                    f.setValue(ci, forKey: kCIInputImageKey)
                    if let out = f.outputImage { ci = out }
                }
            }

            if snap.clarity != 0, let f = CIFilter(name: "CIUnsharpMask") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(20.0, forKey: kCIInputRadiusKey)
                f.setValue(Swift.max(0, snap.clarity) * 2.0, forKey: kCIInputIntensityKey)
                if let out = f.outputImage { ci = out }
            }
            if snap.texture != 0, let f = CIFilter(name: "CIUnsharpMask") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(4.0, forKey: kCIInputRadiusKey)
                f.setValue(Swift.max(0, snap.texture) * 2.5, forKey: kCIInputIntensityKey)
                if let out = f.outputImage { ci = out }
            }
            if snap.dehaze != 0, let f = CIFilter(name: "CIColorControls") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(-snap.dehaze * 0.05,         forKey: kCIInputBrightnessKey)
                f.setValue(1.0 + snap.dehaze * 0.25,    forKey: kCIInputContrastKey)
                f.setValue(1.0,                         forKey: kCIInputSaturationKey)
                if let out = f.outputImage { ci = out }
            }

            if !snap.localAdjustments.isEmpty {
                ci = self.applyLocalAdjustments(snap.localAdjustments, to: ci)
            }

            if snap.rotation != 0 {
                let angle = CGFloat(snap.rotation) * .pi / 180.0
                let cx = ci.extent.midX
                let cy = ci.extent.midY
                var t = CGAffineTransform(translationX: cx, y: cy)
                t = t.rotated(by: angle)
                t = t.translatedBy(x: -cx, y: -cy)
                let rotated = ci.transformed(by: t)
                ci = rotated.transformed(by: CGAffineTransform(
                    translationX: -rotated.extent.minX,
                    y: -rotated.extent.minY))
            }

            if !snap.cropRect.equalTo(CGRect(x: 0, y: 0, width: 1, height: 1)) {
                let ext = ci.extent
                let px = CGRect(
                    x: ext.minX + snap.cropRect.minX * ext.width,
                    y: ext.minY + (1.0 - snap.cropRect.maxY) * ext.height,
                    width:  snap.cropRect.width  * ext.width,
                    height: snap.cropRect.height * ext.height
                )
                let cropped = ci.cropped(to: px)
                ci = cropped.transformed(by: CGAffineTransform(
                    translationX: -cropped.extent.minX,
                    y: -cropped.extent.minY))
            }

            if snap.vignetteAmount != 0, let f = CIFilter(name: "CIVignetteEffect") {
                let center = CIVector(x: ci.extent.midX, y: ci.extent.midY)
                let radius = hypot(ci.extent.width, ci.extent.height) * 0.55
                f.setValue(ci,                           forKey: kCIInputImageKey)
                f.setValue(center,                       forKey: kCIInputCenterKey)
                f.setValue(radius,                       forKey: kCIInputRadiusKey)
                f.setValue(-snap.vignetteAmount / 100.0, forKey: kCIInputIntensityKey)
                f.setValue(0.5,                          forKey: "inputFalloff")
                if let out = f.outputImage { ci = out }
            }

            let result = self.adjCIContext.createCGImage(ci, from: ci.extent)
            stopRAWAccess?()
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.adjToken == token else { return }
                self.adjustedImage = result
                self.displayImageVersion = UUID()
            }
        }
    }

    private func applyLocalAdjustments(_ locals: [LocalAdjustment], to ci: CIImage) -> CIImage {
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
                f.setValue(CIVector(x: CGFloat(6500 - d.warmth * 2500), y: CGFloat(-d.tint * 150)),
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

    private func buildMask(_ shape: MaskShape, extent: CGRect) -> CIImage? {
        let w = extent.width, h = extent.height
        switch shape {
        case .linearGradient(let sx, let sy, let ex, let ey):
            let p0 = CIVector(x: extent.minX + CGFloat(sx) * w,
                              y: extent.minY + (1 - CGFloat(sy)) * h)
            let p1 = CIVector(x: extent.minX + CGFloat(ex) * w,
                              y: extent.minY + (1 - CGFloat(ey)) * h)
            guard let f = CIFilter(name: "CILinearGradient") else { return nil }
            f.setValue(p0, forKey: "inputPoint0")
            f.setValue(p1, forKey: "inputPoint1")
            f.setValue(CIColor.white, forKey: "inputColor0")
            f.setValue(CIColor.black, forKey: "inputColor1")
            return f.outputImage

        case .radialGradient(let cx, let cy, let r, let feather):
            let center = CIVector(x: extent.minX + CGFloat(cx) * w,
                                  y: extent.minY + (1 - CGFloat(cy)) * h)
            let innerR = CGFloat(r) * min(w, h)
            let outerR = innerR * CGFloat(1 + max(0.01, feather))
            guard let f = CIFilter(name: "CIRadialGradient") else { return nil }
            f.setValue(center, forKey: "inputCenter")
            f.setValue(innerR, forKey: "inputRadius0")
            f.setValue(outerR, forKey: "inputRadius1")
            f.setValue(CIColor.white, forKey: "inputColor0")
            f.setValue(CIColor.black, forKey: "inputColor1")
            return f.outputImage
        }
    }

    private func isDefaultCurve(_ pts: [CGPoint]) -> Bool {
        zip(pts, CurvesView.defaultPoints).allSatisfy { abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001 }
    }

    // MARK: - Undo / Redo

    func resetAdjustments() {
        adjustments = AdjustmentState()
        adjustedImage = nil
        pendingMetadataEntries = nil
    }

    func undoAdjustments() {
        guard !adjUndoStack.isEmpty else { return }
        isUndoRedoing = true
        adjRedoStack.append(lastCommittedAdjustments)
        let prev = adjUndoStack.removeLast()
        adjustments = prev
        lastCommittedAdjustments = prev
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.isUndoRedoing = false
        }
    }

    func redoAdjustments() {
        guard !adjRedoStack.isEmpty else { return }
        isUndoRedoing = true
        adjUndoStack.append(lastCommittedAdjustments)
        let next = adjRedoStack.removeLast()
        adjustments = next
        lastCommittedAdjustments = next
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.isUndoRedoing = false
        }
    }

    // MARK: - Presets

    func applyPreset(_ preset: Preset) {
        adjustments = preset.adjustments
    }

    func saveCurrentAsPreset(name: String, author: String? = nil) {
        let p = Preset(name: name, author: author, adjustments: adjustments)
        CatalogStore.shared.savePreset(p)
        userPresets = CatalogStore.shared.allUserPresets()
    }

    func deletePreset(_ preset: Preset) {
        CatalogStore.shared.deletePreset(id: preset.id)
        userPresets = CatalogStore.shared.allUserPresets()
    }

    func exportRecipe(_ preset: Preset) {
        guard let data = try? JSONEncoder().encode(preset) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(preset.name).iphotorecipe"
        panel.allowedFileTypes = ["iphotorecipe"]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                Log.error("Rezept exportieren fehlgeschlagen: \(error)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Rezept exportieren fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }

    func importRecipe() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["iphotorecipe"]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url,
                  let data = try? Data(contentsOf: url),
                  var preset = try? JSONDecoder().decode(Preset.self, from: data) else { return }
            preset.id = UUID()
            CatalogStore.shared.savePreset(preset)
            DispatchQueue.main.async { self?.userPresets = CatalogStore.shared.allUserPresets() }
        }
    }

    // MARK: - Copy / Paste

    func copyAdjustments() {
        copiedAdjustments = adjustments
    }

    func pasteAdjustments() {
        guard let src = copiedAdjustments else { return }
        let targets: [Int] = collection.selectedIndices.isEmpty
            ? [collection.currentIndex]
            : Array(collection.selectedIndices)
        for idx in targets where idx < collection.documents.count {
            if idx == collection.currentIndex {
                adjustments = src
            } else {
                CatalogStore.shared.saveAdjustments(
                    path: collection.documents[idx].url.path,
                    adjustments: src
                )
            }
        }
    }

    func persistAdjustmentsForCurrent() {
        guard let doc = collection.currentDocument else { return }
        if adjustments != AdjustmentState() {
            CatalogStore.shared.saveAdjustments(path: doc.url.path, adjustments: adjustments)
        } else {
            CatalogStore.shared.deleteAdjustments(path: doc.url.path)
        }
    }

    func adjustmentLabel() -> String {
        var parts: [String] = []
        if adjustments.exposure   != 0 { parts.append(String(format: "Belichtung %+.1f EV", adjustments.exposure)) }
        if adjustments.brightness != 0 { parts.append(String(format: "Helligkeit %+.2f",    adjustments.brightness)) }
        if adjustments.contrast   != 1 { parts.append(String(format: "Kontrast %.2f",       adjustments.contrast)) }
        if adjustments.saturation != 1 { parts.append(String(format: "Sättigung %.2f",      adjustments.saturation)) }
        if adjustments.warmth     != 0 { parts.append(String(format: "Wärme %+.2f",         adjustments.warmth)) }
        if adjustments.rotation   != 0 { parts.append(String(format: "Rotation %.1f°",      adjustments.rotation)) }
        if adjustments.cropRect != CGRect(x: 0, y: 0, width: 1, height: 1) { parts.append("Zugeschnitten") }
        let curveDefault = zip(adjustments.curvePoints, CurvesView.defaultPoints).allSatisfy {
            abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001
        }
        if !curveDefault { parts.append("Kurve") }
        return parts.isEmpty ? "Anpassungen" : parts.joined(separator: " · ")
    }
}
