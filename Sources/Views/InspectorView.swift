import SwiftUI

enum InspectorPanel: String, CaseIterable {
    case metadata = "Metadaten"
}

struct InspectorView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var selectedPanel: InspectorPanel = .metadata

    var body: some View {
        VStack(spacing: 0) {
            // Panel selector
            HStack(spacing: 4) {
                ForEach(InspectorPanel.allCases, id: \.self) { panel in
                    Button(action: { selectedPanel = panel }) {
                        Text(panel.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedPanel == panel
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(selectedPanel == panel ? .accentColor : .secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider()

            Group {
                switch selectedPanel {
                case .metadata:
                    MetadataPanel()
                        .environmentObject(viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
