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

        var snap = adjustments
        if !bypassedAdjustments.isEmpty {
            let neutral = AdjustmentState()
            for kp in bypassedAdjustments {
                if let dkp = kp as? WritableKeyPath<AdjustmentState, Double> {
                    snap[keyPath: dkp] = neutral[keyPath: dkp]
                }
            }
        }
        let token       = UUID()
        adjToken        = token
        let useRAW      = collection.currentDocument?.isRAW ?? false
        let rawURL      = collection.currentDocument?.url
        let nativeSize  = imageSize

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var ci: CIImage
            var exposureApplied = false
            var wbApplied = false

            let longestEdge  = max(nativeSize.width, nativeSize.height)
            let previewScale = longestEdge > 0 ? min(1.0, 1500.0 / Double(longestEdge)) : 1.0

            if useRAW, let url = rawURL,
               let result = AdjustmentRenderer.rawPipeline(url: url, snap: snap,
                                                           scale: previewScale, draftMode: true) {
                ci = result.image
                exposureApplied = result.exposureApplied
                wbApplied = result.wbApplied
            } else {
                ci = CIImage(cgImage: source)
            }

            ci = AdjustmentRenderer.pipeline(ci, snap: snap,
                                             exposureApplied: exposureApplied, wbApplied: wbApplied)

            let result = self.adjCIContext.createCGImage(ci, from: ci.extent)
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.adjToken == token else { return }
                self.adjustedImage = result
                self.displayImageVersion = UUID()
            }
        }
    }

    // MARK: - Rotation

    func rotateLeft() {
        adjustments.turns = ((adjustments.turns - 1) % 4 + 4) % 4
        adjHistory.commit(adjustments)
        applyAdjustments()
    }

    func rotateRight() {
        adjustments.turns = (adjustments.turns + 1) % 4
        adjHistory.commit(adjustments)
        applyAdjustments()
    }

    // MARK: - Undo / Redo

    func resetAdjustments() {
        adjustments = AdjustmentState()
        adjustedImage = nil
        versions.pendingMetadataEntries = nil
    }

    func undoAdjustments() {
        guard let prev = adjHistory.undo() else { return }
        isUndoRedoing = true
        adjustments = prev
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.isUndoRedoing = false
        }
    }

    func redoAdjustments() {
        guard let next = adjHistory.redo() else { return }
        isUndoRedoing = true
        adjustments = next
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
        // Unverändert seit Laden/letztem Speichern → kein synchroner SQLite-Write pro Bildwechsel
        guard adjustments != lastPersistedAdjustments else { return }
        if adjustments != AdjustmentState() {
            CatalogStore.shared.saveAdjustments(path: doc.url.path, adjustments: adjustments)
        } else {
            CatalogStore.shared.deleteAdjustments(path: doc.url.path)
        }
        lastPersistedAdjustments = adjustments
    }

    func adjustmentLabel() -> String {
        var parts: [String] = []
        if adjustments.exposure   != 0 { parts.append(String(format: "Belichtung %+.1f EV", adjustments.exposure)) }
        if adjustments.brightness != 0 { parts.append(String(format: "Helligkeit %+.2f",    adjustments.brightness)) }
        if adjustments.contrast   != 1 { parts.append(String(format: "Kontrast %.2f",       adjustments.contrast)) }
        if adjustments.saturation != 1 { parts.append(String(format: "Sättigung %.2f",      adjustments.saturation)) }
        if adjustments.warmth     != 0 { parts.append(String(format: "Wärme %+.2f",         adjustments.warmth)) }
        if adjustments.turns      != 0 { parts.append("\(adjustments.turns * 90)° gedreht") }
        if adjustments.rotation   != 0 { parts.append(String(format: "Rotation %.1f°",      adjustments.rotation)) }
        if adjustments.cropRect != CGRect(x: 0, y: 0, width: 1, height: 1) { parts.append("Zugeschnitten") }
        let curveDefault = zip(adjustments.curvePoints, CurvesView.defaultPoints).allSatisfy {
            abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001
        }
        if !curveDefault { parts.append("Kurve") }
        return parts.isEmpty ? "Anpassungen" : parts.joined(separator: " · ")
    }
}
