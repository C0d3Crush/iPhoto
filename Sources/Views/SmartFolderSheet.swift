import SwiftUI

struct SmartFolderSheet: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var editing: SmartFolder?

    @Binding var isPresented: Bool

    @State private var name: String
    @State private var matchAll: Bool
    @State private var criteria: [SmartFolderCriterion]

    init(editing: SmartFolder? = nil, isPresented: Binding<Bool>) {
        self.editing = editing
        self._isPresented = isPresented
        _name      = State(initialValue: editing?.name ?? "")
        _matchAll  = State(initialValue: editing?.matchAll ?? true)
        _criteria  = State(initialValue: editing?.criteria ?? [SmartFolderCriterion()])
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
                Button("Abbrechen") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(editing == nil ? "Erstellen" : "Speichern") {
                    save()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if var sf = editing {
            sf.name = trimmed
            sf.criteria = criteria
            sf.matchAll = matchAll
            viewModel.updateSmartFolder(sf)
        } else {
            var sf = SmartFolder(name: trimmed)
            sf.criteria = criteria
            sf.matchAll = matchAll
            viewModel.createSmartFolder(sf)
        }
    }
}

private struct CriterionRow: View {
    @Binding var criterion: SmartFolderCriterion
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $criterion.kind) {
                ForEach(SmartFolderCriterionKind.allCases, id: \.self) { k in
                    Text(k.displayName).tag(k)
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .frame(width: 165)

            criterionValueView

            Spacer(minLength: 0)

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(Color(NSColor.systemRed))
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private var criterionValueView: some View {
        switch criterion.kind {
        case .flag:
            Picker("", selection: $criterion.flagValue) {
                Text("Ausgewählt (Pick)").tag(FlagStatus.pick)
                Text("Abgelehnt (Reject)").tag(FlagStatus.reject)
                Text("Keine Markierung").tag(FlagStatus.none)
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .frame(width: 150)

        case .ratingAtLeast:
            HStack(spacing: 4) {
                Stepper("", value: $criterion.ratingValue, in: 1...5)
                    .labelsHidden()
                    .frame(width: 60)
                Text("\(criterion.ratingValue) ★")
                    .font(.caption)
                    .frame(width: 30)
            }

        case .colorLabel:
            Picker("", selection: $criterion.colorValue) {
                Text("Rot").tag(ColorLabel.red)
                Text("Gelb").tag(ColorLabel.yellow)
                Text("Grün").tag(ColorLabel.green)
                Text("Blau").tag(ColorLabel.blue)
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .frame(width: 100)

        case .cameraMake, .cameraModel:
            TextField("z.B. Sony", text: $criterion.textValue)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 150)
        }
    }
}
