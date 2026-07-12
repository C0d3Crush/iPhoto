import SwiftUI

struct HDRMergeSheet: View {
    @EnvironmentObject var vm: ImageViewModel
    @Binding var isPresented: Bool

    let docs: [ImageDocument]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    exposureList
                    Divider().padding(.vertical, 2)
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
            Button { isPresented = false } label: {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
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
                        Text(doc.filename).font(.caption).lineLimit(1)
                        if let bias = ImageViewModel.exposureBias(at: doc.url) {
                            Text(bias == 0 ? "0 EV" : String(format: "%+.1f EV", bias))
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }

    private var infoText: some View {
        Text("Belichtungsreihe wird per Laplacian-Pyramid-Fusion zusammengeführt. Alle Gewichte (Kontrast, Sättigung, Belichtung) werden automatisch berechnet. Ergebnis als TIFF im selben Ordner.")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)
    }

    @ViewBuilder
    private var statusArea: some View {
        if let err = vm.hdr.error {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                Text(err).font(.caption).foregroundColor(.red)
            }
            .padding(.horizontal)
        } else if let url = vm.hdr.resultURL {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Gespeichert: \(url.lastPathComponent)")
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            .padding(.horizontal)
        }
    }

    private var footer: some View {
        HStack {
            Button("Abbrechen") { isPresented = false }
                .keyboardShortcut(.escape, modifiers: [])
            Spacer()
            if vm.hdr.isMerging {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Wird berechnet…").font(.caption).foregroundColor(.secondary)
                }
            } else if vm.hdr.resultURL != nil {
                Button("Fertig") { isPresented = false }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(DefaultButtonStyle())
            } else {
                Button("Zusammenführen") {
                    vm.mergeHDR(docs: docs)
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
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .frame(width: 52, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
