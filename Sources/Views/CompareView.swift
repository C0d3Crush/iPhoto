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
