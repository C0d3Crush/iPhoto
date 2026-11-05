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
    var isEyesClosed: Bool = false
    var isBestInStack: Bool = false

    @AppStorage("grid.forceSquare")   private var forceSquare     = false
    @AppStorage("badge.rating")      private var showRating      = true
    @AppStorage("badge.colorLabel")  private var showColorLabel  = true
    @AppStorage("badge.flag")        private var showFlag        = true
    @AppStorage("badge.blurry")      private var showBlurry      = true
    @AppStorage("badge.under")       private var showUnder       = true
    @AppStorage("badge.over")        private var showOver        = true
    @AppStorage("badge.eyes")        private var showEyes        = true
    @AppStorage("badge.bestInStack") private var showBestInStack = true
    @AppStorage("badge.adjustments") private var showAdjustments = true
    @AppStorage("badge.hdr")         private var showHDR         = true

    private var thumbH: CGFloat { (thumbnailWidth * 2 / 3).rounded() }
    private var showDetails: Bool { !forceSquare && thumbnailWidth >= 50 }
    private var cornerR: CGFloat { showDetails ? 4 : 0 }

    var body: some View {
        if showDetails {
            detailedCell
        } else {
            compactCell
        }
    }

    // Full cell: thumbnail + filename + stars + badges
    private var detailedCell: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerR)
                    .fill(Color(NSColor.quaternaryLabelColor))
                    .frame(width: thumbnailWidth, height: thumbH)

                if let thumb = document.thumbnailImage ?? document.placeholderThumbnailImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(width: thumbnailWidth, height: thumbH)
                        .clipShape(RoundedRectangle(cornerRadius: cornerR))
                        .animation(.easeIn(duration: 0.15), value: document.thumbnailImage != nil)
                } else {
                    ProgressView().scaleEffect(0.6)
                }

                if showColorLabel && document.colorLabel != .none {
                    VStack { Spacer()
                        HStack { Circle().fill(Color(document.colorLabel.displayColor))
                            .frame(width: 8, height: 8).padding([.leading, .bottom], 4); Spacer() }
                    }.frame(width: thumbnailWidth, height: thumbH)
                }

                if showHDR && document.metadata.first(where: { $0.key == "exif.HDR" })?.value == "Ja" {
                    VStack { Spacer()
                        HStack { Spacer()
                            Text("HDR").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 4).padding(.vertical, 2)
                                .background(Color.orange).cornerRadius(3)
                                .padding([.bottom, .trailing], 4) }
                    }.frame(width: thumbnailWidth, height: thumbH)
                }

                if stackCount > 1 {
                    VStack {
                        HStack {
                            HStack(spacing: 2) {
                                Image(systemName: isStackExpanded ? "chevron.down" : "photo.on.rectangle")
                                    .font(.system(size: 8, weight: .bold))
                                Text("\(stackCount)").font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.black.opacity(0.65)).cornerRadius(4)
                            .padding([.top, .leading], 4)
                            .contentShape(Rectangle()).onTapGesture { onStackToggle?() }
                            Spacer()
                        }
                        Spacer()
                    }.frame(width: thumbnailWidth, height: thumbH)
                }

                flagAndQualityOverlay
            }

            Text(document.filename)
                .font(.caption2).lineLimit(1).frame(width: thumbnailWidth)
                .foregroundColor(isSelected ? .primary : .secondary)

            if showRating && document.rating > 0 {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= document.rating ? "star.fill" : "star")
                            .font(.system(size: 7))
                            .foregroundColor(star <= document.rating ? .yellow : Color(NSColor.tertiaryLabelColor))
                    }
                }.fixedSize()
            }
        }
        .background(RoundedRectangle(cornerRadius: 4).fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 4)
            .strokeBorder(isSelected ? Color.accentColor : (isStackMember ? Color.accentColor.opacity(0.35) : Color.clear),
                          lineWidth: isSelected ? 1.5 : 1))
    }

    // Compact cell: pure square thumbnail, no metadata
    private var compactCell: some View {
        ZStack {
            Color(NSColor.quaternaryLabelColor)

            if let thumb = document.thumbnailImage ?? document.placeholderThumbnailImage {
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbnailWidth, height: thumbnailWidth)
                    .clipped()
                    .animation(.easeIn(duration: 0.15), value: document.thumbnailImage != nil)
            }

            if isSelected {
                RoundedRectangle(cornerRadius: cornerR)
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
            }
        }
        .frame(width: thumbnailWidth, height: thumbnailWidth)
        .clipShape(RoundedRectangle(cornerRadius: cornerR))
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
        let hasAny = (showFlag && document.flagStatus != .none)
                     || (showBlurry && isBlurry) || (showUnder && isUnder) || (showOver && isOver)
                     || (showEyes && isEyesClosed) || (showBestInStack && isBestInStack)
                     || (showAdjustments && document.hasPersistedAdjustments)
        if hasAny {
            VStack {
                HStack(spacing: 3) {
                    Spacer()
                    if showBestInStack && isBestInStack {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                            .padding(3)
                            .background(Color.black.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    if showFlag && document.flagStatus != .none {
                        Image(systemName: document.flagStatus == .pick ? "flag.fill" : "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(document.flagStatus == .pick ? .green : .red)
                    }
                    if showBlurry     && isBlurry     { qualityBadge(system: "drop.triangle.fill", color: .purple) }
                    if showUnder      && isUnder       { qualityBadge(system: "moon.fill",          color: .blue) }
                    if showOver       && isOver        { qualityBadge(system: "sun.max.fill",       color: .yellow) }
                    if showEyes       && isEyesClosed  { qualityBadge(system: "eye.slash.fill",     color: .pink) }
                    if showAdjustments && document.hasPersistedAdjustments {
                        qualityBadge(system: "triangle.fill", color: .purple)
                    }
                }
                .padding([.top, .trailing], 4)
                Spacer()
            }
            .frame(width: thumbnailWidth, height: thumbH)
        }
    }
}
