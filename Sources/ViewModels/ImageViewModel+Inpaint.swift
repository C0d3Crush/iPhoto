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
                let result = try InpaintProcessor.run(image: image, mask: maskImage, config: config)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.inpaint.resultImage  = result
                    self.inpaint.isRunning    = false
                    self.inpaint.statusMessage = "Fertig"
                    self.inpaint.isMaskingMode = false
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.inpaint.isRunning    = false
                    self.inpaint.errorMessage = error.localizedDescription
                    self.inpaint.statusMessage = nil
                    Log.error("Inpaint fehlgeschlagen: \(error.localizedDescription)")
                }
            }
        }
    }

    func clearInpaint() {
        inpaint.resultImage    = nil
        inpaint.pendingMaskBitmap = nil
        inpaint.statusMessage  = nil
        inpaint.errorMessage   = nil
        inpaint.isMaskingMode  = false
        NotificationCenter.default.post(name: .inpaintClearMask, object: nil)
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let inpaintClearMask = Notification.Name("iPhoto.inpaintClearMask")
}
