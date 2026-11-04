import SwiftUI

// Einstellungen-Panel (macOS Settings-Scene). Aktuell nur Qualitäts-Schwellenwerte:
// Blur/Belichtung. Werte werden in UserDefaults persistiert (siehe QualityDetectionState)
// und via Combine-Subscription in ImageViewModel automatisch auf die Listen angewendet.
struct SettingsView: View {
    @EnvironmentObject var viewModel: ImageViewModel
    @ObservedObject private var pluginStore = PluginStore.shared

    var body: some View {
        TabView {
            qualityTab
                .tabItem { Label("Qualität", systemImage: "wand.and.stars") }
            backupTab
                .tabItem { Label("Backup", systemImage: "externaldrive.badge.checkmark") }
            thumbnailsTab
                .tabItem { Label("Thumbnails", systemImage: "photo.on.rectangle") }
            toolbarTab
                .tabItem { Label("Toolbar", systemImage: "toolbar.horizontal") }
            sidebarTab
                .tabItem { Label("Seitenleiste", systemImage: "sidebar.left") }
            featuresTab
                .tabItem { Label("Funktionen", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 520, height: 500)
    }

    // MARK: - Backup

    private var backupTab: some View {
        let s = viewModel.backupSettings
        return Form {
            Section(header: Text("Zielordner").font(.headline)) {
                HStack {
                    Text(s.destinationDisplayPath)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Wählen…") { pickBackupDestination() }
                }
                Text("Backups werden nach `<Jahr>/<Monat>/` einsortiert (Aufnahmedatum aus EXIF, Fallback: Dateidatum).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("JPEG-Qualität").font(.headline)) {
                HStack {
                    Slider(value: Binding(
                        get: { s.jpegQuality },
                        set: { s.jpegQuality = $0 }
                    ), in: 0.5...1.0, step: 0.01)
                    Text(String(format: "%.0f %%", s.jpegQuality * 100))
                        .font(.body.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                Text("0.85 entspricht dem Export-Standard — sichtbar verlustfrei bei ~30–50 % Dateigröße.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Metadaten & Auflösung").font(.headline)) {
                Toggle(isOn: Binding(get: { s.copyMetadata }, set: { s.copyMetadata = $0 })) {
                    Text("EXIF/GPS/Kamera-Metadaten mitkopieren")
                }
                Toggle(isOn: Binding(get: { s.downscaleEnabled }, set: { s.downscaleEnabled = $0 })) {
                    Text("Auflösung reduzieren")
                }
                HStack {
                    Text("Lange Kante")
                        .frame(width: 110, alignment: .leading)
                        .foregroundColor(s.downscaleEnabled ? .primary : .secondary)
                    Stepper(value: Binding(
                        get: { s.longSidePixels },
                        set: { s.longSidePixels = max(320, $0) }
                    ), in: 320...12000, step: 128) {
                        Text("\(s.longSidePixels) px")
                            .font(.body.monospacedDigit())
                    }
                    .disabled(!s.downscaleEnabled)
                }
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Bei bestehender Datei").font(.headline)) {
                Picker("", selection: Binding(
                    get: { s.collisionMode },
                    set: { s.collisionMode = $0 }
                )) {
                    ForEach(BackupSettings.CollisionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(RadioGroupPickerStyle())
                .labelsHidden()
            }
        }
        .padding(20)
    }

    // MARK: - Thumbnails

    private var thumbnailsTab: some View {
        Form {
            Section(header: Text("Angezeigte Symbole").font(.headline)) {
                badgeToggle("Sternebewertung",       key: "badge.rating",      icon: "star.fill",             color: .yellow)
                badgeToggle("Farb-Label",             key: "badge.colorLabel",  icon: "circle.fill",           color: .blue)
                badgeToggle("Markierung / Ablehnung", key: "badge.flag",        icon: "flag.fill",             color: .green)
                badgeToggle("Unscharf",               key: "badge.blurry",      icon: "drop.triangle.fill",    color: .purple)
                badgeToggle("Unterbelichtet",         key: "badge.under",       icon: "moon.fill",             color: .blue)
                badgeToggle("Überbelichtet",          key: "badge.over",        icon: "sun.max.fill",          color: .yellow)
                badgeToggle("Geschlossene Augen",     key: "badge.eyes",        icon: "eye.slash.fill",        color: .pink)
                badgeToggle("Bestes im Stapel",       key: "badge.bestInStack", icon: "crown.fill",            color: .yellow)
                badgeToggle("Bearbeitungen",          key: "badge.adjustments", icon: "triangle.fill",         color: .purple)
                badgeToggle("HDR",                    key: "badge.hdr",         icon: "sparkles",              color: .orange)
            }

            HStack {
                Spacer()
                Button("Alle einblenden") {
                    for key in ["badge.rating","badge.colorLabel","badge.flag","badge.blurry",
                                "badge.under","badge.over","badge.eyes","badge.bestInStack",
                                "badge.adjustments","badge.hdr"] {
                        UserDefaults.standard.set(true, forKey: key)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
    }

    private func badgeToggle(_ title: String, key: String, icon: String, color: Color) -> some View {
        Toggle(isOn: Binding(
            get: { UserDefaults.standard.object(forKey: key) as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: key) }
        )) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 18)
                Text(title).font(.system(size: 12))
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Toolbar

    @AppStorage("actionBar.order") private var actionBarOrderRaw: String = ""
    @State private var unifiedEntries: [ToolbarEntry] = ToolbarEntry.loadUnified()

    private func unifiedVisibilityBinding(for entry: ToolbarEntry) -> Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.object(forKey: entry.visibilityKey) as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: entry.visibilityKey) }
        )
    }

    private func unifiedRow(for entry: ToolbarEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
            Toggle(isOn: unifiedVisibilityBinding(for: entry)) {
                HStack(spacing: 10) {
                    Image(systemName: entry.icon).frame(width: 18).foregroundColor(.secondary)
                    Text(entry.label).font(.system(size: 12))
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var toolbarTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Toolbar")
                .font(.headline)
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 4)
            Text("Reihenfolge per Drag ändern · Haken = sichtbar in der Toolbar")
                .font(.caption).foregroundColor(.secondary)
                .padding(.horizontal, 20).padding(.bottom, 10)

            List {
                ForEach(unifiedEntries) { entry in
                    unifiedRow(for: entry)
                }
                .onMove { from, to in
                    unifiedEntries.move(fromOffsets: from, toOffset: to)
                    ToolbarEntry.saveUnified(unifiedEntries)
                    actionBarOrderRaw = unifiedEntries
                        .compactMap { ToolbarEntry.actionBarItem(from: $0) }
                        .map(\.rawValue)
                        .joined(separator: ",")
                }
            }
            .listStyle(PlainListStyle())
            .environment(\.defaultMinListRowHeight, 38)

            HStack {
                Spacer()
                Button("Alle einblenden") {
                    ToolbarEntry.allItems.forEach {
                        UserDefaults.standard.set(true, forKey: $0.visibilityKey)
                    }
                }
                Button("Alle ausblenden") {
                    ToolbarEntry.allItems.forEach {
                        UserDefaults.standard.set(false, forKey: $0.visibilityKey)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .onAppear { unifiedEntries = ToolbarEntry.loadUnified() }
    }

    // MARK: - Sidebar

    private var sidebarTab: some View {
        sidebarTabBody
    }

    private var sidebarTabBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Seitenleisten-Bereiche")
                .font(.headline)
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)
            Text("Wähle, welche Bereiche in der linken Seitenleiste angezeigt werden.")
                .font(.caption).foregroundColor(.secondary)
                .padding(.horizontal, 20).padding(.bottom, 10)
            sidebarSectionList
            Spacer()
        }
    }

    private var sidebarSectionList: some View {
        List {
            ForEach(NavSidebarSection.allCases, id: \.self) { section in
                sidebarSectionRow(section)
            }
        }
        .listStyle(PlainListStyle())
        .environment(\.defaultMinListRowHeight, 36)
    }

    private func sidebarSectionRow(_ section: NavSidebarSection) -> some View {
        Toggle(isOn: Binding(
            get: { NavSidebarSection.isVisible(section) },
            set: { NavSidebarSection.setVisible(section, $0) }
        )) {
            HStack(spacing: 10) {
                Image(systemName: section.icon).frame(width: 18).foregroundColor(.secondary)
                Text(section.displayName).font(.system(size: 12))
            }
        }
        .padding(.vertical, 3)
    }

    private var featuresTab: some View {
        Form {
            Section(header: Text("Experimentelle Funktionen").font(.headline)) {
                expToggle(
                    title: "Ansicht wählen (Kachelansicht)",
                    description: "Zeigt den ⌘M-Button in der Toolbar und ermöglicht das Windows-8-ähnliche Kachelmenü zum schnellen Wechsel zwischen Modi.",
                    isOn: Binding(
                        get: { viewModel.modeSwitcherEnabled },
                        set: { viewModel.modeSwitcherEnabled = $0 }
                    )
                )

                Divider().padding(.vertical, 2)

                expToggle(
                    title: "Bildvergleich (ELO-Rating)",
                    description: "Duell-Modus in Seitenleiste und Inspector: zwei Bilder nebeneinander vergleichen, ELO-Score wird automatisch berechnet.",
                    isOn: Binding(
                        get: { pluginStore.isEnabled("com.iphoto.builtin.compare") },
                        set: {
                            pluginStore.setEnabled("com.iphoto.builtin.compare", $0)
                            if !$0 && viewModel.compare.active { viewModel.stopCompareMode() }
                        }
                    )
                )
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Tageslimit").font(.headline)) {
                Toggle(isOn: Binding(
                    get: { viewModel.compareDailyLimit > 0 },
                    set: { viewModel.compareDailyLimit = $0 ? 50 : 0 }
                )) {
                    Text("Tägliches Duell-Limit")
                }
                .disabled(!pluginStore.isEnabled("com.iphoto.builtin.compare"))

                if viewModel.compareDailyLimit > 0 {
                    HStack {
                        Text("Duelle pro Tag")
                            .frame(width: 130, alignment: .leading)
                        Stepper(value: Binding(
                            get: { viewModel.compareDailyLimit },
                            set: { viewModel.compareDailyLimit = max(5, $0) }
                        ), in: 5...500, step: 5) {
                            Text("\(viewModel.compareDailyLimit)")
                                .font(.body.monospacedDigit())
                        }
                    }
                    HStack {
                        Text("Heute")
                            .foregroundColor(.secondary)
                            .frame(width: 130, alignment: .leading)
                        ProgressView(value: Double(viewModel.compare.dailyCount),
                                     total: Double(viewModel.compareDailyLimit))
                        Text("\(viewModel.compare.dailyCount) / \(viewModel.compareDailyLimit)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Entwickler").font(.headline)) {
                expToggle(
                    title: "Für Geeks",
                    description: "Zeigt am unteren Rand der Seitenleiste einen ausklappbaren Live-Log mit Lade- und Performance-Daten (PERF, INFO, WARN).",
                    isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "settings.geekMode") },
                        set: { UserDefaults.standard.set($0, forKey: "settings.geekMode") }
                    )
                )

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Thumbnails generieren")
                        Text("Startet die Thumbnail-Generierung für alle Bilder manuell.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Jetzt laden") {
                        viewModel.loadThumbnails()
                    }
                }
                .padding(.vertical, 2)
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("ELO-Konvergenz").font(.headline)) {
                let factor = viewModel.eloConvergenceFactor
                HStack {
                    Text("Stabilität")
                        .frame(width: 130, alignment: .leading)
                    ProgressView(value: factor)
                    Text(String(format: "%.0f %%", factor * 100))
                        .font(.body.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 46, alignment: .trailing)
                }
                Text("100 % ≈ 20 Duelle pro Bild (K-Faktor stabilisiert). Erst ab ~80 % sind ELO-Rankings verlässlich.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }

    private func pickBackupDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Wählen"
        panel.title = "Backup-Zielordner wählen"
        panel.directoryURL = URL(fileURLWithPath: viewModel.backupSettings.destinationDisplayPath)
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.backupSettings.setDestination(url)
        }
    }

    private var qualityTab: some View {
        Form {
            Section(header: Text("Unschärfe-Erkennung").font(.headline)) {
                thresholdRow(
                    title: "Schwellenwert",
                    value: Binding(
                        get: { viewModel.quality.blurThreshold },
                        set: { viewModel.quality.blurThreshold = $0 }
                    ),
                    range: 20...400, step: 10,
                    format: { String(format: "%.0f", $0) },
                    hint: "Bilder mit Laplacian-Varianz unter diesem Wert gelten als unscharf."
                )
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Unterbelichtung").font(.headline)) {
                thresholdRow(
                    title: "Schatten-Clip",
                    value: Binding(
                        get: { viewModel.quality.shadowClipThreshold },
                        set: { viewModel.quality.shadowClipThreshold = $0 }
                    ),
                    range: 0.01...0.30, step: 0.01,
                    format: { String(format: "%.0f %%", $0 * 100) },
                    hint: "Anteil sehr dunkler Pixel, ab dem ein Bild als unterbelichtet gilt."
                )
            }

            Divider().padding(.vertical, 4)

            Section(header: Text("Überbelichtung").font(.headline)) {
                thresholdRow(
                    title: "Lichter-Clip",
                    value: Binding(
                        get: { viewModel.quality.highlightClipThreshold },
                        set: { viewModel.quality.highlightClipThreshold = $0 }
                    ),
                    range: 0.01...0.30, step: 0.01,
                    format: { String(format: "%.0f %%", $0 * 100) },
                    hint: "Anteil sehr heller Pixel, ab dem ein Bild als überbelichtet gilt."
                )
            }

            HStack {
                Spacer()
                Button("Auf Standard zurücksetzen") {
                    viewModel.quality.resetThresholdsToDefaults()
                }
            }
            .padding(.top, 10)
        }
        .padding(20)
    }

    @ViewBuilder
    private func expToggle(title: String, description: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func thresholdRow(title: String,
                              value: Binding<Double>,
                              range: ClosedRange<Double>, step: Double,
                              format: @escaping (Double) -> String,
                              hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).frame(width: 110, alignment: .leading)
                Slider(value: value, in: range, step: step)
                Text(format(value.wrappedValue))
                    .font(.body.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            Text(hint)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 110)
        }
    }
}

// MARK: - ToolbarEntry

private struct ToolbarEntry: Identifiable, Hashable {
    let id: String
    let icon: String
    let label: String
    let visibilityKey: String

    static let allNavItems: [ToolbarEntry] = [
        ToolbarEntry(id: "nav.sidebar",    icon: "sidebar.left",          label: "Seitenleiste",        visibilityKey: "navtoolbar.showSidebar"),
        ToolbarEntry(id: "nav.viewMode",   icon: "square.grid.2x2",       label: "Ansichtsmodus",       visibilityKey: "navtoolbar.showViewMode"),
        ToolbarEntry(id: "nav.navigation", icon: "chevron.left",          label: "Navigation (← →)",    visibilityKey: "navtoolbar.showNavigation"),
        ToolbarEntry(id: "nav.inspector",  icon: "sidebar.right",         label: "Inspector",           visibilityKey: "navtoolbar.showInspector"),
        ToolbarEntry(id: "nav.sort",       icon: "arrow.up.arrow.down",   label: "Sortierung (Grid)",   visibilityKey: "navtoolbar.showSort"),
        ToolbarEntry(id: "nav.slider",     icon: "slider.horizontal.3",   label: "Rastergröße-Slider",  visibilityKey: "navtoolbar.showSlider"),
        ToolbarEntry(id: "nav.share",      icon: "square.and.arrow.up",   label: "Teilen",              visibilityKey: "navtoolbar.showShare"),
        ToolbarEntry(id: "nav.tag",        icon: "tag",                   label: "Farblabel",           visibilityKey: "navtoolbar.showTag"),
        ToolbarEntry(id: "nav.more",       icon: "ellipsis.circle",       label: "Weitere Aktionen",    visibilityKey: "navtoolbar.showMore"),
        ToolbarEntry(id: "nav.search",     icon: "magnifyingglass",       label: "Suche",               visibilityKey: "navtoolbar.showSearch"),
    ]

    static var allActionItems: [ToolbarEntry] {
        ActionBarItem.allCases.map { item in
            ToolbarEntry(
                id: "action.\(item.rawValue)",
                icon: item.icon,
                label: item.helpText.components(separatedBy: " (").first ?? item.helpText,
                visibilityKey: "toolbar.item.\(item.rawValue)"
            )
        }
    }

    static var allItems: [ToolbarEntry] { allNavItems + allActionItems }

    static func loadUnified() -> [ToolbarEntry] {
        let raw = UserDefaults.standard.string(forKey: "toolbar.unified.order") ?? ""
        guard !raw.isEmpty else { return allItems }
        let byId = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        let saved = raw.split(separator: ",").compactMap { byId[String($0)] }
        let missing = allItems.filter { item in !saved.contains(where: { $0.id == item.id }) }
        return saved + missing
    }

    static func saveUnified(_ entries: [ToolbarEntry]) {
        UserDefaults.standard.set(entries.map(\.id).joined(separator: ","), forKey: "toolbar.unified.order")
        let actionItems = entries.compactMap { actionBarItem(from: $0) }
        ActionBarItem.saveOrder(actionItems)
        UserDefaults.standard.set(actionItems.map(\.rawValue).joined(separator: ","), forKey: "actionBar.order")
    }

    static func actionBarItem(from entry: ToolbarEntry) -> ActionBarItem? {
        guard entry.id.hasPrefix("action.") else { return nil }
        return ActionBarItem(rawValue: String(entry.id.dropFirst(7)))
    }
}
