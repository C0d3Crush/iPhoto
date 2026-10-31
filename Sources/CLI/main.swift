import Foundation
import CoreGraphics
import ImageIO
import CoreImage

// MARK: - Usage

private func printUsage() {
    print("""
    Verwendung:
      iphoto-cli export <eingabe> --format jpeg|png|tiff|heif [--output <pfad>] [--quality 0.9]
      iphoto-cli export <datei1> <datei2> ... --format jpeg --output-dir <ordner>
      iphoto-cli hdr <ordner> --output-dir <ziel>
      iphoto-cli info <eingabe> [--json]
      iphoto-cli hotpixel <ordner>
      iphoto-cli rating <datei> [--set 0-5] [--flag pick|reject|none] [--color red|yellow|green|blue|none] [--json]
      iphoto-cli adjust <datei> --output <ziel> [--format jpeg|png|tiff|heif] [--quality 0.9]
                        [--exposure N] [--brightness N] [--contrast N] [--saturation N]
                        [--warmth N] [--tint N] [--vibrance N] [--hue N]
                        [--clarity N] [--sharpen N] [--preset <name>]
      iphoto-cli preset list [--json]
      iphoto-cli preset apply <datei> --name <name> --output <ziel> [--format jpeg] [--quality 0.9]
      iphoto-cli analyse <datei|ordner> [--json] [--blur-threshold N] [--shadow N] [--highlight N]
      iphoto-cli inpaint <datei> --output <ziel> [--python /usr/bin/python3] [--cmt ~/cmt] [--checkpoint ~/cmt/checkpoints]
      iphoto-cli plugins list [--json]
      iphoto-cli plugins dir
      iphoto-cli viewmode get
      iphoto-cli viewmode set <grid|list|columns|gallery>

    Formate:  jpeg (Standard), png, tiff, heif
    Quality:  0.0–1.0, nur für jpeg und heif (Standard: 0.9)
    hdr:      Erzeugt 6 Preset-Varianten aus allen RAWs im Ordner (Vergleich)
    info:     Gibt alle EXIF/IPTC/GPS-Metadaten aus; --json für maschinenlesbare Ausgabe
    rating:   Liest oder schreibt Bewertung, Flag und Farblabel aus dem Katalog
    adjust:   Wendet Bildanpassungen an und exportiert das Ergebnis
    preset:   Zeigt Built-in-Presets oder wendet einen an
    analyse:  Analysiert Schärfe und Belichtung (Blur + Exposure)
    inpaint:  KI-basiertes Inpainting via CMT (benötigt Python + CMT-Installation)
    plugins:  Listet installierte Plugins/Panels auf oder zeigt den Plugin-Ordner
    """)
}

// MARK: - Argument Parsing

private struct CLIArgs {
    var inputs: [URL] = []
    var format: ExportFormat = .jpeg
    var outputURL: URL? = nil
    var outputDir: URL? = nil
    var quality: Double = 0.9
    var command: String = "export"
    var jsonOutput: Bool = false

    // rating flags
    var ratingSet: Int? = nil
    var ratingFlag: String? = nil
    var ratingColor: String? = nil

    // adjust flags
    var exposure: Double? = nil
    var brightness: Double? = nil
    var contrast: Double? = nil
    var saturation: Double? = nil
    var warmth: Double? = nil
    var tint: Double? = nil
    var vibrance: Double? = nil
    var hue: Double? = nil
    var clarity: Double? = nil
    var sharpen: Double? = nil
    var presetName: String? = nil

    // analyse flags
    var blurThreshold: Double = 80.0
    var shadowThreshold: Double = 0.08
    var highlightThreshold: Double = 0.08

    // inpaint flags
    var pythonPath: String = "/usr/bin/python3"
    var cmtPath: String = "~/cmt"
    var checkpointPath: String = "~/cmt/checkpoints"
}

