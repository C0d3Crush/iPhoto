import SwiftUI
import AppKit

private class ExportState: ObservableObject {
    enum Scope { case current, selection, all }
    enum Phase { case idle, exporting, done, failed(String) }

    @Published var format: ExportFormat = .jpeg
    @Published var quality: Double = 85
    @Published var scope: Scope = .current
    @Published var phase: Phase = .idle
    @Published var completedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var result: ExportResult? = nil
}

struct ExportSheet: View {
    let documents: [ImageDocument]
    let selectedDocuments: [ImageDocument]
    let currentDocument: ImageDocument?
    @Binding var isPresented: Bool

    @StateObject private var state = ExportState()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text("Exportieren")
                .font(.title2).bold()

            Divider()

            // Format
            row(label: "Format") {
                Picker("", selection: $state.format) {
                    ForEach(ExportFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 280)
            }

            // Qualität (nur JPEG / HEIF)
            if state.format.supportsQuality {
                row(label: "Qualität") {
                    Slider(value: $state.quality, in: 0...100, step: 1)
                        .frame(width: 210)
                    Text("\(Int(state.quality)) %")
                        .frame(width: 40, alignment: .trailing)
                        .foregroundColor(.secondary)
                }
            }

            // Umfang
            row(label: "Umfang") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        radioButton(selected: state.scope == .current, label: "Aktuelles Bild") {
                            state.scope = .current
                        }
                    }
                    if selectedDocuments.count > 1 {
                        HStack {
                            radioButton(selected: state.scope == .selection,
                                        label: "Auswahl (\(selectedDocuments.count) Bilder)") {
                                state.scope = .selection
                            }
                        }
                    }
                    HStack {
                        radioButton(selected: state.scope == .all,
                                    label: "Alle Bilder (\(documents.count))") {
                            state.scope = .all
                        }
                    }
                }
            }
            .disabled(currentDocument == nil)
            .onAppear {
                if selectedDocuments.count > 1 { state.scope = .selection }
            }

            Divider()

            // Fortschritt / Ergebnis
            statusArea

            // Buttons
            HStack {
                Button("Abbrechen") { isPresented = false }

                Spacer()

                Button("Exportieren…") { beginExport() }
                    .buttonStyle(DefaultButtonStyle())
                    .disabled(isExporting)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            state.phase = .idle
            state.result = nil
            state.completedCount = 0
            state.totalCount = 0
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusArea: some View {
        switch state.phase {
        case .idle:
            EmptyView()
        case .exporting:
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: Double(state.completedCount),
                             total: Double(max(state.totalCount, 1)))
                Text("\(state.completedCount) von \(state.totalCount) exportiert…")
                    .font(.callout).foregroundColor(.secondary)
            }
        case .done:
            if let r = state.result {
                resultView(r)
            }
        case .failed(let msg):
            Label(msg, systemImage: "xmark.octagon")
                .foregroundColor(.red).font(.callout)
        }
    }

    @ViewBuilder
    private func resultView(_ r: ExportResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                r.failed.isEmpty
                    ? "\(r.succeeded) Bild(er) erfolgreich exportiert"
                    : "\(r.succeeded) von \(r.total) erfolgreich – \(r.failed.count) fehlgeschlagen",
                systemImage: r.failed.isEmpty ? "checkmark.circle" : "exclamationmark.triangle"
            )
            .foregroundColor(r.failed.isEmpty ? .green : .orange)
            .font(.callout)

            ForEach(Array(r.failed.prefix(3).enumerated()), id: \.offset) { _, item in
                Text("• \(item.filename): \(item.reason)")
                    .font(.caption).foregroundColor(.secondary)
            }
            if r.failed.count > 3 {
                Text("… und \(r.failed.count - 3) weitere")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // Label + Content zweispaltig, macOS 11 kompatibel (kein LabeledContent)
    private func row<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .frame(width: 70, alignment: .trailing)
                .foregroundColor(.secondary)
            content()
        }
    }

    private func radioButton(selected: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selected ? .accentColor : .secondary)
                Text(label)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var isExporting: Bool {
        if case .exporting = state.phase { return true }
        return false
    }

    // MARK: - Export

    private func beginExport() {
        switch state.scope {
        case .current:   exportCurrent()
        case .selection: exportBatch(selectedDocuments)
        case .all:       exportBatch(documents)
        }
    }

    private func exportCurrent() {
        guard let doc = currentDocument else { return }
        let fmt = state.format
        let q = state.quality / 100.0

        let panel = NSSavePanel()
        panel.nameFieldStringValue = (doc.filename as NSString).deletingPathExtension + "." + fmt.fileExtension
        panel.allowedFileTypes = [fmt.fileExtension]
        panel.title = "Bild exportieren"
        panel.prompt = "Exportieren"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            state.phase = .exporting
            state.totalCount = 1
            state.completedCount = 0

            DispatchQueue.global(qos: .userInitiated).async {
                let image: CGImage
                do {
                    if let cached = doc.cgImage {
                        image = cached
                    } else {
                        image = try RAWImageDecoder.decode(url: doc.url)
                    }
                } catch {
                    DispatchQueue.main.async { state.phase = .failed(error.localizedDescription) }
                    return
                }

                do {
                    try ImageExporter.exportSingle(image: image, to: url, format: fmt, quality: q)
                    DispatchQueue.main.async {
                        state.completedCount = 1
                        state.result = ExportResult(total: 1, succeeded: 1, failed: [])
                        state.phase = .done
                    }
                } catch {
                    DispatchQueue.main.async { state.phase = .failed(error.localizedDescription) }
                }
            }
        }
    }

    private func exportBatch(_ docs: [ImageDocument]) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.title = "Exportziel wählen"
        panel.prompt = "Exportieren"

        let fmt = state.format
        let q = state.quality / 100.0

        panel.begin { response in
            guard response == .OK, let folder = panel.url else { return }
            state.phase = .exporting
            state.totalCount = docs.count
            state.completedCount = 0

            ImageExporter.exportBatch(
                documents: docs,
                to: folder,
                format: fmt,
                quality: q,
                progressHandler: { completed, _ in
                    DispatchQueue.main.async { state.completedCount = completed }
                },
                completion: { result in
                    DispatchQueue.main.async {
                        state.result = result
                        state.phase = .done
                    }
                }
            )
        }
    }
}
