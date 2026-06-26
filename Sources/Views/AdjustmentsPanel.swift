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
                               value: $viewModel.adjExposure,
                               range: -2...2,
                               format: "%+.1f EV")

                        adjRow(label: "Helligkeit",
                               value: $viewModel.adjBrightness,
                               range: -0.5...0.5,
                               format: "%+.2f")

                        adjRow(label: "Kontrast",
                               value: $viewModel.adjContrast,
                               range: 0.5...1.5,
                               format: "%.2f")

                        adjRow(label: "Sättigung",
                               value: $viewModel.adjSaturation,
                               range: 0...2,
                               format: "%.2f")

                        adjRow(label: "Wärme",
                               value: $viewModel.adjWarmth,
                               range: -1...1,
                               format: "%+.2f")

                        adjRow(label: "Farbstich",
                               value: $viewModel.adjTint,
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
                               value: $viewModel.adjClarity,
                               range: -1...1,
                               format: "%+.2f")

                        adjRow(label: "Textur",
                               value: $viewModel.adjTexture,
                               range: -1...1,
                               format: "%+.2f")

                        adjRow(label: "Dunst",
                               value: $viewModel.adjDehaze,
                               range: -1...1,
                               format: "%+.2f")

                        Divider()

                        HStack(spacing: 8) {
                            Button("Zurücksetzen") {
                                viewModel.resetAdjustments()
                            }
                            .disabled(isNeutral)
                            Spacer()
                        }

                        Text(isRAW ? "RAW — Exportieren zum Speichern" : "Vorschau — Original nicht verändert")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
        }
    }

    private var isNeutral: Bool { !viewModel.hasActiveAdjustments }

    private var hasCropOrRotation: Bool {
        viewModel.adjRotation != 0 ||
        viewModel.adjCropRect != CGRect(x: 0, y: 0, width: 1, height: 1)
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
        }
    }
}
