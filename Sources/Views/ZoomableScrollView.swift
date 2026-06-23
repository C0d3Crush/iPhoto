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
        scrollView.backgroundColor = .windowBackgroundColor

        let imageView = CenteredImageView()
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.autoresizingMask = []
        scrollView.documentView = imageView

        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

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
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

        if coordinator.imageView?.image !== nsImage {
            coordinator.imageView?.image = nsImage
            coordinator.imageView?.frame = NSRect(origin: .zero, size: nsImage.size)
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

        init(zoomFactor: Binding<CGFloat>) {
            self.zoomFactor = zoomFactor
        }

        func fitToWindow() {
            guard let scrollView = scrollView,
                  let imageView = imageView,
                  let img = imageView.image else { return }
            let viewSize = scrollView.contentSize
            let imgSize = img.size
            guard imgSize.width > 0, imgSize.height > 0 else { return }

            let scaleX = viewSize.width / imgSize.width
            let scaleY = viewSize.height / imgSize.height
            let scale = min(scaleX, scaleY)
            let clamped = min(max(scale, scrollView.minMagnification), scrollView.maxMagnification)

            scrollView.magnification = clamped
            zoomFactor.wrappedValue = clamped

            let scaledW = imgSize.width * clamped
            let scaledH = imgSize.height * clamped
            let offsetX = max((viewSize.width - scaledW) / 2, 0)
            let offsetY = max((viewSize.height - scaledH) / 2, 0)
            scrollView.contentView.scroll(to: NSPoint(x: -offsetX, y: -offsetY))
        }

        @objc func magnificationChanged(_ notification: Notification) {
            guard let sv = notification.object as? NSScrollView else { return }
            zoomFactor.wrappedValue = sv.magnification
        }
    }
}

// NSScrollView-Subklasse mit Hand-Cursor und Klick-Ziehen zum Verschieben
class PanScrollView: NSScrollView {
    private var dragStart: NSPoint?
    private var scrollOrigin: NSPoint?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
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
        let newOrigin = NSPoint(x: origin.x - dx, y: origin.y - dy)
        contentView.scroll(to: newOrigin)
        reflectScrolledClipView(contentView)
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        scrollOrigin = nil
        NSCursor.pop()
    }
}

private class CenteredImageView: NSImageView {
    override var isFlipped: Bool { false }
}
