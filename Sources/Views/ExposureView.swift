import SwiftUI
import AppKit

struct ExposureView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var shadowThresh: Double = ExposureDetector.defaultShadowClipThreshold
    @State private var highlightThresh: Double = ExposureDetector.defaultHighlightClipThreshold

    private var isUnder: Bool { viewModel.navSelection == .underexposed }

    private var docs: [ImageDocument] {
        isUnder ? viewModel.quality.underexposedDocuments : viewModel.quality.overexposedDocuments
    }

    private var pendingCount: Int {
        viewModel.collection.documents.filter { !$0.isTrashed && !$0.qualityScanned }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if docs.isEmpty {
                emptyState
            } else {
                imageGrid
            }
        }
        .onAppear {
            shadowThresh = viewModel.quality.shadowClipThreshold
            highlightThresh = viewModel.quality.highlightClipThreshold
            viewModel.refreshQualityLists()
            if pendingCount > 0 { viewModel.scanQualityForLibrary() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isUnder ? "Unterbelichtete Bilder" : "Überbelichtete Bilder")
                    .font(.title2).fontWeight(.semibold)
                if docs.isEmpty {
                    Text(pendingCount > 0
                         ? "\(pendingCount) Bilder werden noch analysiert…"
                         : "Keine \(isUnder ? "unterbelichteten" : "überbelichteten") Bilder gefunden")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text("\(docs.count) \(docs.count == 1 ? "Bild" : "Bilder") erkannt" +
                         (pendingCount > 0 ? " · \(pendingCount) noch offen" : ""))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()

            HStack(spacing: 6) {
                Text(isUnder ? "Schatten-Clip:" : "Lichter-Clip:")
                    .font(.caption).foregroundColor(.secondary)
                Slider(
                    value: isUnder ? $shadowThresh : $highlightThresh,
                    in: 0.01...0.30, step: 0.01
                )
                .frame(width: 110)
                .onChange(of: shadowThresh) { newValue in
                    viewModel.quality.shadowClipThreshold = newValue
                }
                .onChange(of: highlightThresh) { newValue in
                    viewModel.quality.highlightClipThreshold = newValue
                }
                Text(String(format: "%.0f %%", (isUnder ? shadowThresh : highlightThresh) * 100))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }

            Button("Neu scannen") {
                viewModel.scanQualityForLibrary()
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.accentColor)

            if !docs.isEmpty {
                Button("Alle in Papierkorb") {
                    viewModel.moveToAppTrash(docs)
                    viewModel.refreshQualityLists()
                }
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: pendingCount > 0 ? "hourglass" : "checkmark.circle")
                .font(.system(size: 52))
                .foregroundColor(pendingCount > 0 ? .accentColor : .green)
            Text(pendingCount > 0
                 ? "Analyse läuft"
                 : (isUnder ? "Keine unterbelichteten Bilder" : "Keine überbelichteten Bilder"))
                .font(.title3).fontWeight(.medium)
            Text(pendingCount > 0
                 ? "Noch \(pendingCount) Bilder müssen analysiert werden."
                 : "Alle Bilder liegen innerhalb des gewählten Belichtungs-Schwellenwerts.")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 320)
            Button("Neu scannen") { viewModel.scanQualityForLibrary() }.padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var imageGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 10)],
                spacing: 10
            ) {
                ForEach(docs) { doc in
                    let colIdx = viewModel.collectionIndex(for: doc)
                    let isSelected = colIdx.map { viewModel.collection.selectedIndices.contains($0) } ?? false
                    ExposureDocTile(doc: doc, isUnder: isUnder, isSelected: isSelected) {
                        viewModel.moveToAppTrash([doc])
                        viewModel.refreshQualityLists()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { openDetail(for: doc) }
                    .onTapGesture { handleTap(for: doc) }
                    .contextMenu { ThumbnailContextMenu(doc: doc).environmentObject(viewModel) }
                }
            }
            .padding(16)
        }
    }

    private func handleTap(for doc: ImageDocument) {
        guard let idx = viewModel.collectionIndex(for: doc) else { return }
        let flags = viewModel.lastClickModifiers
        if flags.contains(.command) {
            viewModel.toggleSelection(at: idx)
        } else if flags.contains(.shift) {
            viewModel.extendSelection(to: idx)
        } else {
            viewModel.selectDocument(at: idx)
        }
    }

    private func openDetail(for doc: ImageDocument) {
        guard let idx = viewModel.collectionIndex(for: doc) else { return }
        viewModel.selectDocument(at: idx)
        viewModel.qualityDetailActive = true
    }

}

private struct ExposureDocTile: View {
    let doc: ImageDocument
    let isUnder: Bool
    let isSelected: Bool
    let onTrash: () -> Void

    private var accentColor: Color { isUnder ? .purple : .yellow }
    private var icon: String { isUnder ? "moon.fill" : "sun.max.fill" }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = doc.thumbnailImage ?? doc.placeholderThumbnailImage {
                        Image(nsImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 150, height: 110).clipped()
                    } else {
                        Color.secondary.opacity(0.15)
                            .frame(width: 150, height: 110)
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    }
                }
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? Color.accentColor : accentColor.opacity(0.6),
                            lineWidth: isSelected ? 3 : 1.5))

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(accentColor)
                    .background(Circle().fill(Color.white).padding(2))
                    .padding(5)
            }

            Text(doc.filename)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1).frame(width: 150, alignment: .leading)

            HStack(spacing: 4) {
                if doc.isRAW {
                    Text("RAW")
                        .font(.system(size: 8, weight: .semibold)).foregroundColor(.orange)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.orange.opacity(0.12)).cornerRadius(3)
                }
                Spacer()
                Button(action: onTrash) {
                    Image(systemName: "trash").font(.system(size: 10)).foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 150)
        }
        .frame(width: 150)
    }
}
