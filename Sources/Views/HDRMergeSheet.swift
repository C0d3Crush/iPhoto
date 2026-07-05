import SwiftUI

struct HDRMergeSheet: View {
    @EnvironmentObject var vm: ImageViewModel
    @Binding var isPresented: Bool

    let docs: [ImageDocument]

    @State private var sigma: Double = 0.2

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    exposureList
                    Divider().padding(.vertical, 2)
                    sigmaControl
                    infoText
                    statusArea
                }
                .padding(.vertical, 8)
            }
            Divider()
            footer
        }
        .frame(width: 400)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("HDR zusammenführen")
                .font(.headline)
            Spacer()
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }

    private var exposureList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(docs.count) Belichtungen:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ForEach(docs) { doc in
                HStack(spacing: 10) {
                    thumbnailView(for: doc)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.filename)
                            .font(.caption)
                            .lineLimit(1)
                        if let bias = ImageViewModel.exposureBias(at: doc.url) {
                            Text(formatBias(bias))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }

    private var sigmaControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Belichtungstoleranz")
                    .font(.subheadline)
                Spacer()
                Text(String(format: "σ = %.2f", sigma))
                    .font(.caption)
                    .foregroundColor(.secondary)

            }
            Slider(value: $sigma, in: 0.05...0.5)
            Text("Kleiner = nur optimal belichtete Pixel; größer = sanftere Übergänge.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .disabled(vm.isHDRMerging)
    }

    private var infoText: some View {
        Text("Die Belichtungsreihe wird nach Mertens Exposure Fusion zusammengeführt und als TIFF im gleichen Ordner gespeichert.")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)
    }

    @ViewBuilder
    private var statusArea: some View {
        if let err = vm.hdrMergeError {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(.horizontal)
        } else if let url = vm.hdrMergeResultURL {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Gespeichert: \(url.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal)
        }
    }

    private var footer: some View {
        HStack {
            Button("Abbrechen") { isPresented = false }
                .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            if vm.isHDRMerging {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Wird berechnet…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if vm.hdrMergeResultURL != nil {
                Button("Fertig") { isPresented = false }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(DefaultButtonStyle())
            } else {
                Button("Zusammenführen") {
                    var opts = HDRMerger.Options()
                    opts.sigma = Float(sigma)
                    vm.mergeHDR(docs: docs, options: opts)
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(DefaultButtonStyle())
                .disabled(docs.count < 2)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func thumbnailView(for doc: ImageDocument) -> some View {
        Group {
            if let img = doc.thumbnailImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .frame(width: 52, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func formatBias(_ bias: Double) -> String {
        if bias == 0 { return "0 EV" }
        return String(format: "%+.1f EV", bias)
    }
}
