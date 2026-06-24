import SwiftUI
import AppKit

struct WaveformView: View {
    let engine: AnalysisEngine
    let isParade: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                guideLines
                if let img = isParade ? engine.rgbParadeImage : engine.waveformImage {
                    Image(nsImage: NSImage(cgImage: img, size: .zero))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    Text("Berechne…")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 160)
            .cornerRadius(4)

            if isParade {
                HStack {
                    ForEach(["R", "G", "B"], id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .foregroundColor(label == "R" ? .red : label == "G" ? .green : .blue)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            } else {
                HStack {
                    Text("0%").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("50%").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("100%").font(.caption2).foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var guideLines: some View {
        GeometryReader { geo in
            Path { path in
                for frac in [0.25, 0.5, 0.75] as [CGFloat] {
                    let y = frac * geo.size.height
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        }
    }
}
