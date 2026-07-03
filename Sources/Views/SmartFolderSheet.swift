import SwiftUI

struct SmartFolderSheetItem: Identifiable {
    let id = UUID()
    let folder: SmartFolder?
}

struct SmartFolderSheet: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @Environment(\.presentationMode) private var presentationMode

    var editing: SmartFolder?

    @State private var name: String
    @State private var matchAll: Bool
    @State private var criteria: [SmartFolderCriterion]

    init(editing: SmartFolder? = nil) {
        self.editing = editing
        _name     = State(initialValue: editing?.name ?? "")
        _matchAll = State(initialValue: editing?.matchAll ?? true)
        _criteria = State(initialValue: editing?.criteria ?? [SmartFolderCriterion()])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "Intelligenter Ordner" : "Ordner bearbeiten")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())

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

            VStack(alignment: .leading, spacing: 6) {
                ForEach(criteria.indices, id: \.self) { i in
                    CriterionRow(criterion: $criteria[i]) {
                        criteria.remove(at: i)
                    }
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
        if var sf = editing {
            sf.name = trimmed; sf.criteria = criteria; sf.matchAll = matchAll
            viewModel.updateSmartFolder(sf)
        } else {
            var sf = SmartFolder(name: trimmed)
            sf.criteria = criteria; sf.matchAll = matchAll
            viewModel.createSmartFolder(sf)
        }
    }
}

// MARK: - CriterionRow

private struct CriterionRow: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @Binding var criterion: SmartFolderCriterion
    let onDelete: () -> Void

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

        // --- Text-Attribute ---
        case .cameraMake, .cameraModel, .lens, .filename:
            TextField(textPlaceholder, text: $criterion.textValue)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 150)

        // --- Album ---
        case .album:
            if viewModel.albums.isEmpty {
                Text("Keine Alben vorhanden")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                Picker("", selection: $criterion.textValue) {
                    Text("Bitte wählen").tag("")
                    ForEach(viewModel.albums) { album in
                        Text(album.name).tag(album.id.uuidString)
                    }
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
                .frame(width: 160)
                .onAppear {
                    if criterion.textValue.isEmpty, let first = viewModel.albums.first {
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