private func parseArgs(_ args: [String]) -> CLIArgs? {
    var result = CLIArgs()
    var i = 1
    guard i < args.count else { printUsage(); return nil }
    result.command = args[i]; i += 1

    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--format":
            i += 1
            guard i < args.count else { fputs("Fehler: --format braucht einen Wert\n", stderr); return nil }
            guard let fmt = ExportFormat(rawValue: args[i].uppercased()) else {
                fputs("Fehler: Unbekanntes Format '\(args[i])'. Erlaubt: jpeg, png, tiff, heif\n", stderr)
                return nil
            }
            result.format = fmt
        case "--output":
            i += 1
            guard i < args.count else { fputs("Fehler: --output braucht einen Pfad\n", stderr); return nil }
            result.outputURL = URL(fileURLWithPath: args[i])
        case "--output-dir":
            i += 1
            guard i < args.count else { fputs("Fehler: --output-dir braucht einen Pfad\n", stderr); return nil }
            result.outputDir = URL(fileURLWithPath: args[i])
        case "--quality":
            i += 1
            guard i < args.count, let q = Double(args[i]) else {
                fputs("Fehler: --quality braucht eine Zahl (0.0–1.0)\n", stderr); return nil
            }
            result.quality = max(0, min(1, q))
        case "--json":
            result.jsonOutput = true
        case "--set":
            i += 1
            guard i < args.count, let r = Int(args[i]), r >= 0, r <= 5 else {
                fputs("Fehler: --set braucht eine Zahl 0–5\n", stderr); return nil
            }
            result.ratingSet = r
        case "--flag":
            i += 1
            guard i < args.count else { fputs("Fehler: --flag braucht einen Wert\n", stderr); return nil }
            let f = args[i].lowercased()
            guard ["pick", "reject", "none"].contains(f) else {
                fputs("Fehler: --flag erlaubt: pick|reject|none\n", stderr); return nil
            }
            result.ratingFlag = f
        case "--color":
            i += 1
            guard i < args.count else { fputs("Fehler: --color braucht einen Wert\n", stderr); return nil }
            let c = args[i].lowercased()
            guard ["red", "yellow", "green", "blue", "none"].contains(c) else {
                fputs("Fehler: --color erlaubt: red|yellow|green|blue|none\n", stderr); return nil
            }
            result.ratingColor = c
        case "--exposure":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --exposure braucht eine Zahl\n", stderr); return nil }
            result.exposure = v
        case "--brightness":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --brightness braucht eine Zahl\n", stderr); return nil }
            result.brightness = v
        case "--contrast":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --contrast braucht eine Zahl\n", stderr); return nil }
            result.contrast = v
        case "--saturation":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --saturation braucht eine Zahl\n", stderr); return nil }
            result.saturation = v
        case "--warmth":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --warmth braucht eine Zahl\n", stderr); return nil }
            result.warmth = v
        case "--tint":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --tint braucht eine Zahl\n", stderr); return nil }
            result.tint = v
        case "--vibrance":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --vibrance braucht eine Zahl\n", stderr); return nil }
            result.vibrance = v
        case "--hue":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --hue braucht eine Zahl\n", stderr); return nil }
            result.hue = v
        case "--clarity":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --clarity braucht eine Zahl\n", stderr); return nil }
            result.clarity = v
        case "--sharpen":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --sharpen braucht eine Zahl\n", stderr); return nil }
            result.sharpen = v
        case "--preset", "--name":
            i += 1
            guard i < args.count else { fputs("Fehler: \(arg) braucht einen Namen\n", stderr); return nil }
            result.presetName = args[i]
        case "--blur-threshold":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --blur-threshold braucht eine Zahl\n", stderr); return nil }
            result.blurThreshold = v
        case "--shadow":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --shadow braucht eine Zahl\n", stderr); return nil }
            result.shadowThreshold = v
        case "--highlight":
            i += 1
            guard i < args.count, let v = Double(args[i]) else { fputs("Fehler: --highlight braucht eine Zahl\n", stderr); return nil }
            result.highlightThreshold = v
        case "--python":
            i += 1
            guard i < args.count else { fputs("Fehler: --python braucht einen Pfad\n", stderr); return nil }
            result.pythonPath = args[i]
        case "--cmt":
            i += 1
            guard i < args.count else { fputs("Fehler: --cmt braucht einen Pfad\n", stderr); return nil }
            result.cmtPath = args[i]
        case "--checkpoint":
            i += 1
            guard i < args.count else { fputs("Fehler: --checkpoint braucht einen Pfad\n", stderr); return nil }
            result.checkpointPath = args[i]
        default:
            result.inputs.append(URL(fileURLWithPath: arg))
        }
        i += 1
    }
    return result
}

// MARK: - Helper: Env DB Path

private func envDBPath() -> String? {
    ProcessInfo.processInfo.environment["IPHOTO_CATALOG_DB"]
}

// MARK: - Commands

