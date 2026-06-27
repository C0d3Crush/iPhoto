import SwiftUI

struct RatingPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private var doc: ImageDocument? {
        let idx = viewModel.collection.currentIndex
        guard viewModel.collection.documents.indices.contains(idx) else { return nil }
        return viewModel.collection.documents[idx]
    }

    var body: some View {
        VStack(spacing: 14) {
            starRow
            Divider()
            flagRow
            Divider()
            colorRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    // MARK: Stars

    private var starRow: some View {
        VStack(spacing: 6) {
            Text("Bewertung")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: starIcon(star))
                        .font(.system(size: 22))
                        .foregroundColor(starColor(star))
                        .onTapGesture {
                            let current = doc?.rating ?? 0
                            viewModel.setRating(current == star ? 0 : star)
                        }
                        .contentShape(Rectangle())
                }

                if let rating = doc?.rating, rating > 0 {
                    Button(action: { viewModel.setRating(0) }) {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func starIcon(_ star: Int) -> String {
        (doc?.rating ?? 0) >= star ? "star.fill" : "star"
    }

    private func starColor(_ star: Int) -> Color {
        (doc?.rating ?? 0) >= star ? .yellow : Color(NSColor.tertiaryLabelColor)
    }

    // MARK: Flags

    private var flagRow: some View {
        VStack(spacing: 6) {
            Text("Markierung")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                flagButton(flag: .pick, icon: "flag.fill", label: "Pick", activeColor: .green)
                flagButton(flag: .reject, icon: "xmark", label: "Ablehnen", activeColor: .red)
                Spacer()
                Text(flagLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var flagLabel: String {
        switch doc?.flagStatus ?? .none {
        case .none:   return ""
        case .pick:   return "Ausgewählt"
        case .reject: return "Abgelehnt"
        }
    }

    @ViewBuilder
    private func flagButton(flag: FlagStatus, icon: String, label: String, activeColor: Color) -> some View {
        let isActive = doc?.flagStatus == flag
        Button(action: { viewModel.toggleFlag(flag) }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? activeColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isActive ? activeColor : .secondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? activeColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Color Labels

    private var colorRow: some View {
        VStack(spacing: 6) {
            Text("Farb-Label")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(ColorLabel.allCases, id: \.self) { label in
                    colorDot(label: label)
                }
                Spacer()
            }
        }
    }

    private func colorDot(label: ColorLabel) -> some View {
        let isActive = doc?.colorLabel == label
        let color = Color(label.displayColor)

        return ZStack {
            if label == .none {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if isActive {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 22, height: 22)
                if isActive {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    Circle()
                        .strokeBorder(color, lineWidth: 3)
                        .frame(width: 26, height: 26)
                }
            }
        }
        .onTapGesture { viewModel.setColorLabel(label) }
        .contentShape(Circle().size(CGSize(width: 30, height: 30)))
    }
}

extension ColorLabel: CaseIterable {
    public static var allCases: [ColorLabel] { [.none, .red, .yellow, .green, .blue] }
}
