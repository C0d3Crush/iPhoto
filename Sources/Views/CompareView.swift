import SwiftUI
import AppKit

struct CompareView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var hoveredSide: CompareVerdict? = nil
    @State private var leftZoom: CGFloat = 1.0
    @State private var rightZoom: CGFloat = 1.0
    @State private var leftFit: Bool = false
    @State private var rightFit: Bool = false
    @State private var distributionCollapsed: Bool = false
    @State private var paneInfoCollapsed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let left = viewModel.compareLeftDocument,
               let right = viewModel.compareRightDocument {
                HStack(spacing: 1) {
                    comparePane(doc: left, side: .left,
                                zoom: $leftZoom, fit: $leftFit)
                    Divider()
                    comparePane(doc: right, side: .right,
                                zoom: $rightZoom, fit: $rightFit)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                HStack(spacing: 0) {
                    if !distributionCollapsed {
                        distributionPanel
                    }
                    Spacer(minLength: 0)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            distributionCollapsed.toggle()
                        }
                    }) {
                        Image(systemName: distributionCollapsed ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: distributionCollapsed ? 20 : nil)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(distributionCollapsed ? "ELO-Verteilung einblenden" : "ELO-Verteilung ausblenden")
                    .padding(.trailing, 6)
                    .padding(.vertical, distributionCollapsed ? 4 : 0)
                }
                Divider()
                verdictBar
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Mindestens zwei Bilder nötig, um zu vergleichen.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Label("Bildvergleich", systemImage: "arrow.left.arrow.right")
                .font(.headline)
            Spacer()
            if viewModel.compareDailyLimit > 0 {
                let remaining = max(0, viewModel.compareDailyLimit - viewModel.compare.dailyCount)
                Text("\(remaining) / \(viewModel.compareDailyLimit)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(remaining == 0 ? .red : .secondary)
                    .help("Verbleibende Duelle heute")
            }
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { paneInfoCollapsed.toggle() }
            }) {
                Image(systemName: paneInfoCollapsed ? "info.circle" : "info.circle.fill")
                    .foregroundColor(.secondary)
                    .opacity(paneInfoCollapsed ? 0.5 : 0.9)
            }
            .buttonStyle(PlainButtonStyle())
            .help(paneInfoCollapsed ? "Bildinfos einblenden" : "Bildinfos ausblenden")
            Button(action: { viewModel.stopCompareMode() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Vergleich beenden")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func comparePane(doc: ImageDocument, side: CompareVerdict,
                             zoom: Binding<CGFloat>, fit: Binding<Bool>) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Color(NSColor.underPageBackgroundColor)
                if let cg = doc.cgImage ?? doc.previewImage ?? doc.thumbnail {
                    ZoomableScrollView(image: cg, zoomFactor: zoom, fitToWindow: fit,
                                       alwaysFitOnImageChange: true)
                } else if let ns = doc.thumbnailImage ?? doc.placeholderThumbnailImage,
                          let cg = ns.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    ZoomableScrollView(image: cg, zoomFactor: zoom, fitToWindow: fit,
                                       alwaysFitOnImageChange: true)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(hoveredSide == side ? Color.accentColor : Color.clear, lineWidth: 3)
                    .padding(2)
                    .allowsHitTesting(false)
            )
            .onHover { inside in
                hoveredSide = inside ? side : (hoveredSide == side ? nil : hoveredSide)
            }

            if !paneInfoCollapsed {
                HStack(spacing: 8) {
                    Button(action: { viewModel.resolveCompare(side) }) {
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.accentColor)
                    .help("Dieses Bild ist besser")

                    Text(doc.filename)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { fit.wrappedValue = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("An Pane anpassen")
                    Text("\(Int(zoom.wrappedValue * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
                .padding(.horizontal, 8)

                eloRow(elo: doc.elo, matches: doc.eloMatches)
                    .padding(.bottom, 8)
            }
        }
    }

    private func eloRow(elo: Double, matches: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
            Text("ELO \(Int(elo.rounded()))")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
            Text("· \(matches) Duell\(matches == 1 ? "" : "e")")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private var distributionPanel: some View {
        let docs = viewModel.visibleDocuments
        let elos = docs.map { $0.elo }
        let leftElo  = viewModel.compareLeftDocument?.elo
        let rightElo = viewModel.compareRightDocument?.elo
        let pts = Self.kdePoints(elos: elos)
        return EloAreaGraph(points: pts, leftElo: leftElo, rightElo: rightElo) { lo, hi in
            viewModel.stopCompareMode()
            viewModel.navSelection = .eloRange(lo, hi)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    // Gaussian KDE: 40 sample points over the actual ELO range.
    // Scott's bandwidth; capped at 300 samples for large libraries.
    private static func kdePoints(elos: [Double], sampleCount: Int = 40) -> [(x: Double, y: Double)] {
        guard elos.count >= 2 else {
            let x = elos.first ?? 1500
            return [(x: x - 200, y: 0), (x: x, y: 1), (x: x + 200, y: 0)]
        }
        let n = Double(elos.count)
        let mean = elos.reduce(0, +) / n
        let variance = elos.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / n
        let h = max(1.06 * sqrt(variance) * pow(n, -0.2), 20)

        let lo = (elos.min() ?? 1000) - h * 2.5
        let hi = (elos.max() ?? 2000) + h * 2.5
        let step = (hi - lo) / Double(sampleCount - 1)

        let sample: [Double] = elos.count <= 300 ? elos : stride(from: 0, to: elos.count, by: elos.count / 300).map { elos[$0] }
        let ns = Double(sample.count)
        let norm = ns * h * sqrt(2 * .pi)

        return (0..<sampleCount).map { i in
            let x = lo + Double(i) * step
            let density = sample.reduce(0.0) { acc, xi in
                let z = (x - xi) / h
                return acc + exp(-0.5 * z * z)
            } / norm
            return (x: x, y: density)
        }
    }

    private var verdictBar: some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.resolveCompare(.left) }) {
                Label("Links ist besser", systemImage: "arrow.left")
            }
            .help("Pfeiltaste ←")
            Button(action: { viewModel.resolveCompare(.equal) }) {
                Label("Gleich gut", systemImage: "equal")
            }
            .help("Pfeiltaste ↑")
            Button(action: { viewModel.resolveCompare(.right) }) {
                Label("Rechts ist besser", systemImage: "arrow.right")
            }
            .help("Pfeiltaste →")
            Divider().frame(height: 18)
            Button(action: { viewModel.nextComparePair() }) {
                Label("Überspringen", systemImage: "arrow.uturn.forward")
            }
            .help("Pfeiltaste ↓")
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ELO Area Graph (KDE)

private struct EloAreaGraph: View {
    let points: [(x: Double, y: Double)]   // KDE sample points, sorted by x
    let leftElo:  Double?
    let rightElo: Double?
    let onSelectRange: (Double, Double) -> Void   // (loElo, hiElo)

    @State private var hoverX:    CGFloat? = nil
    @State private var dragStartX: CGFloat? = nil
    @State private var dragEndX:   CGFloat? = nil

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack {
                    gridLines(in: geo.size)
                    areaPath(in: geo.size)
                        .fill(areaGradient)
                    linePath(in: geo.size)
                        .stroke(lineGradient, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    eloMarkers(in: geo.size)
                    rangeSelection(in: geo.size)
                    hoverCursor(in: geo.size)
                }
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside { NSCursor.crosshair.push() } else { NSCursor.pop(); hoverX = nil }
                }
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { v in
                            if dragStartX == nil { dragStartX = max(0, min(v.startLocation.x, geo.size.width)) }
                            dragEndX = max(0, min(v.location.x, geo.size.width))
                            hoverX = dragEndX
                        }
                        .onEnded { v in
                            let start = dragStartX ?? 0
                            let end   = max(0, min(v.location.x, geo.size.width))
                            let loElo = eloAt(screenX: min(start, end), width: geo.size.width)
                            let hiElo = eloAt(screenX: max(start, end), width: geo.size.width)
                            dragStartX = nil; dragEndX = nil; hoverX = nil
                            // Minimum range of 20 ELO so a near-click still selects something
                            let margin = max((hiElo - loElo) < 20 ? 10 : 0, 0.0)
                            onSelectRange(loElo - margin, hiElo + margin)
                        }
                )
            }
            .frame(height: 72)

            xAxisLabels
        }
    }

    // MARK: - Coordinate helpers

    private var xMin: Double { points.first?.x ?? 0 }
    private var xMax: Double { points.last?.x  ?? 1 }
    private var xRange: Double { max(xMax - xMin, 1) }
    private var yMax: Double { max(points.map { $0.y }.max() ?? 0, 1e-10) }

    private func xScreen(_ elo: Double, width: CGFloat) -> CGFloat {
        CGFloat((elo - xMin) / xRange) * width
    }

    private func yScreen(_ density: Double, height: CGFloat) -> CGFloat {
        height - CGFloat(density / yMax) * (height - 6)
    }

    // MARK: - Paths

    private func linePath(in size: CGSize) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        path.move(to: CGPoint(x: xScreen(points[0].x, width: size.width),
                              y: yScreen(points[0].y, height: size.height)))
        for i in 1..<points.count {
            let px = xScreen(points[i-1].x, width: size.width)
            let py = yScreen(points[i-1].y, height: size.height)
            let cx = xScreen(points[i].x, width: size.width)
            let cy = yScreen(points[i].y, height: size.height)
            let cpx = px + (cx - px) * 0.5
            path.addCurve(to: CGPoint(x: cx, y: cy),
                          control1: CGPoint(x: cpx, y: py),
                          control2: CGPoint(x: cpx, y: cy))
        }
        return path
    }

    private func areaPath(in size: CGSize) -> Path {
        var path = linePath(in: size)
        guard !points.isEmpty else { return path }
        path.addLine(to: CGPoint(x: xScreen(points.last!.x, width: size.width), y: size.height))
        path.addLine(to: CGPoint(x: xScreen(points.first!.x, width: size.width), y: size.height))
        path.closeSubpath()
        return path
    }

    private func gridLines(in size: CGSize) -> some View {
        Path { p in
            for t in [0.25, 0.5, 0.75, 1.0] {
                let y = size.height - CGFloat(t) * (size.height - 6)
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color.secondary.opacity(0.08), lineWidth: 0.5)
    }

    // Vertical markers for the two compared images
    private func eloMarkers(in size: CGSize) -> some View {
        let pairs: [(Double, Color)] = [
            leftElo.map  { ($0, Color.accentColor) },
            rightElo.map { ($0, Color.orange) }
        ].compactMap { $0 }
        return ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
            let (elo, color) = pair
            let xp = xScreen(elo, width: size.width)
            Path { p in
                p.move(to:    CGPoint(x: xp, y: size.height))
                p.addLine(to: CGPoint(x: xp, y: 0))
            }
            .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }

    private func rangeSelection(in size: CGSize) -> some View {
        Group {
            if let start = dragStartX, let end = dragEndX {
                let lo = min(start, end)
                let hi = max(start, end)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: max(hi - lo, 1), height: size.height)
                    .position(x: lo + (hi - lo) / 2, y: size.height / 2)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: 1.5, height: size.height)
                    .position(x: lo, y: size.height / 2)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: 1.5, height: size.height)
                    .position(x: hi, y: size.height / 2)
                // ELO labels at edges
                Text("\(Int(eloAt(screenX: lo, width: size.width).rounded()))")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.accentColor)
                    .position(x: lo + 18, y: 8)
                Text("\(Int(eloAt(screenX: hi, width: size.width).rounded()))")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.accentColor)
                    .position(x: hi - 18, y: 8)
            }
        }
    }

    private func nearestDensity(for elo: Double) -> Double {
        guard !points.isEmpty else { return 0 }
        return points.min(by: { abs($0.x - elo) < abs($1.x - elo) })?.y ?? 0
    }

    private func eloAt(screenX: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return xMin }
        return xMin + Double(screenX / width) * xRange
    }

    private func hoverCursor(in size: CGSize) -> some View {
        Group {
            if let hx = hoverX {
                let elo = eloAt(screenX: hx, width: size.width)
                let density = nearestDensity(for: elo)
                let yp = yScreen(density, height: size.height)
                Path { p in
                    p.move(to:    CGPoint(x: hx, y: size.height))
                    p.addLine(to: CGPoint(x: hx, y: 0))
                }
                .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .offset(x: hx - 3, y: yp - 3)
                Text("\(Int(elo.rounded()))")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .offset(x: hx + 4, y: min(yp - 10, size.height - 14))
            }
        }
    }

    // MARK: - X-Axis

    private var xAxisLabels: some View {
        // Show 6 evenly-spaced ELO tick labels across the range
        let ticks = 6
        let step = xRange / Double(ticks - 1)
        let labels = (0..<ticks).map { Int((xMin + Double($0) * step).rounded()) }
        return HStack(spacing: 0) {
            ForEach(labels, id: \.self) { v in
                Text("\(v)")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.55))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Gradients

    private var areaGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color(red: 0.3, green: 0.75, blue: 0.4).opacity(0.35),
                                        Color(red: 0.3, green: 0.75, blue: 0.4).opacity(0.04)]),
            startPoint: .top, endPoint: .bottom
        )
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.red, .orange, .yellow,
                                        Color(red: 0.5, green: 0.85, blue: 0.5), .green, .accentColor]),
            startPoint: .leading, endPoint: .trailing
        )
    }
}
