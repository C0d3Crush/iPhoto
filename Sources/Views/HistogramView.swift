import SwiftUI
import AppKit

struct HistogramView: View {
    @ObservedObject var engine: AnalysisEngine

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Color.black
                if let img = engine.histogramImage {
                    Image(nsImage: NSImage(cgImage: img, size: .zero))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                        .allowsHitTesting(false)
                } else {
                    Text("Berechne…")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 12) {
                legendDot(color: .white,  label: "Luma")
                legendDot(color: .red,    label: "R")
                legendDot(color: .green,  label: "G")
                legendDot(color: .blue,   label: "B")
            }
            .font(.caption2)
            .padding(.top, 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundColor(.secondary)
        }
    }
}
