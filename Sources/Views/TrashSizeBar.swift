import SwiftUI

struct TrashSizeBar: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var totalBytes: Int64 = -1  // -1 = noch nicht berechnet
    @State private var trashedFileCount: Int = 0

    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB, .useKB]
        f.countStyle = .file
        return f
    }()

    var body: some View {
        let trashed = viewModel.trashedCount
        if trashed > 0 {
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
                    Text("\(trashedFileCount) Dateien · \(Self.sizeFormatter.string(fromByteCount: totalBytes)) würden freigegeben")
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color(NSColor.windowBackgroundColor))
            .onAppear { recalculate() }
            .onChange(of: trashed) { _ in recalculate() }
        }
    }

    private func recalculate() {
        totalBytes = -1
        let urls = viewModel.collection.documents.compactMap { $0.isTrashed ? $0.url : nil }
        trashedFileCount = urls.count
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
}
