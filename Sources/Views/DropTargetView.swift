import SwiftUI
import AppKit

struct DropTargetView: NSViewRepresentable {
    @EnvironmentObject var viewModel: ImageViewModel

    func makeNSView(context: Context) -> InternalDropView {
        let view = InternalDropView()
        view.onDrop = { urls in
            context.coordinator.viewModel?.importFiles(urls)
        }
        return view
    }

    func updateNSView(_ view: InternalDropView, context: Context) {
        context.coordinator.viewModel = viewModel
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var viewModel: ImageViewModel?
    }
}

class InternalDropView: NSView {
    var onDrop: (([URL]) -> Void)?
    private var isHighlighted = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override var isOpaque: Bool { false }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = extractURLs(from: sender)
        isHighlighted = !urls.isEmpty
        needsDisplay = true
        return urls.isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false
        needsDisplay = true
        let urls = extractURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isHighlighted else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
        bounds.fill()
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 6), xRadius: 10, yRadius: 10)
        path.lineWidth = 3
        path.setLineDash([10, 5], count: 2, phase: 0)
        path.stroke()
    }

    private func extractURLs(from info: NSDraggingInfo) -> [URL] {
        guard let items = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            return []
        }
        return items.filter {
            ImageDocument.supportedExtensions.contains($0.pathExtension.lowercased())
        }
    }
}