private func runExport(_ args: CLIArgs) -> Int32 {
    guard !args.inputs.isEmpty else {
        fputs("Fehler: Keine Eingabedatei angegeben\n", stderr)
        return 1
    }

    let isBatch = args.inputs.count > 1 || args.outputDir != nil

    if isBatch {
        guard let dir = args.outputDir else {
            fputs("Fehler: Bei mehreren Dateien --output-dir <ordner> angeben\n", stderr)
            return 1
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var failed = 0
        for input in args.inputs {
            let stem = input.deletingPathExtension().lastPathComponent
            let outURL = dir.appendingPathComponent(stem).appendingPathExtension(args.format.fileExtension)
            if !exportOne(input: input, output: outURL, format: args.format, quality: args.quality) {
                failed += 1
            }
        }
        return failed == 0 ? 0 : 1
    } else {
        let input = args.inputs[0]
        let outURL: URL
        if let explicit = args.outputURL {
            outURL = explicit
        } else {
            let stem = input.deletingPathExtension().lastPathComponent
            outURL = input.deletingLastPathComponent()
                .appendingPathComponent(stem)
                .appendingPathExtension(args.format.fileExtension)
        }
        return exportOne(input: input, output: outURL, format: args.format, quality: args.quality) ? 0 : 1
    }
}

@discardableResult
private func exportOne(input: URL, output: URL, format: ExportFormat, quality: Double) -> Bool {
    do {
        let image = try RAWImageDecoder.decode(url: input)
        try ImageExporter.exportSingle(image: image, to: output, format: format, quality: quality)
        print("OK  \(output.path)")
        return true
    } catch {
        fputs("FAIL \(input.lastPathComponent): \(error.localizedDescription)\n", stderr)
        return false
    }
}

private func runInfo(_ args: CLIArgs) -> Int32 {
    guard let input = args.inputs.first else {
        fputs("Fehler: Keine Eingabedatei angegeben\n", stderr)
        return 1
    }
    guard FileManager.default.fileExists(atPath: input.path) else {
        fputs("Fehler: Datei nicht gefunden: \(input.path)\n", stderr)
        return 1
    }

    let entries = MetadataService().readPhotoMetadata(from: input)

    if args.jsonOutput {
        var dict: [String: String] = [:]
        dict["file"] = input.lastPathComponent
        for e in entries where !e.value.isEmpty { dict[e.key] = e.value }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
        return 0
    }

    // Gruppenüberschriften
    let groups: [(String, MetadataCategory)] = [
        ("Allgemein", .general), ("Aufnahme", .dateTime),
        ("Kamera",    .camera),  ("GPS",      .location),
    ]
    print("━━━  \(input.lastPathComponent)  ━━━")
    for (title, cat) in groups {
        let inCat = entries.filter { $0.category == cat && !$0.value.isEmpty }
        guard !inCat.isEmpty else { continue }
        print("\n[\(title)]")
        let maxLen = inCat.map { $0.displayName.count }.max() ?? 0
        for e in inCat {
            let pad = String(repeating: " ", count: maxLen - e.displayName.count)
            print("  \(e.displayName)\(pad)  \(e.value)")
        }
    }
    print("")
    return 0
}

private func runHotPixel(_ args: CLIArgs) -> Int32 {
    guard let dir = args.inputs.first else {
        fputs("Fehler: Ordner angeben — iphoto-cli hotpixel <ordner>\n", stderr)
        return 1
    }
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
        fputs("Fehler: '\(dir.path)' ist kein Ordner\n", stderr)
        return 1
    }

    let imageExts: Set<String> = ["raf","cr2","cr3","nef","arw","dng","orf","rw2","nrw","pef",
                                   "srw","erf","kdc","dcr","raw","rwl","mrw","3fr","mef","iiq",
                                   "x3f","srf","sr2","jpg","jpeg","tiff","tif","png","heic","heif"]
    let urls = (try? FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil
    ))?.filter { imageExts.contains($0.pathExtension.lowercased()) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []

    guard !urls.isEmpty else {
        fputs("Fehler: Keine Bilddateien in '\(dir.path)'\n", stderr)
        return 1
    }

    print("Hot-Pixel-Analyse: \(urls.count) Datei(en) in \(dir.lastPathComponent)")

    guard let result = HotPixelAnalyzer.analyze(urls: urls, progress: { status, pct in
        let bar = String(repeating: "█", count: Int(pct * 30))
            + String(repeating: "░", count: 30 - Int(pct * 30))
        print("\r[\(bar)] \(Int(pct * 100))%  \(status)          ", terminator: "")
        fflush(stdout)
    }) else {
        fputs("\nFehler: Analyse fehlgeschlagen (keine Frames dekodierbar)\n", stderr)
        return 1
    }

    print("\n")
    print("╔══════════════════════════════════════════════════╗")
    print("║           HOT-PIXEL-ANALYSE ERGEBNIS             ║")
    print("╚══════════════════════════════════════════════════╝")
    print("  Sensor       : \(result.sensorWidth) × \(result.sensorHeight) px")
    print("  Frames        : \(result.frameCount)")
    print("  Dunkel-Mittel : \(String(format: "%.1f", result.darkMean))  σ = \(String(format: "%.1f", result.darkStd))")
    print("  Schwelle      : \(String(format: "%.1f", result.threshold))")
    print("")
    print("  Hot Pixel     : \(result.hotCount)")
    print("  Bewertung     : \(result.grade) — \(result.gradeLabel)")
    print("")

    if !result.hotPixels.isEmpty {
        print("  Top-10 hellste Hot Pixel:")
        print("  ─────────────────────────────────────────")
        print("   #   X      Y      Wert")
        let top = Array(result.hotPixels.prefix(10))
        for i in 0..<top.count {
            print(String(format: "  %2d  %-6d %-6d %.1f", i + 1, top[i].x, top[i].y, top[i].value))
        }
        print("")
    }

    // ASCII cluster grid (20×20 → condensed to 10×5 for terminal)
    print("  Cluster-Grid (20×20, Wert = Anzahl Hot Pixel pro Zelle):")
    for row in result.clusterGrid {
        let line = row.map { v -> String in
            switch v {
            case 0:       return "·"
            case 1...3:   return "+"
            case 4...10:  return "▪"
            default:      return "█"
            }
        }.joined()
        print("  \(line)")
    }
    print("")
    return 0
}

// MARK: - Rating Command

