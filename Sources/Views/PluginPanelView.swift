import SwiftUI

struct PluginPanelView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    let plugin: Plugin

    @State private var rowResults: [String: String] = [:]
    @State private var loading = false
    // Token incremented on each load; captured value compared before writing results.
    @State private var loadToken: UUID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(plugin.rows.indices, id: \.self) { i in
                rowView(plugin.rows[i])
                Divider().padding(.leading, 8)
            }
            if !plugin.actions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(plugin.actions.indices, id: \.self) { i in
                        let action = plugin.actions[i]
                        Button { runAction(action) } label: {
                            if let icon = action.icon {
                                Label(action.label, systemImage: icon)
                            } else {
                                Text(action.label)
                            }
                        }
                        .font(.caption)
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
        .onAppear { loadResults() }
        .onChange(of: viewModel.collection.currentDocument?.id) { _ in loadResults() }
    }

    @ViewBuilder
    private func rowView(_ row: Plugin.PluginRow) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(row.label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
                .padding(.top, 2)

            if let staticVal = row.staticValue {
                Text(staticVal.isEmpty ? "–" : staticVal)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let result = rowResults[row.label] {
                Text(result.isEmpty ? "–" : result)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if loading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else {
                Text("–")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func loadResults() {
        // Safe: called on Main thread only (onAppear / onChange).
        guard let url = viewModel.collection.currentDocument?.url else {
            rowResults = [:]
            return
        }
        let commandRows = plugin.rows.filter { $0.command != nil }
        guard !commandRows.isEmpty else { return }

        loading = true
        rowResults = [:]
        let token = UUID()
        loadToken = token

        // Debounce on Main — safe read of currentDocument here.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            guard loadToken == token,
                  viewModel.collection.currentDocument?.url == url else {
                if loadToken == token { loading = false }
                return
            }
            // Hand off to the serial plugin queue — no further viewModel access here.
            PluginStore.shared.pluginQueue.async {
                var results: [String: String] = [:]
                for row in commandRows {
                    guard let cmd = row.command else { continue }
                    results[row.label] = PluginStore.shared.run(command: cmd, imageURL: url)
                }
                DispatchQueue.main.async {
                    guard self.loadToken == token else { self.loading = false; return }
                    self.rowResults = results
                    self.loading = false
                }
            }
        }
    }

    private func runAction(_ action: Plugin.PluginAction) {
        guard let url = viewModel.collection.currentDocument?.url else { return }
        PluginStore.shared.pluginQueue.async {
            _ = PluginStore.shared.run(command: action.command, imageURL: url)
        }
    }
}
