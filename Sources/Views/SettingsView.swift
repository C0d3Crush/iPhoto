import SwiftUI

// Einstellungen-Panel (macOS Settings-Scene). Aktuell nur Qualitäts-Schwellenwerte:
// Blur/Belichtung. Werte werden in UserDefaults persistiert (siehe QualityDetectionState)
// und via Combine-Subscription in ImageViewModel automatisch auf die Listen angewendet.
struct SettingsView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @ObservedObject private var pluginStore = PluginStore.shared

    var body: some View {
        TabView {
            qualityTab
                .tabItem { Label("Qualität", systemImage: "wand.and.stars") }
            backupTab
                .tabItem { Label("Backup", systemImage: "externaldrive.badge.checkmark") }
            featuresTab
                .tabItem { Label("Funktionen", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 520, height: 500)
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

    private var featuresTab: some View {
        Form {
            Section(header: Text("Experimentelle Funktionen").font(.headline)) {
                expToggle(
                    title: "Ansicht wählen (Kachelansicht)",
                    description: "Zeigt den ⌘M-Button in der Toolbar und ermöglicht das Windows-8-ähnliche Kachelmenü zum schnellen Wechsel zwischen Modi.",
                    isOn: Binding(
                        get: { viewModel.modeSwitcherEnabled },
                        set: { viewModel.modeSwitcherEnabled = $0 }
                    )
                )

                Divider().padding(.vertical, 2)

                expToggle(
                    title: "Bildvergleich (ELO-Rating)",
                    description: "Duell-Modus in Seitenleiste und Inspector: zwei Bilder nebeneinander vergleichen, ELO-Score wird automatisch berechnet.",
                    isOn: Binding(
                        get: { pluginStore.isEnabled("com.iphoto.builtin.compare") },
                        set: {
                            pluginStore.setEnabled("com.iphoto.builtin.compare", $0)
                            if !$0 && viewModel.compare.active { viewModel.stopCompareMode() }
                        }
                    )
                )
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Tageslimit").font(.headline)) {
                Toggle(isOn: Binding(
                    get: { viewModel.compareDailyLimit > 0 },
                    set: { viewModel.compareDailyLimit = $0 ? 50 : 0 }
                )) {
                    Text("Tägliches Duell-Limit")
                }
                .disabled(!pluginStore.isEnabled("com.iphoto.builtin.compare"))

                if viewModel.compareDailyLimit > 0 {
                    HStack {
                        Text("Duelle pro Tag")
                            .frame(width: 130, alignment: .leading)
                        Stepper(value: Binding(
                            get: { viewModel.compareDailyLimit },
                            set: { viewModel.compareDailyLimit = max(5, $0) }
                        ), in: 5...500, step: 5) {
                            Text("\(viewModel.compareDailyLimit)")
                                .font(.body.monospacedDigit())
                        }
                    }
                    HStack {
                        Text("Heute")
                            .foregroundColor(.secondary)
                            .frame(width: 130, alignment: .leading)
                        ProgressView(value: Double(viewModel.compare.dailyCount),
                                     total: Double(viewModel.compareDailyLimit))
                        Text("\(viewModel.compare.dailyCount) / \(viewModel.compareDailyLimit)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("ELO-Konvergenz").font(.headline)) {
                let factor = viewModel.eloConvergenceFactor
                HStack {
                    Text("Stabilität")
                        .frame(width: 130, alignment: .leading)
                    ProgressView(value: factor)
                    Text(String(format: "%.0f %%", factor * 100))
                        .font(.body.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }
                Text("100 % ≈ 20 Duelle pro Bild (K-Faktor stabilisiert). Erst ab ~80 % sind ELO-Rankings verlässlich.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    private func expToggle(title: String, description: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
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
