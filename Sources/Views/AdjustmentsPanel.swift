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
                        // Rotate + Crop row
                        HStack(spacing: 6) {
                            Button(action: { viewModel.rotateLeft() }) {
                                Image(systemName: "rotate.left")
                                    .font(.system(size: 13))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.primary)
                            .background(Color(NSColor.controlBackgroundColor).cornerRadius(6))
                            .help("90° links drehen (⌘[)")

                            Button(action: { viewModel.rotateRight() }) {
                                Image(systemName: "rotate.right")
                                    .font(.system(size: 13))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.primary)
                            .background(Color(NSColor.controlBackgroundColor).cornerRadius(6))
                            .help("90° rechts drehen (⌘])")

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
                        }

                        Divider()

                        adjRow(label: "Belichtung",
                               key: \.exposure,
                               range: -2...2,
                               format: "%+.1f EV")

                        adjRow(label: "Helligkeit",
                               key: \.brightness,
                               range: -0.5...0.5,
                               format: "%+.2f")

                        adjRow(label: "Kontrast",
                               key: \.contrast,
                               range: 0.5...1.5,
                               format: "%.2f")

                        adjRow(label: "Sättigung",
                               key: \.saturation,
                               range: 0...2,
                               format: "%.2f")

                        adjRow(label: "Wärme",
                               key: \.warmth,
                               range: -1...1,
                               format: "%+.2f")

                        adjRow(label: "Farbstich",
                               key: \.tint,
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
                               key: \.clarity,
                               range: -1...1,
                               format: "%+.2f")

                        adjRow(label: "Textur",
                               key: \.texture,
                               range: -1...1,
                               format: "%+.2f")

                        adjRow(label: "Dunst",
                               key: \.dehaze,
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
                               key: \.sharpenAmount,
                               range: 0...150,
                               format: "%.0f")

                        adjRow(label: "Schärfen-Radius",
                               key: \.sharpenRadius,
                               range: 0.5...3.0,
                               format: "%.1f px")

                        adjRow(label: "Luma-Rauschen",
                               key: \.lumaNoise,
                               range: 0...100,
                               format: "%.0f")

                        adjRow(label: "Farb-Rauschen",
                               key: \.colorNoise,
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
                               key: \.vignetteAmount,
                               range: -100...100,
                               format: "%+.0f")

                        adjRow(label: "Verzeichnung",
                               key: \.distortion,
                               range: -100...100,
                               format: "%+.0f")

                        adjRow(label: "Farbsaum",
                               key: \.caAmount,
                               range: 0...100,
                               format: "%.0f")

                        Divider()

                        HStack(spacing: 6) {
                            Button("Zurücksetzen") { viewModel.resetAdjustments() }
                                .disabled(isNeutral)
                                .buttonStyle(PlainButtonStyle())
                            Spacer()
                            Button("Kopieren") { viewModel.copyAdjustments() }
                                .disabled(isNeutral)
                                .help("Anpassungen in Zwischenablage")
                                .buttonStyle(PlainButtonStyle())
                            Button("Einfügen") { viewModel.pasteAdjustments() }
                                .disabled(viewModel.copiedAdjustments == nil)
                                .help("Auf aktuelles Bild oder Auswahl anwenden")
                                .buttonStyle(PlainButtonStyle())
                        }
                        .font(.caption)

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
        viewModel.adjustments.turns    != 0 ||
        viewModel.adjustments.cropRect != CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    private var isRAW: Bool {
        viewModel.collection.currentDocument?.isRAW ?? false
    }

    private func adjRow(label: String, key: WritableKeyPath<AdjustmentState, Double>, range: ClosedRange<Double>, format: String) -> some View {
        let value = Binding<Double>(
            get: { viewModel.adjustments[keyPath: key] },
            set: { viewModel.adjustments[keyPath: key] = $0 }
        )
        let bypassed = viewModel.bypassedAdjustments.contains(key)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(action: {
                    if bypassed {
                        viewModel.bypassedAdjustments.remove(key)
                    } else {
                        viewModel.bypassedAdjustments.insert(key)
                    }
                    viewModel.applyAdjustments()
                }) {
                    Image(systemName: bypassed ? "eye.slash" : "eye")
                        .font(.caption2)
                        .foregroundColor(bypassed ? .accentColor : .secondary)
                        .frame(width: 16)
                }
                .buttonStyle(PlainButtonStyle())
                .help(bypassed ? "Effekt wieder einblenden" : "Effekt temporär ausblenden")

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                AdjustmentValueField(value: value, range: range, format: format)
            }
            Slider(value: value, in: range)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .opacity(bypassed ? 0.5 : 1.0)
    }
}