private func runRating(_ args: CLIArgs) -> Int32 {
    guard let input = args.inputs.first else {
        fputs("Fehler: Datei angeben — iphoto-cli rating <datei>\n", stderr)
        return 1
    }
    guard FileManager.default.fileExists(atPath: input.path) else {
        fputs("Fehler: Datei nicht gefunden: \(input.path)\n", stderr)
        return 1
    }

    let catalog = CatalogStore(dbPath: envDBPath())
    let path = input.path

    // If any write flag is present, save and then read back
    if args.ratingSet != nil || args.ratingFlag != nil || args.ratingColor != nil {
        // Read current values as base
        let current = catalog.rating(forPath: path)
        let newRating = args.ratingSet ?? (current?.rating ?? 0)
        let newFlag   = args.ratingFlag ?? (current?.flag ?? "none")
        let newColor  = args.ratingColor ?? (current?.colorLabel ?? "none")
        catalog.saveRating(path: path, rating: newRating, flag: newFlag, colorLabel: newColor)
        print("Gespeichert: rating=\(newRating) flag=\(newFlag) color=\(newColor)")
    }

    // Read back current state
    let entry = catalog.rating(forPath: path)
    let rating    = entry?.rating     ?? 0
    let flag      = entry?.flag       ?? "none"
    let color     = entry?.colorLabel ?? "none"

    if args.jsonOutput {
        let dict: [String: Any] = [
            "path":   path,
            "rating": rating,
            "flag":   flag,
            "color":  color
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    } else {
        print("Datei  : \(input.lastPathComponent)")
        print("Rating : \(rating)")
        print("Flag   : \(flag)")
        print("Farbe  : \(color)")
    }
    return 0
}

// MARK: - Adjust Command
// Note: AdjustmentRenderer.swift depends on CurvesView (SwiftUI) so we implement
// a self-contained CI pipeline here for CLI use.

private let cliCIContext: CIContext = {
    var opts: [CIContextOption: Any] = [.useSoftwareRenderer: false]
    if let linearSRGB = CGColorSpace(name: CGColorSpace.linearSRGB) {
        opts[.workingColorSpace] = linearSRGB
    }
    opts[.workingFormat] = CIFormat.RGBAh
    return CIContext(options: opts)
}()

/// Apply a subset of AdjustmentState parameters to a CIImage using CoreImage filters.
/// Implements the same transforms as AdjustmentRenderer.pipeline() but without
/// the CurvesView/RGB-LUT stages (which require the SwiftUI CurvesView).
private func applyAdjustments(_ input: CIImage, state: AdjustmentState) -> CIImage {
    var ci = input

    // Exposure
    if state.exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(state.exposure, forKey: kCIInputEVKey)
        if let r = f.outputImage { ci = r }
    }
    // Brightness / Contrast / Saturation
    if state.brightness != 0 || state.contrast != 1 || state.saturation != 1,
       let f = CIFilter(name: "CIColorControls") {
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(state.brightness, forKey: kCIInputBrightnessKey)
        f.setValue(state.contrast,   forKey: kCIInputContrastKey)
        f.setValue(state.saturation, forKey: kCIInputSaturationKey)
        if let r = f.outputImage { ci = r }
    }
    // Warmth / Tint (white balance)
    if state.warmth != 0 || state.tint != 0, let f = CIFilter(name: "CITemperatureAndTint") {
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
        f.setValue(CIVector(x: CGFloat(6500 - state.warmth * 2500),
                            y: CGFloat(-state.tint * 150)),
                   forKey: "inputTargetNeutral")
        if let r = f.outputImage { ci = r }
    }
    // Vibrance — approximate via saturation boost on less-saturated pixels
    if state.vibrance != 0, let f = CIFilter(name: "CIVibrance") {
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(state.vibrance, forKey: kCIInputAmountKey)
        if let r = f.outputImage { ci = r }
    }
    // Hue
    if state.hue != 0, let f = CIFilter(name: "CIHueAdjust") {
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(Float(state.hue * .pi / 180.0), forKey: kCIInputAngleKey)
        if let r = f.outputImage { ci = r }
    }
    // Clarity (midtone contrast via unsharp mask with large radius)
    if state.clarity != 0, let f = CIFilter(name: "CIUnsharpMask") {
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(20.0, forKey: kCIInputRadiusKey)
        f.setValue(max(0, state.clarity) * 2.0, forKey: kCIInputIntensityKey)
        if let r = f.outputImage { ci = r }
    }
    // Sharpening (sharpenAmount is 0–150 in AdjustmentState)
    if state.sharpenAmount > 0, let f = CIFilter(name: "CIUnsharpMask") {
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(state.sharpenRadius, forKey: kCIInputRadiusKey)
        f.setValue(state.sharpenAmount / 100.0, forKey: kCIInputIntensityKey)
        if let r = f.outputImage { ci = r }
    }
    return ci
}

/// Build AdjustmentState from CLI args, optionally starting from a named preset.
private func buildAdjustmentState(_ args: CLIArgs) -> AdjustmentState? {
    var state: AdjustmentState

    if let name = args.presetName {
        // Try built-in presets first, then user presets from catalog
        let catalog = CatalogStore(dbPath: envDBPath())
        let all = Preset.builtIn + catalog.allUserPresets()
        guard let found = all.first(where: { $0.name.lowercased() == name.lowercased() }) else {
            fputs("Fehler: Preset '\(name)' nicht gefunden.\n", stderr)
            fputs("Verfügbare Presets: \(all.map { $0.name }.joined(separator: ", "))\n", stderr)
            return nil
        }
        state = found.adjustments
    } else {
        state = AdjustmentState()
    }

    // Apply CLI overrides on top of preset
    if let v = args.exposure    { state.exposure    = v }
    if let v = args.brightness  { state.brightness  = v }
    if let v = args.contrast    { state.contrast    = v }
    if let v = args.saturation  { state.saturation  = v }
    if let v = args.warmth      { state.warmth      = v }
    if let v = args.tint        { state.tint        = v }
    if let v = args.vibrance    { state.vibrance    = v }
    if let v = args.hue         { state.hue         = v }
    if let v = args.clarity     { state.clarity     = v }
    if let v = args.sharpen     { state.sharpenAmount = v }

    return state
}

