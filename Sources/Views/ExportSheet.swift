import SwiftUI
import AppKit

private class ExportState: ObservableObject {
    enum Scope { case current, selection, all }
    enum Destination { case file, airdrop }
    enum Phase { case idle, exporting, done, failed(String) }

    @Published var format: ExportFormat = .jpeg
    @Published var quality: Double = 85
    @Published var scope: Scope = .current
    @Published var destination: Destination = .file
    @Published var phase: Phase = .idle
    @Published var completedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var result: ExportResult? = nil
}

struct ExportSheet: View {
    let documents: [ImageDocument]
    let selectedDocuments: [ImageDocument]
    let currentDocument: ImageDocument?
    var currentAdjustments: AdjustmentState? = nil
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

            // Ziel
            row(label: "Ziel") {
                VStack(alignment: .leading, spacing: 4) {
                    radioButton(selected: state.destination == .file, label: "Speicherort wählen…") {
                        state.destination = .file
                    }
                    HStack(spacing: 6) {
                        radioButton(selected: state.destination == .airdrop, label: "AirDrop") {
                            state.destination = .airdrop
                        }
                        Image(systemName: "wifi")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }

            Divider()

            // Fortschritt / Ergebnis
            statusArea

            // Buttons
            HStack {
                Button("Abbrechen") { isPresented = false }

                Spacer()

                Button(state.destination == .airdrop ? "Per AirDrop senden…" : "Exportieren…") { beginExport() }
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

    /// Anpassungen für ein Dokument: aktuelle Session-Anpassungen fürs aktive Bild,
    /// sonst gespeicherte aus dem Katalog. Nil wenn neutral.
    private func effectiveAdjustments(for doc: ImageDocument) -> AdjustmentState? {
        let adj: AdjustmentState?
        if doc.url == currentDocument?.url, let cur = currentAdjustments {
            adj = cur
        } else {
            adj = CatalogStore.shared.loadAdjustments(path: doc.url.path)
        }
        guard let result = adj, result != AdjustmentState() else { return nil }
        return result
    }

    private func beginExport() {
        if state.destination == .airdrop {
            exportViaAirDrop()
            return
        }
        switch state.scope {
        case .current:   exportCurrent()
        case .selection: exportBatch(selectedDocuments)
        case .all:       exportBatch(documents)
        }
    }

    private func scopedDocuments() -> [ImageDocument] {
        switch state.scope {
        case .current:   return currentDocument.map { [$0] } ?? []
        case .selection: return selectedDocuments
        case .all:       return documents
        }
    }

    /// Exportiert in einen temporären Ordner und öffnet dann das AirDrop-Fenster.
    private func exportViaAirDrop() {
        let docs = scopedDocuments()
        guard !docs.isEmpty else { return }
        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            state.phase = .failed("AirDrop ist auf diesem Mac nicht verfügbar")
            return
        }
        let fmt = state.format
        let q = state.quality / 100.0
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iPhoto-AirDrop-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            state.phase = .failed(error.localizedDescription)
            return
        }

        state.phase = .exporting
        state.totalCount = docs.count
        state.completedCount = 0

        ImageExporter.exportBatch(
            documents: docs,
            to: tempDir,
            format: fmt,
            quality: q,
            adjustmentsProvider: { effectiveAdjustments(for: $0) },
            progressHandler: { completed, _ in
                DispatchQueue.main.async { state.completedCount = completed }
            },
            completion: { result in
                DispatchQueue.main.async {
                    let urls = docs.map { doc -> URL in
                        let stem = (doc.filename as NSString).deletingPathExtension
                        return tempDir.appendingPathComponent(stem)
                            .appendingPathExtension(fmt.fileExtension)
                    }.filter { FileManager.default.fileExists(atPath: $0.path) }

                    guard !urls.isEmpty else {
                        state.phase = .failed(result.failed.first.map {
                            "\($0.filename): \($0.reason)"
                        } ?? "Export fehlgeschlagen")
                        return
                    }
                    state.result = result
                    state.phase = .done
                    service.perform(withItems: urls)
                }
            }
        )
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

            let adjustments = effectiveAdjustments(for: doc)

            DispatchQueue.global(qos: .userInitiated).async {
                let image: CGImage
                do {
                    if let adj = adjustments {
                        image = try AdjustmentRenderer.renderForExport(document: doc, adjustments: adj)
                    } else if let cached = doc.cgImage {
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
                adjustmentsProvider: { effectiveAdjustments(for: $0) },
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
