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

                if let thumb = document.thumbnailImage ?? document.placeholderThumbnailImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 148, height: 99)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .animation(.easeIn(duration: 0.15), value: document.thumbnailImage != nil)
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                // Color label dot — bottom leading
                if document.colorLabel != .none {
                    VStack {
                        Spacer()
                        HStack {
                            Circle()
                                .fill(Color(document.colorLabel.displayColor))
                                .frame(width: 8, height: 8)
                                .padding([.leading, .bottom], 4)
                            Spacer()
                        }
                    }
                    .frame(width: 148, height: 99)
                }

                // HDR badge — bottom trailing
                if document.metadata.first(where: { $0.key == "exif.HDR" })?.value == "Ja" {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("HDR")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(3)
                                .padding([.bottom, .trailing], 4)
                        }
                    }
                    .frame(width: 148, height: 99)
                }

                // Flag badge — top trailing
                if document.flagStatus != .none {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: document.flagStatus == .pick ? "flag.fill" : "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(document.flagStatus == .pick ? .green : .red)
                                .padding([.top, .trailing], 4)
                        }
                        Spacer()
                    }
                    .frame(width: 148, height: 99)
                }
            }

            Text(document.filename)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 148)
                .foregroundColor(isSelected ? .primary : .secondary)

            // Star rating
            if document.rating > 0 {
                HStack(spacing: 1) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= document.rating ? "star.fill" : "star")
                            .font(.system(size: 7))
                            .foregroundColor(star <= document.rating ? .yellow : Color(NSColor.tertiaryLabelColor))
                    }
                }
                .frame(width: 148)
            }
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
