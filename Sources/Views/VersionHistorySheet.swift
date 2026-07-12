import SwiftUI
import AppKit

struct VersionHistorySheet: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @Binding var isPresented: Bool
    @State private var thumbnails: [UUID: NSImage] = [:]
    @State private var confirmRevert: ImageVersionMeta? = nil

    private var versions: [ImageVersionMeta] { viewModel.versions.savedVersions }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if versions.isEmpty {
                Spacer()
                Text("Keine gespeicherten Versionen")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(versions) { meta in
                            versionRow(meta)
                            Divider()
                        }
                    }
                }
            }
            Divider()
            footer
        }
        .frame(width: 420, height: 480)
        .onAppear { loadThumbnails() }
        .alert(item: $confirmRevert) { meta in
            Alert(
                title: Text("Version wiederherstellen?"),
                message: Text("Der aktuelle Stand wird als neue Version gesichert bevor die gewählte Version wiederhergestellt wird."),
                primaryButton: .default(Text("Wiederherstellen")) {
                    viewModel.revertToVersion(meta)
                    isPresented = false
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var header: some View {
        HStack {
            Text("Versionshistorie")
                .font(.headline)
            Spacer()
            if let name = viewModel.collection.currentDocument?.filename {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func versionRow(_ meta: ImageVersionMeta) -> some View {
        HStack(spacing: 12) {
            if let img = thumbnails[meta.id] {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 40)
                    .clipped()
                    .cornerRadius(4)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(width: 60, height: 40)
                    .overlay(ProgressView().scaleEffect(0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(meta.date, style: .date)
                    .font(.callout)
                Text(meta.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let label = meta.label {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button("Wiederherstellen") {
                confirmRevert = meta
            }
            .buttonStyle(BorderlessButtonStyle())
            .foregroundColor(.accentColor)

            Button(action: { deleteVersion(meta) }) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Version löschen")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Text("\(versions.count) Version\(versions.count == 1 ? "" : "en")")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Schließen") { isPresented = false }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func loadThumbnails() {
        guard let docURL = viewModel.collection.currentDocument?.url else { return }
        let (accessURL, stop) = BookmarkStore.shared.access(url: docURL)
        DispatchQueue.global(qos: .utility).async {
            let metas = versions
            for meta in metas {
                if let cg = VersionStore.shared.thumbnail(for: meta, url: accessURL) {
                    let img = NSImage(cgImage: cg, size: .zero)
                    DispatchQueue.main.async { thumbnails[meta.id] = img }
                }
            }
            stop()
        }
    }

    private func deleteVersion(_ meta: ImageVersionMeta) {
        guard let docURL = viewModel.collection.currentDocument?.url else { return }
        let (accessURL, stop) = BookmarkStore.shared.access(url: docURL)
        VersionStore.shared.deleteVersion(meta, for: accessURL)
        stop()
        viewModel.loadVersionsForCurrentImage()
    }
}