private func runAdjust(_ args: CLIArgs) -> Int32 {
    guard let input = args.inputs.first else {
        fputs("Fehler: Eingabedatei angeben — iphoto-cli adjust <datei> --output <ziel>\n", stderr)
        return 1
    }
    guard let output = args.outputURL else {
        fputs("Fehler: --output <ziel> ist erforderlich\n", stderr)
        return 1
    }
    guard FileManager.default.fileExists(atPath: input.path) else {
        fputs("Fehler: Datei nicht gefunden: \(input.path)\n", stderr)
        return 1
    }

    guard let state = buildAdjustmentState(args) else { return 1 }

    do {
        let cg = try RAWImageDecoder.decode(url: input)
        let ci = CIImage(cgImage: cg)
        let adjusted = applyAdjustments(ci, state: state)
        guard let outCG = cliCIContext.createCGImage(adjusted, from: adjusted.extent) else {
            fputs("Fehler: Bild konnte nicht gerendert werden\n", stderr)
            return 1
        }
        try ImageExporter.exportSingle(image: outCG, to: output, format: args.format, quality: args.quality)
        print("OK  \(output.path)")
        return 0
    } catch {
        fputs("FAIL \(input.lastPathComponent): \(error.localizedDescription)\n", stderr)
        return 1
    }
}

// MARK: - Preset Command

private func runPreset(_ subArgs: [String]) -> Int32 {
    guard !subArgs.isEmpty else {
        fputs("Fehler: 'preset list' oder 'preset apply' angeben\n", stderr)
        return 1
    }
    let sub = subArgs[0]

    switch sub {
    case "list":
        let jsonOutput = subArgs.contains("--json")
        let catalog = CatalogStore(dbPath: envDBPath())
        let all = Preset.builtIn + catalog.allUserPresets()

        if jsonOutput {
            let dicts: [[String: Any]] = all.map { p in
                var d: [String: Any] = ["id": p.id.uuidString, "name": p.name]
                if let author = p.author { d["author"] = author }
                d["builtin"] = Preset.builtIn.contains(where: { $0.id == p.id })
                return d
            }
            if let data = try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            print("Verfügbare Presets (\(all.count)):")
            let builtin = Preset.builtIn
            for p in all {
                let tag = builtin.contains(where: { $0.id == p.id }) ? "[Built-in]" : "[Nutzer]  "
                let author = p.author.map { " (\($0))" } ?? ""
                print("  \(tag)  \(p.name)\(author)")
            }
        }
        return 0

    case "apply":
        // Build a fake CLIArgs from remaining args and delegate to runAdjust
        var remaining = Array(subArgs.dropFirst())
        // Extract non-flag positional as input
        var inputURL: URL? = nil
        var outputURL: URL? = nil
        var presetName: String? = nil
        var format: ExportFormat = .jpeg
        var quality: Double = 0.9
        var j = 0
        while j < remaining.count {
            let tok = remaining[j]
            switch tok {
            case "--name":
                j += 1
                if j < remaining.count { presetName = remaining[j] }
            case "--output":
                j += 1
                if j < remaining.count { outputURL = URL(fileURLWithPath: remaining[j]) }
            case "--format":
                j += 1
                if j < remaining.count, let fmt = ExportFormat(rawValue: remaining[j].uppercased()) {
                    format = fmt
                }
            case "--quality":
                j += 1
                if j < remaining.count, let q = Double(remaining[j]) { quality = q }
            default:
                if !tok.hasPrefix("--") { inputURL = URL(fileURLWithPath: tok) }
            }
            j += 1
        }

        guard let input = inputURL else {
            fputs("Fehler: Eingabedatei angeben — iphoto-cli preset apply <datei> --name <name> --output <ziel>\n", stderr)
            return 1
        }
        guard let output = outputURL else {
            fputs("Fehler: --output <ziel> ist erforderlich\n", stderr)
            return 1
        }
        guard let name = presetName else {
            fputs("Fehler: --name <preset-name> ist erforderlich\n", stderr)
            return 1
        }
        guard FileManager.default.fileExists(atPath: input.path) else {
            fputs("Fehler: Datei nicht gefunden: \(input.path)\n", stderr)
            return 1
        }

        let catalog = CatalogStore(dbPath: envDBPath())
        let all = Preset.builtIn + catalog.allUserPresets()
        guard let preset = all.first(where: { $0.name.lowercased() == name.lowercased() }) else {
            fputs("Fehler: Preset '\(name)' nicht gefunden.\n", stderr)
            fputs("Verfügbare Presets: \(all.map { $0.name }.joined(separator: ", "))\n", stderr)
            return 1
        }

        do {
            let cg = try RAWImageDecoder.decode(url: input)
            let ci = CIImage(cgImage: cg)
            let adjusted = applyAdjustments(ci, state: preset.adjustments)
            guard let outCG = cliCIContext.createCGImage(adjusted, from: adjusted.extent) else {
                fputs("Fehler: Bild konnte nicht gerendert werden\n", stderr)
                return 1
            }
            try ImageExporter.exportSingle(image: outCG, to: output, format: format, quality: quality)
            print("OK  \(output.path)")
            return 0
        } catch {
            fputs("FAIL \(input.lastPathComponent): \(error.localizedDescription)\n", stderr)
            return 1
        }

    default:
        fputs("Fehler: Unbekannter preset-Unterbefehl '\(sub)'. Erlaubt: list, apply\n", stderr)
        return 1
    }
}

// MARK: - Analyse Command

private let imageExtensions: Set<String> = [
    "raf","cr2","cr3","nef","arw","dng","orf","rw2","nrw","pef",
    "srw","erf","kdc","dcr","raw","rwl","mrw","3fr","mef","iiq",
    "x3f","srf","sr2","jpg","jpeg","tiff","tif","png","heic","heif"
]

