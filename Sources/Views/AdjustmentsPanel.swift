import SwiftUI

// MARK: - Section model

private struct AdjSection: Identifiable {
    let id: String
    let label: String
    let icon: String
    let hasAuto: Bool
    let rows: [AdjRow]

    struct AdjRow {
        let label: String
        let key: WritableKeyPath<AdjustmentState, Double>
        let range: ClosedRange<Double>
        let format: String
        let neutral: Double
    }
}

// MARK: - Panel

struct AdjustmentsPanel: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @State private var expanded: Set<String> = []

    private let sections: [AdjSection] = [
        AdjSection(id: "licht", label: "Licht", icon: "sun.max", hasAuto: true, rows: [
            .init(label: "Belichtung",       key: \.exposure,      range: -2...2,       format: "%+.1f EV", neutral: 0),
            .init(label: "Helligkeit",       key: \.brightness,    range: -0.5...0.5,   format: "%+.2f",    neutral: 0),
            .init(label: "Kontrast",         key: \.contrast,      range: 0.5...1.5,    format: "%.2f",     neutral: 1),
        ]),
        AdjSection(id: "farbe", label: "Farbe", icon: "circle.righthalf.filled", hasAuto: true, rows: [
            .init(label: "Sättigung",        key: \.saturation,    range: 0...2,         format: "%.2f",    neutral: 1),
            .init(label: "Lebendigkeit",     key: \.vibrance,      range: -1...1,        format: "%+.2f",   neutral: 0),
            .init(label: "Farbton",          key: \.hue,           range: -180...180,    format: "%+.0f°",  neutral: 0),
        ]),
        AdjSection(id: "weiss", label: "Weißabgleich", icon: "thermometer.medium", hasAuto: false, rows: [
            .init(label: "Wärme",            key: \.warmth,        range: -50...50,      format: "%+.0f",   neutral: 0),
            .init(label: "Farbstich",        key: \.tint,          range: -50...50,      format: "%+.0f",   neutral: 0),
        ]),
        AdjSection(id: "aufl", label: "Auflösung", icon: "sparkles", hasAuto: true, rows: [
            .init(label: "Klarheit",         key: \.clarity,       range: -1...1,        format: "%+.2f",   neutral: 0),
            .init(label: "Textur",           key: \.texture,       range: -1...1,        format: "%+.2f",   neutral: 0),
            .init(label: "Dunst",            key: \.dehaze,        range: -1...1,        format: "%+.2f",   neutral: 0),
        ]),
        AdjSection(id: "rauschen", label: "Störungen reduzieren", icon: "waveform", hasAuto: false, rows: [
            .init(label: "Luma-Rauschen",    key: \.lumaNoise,     range: 0...100,       format: "%.0f",    neutral: 0),
            .init(label: "Farb-Rauschen",    key: \.colorNoise,    range: 0...100,       format: "%.0f",    neutral: 0),
        ]),
        AdjSection(id: "schaerfen", label: "Scharfzeichnen", icon: "line.diagonal", hasAuto: false, rows: [
            .init(label: "Schärfen",         key: \.sharpenAmount, range: 0...150,       format: "%.0f",    neutral: 0),
            .init(label: "Schärfen-Radius",  key: \.sharpenRadius, range: 0.5...3.0,    format: "%.1f px", neutral: 1.0),
        ]),
        AdjSection(id: "vignette", label: "Vignette & Optik", icon: "circle.dashed", hasAuto: false, rows: [
            .init(label: "Vignette",         key: \.vignetteAmount, range: -100...100,  format: "%+.0f",   neutral: 0),
            .init(label: "Vignetten-Radius", key: \.vignetteRadius, range: 0.3...1.0,  format: "%.2f",    neutral: 0.55),
            .init(label: "Verzeichnung",     key: \.distortion,     range: -100...100,  format: "%+.0f",   neutral: 0),
            .init(label: "Farbsaum",         key: \.caAmount,       range: 0...100,     format: "%.0f",    neutral: 0),
        ]),
    ]

    var body: some View {
        if viewModel.currentImage == nil {
            VStack {
                Spacer()
                Text("Kein Bild geladen").foregroundColor(.secondary).font(.callout)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                panelHeader
                Divider()
                cropRotateRow
                Divider()
                sectionsBody
                Divider()
                bottomButtons
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            Text("ANPASSEN")
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
                .foregroundColor(.primary)
            Spacer()
            Button(action: autoEnhanceAll) {
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 13))
                    .foregroundColor(.accentColor)
                    .padding(4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(5)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Automatisch optimieren (Licht + Farbe)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: - Crop / Rotate

    private var cropRotateRow: some View {
        HStack(spacing: 6) {
            Button(action: { viewModel.rotateLeft() }) {
                Image(systemName: "rotate.left").font(.system(size: 13)).frame(width: 28, height: 28)
            }
            .buttonStyle(PlainButtonStyle()).foregroundColor(.primary)
            .background(Color(NSColor.controlBackgroundColor).cornerRadius(6))
            .help("90° links drehen (⌘[)")

            Button(action: { viewModel.rotateRight() }) {
                Image(systemName: "rotate.right").font(.system(size: 13)).frame(width: 28, height: 28)
            }
            .buttonStyle(PlainButtonStyle()).foregroundColor(.primary)
            .background(Color(NSColor.controlBackgroundColor).cornerRadius(6))
            .help("90° rechts drehen (⌘])")

            Button(action: { viewModel.adj.cropToolActive = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "crop").font(.caption)
                    Text("Zuschneiden & Begradigen").font(.caption)
                    Spacer()
                    if hasCropOrRotation {
                        Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(.accentColor)
                    }
                    Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(Color(NSColor.controlBackgroundColor).cornerRadius(6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Sections

    private var sectionsBody: some View {
        VStack(spacing: 0) {
            ForEach(sections) { section in
                sectionView(section)
                Divider()
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: AdjSection) -> some View {
        // Header row — left area toggles expand; right buttons are independent
        HStack(spacing: 7) {
            // Expand/collapse tap area (chevron + icon + label)
            HStack(spacing: 7) {
                Image(systemName: expanded.contains(section.id) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 12)
                Image(systemName: section.icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSectionBypassed(section) ? .secondary : .primary)
                Text(section.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSectionBypassed(section) ? .secondary : .primary)
            }
            .contentShape(Rectangle())
            .onTapGesture { toggle(section.id) }

            Spacer()

            // ↺ reset
            Button(action: { resetSection(section) }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10))
                    .foregroundColor(isSectionNeutral(section)
                        ? Color(NSColor.disabledControlTextColor) : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSectionNeutral(section))
            .help("Abschnitt zurücksetzen")

            // AUTO pill
            if section.hasAuto {
                Button(action: { autoEnhanceSection(section) }) {
                    Text("AUTO")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(Color(NSColor.secondaryLabelColor).opacity(0.7), lineWidth: 0.75))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Automatisch optimieren")
            }

            // ○ section enable toggle
            Button(action: { toggleSectionBypass(section) }) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSectionBypassed(section) ? Color(NSColor.disabledControlTextColor) : Color.accentColor,
                            lineWidth: 1.5)
                        .frame(width: 17, height: 17)
                    if !isSectionBypassed(section) {
                        Circle().fill(Color.accentColor).frame(width: 9, height: 9)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .help(isSectionBypassed(section) ? "Abschnitt aktivieren" : "Abschnitt deaktivieren")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)

        // Expanded sliders
        if expanded.contains(section.id) {
            VStack(spacing: 0) {
                ForEach(section.rows.indices, id: \.self) { idx in
                    adjRow(section.rows[idx])
                    if idx < section.rows.count - 1 {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }

    // MARK: - Single slider row

    private func adjRow(_ row: AdjSection.AdjRow) -> some View {
        let value = Binding<Double>(
            get: { viewModel.adj.adjustments[keyPath: row.key] },
            set: { viewModel.adj.adjustments[keyPath: row.key] = $0 }
        )
        let bypassed = viewModel.adj.bypassedAdjustments.contains(row.key)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button(action: {
                    if bypassed {
                        viewModel.adj.bypassedAdjustments.remove(row.key)
                    } else {
                        viewModel.adj.bypassedAdjustments.insert(row.key)
                    }
                    viewModel.applyAdjustments()
                }) {
                    Image(systemName: bypassed ? "eye.slash" : "eye")
                        .font(.system(size: 9))
                        .foregroundColor(bypassed ? .accentColor : Color(NSColor.tertiaryLabelColor))
                        .frame(width: 14)
                }
                .buttonStyle(PlainButtonStyle())
                .help(bypassed ? "Einblenden" : "Ausblenden")

                Text(row.label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                AdjustmentValueField(value: value, format: row.format)
            }
            Slider(value: value, in: row.range) { editing in
                if !editing { viewModel.applyAdjustments(hiRes: true) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .opacity(bypassed ? 0.5 : 1.0)
    }

    // MARK: - Bottom

    private var bottomButtons: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button("Zurücksetzen") { viewModel.resetAdjustments() }
                    .disabled(isNeutral).buttonStyle(PlainButtonStyle())
                Button("Verwerfen") { viewModel.revertAdjustments() }
                    .disabled(isReverted).buttonStyle(PlainButtonStyle())
                    .help("Änderungen seit dem letzten Speichern verwerfen")
                Spacer()
                Button("Kopieren") { viewModel.copyAdjustments() }
                    .disabled(isNeutral).buttonStyle(PlainButtonStyle())
                    .help("Anpassungen in Zwischenablage")
                Button("Einfügen") { viewModel.pasteAdjustments() }
                    .disabled(viewModel.adj.copiedAdjustments == nil).buttonStyle(PlainButtonStyle())
                    .help("Auf aktuelles Bild oder Auswahl anwenden")
            }
            .font(.caption)
            Text("Original wird nie verändert — Exportieren zum Rendern")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var isNeutral: Bool  { !viewModel.hasActiveAdjustments }
    private var isReverted: Bool { viewModel.adj.adjustments == viewModel.adj.lastPersisted }

    private var hasCropOrRotation: Bool {
        viewModel.adj.adjustments.rotation != 0 ||
        viewModel.adj.adjustments.turns    != 0 ||
        viewModel.adj.adjustments.cropRect != CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    private func toggle(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    private func isSectionNeutral(_ section: AdjSection) -> Bool {
        section.rows.allSatisfy { viewModel.adj.adjustments[keyPath: $0.key] == $0.neutral }
    }

    private func isSectionBypassed(_ section: AdjSection) -> Bool {
        !section.rows.isEmpty &&
        section.rows.allSatisfy { viewModel.adj.bypassedAdjustments.contains($0.key) }
    }

    private func toggleSectionBypass(_ section: AdjSection) {
        if isSectionBypassed(section) {
            section.rows.forEach { viewModel.adj.bypassedAdjustments.remove($0.key) }
        } else {
            section.rows.forEach { viewModel.adj.bypassedAdjustments.insert($0.key) }
        }
        viewModel.applyAdjustments()
    }

    private func resetSection(_ section: AdjSection) {
        section.rows.forEach { viewModel.adj.adjustments[keyPath: $0.key] = $0.neutral }
        viewModel.applyAdjustments()
    }

    private func autoEnhanceSection(_ section: AdjSection) {
        guard let cgImage = viewModel.currentImage else { return }
        switch section.id {
        case "licht":
            let r = ImageAutoEnhancer.analyzeLight(cgImage)
            viewModel.adj.adjustments.exposure   = r.exposure
            viewModel.adj.adjustments.brightness = r.brightness
            viewModel.adj.adjustments.contrast   = r.contrast
        case "farbe":
            let r = ImageAutoEnhancer.analyzeColor(cgImage)
            viewModel.adj.adjustments.saturation = r.saturation
            viewModel.adj.adjustments.vibrance   = r.vibrance
            viewModel.adj.adjustments.hue        = 0.0
        case "aufl":
            viewModel.adj.adjustments.clarity  = 0.2
            viewModel.adj.adjustments.texture  = 0.1
            viewModel.adj.adjustments.dehaze   = 0.0
        default: break
        }
        section.rows.forEach { viewModel.adj.bypassedAdjustments.remove($0.key) }
        expanded.insert(section.id)
        viewModel.applyAdjustments(hiRes: true)
    }

    private func autoEnhanceAll() {
        guard let cgImage = viewModel.currentImage else { return }
        let light = ImageAutoEnhancer.analyzeLight(cgImage)
        viewModel.adj.adjustments.exposure   = light.exposure
        viewModel.adj.adjustments.brightness = light.brightness
        viewModel.adj.adjustments.contrast   = light.contrast
        let color = ImageAutoEnhancer.analyzeColor(cgImage)
        viewModel.adj.adjustments.saturation = color.saturation
        viewModel.adj.adjustments.vibrance   = color.vibrance
        viewModel.adj.adjustments.hue        = 0.0
        viewModel.adj.adjustments.clarity    = 0.2
        viewModel.adj.adjustments.texture    = 0.1
        // un-bypass all auto sections
        ["licht", "farbe", "aufl"].flatMap { id in
            sections.first(where: { $0.id == id })?.rows ?? []
        }.forEach { viewModel.adj.bypassedAdjustments.remove($0.key) }
        // expand auto sections
        ["licht", "farbe", "aufl"].forEach { expanded.insert($0) }
        viewModel.applyAdjustments(hiRes: true)
    }
}
