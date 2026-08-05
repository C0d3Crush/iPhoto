import SwiftUI

struct MetadataPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        MetadataPanelContent()
            .environmentObject(viewModel)
            .id(viewModel.collection.currentDocument?.id)
    }
}

private struct MetadataPanelContent: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var editedEntries: [MetadataEntry] = []

    private var sourceEntries: [MetadataEntry] {
        let base: [MetadataEntry]
        if let doc = viewModel.collection.currentDocument {
            base = doc.metadata.isEmpty ? MetadataService().defaultEntries() : doc.metadata
        } else {
            base = MetadataService().defaultEntries()
        }
        return base + qualityEntries()
    }

    // Qualitäts-Kategorie: dynamisch aus persistierten Scores + aktuellen Schwellen +
    // Overrides berechnet. Nicht editierbar. Aktualisiert sich automatisch, wenn der
    // Nutzer Schwellenwerte verstellt oder Overrides setzt — sourceEntries wird via
    // .id(currentDocument.id) neu evaluiert.
    private func qualityEntries() -> [MetadataEntry] {
        guard let doc = viewModel.collection.currentDocument else { return [] }
        if !doc.qualityScanned {
            return [MetadataEntry(displayName: "Analyse",
                                  key: "quality.status",
                                  category: .quality,
                                  value: "Noch nicht analysiert",
                                  isEditable: false)]
        }
        var out: [MetadataEntry] = []
        let flags = viewModel.qualityFlags(for: doc)

        if let s = doc.blurScore {
            let label: String
            if doc.blurOverride {
                label = String(format: "OK (Override, Score %.1f)", s)
            } else if flags.blur {
                label = String(format: "Unscharf (Score %.1f)", s)
            } else {
                label = String(format: "Scharf (Score %.1f)", s)
            }
            out.append(MetadataEntry(displayName: "Schärfe",
                                     key: "quality.blur", category: .quality,
                                     value: label, isEditable: false))
        }
        if let r = doc.underRatio {
            let pct = r * 100
            let label: String
            if doc.underOverride {
                label = String(format: "OK (Override, %.1f%% Schatten)", pct)
            } else if flags.under {
                label = String(format: "Unterbelichtet (%.1f%% Schatten)", pct)
            } else {
                label = String(format: "OK (%.1f%% Schatten)", pct)
            }
            out.append(MetadataEntry(displayName: "Unterbel.",
                                     key: "quality.under", category: .quality,
                                     value: label, isEditable: false))
        }
        if let r = doc.overRatio {
            let pct = r * 100
            let label: String
            if doc.overOverride {
                label = String(format: "OK (Override, %.1f%% Lichter)", pct)
            } else if flags.over {
                label = String(format: "Überbelichtet (%.1f%% Lichter)", pct)
            } else {
                label = String(format: "OK (%.1f%% Lichter)", pct)
            }
            out.append(MetadataEntry(displayName: "Überbel.",
                                     key: "quality.over", category: .quality,
                                     value: label, isEditable: false))
        }
        return out
    }

    private var sourceSignature: String {
        sourceEntries.filter { $0.isEditable }.map { "\($0.key)=\($0.value)" }.joined(separator: "|")
    }

    private var editedSignature: String {
        editedEntries.filter { $0.isEditable }.map { "\($0.key)=\($0.value)" }.joined(separator: "|")
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.currentImage == nil {
                Spacer()
                Text("Kein Bild geöffnet")
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(MetadataCategory.allCases, id: \.self) { category in
                        let indices = editedEntries.indices.filter { editedEntries[$0].category == category }
                        if !indices.isEmpty {
                            Text(category.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(indices, id: \.self) { idx in
                                MetadataRowView(entry: $editedEntries[idx])
                                Divider().padding(.leading, 8)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .onChange(of: sourceEntries.count) { _ in
            editedEntries = sourceEntries
            viewModel.versions.pendingMetadataEntries = nil
        }
        .onChange(of: editedSignature) { sig in
            viewModel.versions.pendingMetadataEntries = sig != sourceSignature ? editedEntries : nil
        }
        .onAppear {
            if let pending = viewModel.versions.pendingMetadataEntries {
                editedEntries = pending
            } else {
                editedEntries = sourceEntries
            }
        }
    }
}

private struct MetadataRowView: View {
    @Binding var entry: MetadataEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
                .padding(.top, 2)

            if entry.isEditable {
                TextField("", text: $entry.value)
                    .font(.caption)
                    .textFieldStyle(PlainTextFieldStyle())
                    .multilineTextAlignment(.leading)
            } else {
                Text(entry.value.isEmpty ? "–" : entry.value)
                    .font(.caption)
                    .foregroundColor(entry.value.isEmpty ? Color(NSColor.tertiaryLabelColor) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
