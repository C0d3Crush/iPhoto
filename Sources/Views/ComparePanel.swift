import SwiftUI

struct ComparePanel: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        VStack(spacing: 8) {
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
            .padding(.vertical, 6)
        }
    }
}
