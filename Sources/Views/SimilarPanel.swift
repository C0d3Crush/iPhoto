import SwiftUI

struct SimilarPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Status + open button
            HStack(spacing: 8) {
                if viewModel.quality.similarGroups.isEmpty {
                    Text("Keine ähnlichen Bilder gefunden")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 4) {
                        Text("\(viewModel.quality.similarGroups.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue)
                            .cornerRadius(4)
                        Text("Gruppen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Öffnen") {
                        viewModel.navSelection = .similar
                    }
                    .font(.caption)
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            Divider()

            // Action buttons
            HStack(spacing: 6) {
                Button(action: { viewModel.detectSimilarImages() }) {
                    Label("Neu gruppieren", systemImage: "arrow.triangle.2.circlepath")
                }
                .font(.caption)
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
    }
}
