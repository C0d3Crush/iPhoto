import SwiftUI

struct MetadataPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var editedEntries: [MetadataEntry] = []
    @State private var saveError: String? = nil

    private var entries: [MetadataEntry] {
        viewModel.collection.currentDocument?.metadata ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            if entries.isEmpty {
                Spacer()
                Text(viewModel.currentImage == nil ? "Kein Bild geöffnet" : "Keine Metadaten")
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(MetadataCategory.allCases, id: \.self) { category in
                            let catEntries = editedEntries.filter { $0.category == category }
                            if !catEntries.isEmpty {
                                Section(header:
                                    Text(category.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(NSColor.windowBackgroundColor))
                                ) {
                                    ForEach(catEntries.indices, id: \.self) { i in
                                        let globalIndex = editedEntries.firstIndex(where: { $0.id == catEntries[i].id })!
                                        MetadataRowView(entry: $editedEntries[globalIndex])
                                        Divider().padding(.leading, 8)
                                    }
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
        .onChange(of: entries.map { $0.id }) { _ in
            editedEntries = entries
            saveError = nil
        }
        .onAppear {
            editedEntries = entries
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
