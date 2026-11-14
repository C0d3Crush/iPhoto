import SwiftUI

struct AlbumNameSheet: View {
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

// MARK: - MoveToGroupSheet

struct MoveToGroupSheet: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @Environment(\.presentationMode) private var presentationMode

    let folder: SmartFolder
    @State private var newGroupName = ""

    private var existingGroups: [String] {
        Array(Set(viewModel.library.smartFolders.compactMap { $0.group }.filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("In Gruppe verschieben")
                .font(.headline)

            if !existingGroups.isEmpty {
                Text("Vorhandene Gruppen:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(existingGroups, id: \.self) { grp in
                        Button(action: {
                            viewModel.moveSmartFolder(folder, toGroup: grp)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: folder.group == grp ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(folder.group == grp ? .accentColor : .secondary)
                                Text(grp)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(folder.group == grp ? Color.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Divider()
            }

            Text("Neue Gruppe erstellen:")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("Gruppenname", text: $newGroupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Erstellen") {
                    let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    viewModel.moveSmartFolder(folder, toGroup: trimmed)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if folder.group != nil {
                Divider()
                Button("Aus Gruppe entfernen") {
                    viewModel.moveSmartFolder(folder, toGroup: nil)
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Color(NSColor.systemRed))
            }

            HStack {
                Spacer()
                Button("Abbrechen") { presentationMode.wrappedValue.dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

// MARK: - GroupRenameSheet

struct GroupRenameSheet: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let oldName: String
    @Binding var name: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Gruppe umbenennen").font(.headline)
            TextField("Gruppenname", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 240)
            HStack(spacing: 12) {
                Button("Abbrechen") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Umbenennen") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    viewModel.renameGroup(oldName, to: trimmed)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }
}
