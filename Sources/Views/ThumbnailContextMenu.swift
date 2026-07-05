import SwiftUI

struct ThumbnailContextMenu: View {
    let doc: ImageDocument
    @EnvironmentObject var vm: ImageViewModel

    private var docIndex: Int? { vm.collectionIndex(for: doc) }
    private var isInMultiSelection: Bool {
        guard let idx = docIndex else { return false }
        return vm.collection.selectedIndices.contains(idx) && vm.collection.selectedIndices.count > 1
    }

    var body: some View {
        Group {
            flagSection
            Divider()
            ratingMenu
            Divider()
            colorLabelSection
        }
        Group {
            Divider()
            actionSection
            Divider()
            albumSection
            Divider()
            Button("Aus Sammlung entfernen") {
                vm.removeDocument(doc)
            }
            Button {
                vm.trashDocument(doc)
            } label: {
                let multi = isInMultiSelection
                Label(multi ? "\(vm.collection.selectedIndices.count) Dateien in Papierkorb" : "In Papierkorb",
                      systemImage: "trash")
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

    @ViewBuilder private var actionSection: some View {
        if isInMultiSelection && vm.collection.selectedIndices.count >= 2 {
            Button("HDR zusammenführen…") {
                vm.showHDRMergeSheet = true
            }
            Divider()
        }
        Button(isInMultiSelection
               ? "\(vm.collection.selectedIndices.count) Bilder exportieren..."
               : "Exportieren...") {
            // Mehrafachauswahl beibehalten — nur umschalten wenn das Bild noch nicht ausgewählt ist
            if !isInMultiSelection, let idx = docIndex { vm.selectDocument(at: idx) }
            vm.showExportSheet = true
        }
        Button("Im Finder zeigen") {
            vm.showInFinder(doc)
        }
    }

    @ViewBuilder private var albumSection: some View {
        if !vm.albums.isEmpty {
            let multi = isInMultiSelection
            Menu(multi ? "Alle (\(vm.collection.selectedIndices.count)) zu Album hinzufügen" : "Zu Album hinzufügen") {
                ForEach(vm.albums) { album in
                    let inAlbum = !multi && album.photoURLs.contains(doc.url)
                    Button {
                        if multi {
                            vm.addSelectedToAlbum(albumID: album.id)
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
                Button("Aus Album entfernen") { vm.removeFromAlbum(doc, albumID: id) }
            }
        }
    }
}
