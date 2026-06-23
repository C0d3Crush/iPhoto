import SwiftUI

struct ThumbnailCell: View {
    let document: ImageDocument
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.quaternaryLabelColor))
                    .frame(width: 72, height: 48)

                if let thumb = document.thumbnailImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            Text(document.filename)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 72)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }
}
