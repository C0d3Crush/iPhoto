import SwiftUI
import AppKit

// macOS 11: ScrollViewProxy.scrollTo hinterlässt in SwiftUIs HostingScrollView
// ein persistentes Scroll-Ziel (makeTarget). Wird das Lazy-Layout danach neu
// aufgebaut (visibleDocuments ändert sich, Thumbnails laden), dereferenziert
// die nächste Scroll-/Resize-Notification ein freigegebenes AttributeGraph-
// Attribut → SIGSEGV/SIGABRT (Bugs #10/#18/#21–24/#27/#31). Deshalb wird hier
// direkt über das umgebende NSScrollView gescrollt — ohne SwiftUI-Ziel.

final class AppKitScroller: ObservableObject {
    weak var scrollView: NSScrollView?

    func centerHorizontally(position: Int, cellWidth: CGFloat, spacing: CGFloat, padding: CGFloat) {
        guard let sv = scrollView, let doc = sv.documentView, position >= 0 else { return }
        let clip = sv.contentView
        let targetCenterX = padding + CGFloat(position) * (cellWidth + spacing) + cellWidth / 2
        var origin = clip.bounds.origin
        origin.x = clamp(targetCenterX - clip.bounds.width / 2,
                         max: doc.frame.width - clip.bounds.width)
        clip.scroll(to: origin)
        sv.reflectScrolledClipView(clip)
    }

    func centerRow(position: Int, count: Int, columns: Int, verticalPadding: CGFloat) {
        guard let sv = scrollView, let doc = sv.documentView,
              position >= 0, count > 0, columns > 0 else { return }
        let clip = sv.contentView
        let rows = (count + columns - 1) / columns
        let rowHeight = (doc.frame.height - verticalPadding * 2) / CGFloat(rows)
        let targetCenterYTop = verticalPadding + (CGFloat(position / columns) + 0.5) * rowHeight
        let targetCenterY = doc.isFlipped ? targetCenterYTop : doc.frame.height - targetCenterYTop
        var origin = clip.bounds.origin
        origin.y = clamp(targetCenterY - clip.bounds.height / 2,
                         max: doc.frame.height - clip.bounds.height)
        clip.scroll(to: origin)
        sv.reflectScrolledClipView(clip)
    }

    private func clamp(_ v: CGFloat, max upper: CGFloat) -> CGFloat {
        min(max(v, 0), max(upper, 0))
    }
}

struct ScrollViewGrabber: NSViewRepresentable {
    let scroller: AppKitScroller

    func makeNSView(context: Context) -> GrabberView {
        let v = GrabberView()
        v.scroller = scroller
        return v
    }

    func updateNSView(_ nsView: GrabberView, context: Context) {
        nsView.scroller = scroller
        if let sv = nsView.enclosingScrollView { scroller.scrollView = sv }
    }

    final class GrabberView: NSView {
        weak var scroller: AppKitScroller?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let sv = enclosingScrollView { scroller?.scrollView = sv }
        }
    }
}
