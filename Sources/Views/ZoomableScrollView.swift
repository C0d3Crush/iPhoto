import SwiftUI
import AppKit

struct ZoomableScrollView: NSViewRepresentable {
    let image: CGImage
    @Binding var zoomFactor: CGFloat
    @Binding var fitToWindow: Bool
    var alwaysFitOnImageChange: Bool = false
    // Inpaint mask drawing
    var maskModeEnabled: Bool = false
    var brushRadius: CGFloat = 20.0
    var onMaskUpdate: ((NSBitmapImageRep?) -> Void)? = nil

    func makeNSView(context: Context) -> PanScrollView {
        let scrollView = PanScrollView()
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.01
        scrollView.maxMagnification = 32.0
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let clipView = CenteredClipView()
        clipView.drawsBackground = true
        clipView.backgroundColor = .windowBackgroundColor
        scrollView.contentView = clipView

        let imageView = NSImageView()
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.autoresizingMask = []
        scrollView.documentView = imageView

        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        scrollView.onMagnificationChange = { [weak coordinator = context.coordinator] mag in
            coordinator?.zoomFactor.wrappedValue = mag
        }

        scrollView.onSmartZoom = { [weak coordinator = context.coordinator] in
            guard let coordinator = coordinator else { return }
            if abs(coordinator.zoomFactor.wrappedValue - 1.0) < 0.05 {
                coordinator.fitToWindow()
            } else {
                coordinator.scrollView?.magnification = 1.0
                coordinator.zoomFactor.wrappedValue = 1.0
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.liveMagnifyBegan(_:)),
            name: NSScrollView.willStartLiveMagnifyNotification,
            object: scrollView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.liveMagnifyEnded(_:)),
            name: NSScrollView.didEndLiveMagnifyNotification,
            object: scrollView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: PanScrollView, context: Context) {
        let coordinator = context.coordinator

        // Inpaint props (always update, cheap)
        scrollView.maskModeEnabled = maskModeEnabled
        scrollView.brushRadius = brushRadius
        scrollView.onMaskUpdate = onMaskUpdate

        let imageChanged = coordinator.lastCGImage !== image
        if imageChanged {
            Log.trace("ZoomableScrollView: neues Bild angezeigt \(image.width)×\(image.height)")
            let oldWidth = CGFloat(coordinator.lastCGImage?.width ?? 0)
            coordinator.lastCGImage = image
            let newSize = NSSize(width: image.width, height: image.height)
            let nsImage = NSImage(cgImage: image, size: newSize)
            coordinator.imageView?.image = nsImage
            coordinator.imageView?.frame = NSRect(origin: .zero, size: newSize)

            // Reset mask for new image
            scrollView.resetMask(imageSize: newSize)

            if fitToWindow || alwaysFitOnImageChange {
                coordinator.fitToWindow()
                DispatchQueue.main.async { self.fitToWindow = false }
            } else if oldWidth > 0, let sv = coordinator.scrollView {
                let ratio = oldWidth / CGFloat(image.width)
                let adjusted = min(max(sv.magnification * ratio, sv.minMagnification), sv.maxMagnification)
                sv.magnification = adjusted
                coordinator.zoomFactor.wrappedValue = adjusted
            }
            return
        }

        if fitToWindow {
            DispatchQueue.main.async {
                coordinator.fitToWindow()
                self.fitToWindow = false
            }
        } else if !scrollView.isLiveMagnifying,
                  abs(scrollView.magnification - zoomFactor) > 0.001 {
            scrollView.magnification = zoomFactor
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(zoomFactor: $zoomFactor) }

    class Coordinator: NSObject {
        var zoomFactor: Binding<CGFloat>
        weak var imageView: NSImageView?
        weak var scrollView: PanScrollView?
        var lastCGImage: CGImage?

        init(zoomFactor: Binding<CGFloat>) { self.zoomFactor = zoomFactor }

        func fitToWindow() {
            guard let scrollView = scrollView,
                  let imageView = imageView,
                  let img = imageView.image else { return }
            let viewSize = scrollView.contentSize
            let imgSize = img.size
            guard imgSize.width > 0, imgSize.height > 0 else { return }
            guard viewSize.width > 0, viewSize.height > 0 else {
                DispatchQueue.main.async { [weak self] in self?.fitToWindow() }
                return
            }
            let scale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
            let clamped = min(max(scale, scrollView.minMagnification), scrollView.maxMagnification)
            scrollView.magnification = clamped
            zoomFactor.wrappedValue = clamped
        }

        @objc func liveMagnifyBegan(_ n: Notification) {
            (n.object as? PanScrollView)?.isLiveMagnifying = true
        }

        @objc func liveMagnifyEnded(_ n: Notification) {
            guard let sv = n.object as? PanScrollView else { return }
            sv.isLiveMagnifying = false
            zoomFactor.wrappedValue = sv.magnification
        }
    }
}

// MARK: - CenteredClipView

private class CenteredClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let doc = documentView else { return rect }
        let docFrame = doc.frame
        if rect.width > docFrame.width  { rect.origin.x = (docFrame.width  - rect.width)  / 2 }
        if rect.height > docFrame.height { rect.origin.y = (docFrame.height - rect.height) / 2 }
        return rect
    }
}

// MARK: - MaskOverlayView

/// Transparent NSView placed as subview of documentView (= image-space coordinates).
/// Paints a red overlay where the user has brushed the mask.
private class MaskOverlayView: NSView {
    private var maskCtx: CGContext?
    private(set) var imageSize: CGSize = .zero

    override var isOpaque: Bool { false }

