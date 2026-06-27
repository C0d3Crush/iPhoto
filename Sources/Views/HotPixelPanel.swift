import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Phase

enum HotPixelPhase {
    case idle
    case analyzing(String, Double)
    case result(HotPixelResult)
}

// MARK: - Main Panel

struct HotPixelPanel: View {

    @EnvironmentObject var viewModel: ImageViewModel

    private var phase: HotPixelPhase { viewModel.hotPixelPhase }

    var body: some View {
        switch phase {
        case .idle:
            idleView
        case .analyzing(let status, let pct):
            analyzingView(status: status, pct: pct)
        case .result(let result):
            resultView(result)
        }
    }

    // MARK: Idle

    private var idleView: some View {
        VStack(spacing: 14) {
            Text("Lege Dunkelbilder (Dark Frames) in einen Ordner und wähle diesen aus. Deckel-zu, ISO wie beim Shooting, gleiche Belichtungszeit.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button("Dunkelbilder-Ordner wählen") {
                pickFolder()
            }
            .buttonStyle(BorderedButtonStyle())
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: Analyzing

    private func analyzingView(status: String, pct: Double) -> some View {
        VStack(spacing: 12) {
            ProgressView(value: pct)
                .padding(.horizontal, 16)
            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: Result

    private func resultView(_ result: HotPixelResult) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                // --- Grade Badge ---
                gradeBadge(result)

                // --- Stats ---
                statsGrid(result)

                Divider()

                // --- Hot Pixel Map ---
                chartSection(title: "Hot-Pixel-Karte") {
                    let img = HotPixelCharts.renderHotPixelMap(
                        hotPixels: result.hotPixels,
                        w: result.sensorWidth,
                        h: result.sensorHeight,
                        size: CGSize(width: 256, height: 156)
                    )
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }

                // --- Cluster Map ---
                chartSection(title: "Cluster-Karte (20×20)") {
                    let img = HotPixelCharts.renderClusterMap(
                        grid: result.clusterGrid,
                        size: CGSize(width: 256, height: 156)
                    )
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }

                // --- Distribution Histogram ---
                chartSection(title: "Verteilung") {
                    let hotVals = result.hotPixels.map { $0.value }
                    let img = HotPixelCharts.renderDistribution(
                        sample: result.sampleDistribution,
                        hotValues: hotVals,
                        threshold: result.threshold,
                        size: CGSize(width: 256, height: 130)
                    )
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }

                Divider()

                // --- Top-10 Table ---
                top10Table(result)

                // --- Reset ---
                Button("Neue Analyse") {
                    viewModel.hotPixelPhase = .idle
                }
                .buttonStyle(BorderedButtonStyle())
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
        }
    }

    // MARK: Sub-views

    private func gradeBadge(_ r: HotPixelResult) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(r.gradeColor))
                    .frame(width: 56, height: 56)
                Text(r.grade)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text(r.gradeLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color(r.gradeColor))
            Text("\(r.hotCount) Hot Pixel")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func statsGrid(_ r: HotPixelResult) -> some View {
        let sensorPct = r.sensorWidth > 0 && r.sensorHeight > 0
            ? Double(r.hotCount) / Double(r.sensorWidth * r.sensorHeight) * 100.0
            : 0.0
        let brightest = r.hotPixels.first?.value ?? 0

        return VStack(spacing: 4) {
            statRow("Sensor",     "\(r.sensorWidth)×\(r.sensorHeight)")
            statRow("Anteil",     String(format: "%.4f%%", sensorPct))
            statRow("Dunkel-Ø",  String(format: "%.1f ± %.1f", r.darkMean, r.darkStd))
            statRow("Schwelle",   String(format: "%.0f", r.threshold))
            statRow("Frames",     "\(r.frameCount)")
            statRow("Hellstes",   String(format: "%.0f", brightest))
        }
        .padding(.horizontal, 4)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }

    @ViewBuilder
    private func chartSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            content()
        }
    }

    private func top10Table(_ r: HotPixelResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Top 10 Hot Pixel")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 2) {
                HStack {
                    Text("#").frame(width: 22, alignment: .trailing)
                    Text("X").frame(width: 44, alignment: .trailing)
                    Text("Y").frame(width: 44, alignment: .trailing)
                    Spacer()
                    Text("Wert").frame(width: 60, alignment: .trailing)
                }
                .font(.caption2)
                .foregroundColor(.secondary)

                ForEach(Array(r.hotPixels.prefix(10).enumerated()), id: \.offset) { idx, hp in
                    HStack {
                        Text("\(idx + 1)").frame(width: 22, alignment: .trailing)
                        Text("\(hp.x)").frame(width: 44, alignment: .trailing)
                        Text("\(hp.y)").frame(width: 44, alignment: .trailing)
                        Spacer()
                        Text(String(format: "%.0f", hp.value)).frame(width: 60, alignment: .trailing)
                    }
                    .font(.caption2.monospacedDigit())
                }
            }
        }
    }

    // MARK: - Folder picker

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Dunkelbilder-Ordner wählen"
        panel.prompt = "Analysieren"

        guard panel.runModal() == .OK, let folder = panel.url else { return }

        let supportedExts: Set<String> = [
            "raf","cr2","cr3","nef","arw","dng","orf","rw2","nrw","pef","srw","erf","kdc","dcr",
            "raw","rwl","mrw","3fr","mef","iiq","x3f","srf","sr2","jpg","jpeg","tiff","tif","png","heic","heif"
        ]

        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let urls = contents.filter { supportedExts.contains($0.pathExtension.lowercased()) }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !urls.isEmpty else {
            viewModel.hotPixelPhase = .analyzing("Keine Bilddateien gefunden.", 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.viewModel.hotPixelPhase = .idle
            }
            return
        }

        viewModel.hotPixelPhase = .analyzing("Starte …", 0.0)

        DispatchQueue.global(qos: .userInitiated).async {
            // HotPixelAnalyzer.analyze already dispatches progress to main — no inner async needed.
            let result = HotPixelAnalyzer.analyze(urls: urls) { status, pct in
                self.viewModel.hotPixelPhase = .analyzing(status, pct)
            }
            DispatchQueue.main.async {
                if let r = result {
                    self.viewModel.hotPixelPhase = .result(r)
                } else {
                    self.viewModel.hotPixelPhase = .analyzing("Keine Bilder dekodierbar.", 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.viewModel.hotPixelPhase = .idle
                    }
                }
            }
        }
    }
}

