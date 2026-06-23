import SwiftUI
import AppKit

struct ZoomableScrollView: NSViewRepresentable {
    let image: CGImage
    @Binding var zoomFactor: CGFloat
    @Binding var fitToWindow: Bool

    func makeNSView(context: Context) -> PanScrollView {
        let scrollView = PanScrollView()
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.01
        scrollView.maxMagnification = 32.0
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        // CenteredClipView keeps the document centered whenever it's smaller than the viewport
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

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.magnificationChanged(_:)),
            name: NSScrollView.didEndLiveMagnifyNotification,
            object: scrollView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: PanScrollView, context: Context) {
        let coordinator = context.coordinator

        let imageChanged = coordinator.lastCGImage !== image
        if imageChanged {
            coordinator.lastCGImage = image
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            coordinator.imageView?.image = nsImage
            coordinator.imageView?.frame = NSRect(origin: .zero, size: nsImage.size)
            DispatchQueue.main.async { coordinator.fitToWindow() }
            return
        }

        if fitToWindow {
            DispatchQueue.main.async {
                coordinator.fitToWindow()
                self.fitToWindow = false
            }
        } else if abs(scrollView.magnification - zoomFactor) > 0.001 {
            scrollView.magnification = zoomFactor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomFactor: $zoomFactor)
    }

    class Coordinator: NSObject {
        var zoomFactor: Binding<CGFloat>
        weak var imageView: NSImageView?
        weak var scrollView: NSScrollView?
        var lastCGImage: CGImage?

        init(zoomFactor: Binding<CGFloat>) {
            self.zoomFactor = zoomFactor
        }

        func fitToWindow() {
            guard let scrollView = scrollView,
                  let imageView = imageView,
                  let img = imageView.image else { return }
            let viewSize = scrollView.contentSize
            let imgSize = img.size
            guard imgSize.width > 0, imgSize.height > 0, viewSize.width > 0 else { return }

            let scale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
            let clamped = min(max(scale, scrollView.minMagnification), scrollView.maxMagnification)
            scrollView.magnification = clamped
            zoomFactor.wrappedValue = clamped
            // CenteredClipView handles centering automatically
        }

        @objc func magnificationChanged(_ notification: Notification) {
            guard let sv = notification.object as? NSScrollView else { return }
            zoomFactor.wrappedValue = sv.magnification
        }
    }
}

// Automatically centers the document view when it is smaller than the visible area
private class CenteredClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let doc = documentView else { return rect }
        let docFrame = doc.frame
        if rect.width > docFrame.width {
            rect.origin.x = (docFrame.width - rect.width) / 2
        }
        if rect.height > docFrame.height {
            rect.origin.y = (docFrame.height - rect.height) / 2
        }
        return rect
    }
}

class PanScrollView: NSScrollView {
    var onMagnificationChange: ((CGFloat) -> Void)?

    private var dragStart: NSPoint?
    private var scrollOrigin: NSPoint?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func scrollWheel(with event: NSEvent) {
        // Mouse wheel (no trackpad phase) → zoom centered on cursor
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

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        scrollOrigin = contentView.bounds.origin
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let origin = scrollOrigin else { return }
        let current = event.locationInWindow
        let dx = current.x - start.x
        let dy = current.y - start.y
        contentView.scroll(to: NSPoint(x: origin.x - dx, y: origin.y - dy))
        reflectScrolledClipView(contentView)
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        scrollOrigin = nil
        NSCursor.pop()
    }
}
