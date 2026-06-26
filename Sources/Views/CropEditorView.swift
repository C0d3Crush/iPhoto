import SwiftUI
import AppKit

struct CropEditorView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let sourceImage: CGImage

    @State private var cropRect: CGRect
    @State private var rotation: Double
    @State private var isDragging = false
    @State private var activeHandle: HandleKind? = nil
    @State private var dragStartCrop = CGRect(x: 0, y: 0, width: 1, height: 1)

    private static let defaultCrop = CGRect(x: 0, y: 0, width: 1, height: 1)
    private let bottomBarH: CGFloat = 72

    enum HandleKind: Equatable, Hashable {
        case tl, tc, tr, ml, mr, bl, bc, br, move
    }

    init(image: CGImage, initialCrop: CGRect, initialRotation: Double) {
        self.sourceImage = image
        _cropRect = State(initialValue: initialCrop)
        _rotation = State(initialValue: initialRotation)
    }

    var body: some View {
        GeometryReader { geo in
            let containerSize = CGSize(width: geo.size.width, height: geo.size.height - bottomBarH)
            let imgSize = imageDisplaySize(in: containerSize)

            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                // Rotated crop editing area (image + overlay + handles rotate together)
                ZStack {
                    Image(nsImage: NSImage(cgImage: sourceImage, size: .zero))
                        .resizable()
                        .frame(width: imgSize.width, height: imgSize.height)

                    cropOverlay(imgSize: imgSize, containerSize: containerSize)
                    cropHandles(imgSize: imgSize, containerSize: containerSize)
                }
                .frame(width: containerSize.width, height: containerSize.height)
                .rotationEffect(.degrees(rotation))

                bottomBar
                    .frame(height: bottomBarH)
                    .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }

    // MARK: - Image sizing

    private func imageDisplaySize(in container: CGSize) -> CGSize {
        let iw = CGFloat(sourceImage.width)
        let ih = CGFloat(sourceImage.height)
        let scale = min(container.width * 0.88 / iw, container.height * 0.88 / ih)
        return CGSize(width: iw * scale, height: ih * scale)
    }

    // MARK: - Position helpers

    private func imgOrigin(imgSize: CGSize, containerSize: CGSize) -> CGPoint {
        CGPoint(
            x: (containerSize.width  - imgSize.width)  / 2,
            y: (containerSize.height - imgSize.height) / 2
        )
    }

    // MARK: - Crop overlay (4 dark rects + border + thirds)

    @ViewBuilder
    private func cropOverlay(imgSize: CGSize, containerSize: CGSize) -> some View {
        let o = imgOrigin(imgSize: imgSize, containerSize: containerSize)
        let cX = o.x + cropRect.minX * imgSize.width
        let cY = o.y + cropRect.minY * imgSize.height
        let cW = cropRect.width  * imgSize.width
        let cH = cropRect.height * imgSize.height

        ZStack {
            // Top
            let topH = cY - o.y
            if topH > 0 {
                Rectangle().fill(Color.black.opacity(0.55))
                    .frame(width: imgSize.width, height: topH)
                    .position(x: o.x + imgSize.width / 2, y: o.y + topH / 2)
                    .allowsHitTesting(false)
            }
            // Bottom
            let botY = cY + cH
            let botH = o.y + imgSize.height - botY
            if botH > 0 {
                Rectangle().fill(Color.black.opacity(0.55))
                    .frame(width: imgSize.width, height: botH)
                    .position(x: o.x + imgSize.width / 2, y: botY + botH / 2)
                    .allowsHitTesting(false)
            }
            // Left
            let leftW = cX - o.x
            if leftW > 0 {
                Rectangle().fill(Color.black.opacity(0.55))
                    .frame(width: leftW, height: cH)
                    .position(x: o.x + leftW / 2, y: cY + cH / 2)
                    .allowsHitTesting(false)
            }
            // Right
            let rightX = cX + cW
            let rightW = o.x + imgSize.width - rightX
            if rightW > 0 {
                Rectangle().fill(Color.black.opacity(0.55))
                    .frame(width: rightW, height: cH)
                    .position(x: rightX + rightW / 2, y: cY + cH / 2)
                    .allowsHitTesting(false)
            }

            // Border
            Rectangle()
                .stroke(Color.white.opacity(0.85), lineWidth: 1)
                .frame(width: cW, height: cH)
                .position(x: cX + cW / 2, y: cY + cH / 2)
                .allowsHitTesting(false)

            // Rule of thirds when dragging
            if isDragging {
                ForEach([1, 2], id: \.self) { i in
                    Rectangle().fill(Color.white.opacity(0.22))
                        .frame(width: 0.5, height: cH)
                        .position(x: cX + CGFloat(i) * cW / 3, y: cY + cH / 2)
                        .allowsHitTesting(false)
                    Rectangle().fill(Color.white.opacity(0.22))
                        .frame(width: cW, height: 0.5)
                        .position(x: cX + cW / 2, y: cY + CGFloat(i) * cH / 3)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Handles

    @ViewBuilder
    private func cropHandles(imgSize: CGSize, containerSize: CGSize) -> some View {
        let o = imgOrigin(imgSize: imgSize, containerSize: containerSize)
        let cX = o.x + cropRect.minX * imgSize.width
        let cY = o.y + cropRect.minY * imgSize.height
        let cW = cropRect.width  * imgSize.width
        let cH = cropRect.height * imgSize.height

        // Move gesture on crop interior
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(width: max(0, cW - 24), height: max(0, cH - 24))
            .position(x: cX + cW / 2, y: cY + cH / 2)
            .gesture(DragGesture(minimumDistance: 2)
                .onChanged { v in
                    startDrag(.move)
                    applyDrag(.move, t: v.translation, imgSize: imgSize)
                }
                .onEnded { _ in endDrag() }
            )

        let defs: [(HandleKind, CGFloat, CGFloat)] = [
            (.tl, cropRect.minX, cropRect.minY),
            (.tc, cropRect.midX, cropRect.minY),
            (.tr, cropRect.maxX, cropRect.minY),
            (.ml, cropRect.minX, cropRect.midY),
            (.mr, cropRect.maxX, cropRect.midY),
            (.bl, cropRect.minX, cropRect.maxY),
            (.bc, cropRect.midX, cropRect.maxY),
            (.br, cropRect.maxX, cropRect.maxY),
        ]

        ForEach(defs, id: \.0) { kind, nx, ny in
            let corner = kind == .tl || kind == .tr || kind == .bl || kind == .br
            Circle()
                .fill(Color.white)
                .frame(width: corner ? 12 : 8, height: corner ? 12 : 8)
                .shadow(color: .black.opacity(0.5), radius: 1.5)
                .position(x: o.x + nx * imgSize.width, y: o.y + ny * imgSize.height)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        startDrag(kind)
                        applyDrag(kind, t: v.translation, imgSize: imgSize)
                    }
                    .onEnded { _ in endDrag() }
                )
        }
    }

    private func startDrag(_ kind: HandleKind) {
        guard activeHandle != kind else { return }
        activeHandle = kind
        isDragging = true
        dragStartCrop = cropRect
    }

    private func endDrag() {
        activeHandle = nil
        isDragging = false
    }

    private func applyDrag(_ kind: HandleKind, t: CGSize, imgSize: CGSize) {
        let dx = t.width  / imgSize.width
        let dy = t.height / imgSize.height
        var r = dragStartCrop
        let minS: CGFloat = 0.05

        switch kind {
        case .tl:
            r.origin.x    = min(r.maxX - minS, r.origin.x + dx)
            r.size.width  = dragStartCrop.maxX - r.origin.x
            r.origin.y    = min(r.maxY - minS, r.origin.y + dy)
            r.size.height = dragStartCrop.maxY - r.origin.y
        case .tc:
            r.origin.y    = min(r.maxY - minS, r.origin.y + dy)
            r.size.height = dragStartCrop.maxY - r.origin.y
        case .tr:
            r.size.width  = max(minS, dragStartCrop.width + dx)
            r.origin.y    = min(r.maxY - minS, r.origin.y + dy)
            r.size.height = dragStartCrop.maxY - r.origin.y
        case .ml:
            r.origin.x   = min(r.maxX - minS, r.origin.x + dx)
            r.size.width = dragStartCrop.maxX - r.origin.x
        case .mr:
            r.size.width = max(minS, dragStartCrop.width + dx)
        case .bl:
            r.origin.x    = min(r.maxX - minS, r.origin.x + dx)
            r.size.width  = dragStartCrop.maxX - r.origin.x
            r.size.height = max(minS, dragStartCrop.height + dy)
        case .bc:
            r.size.height = max(minS, dragStartCrop.height + dy)
        case .br:
            r.size.width  = max(minS, dragStartCrop.width + dx)
            r.size.height = max(minS, dragStartCrop.height + dy)
        case .move:
            r.origin.x += dx
            r.origin.y += dy
        }

        r.origin.x    = max(0, min(1 - r.size.width,  r.origin.x))
        r.origin.y    = max(0, min(1 - r.size.height, r.origin.y))
        r.size.width  = min(1 - r.origin.x, max(minS, r.size.width))
        r.size.height = min(1 - r.origin.y, max(minS, r.size.height))

        cropRect = r
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button("Abbrechen") { viewModel.cropToolActive = false }

                Spacer()

                Image(systemName: "rotate.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $rotation, in: -45...45)
                    .frame(width: 160)
                Text(String(format: "%.1f°", rotation))
                    .font(.caption.monospacedDigit())
                    .frame(width: 36, alignment: .leading)
                    .foregroundColor(.secondary)
                Button(action: { rotation = 0 }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(rotation == 0)
                .foregroundColor(rotation == 0 ? Color(NSColor.tertiaryLabelColor) : .secondary)
                .help("Begradigung zurücksetzen")

                Spacer()

                Button("Zurücksetzen") {
                    cropRect = Self.defaultCrop
                    rotation = 0
                }
                .disabled(cropRect == Self.defaultCrop && rotation == 0)

                Button("Anwenden") { apply() }
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Apply

    private func apply() {
        viewModel.adjustments.cropRect = cropRect
        viewModel.adjustments.rotation = rotation
        viewModel.cropToolActive = false
    }
}
