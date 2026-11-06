import SwiftUI
import AppKit

struct ProjectPickerView: View {
    var onOpen: (Project) -> Void
    var onOpenWithoutProject: () -> Void

    @ObservedObject private var store = ProjectStore.shared
    @State private var selectedProjectID: UUID? = nil
    @State private var renamingProject: Project? = nil
    @State private var renameText: String = ""

    var body: some View {
        HStack(spacing: 0) {
            // Left panel: project list
            VStack(alignment: .leading, spacing: 0) {
                Text("Projekte")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                Divider()

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.projects) { project in
                            ProjectRowView(
                                project: project,
                                isSelected: selectedProjectID == project.id,
                                onSelect: { selectedProjectID = project.id },
                                onOpen: { onOpen(project) },
                                onRename: {
                                    renamingProject = project
                                    renameText = project.name
                                    showRenameAlert(project: project)
                                },
                                onDelete: {
                                    store.deleteProject(project)
                                    if selectedProjectID == project.id { selectedProjectID = nil }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }

                Spacer()
            }
            .frame(width: 260)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Right panel: actions
            VStack(spacing: 0) {
                Spacer()

                // App icon + title
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 56))
                        .foregroundColor(.accentColor)
                    Text("iPhoto")
                        .font(.title)
                        .fontWeight(.semibold)
                }
                .padding(.bottom, 32)

                // Action rows
                VStack(spacing: 12) {
                    ActionRowView(
                        title: "Neues Projekt erstellen.",
                        subtitle: "Erstelle ein neues Projekt mit einem oder mehreren Ordnern.",
                        buttonTitle: "Erstellen",
                        isAccented: true
                    ) {
                        createNewProject()
                    }

                    Divider()

                    ActionRowView(
                        title: "Ordner als Projekt öffnen.",
                        subtitle: "Wähle einen Ordner und öffne ihn direkt als Projekt.",
                        buttonTitle: "Öffnen",
                        isAccented: false
                    ) {
                        openFolderAsProject()
                    }

                    Divider()

                    ActionRowView(
                        title: "Ohne Projekt öffnen.",
                        subtitle: "Alle bekannten Ordner werden geladen (klassischer Modus).",
                        buttonTitle: "Öffnen",
                        isAccented: false
                    ) {
                        onOpenWithoutProject()
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 700, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Actions

    private func createNewProject() {
        // Step 1: get project name via NSAlert
        let alert = NSAlert()
        alert.messageText = "Neues Projekt"
        alert.informativeText = "Gib einen Namen für das neue Projekt ein:"
        alert.addButton(withTitle: "Weiter")
        alert.addButton(withTitle: "Abbrechen")

        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        nameField.placeholderString = "Projektname"
        alert.accessoryView = nameField
        alert.window.initialFirstResponder = nameField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        // Step 2: pick folders
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Ordner auswählen"
        panel.message = "Wähle einen oder mehrere Ordner für das Projekt \"\(name)\"."
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        let paths = panel.urls.map { $0.path }
        let project = store.createProject(name: name, folderPaths: paths)
        onOpen(project)
    }

    private func openFolderAsProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Öffnen"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let name = url.lastPathComponent
        let project = store.createProject(name: name, folderPaths: [url.path])
        onOpen(project)
    }

    private func showRenameAlert(project: Project) {
        let alert = NSAlert()
        alert.messageText = "Projekt umbenennen"
        alert.informativeText = "Neuer Name für \"\(project.name)\":"
        alert.addButton(withTitle: "Umbenennen")
        alert.addButton(withTitle: "Abbrechen")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = project.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else { return }

        var updated = project
        updated.name = newName
        store.updateProject(updated)
    }
}

// MARK: - Project Row

private struct ProjectRowView: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(project.folderPaths.prefix(2).joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Menu {
                Button("Umbenennen") { onRename() }
                Divider()
                Button("Löschen") { onDelete() }
            } label: {
                Text("…")
                    .frame(width: 22, height: 22)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen() }
        .onTapGesture(count: 1) { onSelect() }
    }
}

// MARK: - Action Row

private struct ActionRowView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let isAccented: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if isAccented {
                Button(buttonTitle) { action() }
                    .buttonStyle(AccentButtonStyle())
            } else {
                Button(buttonTitle) { action() }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Button style helpers

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(6)
    }
}