private func collectImageURLs(at url: URL) -> [URL] {
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return [] }
    if isDir.boolValue {
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            if imageExtensions.contains(fileURL.pathExtension.lowercased()) {
                results.append(fileURL)
            }
        }
        return results.sorted { $0.lastPathComponent < $1.lastPathComponent }
    } else {
        return imageExtensions.contains(url.pathExtension.lowercased()) ? [url] : []
    }
}

private struct AnalyseResult {
    let path: String
    let filename: String
    let blurScore: Double
    let underRatio: Double
    let overRatio: Double
    let isBlurry: Bool
    let isUnder: Bool
    let isOver: Bool
}

private func runAnalyse(_ args: CLIArgs) -> Int32 {
    guard let input = args.inputs.first else {
        fputs("Fehler: Datei oder Ordner angeben — iphoto-cli analyse <datei|ordner>\n", stderr)
        return 1
    }

    let urls = collectImageURLs(at: input)
    guard !urls.isEmpty else {
        fputs("Fehler: Keine Bilddateien gefunden in '\(input.path)'\n", stderr)
        return 1
    }

    let maxDim = 1600
    var results: [AnalyseResult] = []

    for url in urls {
        // Decode at reduced size for speed
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { continue }
        let hint: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxDim,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, hint as CFDictionary) else { continue }

        let blur  = BlurDetector.score(from: cg)
        let exp   = ExposureDetector.analyze(from: cg)

        let isBlurry = blur < args.blurThreshold
        let isUnder  = exp.underRatio > args.shadowThreshold
        let isOver   = exp.overRatio  > args.highlightThreshold

        results.append(AnalyseResult(
            path:      url.path,
            filename:  url.lastPathComponent,
            blurScore: blur,
            underRatio: exp.underRatio,
            overRatio:  exp.overRatio,
            isBlurry:  isBlurry,
            isUnder:   isUnder,
            isOver:    isOver
        ))
    }

    if args.jsonOutput {
        let dicts: [[String: Any]] = results.map { r in
            var flags: [String] = []
            if r.isBlurry { flags.append("UNSCHARF") }
            if r.isUnder  { flags.append("UNTER") }
            if r.isOver   { flags.append("ÜBER") }
            return [
                "path":       r.path,
                "filename":   r.filename,
                "blur_score": r.blurScore,
                "under_ratio": r.underRatio,
                "over_ratio":  r.overRatio,
                "flags":      flags
            ] as [String: Any]
        }
        if let data = try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
        return 0
    }

    // Table output
    let colName = 36
    func pad(_ s: String, _ w: Int) -> String {
        s.count >= w ? String(s.prefix(w - 1)) + "…" : s + String(repeating: " ", count: w - s.count)
    }
    let header = "\(pad("Dateiname", colName))  \(pad("Blur", 9))  \(pad("Belicht.", 9))  Flags"
    print(header)
    print(String(repeating: "─", count: header.count + 2))

    for r in results {
        var flags: [String] = []
        if r.isBlurry { flags.append("UNSCHARF") }
        if r.isUnder  { flags.append("UNTER") }
        if r.isOver   { flags.append("ÜBER") }
        let flagStr = flags.isEmpty ? "OK" : flags.joined(separator: " ")
        let blurStr = String(format: "%9.1f", r.blurScore)
        let expStr  = String(format: "%9.3f", r.underRatio)
        print("\(pad(r.filename, colName))  \(blurStr)  \(expStr)  \(flagStr)")
    }
    print("")
    print("Gesamt: \(results.count) Datei(en)  " +
          "Unscharf: \(results.filter { $0.isBlurry }.count)  " +
          "Unterbelichtet: \(results.filter { $0.isUnder }.count)  " +
          "Überbelichtet: \(results.filter { $0.isOver }.count)")
    return 0
}

// MARK: - Inpaint Command

