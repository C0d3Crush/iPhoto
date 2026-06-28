import SwiftUI

struct AdjustmentsPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        if viewModel.currentImage == nil {
            VStack {
                Spacer()
                Text("Kein Bild geladen")
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                    Group {
                        // Crop tool
                        Button(action: { viewModel.cropToolActive = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "crop")
                                    .font(.caption)
                                Text("Zuschneiden & Begradigen")
                                    .font(.caption)
                                Spacer()
                                if hasCropOrRotation {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.primary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color(NSColor.controlBackgroundColor).cornerRadius(6))
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()

                        adjRow(label: "Belichtung",
                               value: $viewModel.adjustments.exposure,
                               range: -2...2,
                               format: "%+.1f EV")

                        adjRow(label: "Helligkeit",
                               value: $viewModel.adjustments.brightness,
                               range: -0.5...0.5,
                               format: "%+.2f")

                        adjRow(label: "Kontrast",
                               value: $viewModel.adjustments.contrast,
                               range: 0.5...1.5,
                               format: "%.2f")

                        adjRow(label: "Sättigung",
                               value: $viewModel.adjustments.saturation,
                               range: 0...2,
                               format: "%.2f")

                        adjRow(label: "Wärme",
                               value: $viewModel.adjustments.warmth,
                               range: -1...1,
                               format: "%+.2f")

                        adjRow(label: "Farbstich",
                               value: $viewModel.adjustments.tint,
                               range: -1...1,
                               format: "%+.2f")
                    }

                    Group {
                        Divider()

                        Text("Detail")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)

                        adjRow(label: "Klarheit",
                               value: $viewModel.adjustments.clarity,
                               range: -1...1,
                               format: "%+.2f")

                        adjRow(label: "Textur",
                               value: $viewModel.adjustments.texture,
                               range: -1...1,
                               format: "%+.2f")

                        adjRow(label: "Dunst",
                               value: $viewModel.adjustments.dehaze,
                               range: -1...1,
                               format: "%+.2f")
                    }

                    Group {
                        Divider()

                        Text("Schärfe & Rauschen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)

                        adjRow(label: "Schärfen",
                               value: $viewModel.adjustments.sharpenAmount,
                               range: 0...150,
                               format: "%.0f")

                        adjRow(label: "Schärfen-Radius",
                               value: $viewModel.adjustments.sharpenRadius,
                               range: 0.5...3.0,
                               format: "%.1f px")

                        adjRow(label: "Luma-Rauschen",
                               value: $viewModel.adjustments.lumaNoise,
                               range: 0...100,
                               format: "%.0f")

                        adjRow(label: "Farb-Rauschen",
                               value: $viewModel.adjustments.colorNoise,
                               range: 0...100,
                               format: "%.0f")
                    }

                    Group {
                        Divider()

                        Text("Objektiv")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)

                        adjRow(label: "Vignette",
                               value: $viewModel.adjustments.vignetteAmount,
                               range: -100...100,
                               format: "%+.0f")

                        adjRow(label: "Verzeichnung",
                               value: $viewModel.adjustments.distortion,
                               range: -100...100,
                               format: "%+.0f")

                        adjRow(label: "Farbsaum",
                               value: $viewModel.adjustments.caAmount,
                               range: 0...100,
                               format: "%.0f")

                        Divider()

                        HStack(spacing: 6) {
                            Button("Zurücksetzen") { viewModel.resetAdjustments() }
                                .disabled(isNeutral)
                            Spacer()
                            Button("Kopieren") { viewModel.copyAdjustments() }
                                .disabled(isNeutral)
                                .help("Anpassungen in Zwischenablage")
                            Button("Einfügen") { viewModel.pasteAdjustments() }
                                .disabled(viewModel.copiedAdjustments == nil)
                                .help("Auf aktuelles Bild oder Auswahl anwenden")
                        }

                        Text("Original wird nie verändert — Exportieren zum Rendern")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
        }
    }

    private var isNeutral: Bool { !viewModel.hasActiveAdjustments }

    private var hasCropOrRotation: Bool {
        viewModel.adjustments.rotation != 0 ||
        viewModel.adjustments.cropRect != CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    private var isRAW: Bool {
        viewModel.collection.currentDocument?.isRAW ?? false
    }

    @ViewBuilder
    private func adjRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.primary)
            }
            Slider(value: value, in: range)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}
