import SwiftUI

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
            albumSection
            Divider()
            Button(stackMembers.map { "Stapel (\($0.count)) aus Sammlung entfernen" } ?? "Aus Sammlung entfernen") {
                vm.removeDocument(doc)
            }
            Button {
                vm.trashDocument(doc)
            } label: {
                if isInMultiSelection {
                    Label("\(vm.collection.selectedIndices.count) Dateien in Papierkorb", systemImage: "trash")
                } else if let members = stackMembers {
                    Label("Stapel (\(members.count)) in Papierkorb", systemImage: "trash")
                } else {
                    Label("In Papierkorb", systemImage: "trash")
                }
            }
            Divider()
            backupSection
        }
    }

    @ViewBuilder private var backupSection: some View {
        let targets = trashTargets
        let n = targets.count
        Button {
            vm.backupDocuments(targets, deleteOriginal: false)
        } label: {
            if isInMultiSelection {
                Label("\(n) Dateien als JPEG sichern", systemImage: "externaldrive.badge.checkmark")
            } else if let members = stackMembers {
                Label("Stapel (\(members.count)) als JPEG sichern", systemImage: "externaldrive.badge.checkmark")
            } else {
                Label("Als JPEG sichern", systemImage: "externaldrive.badge.checkmark")
            }
        }
        Button {
            vm.backupDocuments(targets, deleteOriginal: true)
        } label: {
            if isInMultiSelection {
                Label("\(n) Dateien sichern & Original in Papierkorb", systemImage: "externaldrive.badge.minus")
            } else if let members = stackMembers {
                Label("Stapel (\(members.count)) sichern & Original in Papierkorb", systemImage: "externaldrive.badge.minus")
            } else {
                Label("Sichern & Original in Papierkorb", systemImage: "externaldrive.badge.minus")
            }
        }
    }

    @ViewBuilder private var flagSection: some View {
        Button {
            vm.setFlagStatus(.pick, for: doc)
        } label: {
            if doc.flagStatus == .pick {
                Label("Pick entfernen", systemImage: "checkmark")
            } else {
                Text("Als Pick markieren")
            }
        }
        Button {
            vm.setFlagStatus(.reject, for: doc)
        } label: {
            if doc.flagStatus == .reject {
                Label("Abgelehnt entfernen", systemImage: "checkmark")
            } else {
                Text("Als Abgelehnt markieren")
            }
        }
    }

    @ViewBuilder private var ratingMenu: some View {
        Menu("Bewertung") {
            ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                Button {
                    vm.setRating(stars, for: doc)
                } label: {
                    let label = String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)
                    if doc.rating == stars {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
            Divider()
            Button {
                vm.setRating(0, for: doc)
            } label: {
                if doc.rating == 0 {
                    Label("Keine Bewertung", systemImage: "checkmark")
                } else {
                    Text("Keine Bewertung")
                }
            }
        }
    }

    @ViewBuilder private var colorLabelSection: some View {
        colorLabelButton(.red,    name: "Rot")
        colorLabelButton(.yellow, name: "Gelb")
        colorLabelButton(.green,  name: "Grün")
        colorLabelButton(.blue,   name: "Blau")
        Button {
            vm.setColorLabel(.none, for: doc)
        } label: {
            if doc.colorLabel == .none {
                Label("Kein Label", systemImage: "checkmark")
            } else {
                Text("Kein Label")
            }
        }
    }

    private func colorLabelButton(_ label: ColorLabel, name: String) -> some View {
        Button {
            vm.setColorLabel(label, for: doc)
        } label: {
            if doc.colorLabel == label {
                Label(name, systemImage: "checkmark")
            } else {
                Text(name)
            }
        }
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
        Button("Im Finder zeigen") {
            vm.showInFinder(doc)
        }
    }

    @ViewBuilder private var albumSection: some View {
        if !vm.library.albums.isEmpty {
            let multi = isInMultiSelection
            let stack = stackMembers
            Menu(multi ? "Alle (\(vm.collection.selectedIndices.count)) zu Album hinzufügen"
                 : (stack.map { "Stapel (\($0.count)) zu Album hinzufügen" } ?? "Zu Album hinzufügen")) {
                ForEach(vm.library.albums) { album in
                    let inAlbum = !multi && stack == nil && album.photoURLs.contains(doc.url)
                    Button {
                        if multi {
                            vm.addSelectedToAlbum(albumID: album.id)
                        } else if let members = stack {
                            for m in members { vm.addToAlbum(m, albumID: album.id) }
                        } else if inAlbum {
                            vm.removeFromAlbum(doc, albumID: album.id)
                        } else {
                            vm.addToAlbum(doc, albumID: album.id)
                        }
                    } label: {
                        if inAlbum {
                            Label(album.name, systemImage: "checkmark")
                        } else {
                            Text(album.name)
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
    }
}
