import SwiftUI

struct ComparePanel: View {
    @EnvironmentObject var viewModel: ImageViewModel

    private var distributionChart: some View {
        let elos = viewModel.visibleDocuments.map { $0.elo }
        let leftElo  = viewModel.compareLeftDocument?.elo
        let rightElo = viewModel.compareRightDocument?.elo
        let pts = CompareView.kdePoints(elos: elos)
        return EloAreaGraph(points: pts, leftElo: leftElo, rightElo: rightElo) { lo, hi in
            viewModel.stopCompareMode()
            viewModel.navSelection = .eloRange(lo, hi)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { viewModel.toggleCompareMode() }) {
                HStack {
                    Image(systemName: viewModel.compare.active ? "xmark.circle" : "arrow.left.arrow.right")
                    Text(viewModel.compare.active ? "Vergleich beenden" : "Vergleich starten")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DefaultButtonStyle())
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Divider()
            distributionChart
        }
    }
}
