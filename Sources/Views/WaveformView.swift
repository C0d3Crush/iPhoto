import SwiftUI
import AppKit

struct WaveformView: View {
    @ObservedObject var engine: AnalysisEngine
    let isParade: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isParade {
                paradeView
            } else {
                waveformView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var waveformView: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                guideLines
                if let img = engine.waveformImage {
                    Image(nsImage: NSImage(cgImage: img, size: .zero))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    Text("Berechne…").font(.caption2).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 140)
            .clipShape(RoundedRectangle(cornerRadius: 4))

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

    private var paradeView: some View {
        let channelInfo: [(String, Color)] = [("R", .red), ("G", .green), ("B", .blue)]
        return VStack(spacing: 3) {
            if let img = engine.rgbParadeImage {
                let cgH = img.height / 3
                ForEach(0..<3, id: \.self) { i in
                    HStack(spacing: 6) {
                        Text(channelInfo[i].0)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(channelInfo[i].1)
                            .frame(width: 10)
                        ZStack {
                            Color.black
                            if let slice = img.cropping(to: CGRect(x: 0, y: i * cgH, width: img.width, height: cgH)) {
                                Image(nsImage: NSImage(cgImage: slice, size: .zero))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            } else {
                Text("Berechne…").font(.caption2).foregroundColor(.secondary)
                    .frame(height: 258)
            }
        }
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
