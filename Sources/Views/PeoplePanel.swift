import SwiftUI

// Inspector-Plugin: Kompakte Gesichts-/Personen-Übersicht für das aktuelle Bild.
// Zeigt Gesichts-Crops des aktuellen Bilds, Personenzuordnung und Scan-Shortcut.

struct PeoplePanel: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let doc = viewModel.collection.currentDocument {
                let faces = viewModel.people.facesPerPerson.values.flatMap { $0 }
                    .filter { $0.imagePath == doc.url.path }
                + viewModel.people.unassignedFaces.filter { $0.imagePath == doc.url.path }

                if faces.isEmpty {
                    noFacesRow(doc: doc)
                } else {
                    facesRow(faces: faces, doc: doc)
                }
            } else {
                Text("Kein Bild ausgewählt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(10)
            }

            Divider()
            bottomBar
        }
    }

    // MARK: - Rows

    private func noFacesRow(doc: ImageDocument) -> some View {
        HStack {
            Image(systemName: "person.slash")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
            Text(CatalogStore.shared.pathsNeedingFaceScan().contains(doc.url.path)
                 ? "Noch nicht gescannt"
                 : "Kein Gesicht erkannt")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private func facesRow(faces: [FaceRecord], doc: ImageDocument) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(faces) { face in
                    faceChip(face)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
    }

    private func faceChip(_ face: FaceRecord) -> some View {
        let personName: String? = face.clusterID.flatMap { cid in
            viewModel.people.people.first { $0.id == cid }?.name
        }
        return VStack(spacing: 3) {
            FaceCropTile(face: face, size: 44)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))

            Text(personName ?? "?")
                .font(.system(size: 9))
                .foregroundColor(personName != nil ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: 50)
        }
        .contextMenu {
            ForEach(viewModel.people.people) { person in
                Button(person.name ?? "Unbekannt") {
                    viewModel.assignFace(faceID: face.id, toPersonID: person.id)
                }
            }
            if !viewModel.people.people.isEmpty { Divider() }
            Button("Neue Person anlegen…") {
                // Öffne Menschen-Ansicht für volle Zuordnung
                viewModel.navSelection = .people
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 6) {
            let total = viewModel.people.totalFaceCount
            let personCount = viewModel.people.people.count
            Text("\(personCount) Person\(personCount == 1 ? "" : "en")")
                .font(.caption2)
                .foregroundColor(.secondary)
            if total > 0 {
                Text("·")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(total) Gesicht\(total == 1 ? "" : "er")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { viewModel.navSelection = .people }) {
                Text("Öffnen")
                    .font(.caption2)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