// MARK: - Chart Rendering

enum HotPixelCharts {

    // MARK: Hot Pixel Map

    static func renderHotPixelMap(
        hotPixels: [(x: Int, y: Int, value: Float)],
        w: Int, h: Int,
        size: CGSize
    ) -> NSImage {
        NSImage(size: size, flipped: false) { bounds in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            // Background
            ctx.setFillColor(NSColor(white: 0.067, alpha: 1).cgColor)
            ctx.fill(bounds)

            guard w > 0, h > 0 else { return true }

            let scaleX = bounds.width  / CGFloat(w)
            let scaleY = bounds.height / CGFloat(h)
            let dotR: CGFloat = max(1.0, min(scaleX, scaleY) * 1.2)

            ctx.setFillColor(NSColor(red: 1.0, green: 0.341, blue: 0.133, alpha: 0.85).cgColor)

            for hp in hotPixels {
                let px = CGFloat(hp.x) * scaleX
                let py = bounds.height - CGFloat(hp.y) * scaleY  // flip Y
                let rect = CGRect(x: px - dotR/2, y: py - dotR/2, width: dotR, height: dotR)
                ctx.fillEllipse(in: rect)
            }
            return true
        }
    }

    // MARK: Cluster Map

    static func renderClusterMap(grid: [[Int]], size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { bounds in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            ctx.setFillColor(NSColor(white: 0.067, alpha: 1).cgColor)
            ctx.fill(bounds)

            let rows = grid.count
            guard rows > 0 else { return true }
            let cols = grid[0].count
            guard cols > 0 else { return true }

            // Reserve right margin for colorbar
            let colorbarW: CGFloat = 20
            let mapW = bounds.width - colorbarW - 6
            let mapH = bounds.height

            let cellW = mapW / CGFloat(cols)
            let cellH = mapH / CGFloat(rows)

            // Find max for normalization
            var maxVal = 1
            for row in grid { for v in row { if v > maxVal { maxVal = v } } }

            for r in 0..<rows {
                for c in 0..<cols {
                    let val = grid[r][c]
                    let t = CGFloat(val) / CGFloat(maxVal)
                    let color = clusterColor(t: t)
                    ctx.setFillColor(color)
                    let cellRect = CGRect(
                        x: CGFloat(c) * cellW,
                        y: bounds.height - CGFloat(r + 1) * cellH,
                        width: cellW,
                        height: cellH
                    )
                    ctx.fill(cellRect)
                }
            }

            // Colorbar
            let cbX = mapW + 6
            let steps = 100
            for i in 0..<steps {
                let t = CGFloat(i) / CGFloat(steps - 1)
                let color = clusterColor(t: t)
                ctx.setFillColor(color)
                let segH = bounds.height / CGFloat(steps)
                let segRect = CGRect(x: cbX, y: CGFloat(i) * segH, width: colorbarW - 2, height: segH + 1)
                ctx.fill(segRect)
            }

            // Colorbar labels
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 7),
                .foregroundColor: NSColor.white
            ]
            let maxStr = "\(maxVal)" as NSString
            maxStr.draw(at: CGPoint(x: cbX, y: bounds.height - 10), withAttributes: attrs)
            ("0" as NSString).draw(at: CGPoint(x: cbX, y: 1), withAttributes: attrs)

