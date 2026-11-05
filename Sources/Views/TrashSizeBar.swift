import SwiftUI

struct TrashSizeBar: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var totalBytes: Int64 = -1  // -1 = noch nicht berechnet

    private var trashedDocs: [ImageDocument] {
        viewModel.collection.documents.filter { $0.isTrashed }
    }

    var body: some View {
        if !trashedDocs.isEmpty {
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if totalBytes < 0 {
                    Text("Berechne Größe…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(trashedDocs.count) Dateien · \(formattedSize(totalBytes)) würden freigegeben")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Papierkorb leeren") {
                    viewModel.emptyTrash()
                }
                .font(.system(size: 11))
                .foregroundColor(.red)
                .buttonStyle(PlainButtonStyle())
                .disabled(trashedDocs.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color(NSColor.windowBackgroundColor))
            .onAppear { recalculate() }
            .onChange(of: trashedDocs.count) { _ in recalculate() }
        }
    }

    private func recalculate() {
        totalBytes = -1
        let urls = trashedDocs.map { $0.url }
        DispatchQueue.global(qos: .utility).async {
            var sum: Int64 = 0
            for url in urls {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    sum += Int64(size)
                }
            }
            DispatchQueue.main.async { totalBytes = sum }
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
