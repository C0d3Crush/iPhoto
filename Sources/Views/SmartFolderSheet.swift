import SwiftUI

struct SmartFolderSheetItem: Identifiable {
    let id = UUID()
    let folder: SmartFolder?
    var preselectedBasePath: String? = nil
}

struct SmartFolderSheet: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @Environment(\.presentationMode) private var presentationMode

    var editing: SmartFolder?

    @State private var name: String
    @State private var matchAll: Bool
    @State private var criteria: [SmartFolderCriterion]
    @State private var group: String
    @State private var limitEnabled: Bool
    @State private var limitCount: Int
    @State private var limitSelection: SmartFolderLimitSelection
    @State private var baseFolderPath: String?

    init(editing: SmartFolder? = nil, preselectedBasePath: String? = nil) {
        self.editing = editing
        _name           = State(initialValue: editing?.name ?? "")
        _matchAll       = State(initialValue: editing?.matchAll ?? true)
        _criteria       = State(initialValue: editing?.criteria ?? [SmartFolderCriterion()])
        _group          = State(initialValue: editing?.group ?? "")
        _limitEnabled   = State(initialValue: editing?.limitEnabled ?? false)
        _limitCount     = State(initialValue: editing?.limitCount ?? 25)
        _limitSelection = State(initialValue: editing?.limitSelection ?? .highestRating)
        _baseFolderPath = State(initialValue: editing?.baseFolderPath ?? preselectedBasePath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text(editing == nil ? "iAlbum" : "iAlbum bearbeiten")
                    .font(.headline)

                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                HStack(spacing: 8) {
                    Text("Gruppe:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Gruppenname (optional)", text: $group)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    let existingGroups = Array(Set(viewModel.library.smartFolders.compactMap { $0.group }.filter { !$0.isEmpty })).sorted()
                    if !existingGroups.isEmpty {
                        Menu("Gruppe wählen") {
                            ForEach(existingGroups, id: \.self) { g in
                                Button(g) { group = g }
                            }
                            Divider()
                            Button("Keine Gruppe") { group = "" }
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        .fixedSize()
                    }
                }

                HStack(spacing: 8) {
                    Text("Übereinstimmung:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $matchAll) {
                        Text("Alle Kriterien").tag(true)
                        Text("Mindestens eines").tag(false)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .labelsHidden()
                }

                Divider()
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(criteria) { criterion in
                    CriterionRow(
                        criterion: Binding(
                            get: { criteria.first(where: { $0.id == criterion.id }) ?? criterion },
                            set: { new in
                                if let i = criteria.firstIndex(where: { $0.id == new.id }) {
                                    criteria[i] = new
                                }
                            }
                        ),
                        onDelete: { criteria.removeAll { $0.id == criterion.id } },
                        excludingSmartFolderID: editing?.id
                    )
                }

                Button {
                    criteria.append(SmartFolderCriterion())
                } label: {
                    Label("Kriterium hinzufügen", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
                .padding(.top, 2)
            }

            Divider()

            HStack(spacing: 8) {
                Toggle("", isOn: $limitEnabled)
                    .labelsHidden()
                    .toggleStyle(CheckboxToggleStyle())
                Text("Begrenze auf")
                    .foregroundColor(limitEnabled ? .primary : .secondary)
                TextField("", value: $limitCount, formatter: {
                    let f = NumberFormatter()
                    f.numberStyle = .decimal
                    f.allowsFloats = false
                    f.minimum = 1
                    f.maximum = 10000
                    return f
                }())
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 60)
                .disabled(!limitEnabled)
                Text("Bilder, ausgewählt nach:")
                    .foregroundColor(limitEnabled ? .primary : .secondary)
                Picker("", selection: $limitSelection) {
                    ForEach(SmartFolderLimitSelection.allCases, id: \.self) { sel in
                        Text(sel.displayName).tag(sel)
                    }
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
                .frame(width: 170)
                .disabled(!limitEnabled)
            }

            Divider()

            // Basispfad-Einschränkung (iOrdner)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { baseFolderPath != nil },
                        set: { enabled in
                            if !enabled { baseFolderPath = nil }
                            else {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.allowsMultipleSelection = false
                                panel.prompt = "Auswählen"
                                if panel.runModal() == .OK, let url = panel.url {
                                    baseFolderPath = url.standardized.path
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(CheckboxToggleStyle())
                    Text("Auf Ordner einschränken")
                        .foregroundColor(baseFolderPath != nil ? .primary : .secondary)
                }
                if let path = baseFolderPath {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text(path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Wählen…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.prompt = "Auswählen"
                            panel.directoryURL = URL(fileURLWithPath: path)
                            if panel.runModal() == .OK, let url = panel.url {
                                baseFolderPath = url.standardized.path
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    }
                    .padding(.leading, 20)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Abbrechen") { presentationMode.wrappedValue.dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(editing == nil ? "Erstellen" : "Speichern") {
                    save()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    private func save() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let resolvedGroup: String? = group.trimmingCharacters(in: .whitespaces).isEmpty ? nil : group.trimmingCharacters(in: .whitespaces)
        if var sf = editing {
            sf.name = trimmed; sf.criteria = criteria; sf.matchAll = matchAll; sf.group = resolvedGroup
            sf.limitEnabled = limitEnabled; sf.limitCount = max(1, limitCount); sf.limitSelection = limitSelection
            sf.baseFolderPath = baseFolderPath
            viewModel.updateSmartFolder(sf)
        } else {
            var sf = SmartFolder(name: trimmed)
            sf.criteria = criteria; sf.matchAll = matchAll; sf.group = resolvedGroup
            sf.limitEnabled = limitEnabled; sf.limitCount = max(1, limitCount); sf.limitSelection = limitSelection
            sf.baseFolderPath = baseFolderPath
            viewModel.createSmartFolder(sf)
        }
    }
}

// MARK: - CriterionRow

private struct CriterionRow: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @Binding var criterion: SmartFolderCriterion
    let onDelete: () -> Void
    var excludingSmartFolderID: UUID? = nil

    var body: some View {
        HStack(spacing: 6) {
            // 1. Attribut-Picker
            Picker("", selection: $criterion.attribute) {
                ForEach(SmartFolderAttribute.allCases, id: \.self) { a in
                    Text(a.displayName).tag(a)
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .frame(width: 140)
            .onChange(of: criterion.attribute) { newAttr in
                // Operator zurücksetzen wenn er für den neuen Typ ungültig ist
                if !newAttr.availableOperators.contains(criterion.op) {
                    criterion.op = newAttr.defaultOperator
                }
            }

            // 2. Operator-Picker
            Picker("", selection: $criterion.op) {
                ForEach(criterion.attribute.availableOperators, id: \.self) { op in
                    Text(op.displayName).tag(op)
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .frame(width: 145)

            // 3. Wert-Input
            valueView

            Spacer(minLength: 0)

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(Color(NSColor.systemRed))
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: Value view

    @ViewBuilder
    private var valueView: some View {
        switch criterion.attribute {

        // --- Enum-Attribute ---
        case .flag:
            Picker("", selection: $criterion.flagValue) {
                Text("Ausgewählt (Pick)").tag(FlagStatus.pick)
                Text("Abgelehnt (Reject)").tag(FlagStatus.reject)
                Text("Keine Markierung").tag(FlagStatus.none)
            }
            .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 160)

        case .colorLabel:
            Picker("", selection: $criterion.colorValue) {
                Text("Rot").tag(ColorLabel.red)
                Text("Gelb").tag(ColorLabel.yellow)
                Text("Grün").tag(ColorLabel.green)
                Text("Blau").tag(ColorLabel.blue)
            }
            .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 100)

        case .isRAW:
            Picker("", selection: $criterion.boolValue) {
                Text("RAW").tag(true)
                Text("Nicht RAW").tag(false)
            }
            .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 100)

        case .orientation:
            Picker("", selection: $criterion.boolValue) {
                Text("Hochformat").tag(true)
                Text("Querformat").tag(false)
            }
            .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 110)

        case .hdr:
            Picker("", selection: $criterion.boolValue) {
                Text("HDR").tag(true)
                Text("Standard").tag(false)
            }
            .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 100)

        // --- Rating ---
        case .rating:
            if criterion.op == .inRange {
                HStack(spacing: 4) {
                    Stepper("", value: $criterion.ratingValue, in: 0...5).labelsHidden().frame(width: 60)
                    Text("\(criterion.ratingValue)★").font(.caption)
                    Text("–").font(.caption).foregroundColor(.secondary)
                    Stepper("", value: $criterion.ratingValue2, in: 0...5).labelsHidden().frame(width: 60)
                    Text("\(criterion.ratingValue2)★").font(.caption)
                }
            } else {
                HStack(spacing: 4) {
                    Stepper("", value: $criterion.ratingValue, in: 0...5).labelsHidden().frame(width: 60)
                    Text("\(criterion.ratingValue) ★").font(.caption).frame(width: 30)
                }
            }

        // --- ELO-Rating ---
        case .eloRating:
            Group {
                if criterion.op == .inRange {
                    numericRangeInput(unit: "ELO")
                } else {
                    numericSingleInput(unit: "ELO")
                }
            }
            .onAppear {
                if criterion.numericValue == 100 { criterion.numericValue = 1500 }
                if criterion.numericValue2 == 400 { criterion.numericValue2 = 1800 }
            }

        // --- ISO ---
        case .iso:
            if criterion.op == .inRange {
                numericRangeInput(unit: "ISO")
            } else {
                numericSingleInput(unit: "ISO")
            }

        // --- Brennweite ---
        case .focalLength:
            if criterion.op == .inRange {
                numericRangeInput(unit: "mm")
            } else {
                numericSingleInput(unit: "mm")
            }

        // --- Blende ---
        case .aperture:
            let fValues: [Double] = [1.0, 1.2, 1.4, 1.8, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
            if criterion.op == .inRange {
                HStack(spacing: 4) {
                    Picker("", selection: $criterion.numericValue) {
                        ForEach(fValues, id: \.self) { f in Text(fLabel(f)).tag(f) }
                    }
                    .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 70)
                    Text("–").font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $criterion.numericValue2) {
                        ForEach(fValues, id: \.self) { f in Text(fLabel(f)).tag(f) }
                    }
                    .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 70)
                }
            } else {
                Picker("", selection: $criterion.numericValue) {
                    ForEach(fValues, id: \.self) { f in Text(fLabel(f)).tag(f) }
                }
                .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 80)
            }

        // --- Aufnahmedatum ---
        case .captureDate:
            if criterion.op == .isDynamic {
                Picker("", selection: $criterion.dynamicDateRange) {
                    ForEach(DynamicDateRange.allCases, id: \.self) { d in
                        Text(d.displayName).tag(d)
                    }
                }
                .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 150)
            } else if criterion.op == .inDateRange {
                HStack(spacing: 4) {
                    DatePicker("", selection: $criterion.dateValue, displayedComponents: .date)
                        .labelsHidden().frame(width: 110)
                    Text("–").font(.caption).foregroundColor(.secondary)
                    DatePicker("", selection: $criterion.dateValue2, displayedComponents: .date)
                        .labelsHidden().frame(width: 110)
                }
            } else {
                DatePicker("", selection: $criterion.dateValue, displayedComponents: .date)
                    .labelsHidden().frame(width: 120)
            }

        // --- Film Simulation ---
        case .filmSimulation:
            Picker("", selection: $criterion.textValue) {
                ForEach(MetadataService.allFilmSimulations, id: \.self) { sim in
                    Text(sim).tag(sim)
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .frame(width: 180)
            .onAppear {
                if criterion.textValue.isEmpty {
                    criterion.textValue = MetadataService.allFilmSimulations.first ?? ""
                }
            }

        // --- Text-Attribute ---
        case .cameraMake, .cameraModel, .lens, .filename:
            TextField(textPlaceholder, text: $criterion.textValue)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 150)

        // --- Motiv (KI) ---
        case .motif:
            Picker("", selection: $criterion.textValue) {
                ForEach(MotifAssessor.knownLabels, id: \.id) { label in
                    Text(label.name).tag(label.id)
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .frame(width: 160)
            .onAppear {
                if criterion.textValue.isEmpty {
                    criterion.textValue = MotifAssessor.knownLabels.first?.id ?? ""
                }
            }

        // --- Album ---
        case .album:
            if viewModel.library.albums.isEmpty {
                Text("Keine Alben vorhanden")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                Picker("", selection: $criterion.textValue) {
                    Text("Bitte wählen").tag("")
                    ForEach(viewModel.library.albums) { album in
                        Text(album.name).tag(album.id.uuidString)
                    }
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
                .frame(width: 160)
                .onAppear {
                    if criterion.textValue.isEmpty, let first = viewModel.library.albums.first {
                        criterion.textValue = first.id.uuidString
                    }
                }
            }

        // --- Farbanteil ---
        case .colorRatio:
            HStack(spacing: 6) {
                if criterion.op == .inRange {
                    numericRangeInput(unit: "%")
                } else {
                    numericSingleInput(unit: "%")
                }
                Text("–").font(.caption).foregroundColor(.secondary)
                Picker("", selection: $criterion.textValue) {
                    Text("Rot (R)").tag("R")
                    Text("Grün (G)").tag("G")
                    Text("Blau (B)").tag("B")
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
                .frame(width: 90)
                .onAppear { if criterion.textValue.isEmpty { criterion.textValue = "R" } }
            }

        // --- Qualitätsmerkmale ---
        case .blurScore:
            if criterion.op == .inRange {
                numericRangeInput(unit: "%")
            } else {
                numericSingleInput(unit: "%")
            }

        case .isUnderexposed:
            Picker("", selection: $criterion.boolValue) {
                Text("Unterbelichtet").tag(true)
                Text("Nicht unterbelichtet").tag(false)
            }
            .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 160)

        case .isOverexposed:
            Picker("", selection: $criterion.boolValue) {
                Text("Überbelichtet").tag(true)
                Text("Nicht überbelichtet").tag(false)
            }
            .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 160)

        case .hasClosedEyes:
            Picker("", selection: $criterion.boolValue) {
                Text("Augen geschlossen").tag(true)
                Text("Augen offen").tag(false)
            }
            .labelsHidden().pickerStyle(MenuPickerStyle()).frame(width: 160)

        // --- Nicht in Album ---
        case .notInAlbum:
            Text("Keinem Album zugeordnet")
                .font(.caption).foregroundColor(.secondary)

        // --- Intelligenter Ordner (Rule-Tree) ---
        case .smartFolderRef:
            let available = viewModel.library.smartFolders.filter { $0.id != excludingSmartFolderID }
            if available.isEmpty {
                Text("Keine anderen Ordner")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                Picker("", selection: $criterion.textValue) {
                    Text("Bitte wählen").tag("")
                    ForEach(available) { sf in
                        Text(sf.name).tag(sf.id.uuidString)
                    }
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
                .frame(width: 160)
                .onAppear {
                    if criterion.textValue.isEmpty, let first = available.first {
                        criterion.textValue = first.id.uuidString
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func fLabel(_ f: Double) -> String {
        if f == f.rounded(.toNearestOrAwayFromZero) { return "f/\(Int(f.rounded()))" }
        return String(format: "f/%.1f", f)
    }

    @ViewBuilder
    private func numericSingleInput(unit: String) -> some View {
        HStack(spacing: 4) {
            TextField("", value: $criterion.numericValue, formatter: intFormatter)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 70)
            Text(unit).font(.caption).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func numericRangeInput(unit: String) -> some View {
        HStack(spacing: 4) {
            TextField("", value: $criterion.numericValue, formatter: intFormatter)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 65)
            Text("–").font(.caption).foregroundColor(.secondary)
            TextField("", value: $criterion.numericValue2, formatter: intFormatter)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 65)
            Text(unit).font(.caption).foregroundColor(.secondary)
        }
    }

    private var textPlaceholder: String {
        switch criterion.attribute {
        case .cameraMake: return "z.B. Fujifilm"
        case .cameraModel: return "z.B. X-T5"
        case .lens: return "z.B. 35mm"
        case .filename: return "z.B. DSC"
        default: return ""
        }
    }

    private var intFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.allowsFloats = false
        f.minimum = 0
        return f
    }
}
