import SwiftUI

struct SortMenuButton: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        Menu {
            ForEach(SortCriterion.allCases, id: \.self) { criterion in
                Button(action: {
                    if criterion == .random { viewModel.applyRandomShuffle() }
                    viewModel.sortCriterion = criterion
                }) {
                    Label(criterion.displayName, systemImage: criterion.icon)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .help("Sortierung")
    }
}
