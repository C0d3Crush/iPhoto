import SwiftUI

// Helper: menu item with right-aligned shortcut hint (macOS 11 doesn't auto-display
// bare-key shortcuts from .keyboardShortcut(), so we embed them in the label).
private func mItem(_ title: String, shortcut: String? = nil, icon: String? = nil) -> some View {
    HStack(spacing: 0) {
        if let icon = icon {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundColor(.primary)
        }
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
        if let s = shortcut {
            Text(s)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .font(.system(size: 11, design: .monospaced))
                .padding(.leading, 12)
        }
    }
    .frame(minWidth: 220)
}

struct ThumbnailContextMenu: View {
    let doc: ImageDocument
    @EnvironmentObject var vm: ImageViewModel

    private var docIndex: Int? { vm.collectionIndex(for: doc) }
    private var isInMultiSelection: Bool {
        guard let idx = docIndex else { return false }
        return vm.collection.selectedIndices.contains(idx) && vm.collection.selectedIndices.count > 1
    }
    // Eingeklappter Stapel: Aktionen wirken auf alle Mitglieder (Mehrfachauswahl hat Vorrang)
    private var stackMembers: [ImageDocument]? {
        isInMultiSelection ? nil : vm.collapsedStackMembers(for: doc)
    }

    private var trashTargets: [ImageDocument] {
        if isInMultiSelection {
            return vm.collection.selectedIndices.sorted().compactMap {
                $0 < vm.collection.documents.count ? vm.collection.documents[$0] : nil
            }
        }
        return stackMembers ?? [doc]
    }

    var body: some View {
        if vm.navSelection == .trash {
            trashMenu
        } else {
            normalMenu
        }
    }

    @ViewBuilder private var trashMenu: some View {
        let targets = trashTargets
        Button(targets.count > 1 ? "\(targets.count) Bilder wiederherstellen" : "Wiederherstellen") {
            vm.restoreFromTrash(targets)
        }
        Button(targets.count > 1 ? "\(targets.count) Bilder endgültig löschen…" : "Endgültig löschen…") {
            vm.deletePermanently(targets)
        }
        Divider()
        Button("Papierkorb leeren…") { vm.emptyTrash() }
        Divider()
        Button("Im Finder zeigen") { vm.showInFinder(doc) }
    }

    @ViewBuilder private var normalMenu: some View {
        Group {
            flagSection
            Divider()
            ratingMenu
            Divider()
            colorLabelSection
            if doc.qualityScanned {
                Divider()
                qualityOverrideSection
            }
        }
        Group {
            Divider()
            actionSection
            Divider()
            lastUsedAlbumButton
            albumSection
            Divider()
            Button(stackMembers.map { "Stapel (\($0.count)) aus Sammlung entfernen" } ?? "Aus Sammlung entfernen") {
                vm.removeDocument(doc)
            }
            trashButton
            .keyboardShortcut(.delete, modifiers: .command)
            Divider()
            backupSection
        }
    }

    private var trashTitle: String {
        if isInMultiSelection { return "\(vm.collection.selectedIndices.count) Dateien in Papierkorb" }
        if let members = stackMembers { return "Stapel (\(members.count)) in Papierkorb" }
        return "In Papierkorb"
    }

    @ViewBuilder private var trashButton: some View {
        Button(action: { vm.trashDocument(doc) }) {
            mItem(trashTitle, shortcut: "⌘⌫", icon: "trash")
        }
        .keyboardShortcut(.delete, modifiers: .command)
    }

    @ViewBuilder private var backupSection: some View {
        let targets = trashTargets
        let n = targets.count
        Button { vm.backupDocuments(targets, deleteOriginal: false) } label: {
            let title = isInMultiSelection ? "\(n) Dateien als Backup sichern"
                : (stackMembers.map { "Stapel (\($0.count)) als Backup sichern" } ?? "Als Backup sichern")
            mItem(title, shortcut: "⌘B", icon: "externaldrive.badge.checkmark")
        }
        Button { vm.backupDocuments(targets, deleteOriginal: true) } label: {
            let title = isInMultiSelection ? "\(n) Dateien sichern & Original in Papierkorb"
                : (stackMembers.map { "Stapel (\($0.count)) sichern & Original in Papierkorb" }
                   ?? "Als Backup sichern & Original in Papierkorb")
            mItem(title, shortcut: "⌘⇧B", icon: "externaldrive.badge.minus")
        }
    }

