import SwiftUI

struct LocalAdjustmentsPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var expandedIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.currentImage == nil {
                Text("Kein Bild geladen")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(10)
            } else {
                let locals = viewModel.adj.adjustments.localAdjustments
                if locals.isEmpty {
                    Text("Noch keine lokalen Anpassungen")
                        .font(.caption2)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                } else {
                    ForEach(locals) { adj in
                        LocalAdjRow(
                            adj: adj,
                            isExpanded: expandedIDs.contains(adj.id),
                            onToggle: { toggleExpand(adj.id) },
                            onDelete: { deleteAdj(adj.id) },
                            onUpdate: { updated in updateAdj(updated) }
                        )
                        Divider()
                    }
                }

                HStack(spacing: 8) {
                    Menu("Verlauf hinzufügen") {
                        Button("Linearer Verlauf") { addLinear() }
                        Button("Radialer Verlauf") { addRadial() }
                    }
                    .font(.caption)
                    .disabled(viewModel.currentImage == nil)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
    }

    private func toggleExpand(_ id: UUID) {
        if expandedIDs.contains(id) { expandedIDs.remove(id) }
        else { expandedIDs.insert(id) }
    }

    private func deleteAdj(_ id: UUID) {
        viewModel.adj.adjustments.localAdjustments.removeAll { $0.id == id }
        expandedIDs.remove(id)
    }

    private func updateAdj(_ updated: LocalAdjustment) {
        guard let i = viewModel.adj.adjustments.localAdjustments.firstIndex(where: { $0.id == updated.id }) else { return }
        viewModel.adj.adjustments.localAdjustments[i] = updated
    }

    private func addLinear() {
        let adj = LocalAdjustment(
            label: "Linearer Verlauf",
            mask: .linearGradient(startX: 0.5, startY: 0.0, endX: 0.5, endY: 0.5)
        )
        viewModel.adj.adjustments.localAdjustments.append(adj)
        expandedIDs.insert(adj.id)
    }

    private func addRadial() {
        let adj = LocalAdjustment(
            label: "Radialer Verlauf",
            mask: .radialGradient(centerX: 0.5, centerY: 0.5, radius: 0.25, feather: 0.5)
        )
        viewModel.adj.adjustments.localAdjustments.append(adj)
        expandedIDs.insert(adj.id)
    }
}

// MARK: - Row

private struct LocalAdjRow: View {
    let adj: LocalAdjustment
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onUpdate: (LocalAdjustment) -> Void

    @State private var isHovered = false

    private var iconName: String {
        switch adj.mask {
        case .linearGradient: return "rectangle.and.hand.point.up.left"
        case .radialGradient: return "circle.dashed"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(adj.label.isEmpty ? maskName : adj.label)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }
            .onHover { isHovered = $0 }

            if isExpanded {
                LocalAdjEditor(adj: adj, onUpdate: onUpdate)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
    }

    private var maskName: String {
        switch adj.mask {
        case .linearGradient: return "Linearer Verlauf"
        case .radialGradient: return "Radialer Verlauf"
        }
    }
}

// MARK: - Editor

private struct LocalAdjEditor: View {
    let adj: LocalAdjustment
    let onUpdate: (LocalAdjustment) -> Void

    private func binding<T>(_ keyPath: WritableKeyPath<LocalAdjustment, T>) -> Binding<T> {
        Binding(get: { adj[keyPath: keyPath] },
                set: { new in var copy = adj; copy[keyPath: keyPath] = new; onUpdate(copy) })
    }

