import SwiftUI

struct NavSidebarView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""
    @State private var renamingAlbum: Album? = nil
    @State private var renameText = ""

    var body: some View {
        List(selection: $viewModel.navSelection) {
            Section(header: Text("Bibliothek")) {
                Label("Library", systemImage: "photo.stack")
                    .tag(NavSelection.library)
            }

            Section(header: HStack {
                Text("Alben")
                Spacer()
                Button(action: { newAlbumName = ""; showCreateAlbum = true }) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }) {
                ForEach(viewModel.albums) { album in
                    Label(album.name, systemImage: "rectangle.stack")
                        .tag(NavSelection.album(album.id))
                        .contextMenu {
                            Button("Umbenennen") {
                                renameText = album.name
                                renamingAlbum = album
                            }
                            Divider()
                            Button("Album löschen") {
                                viewModel.deleteAlbum(album)
                            }
                        }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)
        .sheet(isPresented: $showCreateAlbum) {
            AlbumNameSheet(
                title: "Neues Album",
                placeholder: "Albumname",
                confirmLabel: "Erstellen",
                name: $newAlbumName,
                isPresented: $showCreateAlbum
            ) { name in
                viewModel.createAlbum(name: name)
            }
        }
        .sheet(item: $renamingAlbum) { album in
            AlbumNameSheet(
                title: "Umbenennen",
                placeholder: album.name,
                confirmLabel: "Speichern",
                name: $renameText,
                isPresented: Binding(
                    get: { renamingAlbum != nil },
                    set: { if !$0 { renamingAlbum = nil } }
                )
            ) { name in
                viewModel.renameAlbum(album, to: name)
            }
        }
    }
}

private struct AlbumNameSheet: View {
    let title: String
    let placeholder: String
    let confirmLabel: String
    @Binding var name: String
    @Binding var isPresented: Bool
    let onConfirm: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title).font(.headline)
            TextField(placeholder, text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 240)
            HStack(spacing: 12) {
                Button("Abbrechen") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(confirmLabel) {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    onConfirm(trimmed)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }
}
