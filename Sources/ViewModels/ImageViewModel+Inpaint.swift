import Foundation
import CoreGraphics
import AppKit

// MARK: - InpaintState

final class InpaintState: ObservableObject {
    @Published var isMaskingMode: Bool = false
    @Published var isRunning: Bool = false
    @Published var resultImage: CGImage? = nil
    @Published var errorMessage: String? = nil
    @Published var statusMessage: String? = nil
    @Published var brushRadius: CGFloat = 30.0

    // Written by PanScrollView (mask-drawing canvas), read on inpaint submission.
    var pendingMaskBitmap: NSBitmapImageRep? = nil

    // Token + URL to detect stale completions after image switch.
    var runToken: UUID = UUID()
    var runURL: URL? = nil
    // Cancel closure to terminate the subprocess when clearing mid-run.
    var cancelProcess: (() -> Void)? = nil

    var cmtDirectory: String {
        get { UserDefaults.standard.string(forKey: "inpaint.cmtDirectory") ?? "~/.iPhoto/CMT" }
        set { UserDefaults.standard.set(newValue, forKey: "inpaint.cmtDirectory") }
    }
    var checkpointPath: String {
        get { UserDefaults.standard.string(forKey: "inpaint.checkpointPath") ?? "~/.iPhoto/CMT/checkpoints/places2.pth" }
        set { UserDefaults.standard.set(newValue, forKey: "inpaint.checkpointPath") }
    }
    var python3Path: String {
        get { UserDefaults.standard.string(forKey: "inpaint.python3Path") ?? "/usr/local/bin/python3.10" }
        set { UserDefaults.standard.set(newValue, forKey: "inpaint.python3Path") }
    }
}

// MARK: - ImageViewModel extension

extension ImageViewModel {

    func startInpaint() {
        guard let image = adj.adjustedImage ?? currentImage else {
            inpaint.errorMessage = "Kein Bild geladen"
            return
        }
        guard let maskBmp = inpaint.pendingMaskBitmap, let maskImage = maskBmp.cgImage else {
            inpaint.errorMessage = "Keine Maske gezeichnet — zuerst den Bereich anmalen"
            return
        }

        let token = UUID()
        let url   = collection.currentDocument?.url
        inpaint.runToken  = token
        inpaint.runURL    = url
        inpaint.isRunning    = true
        inpaint.errorMessage = nil
        inpaint.statusMessage = "CMT läuft… (kann je nach GPU/CPU einige Minuten dauern)"

        let config = InpaintProcessor.Config(
            cmtDirectory:   inpaint.cmtDirectory,
            checkpointPath: inpaint.checkpointPath,
            python3Path:    inpaint.python3Path
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try InpaintProcessor.run(image: image, mask: maskImage, config: config,
                    taskStarted: { [weak self] process in
                        DispatchQueue.main.async { self?.inpaint.cancelProcess = { process.terminate() } }
                    })
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          self.inpaint.runToken == token,
                          self.collection.currentDocument?.url == url else { return }
                    self.inpaint.resultImage   = result
                    self.inpaint.isRunning     = false
                    self.inpaint.statusMessage = "Ergebnis bereit"
                    self.inpaint.isMaskingMode = false
                    self.inpaint.cancelProcess = nil
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.inpaint.runToken == token else { return }
                    self.inpaint.isRunning     = false
                    self.inpaint.cancelProcess = nil
                    self.inpaint.errorMessage  = error.localizedDescription
                    self.inpaint.statusMessage = nil
                    Log.error("Inpaint fehlgeschlagen: \(error.localizedDescription)")
                }
            }
        }
    }

    func clearInpaint() {
        inpaint.runToken      = UUID()   // invalidates any in-flight completion
        inpaint.cancelProcess?()         // terminate subprocess if running
        inpaint.cancelProcess  = nil
        inpaint.isRunning      = false
        inpaint.resultImage    = nil
        inpaint.pendingMaskBitmap = nil
        inpaint.statusMessage  = nil
        inpaint.errorMessage   = nil
        inpaint.isMaskingMode  = false
        NotificationCenter.default.post(name: .inpaintClearMask, object: nil)
    }

    func saveInpaintResult() {
        guard let result = inpaint.resultImage,
              let sourceURL = inpaint.runURL ?? collection.currentDocument?.url else { return }
        let stem = (sourceURL.deletingPathExtension().lastPathComponent)
        let name = "\(stem)_inpaint.jpg"
        let destURL = sourceURL.deletingLastPathComponent().appendingPathComponent(name)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try ImageExporter.exportSingle(image: result, to: destURL, format: .jpeg, quality: 0.95, sourceURL: sourceURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.clearInpaint()
                    self.importFiles([destURL], selectFirst: true)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.inpaint.errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let inpaintClearMask = Notification.Name("iPhoto.inpaintClearMask")
}
