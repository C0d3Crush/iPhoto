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
        }
        .frame(width: 460, height: 320)
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
