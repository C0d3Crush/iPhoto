import SwiftUI

struct PeopleView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    @State private var showCreatePerson = false
    @State private var newPersonName = ""
    @State private var renamingPerson: PersonRecord? = nil
    @State private var renameText = ""
    @State private var selectedPersonID: String? = nil

    private let tileSize: CGFloat = 100
    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if viewModel.people.isScanning {
                scanProgress
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !viewModel.people.people.isEmpty {
                        peopleSection
                    }
                    if !viewModel.people.unassignedFaces.isEmpty {
                        unassignedSection
                    }
                    if viewModel.people.people.isEmpty && viewModel.people.unassignedFaces.isEmpty && !viewModel.people.isScanning {
                        emptyState
                    }
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showCreatePerson) {
            createPersonSheet
        }
        .sheet(item: $renamingPerson) { person in
            renamePersonSheet(person)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("Menschen")
                .font(.headline)
            Spacer()
            if viewModel.people.isScanning {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }
            Button(action: { viewModel.clusterFaces() }) {
                Label("Gruppieren", systemImage: "person.3")
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.people.isScanning)

            Button(action: { viewModel.scanFacesForLibrary() }) {
                Label("Scannen", systemImage: "person.crop.rectangle.badge.plus")
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.people.isScanning)

            Button(action: { showCreatePerson = true }) {
                Image(systemName: "plus")
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Scan progress

    private var scanProgress: some View {
        VStack(spacing: 4) {
            ProgressView(value: viewModel.people.scanProgress)
                .padding(.horizontal, 16)
            Text(viewModel.people.scanProgress < 0.85
                 ? "Gesichter werden erkannt…"
                 : "Gesichter werden gruppiert…")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - People grid

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personen")
                .font(.subheadline)
                .foregroundColor(.secondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.people.people) { person in
                    personTile(person)
                }
            }
        }
    }

    private func personTile(_ person: PersonRecord) -> some View {
        let faces = viewModel.people.facesPerPerson[person.id] ?? []
        let coverFace = faces.first(where: { $0.id == person.coverFaceID }) ?? faces.first
        return VStack(spacing: 4) {
            ZStack {
                if let face = coverFace {
                    FaceCropTile(face: face, size: tileSize)
                } else {
                    Rectangle()
                        .fill(Color(NSColor.separatorColor).opacity(0.3))
                        .frame(width: tileSize, height: tileSize)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: tileSize * 0.4))
                                .foregroundColor(.secondary)
                        )
                }
                // Face count badge
                if faces.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(faces.count)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                                .padding(4)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: tileSize, height: tileSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(selectedPersonID == person.id ? Color.accentColor : Color.clear, lineWidth: 2)
            )

            Text(person.name ?? "Unbekannt")
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: tileSize)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { viewModel.navSelection = .personDetail(person.id) }
        .onTapGesture { selectedPersonID = person.id }
        .contextMenu {
            Button("Bilder öffnen") { viewModel.navSelection = .personDetail(person.id) }
            Button("Umbenennen") { renamingPerson = person; renameText = person.name ?? "" }
            Divider()
            Button("Person löschen") { viewModel.deletePerson(person) }
        }
    }

    // MARK: - Unassigned

    private var unassignedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nicht zugeordnet (\(viewModel.people.unassignedFaces.count))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.people.unassignedFaces.prefix(50)) { face in
                    unassignedTile(face)
                }
            }
            if viewModel.people.unassignedFaces.count > 50 {
                Text("+ \(viewModel.people.unassignedFaces.count - 50) weitere")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func unassignedTile(_ face: FaceRecord) -> some View {
        VStack(spacing: 4) {
            FaceCropTile(face: face, size: tileSize)
                .frame(width: tileSize, height: tileSize)
                .clipShape(Circle())

            Text("?")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contextMenu {
            ForEach(viewModel.people.people) { person in
                Button(person.name ?? "Unbekannt") {
                    viewModel.assignFace(faceID: face.id, toPersonID: person.id)
                }
            }
            if !viewModel.people.people.isEmpty { Divider() }
            Button("Neue Person anlegen…") {
                showCreatePerson = true
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Noch keine Gesichter erkannt")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Klicke auf Scannen, um Gesichter in der Bibliothek zu erkennen.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
            Button("Jetzt scannen") { viewModel.scanFacesForLibrary() }
                .disabled(viewModel.people.isScanning)
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sheets

    private var createPersonSheet: some View {
        VStack(spacing: 16) {
            Text("Neue Person")
                .font(.headline)
            TextField("Name", text: $newPersonName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minWidth: 200)
            HStack {
                Button("Abbrechen") { showCreatePerson = false; newPersonName = "" }
                    .keyboardShortcut(.cancelAction)
                Button("Erstellen") {
                    if !newPersonName.isEmpty {
                        viewModel.createPerson(name: newPersonName)
                        newPersonName = ""
                        showCreatePerson = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPersonName.isEmpty)
            }
        }
        .padding(24)
    }

    private func renamePersonSheet(_ person: PersonRecord) -> some View {
        VStack(spacing: 16) {
            Text("Person umbenennen")
                .font(.headline)
            TextField("Name", text: $renameText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minWidth: 200)
            HStack {
                Button("Abbrechen") { renamingPerson = nil }
                    .keyboardShortcut(.cancelAction)
                Button("Speichern") {
                    if !renameText.isEmpty {
                        viewModel.renamePerson(person, to: renameText)
                        renamingPerson = nil
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(renameText.isEmpty)
            }
        }
        .padding(24)
    }
}