private func runInpaint(_ args: CLIArgs) -> Int32 {
    guard let input = args.inputs.first else {
        fputs("Fehler: Eingabedatei angeben — iphoto-cli inpaint <datei> --output <ziel>\n", stderr)
        return 1
    }
    guard let outputDir = args.outputURL ?? args.outputDir else {
        fputs("Fehler: --output <ziel> ist erforderlich\n", stderr)
        return 1
    }
    guard FileManager.default.fileExists(atPath: input.path) else {
        fputs("Fehler: Datei nicht gefunden: \(input.path)\n", stderr)
        return 1
    }

    let config = InpaintProcessor.Config(
        cmtDirectory:   args.cmtPath,
        checkpointPath: args.checkpointPath,
        python3Path:    args.pythonPath
    )

    do {
        try InpaintProcessor.validateSetup(config: config)
    } catch {
        fputs("Fehler: Inpaint-Setup ungültig — \(error.localizedDescription)\n", stderr)
        fputs("Tipp: CMT installieren unter https://github.com/vt-vl-lab/3d-photo-inpainting\n", stderr)
        return 1
    }

    // Inpaint requires an image + mask; CLI mode uses the image itself decoded as both
    // (for smoke-testing; production use is through the GUI InpaintPanel).
    do {
        let cg = try RAWImageDecoder.decode(url: input)
        // Create a trivial all-white mask (inpaint nothing — just tests the pipeline)
        let w = cg.width, h = cg.height
        var white = [UInt8](repeating: 255, count: w * h)
        guard let maskCtx = CGContext(data: &white, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let mask = maskCtx.makeImage() else {
            fputs("Fehler: Maske konnte nicht erstellt werden\n", stderr)
            return 1
        }

        let result = try InpaintProcessor.run(image: cg, mask: mask, config: config)
        let outURL = outputDir.appendingPathExtension("png")
        try? FileManager.default.createDirectory(
            at: outputDir.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil) else {
            fputs("Fehler: Ausgabedatei konnte nicht erstellt werden\n", stderr)
            return 1
        }
        CGImageDestinationAddImage(dest, result, nil)
        guard CGImageDestinationFinalize(dest) else {
            fputs("Fehler: Schreiben fehlgeschlagen\n", stderr)
            return 1
        }
        print("OK  \(outURL.path)")
        return 0
    } catch {
        fputs("FAIL \(input.lastPathComponent): \(error.localizedDescription)\n", stderr)
        return 1
    }
}

// MARK: - HDR Test

private struct HDRPreset {
    let name: String       // Dateiname-Suffix
    let label: String      // Beschreibung
    let contrast: Float
    let saturation: Float
    let exposedness: Float
}

private let hdrPresets: [HDRPreset] = [
    HDRPreset(name: "A_default",      label: "Standard      c=1.0 s=1.0 e=1.0",  contrast: 1.0, saturation: 1.0, exposedness: 1.0),
    HDRPreset(name: "B_no_sat",       label: "Kein Sättigung c=1.0 s=0.0 e=1.0",  contrast: 1.0, saturation: 0.0, exposedness: 1.0),
    HDRPreset(name: "C_contrast",     label: "Kontrast-Heavy c=2.0 s=0.5 e=1.0",  contrast: 2.0, saturation: 0.5, exposedness: 1.0),
    HDRPreset(name: "D_exposure",     label: "Exposition-Hvy c=1.0 s=1.0 e=2.0",  contrast: 1.0, saturation: 1.0, exposedness: 2.0),
    HDRPreset(name: "E_natural",      label: "Natural        c=1.5 s=0.0 e=1.5",  contrast: 1.5, saturation: 0.0, exposedness: 1.5),
    HDRPreset(name: "F_gentle",       label: "Sanft          c=0.5 s=0.5 e=1.5",  contrast: 0.5, saturation: 0.5, exposedness: 1.5),
]

private func runHDR(_ args: CLIArgs) -> Int32 {
    let rawExts: Set<String> = ["raf","cr2","cr3","nef","arw","dng","orf","rw2","nrw","pef",
                                 "srw","erf","kdc","dcr","raw","rwl","mrw","3fr","mef","iiq",
                                 "x3f","srf","sr2","jpg","jpeg","tiff","tif","png","heic","heif"]

    // Eingabe: Ordner oder explizite Dateien
    var inputURLs: [URL]
    if args.inputs.count == 1 {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: args.inputs[0].path, isDirectory: &isDir)
        if isDir.boolValue {
            inputURLs = (try? FileManager.default.contentsOfDirectory(
                at: args.inputs[0], includingPropertiesForKeys: nil
            ))?.filter { rawExts.contains($0.pathExtension.lowercased()) }
              .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        } else {
            inputURLs = args.inputs
        }
    } else {
        inputURLs = args.inputs
    }

    guard inputURLs.count >= 2 else {
        fputs("Fehler: Mindestens 2 Bilder für HDR-Merge benötigt (gefunden: \(inputURLs.count))\n", stderr)
        return 1
    }

    let outDir: URL
    if let d = args.outputDir {
        outDir = d
    } else if let d = args.inputs.first.map({ $0.deletingLastPathComponent() }) {
        outDir = d
    } else {
        fputs("Fehler: --output-dir <ordner> angeben\n", stderr)
        return 1
    }
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    print("HDR-Merge: \(inputURLs.count) Bilder")
    for url in inputURLs { print("  · \(url.lastPathComponent)") }
    print("")
    print("Dekodiere RAWs…")

    // Alle Bilder einmalig dekodieren
    var cgImages: [CGImage] = []
    for url in inputURLs {
        do {
            let img = try RAWImageDecoder.decode(url: url)
            cgImages.append(img)
            print("  ✓ \(url.lastPathComponent)  \(img.width)×\(img.height)")
        } catch {
            fputs("  ✗ \(url.lastPathComponent): \(error.localizedDescription)\n", stderr)
        }
    }

    guard cgImages.count >= 2 else {
        fputs("Fehler: Weniger als 2 Bilder dekodierbar\n", stderr)
        return 1
    }

    print("")
    print("Erzeuge \(hdrPresets.count) Preset-Varianten…")
    print(String(repeating: "─", count: 56))

    var failed = 0
    for preset in hdrPresets {
        let outURL = outDir.appendingPathComponent("hdr_\(preset.name).tiff")
        let opts = HDRMerger.Options(
            contrastWeight:   preset.contrast,
            saturationWeight: preset.saturation,
            exposednessWeight: preset.exposedness
        )
        print("[\(preset.name)]  \(preset.label)")
        let t0 = Date()
        guard let merged = HDRMerger.merge(cgImages: cgImages, options: opts) else {
            fputs("  ✗ Merge fehlgeschlagen\n", stderr)
            failed += 1
            continue
        }
        let elapsed = Date().timeIntervalSince(t0)

        // Als TIFF speichern (verlustfrei)
        guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.tiff" as CFString, 1, nil) else {
            fputs("  ✗ TIFF-Ziel konnte nicht erstellt werden\n", stderr)
            failed += 1
            continue
        }
        CGImageDestinationAddImage(dest, merged, nil)
        if CGImageDestinationFinalize(dest) {
            print("  → \(outURL.lastPathComponent)  (\(String(format: "%.1f", elapsed))s)")
        } else {
            fputs("  ✗ TIFF schreiben fehlgeschlagen\n", stderr)
            failed += 1
        }
    }

    print(String(repeating: "─", count: 56))
    print("Fertig. \(hdrPresets.count - failed)/\(hdrPresets.count) erfolgreich → \(outDir.path)")
    return failed == 0 ? 0 : 1
}

