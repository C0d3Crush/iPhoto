import SwiftUI

// Einstellungen-Panel (macOS Settings-Scene). Aktuell nur Qualitäts-Schwellenwerte:
// Blur/Belichtung. Werte werden in UserDefaults persistiert (siehe QualityDetectionState)
// und via Combine-Subscription in ImageViewModel automatisch auf die Listen angewendet.
struct SettingsView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        TabView {
            qualityTab
                .tabItem { Label("Qualität", systemImage: "wand.and.stars") }
            backupTab
                .tabItem { Label("Backup", systemImage: "externaldrive.badge.checkmark") }
        }
        .frame(width: 520, height: 420)
    }

    // MARK: - Backup

    private var backupTab: some View {
        let s = viewModel.backupSettings
        return Form {
            Section(header: Text("Zielordner").font(.headline)) {
                HStack {
                    Text(s.destinationDisplayPath)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Wählen…") { pickBackupDestination() }
                }
                Text("Backups werden nach `<Jahr>/<Monat>/` einsortiert (Aufnahmedatum aus EXIF, Fallback: Dateidatum).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("JPEG-Qualität").font(.headline)) {
                HStack {
                    Slider(value: Binding(
                        get: { s.jpegQuality },
                        set: { s.jpegQuality = $0 }
                    ), in: 0.5...1.0, step: 0.01)
                    Text(String(format: "%.0f %%", s.jpegQuality * 100))
                        .font(.body.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                Text("0.85 entspricht dem Export-Standard — sichtbar verlustfrei bei ~30–50 % Dateigröße.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Metadaten & Auflösung").font(.headline)) {
                Toggle(isOn: Binding(get: { s.copyMetadata }, set: { s.copyMetadata = $0 })) {
                    Text("EXIF/GPS/Kamera-Metadaten mitkopieren")
                }
                Toggle(isOn: Binding(get: { s.downscaleEnabled }, set: { s.downscaleEnabled = $0 })) {
                    Text("Auflösung reduzieren")
                }
                HStack {
                    Text("Lange Kante")
                        .frame(width: 110, alignment: .leading)
                        .foregroundColor(s.downscaleEnabled ? .primary : .secondary)
                    Stepper(value: Binding(
                        get: { s.longSidePixels },
                        set: { s.longSidePixels = max(320, $0) }
                    ), in: 320...12000, step: 128) {
                        Text("\(s.longSidePixels) px")
                            .font(.body.monospacedDigit())
                    }
                    .disabled(!s.downscaleEnabled)
                }
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Bei bestehender Datei").font(.headline)) {
                Picker("", selection: Binding(
                    get: { s.collisionMode },
                    set: { s.collisionMode = $0 }
                )) {
                    ForEach(BackupSettings.CollisionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(RadioGroupPickerStyle())
                .labelsHidden()
            }
        }
        .padding(20)
    }

    private func pickBackupDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Wählen"
        panel.title = "Backup-Zielordner wählen"
        panel.directoryURL = URL(fileURLWithPath: viewModel.backupSettings.destinationDisplayPath)
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.backupSettings.setDestination(url)
        }
    }

    private var qualityTab: some View {
        Form {
            Section(header: Text("Unschärfe-Erkennung").font(.headline)) {
                thresholdRow(
                    title: "Schwellenwert",
                    value: Binding(
                        get: { viewModel.quality.blurThreshold },
                        set: { viewModel.quality.blurThreshold = $0 }
                    ),
                    range: 20...400, step: 10,
                    format: { String(format: "%.0f", $0) },
                    hint: "Bilder mit Laplacian-Varianz unter diesem Wert gelten als unscharf."
                )
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Unterbelichtung").font(.headline)) {
                thresholdRow(
                    title: "Schatten-Clip",
                    value: Binding(
                        get: { viewModel.quality.shadowClipThreshold },
                        set: { viewModel.quality.shadowClipThreshold = $0 }
                    ),
                    range: 0.01...0.30, step: 0.01,
                    format: { String(format: "%.0f %%", $0 * 100) },
                    hint: "Anteil sehr dunkler Pixel, ab dem ein Bild als unterbelichtet gilt."
                )
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Überbelichtung").font(.headline)) {
                thresholdRow(
                    title: "Lichter-Clip",
                    value: Binding(
                        get: { viewModel.quality.highlightClipThreshold },
                        set: { viewModel.quality.highlightClipThreshold = $0 }
                    ),
                    range: 0.01...0.30, step: 0.01,
                    format: { String(format: "%.0f %%", $0 * 100) },
                    hint: "Anteil sehr heller Pixel, ab dem ein Bild als überbelichtet gilt."
                )
            }

            HStack {
                Spacer()
                Button("Auf Standard zurücksetzen") {
                    viewModel.quality.resetThresholdsToDefaults()
                }
            }
            .padding(.top, 10)
        }
        .padding(20)
    }

    @ViewBuilder
    private func thresholdRow(title: String,
                              value: Binding<Double>,
                              range: ClosedRange<Double>, step: Double,
                              format: @escaping (Double) -> String,
                              hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).frame(width: 110, alignment: .leading)
                Slider(value: value, in: range, step: step)
                Text(format(value.wrappedValue))
                    .font(.body.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            Text(hint)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 110)
        }
    }
}