            return true
        }
    }

    private static func clusterColor(t: CGFloat) -> CGColor {
        // black → dark-yellow → red
        if t < 0.5 {
            let u = t * 2
            return NSColor(red: u * 0.6, green: u * 0.5, blue: 0, alpha: 1).cgColor
        } else {
            let u = (t - 0.5) * 2
            return NSColor(red: 0.6 + u * 0.4, green: 0.5 - u * 0.5, blue: 0, alpha: 1).cgColor
        }
    }

    // MARK: Distribution Histogram

    static func renderDistribution(
        sample: [Float],
        hotValues: [Float],
        threshold: Float,
        size: CGSize
    ) -> NSImage {
        NSImage(size: size, flipped: false) { bounds in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            ctx.setFillColor(NSColor(white: 0.067, alpha: 1).cgColor)
            ctx.fill(bounds)

            guard !sample.isEmpty else { return true }

            let bins = 80
            let maxVal: Float = 65535
            let binWidth = maxVal / Float(bins)

            var allBins  = [Int](repeating: 0, count: bins)
            var hotBins  = [Int](repeating: 0, count: bins)

            for v in sample {
                let b = min(Int(v / binWidth), bins - 1)
                allBins[b] += 1
            }
            for v in hotValues {
                let b = min(Int(v / binWidth), bins - 1)
                hotBins[b] += 1
            }

            let maxCount = max(1, allBins.max() ?? 1)
            let barW = bounds.width / CGFloat(bins)

            for i in 0..<bins {
                // All pixels bar
                let allH = CGFloat(allBins[i]) / CGFloat(maxCount) * bounds.height
                let allRect = CGRect(x: CGFloat(i) * barW, y: 0, width: barW - 0.5, height: allH)
                ctx.setFillColor(NSColor(white: 0.27, alpha: 1).cgColor)
                ctx.fill(allRect)

                // Hot pixels bar
                if hotBins[i] > 0 {
                    let hotH = CGFloat(hotBins[i]) / CGFloat(maxCount) * bounds.height
                    let hotRect = CGRect(x: CGFloat(i) * barW, y: 0, width: barW - 0.5, height: hotH)
                    ctx.setFillColor(NSColor(red: 1.0, green: 0.341, blue: 0.133, alpha: 1).cgColor)
                    ctx.fill(hotRect)
                }
            }

            // Threshold line
            let threshX = CGFloat(threshold / maxVal) * bounds.width
            ctx.setStrokeColor(NSColor(red: 1.0, green: 0.596, blue: 0.0, alpha: 1).cgColor)
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: threshX, y: 0))
            ctx.addLine(to: CGPoint(x: threshX, y: bounds.height))
            ctx.strokePath()

            return true
        }
    }
}
