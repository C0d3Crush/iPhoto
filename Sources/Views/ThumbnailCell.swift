import SwiftUI

struct ThumbnailCell: View {
    let document: ImageDocument
    let isSelected: Bool
    var thumbnailWidth: CGFloat = 148
    var stackCount: Int = 0
    var isStackExpanded: Bool = false
    var isStackMember: Bool = false
    var onStackToggle: (() -> Void)? = nil
    var isBlurry: Bool = false
    var isUnder:  Bool = false
    var isOver:   Bool = false

    private var thumbH: CGFloat { (thumbnailWidth * 2 / 3).rounded() }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.quaternaryLabelColor))
                    .frame(width: thumbnailWidth, height: thumbH)

                if let thumb = document.thumbnailImage ?? document.placeholderThumbnailImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(width: thumbnailWidth, height: thumbH)
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
                    .frame(width: thumbnailWidth, height: thumbH)
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
                    .frame(width: thumbnailWidth, height: thumbH)
                }

                // Stack badge — top leading
            if stackCount > 1 {
                VStack {
                    HStack {
                        HStack(spacing: 2) {
                            Image(systemName: isStackExpanded ? "chevron.down" : "photo.on.rectangle")
                                .font(.system(size: 8, weight: .bold))
                            Text("\(stackCount)")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(4)
                        .padding([.top, .leading], 4)
                        .contentShape(Rectangle())
                        .onTapGesture { onStackToggle?() }
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: thumbnailWidth, height: thumbH)
            }

                flagAndQualityOverlay
            }

            Text(document.filename)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: thumbnailWidth)
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
                .frame(width: thumbnailWidth)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.accentColor
                              : (isStackMember ? Color.accentColor.opacity(0.35) : Color.clear),
                              lineWidth: isSelected ? 1.5 : 1)
        )
    }

    private func qualityBadge(system: String, color: Color) -> some View {
        Image(systemName: system)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .padding(2)
            .background(Circle().fill(color.opacity(0.85)))
    }

    // Separates VStack, damit der SwiftUI-Type-Checker die geschachtelte body nicht
    // aufgibt ("unable to type-check this expression in reasonable time").
    @ViewBuilder
    private var flagAndQualityOverlay: some View {
        if document.flagStatus != .none || isBlurry || isUnder || isOver {
            VStack {
                HStack(spacing: 3) {
                    Spacer()
                    if document.flagStatus != .none {
                        Image(systemName: document.flagStatus == .pick ? "flag.fill" : "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(document.flagStatus == .pick ? .green : .red)
                    }
                    if isBlurry { qualityBadge(system: "drop.triangle.fill",       color: .purple) }
                    if isUnder  { qualityBadge(system: "moon.fill",                color: .blue) }
                    if isOver   { qualityBadge(system: "sun.max.fill",             color: .yellow) }
                }
                .padding([.top, .trailing], 4)
                Spacer()
            }
            .frame(width: thumbnailWidth, height: thumbH)
        }
    }
}