    @ViewBuilder private var flagSection: some View {
        Button {
            vm.setFlagStatus(.pick, for: doc)
        } label: {
            if doc.flagStatus == .pick {
                mItem("Pick entfernen", shortcut: "P", icon: "checkmark")
            } else {
                mItem("Als Pick markieren", shortcut: "P")
            }
        }
        .keyboardShortcut("p", modifiers: [])
        Button {
            vm.setFlagStatus(.reject, for: doc)
        } label: {
            if doc.flagStatus == .reject {
                mItem("Abgelehnt entfernen", shortcut: "X", icon: "checkmark")
            } else {
                mItem("Als Abgelehnt markieren", shortcut: "X")
            }
        }
        .keyboardShortcut("x", modifiers: [])
    }

    @ViewBuilder private var ratingMenu: some View {
        Menu("Bewertung") {
            ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                Button {
                    vm.setRating(stars, for: doc)
                } label: {
                    let label = String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)
                    mItem(label, shortcut: "\(stars)",
                          icon: doc.rating == stars ? "checkmark" : nil)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(stars)")), modifiers: [])
            }
            Divider()
            Button {
                vm.setRating(0, for: doc)
            } label: {
                mItem("Keine Bewertung", shortcut: "0",
                      icon: doc.rating == 0 ? "checkmark" : nil)
            }
            .keyboardShortcut("0", modifiers: [])
        }
    }

    @ViewBuilder private var colorLabelSection: some View {
        colorLabelButton(.red,    name: "Rot",        shortcut: "R")
        colorLabelButton(.yellow, name: "Gelb",       shortcut: "Y")
        colorLabelButton(.green,  name: "Grün",       shortcut: "G")
        colorLabelButton(.blue,   name: "Blau",       shortcut: "B")
        Button {
            vm.setColorLabel(.none, for: doc)
        } label: {
            mItem("Kein Label", shortcut: "L",
                  icon: doc.colorLabel == .none ? "checkmark" : nil)
        }
        .keyboardShortcut("l", modifiers: [])
    }

    private func colorLabelButton(_ label: ColorLabel, name: String, shortcut: String) -> some View {
        Button {
            vm.setColorLabel(label, for: doc)
        } label: {
            mItem(name, shortcut: shortcut,
                  icon: doc.colorLabel == label ? "checkmark" : nil)
        }
        .keyboardShortcut(KeyEquivalent(shortcut.lowercased().first ?? "?"), modifiers: [])
    }

    @ViewBuilder private var qualityOverrideSection: some View {
        let flags = vm.qualityFlags(for: doc)
        // Blur
        if flags.blur {
            Button("Nicht unscharf") { vm.setBlurOverride(true, for: doc) }
        } else if doc.blurOverride {
            Button("Unschärfe-Override entfernen") { vm.setBlurOverride(false, for: doc) }
        }
        // Under
        if flags.under {
            Button("Nicht unterbelichtet") { vm.setUnderExposureOverride(true, for: doc) }
        } else if doc.underOverride {
            Button("Unterbelichtungs-Override entfernen") { vm.setUnderExposureOverride(false, for: doc) }
        }
        // Over
        if flags.over {
            Button("Nicht überbelichtet") { vm.setOverExposureOverride(true, for: doc) }
        } else if doc.overOverride {
            Button("Überbelichtungs-Override entfernen") { vm.setOverExposureOverride(false, for: doc) }
        }
        // Eyes closed
        if flags.eyes {
            Button("Augen sind offen") { vm.setEyesClosedOverride(true, for: doc) }
        } else if doc.eyesClosedOverride {
            Button("Augen-Override entfernen") { vm.setEyesClosedOverride(false, for: doc) }
        }
    }

    @ViewBuilder private var actionSection: some View {
        if isInMultiSelection && vm.collection.selectedIndices.count >= 2 {
            Button("HDR zusammenführen…") {
                vm.hdr.showSheet = true
            }
            Divider()
        }
        Button(isInMultiSelection
               ? "\(vm.collection.selectedIndices.count) Bilder exportieren..."
               : (stackMembers.map { "Stapel (\($0.count) Bilder) exportieren..." } ?? "Exportieren...")) {
            // Mehrfachauswahl beibehalten — nur umschalten wenn das Bild noch nicht ausgewählt ist
            if !isInMultiSelection {
                if let members = stackMembers {
                    vm.collection.selectedIndices = Set(members.compactMap { vm.collectionIndex(for: $0) })
                    if let idx = docIndex { vm.collection.currentIndex = idx }
                } else if let idx = docIndex {
                    vm.selectDocument(at: idx)
                }
            }
            vm.showExportSheet = true
        }
        Button { vm.showInFinder(doc) } label: {
            mItem("Im Finder zeigen", shortcut: "⌘R")
        }
        .keyboardShortcut("r", modifiers: .command)
    }

    private static let lastAlbumKey = "contextMenu.lastUsedAlbumID"

    private var lastUsedAlbum: Album? {
        guard let raw = UserDefaults.standard.string(forKey: Self.lastAlbumKey),
              let id = UUID(uuidString: raw) else { return nil }
        return vm.library.albums.first(where: { $0.id == id })
    }

    @ViewBuilder private var lastUsedAlbumButton: some View {
        if let album = lastUsedAlbum {
            Button("Zu \"\(album.name)\" hinzufügen") {
                addToAlbum(album)
            }
            Divider()
        }
    }

    private func addToAlbum(_ album: Album) {
        UserDefaults.standard.set(album.id.uuidString, forKey: Self.lastAlbumKey)
        let stack = stackMembers
        if isInMultiSelection {
            vm.addSelectedToAlbum(albumID: album.id)
        } else if let members = stack {
            for m in members { vm.addToAlbum(m, albumID: album.id) }
        } else {
            vm.addToAlbum(doc, albumID: album.id)
        }
    }

    @ViewBuilder private var albumSection: some View {
        let multi = isInMultiSelection
        let stack = stackMembers
        Menu(multi ? "Alle (\(vm.collection.selectedIndices.count)) zu Album hinzufügen"
             : (stack.map { "Stapel (\($0.count)) zu Album hinzufügen" } ?? "Zu Album hinzufügen")) {
            Button(action: { createAlbumAndAdd() }) {
                Label("Neues Album erstellen…", systemImage: "plus")
            }
            if !vm.library.albums.isEmpty {
                Divider()
                ForEach(vm.library.albums) { album in
                    let inAlbum = !multi && stack == nil && album.photoURLs.contains(doc.url)
                    Button {
                        addToAlbum(album)
                    } label: {
                        if inAlbum {
                            Label(album.name, systemImage: "checkmark")
                        } else {
                            Text(album.name)
                        }
                    }
                }
            }
        }
        if case .album(let id) = vm.navSelection {
            Button("Aus Album entfernen") {
                for m in stack ?? [doc] { vm.removeFromAlbum(m, albumID: id) }
            }
        }
    }

    private func createAlbumAndAdd() {
        let alert = NSAlert()
        alert.messageText = "Neues Album"
        alert.informativeText = "Albumname eingeben:"
        alert.addButton(withTitle: "Erstellen")
        alert.addButton(withTitle: "Abbrechen")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        field.placeholderString = "Albumname"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        vm.createAlbum(name: name)
        guard let album = vm.library.albums.first(where: { $0.name == name }) else { return }
        addToAlbum(album)
    }
}
