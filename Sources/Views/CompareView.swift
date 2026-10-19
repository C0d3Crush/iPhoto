import SwiftUI
import AppKit

struct CompareView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var hoveredSide: CompareVerdict? = nil
    @State private var leftZoom: CGFloat = 1.0
    @State private var rightZoom: CGFloat = 1.0
    @State private var leftFit: Bool = false
    @State private var rightFit: Bool = false

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
                distributionPanel
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
        let total = max(1, docs.count)
        let buckets = ImageViewModel.compareEloBuckets
        let fractions = buckets.map { bucket in
            Double(docs.filter { bucket.range.contains($0.elo) }.count) / Double(total)
        }
        return EloAreaGraph(buckets: buckets, fractions: fractions)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
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

// MARK: - ELO Area Graph

private struct EloAreaGraph: View {
    let buckets: [ImageViewModel.EloBucket]
    let fractions: [Double]

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack {
                    areaPath(in: geo.size)
                        .fill(areaGradient)
                    linePath(in: geo.size)
                        .stroke(lineGradient, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    dots(in: geo.size)
                    gridLines(in: geo.size)
                }
            }
            .frame(height: 72)

            // X-Achsenbeschriftungen
            HStack(spacing: 0) {
                ForEach(Array(buckets.enumerated()), id: \.element.id) { i, bucket in
                    VStack(spacing: 1) {
                        Text("\(Int((fractions[i] * 100).rounded())) %")
                            .font(.system(size: 8).monospacedDigit())
                            .foregroundColor(fractions[i] > 0 ? bucketColor(i).opacity(0.9) : .secondary.opacity(0.35))
                        Text(bucket.label)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Paths

    private func xPos(_ i: Int, width: CGFloat) -> CGFloat {
        let count = CGFloat(buckets.count - 1)
        return count == 0 ? width / 2 : CGFloat(i) / count * width
    }

    private func yPos(_ fraction: Double, height: CGFloat) -> CGFloat {
        let maxF = max(fractions.max() ?? 0, 0.001)
        return height - CGFloat(fraction / maxF) * (height - 6)
    }

    private func linePath(in size: CGSize) -> Path {
        var path = Path()
        guard !fractions.isEmpty else { return path }
        path.move(to: CGPoint(x: xPos(0, width: size.width),
                              y: yPos(fractions[0], height: size.height)))
        for i in 1..<fractions.count {
            let x = xPos(i, width: size.width)
            let y = yPos(fractions[i], height: size.height)
            let prevX = xPos(i - 1, width: size.width)
            let prevY = yPos(fractions[i - 1], height: size.height)
            let cp1 = CGPoint(x: prevX + (x - prevX) * 0.5, y: prevY)
            let cp2 = CGPoint(x: prevX + (x - prevX) * 0.5, y: y)
            path.addCurve(to: CGPoint(x: x, y: y), control1: cp1, control2: cp2)
        }
        return path
    }

    private func areaPath(in size: CGSize) -> Path {
        var path = linePath(in: size)
        guard !fractions.isEmpty else { return path }
        path.addLine(to: CGPoint(x: xPos(fractions.count - 1, width: size.width),
                                 y: size.height))
        path.addLine(to: CGPoint(x: xPos(0, width: size.width), y: size.height))
        path.closeSubpath()
        return path
    }

    private func dots(in size: CGSize) -> some View {
        ForEach(Array(fractions.enumerated()), id: \.offset) { i, f in
            if f > 0 {
                Circle()
                    .fill(bucketColor(i))
                    .frame(width: 6, height: 6)
                    .offset(x: xPos(i, width: size.width) - 3,
                            y: yPos(f, height: size.height) - 3)
            }
        }
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

    // MARK: - Gradients (macOS 11 kompatibel — kein LinearGradient über stops mit Color)

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

    private func bucketColor(_ i: Int) -> Color {
        switch i {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return Color(red: 0.5, green: 0.85, blue: 0.5)
        case 4: return .green
        default: return .accentColor
        }
    }
}
