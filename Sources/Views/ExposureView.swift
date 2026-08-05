import SwiftUI
import AppKit

struct ExposureView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isScanning = false
    @State private var shadowThresh: Double = ExposureDetector.defaultShadowClipThreshold
    @State private var highlightThresh: Double = ExposureDetector.defaultHighlightClipThreshold

    private var isUnder: Bool { viewModel.navSelection == .underexposed }

    private var docs: [ImageDocument] {
        isUnder ? viewModel.underexposedDocuments : viewModel.overexposedDocuments
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if isScanning {
                scanningState
            } else if docs.isEmpty {
                emptyState
            } else {
                imageGrid
            }
        }
        .onAppear {
            shadowThresh = viewModel.shadowClipThreshold
            highlightThresh = viewModel.highlightClipThreshold
            if docs.isEmpty { scan() }
        }
        .onChange(of: viewModel.navSelection) { _ in
            if docs.isEmpty && !isScanning { scan() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isUnder ? "Unterbelichtete Bilder" : "Überbelichtete Bilder")
                    .font(.title2).fontWeight(.semibold)
                if docs.isEmpty && !isScanning {
                    Text("Keine \(isUnder ? "unterbelichteten" : "überbelichteten") Bilder gefunden")
                        .font(.caption).foregroundColor(.secondary)
                } else if !isScanning {
                    Text("\(docs.count) \(docs.count == 1 ? "Bild" : "Bilder") erkannt")
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
                Text(String(format: "%.0f %%", (isUnder ? shadowThresh : highlightThresh) * 100))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }

            Button("Neu scannen") {
                viewModel.shadowClipThreshold = shadowThresh
                viewModel.highlightClipThreshold = highlightThresh
                scan()
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.accentColor)
            .disabled(isScanning)

            if !docs.isEmpty {
                Button("Alle in Papierkorb") {
                    viewModel.moveToAppTrash(docs)
                    if isUnder { viewModel.underexposedDocuments = [] }
                    else       { viewModel.overexposedDocuments   = [] }
                }
                .foregroundColor(.red)
                .disabled(isScanning)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var scanningState: some View {
        VStack(spacing: 14) {
            ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1.2)
            Text("Bilder werden analysiert…")
                .font(.callout).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 52)).foregroundColor(.green)
            Text(isUnder ? "Keine unterbelichteten Bilder" : "Keine überbelichteten Bilder")
                .font(.title3).fontWeight(.medium)
            Text("Alle Bilder liegen innerhalb des gewählten Belichtungs-Schwellenwerts.")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 320)
            Button("Neu scannen") { scan() }.padding(.top, 4)
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
                        if isUnder { viewModel.underexposedDocuments.removeAll { $0.id == doc.id } }
                        else       { viewModel.overexposedDocuments.removeAll   { $0.id == doc.id } }
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

    private func scan() {
        isScanning = true
        viewModel.shadowClipThreshold    = shadowThresh
        viewModel.highlightClipThreshold = highlightThresh
        let shadT = shadowThresh
        let highT = highlightThresh
        let allDocs = viewModel.collection.documents.filter { !$0.isTrashed }
        DispatchQueue.global(qos: .utility).async {
            var under: [ImageDocument] = []
            var over:  [ImageDocument] = []
            for doc in allDocs {
                let src: CGImage?
                if let t = doc.thumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = t
                } else if let p = doc.placeholderThumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = p
                } else {
                    src = try? RAWImageDecoder.thumbnail(url: doc.url, maxDimension: 512)
                }
                guard let img = src else { continue }
                let r = ExposureDetector.analyze(from: img)
                if r.underRatio >= shadT { under.append(doc) }
                if r.overRatio  >= highT { over.append(doc)  }
            }
            DispatchQueue.main.async {
                viewModel.underexposedDocuments = under.sorted { $0.filename < $1.filename }
                viewModel.overexposedDocuments  = over.sorted  { $0.filename < $1.filename }
                isScanning = false
            }
        }
    }
}

private struct ExposureDocTile: View {
    let doc: ImageDocument
    let isUnder: Bool
    let isSelected: Bool
    let onTrash: () -> Void

    private var accentColor: Color { isUnder ? .purple : .yellow }
    private var icon: String { isUnder ? "circle.lefthalf.filled" : "circle.righthalf.filled" }

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
