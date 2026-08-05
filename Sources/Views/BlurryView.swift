import SwiftUI
import AppKit

struct BlurryView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isScanning = false
    @State private var threshold: Double = BlurDetector.defaultThreshold

    private var docs: [ImageDocument] { viewModel.quality.blurryDocuments }

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
            threshold = viewModel.quality.blurThreshold
            if docs.isEmpty { scan() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Unscharfe Bilder")
                    .font(.title2).fontWeight(.semibold)
                if docs.isEmpty && !isScanning {
                    Text("Keine unscharfen Bilder gefunden")
                        .font(.caption).foregroundColor(.secondary)
                } else if !isScanning {
                    Text("\(docs.count) \(docs.count == 1 ? "Bild" : "Bilder") erkannt")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()

            HStack(spacing: 6) {
                Text("Schwellenwert:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $threshold, in: 20...400, step: 10)
                    .frame(width: 110)
                Text(String(format: "%.0f", threshold))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }

            Button("Neu scannen") {
                viewModel.quality.blurThreshold = threshold
                scan()
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.accentColor)
            .disabled(isScanning)

            if !docs.isEmpty {
                Button("Alle in Papierkorb") {
                    viewModel.moveToAppTrash(docs)
                    viewModel.quality.blurryDocuments = []
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
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            Text("Bilder werden analysiert…")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 52))
                .foregroundColor(.green)
            Text("Keine unscharfen Bilder")
                .font(.title3).fontWeight(.medium)
            Text("Alle Bilder haben ausreichend Schärfe bei dem gewählten Schwellenwert.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("Neu scannen") { scan() }
                .padding(.top, 4)
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
                    BlurryDocTile(doc: doc, isSelected: isSelected) {
                        viewModel.moveToAppTrash([doc])
                        viewModel.quality.blurryDocuments.removeAll { $0.id == doc.id }
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
        viewModel.quality.blurThreshold = threshold
        let docs = viewModel.collection.documents.filter { !$0.isTrashed }
        let thresh = threshold
        let taskID = UUID()
        viewModel.activity.enqueue(id: taskID, label: "Unschärfe analysieren…",
                                    icon: "drop.triangle.fill",
                                    done: 0, total: docs.count, summaryVerb: "analysiert")
        DispatchQueue.global(qos: .utility).async {
            var blurry: [ImageDocument] = []
            for (i, doc) in docs.enumerated() {
                let src: CGImage?
                if let thumb = doc.thumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = thumb
                } else if let ph = doc.placeholderThumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = ph
                } else {
                    src = try? RAWImageDecoder.thumbnail(url: doc.url, maxDimension: 512)
                }
                if let img = src, BlurDetector.score(from: img) < thresh {
                    blurry.append(doc)
                }
                let done = i + 1
                if done % 10 == 0 || done == docs.count {
                    DispatchQueue.main.async {
                        viewModel.activity.update(id: taskID, done: done, total: docs.count)
                    }
                }
            }
            let sorted = blurry.sorted { $0.filename < $1.filename }
            DispatchQueue.main.async {
                viewModel.quality.blurryDocuments = sorted
                viewModel.activity.dequeue(id: taskID)
                isScanning = false
            }
        }
    }
}

private struct BlurryDocTile: View {
    let doc: ImageDocument
    let isSelected: Bool
    let onTrash: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = doc.thumbnailImage ?? doc.placeholderThumbnailImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 110)
                            .clipped()
                    } else {
                        Color.secondary.opacity(0.15)
                            .frame(width: 150, height: 110)
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    }
                }
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? Color.accentColor : Color.purple.opacity(0.5),
                                lineWidth: isSelected ? 3 : 1.5)
                )

                Image(systemName: "drop.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.purple)
                    .background(Circle().fill(Color.white).padding(2))
                    .padding(5)
            }

            Text(doc.filename)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            HStack(spacing: 4) {
                if doc.isRAW {
                    Text("RAW")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(3)
                }
                Spacer()
                Button(action: onTrash) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 150)
        }
        .frame(width: 150)
    }
}