    /// Pass all mouse events through to PanScrollView.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func initialize(size: CGSize) {
        imageSize = size
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(origin: .zero, size: size))
        maskCtx = ctx
    }

    func paint(at point: NSPoint, radius: CGFloat) {
        guard let ctx = maskCtx else { return }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fillEllipse(in: CGRect(
            x: point.x - radius, y: point.y - radius,
            width: radius * 2,   height: radius * 2
        ))
        setNeedsDisplay(bounds)
    }

    func clear() {
        guard let ctx = maskCtx else { return }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(origin: .zero, size: imageSize))
        setNeedsDisplay(bounds)
    }

    var maskImage: CGImage? { maskCtx?.makeImage() }

    var hasPaint: Bool {
        guard let ctx = maskCtx, let data = ctx.data else { return false }
        let total = ctx.bytesPerRow * Int(imageSize.height)
        let ptr = data.bindMemory(to: UInt8.self, capacity: total)
        for i in 0..<total { if ptr[i] != 0 { return true } }
        return false
    }

    /// Returns an NSBitmapImageRep wrapping a white-on-black grayscale mask image.
    var maskBitmap: NSBitmapImageRep? {
        guard let img = maskImage else { return nil }
        return NSBitmapImageRep(cgImage: img)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              let maskImg = maskCtx?.makeImage() else { return }
        ctx.saveGState()
        ctx.clip(to: bounds, mask: maskImg)
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        ctx.fill(bounds)
        ctx.restoreGState()
    }
}

// MARK: - PanScrollView

class PanScrollView: NSScrollView {
    var onMagnificationChange: ((CGFloat) -> Void)?
    var onSmartZoom: (() -> Void)?
    var isLiveMagnifying = false

    // Mask drawing
    var maskModeEnabled: Bool = false {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }
    var brushRadius: CGFloat = 20.0
    var onMaskUpdate: ((NSBitmapImageRep?) -> Void)?

    private weak var maskOverlay: MaskOverlayView?
    private var lastDrawPoint: NSPoint?
    private var clearObserver: NSObjectProtocol?

    private var dragStart: NSPoint?
    private var scrollOrigin: NSPoint?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clearObserver = NotificationCenter.default.addObserver(
            forName: .inpaintClearMask, object: nil, queue: .main
        ) { [weak self] _ in
            self?.maskOverlay?.clear()
            self?.onMaskUpdate?(nil)
        }
    }

    deinit {
        if let obs = clearObserver { NotificationCenter.default.removeObserver(obs) }
    }

    // Called by ZoomableScrollView.updateNSView when a new image is set.
    func resetMask(imageSize: NSSize) {
        maskOverlay?.removeFromSuperview()

        guard let docView = documentView else { return }
        let overlay = MaskOverlayView(frame: NSRect(origin: .zero, size: imageSize))
        overlay.initialize(size: imageSize)
        docView.addSubview(overlay)
        maskOverlay = overlay
        onMaskUpdate?(nil)
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: maskModeEnabled ? .crosshair : .openHand)
    }

    // MARK: - Zoom / Magnification

    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        onMagnificationChange?(magnification)
    }

    override func smartMagnify(with event: NSEvent) {
        onSmartZoom?()
    }

    override func scrollWheel(with event: NSEvent) {
        if event.phase == [] && event.momentumPhase == [] {
            let factor: CGFloat = event.deltaY > 0 ? 1.1 : (1.0 / 1.1)
            let newMag = min(max(magnification * factor, minMagnification), maxMagnification)
            let mouseInView = convert(event.locationInWindow, from: nil)
            setMagnification(newMag, centeredAt: mouseInView)
            onMagnificationChange?(magnification)
        } else {
            super.scrollWheel(with: event)
        }
    }

    // MARK: - Mouse (pan + mask drawing)

    override func mouseDown(with event: NSEvent) {
        if maskModeEnabled {
            paintAt(event: event)
            lastDrawPoint = docPoint(for: event)
        } else {
            dragStart = event.locationInWindow
            scrollOrigin = contentView.bounds.origin
            NSCursor.closedHand.push()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if maskModeEnabled {
            let current = docPoint(for: event)
            if let last = lastDrawPoint {
                // Interpolate for smooth strokes
                let dist = hypot(current.x - last.x, current.y - last.y)
                let steps = max(1, Int(dist / max(1, brushRadius * 0.4)))
                for i in 1...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let p = NSPoint(x: last.x + (current.x - last.x) * t,
                                   y: last.y + (current.y - last.y) * t)
                    maskOverlay?.paint(at: p, radius: brushRadius)
                }
            } else {
                maskOverlay?.paint(at: current, radius: brushRadius)
            }
            lastDrawPoint = current
        } else {
            guard let start = dragStart, let origin = scrollOrigin else { return }
            let dx = event.locationInWindow.x - start.x
            let dy = event.locationInWindow.y - start.y
            contentView.scroll(to: NSPoint(x: origin.x - dx, y: origin.y - dy))
            reflectScrolledClipView(contentView)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if maskModeEnabled {
            lastDrawPoint = nil
            // Publish the updated mask bitmap to SwiftUI
            onMaskUpdate?(maskOverlay?.maskBitmap)
        } else {
            dragStart = nil; scrollOrigin = nil
            NSCursor.pop()
        }
    }

    // MARK: - Helpers

    private func docPoint(for event: NSEvent) -> NSPoint {
        guard let docView = documentView else {
            return convert(event.locationInWindow, from: nil)
        }
        return docView.convert(event.locationInWindow, from: nil)
    }

    private func paintAt(event: NSEvent) {
        let p = docPoint(for: event)
        maskOverlay?.paint(at: p, radius: brushRadius)
    }
}
