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
    @State private var saveError: String? = nil

    private var sourceEntries: [MetadataEntry] {
        viewModel.collection.currentDocument?.metadata ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            if editedEntries.isEmpty {
                Spacer()
                Text(viewModel.currentImage == nil ? "Kein Bild geöffnet" : "Keine Metadaten")
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
            } else {
                ScrollView {
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

                Divider()

                VStack(spacing: 4) {
                    if let err = saveError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    Button(action: save) {
                        if viewModel.isSavingMetadata {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                        } else {
                            Text("Speichern")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(DefaultButtonStyle())
                    .disabled(viewModel.isSavingMetadata || viewModel.currentImage == nil)
                    .padding(8)
                }
            }
        }
        .onChange(of: sourceEntries.count) { newCount in
            Log.debug("MetadataPanel: Einträge geändert → \(newCount)")
            editedEntries = sourceEntries
            saveError = nil
        }
        .onAppear {
            Log.debug("MetadataPanel: onAppear, \(sourceEntries.count) Einträge")
            editedEntries = sourceEntries
        }
    }

    private func save() {
        saveError = nil
        viewModel.saveMetadata(editedEntries)
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
