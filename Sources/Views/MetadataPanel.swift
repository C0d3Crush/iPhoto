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
        let entries = viewModel.collection.currentDocument?.metadata ?? []
        return entries.isEmpty ? MetadataService().defaultEntries() : entries
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
            viewModel.pendingMetadataEntries = nil
        }
        .onChange(of: editedSignature) { sig in
            viewModel.pendingMetadataEntries = sig != sourceSignature ? editedEntries : nil
        }
        .onAppear {
            if let pending = viewModel.pendingMetadataEntries {
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