// MARK: - Plugins Command

private func runPlugins(_ subArgs: [String]) -> Int32 {
    let pluginDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("iPhoto/Plugins")

    let sub = subArgs.first ?? "list"
    let jsonOutput = subArgs.contains("--json")

    switch sub {
    case "dir":
        print(pluginDir.path)
        return 0
    case "list":
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: pluginDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }) ?? []

        struct PluginInfo: Codable {
            let id: String
            let name: String
            let icon: String
            let builtin: String?
            let order: Int
            let defaultEnabled: Bool
        }

        var infos: [PluginInfo] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = obj["id"] as? String,
                  let name = obj["name"] as? String else { continue }
            infos.append(PluginInfo(
                id: id,
                name: name,
                icon: obj["icon"] as? String ?? "puzzlepiece.extension",
                builtin: obj["builtin"] as? String,
                order: obj["order"] as? Int ?? 99,
                defaultEnabled: obj["defaultEnabled"] as? Bool ?? true
            ))
        }
        infos.sort { $0.order < $1.order }

        if jsonOutput {
            if let data = try? JSONEncoder().encode(infos),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            func padRight(_ s: String, _ w: Int) -> String {
                s.count >= w ? s : s + String(repeating: " ", count: w - s.count)
            }
            print("Plugin-Ordner: \(pluginDir.path)")
            print("─────────────────────────────────────")
            for p in infos {
                let kind = p.builtin != nil ? "[builtin:\(p.builtin!)]" : "[extern]"
                let orderStr = padRight(String(p.order), 4)
                let nameStr  = padRight(p.name, 30)
                print("  \(orderStr)  \(nameStr)  \(kind)  \(p.id)")
            }
            print("─────────────────────────────────────")
            print("  \(infos.count) Plugins/Panels")
        }
        return 0
    default:
        fputs("Fehler: Unbekannter plugins-Unterbefehl '\(sub)'. Erlaubt: list, dir\n", stderr)
        return 1
    }
}

// MARK: - ViewMode Command

private let viewModeKey = "library.viewMode"
private let validViewModes = ["grid", "list", "columns", "gallery"]

private func runViewMode(_ subArgs: [String]) -> Int32 {
    let sub = subArgs.first ?? ""
    switch sub {
    case "get":
        let defaults = UserDefaults.standard
        // UserDefaults.standard in CLI reads from the app's domain if IPHOTO_CATALOG_DB is set,
        // but for a headless CLI we use a shared suite. Fall back to "gallery" when unset.
        let current = defaults.string(forKey: viewModeKey) ?? "gallery"
        print(current)
        return 0
    case "set":
        guard subArgs.count >= 2 else {
            fputs("Fehler: 'viewmode set' benötigt einen Modus: grid|list|columns|gallery\n", stderr)
            return 1
        }
        let mode = subArgs[1].lowercased()
        guard validViewModes.contains(mode) else {
            fputs("Fehler: Unbekannter Modus '\(mode)'. Erlaubt: grid, list, columns, gallery\n", stderr)
            return 1
        }
        UserDefaults.standard.set(mode, forKey: viewModeKey)
        UserDefaults.standard.synchronize()
        print("Ansicht gesetzt: \(mode)")
        return 0
    default:
        fputs("Fehler: Unbekannter viewmode-Unterbefehl '\(sub)'. Erlaubt: get, set <modus>\n", stderr)
        return 1
    }
}

// MARK: - Entry Point

let rawArgs = CommandLine.arguments
guard rawArgs.count >= 2 else { printUsage(); exit(0) }

// Special case: "preset" and "plugins" commands need their sub-args forwarded differently
let firstArg = rawArgs[1]
if firstArg == "preset" {
    let subArgs = Array(rawArgs.dropFirst(2))
    exit(runPreset(subArgs))
}
if firstArg == "plugins" {
    let subArgs = Array(rawArgs.dropFirst(2))
    exit(runPlugins(subArgs))
}
if firstArg == "viewmode" {
    let subArgs = Array(rawArgs.dropFirst(2))
    exit(runViewMode(subArgs))
}

guard let parsed = parseArgs(rawArgs) else { exit(1) }

let exitCode: Int32
switch parsed.command {
case "export":
    exitCode = runExport(parsed)
case "info":
    exitCode = runInfo(parsed)
case "hdr":
    exitCode = runHDR(parsed)
case "hotpixel":
    exitCode = runHotPixel(parsed)
case "rating":
    exitCode = runRating(parsed)
case "adjust":
    exitCode = runAdjust(parsed)
case "analyse", "analyze":
    exitCode = runAnalyse(parsed)
case "inpaint":
    exitCode = runInpaint(parsed)
case "--help", "-h", "help":
    printUsage()
    exitCode = 0
default:
    fputs("Fehler: Unbekannter Befehl '\(parsed.command)'\n", stderr)
    printUsage()
    exitCode = 1
}

exit(exitCode)
