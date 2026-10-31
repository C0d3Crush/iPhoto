import SwiftUI

struct EloChampionsView: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private var rankedDocs: [ImageDocument] {
        viewModel.collection.documents
            .filter { !$0.isTrashed && $0.eloMatches > 0 }
            .sorted { $0.elo > $1.elo }
    }

    private var bestDocs: [ImageDocument] { Array(rankedDocs.prefix(10)) }
    private var worstDocs: [ImageDocument] {
        let all = rankedDocs
        guard all.count > 1 else { return [] }
        return Array(all.suffix(min(10, all.count - 1)).reversed())
    }

    var body: some View {
        ScrollView {
            if rankedDocs.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 36) {
                    championSection
                    if !worstDocs.isEmpty {
                        worstSection
                    }
                }
                .padding(28)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            Text("Noch keine ELO-Duelle")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Starte einen Bildvergleich, um ELO-Punkte zu vergeben.")
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    @ViewBuilder private var championSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.0))
                    .font(.title2)
                Text("Beste Bilder")
                    .font(.title2.bold())
                Spacer()
                Text("\(bestDocs.count) von \(rankedDocs.count) bewertet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(bestDocs.enumerated()), id: \.element.id) { rank, doc in
                        EloImageCard(doc: doc, rank: rank + 1, best: true)
                            .environmentObject(viewModel)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder private var worstSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title2)
                Text("Schlechteste Bilder")
                    .font(.title2.bold())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(worstDocs.enumerated()), id: \.element.id) { rank, doc in
                        EloImageCard(doc: doc, rank: rank + 1, best: false)
                            .environmentObject(viewModel)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}

private struct EloImageCard: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let doc: ImageDocument
    let rank: Int
    let best: Bool

    private var badgeColor: Color {
        guard best else { return .secondary }
        switch rank {
        case 1: return Color(red: 1.0, green: 0.78, blue: 0.0)
        case 2: return Color(red: 0.72, green: 0.72, blue: 0.72)
        case 3: return Color(red: 0.78, green: 0.48, blue: 0.18)
        default: return Color(NSColor.controlAccentColor)
        }
    }

    private var thumbHeight: CGFloat {
        switch rank {
        case 1: return 210
        case 2, 3: return 175
        default: return 145
        }
    }

    private var thumbWidth: CGFloat { thumbHeight * 1.4 }

    var body: some View {
        Button(action: {
            if let idx = viewModel.collectionIndex(for: doc) {
                viewModel.navSelection = .library
                viewModel.selectDocument(at: idx)
            }
        }) {
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    Group {
                        if let thumb = doc.thumbnailImage {
                            Image(nsImage: thumb)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Color(NSColor.controlBackgroundColor)
                                Image(systemName: "photo")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(width: thumbWidth, height: thumbHeight)
                    .clipped()
                    .cornerRadius(4)

                    Text(rank <= 3 && best ? rankLabel : "#\(rank)")
                        .font(.system(size: rank <= 3 && best ? 13 : 11, weight: .bold))
                        .foregroundColor(rank <= 3 && best ? .black : .white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(badgeColor)
                        .cornerRadius(3)
                        .padding(6)
                }

                VStack(spacing: 2) {
                    Text(doc.filename)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: thumbWidth, alignment: .leading)
                        .foregroundColor(.primary)
                    HStack(spacing: 4) {
                        Text(String(format: "%.0f ELO", doc.elo))
                            .font(.system(size: 11, design: .monospaced).bold())
                            .foregroundColor(best ? Color(red: 1.0, green: 0.78, blue: 0.0) : .secondary)
                        Text("·")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(doc.eloMatches) Duelle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(width: thumbWidth)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var rankLabel: String {
        switch rank {
        case 1: return "1. Platz"
        case 2: return "2. Platz"
        case 3: return "3. Platz"
        default: return "#\(rank)"
        }
    }
}
