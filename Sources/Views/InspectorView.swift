import SwiftUI

enum InspectorPanel: String, CaseIterable {
    case metadata = "Metadaten"

    var storageKey: String { "plugin.\(rawValue.lowercased())" }
}

struct InspectorView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @AppStorage("plugin.metadata") var metadataActive: Bool = true
    @State private var selectedPanel: InspectorPanel = .metadata

    private var activePanels: [InspectorPanel] {
        InspectorPanel.allCases.filter { panel in
            switch panel {
            case .metadata: return metadataActive
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if activePanels.isEmpty {
                Spacer()
                Text("Kein Plugin aktiv")
                    .foregroundColor(.secondary)
                    .font(.callout)
                Spacer()
            } else {
                if activePanels.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(activePanels, id: \.self) { panel in
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
                }

                currentPanelView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: activePanels.count) { _ in
            if !activePanels.contains(selectedPanel), let first = activePanels.first {
                selectedPanel = first
            }
        }
    }

    @ViewBuilder
    private var currentPanelView: some View {
        let panel = activePanels.contains(selectedPanel) ? selectedPanel : (activePanels.first ?? .metadata)
        switch panel {
        case .metadata:
            MetadataPanel()
                .environmentObject(viewModel)
        }
    }
}