    private func deltaBinding<T>(_ keyPath: WritableKeyPath<LocalDelta, T>) -> Binding<T> {
        Binding(
            get: { adj.delta[keyPath: keyPath] },
            set: { new in var copy = adj; copy.delta[keyPath: keyPath] = new; onUpdate(copy) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Mask geometry
            maskEditor

            Divider()

            // Delta sliders
            Group {
                Text("Anpassungen")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)

                miniRow("Belichtung", value: deltaBinding(\.exposure), range: -2...2, format: "%+.1f")
                miniRow("Helligkeit", value: deltaBinding(\.brightness), range: -0.5...0.5, format: "%+.2f")
                miniRow("Kontrast",   value: deltaBinding(\.contrast),   range: 0.5...1.5, format: "%.2f")
                miniRow("Sättigung",  value: deltaBinding(\.saturation), range: 0...2,     format: "%.2f")
                miniRow("Wärme",      value: deltaBinding(\.warmth),     range: -1...1,    format: "%+.2f")
                miniRow("Farbstich",  value: deltaBinding(\.tint),       range: -1...1,    format: "%+.2f")
            }

            Divider()

            // Intensity + invert
            miniRow("Stärke", value: binding(\.intensity), range: 0...1, format: "%.0f%%",
                    displayScale: 100)
            Toggle("Maske invertieren", isOn: binding(\.inverted))
                .font(.caption2)
                .toggleStyle(CheckboxToggleStyle())
        }
    }

    @ViewBuilder
    private var maskEditor: some View {
        Text("Maske")
            .font(.caption2)
            .foregroundColor(.secondary)
            .fontWeight(.semibold)

        switch adj.mask {
        case .linearGradient:
            miniRow("Start X", value: maskLinearBinding(\.startX), range: 0...1, format: "%.2f")
            miniRow("Start Y", value: maskLinearBinding(\.startY), range: 0...1, format: "%.2f")
            miniRow("Ende X",  value: maskLinearBinding(\.endX),   range: 0...1, format: "%.2f")
            miniRow("Ende Y",  value: maskLinearBinding(\.endY),   range: 0...1, format: "%.2f")

        case .radialGradient:
            miniRow("Mitte X",        value: maskRadialBinding(\.centerX), range: 0...1,       format: "%.2f")
            miniRow("Mitte Y",        value: maskRadialBinding(\.centerY), range: 0...1,       format: "%.2f")
            miniRow("Radius",         value: maskRadialBinding(\.radius),  range: 0.01...0.99, format: "%.2f")
            miniRow("Weichzeichnung", value: maskRadialBinding(\.feather), range: 0...2,       format: "%.2f")
        }
    }

    // Helpers to produce bindings into enum associated values
    private func maskLinearBinding(_ kp: WritableKeyPath<LinearParams, Double>) -> Binding<Double> {
        Binding(
            get: {
                guard case .linearGradient(let sx, let sy, let ex, let ey) = adj.mask else { return 0 }
                let p = LinearParams(startX: sx, startY: sy, endX: ex, endY: ey)
                return p[keyPath: kp]
            },
            set: { val in
                guard case .linearGradient(let sx, let sy, let ex, let ey) = adj.mask else { return }
                var p = LinearParams(startX: sx, startY: sy, endX: ex, endY: ey)
                p[keyPath: kp] = val
                var copy = adj
                copy.mask = .linearGradient(startX: p.startX, startY: p.startY,
                                            endX: p.endX, endY: p.endY)
                onUpdate(copy)
            }
        )
    }

    private func maskRadialBinding(_ kp: WritableKeyPath<RadialParams, Double>) -> Binding<Double> {
        Binding(
            get: {
                guard case .radialGradient(let cx, let cy, let r, let f) = adj.mask else { return 0 }
                let p = RadialParams(centerX: cx, centerY: cy, radius: r, feather: f)
                return p[keyPath: kp]
            },
            set: { val in
                guard case .radialGradient(let cx, let cy, let r, let f) = adj.mask else { return }
                var p = RadialParams(centerX: cx, centerY: cy, radius: r, feather: f)
                p[keyPath: kp] = val
                var copy = adj
                copy.mask = .radialGradient(centerX: p.centerX, centerY: p.centerY,
                                            radius: p.radius, feather: p.feather)
                onUpdate(copy)
            }
        )
    }

    @ViewBuilder
    private func miniRow(_ label: String,
                         value: Binding<Double>,
                         range: ClosedRange<Double>,
                         format: String,
                         displayScale: Double = 1) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                AdjustmentValueField(value: value, format: format,
                                     displayScale: displayScale,
                                     font: .system(size: 9, design: .monospaced))
            }
            Slider(value: value, in: range)
        }
    }
}

// Mutable parameter structs used as binding intermediaries
private struct LinearParams {
    var startX, startY, endX, endY: Double
}

private struct RadialParams {
    var centerX, centerY, radius, feather: Double
}
