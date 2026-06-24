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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                .padding(16)
            }
        }
    }

    private var isNeutral: Bool {
        viewModel.adjExposure == 0 && viewModel.adjBrightness == 0 &&
        viewModel.adjContrast == 1 && viewModel.adjSaturation == 1 &&
        viewModel.adjWarmth == 0 &&
        zip(viewModel.adjCurvePoints, CurvesView.defaultPoints).allSatisfy {
            abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001
        }
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
