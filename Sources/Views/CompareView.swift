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
        return HStack(alignment: .center, spacing: 12) {
            ForEach(ImageViewModel.compareEloBuckets) { bucket in
                EloDistributionColumn(
                    bucket: bucket,
                    current: Double(docs.filter { bucket.range.contains($0.elo) }.count) / Double(total)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
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

private struct EloDistributionColumn: View {
    let bucket: ImageViewModel.EloBucket
    let current: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(bucket.short)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(bucketColor)
            barChart
            Text("\(Int((current * 100).rounded())) %")
                .font(.system(size: 9).monospacedDigit())
                .foregroundColor(.secondary)
            Text(bucket.label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }

    private var barChart: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                RoundedRectangle(cornerRadius: 2)
                    .fill(bucketColor.opacity(0.75))
                    .frame(height: geo.size.height * CGFloat(min(1.0, current * 2.5)))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 36, height: 48)
    }

    // Farbverlauf über die Buckets: rot für schwache ELO, gelb Mitte, grün für starke.
    // Kein .mint (macOS 12+) — App unterstützt macOS 11.7.
    private var bucketColor: Color {
        switch bucket.id {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return Color(red: 0.5, green: 0.85, blue: 0.5)
        case 4: return .green
        default: return .accentColor
        }
    }
}
