import SwiftUI
import Foundation

struct StoragePanel: View {
    @EnvironmentObject var viewModel: ImageViewModel

    @State private var backupFolderSize: Int64 = -1
    @State private var backupFileCount: Int = 0
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            storageRow(label: "Bibliothek",
                       value: "\(viewModel.collection.documents.count) Bilder",
                       icon: "photo.on.rectangle.angled")
            Divider().padding(.leading, 8)

            storageRow(label: "Gesichert",
                       value: viewModel.backedUpCount > 0 ? "\(viewModel.backedUpCount) Bilder" : "–",
                       icon: "externaldrive.badge.checkmark")
            Divider().padding(.leading, 8)

            storageRow(label: "Backup-Ordner",
                       value: backupFolderSize >= 0
                           ? "\(backupFileCount) Dateien · \(formatBytes(backupFolderSize))"
                           : (loading ? "…" : "–"),
                       icon: "internaldrive")
            Divider().padding(.leading, 8)

            storageRow(label: "Papierkorb",
                       value: viewModel.trashedCount > 0 ? "\(viewModel.trashedCount) Bilder" : "–",
                       icon: "trash")
            Divider().padding(.leading, 8)

            storageRow(label: "Duplikate",
                       value: !viewModel.quality.duplicateGroups.isEmpty
                           ? "\(viewModel.quality.duplicateGroups.count) Gruppen"
                           : "–",
                       icon: "doc.on.doc")

            if hasRecommendations {
                Divider().padding(.vertical, 4)
                Text("Empfehlungen")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)

                if viewModel.trashedCount > 0 {
                    recommendationButton(
                        label: "Papierkorb leeren (\(viewModel.trashedCount) Bilder)",
                        icon: "trash",
                        hint: "⌘⇧⌫") {
                        viewModel.emptyTrash()
                    }
                }
                if !viewModel.quality.duplicateGroups.isEmpty {
                    recommendationButton(
                        label: "Duplikate prüfen (\(viewModel.quality.duplicateGroups.count) Gruppen)",
                        icon: "doc.on.doc",
                        hint: "⌘⇧U") {
                        viewModel.navSelection = .duplicates
                    }
                }
                if viewModel.backedUpCount > 0 {
                    recommendationButton(
                        label: "Backup-Ordner öffnen",
                        icon: "folder",
                        hint: "⌘⇧K") {
                        openBackupFolder()
                    }
                }
            }
        }
        .onAppear { refreshBackupFolderSize() }
    }

    private var hasRecommendations: Bool {
        viewModel.trashedCount > 0 || !viewModel.quality.duplicateGroups.isEmpty || viewModel.backedUpCount > 0
    }

    @ViewBuilder
    private func storageRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func recommendationButton(label: String, icon: String, hint: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let hint = hint {
                    Text(hint)
                        .font(.caption2)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    private func refreshBackupFolderSize() {
        loading = true
        let (root, stop) = viewModel.backupSettings.resolveDestination()
        DispatchQueue.global(qos: .utility).async {
            let (size, count) = directorySize(root)
            stop()
            DispatchQueue.main.async {
                backupFolderSize = size
                backupFileCount = count
                loading = false
            }
        }
    }

    private func openBackupFolder() {
        let (root, stop) = viewModel.backupSettings.resolveDestination()
        NSWorkspace.shared.open(root)
        stop()
    }

    private func directorySize(_ url: URL) -> (Int64, Int) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, 0) }
        var total: Int64 = 0
        var count = 0
        for case let fileURL as URL in enumerator {
            guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  vals.isRegularFile == true else { continue }
            total += Int64(vals.fileSize ?? 0)
            count += 1
        }
        return (total, count)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
