import SwiftUI

struct PresetsPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var showSaveSheet = false
    @State private var newPresetName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            presetSection(title: "Film-Looks", presets: Preset.builtIn, deletable: false)
            Divider()
            presetSection(title: "Eigene Rezepte", presets: viewModel.adj.userPresets, deletable: true)
            Divider()
            bottomBar
        }
        .sheet(isPresented: $showSaveSheet) {
            SavePresetSheet(name: $newPresetName, isPresented: $showSaveSheet) { name in
                viewModel.saveCurrentAsPreset(name: name)
            }
        }
    }

    @ViewBuilder
    private func presetSection(title: String, presets: [Preset], deletable: Bool) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 4)

        if presets.isEmpty {
            Text("Keine Rezepte")
                .font(.caption2)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
        } else {
            ForEach(presets) { preset in
                PresetRow(preset: preset, deletable: deletable)
                    .environmentObject(viewModel)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button("Importieren") { viewModel.importRecipe() }
                .font(.caption)
            Spacer()
            if viewModel.hasActiveAdjustments {
                Button("Zurücksetzen") { viewModel.resetAdjustments() }
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button("Als Rezept speichern") {
                newPresetName = ""
                showSaveSheet = true
            }
            .font(.caption)
            .disabled(viewModel.currentImage == nil)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct PresetRow: View {
    let preset: Preset
    let deletable: Bool
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var isHovered = false
    @State private var justApplied = false
    @State private var snapshotBeforeApply: AdjustmentState? = nil

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name)
                    .font(.caption)
                    .fontWeight(.medium)
                if let author = preset.author, author != "iPhoto" {
                    Text(author)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if justApplied {
                Button {
                    if let snap = snapshotBeforeApply {
                        viewModel.adj.adjustments = snap
                    }
                    justApplied = false
                    snapshotBeforeApply = nil
                } label: {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                if isHovered {
                    if deletable {
                        Button(action: { viewModel.deletePreset(preset) }) {
                            Image(systemName: "trash")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Button(action: { viewModel.exportRecipe(preset) }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Button("Anwenden") {
                    snapshotBeforeApply = viewModel.adj.adjustments
                    viewModel.applyPreset(preset)
                    justApplied = true
                }
                .font(.caption2)
                .disabled(viewModel.currentImage == nil)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isHovered || justApplied ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .onHover { isHovered = $0 }
        .onChange(of: viewModel.collection.currentIndex) { _ in
            justApplied = false
            snapshotBeforeApply = nil
        }
    }
}

private struct SavePresetSheet: View {
    @Binding var name: String
    @Binding var isPresented: Bool
    let onSave: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Rezept speichern").font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 240)
            HStack(spacing: 12) {
                Button("Abbrechen") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Speichern") {
                    onSave(name.trimmingCharacters(in: .whitespaces))
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }
}
