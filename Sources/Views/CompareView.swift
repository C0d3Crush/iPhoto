import SwiftUI
import AppKit

struct CompareView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var hoveredSide: CompareVerdict? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let left = viewModel.compareLeftDocument,
               let right = viewModel.compareRightDocument {
                HStack(spacing: 1) {
                    comparePane(doc: left, side: .left)
                    Divider()
                    comparePane(doc: right, side: .right)
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

    private func comparePane(doc: ImageDocument, side: CompareVerdict) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Color(NSColor.underPageBackgroundColor)
                if let cg = doc.cgImage ?? doc.previewImage ?? doc.thumbnail {
                    Image(nsImage: NSImage(cgImage: cg, size: .zero))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                } else if let ns = doc.thumbnailImage ?? doc.placeholderThumbnailImage {
                    // Grobes Grid-Thumbnail als Sofort-Anzeige, bis das 1500px-Preview da ist
                    Image(nsImage: ns)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(hoveredSide == side ? Color.accentColor : Color.clear, lineWidth: 3)
                    .padding(2)
            )
            .contentShape(Rectangle())
            .onTapGesture { viewModel.resolveCompare(side) }
            .onHover { inside in
                hoveredSide = inside ? side : (hoveredSide == side ? nil : hoveredSide)
            }
            .help("Klicken: dieses Bild ist besser")

            Text(doc.filename)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.secondary)
            starRow(rating: doc.rating)
                .padding(.bottom, 8)
        }
    }

    private func starRow(rating: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundColor(i <= rating ? .yellow : .secondary)
            }
        }
    }

    private var distributionPanel: some View {
        let docs = viewModel.visibleDocuments
        let total = max(1, docs.count)
        return HStack(alignment: .center, spacing: 14) {
            ForEach([1, 2, 3, 4, 5], id: \.self) { stars in
                RatingDistributionColumn(
                    stars: stars,
                    current: Double(docs.filter { $0.rating == stars }.count) / Double(total),
                    target: ImageViewModel.compareRatingTargets[stars] ?? 0.0
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

private struct RatingDistributionColumn: View {
    let stars: Int
    let current: Double
    let target: Double

    var body: some View {
        VStack(spacing: 4) {
            starIcons
            barChart
            Text("\(Int((current * 100).rounded())) %")
                .font(.system(size: 9).monospacedDigit())
                .foregroundColor(.secondary)
            Text("Soll: \(Int(target * 100)) %")
                .font(.system(size: 8))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }

    private var starIcons: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: 7))
                    .foregroundColor(i <= stars ? .yellow : Color.yellow.opacity(0.15))
            }
        }
    }

    private var barChart: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(height: geo.size.height * CGFloat(current))
                    .frame(maxWidth: .infinity)
                Rectangle()
                    .fill(Color.primary.opacity(0.45))
                    .frame(height: 1.5)
                    .offset(y: -geo.size.height * CGFloat(target))
            }
        }
        .frame(width: 36, height: 48)
    }

    private var barColor: Color {
        let diff = current - target
        if diff > 0.07 { return .orange }
        if diff < -0.07 { return Color.accentColor.opacity(0.55) }
        return .green.opacity(0.75)
    }
}
