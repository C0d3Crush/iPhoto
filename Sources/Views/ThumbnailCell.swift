import SwiftUI

struct ThumbnailCell: View {
    let document: ImageDocument
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.quaternaryLabelColor))
                    .frame(width: 148, height: 99)

                if let thumb = document.thumbnailImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 148, height: 99)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            Text(document.filename)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 148)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .padding(2)
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
