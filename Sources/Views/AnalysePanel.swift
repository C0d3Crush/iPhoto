import SwiftUI

private enum AnalyseTool: String, CaseIterable {
    case histogram = "Histogramm"
    case waveform  = "Waveform"
    case parade    = "RGB-Parade"
    case curves    = "Kurven"
}

struct AnalysePanel: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @StateObject private var engine = AnalysisEngine()
    @State private var tool: AnalyseTool = .histogram

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
            VStack(spacing: 0) {
                toolPicker
                Divider()
                ScrollView {
                    switch tool {
                    case .histogram:
                        HistogramView(engine: engine)
                    case .waveform:
                        WaveformView(engine: engine, isParade: false)
                    case .parade:
                        WaveformView(engine: engine, isParade: true)
                    case .curves:
                        CurvesView()
                            .environmentObject(viewModel)
                    }
                }
            }
            .onAppear { triggerAnalysis() }
            .onChange(of: viewModel.displayImageVersion) { _ in triggerAnalysis() }
        }
    }

    private var toolPicker: some View {
        HStack(spacing: 2) {
            ForEach(AnalyseTool.allCases, id: \.self) { t in
                Button(action: { tool = t }) {
                    Text(t.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(tool == t ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(tool == t ? .accentColor : .secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func triggerAnalysis() {
        if let img = viewModel.adjustedImage ?? viewModel.currentImage {
            engine.analyze(img)
        }
    }
}
