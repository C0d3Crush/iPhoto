import Foundation
import CoreGraphics
import ImageIO
import CoreImage

// MARK: - Usage

private func printUsage() {
    print("""
    Verwendung:
      iphoto-cli export <eingabe> --format jpeg|png|tiff|heif [--output <pfad>] [--quality 0.9] [--json]
      iphoto-cli export <datei1> <datei2> ... --format jpeg --output-dir <ordner> [--json]
      iphoto-cli hdr <ordner> --output-dir <ziel>
      iphoto-cli info <eingabe> [--json]
      iphoto-cli hotpixel <ordner>
      iphoto-cli rating <datei> [--set 0-5] [--flag pick|reject|none] [--color red|yellow|green|blue|none] [--remove] [--json]
      iphoto-cli adjust <datei> --output <ziel> [--format jpeg|png|tiff|heif] [--quality 0.9]
                        [--exposure N] [--brightness N] [--contrast N] [--saturation N]
                        [--warmth N] [--tint N] [--vibrance N] [--hue N]
                        [--clarity N] [--sharpen N] [--preset <name>]
                        [--crop x,y,w,h] [--rotate 90|180|270]
      iphoto-cli preset list [--json]
      iphoto-cli preset apply <datei> --name <name> --output <ziel> [--format jpeg] [--quality 0.9] [--json]
      iphoto-cli preset save <bildpfad> --name <name> [--author <text>] [--json]
      iphoto-cli preset export <name> --output <datei.iphotorecipe> [--json]
      iphoto-cli preset import <datei.iphotorecipe> [--json]
      iphoto-cli preset delete <name>
      iphoto-cli analyse <datei|ordner> [--json] [--blur-threshold N] [--shadow N] [--highlight N]
      iphoto-cli inpaint <datei> --output <ziel> [--python /usr/bin/python3] [--cmt ~/cmt] [--checkpoint ~/cmt/checkpoints]
      iphoto-cli plugins list [--json]
      iphoto-cli plugins dir
      iphoto-cli viewmode get [--json]
      iphoto-cli viewmode set <grid|list|columns|gallery> [--json]
      iphoto-cli people scan <bild1> [<bild2> ...] [--json]
      iphoto-cli people list [--json]
      iphoto-cli people faces [--path <bildpfad>] [--json]
      iphoto-cli people cluster [--epsilon 0.12] [--json]
      iphoto-cli people rename <id> <name> [--json]
      iphoto-cli people export-names [--output <datei.csv>] [--json]
      iphoto-cli people import-names <datei.csv> [--json]
      iphoto-cli album list|create|delete|add|remove|images|reorder [--json]
      iphoto-cli quality scan|list|get [--json]
      iphoto-cli version list|backup|restore|delete [--json]
      iphoto-cli search <text> [--flag pick|reject|none] [--rating N] [--color farbe] [--camera modell] [--date YYYY-MM-DD] [--json]
      iphoto-cli catalog stats|path|vacuum|export|scan-needed|backup-now [--json]
      iphoto-cli albumfolder list|create|rename|delete [--json]
      iphoto-cli motif get <bildpfad> [--json]
      iphoto-cli motif list [--json]
      iphoto-cli duplicate list|similar [--json]
      iphoto-cli config show|get <key>|set <key> <wert>|export [--path <pfad>]|import <pfad>
      iphoto-cli metadata get <bildpfad> [--json]
      iphoto-cli metadata set <bildpfad> [--title X] [--caption X] [--keywords X]
                              [--copyright X] [--creator X] [--date "YYYY:MM:DD HH:MM:SS"]
                              [--lat N] [--lon N] [--json]
      iphoto-cli cache stats|clear [--json]
      iphoto-cli watched list [--json]
      iphoto-cli watched add <pfad> [--auto-sync] [--json]
      iphoto-cli watched remove <name|id> [--json]
      iphoto-cli watched check [<name|id>] [--json]
      iphoto-cli backup get [--json]
      iphoto-cli backup set [--quality 0.85] [--mode rename|skip|overwrite] [--dest <pfad>]
                            [--downscale|--no-downscale] [--long-side 2560]
                            [--metadata|--no-metadata] [--json]
      iphoto-cli rating list [--flag pick|reject] [--color farbe] [--min-rating N] [--json]
      iphoto-cli smartfolder list [--json]
      iphoto-cli smartfolder query <name> [--json]
      iphoto-cli smartfolder create <name> [--rating-min N] [--flag pick|reject] [--color farbe] [--json]
      iphoto-cli smartfolder update <name> [--rating-min N] [--flag pick|reject] [--color farbe]
      iphoto-cli smartfolder rename <alter-name> <neuer-name>
      iphoto-cli smartfolder delete <name> [--json]
      iphoto-cli smartfolder sync [<name>] [--json]
      iphoto-cli local-adjustments list <bildpfad> [--json]
      iphoto-cli local-adjustments clear <bildpfad> [--json]
      iphoto-cli rating histogram [--json]
      iphoto-cli exif get <bildpfad> [--json]
      iphoto-cli exif set <bildpfad> [--iso N] [--focal MM] [--aperture F] [--lens NAME]
                          [--film NAME] [--hdr true|false] [--json]
      iphoto-cli exif films [--json]
      iphoto-cli stack list [--json]
      iphoto-cli stack query <bildpfad> [--json]
      iphoto-cli trash list [--json]
      iphoto-cli trash mark <bildpfad> [--json]
      iphoto-cli trash restore <bildpfad>|--all [--json]
      iphoto-cli trash empty [--json]
      iphoto-cli elo get <bildpfad> [--json]
      iphoto-cli elo list [--json]
      iphoto-cli elo set <bildpfad> <wert> [--matches N] [--json]
      iphoto-cli adjustments list [--json]
      iphoto-cli adjustments get <bildpfad> [--json]
      iphoto-cli adjustments delete <bildpfad> [--json]
      iphoto-cli rating batch-set <bild1> [<bild2>...] [--set N] [--flag pick|reject|none] [--color farbe] [--json]
      iphoto-cli export --list-formats [--json]
      iphoto-cli catalog scan-needed [--json]
      iphoto-cli catalog backup-now [--json]

    Formate:  jpeg (Standard), png, tiff, heif
    Quality:  0.0–1.0, nur für jpeg und heif (Standard: 0.9)
    hdr:      Erzeugt 6 Preset-Varianten aus allen RAWs im Ordner (Vergleich); --json
    info:     Gibt alle EXIF/IPTC/GPS-Metadaten aus; --json für maschinenlesbare Ausgabe
    rating:   Liest/schreibt Bewertung, Flag und Farblabel; 'list' zeigt alle bewerteten Bilder
    adjust:   Wendet Bildanpassungen an und exportiert das Ergebnis
    preset:   Zeigt Built-in-Presets oder wendet einen an
    analyse:  Analysiert Schärfe und Belichtung (Blur + Exposure)
    inpaint:  KI-basiertes Inpainting via CMT (benötigt Python + CMT-Installation); --json
    plugins:  Listet installierte Plugins/Panels auf oder zeigt den Plugin-Ordner; dir --json
    album:    Alben erstellen, bearbeiten, Bilder hinzufügen/entfernen
    quality:  Qualitätsanalyse (Blur, Belichtung, Closed-Eye) scannen und lesen; list --sort blur|rating|elo
    version:  Versionshistorie eines Bildes sichern, anzeigen oder wiederherstellen
    search:   Bilder im Katalog nach Text, Flag (none/pick/reject), Rating (0-5), Farbe, Kamera, Datum
    catalog:  Statistiken (inkl. ELO-Anzahl), Pfad, vacuum --json, export
    motif:    Motiv-Tags eines Bildes anzeigen
    elo:      ELO-Scores lesen, auflisten (nach Score sortiert) und setzen
    duplicate:Duplikate und ähnliche Bilder aus dem Katalog anzeigen
    config:   Einstellungen anzeigen, lesen (get <key>), schreiben (set <key> <wert>), ex-/importieren
    metadata: IPTC/EXIF/GPS-Felder eines Bildes lesen (get) und schreiben (set); nur JPEG/PNG/TIFF
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
    var ratingRemove: Bool = false

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

    // crop / rotate flags (for adjust command)
    var cropRect: CGRect? = nil           // normalized 0-1 coords: x,y,w,h
    var rotateTurns: Int? = nil           // 1=90°, 2=180°, 3=270°

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
        case "--remove":
            result.ratingRemove = true
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
            guard v > 0 else { fputs("Fehler: --blur-threshold muss größer als 0 sein\n", stderr); return nil }
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
        case "--crop":
            i += 1
            guard i < args.count else { fputs("Fehler: --crop braucht x,y,w,h (normalisiert 0-1)\n", stderr); return nil }
            let parts = args[i].split(separator: ",").compactMap { Double($0) }
            guard parts.count == 4 else {
                fputs("Fehler: --crop Format: x,y,w,h (z.B. 0.1,0.1,0.8,0.8)\n", stderr); return nil
            }
            result.cropRect = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
        case "--rotate":
            i += 1
            guard i < args.count else { fputs("Fehler: --rotate braucht 90, 180 oder 270\n", stderr); return nil }
            let deg = args[i]
            switch deg {
            case "90":  result.rotateTurns = 1
            case "180": result.rotateTurns = 2
            case "270": result.rotateTurns = 3
            default:
                fputs("Fehler: --rotate erlaubt: 90, 180, 270\n", stderr); return nil
            }
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
    var jsonResults: [[String: Any]] = []

    if isBatch {
        guard let dir = args.outputDir else {
            fputs("Fehler: Bei mehreren Dateien --output-dir <ordner> angeben\n", stderr)
            return 1
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let silent = args.jsonOutput
        var failed = 0
        for input in args.inputs {
            let stem = input.deletingPathExtension().lastPathComponent
            let outURL = dir.appendingPathComponent(stem).appendingPathExtension(args.format.fileExtension)
            let ok = exportOne(input: input, output: outURL, format: args.format, quality: args.quality, silent: silent)
            if !ok { failed += 1 }
            jsonResults.append(["input": input.lastPathComponent, "output": outURL.path, "ok": ok])
        }
        if args.jsonOutput,
           let data = try? JSONSerialization.data(withJSONObject: jsonResults, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) { print(str) }
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
        let ok = exportOne(input: input, output: outURL, format: args.format, quality: args.quality, silent: args.jsonOutput)
        if args.jsonOutput {
            let obj: [String: Any] = ["input": input.lastPathComponent, "output": outURL.path, "ok": ok]
            if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) { print(str) }
        }
        return ok ? 0 : 1
    }
}

@discardableResult
private func exportOne(input: URL, output: URL, format: ExportFormat, quality: Double, silent: Bool = false) -> Bool {
    do {
        let image = try RAWImageDecoder.decode(url: input)
        try ImageExporter.exportSingle(image: image, to: output, format: format, quality: quality)
        guard FileManager.default.fileExists(atPath: output.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: output.path),
              (attrs[.size] as? Int ?? 0) > 0 else {
            fputs("FAIL \(input.lastPathComponent): Ausgabedatei nicht geschrieben oder leer\n", stderr)
            return false
        }
        if !silent { print("OK  \(output.path)") }
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

    if !args.jsonOutput {
        print("Hot-Pixel-Analyse: \(urls.count) Datei(en) in \(dir.lastPathComponent)")
    }

    guard let result = HotPixelAnalyzer.analyze(urls: urls, progress: { status, pct in
        guard !args.jsonOutput else { return }
        let bar = String(repeating: "█", count: Int(pct * 30))
            + String(repeating: "░", count: 30 - Int(pct * 30))
        print("\r[\(bar)] \(Int(pct * 100))%  \(status)          ", terminator: "")
        fflush(stdout)
    }) else {
        fputs("Fehler: Analyse fehlgeschlagen (keine Frames dekodierbar)\n", stderr)
        return 1
    }

    if args.jsonOutput {
        let topPixels: [[String: Any]] = result.hotPixels.prefix(10).map {
            ["x": $0.x, "y": $0.y, "value": $0.value]
        }
        let obj: [String: Any] = [
            "sensor_width":  result.sensorWidth,
            "sensor_height": result.sensorHeight,
            "frame_count":   result.frameCount,
            "dark_mean":     result.darkMean,
            "dark_std":      result.darkStd,
            "threshold":     result.threshold,
            "hot_count":     result.hotCount,
            "grade":         result.grade,
            "grade_label":   result.gradeLabel,
            "top_pixels":    topPixels
        ]
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) { print(str) }
        return 0
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

    // ASCII cluster grid (20×20)
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

private func runRatingList(_ args: [String]) -> Int32 {
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())
    var all = catalog.allRatings()

    if let fi = args.firstIndex(of: "--flag"), fi + 1 < args.count {
        let flag = args[fi + 1].lowercased()
        guard FlagStatus(rawValue: flag) != nil else {
            fputs("Fehler: Ungültiger Flag-Wert '\(args[fi + 1])'. Erlaubt: none, pick, reject\n", stderr)
            return 1
        }
        all = all.filter { $0.value.flag == flag }
    }
    if let ci = args.firstIndex(of: "--color"), ci + 1 < args.count {
        let color = args[ci + 1].lowercased()
        guard ColorLabel(rawValue: color) != nil else {
            fputs("Fehler: Ungültige Farbe '\(args[ci + 1])'. Erlaubt: none, red, yellow, green, blue\n", stderr)
            return 1
        }
        all = all.filter { $0.value.colorLabel == color }
    }
    if let ri = args.firstIndex(of: "--min-rating"), ri + 1 < args.count {
        guard let n = Int(args[ri + 1]), n >= 0, n <= 5 else {
            fputs("Fehler: --min-rating muss zwischen 0 und 5 liegen (angegeben: \(args[ri + 1]))\n", stderr)
            return 1
        }
        all = all.filter { $0.value.rating >= n }
    }

    let sorted = all.sorted { $0.key < $1.key }
    if jsonMode {
        let arr = sorted.map { (path, e) -> [String: Any] in
            ["path": path, "rating": e.rating, "flag": e.flag, "color": e.colorLabel]
        }
        if let d = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
           let s = String(data: d, encoding: .utf8) { print(s) }
    } else {
        if sorted.isEmpty { print("(keine bewerteten Bilder)") }
        else {
            for (path, e) in sorted {
                print("rating=\(e.rating)  flag=\(e.flag)  color=\(e.colorLabel)  \(path)")
            }
        }
        print("Gesamt: \(sorted.count) Bild(er)")
    }
    return 0
}

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

    if args.ratingRemove {
        catalog.removeRating(path: path)
        print("Rating entfernt: \(input.lastPathComponent)")
        return 0
    }

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
    if let v = args.cropRect    { state.cropRect    = v }
    if let v = args.rotateTurns { state.turns       = v }

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
        guard FileManager.default.fileExists(atPath: output.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: output.path),
              (attrs[.size] as? Int ?? 0) > 0 else {
            fputs("FAIL \(input.lastPathComponent): Ausgabedatei nicht geschrieben oder leer\n", stderr)
            return 1
        }
        if args.jsonOutput {
            let obj: [String: Any] = [
                "input": input.lastPathComponent,
                "output": output.path,
                "format": args.format.rawValue.lowercased(),
                "ok": true
            ]
            if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            print("OK  \(output.path)")
        }
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

        let jsonModeApply = subArgs.contains("--json")
        do {
            let cg = try RAWImageDecoder.decode(url: input)
            let ci = CIImage(cgImage: cg)
            let adjusted = applyAdjustments(ci, state: preset.adjustments)
            guard let outCG = cliCIContext.createCGImage(adjusted, from: adjusted.extent) else {
                fputs("Fehler: Bild konnte nicht gerendert werden\n", stderr)
                return 1
            }
            try ImageExporter.exportSingle(image: outCG, to: output, format: format, quality: quality)
            if jsonModeApply {
                let obj: [String: Any] = ["input": input.lastPathComponent, "output": output.path,
                                          "preset": name, "ok": true]
                if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                   let s = String(data: d, encoding: .utf8) { print(s) }
            } else {
                print("OK  \(output.path)")
            }
            return 0
        } catch {
            fputs("FAIL \(input.lastPathComponent): \(error.localizedDescription)\n", stderr)
            return 1
        }

    case "delete":
        let deletePositional = subArgs.dropFirst().filter { !$0.hasPrefix("--") }
        guard let nameOrId = deletePositional.first else {
            fputs("Fehler: 'preset delete <name>' — Name angeben\n", stderr)
            return 1
        }
        let jsonDelete = subArgs.contains("--json")
        let catalog = CatalogStore(dbPath: envDBPath())
        let userPresets = catalog.allUserPresets()
        guard let found = userPresets.first(where: {
            $0.name.lowercased() == nameOrId.lowercased() || $0.id.uuidString.lowercased() == nameOrId.lowercased()
        }) else {
            fputs("Fehler: Nutzer-Preset '\(nameOrId)' nicht gefunden\n", stderr)
            return 1
        }
        catalog.deletePreset(id: found.id)
        if jsonDelete {
            let obj: [String: Any] = ["name": found.name, "id": found.id.uuidString, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Preset gelöscht: \(found.name)")
        }
        return 0

    case "save":
        // preset save <bildpfad> --name <name> [--author <text>] [--json]
        let positionals = subArgs.dropFirst().filter { !$0.hasPrefix("-") }
        var saveName: String? = nil
        var saveAuthor: String? = nil
        var savePath: String? = positionals.first
        var si = 1
        while si < subArgs.count {
            switch subArgs[si] {
            case "--name":   si += 1; if si < subArgs.count { saveName = subArgs[si] }
            case "--author": si += 1; if si < subArgs.count { saveAuthor = subArgs[si] }
            default: break
            }
            si += 1
        }
        let jsonSave = subArgs.contains("--json")
        guard let imgPath = savePath else {
            fputs("Verwendung: iphoto-cli preset save <bildpfad> --name <name>\n", stderr); return 1
        }
        guard let pName = saveName else {
            fputs("Fehler: --name <name> ist erforderlich\n", stderr); return 1
        }
        let catalog = CatalogStore(dbPath: envDBPath())
        let adj = catalog.loadAdjustments(path: imgPath) ?? AdjustmentState()
        let newPreset = Preset(name: pName, author: saveAuthor, adjustments: adj)
        catalog.savePreset(newPreset)
        if jsonSave {
            let obj: [String: Any] = ["name": pName, "id": newPreset.id.uuidString, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Preset gespeichert: \(pName) (\(newPreset.id.uuidString))")
        }
        return 0

    case "export":
        // preset export <name> --output <datei.iphotorecipe> [--json]
        let exportPositionals = subArgs.dropFirst().filter { !$0.hasPrefix("-") }
        var exportOutput: URL? = nil
        var ei = 1
        while ei < subArgs.count {
            if subArgs[ei] == "--output", ei + 1 < subArgs.count {
                exportOutput = URL(fileURLWithPath: subArgs[ei + 1]); ei += 2
            } else { ei += 1 }
        }
        let jsonExport = subArgs.contains("--json")
        guard let exportName = exportPositionals.first else {
            fputs("Verwendung: iphoto-cli preset export <name> --output <datei.iphotorecipe>\n", stderr); return 1
        }
        guard let outFile = exportOutput else {
            fputs("Fehler: --output <datei.iphotorecipe> ist erforderlich\n", stderr); return 1
        }
        let catalogE = CatalogStore(dbPath: envDBPath())
        let allE = Preset.builtIn + catalogE.allUserPresets()
        guard let found = allE.first(where: { $0.name.lowercased() == exportName.lowercased() }) else {
            fputs("Fehler: Preset '\(exportName)' nicht gefunden\n", stderr); return 1
        }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(found)
            try data.write(to: outFile)
        } catch {
            fputs("Fehler beim Schreiben: \(error.localizedDescription)\n", stderr); return 1
        }
        if jsonExport {
            let obj: [String: Any] = ["name": found.name, "output": outFile.path, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Preset exportiert: \(outFile.path)")
        }
        return 0

    case "import":
        // preset import <datei.iphotorecipe> [--json]
        let importPositionals = subArgs.dropFirst().filter { !$0.hasPrefix("-") }
        let jsonImport = subArgs.contains("--json")
        guard let importFile = importPositionals.first else {
            fputs("Verwendung: iphoto-cli preset import <datei.iphotorecipe>\n", stderr); return 1
        }
        let importURL = URL(fileURLWithPath: importFile)
        guard FileManager.default.fileExists(atPath: importURL.path) else {
            fputs("Fehler: Datei nicht gefunden: \(importURL.path)\n", stderr); return 1
        }
        do {
            let data = try Data(contentsOf: importURL)
            let decoded = try JSONDecoder().decode(Preset.self, from: data)
            let importedPreset = Preset(name: decoded.name, author: decoded.author, adjustments: decoded.adjustments)
            let catalogI = CatalogStore(dbPath: envDBPath())
            catalogI.savePreset(importedPreset)
            if jsonImport {
                let obj: [String: Any] = ["name": importedPreset.name, "id": importedPreset.id.uuidString, "ok": true]
                if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                   let s = String(data: d, encoding: .utf8) { print(s) }
            } else {
                print("Preset importiert: \(importedPreset.name) (\(importedPreset.id.uuidString))")
            }
        } catch {
            fputs("Fehler beim Importieren: \(error.localizedDescription)\n", stderr); return 1
        }
        return 0

    default:
        fputs("Fehler: Unbekannter preset-Unterbefehl '\(sub)'. Erlaubt: list, apply, delete, save, export, import\n", stderr)
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

    guard !results.isEmpty else {
        fputs("Fehler: Keine Bilder konnten geladen werden in '\(input.path)'\n", stderr)
        return 1
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
        if args.jsonOutput {
            let obj: [String: Any] = ["input": input.lastPathComponent, "output": outURL.path, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("OK  \(outURL.path)")
        }
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

    if args.jsonOutput {
        let obj: [String: Any] = [
            "input_count":  inputURLs.count,
            "decoded":      cgImages.count,
            "presets_ok":   hdrPresets.count - failed,
            "presets_total": hdrPresets.count,
            "output_dir":   outDir.path,
            "ok":           failed == 0
        ]
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: d, encoding: .utf8) { print(s) }
    } else {
        print(String(repeating: "─", count: 56))
        print("Fertig. \(hdrPresets.count - failed)/\(hdrPresets.count) erfolgreich → \(outDir.path)")
    }
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
        if jsonOutput {
            let obj: [String: Any] = ["dir": pluginDir.path]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: []),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print(pluginDir.path)
        }
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
    let jsonMode = subArgs.contains("--json")
    switch sub {
    case "get":
        let current = UserDefaults.standard.string(forKey: viewModeKey) ?? "gallery"
        if jsonMode {
            let obj: [String: Any] = ["mode": current]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: []),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print(current)
        }
        return 0
    case "set":
        let positional = subArgs.dropFirst().filter { !$0.hasPrefix("--") }
        guard let mode = positional.first else {
            fputs("Fehler: 'viewmode set' benötigt einen Modus: grid|list|columns|gallery\n", stderr)
            return 1
        }
        let lowMode = mode.lowercased()
        guard validViewModes.contains(lowMode) else {
            fputs("Fehler: Unbekannter Modus '\(lowMode)'. Erlaubt: grid, list, columns, gallery\n", stderr)
            return 1
        }
        UserDefaults.standard.set(lowMode, forKey: viewModeKey)
        UserDefaults.standard.synchronize()
        if jsonMode {
            let obj: [String: Any] = ["mode": lowMode, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: []),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Ansicht gesetzt: \(lowMode)")
        }
        return 0
    default:
        fputs("Fehler: Unbekannter viewmode-Unterbefehl '\(sub)'. Erlaubt: get, set <modus>\n", stderr)
        return 1
    }
}

// MARK: - People

private func runPeople(_ args: [String]) -> Int32 {
    let sub = args.first ?? "list"
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    if sub == "scan" {
        // Collect image paths (all non-flag args after "scan")
        let paths: [String] = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard !paths.isEmpty else {
            fputs("Verwendung: iphoto-cli people scan <bild1> [<bild2> ...]\n", stderr)
            return 1
        }
        var totalFaces = 0
        var results: [[String: Any]] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let img = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                      kCGImageSourceThumbnailMaxPixelSize: 1024,
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true
                  ] as CFDictionary) else {
                fputs("Warnung: Konnte \(path) nicht laden\n", stderr)
                continue
            }
            let filename = url.lastPathComponent
            catalog.upsertImage(path: path, filename: filename, isRAW: false,
                                width: img.width, height: img.height)
            let faces = FaceDetector.detect(in: img, imagePath: path)
            if !faces.isEmpty { catalog.insertFaces(faces) }
            catalog.markFaceScanned(path: path)
            totalFaces += faces.count
            results.append(["path": path, "faces": faces.count])
        }
        if jsonMode {
            if let data = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            for r in results {
                print("\(r["faces"]!) Gesicht(er): \(r["path"]!)")
            }
            print("Gesamt: \(totalFaces) Gesicht(er) in \(paths.count) Bild(ern)")
        }
        return 0
    }

    switch sub {
    case "list":
        let people = catalog.allPeople()
        if jsonMode {
            var arr: [[String: Any]] = []
            for p in people {
                var obj: [String: Any] = ["id": p.id]
                if let n = p.name { obj["name"] = n }
                let faceCount = catalog.allFaces().filter { $0.clusterID == p.id }.count
                obj["face_count"] = faceCount
                arr.append(obj)
            }
            if let data = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            if people.isEmpty {
                print("Keine Personen im Katalog.")
            } else {
                for p in people {
                    let name = p.name ?? "(unbenannt)"
                    print("\(p.id)  \(name)")
                }
            }
        }
        return 0

    case "faces":
        var filterPath: String? = nil
        var i = 1
        while i < args.count {
            if args[i] == "--path", i + 1 < args.count { filterPath = args[i + 1]; i += 2 }
            else { i += 1 }
        }
        let faces: [FaceRecord]
        if let path = filterPath {
            faces = catalog.faces(forPath: path)
        } else {
            faces = catalog.allFaces()
        }
        if jsonMode {
            var arr: [[String: Any]] = []
            for f in faces {
                var obj: [String: Any] = [
                    "id": f.id,
                    "image_path": f.imagePath,
                    "confidence": f.confidence,
                    "bbox": ["x": f.bbox.origin.x, "y": f.bbox.origin.y, "w": f.bbox.width, "h": f.bbox.height]
                ]
                if let cid = f.clusterID { obj["cluster_id"] = cid }
                arr.append(obj)
            }
            if let data = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            if faces.isEmpty {
                print("Keine Gesichter gefunden.")
            } else {
                for f in faces {
                    let cluster = f.clusterID ?? "unzugeordnet"
                    print("\(f.id)  conf=\(String(format: "%.2f", f.confidence))  person=\(cluster)  \(f.imagePath)")
                }
            }
        }
        return 0

    case "cluster":
        var epsilon: Float = FaceClusterer.defaultEpsilon
        var i = 1
        while i < args.count {
            if args[i] == "--epsilon", i + 1 < args.count, let v = Float(args[i + 1]) {
                guard v > 0 else {
                    fputs("Fehler: --epsilon muss größer als 0 sein (angegeben: \(args[i + 1]))\n", stderr)
                    return 1
                }
                epsilon = v; i += 2
            } else { i += 1 }
        }
        let faces = catalog.allFaces()
        guard !faces.isEmpty else {
            if jsonMode {
                let empty: [String: Any] = ["clusters": 0, "noise": 0, "total_faces": 0]
                if let data = try? JSONSerialization.data(withJSONObject: empty, options: .prettyPrinted),
                   let str = String(data: data, encoding: .utf8) { print(str) }
            } else {
                print("Keine Gesichter im Katalog.")
            }
            return 0
        }

        let clusterMap = FaceClusterer.cluster(faces: faces, epsilon: epsilon)
        let clusterCount = Set(clusterMap.values.filter { $0 >= 0 }).count
        let noiseCount   = clusterMap.values.filter { $0 < 0 }.count

        catalog.deleteAutoGeneratedPeople()
        var assignments = [String: String?]()
        let clusters = Set(clusterMap.values.filter { $0 >= 0 })
        for ci in clusters {
            let cFaces = faces.filter { clusterMap[$0.id] == ci }
            let person = PersonRecord(id: UUID().uuidString, name: nil, coverFaceID: cFaces.first?.id)
            catalog.insertPerson(person)
            for face in cFaces { assignments[face.id] = person.id }
        }
        for face in faces where (clusterMap[face.id] ?? -1) < 0 { assignments[face.id] = nil }
        catalog.batchUpdateFaceClusters(assignments)

        if jsonMode {
            let obj: [String: Any] = ["clusters": clusterCount, "noise": noiseCount, "total_faces": faces.count]
            if let data = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            print("Clustering abgeschlossen: \(clusterCount) Gruppen, \(noiseCount) nicht zugeordnet (\(faces.count) Gesichter gesamt)")
        }
        return 0

    case "rename":
        guard args.count >= 3 else {
            fputs("Verwendung: iphoto-cli people rename <id> <name> [--json]\n", stderr)
            return 1
        }
        let personID = args[1]
        let newName  = args[2]
        let all = catalog.allPeople()
        guard let person = all.first(where: { $0.id == personID }) else {
            fputs("Fehler: Person '\(personID)' nicht im Katalog\n", stderr)
            return 1
        }
        var updated = person; updated.name = newName
        catalog.updatePerson(updated)
        if jsonMode {
            if let data = try? JSONSerialization.data(withJSONObject: ["id": personID, "name": newName]),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            print("Person umbenannt: \(personID) → \(newName)")
        }
        return 0

    case "export-names":
        // people export-names --output <datei.csv> [--json]
        var exportOut: URL? = nil
        var i = 1
        while i < args.count {
            if args[i] == "--output", i + 1 < args.count {
                exportOut = URL(fileURLWithPath: args[i + 1]); i += 2
            } else { i += 1 }
        }
        let people = catalog.allPeople()
        let csv = "id,name\n" + people.map { p in
            let name = (p.name ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            return "\(p.id),\"\(name)\""
        }.joined(separator: "\n")
        if let out = exportOut {
            do { try csv.write(to: out, atomically: true, encoding: .utf8) }
            catch { fputs("Fehler beim Schreiben: \(error.localizedDescription)\n", stderr); return 1 }
            if jsonMode {
                let obj: [String: Any] = ["output": out.path, "count": people.count, "ok": true]
                if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                   let s = String(data: d, encoding: .utf8) { print(s) }
            } else {
                print("Exportiert: \(people.count) Person(en) → \(out.path)")
            }
        } else {
            print(csv)
        }
        return 0

    case "import-names":
        // people import-names <datei.csv> [--json]
        let importPath = args.dropFirst().first { !$0.hasPrefix("-") }
        guard let importFile = importPath else {
            fputs("Verwendung: iphoto-cli people import-names <datei.csv>\n", stderr); return 1
        }
        let importURL = URL(fileURLWithPath: importFile)
        guard FileManager.default.fileExists(atPath: importURL.path) else {
            fputs("Fehler: Datei nicht gefunden: \(importURL.path)\n", stderr); return 1
        }
        guard let content = try? String(contentsOf: importURL, encoding: .utf8) else {
            fputs("Fehler: Datei konnte nicht gelesen werden\n", stderr); return 1
        }
        var lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        if lines.first?.lowercased().hasPrefix("id,") == true { lines.removeFirst() }
        var updated = 0
        for line in lines {
            let cols = line.components(separatedBy: ",")
            guard cols.count >= 2 else { continue }
            let id   = cols[0].trimmingCharacters(in: .whitespaces)
            var name = cols.dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("\"") && name.hasSuffix("\"") {
                name = String(name.dropFirst().dropLast()).replacingOccurrences(of: "\"\"", with: "\"")
            }
            let all = catalog.allPeople()
            if let person = all.first(where: { $0.id == id }) {
                var p = person; p.name = name.isEmpty ? nil : name
                catalog.updatePerson(p)
                updated += 1
            }
        }
        if jsonMode {
            let obj: [String: Any] = ["updated": updated, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Namen aktualisiert: \(updated) Person(en)")
        }
        return 0

    default:
        fputs("Fehler: Unbekannter people-Unterbefehl '\(sub)'. Erlaubt: list, faces, cluster, rename, export-names, import-names\n", stderr)
        return 1
    }
}

// MARK: - WatchedFolder

private func watchedFoldersFileURL() -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("iPhoto")
        .appendingPathComponent("watchedFolders.json")
}

private func loadWatchedFoldersList() -> [WatchedFolder] {
    guard let data = try? Data(contentsOf: watchedFoldersFileURL()) else { return [] }
    return (try? JSONDecoder().decode([WatchedFolder].self, from: data)) ?? []
}

private func saveWatchedFoldersList(_ folders: [WatchedFolder]) {
    let url = watchedFoldersFileURL()
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(folders) {
        try? data.write(to: url)
    }
}

private func runWatched(_ args: [String]) -> Int32 {
    let sub = args.first ?? "list"
    let jsonMode = args.contains("--json")

    switch sub {
    case "list":
        let folders = loadWatchedFoldersList()
        if jsonMode {
            let arr: [[String: Any]] = folders.map { f in
                var d: [String: Any] = ["id": f.id.uuidString, "name": f.name]
                if let p = f.bookmarkPath { d["path"] = p }
                d["auto_sync"] = f.autoSync
                d["available"] = f.isAvailable
                d["removable"] = f.isRemovableMedia
                if let dest = f.importDestinationPath { d["import_dest"] = dest }
                return d
            }
            if let data = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
               let s = String(data: data, encoding: .utf8) { print(s) }
        } else {
            if folders.isEmpty {
                print("Keine überwachten Ordner konfiguriert.")
            } else {
                for f in folders {
                    let status = f.isAvailable ? "✓" : "✗"
                    let sync   = f.autoSync ? " [auto-sync]" : ""
                    let path   = f.bookmarkPath ?? "(unbekannt)"
                    print("\(status) \(f.name)\(sync)")
                    print("   Pfad: \(path)")
                    print("   ID:   \(f.id.uuidString)")
                }
            }
        }
        return 0

    case "add":
        let positionals = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard let pathStr = positionals.first else {
            fputs("Verwendung: iphoto-cli watched add <pfad> [--auto-sync] [--json]\n", stderr)
            return 1
        }
        let url = URL(fileURLWithPath: pathStr).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            fputs("Fehler: Verzeichnis nicht gefunden: \(url.path)\n", stderr)
            return 1
        }
        var folders = loadWatchedFoldersList()
        guard !folders.contains(where: { $0.bookmarkPath == url.path }) else {
            fputs("Fehler: Ordner wird bereits überwacht: \(url.path)\n", stderr)
            return 1
        }
        guard let newFolder = try? WatchedFolder(url: url) else {
            fputs("Fehler: Bookmark konnte nicht erstellt werden für: \(url.path)\n", stderr)
            return 1
        }
        var added = newFolder
        if args.contains("--auto-sync") {
            // WatchedFolder is a struct; mutate via local copy
            var mutable = added; mutable.autoSync = true; added = mutable
        }
        folders.append(added)
        saveWatchedFoldersList(folders)
        if jsonMode {
            let obj: [String: Any] = ["id": added.id.uuidString, "name": added.name,
                                      "path": url.path, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Ordner hinzugefügt: \(url.path)")
        }
        return 0

    case "remove":
        let positionals = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard let nameOrId = positionals.first else {
            fputs("Verwendung: iphoto-cli watched remove <name|id> [--json]\n", stderr)
            return 1
        }
        var folders = loadWatchedFoldersList()
        guard let idx = folders.firstIndex(where: {
            $0.id.uuidString.lowercased() == nameOrId.lowercased() ||
            $0.name.lowercased() == nameOrId.lowercased() ||
            $0.bookmarkPath == nameOrId
        }) else {
            fputs("Fehler: Ordner '\(nameOrId)' nicht gefunden\n", stderr)
            return 1
        }
        let removed = folders.remove(at: idx)
        saveWatchedFoldersList(folders)
        if jsonMode {
            let obj: [String: Any] = ["id": removed.id.uuidString, "name": removed.name, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Ordner entfernt: \(removed.name)")
        }
        return 0

    case "check":
        let positionals = args.dropFirst().filter { !$0.hasPrefix("-") }
        let folders = loadWatchedFoldersList()
        let toCheck = positionals.isEmpty ? folders : folders.filter {
            $0.id.uuidString.lowercased() == positionals[0].lowercased() ||
            $0.name.lowercased() == positionals[0].lowercased()
        }
        guard !toCheck.isEmpty else {
            fputs("Fehler: Kein passender Ordner gefunden\n", stderr); return 1
        }
        if jsonMode {
            let arr: [[String: Any]] = toCheck.map { f in
                ["id": f.id.uuidString, "name": f.name,
                 "path": f.bookmarkPath ?? "",
                 "available": f.isAvailable, "removable": f.isRemovableMedia]
            }
            if let d = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            for f in toCheck {
                let avail = f.isAvailable ? "verfügbar" : "nicht erreichbar"
                let rem   = f.isRemovableMedia ? " (Wechselmedium)" : ""
                print("\(f.name): \(avail)\(rem)")
            }
        }
        return 0

    default:
        fputs("Fehler: Unbekannter watched-Unterbefehl '\(sub)'. Erlaubt: list, add, remove, check\n", stderr)
        return 1
    }
}

// MARK: - BackupConfig

private func runBackupConfig(_ args: [String]) -> Int32 {
    let sub = args.first ?? "get"
    let jsonMode = args.contains("--json")
    let d = UserDefaults.standard

    switch sub {
    case "get":
        let quality   = (d.object(forKey: "backup.jpegQuality") as? Double) ?? 0.85
        let metadata  = (d.object(forKey: "backup.copyMetadata") as? Bool) ?? true
        let downscale = (d.object(forKey: "backup.downscaleEnabled") as? Bool) ?? false
        let longSide  = (d.object(forKey: "backup.longSidePixels") as? Int) ?? 2560
        let mode      = d.string(forKey: "backup.collisionMode") ?? "rename"
        let destPath  = d.string(forKey: "backup.destinationDisplayPath")
            ?? (FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("iPhoto/Backups").path)
        if jsonMode {
            let obj: [String: Any] = [
                "jpeg_quality": quality,
                "copy_metadata": metadata,
                "downscale_enabled": downscale,
                "long_side_pixels": longSide,
                "collision_mode": mode,
                "destination": destPath
            ]
            if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: data, encoding: .utf8) { print(s) }
        } else {
            print("Backup-Konfiguration:")
            print("  Zielordner:    \(destPath)")
            print("  JPEG-Qualität: \(Int(quality * 100))%")
            print("  Metadaten:     \(metadata ? "ja" : "nein")")
            print("  Herunterskal.: \(downscale ? "ja (\(longSide)px lange Seite)" : "nein")")
            print("  Kollision:     \(mode)")
        }
        return 0

    case "set":
        var i = 1
        while i < args.count {
            switch args[i] {
            case "--quality":
                i += 1
                if i < args.count, let v = Double(args[i]), v > 0, v <= 1 {
                    d.set(v, forKey: "backup.jpegQuality")
                } else {
                    fputs("Fehler: --quality braucht eine Zahl 0.1–1.0\n", stderr); return 1
                }
            case "--mode":
                i += 1
                if i < args.count, ["rename","skip","overwrite"].contains(args[i]) {
                    d.set(args[i], forKey: "backup.collisionMode")
                } else {
                    fputs("Fehler: --mode erlaubt: rename, skip, overwrite\n", stderr); return 1
                }
            case "--dest":
                i += 1
                if i < args.count {
                    let url = URL(fileURLWithPath: args[i])
                    d.set(url.path, forKey: "backup.destinationDisplayPath")
                } else {
                    fputs("Fehler: --dest braucht einen Pfad\n", stderr); return 1
                }
            case "--downscale":
                d.set(true, forKey: "backup.downscaleEnabled")
            case "--no-downscale":
                d.set(false, forKey: "backup.downscaleEnabled")
            case "--long-side":
                i += 1
                if i < args.count, let v = Int(args[i]), v >= 100 {
                    d.set(v, forKey: "backup.longSidePixels")
                } else {
                    fputs("Fehler: --long-side braucht eine Zahl ≥ 100\n", stderr); return 1
                }
            case "--metadata":
                d.set(true, forKey: "backup.copyMetadata")
            case "--no-metadata":
                d.set(false, forKey: "backup.copyMetadata")
            default: break
            }
            i += 1
        }
        if jsonMode {
            let obj: [String: Any] = ["ok": true]
            if let data = try? JSONSerialization.data(withJSONObject: obj),
               let s = String(data: data, encoding: .utf8) { print(s) }
        } else {
            print("Backup-Konfiguration gespeichert.")
        }
        return 0

    default:
        fputs("Fehler: Unbekannter backup-Unterbefehl '\(sub)'. Erlaubt: get, set\n", stderr)
        return 1
    }
}

// MARK: - SmartFolder

private func smartFolderFileURL() -> URL {
    if let dbPath = envDBPath() {
        return URL(fileURLWithPath: dbPath).deletingLastPathComponent()
            .appendingPathComponent("smartFolders.json")
    }
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("iPhoto/smartFolders.json")
}

private func loadSmartFolders() -> [SmartFolder] {
    guard let data = try? Data(contentsOf: smartFolderFileURL()),
          let arr  = try? JSONDecoder().decode([SmartFolder].self, from: data)
    else { return [] }
    return arr
}

private func saveSmartFolders(_ folders: [SmartFolder]) -> Bool {
    let url = smartFolderFileURL()
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    guard let data = try? JSONEncoder().encode(folders) else { return false }
    return (try? data.write(to: url)) != nil
}

private func parseSFCriteria(_ args: [String]) -> [SmartFolderCriterion] {
    var criteria: [SmartFolderCriterion] = []
    if let idx = args.firstIndex(of: "--rating-min"), idx + 1 < args.count {
        if let n = Int(args[idx + 1]), n >= 0, n <= 5 {
            var c = SmartFolderCriterion()
            c.attribute = .rating; c.op = .greaterThan; c.ratingValue = n
            criteria.append(c)
        } else {
            fputs("Fehler: --rating-min muss zwischen 0 und 5 liegen (angegeben: \(args[idx + 1]))\n", stderr)
        }
    }
    if let idx = args.firstIndex(of: "--flag"), idx + 1 < args.count,
       let f = FlagStatus(rawValue: args[idx + 1].lowercased()) {
        var c = SmartFolderCriterion()
        c.attribute = .flag; c.op = .isExact; c.flagValue = f
        criteria.append(c)
    }
    if let idx = args.firstIndex(of: "--color"), idx + 1 < args.count,
       let col = ColorLabel(rawValue: args[idx + 1].lowercased()) {
        var c = SmartFolderCriterion()
        c.attribute = .colorLabel; c.op = .isExact; c.colorValue = col
        criteria.append(c)
    }
    return criteria
}

private func runSmartFolder(_ args: [String]) -> Int32 {
    guard let sub = args.first else {
        fputs("Verwendung: iphoto-cli smartfolder list|query|create|delete [opts]\n", stderr)
        return 1
    }
    let subArgs  = Array(args.dropFirst())
    let jsonMode = args.contains("--json")

    switch sub {
    case "list":
        let folders = loadSmartFolders()
        if jsonMode {
            let items = folders.map { ["id": $0.id.uuidString, "name": $0.name] }
            if let data = try? JSONSerialization.data(withJSONObject: items),
               let str = String(data: data, encoding: .utf8) { print(str) }
            else { print("[]") }
        } else {
            if folders.isEmpty { print("(keine Smart-Ordner)") }
            else { folders.forEach { print("[\($0.id.uuidString)] \($0.name)") } }
        }
        return 0

    case "query":
        guard let name = subArgs.first(where: { !$0.hasPrefix("--") }) else {
            fputs("Verwendung: iphoto-cli smartfolder query <name> [--json]\n", stderr)
            return 1
        }
        guard let sf = loadSmartFolders().first(where: { $0.name == name }) else {
            fputs("Fehler: Smart-Ordner '\(name)' nicht gefunden\n", stderr)
            return 1
        }
        let catalog = CatalogStore(dbPath: envDBPath())
        guard let paths = catalog.orderedPathsForSmartFolder(sf) else {
            fputs("Fehler: Smart-Ordner enthält nicht ausführbare Kriterien (runtime-only)\n", stderr)
            return 1
        }
        if jsonMode {
            if let data = try? JSONSerialization.data(withJSONObject: paths),
               let str = String(data: data, encoding: .utf8) { print(str) }
            else { print("[]") }
        } else {
            if paths.isEmpty { print("(keine Treffer)") }
            else { paths.forEach { print($0) } }
        }
        return 0

    case "create":
        guard let name = subArgs.first(where: { !$0.hasPrefix("--") }) else {
            fputs("Verwendung: iphoto-cli smartfolder create <name> [--rating-min N] [--flag pick|reject] [--color red|yellow|green|blue] [--json]\n", stderr)
            return 1
        }
        var folders = loadSmartFolders()
        guard !folders.contains(where: { $0.name == name }) else {
            fputs("Fehler: Smart-Ordner '\(name)' existiert bereits\n", stderr)
            return 1
        }
        var sf = SmartFolder(name: name)
        sf.criteria = parseSFCriteria(subArgs)
        folders.append(sf)
        guard saveSmartFolders(folders) else {
            fputs("Fehler: Konnte Smart-Ordner nicht speichern\n", stderr)
            return 1
        }
        if jsonMode {
            if let data = try? JSONEncoder().encode(sf),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            print("Smart-Ordner erstellt: [\(sf.id.uuidString)] \(name)")
        }
        return 0

    case "update":
        let positional = subArgs.filter { !$0.hasPrefix("--") }
        guard let name = positional.first else {
            fputs("Verwendung: iphoto-cli smartfolder update <name> [--rating-min N] [--flag pick|reject] [--color red|yellow|green|blue]\n", stderr)
            return 1
        }
        var folders = loadSmartFolders()
        guard let idx = folders.firstIndex(where: { $0.name == name }) else {
            fputs("Fehler: Smart-Ordner '\(name)' nicht gefunden\n", stderr)
            return 1
        }
        folders[idx].criteria = parseSFCriteria(subArgs)
        guard saveSmartFolders(folders) else {
            fputs("Fehler: Konnte Smart-Ordner nicht speichern\n", stderr)
            return 1
        }
        if jsonMode {
            if let data = try? JSONEncoder().encode(folders[idx]),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            print("Smart-Ordner aktualisiert: \(name)")
        }
        return 0

    case "rename":
        let positional = subArgs.filter { !$0.hasPrefix("--") }
        guard positional.count >= 2 else {
            fputs("Verwendung: iphoto-cli smartfolder rename <alter-name> <neuer-name>\n", stderr)
            return 1
        }
        let oldName = positional[0]; let newName = positional[1]
        var folders = loadSmartFolders()
        guard let idx = folders.firstIndex(where: { $0.name == oldName }) else {
            fputs("Fehler: Smart-Ordner '\(oldName)' nicht gefunden\n", stderr)
            return 1
        }
        guard !folders.contains(where: { $0.name == newName }) else {
            fputs("Fehler: Smart-Ordner '\(newName)' existiert bereits\n", stderr)
            return 1
        }
        folders[idx].name = newName
        guard saveSmartFolders(folders) else {
            fputs("Fehler: Konnte Smart-Ordner nicht speichern\n", stderr)
            return 1
        }
        if jsonMode {
            let obj: [String: Any] = ["old_name": oldName, "new_name": newName, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Smart-Ordner umbenannt: \(oldName) → \(newName)")
        }
        return 0

    case "delete":
        guard let name = subArgs.first(where: { !$0.hasPrefix("--") }) else {
            fputs("Verwendung: iphoto-cli smartfolder delete <name>\n", stderr)
            return 1
        }
        var folders = loadSmartFolders()
        let before = folders.count
        folders.removeAll { $0.name == name }
        guard folders.count < before else {
            fputs("Fehler: Smart-Ordner '\(name)' nicht gefunden\n", stderr)
            return 1
        }
        guard saveSmartFolders(folders) else {
            fputs("Fehler: Konnte Smart-Ordner nicht speichern\n", stderr)
            return 1
        }
        let jsonDelete = subArgs.contains("--json")
        if jsonDelete {
            let obj: [String: Any] = ["name": name, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Smart-Ordner gelöscht: \(name)")
        }
        return 0

    case "sync":
        let catalog = CatalogStore(dbPath: envDBPath())
        let targetName = subArgs.first(where: { !$0.hasPrefix("--") })
        let folders = loadSmartFolders()
        let toSync = targetName.map { n in folders.filter { $0.name == n } } ?? folders
        if let name = targetName, toSync.isEmpty {
            fputs("Fehler: Smart-Ordner '\(name)' nicht gefunden\n", stderr)
            return 1
        }
        var synced: [[String: Any]] = []
        for sf in toSync {
            guard let paths = catalog.orderedPathsForSmartFolder(sf) else { continue }
            let urls = paths.map { URL(fileURLWithPath: $0) }
            SmartFolderFileSync.sync(sf, matchingURLs: urls)
            synced.append(["name": sf.name, "count": paths.count])
        }
        if jsonMode {
            let obj: [String: Any] = ["synced": synced, "total": synced.count, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if synced.isEmpty { print("(keine synchronisierbaren Smart-Ordner)") }
            else {
                for s in synced { print("Sync: \(s["name"]!)  (\(s["count"]!) Bilder)") }
                let dir = SmartFolderFileSync.root.path
                print("Symlinks unter: \(dir)")
            }
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli smartfolder list|query|create|update|rename|delete|sync [opts]\n", stderr)
        return 1
    }
}

// MARK: - Stack

private func runStack(_ args: [String]) -> Int32 {
    guard let sub = args.first else {
        fputs("Verwendung: iphoto-cli stack list|query [opts]\n", stderr)
        return 1
    }
    let jsonMode = args.contains("--json")
    let catalog  = CatalogStore(dbPath: envDBPath())
    let raw      = catalog.allImagesWithSeqNumbers()

    // Build StackDetector items and keep path mapping
    var idToPath: [UUID: String] = [:]
    let items: [StackDetector.Item] = raw.map { entry in
        let id = UUID()
        idToPath[id] = entry.path
        return StackDetector.Item(id: id, filename: entry.filename, seq: entry.seq)
    }
    let result = StackDetector.detect(items)

    switch sub {
    case "list":
        // Build stack groups: leader → member paths (leader first)
        var stacks: [[String: Any]] = []
        for (leaderID, memberIDs) in result.membersByLeader {
            guard let leaderPath = idToPath[leaderID] else { continue }
            let memberPaths = memberIDs.compactMap { idToPath[$0] }.sorted()
            stacks.append(["leader": leaderPath, "members": memberPaths, "count": memberIDs.count])
        }
        stacks.sort { ($0["leader"] as! String) < ($1["leader"] as! String) }
        if jsonMode {
            if let data = try? JSONSerialization.data(withJSONObject: stacks),
               let str = String(data: data, encoding: .utf8) { print(str) }
            else { print("[]") }
        } else {
            if stacks.isEmpty { print("Keine Serienbild-Stapel im Katalog.") }
            else {
                for s in stacks {
                    print("Stapel (\(s["count"]!) Bilder):")
                    print("  Leader: \(s["leader"]!)")
                    for m in (s["members"] as! [String]) { print("    \(m)") }
                }
            }
        }
        return 0

    case "query":
        guard let path = args.dropFirst().first(where: { !$0.hasPrefix("--") }) else {
            fputs("Verwendung: iphoto-cli stack query <bildpfad> [--json]\n", stderr)
            return 1
        }
        guard let myID = idToPath.first(where: { $0.value == path })?.key else {
            fputs("Fehler: Pfad nicht im Katalog oder keine Sequenznummer\n", stderr)
            return 1
        }
        guard let leaderID = result.leaderByMember[myID],
              let leaderPath = idToPath[leaderID],
              let memberIDs = result.membersByLeader[leaderID] else {
            if jsonMode { print("{\"stack\":null}") } else { print("Bild gehört zu keinem Stapel.") }
            return 0
        }
        let memberPaths = memberIDs.compactMap { idToPath[$0] }.sorted()
        if jsonMode {
            let obj: [String: Any] = ["leader": leaderPath, "members": memberPaths, "count": memberIDs.count]
            if let data = try? JSONSerialization.data(withJSONObject: obj),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            print("Stapel (\(memberIDs.count) Bilder), Leader: \(leaderPath)")
            for m in memberPaths { print("  \(m)") }
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli stack list|query [opts]\n", stderr)
        return 1
    }
}

// MARK: - Trash

private func runTrash(_ args: [String]) -> Int32 {
    guard let sub = args.first else {
        fputs("Verwendung: iphoto-cli trash list|mark|restore [opts]\n", stderr)
        return 1
    }
    let jsonMode = args.contains("--json")
    let catalog  = CatalogStore(dbPath: envDBPath())

    switch sub {
    case "list":
        let paths = Array(catalog.trashedPaths()).sorted()
        if jsonMode {
            if let data = try? JSONSerialization.data(withJSONObject: paths),
               let str = String(data: data, encoding: .utf8) { print(str) }
            else { print("[]") }
        } else {
            if paths.isEmpty { print("(Papierkorb leer)") }
            else { paths.forEach { print($0) } }
        }
        return 0

    case "mark":
        let paths = Array(args.dropFirst()).filter { !$0.hasPrefix("--") }
        guard !paths.isEmpty else {
            fputs("Verwendung: iphoto-cli trash mark <bildpfad> [...]\n", stderr)
            return 1
        }
        catalog.setTrashed(paths: paths, true)
        if jsonMode {
            let obj: [String: Any] = ["count": paths.count, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("\(paths.count) Bild(er) in den Papierkorb verschoben")
        }
        return 0

    case "restore":
        let subArgs = Array(args.dropFirst()).filter { !$0.hasPrefix("--") }
        if subArgs.first == "--all" || args.contains("--all") {
            let all = Array(catalog.trashedPaths())
            catalog.setTrashed(paths: all, false)
            if jsonMode {
                let obj: [String: Any] = ["count": all.count, "ok": true]
                if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                   let s = String(data: d, encoding: .utf8) { print(s) }
            } else {
                print("\(all.count) Bild(er) aus dem Papierkorb wiederhergestellt")
            }
        } else {
            guard !subArgs.isEmpty else {
                fputs("Verwendung: iphoto-cli trash restore <bildpfad>|--all\n", stderr)
                return 1
            }
            catalog.setTrashed(paths: subArgs, false)
            if jsonMode {
                let obj: [String: Any] = ["count": subArgs.count, "ok": true]
                if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                   let s = String(data: d, encoding: .utf8) { print(s) }
            } else {
                print("\(subArgs.count) Bild(er) wiederhergestellt")
            }
        }
        return 0

    case "empty":
        let count = catalog.emptyTrash()
        if jsonMode {
            let obj: [String: Any] = ["count": count, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Papierkorb geleert: \(count) Einträge entfernt")
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli trash list|mark|restore|empty [opts]\n", stderr)
        return 1
    }
}

// MARK: - AlbumFolder

private func albumFoldersFileURL() -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("iPhoto")
        .appendingPathComponent("albumFolders.json")
}

private func loadAlbumFoldersList() -> [AlbumFolder] {
    guard let data = try? Data(contentsOf: albumFoldersFileURL()) else { return [] }
    return (try? JSONDecoder().decode([AlbumFolder].self, from: data)) ?? []
}

private func saveAlbumFoldersList(_ folders: [AlbumFolder]) {
    let url = albumFoldersFileURL()
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    if let data = try? JSONEncoder().encode(folders) { try? data.write(to: url) }
}

private func runAlbumFolder(_ args: [String]) -> Int32 {
    let sub = args.first ?? "list"
    let jsonMode = args.contains("--json")

    switch sub {
    case "list":
        let folders = loadAlbumFoldersList()
        if jsonMode {
            let arr: [[String: Any]] = folders.map { f in
                var d: [String: Any] = ["id": f.id.uuidString, "name": f.name]
                if let p = f.parentID { d["parent_id"] = p.uuidString }
                return d
            }
            if let data = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
               let s = String(data: data, encoding: .utf8) { print(s) }
        } else {
            if folders.isEmpty { print("Keine Album-Ordner vorhanden.") }
            for f in folders {
                let parent = f.parentID.map { " (in: \($0.uuidString.prefix(8))…)" } ?? ""
                print("[\(f.id.uuidString.prefix(8))…]  \(f.name)\(parent)")
            }
        }
        return 0

    case "create":
        let positionals = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard let name = positionals.first else {
            fputs("Verwendung: iphoto-cli albumfolder create <name> [--parent <id>] [--json]\n", stderr); return 1
        }
        var parentID: UUID? = nil
        if let pIdx = args.firstIndex(of: "--parent"), pIdx + 1 < args.count {
            parentID = UUID(uuidString: args[pIdx + 1])
        }
        let newFolder = AlbumFolder(name: name, parentID: parentID)
        var folders = loadAlbumFoldersList()
        folders.append(newFolder)
        saveAlbumFoldersList(folders)
        if jsonMode {
            let obj: [String: Any] = ["id": newFolder.id.uuidString, "name": newFolder.name, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Ordner erstellt: \(newFolder.name) (\(newFolder.id.uuidString))")
        }
        return 0

    case "rename":
        let positionals = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard positionals.count >= 2 else {
            fputs("Verwendung: iphoto-cli albumfolder rename <id|name> <neuer-name> [--json]\n", stderr); return 1
        }
        let query = positionals[0]; let newName = positionals[1]
        var folders = loadAlbumFoldersList()
        guard let idx = folders.firstIndex(where: {
            $0.id.uuidString.lowercased() == query.lowercased() ||
            $0.name.lowercased() == query.lowercased()
        }) else {
            fputs("Fehler: Album-Ordner '\(query)' nicht gefunden\n", stderr); return 1
        }
        let oldName = folders[idx].name
        folders[idx].name = newName
        saveAlbumFoldersList(folders)
        if jsonMode {
            let obj: [String: Any] = ["id": folders[idx].id.uuidString, "name": newName, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Ordner umbenannt: \(oldName) → \(newName)")
        }
        return 0

    case "delete":
        let positionals = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard let query = positionals.first else {
            fputs("Verwendung: iphoto-cli albumfolder delete <id|name> [--json]\n", stderr); return 1
        }
        var folders = loadAlbumFoldersList()
        guard let idx = folders.firstIndex(where: {
            $0.id.uuidString.lowercased() == query.lowercased() ||
            $0.name.lowercased() == query.lowercased()
        }) else {
            fputs("Fehler: Album-Ordner '\(query)' nicht gefunden\n", stderr); return 1
        }
        let removed = folders.remove(at: idx)
        // Promote children to parent (match app behaviour)
        let newParent = removed.parentID
        for i in folders.indices where folders[i].parentID == removed.id {
            folders[i].parentID = newParent
        }
        saveAlbumFoldersList(folders)
        // Also promote albums
        let albumsURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto/albums.json")
        if let data = try? Data(contentsOf: albumsURL),
           var albums = try? JSONDecoder().decode([Album].self, from: data) {
            for i in albums.indices where albums[i].parentID == removed.id {
                albums[i].parentID = newParent
            }
            if let out = try? JSONEncoder().encode(albums) { try? out.write(to: albumsURL) }
        }
        if jsonMode {
            let obj: [String: Any] = ["id": removed.id.uuidString, "name": removed.name, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Ordner gelöscht: \(removed.name)")
        }
        return 0

    default:
        fputs("Fehler: Unbekannter albumfolder-Unterbefehl '\(sub)'. Erlaubt: list, create, rename, delete\n", stderr)
        return 1
    }
}

// MARK: - Album

private func runAlbum(_ args: [String]) -> Int32 {
    let sub = args.first ?? ""
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    switch sub {
    case "list":
        let albums = catalog.allAlbums()
        if jsonMode {
            let arr = albums.map { ["id": $0.id, "name": $0.name] }
            if let d = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if albums.isEmpty { print("(keine Alben)") }
            else { albums.forEach { print("\($0.id)  \($0.name)") } }
        }
        return 0

    case "create":
        guard let name = args.dropFirst().first(where: { !$0.hasPrefix("-") }), !name.isEmpty else {
            fputs("Verwendung: iphoto-cli album create <name>\n", stderr); return 1
        }
        let id = UUID().uuidString
        catalog.saveAlbum(id: id, name: name)
        if jsonMode {
            if let d = try? JSONSerialization.data(withJSONObject: ["id": id, "name": name]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Album erstellt: \(id)  \(name)")
        }
        return 0

    case "delete":
        guard let id = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli album delete <id>\n", stderr); return 1
        }
        catalog.deleteAlbum(id: id)
        if jsonMode {
            let obj: [String: Any] = ["id": id, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: []),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Album gelöscht: \(id)")
        }
        return 0

    case "add":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard positional.count >= 2 else {
            fputs("Verwendung: iphoto-cli album add <album-id> <bild1> [<bild2>...]\n", stderr); return 1
        }
        let albumID = positional[0]
        let paths = Array(positional.dropFirst())
        for (i, p) in paths.enumerated() { catalog.addImage(path: p, toAlbum: albumID, order: i) }
        if jsonMode {
            let obj: [String: Any] = ["album_id": albumID, "count": paths.count, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("\(paths.count) Bild(er) zu Album \(albumID) hinzugefügt")
        }
        return 0

    case "remove":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard positional.count >= 2 else {
            fputs("Verwendung: iphoto-cli album remove <album-id> <bild1> [<bild2>...]\n", stderr); return 1
        }
        let albumID = positional[0]
        let paths = Array(positional.dropFirst())
        for p in paths { catalog.removeImage(path: p, fromAlbum: albumID) }
        if jsonMode {
            let obj: [String: Any] = ["album_id": albumID, "count": paths.count, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("\(paths.count) Bild(er) aus Album \(albumID) entfernt")
        }
        return 0

    case "images":
        guard let id = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli album images <album-id> [--json]\n", stderr); return 1
        }
        let paths = catalog.images(inAlbum: id)
        if jsonMode {
            if let d = try? JSONSerialization.data(withJSONObject: paths, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if paths.isEmpty { print("(leer)") }
            else { paths.forEach { print($0) } }
        }
        return 0

    case "reorder":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard positional.count >= 2 else {
            fputs("Verwendung: iphoto-cli album reorder <album-id> <bild1> [<bild2>...]\n", stderr); return 1
        }
        let albumID = positional[0]
        let paths = Array(positional.dropFirst())
        for (i, p) in paths.enumerated() { catalog.setSortOrder(albumID: albumID, path: p, order: i) }
        if jsonMode {
            let obj: [String: Any] = ["album_id": albumID, "count": paths.count, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("\(paths.count) Bild(er) in Album \(albumID) neu sortiert")
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli album list|create|delete|add|remove|images|reorder\n", stderr)
        return 1
    }
}

// MARK: - Quality

private func runQuality(_ args: [String]) -> Int32 {
    let sub = args.first ?? ""
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    switch sub {
    case "scan":
        let imageExts: Set<String> = ["jpg","jpeg","png","tiff","tif","heic","heif","gif","bmp","webp",
                                       "cr2","cr3","nef","arw","dng","orf","rw2","nrw","raf","pef",
                                       "srw","erf","kdc","dcr","raw","rwl","mrw","3fr","mef","iiq","x3f"]
        let rawPaths = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard !rawPaths.isEmpty else {
            fputs("Verwendung: iphoto-cli quality scan <bild-oder-ordner> [...]\n", stderr); return 1
        }
        var expandedPaths: [String] = []
        for p in rawPaths {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: p, isDirectory: &isDir) {
                if isDir.boolValue {
                    let urls = (try? FileManager.default.contentsOfDirectory(
                        at: URL(fileURLWithPath: p), includingPropertiesForKeys: nil
                    ))?.filter { imageExts.contains($0.pathExtension.lowercased()) }
                      .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
                    expandedPaths.append(contentsOf: urls.map { $0.path })
                } else {
                    expandedPaths.append(p)
                }
            } else {
                fputs("Fehler: Pfad nicht gefunden: \(p)\n", stderr)
            }
        }
        guard !expandedPaths.isEmpty else { return 1 }
        let paths = expandedPaths
        var results: [[String: Any]] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard let r = QualityAssessor.assess(url: url) else {
                fputs("Warnung: Konnte \(path) nicht laden\n", stderr); continue
            }
            catalog.upsertImage(path: path, filename: url.lastPathComponent, isRAW: false)
            catalog.upsertQuality(path: path, blurScore: r.blurScore,
                                  underRatio: r.underRatio, overRatio: r.overRatio,
                                  phash: r.phash, phashV: r.phashV, eyeOpenness: r.eyeOpenness)
            results.append(["path": path, "blur": r.blurScore,
                            "under": r.underRatio, "over": r.overRatio])
        }
        if jsonMode {
            if let d = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            for r in results {
                print(String(format: "blur=%.1f  under=%.2f  over=%.2f  %@",
                             r["blur"] as! Double, r["under"] as! Double,
                             r["over"] as! Double, r["path"] as! String))
            }
            print("Gesamt: \(results.count) Bild(er) analysiert")
        }
        return 0

    case "list":
        let all = catalog.allQualityRecords()
        let sortKey: String
        if let si = args.firstIndex(of: "--sort"), si + 1 < args.count {
            sortKey = args[si + 1].lowercased()
        } else { sortKey = "path" }
        let sorted: [(key: String, value: QualityRecord)]
        switch sortKey {
        case "blur":    sorted = all.sorted { ($0.value.blurScore ?? 0) > ($1.value.blurScore ?? 0) }
        case "rating":  let ratings = catalog.allRatings()
                        sorted = all.sorted { (ratings[$0.key]?.rating ?? 0) > (ratings[$1.key]?.rating ?? 0) }
        case "elo":     let elos = catalog.allElos()
                        sorted = all.sorted { (elos[$0.key]?.elo ?? 0) > (elos[$1.key]?.elo ?? 0) }
        default:        sorted = all.sorted { $0.key < $1.key }
        }
        if jsonMode {
            let arr = sorted.map { (path, q) -> [String: Any] in
                var d: [String: Any] = ["path": path, "blur": q.blurScore ?? 0,
                                        "under": q.underRatio ?? 0, "over": q.overRatio ?? 0]
                if let e = q.eyeOpenness { d["eye_openness"] = e }
                return d
            }
            if let d = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if sorted.isEmpty { print("(keine Quality-Daten)") }
            for (path, q) in sorted {
                print(String(format: "blur=%.1f  under=%.2f  over=%.2f  %@",
                             q.blurScore ?? 0, q.underRatio ?? 0, q.overRatio ?? 0, path))
            }
        }
        return 0

    case "get":
        guard let path = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli quality get <bildpfad> [--json]\n", stderr); return 1
        }
        guard let q = catalog.quality(forPath: path) else {
            fputs("Keine Quality-Daten für \(path)\n", stderr); return 1
        }
        if jsonMode {
            var d: [String: Any] = ["path": path, "blur": q.blurScore ?? 0,
                                    "under": q.underRatio ?? 0, "over": q.overRatio ?? 0]
            if let e = q.eyeOpenness { d["eye_openness"] = e }
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            print(String(format: "blur=%.1f  under=%.2f  over=%.2f  %@",
                         q.blurScore ?? 0, q.underRatio ?? 0, q.overRatio ?? 0, path))
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli quality scan|list|get\n", stderr)
        return 1
    }
}

// MARK: - Version

private func runVersion(_ args: [String]) -> Int32 {
    let sub = args.first ?? ""
    let jsonMode = args.contains("--json")
    let store = VersionStore.shared

    switch sub {
    case "list":
        guard let path = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli version list <bildpfad> [--json]\n", stderr); return 1
        }
        let url = URL(fileURLWithPath: path)
        let versions = store.loadVersions(for: url)
        if jsonMode {
            let isoFormatter = ISO8601DateFormatter()
            let arr = versions.map { v -> [String: Any] in
                var d: [String: Any] = ["id": v.id.uuidString,
                                        "date": isoFormatter.string(from: v.date),
                                        "ext": v.ext]
                if let lbl = v.label { d["label"] = lbl }
                return d
            }
            if let d = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if versions.isEmpty { print("(keine Versionen)") }
            for v in versions {
                let lbl = v.label.map { "  [\($0)]" } ?? ""
                print("\(v.id.uuidString)  \(v.date)\(lbl)")
            }
        }
        return 0

    case "backup":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard let path = positional.first else {
            fputs("Verwendung: iphoto-cli version backup <bildpfad> [--label <text>]\n", stderr); return 1
        }
        var label: String? = nil
        if let li = args.firstIndex(of: "--label"), li + 1 < args.count {
            label = args[li + 1]
        }
        let url = URL(fileURLWithPath: path)
        do {
            let meta = try store.backupFile(at: url, label: label)
            if jsonMode {
                var obj: [String: Any] = ["id": meta.id.uuidString, "path": path, "ext": meta.ext]
                if let lbl = meta.label { obj["label"] = lbl }
                if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                   let s = String(data: d, encoding: .utf8) { print(s) }
            } else {
                print("Version gesichert: \(meta.id.uuidString)")
            }
        } catch {
            fputs("Fehler beim Backup: \(error)\n", stderr); return 1
        }
        return 0

    case "restore":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard positional.count >= 2 else {
            fputs("Verwendung: iphoto-cli version restore <bildpfad> <version-id>\n", stderr); return 1
        }
        let path = positional[0]
        let versionIDStr = positional[1]
        let url = URL(fileURLWithPath: path)
        let versions = store.loadVersions(for: url)
        guard let meta = versions.first(where: { $0.id.uuidString == versionIDStr }) else {
            fputs("Version nicht gefunden: \(versionIDStr)\n", stderr); return 1
        }
        do {
            try store.restoreVersion(meta, to: url)
            if jsonMode {
                let obj: [String: Any] = ["id": versionIDStr, "path": path, "ok": true]
                if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                   let s = String(data: d, encoding: .utf8) { print(s) }
            } else {
                print("Version \(versionIDStr) wiederhergestellt: \(path)")
            }
        } catch {
            fputs("Fehler bei Wiederherstellung: \(error)\n", stderr); return 1
        }
        return 0

    case "delete":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard positional.count >= 2 else {
            fputs("Verwendung: iphoto-cli version delete <bildpfad> <version-id>\n", stderr); return 1
        }
        let path = positional[0]
        let versionIDStr = positional[1]
        let url = URL(fileURLWithPath: path)
        let versions = store.loadVersions(for: url)
        guard let meta = versions.first(where: { $0.id.uuidString == versionIDStr }) else {
            fputs("Version nicht gefunden: \(versionIDStr)\n", stderr); return 1
        }
        store.deleteVersion(meta, for: url)
        if jsonMode {
            let obj: [String: Any] = ["id": versionIDStr, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Version \(versionIDStr) gelöscht")
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli version list|backup|restore|delete\n", stderr)
        return 1
    }
}

// MARK: - Search

private func runSearch(_ args: [String]) -> Int32 {
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    // --flag pick|reject|none
    if let fi = args.firstIndex(of: "--flag"), fi + 1 < args.count {
        let flag = args[fi + 1].lowercased()
        guard FlagStatus(rawValue: flag) != nil else {
            fputs("Fehler: Ungültiger Flag-Wert '\(args[fi + 1])'. Erlaubt: none, pick, reject\n", stderr)
            return 1
        }
        let images = catalog.images(flaggedAs: flag)
        return printCatalogImages(images, jsonMode: jsonMode)
    }

    // --rating N
    if let ri = args.firstIndex(of: "--rating"), ri + 1 < args.count,
       let n = Int(args[ri + 1]) {
        guard n >= 0 && n <= 5 else {
            fputs("Fehler: Bewertung muss zwischen 0 und 5 liegen (angegeben: \(n))\n", stderr)
            return 1
        }
        let images = catalog.images(ratedAtLeast: n)
        return printCatalogImages(images, jsonMode: jsonMode)
    }

    // --color red|yellow|green|blue|none
    if let ci = args.firstIndex(of: "--color"), ci + 1 < args.count {
        let color = args[ci + 1].lowercased()
        guard ColorLabel(rawValue: color) != nil else {
            fputs("Fehler: Ungültige Farbe '\(args[ci + 1])'. Erlaubt: none, red, yellow, green, blue\n", stderr)
            return 1
        }
        let images = catalog.images(withColorLabel: color)
        return printCatalogImages(images, jsonMode: jsonMode)
    }

    // --camera <model|make>
    if let ci = args.firstIndex(of: "--camera"), ci + 1 < args.count {
        let camera = args[ci + 1]
        let images = catalog.images(withCamera: camera)
        return printCatalogImages(images, jsonMode: jsonMode)
    }

    // --date YYYY-MM-DD (Präfix-Match auf date_taken)
    if let di = args.firstIndex(of: "--date"), di + 1 < args.count {
        let datePrefix = args[di + 1]
        let images = catalog.images(onDate: datePrefix)
        return printCatalogImages(images, jsonMode: jsonMode)
    }

    // Freitext-Suche
    let query = args.filter { !$0.hasPrefix("-") }.joined(separator: " ")
    guard !query.isEmpty else {
        fputs("Verwendung: iphoto-cli search <text> [--json]\n" +
              "           iphoto-cli search --flag pick|reject|none [--json]\n" +
              "           iphoto-cli search --rating <1-5> [--json]\n" +
              "           iphoto-cli search --color <farbe> [--json]\n" +
              "           iphoto-cli search --camera <modell> [--json]\n" +
              "           iphoto-cli search --date YYYY-MM-DD [--json]\n", stderr)
        return 1
    }
    let images = catalog.search(query: query)
    return printCatalogImages(images, jsonMode: jsonMode)
}

private func printCatalogImages(_ images: [CatalogImage], jsonMode: Bool) -> Int32 {
    if jsonMode {
        let arr = images.map { img -> [String: Any] in
            var d: [String: Any] = ["path": img.path, "filename": img.filename,
                                    "width": img.width, "height": img.height]
            if let dt = img.dateTaken { d["date_taken"] = dt }
            if let cm = img.cameraModel { d["camera"] = cm }
            return d
        }
        if let d = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
           let s = String(data: d, encoding: .utf8) { print(s) }
    } else {
        if images.isEmpty { print("(keine Ergebnisse)") }
        else { images.forEach { print($0.path) } }
        print("Gesamt: \(images.count) Bild(er)")
    }
    return 0
}

// MARK: - Catalog

private func runCatalog(_ args: [String]) -> Int32 {
    let sub = args.first ?? "stats"
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    switch sub {
    case "stats":
        let dbPath = envDBPath() ?? "(Standard: ~/Library/Application Support/iPhoto/catalog.db)"
        let imageCount  = catalog.allImages().count
        let albumCount  = catalog.allAlbums().count
        let faceCount   = catalog.allFaces().count
        let peopleCount = catalog.allPeople().count
        let rs = catalog.ratingStats()
        let eloCount = catalog.eloCount()

        if jsonMode {
            let d: [String: Any] = ["db_path": dbPath, "images": imageCount,
                                    "albums": albumCount, "faces": faceCount,
                                    "people": peopleCount,
                                    "rated": rs.rated, "flagged": rs.flagged,
                                    "by_flag": rs.byFlag, "by_color": rs.byColor,
                                    "elo_count": eloCount]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            print("Katalog:   \(dbPath)")
            print("Bilder:    \(imageCount)")
            print("Alben:     \(albumCount)")
            print("Gesichter: \(faceCount)")
            print("Personen:  \(peopleCount)")
            print("Bewertet:  \(rs.rated)")
            print("Markiert:  \(rs.flagged)")
            print("ELO:       \(eloCount)")
            if !rs.byFlag.isEmpty {
                rs.byFlag.sorted { $0.key < $1.key }.forEach { print("  Flagge \($0.key): \($0.value)") }
            }
            if !rs.byColor.isEmpty {
                rs.byColor.sorted { $0.key < $1.key }.forEach { print("  Farbe \($0.key): \($0.value)") }
            }
        }
        return 0

    case "path":
        let dbPath = envDBPath() ?? "(Standard: ~/Library/Application Support/iPhoto/catalog.db)"
        print(dbPath)
        return 0

    case "vacuum":
        let dbPathVac = envDBPath() ?? ""
        let sizeBefore = (try? FileManager.default.attributesOfItem(atPath: dbPathVac))?[.size] as? Int ?? 0
        catalog.vacuum()
        let sizeAfter = (try? FileManager.default.attributesOfItem(atPath: dbPathVac))?[.size] as? Int ?? 0
        if jsonMode {
            let obj: [String: Any] = ["path": dbPathVac, "size_before": sizeBefore,
                                      "size_after": sizeAfter, "saved": sizeBefore - sizeAfter, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            let saved = sizeBefore - sizeAfter
            print("Katalog optimiert: \(dbPathVac)")
            if sizeBefore > 0 { print("Größe: \(sizeAfter) B (gespart: \(saved) B)") }
        }
        return 0

    case "export":
        guard let outIdx = args.firstIndex(of: "--output"), outIdx + 1 < args.count else {
            fputs("Verwendung: iphoto-cli catalog export --output <ziel.db>\n", stderr); return 1
        }
        let dest = args[outIdx + 1]
        guard catalog.exportTo(path: dest) else {
            fputs("Fehler: Katalog-Export fehlgeschlagen → \(dest)\n", stderr); return 1
        }
        if jsonMode {
            let obj: [String: Any] = ["output": dest, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Katalog exportiert: \(dest)")
        }
        return 0

    case "scan-needed":
        let exif    = catalog.pathsNeedingExifScan()
        let quality = catalog.pathsNeedingQualityScan()
        let motif   = catalog.pathsNeedingMotifScan()
        let face    = catalog.pathsNeedingFaceScan()
        if jsonMode {
            let obj: [String: Any] = [
                "exif": exif, "quality": quality, "motif": motif, "face": face,
                "total_exif": exif.count, "total_quality": quality.count,
                "total_motif": motif.count, "total_face": face.count
            ]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Ausstehende Scans:")
            print("  EXIF:     \(exif.count)")
            print("  Qualität: \(quality.count)")
            print("  Motiv:    \(motif.count)")
            print("  Gesicht:  \(face.count)")
            let total = exif.count + quality.count + motif.count + face.count
            print("Gesamt: \(total) Scan-Aufgaben")
        }
        return 0

    case "backup-now":
        if let path = catalog.backupNow() {
            if jsonMode {
                let obj: [String: Any] = ["backup": path, "ok": true]
                if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                   let s = String(data: d, encoding: .utf8) { print(s) }
            } else {
                print("Backup erstellt: \(path)")
            }
            return 0
        } else {
            fputs("Fehler: Backup fehlgeschlagen\n", stderr)
            return 1
        }

    default:
        fputs("Verwendung: iphoto-cli catalog stats|path|vacuum|export|scan-needed|backup-now [--json]\n", stderr)
        return 1
    }
}

// MARK: - Elo

private func runElo(_ args: [String]) -> Int32 {
    let sub = args.first ?? "list"
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    switch sub {
    case "get":
        guard let path = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli elo get <bildpfad> [--json]\n", stderr); return 1
        }
        if let e = catalog.elo(forPath: path) {
            if jsonMode {
                let d: [String: Any] = ["path": path, "elo": e.elo, "matches": e.matches]
                if let dd = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
                   let s = String(data: dd, encoding: .utf8) { print(s) }
            } else {
                print("ELO: \(String(format: "%.1f", e.elo))  Duelle: \(e.matches)")
            }
        } else {
            if jsonMode { print("{\"path\":\"\(path)\",\"elo\":null}") }
            else { print("Kein ELO-Eintrag für diesen Pfad.") }
        }
        return 0

    case "list":
        let all = catalog.allElos()
        let sorted = all.sorted { $0.value.elo > $1.value.elo }
        if jsonMode {
            let arr = sorted.map { ["path": $0.key, "elo": $0.value.elo, "matches": $0.value.matches] as [String: Any] }
            if let d = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if sorted.isEmpty { print("(keine ELO-Einträge im Katalog)") }
            else {
                print("ELO     Duelle  Pfad")
                print(String(repeating: "─", count: 60))
                for (path, e) in sorted {
                    print(String(format: "%-6.1f  %-6d  %@", e.elo, e.matches, path))
                }
            }
        }
        return 0

    case "set":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard positional.count >= 2, let elo = Double(positional[1]) else {
            fputs("Verwendung: iphoto-cli elo set <bildpfad> <elo-wert> [--matches N]\n", stderr); return 1
        }
        guard elo >= 0 && elo <= 9999 else {
            fputs("Fehler: ELO-Wert muss zwischen 0 und 9999 liegen (angegeben: \(positional[1]))\n", stderr); return 1
        }
        let path = positional[0]
        var matches = catalog.elo(forPath: path)?.matches ?? 0
        if let mi = args.firstIndex(of: "--matches"), mi + 1 < args.count {
            guard let m = Int(args[mi + 1]), m >= 0 else {
                fputs("Fehler: --matches muss eine nicht-negative ganze Zahl sein\n", stderr); return 1
            }
            matches = m
        }
        catalog.saveElo(path: path, elo: elo, eloMatches: matches)
        if jsonMode {
            let d: [String: Any] = ["path": path, "elo": elo, "matches": matches, "ok": true]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: []),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            print("ELO gesetzt: \(String(format: "%.1f", elo)) (\(matches) Duelle) → \(path)")
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli elo get|list|set [opts]\n", stderr)
        return 1
    }
}

// MARK: - Rating Batch-Set

private func runRatingBatchSet(_ args: [String]) -> Int32 {
    let jsonMode = args.contains("--json")
    var ratingValue: Int? = nil
    var flagValue = "none"
    var colorValue = "none"
    var paths: [String] = []
    var i = 0
    while i < args.count {
        switch args[i] {
        case "--set":
            if i + 1 < args.count, let n = Int(args[i + 1]) { ratingValue = n; i += 2 }
            else { fputs("Fehler: --set braucht eine Zahl\n", stderr); return 1 }
        case "--flag":
            if i + 1 < args.count { flagValue = args[i + 1].lowercased(); i += 2 }
            else { fputs("Fehler: --flag braucht einen Wert\n", stderr); return 1 }
        case "--color":
            if i + 1 < args.count { colorValue = args[i + 1].lowercased(); i += 2 }
            else { fputs("Fehler: --color braucht einen Wert\n", stderr); return 1 }
        case "--json": i += 1
        default:
            if !args[i].hasPrefix("-") { paths.append(args[i]) }
            i += 1
        }
    }
    guard !paths.isEmpty else {
        fputs("Verwendung: iphoto-cli rating batch-set <bild1> [<bild2>...] [--set N] [--flag X] [--color X] [--json]\n", stderr)
        return 1
    }
    if let r = ratingValue, r < 0 || r > 5 {
        fputs("Fehler: --set muss zwischen 0 und 5 liegen (angegeben: \(r))\n", stderr); return 1
    }
    if flagValue != "none", FlagStatus(rawValue: flagValue) == nil {
        fputs("Fehler: Ungültiger Flag-Wert '\(flagValue)'. Erlaubt: none, pick, reject\n", stderr); return 1
    }
    if colorValue != "none", ColorLabel(rawValue: colorValue) == nil {
        fputs("Fehler: Ungültige Farbe '\(colorValue)'. Erlaubt: none, red, yellow, green, blue\n", stderr); return 1
    }
    let catalog = CatalogStore(dbPath: envDBPath())
    var results: [[String: Any]] = []
    for path in paths {
        let existing = catalog.rating(forPath: path)
        let r = ratingValue ?? (existing?.rating ?? 0)
        let f = flagValue != "none" ? flagValue : (existing?.flag ?? "none")
        let c = colorValue != "none" ? colorValue : (existing?.colorLabel ?? "none")
        catalog.saveRating(path: path, rating: r, flag: f, colorLabel: c)
        results.append(["path": path, "rating": r, "flag": f, "color": c])
    }
    if jsonMode {
        let obj: [String: Any] = ["count": paths.count, "results": results, "ok": true]
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
           let s = String(data: d, encoding: .utf8) { print(s) }
    } else {
        print("\(paths.count) Bild(er) bewertet")
    }
    return 0
}

// MARK: - Adjustments CLI

private func runAdjustments(_ args: [String]) -> Int32 {
    let sub = args.first ?? "list"
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    switch sub {
    case "list":
        let paths = catalog.allModifiedPaths().sorted()
        if jsonMode {
            if let d = try? JSONSerialization.data(withJSONObject: paths, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if paths.isEmpty { print("(keine gespeicherten Anpassungen)") }
            else {
                for p in paths { print(p) }
                print("Gesamt: \(paths.count) Bild(er) mit Anpassungen")
            }
        }
        return 0

    case "get":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard let path = positional.first else {
            fputs("Verwendung: iphoto-cli adjustments get <bildpfad> [--json]\n", stderr); return 1
        }
        guard let adj = catalog.loadAdjustments(path: path) else {
            if jsonMode { print("{}") } else { print("Keine Anpassungen für: \(path)") }
            return 0
        }
        if jsonMode {
            let d: [String: Any] = [
                "path": path,
                "exposure": adj.exposure, "brightness": adj.brightness,
                "contrast": adj.contrast, "saturation": adj.saturation,
                "vibrance": adj.vibrance, "hue": adj.hue,
                "warmth": adj.warmth, "tint": adj.tint,
                "clarity": adj.clarity, "texture": adj.texture, "dehaze": adj.dehaze,
                "sharpen_amount": adj.sharpenAmount, "sharpen_radius": adj.sharpenRadius,
                "luma_noise": adj.lumaNoise, "color_noise": adj.colorNoise,
                "rotation": adj.rotation, "turns": adj.turns,
                "vignette_amount": adj.vignetteAmount, "distortion": adj.distortion
            ]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            print("Anpassungen für: \(path)")
            print("  Belichtung:  \(adj.exposure)")
            print("  Helligkeit:  \(adj.brightness)")
            print("  Kontrast:    \(adj.contrast)")
            print("  Sättigung:   \(adj.saturation)")
            print("  Vibrance:    \(adj.vibrance)")
            print("  Rotation:    \(adj.rotation)°  Drehungen: \(adj.turns)")
        }
        return 0

    case "delete":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard let path = positional.first else {
            fputs("Verwendung: iphoto-cli adjustments delete <bildpfad> [--json]\n", stderr); return 1
        }
        catalog.deleteAdjustments(path: path)
        if jsonMode {
            let d: [String: Any] = ["path": path, "ok": true]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: []),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            print("Anpassungen gelöscht: \(path)")
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli adjustments list|get|delete [opts]\n", stderr)
        return 1
    }
}

// MARK: - Motif

private func runMotif(_ args: [String]) -> Int32 {
    let sub = args.first ?? ""
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    switch sub {
    case "get":
        guard let path = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli motif get <bildpfad> [--json]\n", stderr); return 1
        }
        let tags = catalog.motifs(forPath: path) ?? []
        if jsonMode {
            let d: [String: Any] = ["path": path, "motifs": tags]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            if tags.isEmpty { print("(keine Motiv-Tags)") }
            else { print(tags.joined(separator: ", ")) }
        }
        return 0

    case "list":
        let all = catalog.allMotifs()
        if jsonMode {
            let arr = all.map { ["path": $0.path, "motifs": $0.tags] as [String: Any] }
            if let d = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if all.isEmpty { print("(keine Motiv-Tags im Katalog)") }
            else { all.forEach { print("\($0.path)  \($0.tags.joined(separator: ","))") } }
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli motif get|list [--json]\n", stderr)
        return 1
    }
}

// MARK: - Duplicate

private func runDuplicate(_ args: [String]) -> Int32 {
    let sub = args.first ?? "list"
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    switch sub {
    case "list":
        let groups = catalog.loadDuplicateGroups()
        if jsonMode {
            if let d = try? JSONSerialization.data(withJSONObject: groups, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if groups.isEmpty { print("(keine Duplikate)") }
            for (i, g) in groups.enumerated() {
                print("Gruppe \(i+1):")
                g.forEach { print("  \($0)") }
            }
        }
        return 0

    case "similar":
        let groups = catalog.loadSimilarGroups()
        if jsonMode {
            if let d = try? JSONSerialization.data(withJSONObject: groups, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if groups.isEmpty { print("(keine ähnlichen Bilder)") }
            for (i, g) in groups.enumerated() {
                print("Gruppe \(i+1):")
                g.forEach { print("  \($0)") }
            }
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli duplicate list|similar [--json]\n", stderr)
        return 1
    }
}

// MARK: - Config

private func runConfig(_ args: [String]) -> Int32 {
    let sub = args.first ?? ""
    switch sub {
    case "show":
        let settings = AppConfig.currentSettings()
        if settings.isEmpty {
            print("{}")
            return 0
        }
        if let data = try? JSONSerialization.data(withJSONObject: settings,
                                                   options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
        return 0

    case "export":
        let pathIdx = args.firstIndex(of: "--path").map { $0 + 1 }
        let url = pathIdx.flatMap { $0 < args.count ? URL(fileURLWithPath: args[$0]) : nil }
        do {
            let target = try AppConfig.exportToFile(url)
            print("Einstellungen exportiert nach: \(target.path)")
            return 0
        } catch {
            fputs("Fehler beim Exportieren: \(error.localizedDescription)\n", stderr)
            return 1
        }

    case "import":
        guard let p = args.dropFirst().first else {
            fputs("config import: Pfad fehlt\n", stderr)
            return 1
        }
        do {
            try AppConfig.importFromFile(URL(fileURLWithPath: p))
            print("Einstellungen importiert aus: \(p)")
            return 0
        } catch {
            fputs("Fehler beim Importieren: \(error.localizedDescription)\n", stderr)
            return 1
        }

    case "get":
        guard let key = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli config get <schlüssel>\n", stderr); return 1
        }
        guard AppConfig.knownKeys.contains(key) else {
            fputs("Fehler: Unbekannter Schlüssel '\(key)'\nBekannte Schlüssel: \(AppConfig.knownKeys.joined(separator: ", "))\n", stderr); return 1
        }
        if let v = AppConfig.defaults.object(forKey: key) {
            print("\(v)")
        } else {
            print("(nicht gesetzt)")
        }
        return 0

    case "set":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard positional.count >= 2 else {
            fputs("Verwendung: iphoto-cli config set <schlüssel> <wert>\n", stderr); return 1
        }
        let key = positional[0], rawValue = positional[1]
        guard AppConfig.knownKeys.contains(key) else {
            fputs("Fehler: Unbekannter Schlüssel '\(key)'\nBekannte Schlüssel: \(AppConfig.knownKeys.joined(separator: ", "))\n", stderr); return 1
        }
        if rawValue.lowercased() == "true" {
            AppConfig.defaults.set(true, forKey: key)
        } else if rawValue.lowercased() == "false" {
            AppConfig.defaults.set(false, forKey: key)
        } else if let n = Int(rawValue) {
            AppConfig.defaults.set(n, forKey: key)
        } else {
            AppConfig.defaults.set(rawValue, forKey: key)
        }
        AppConfig.defaults.synchronize()
        print("Gesetzt: \(key) = \(rawValue)")
        return 0

    default:
        fputs("Verwendung: iphoto-cli config show|get <key>|set <key> <wert>|export [--path <pfad>]|import <pfad>\n", stderr)
        return 1
    }
}

// MARK: - Metadata

private func runMetadata(_ args: [String]) -> Int32 {
    let sub = args.first ?? ""
    let jsonMode = args.contains("--json")
    let svc = MetadataService()

    switch sub {
    case "get":
        guard let path = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli metadata get <bildpfad> [--json]\n", stderr); return 1
        }
        let url = URL(fileURLWithPath: path)
        let entries = svc.readPhotoMetadata(from: url)
        let editable = entries.filter { $0.isEditable }
        if jsonMode {
            var dict: [String: String] = [:]
            for e in editable { dict[e.key] = e.value }
            if let d = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if editable.isEmpty { print("(keine editierbaren Felder)") }
            for e in editable { print("\(e.displayName): \(e.value)") }
        }
        return 0

    case "set":
        guard let path = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli metadata set <bildpfad> [--title X] [--caption X] [--keywords X] [--copyright X] [--creator X] [--date X] [--lat N] [--lon N]\n", stderr); return 1
        }
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        guard ["jpg","jpeg","png","tiff","tif"].contains(ext) else {
            fputs("Fehler: metadata set unterstützt nur JPEG/PNG/TIFF-Dateien (nicht '\(ext)')\n", stderr); return 1
        }
        var entries = svc.defaultEntries()
        func setEntry(key: String, value: String) {
            if let i = entries.firstIndex(where: { $0.key == key }) { entries[i].value = value }
        }
        var i = 1
        while i < args.count {
            let a = args[i]
            func next() -> String? { guard i + 1 < args.count else { return nil }; i += 1; return args[i] }
            switch a {
            case "--title":    if let v = next() { setEntry(key: "iptc.ObjectName", value: v) }
            case "--caption":  if let v = next() { setEntry(key: "iptc.Caption", value: v) }
            case "--keywords": if let v = next() { setEntry(key: "iptc.Keywords", value: v) }
            case "--copyright":if let v = next() { setEntry(key: "iptc.Copyright", value: v) }
            case "--creator":  if let v = next() { setEntry(key: "iptc.Creator", value: v) }
            case "--date":     if let v = next() { setEntry(key: "exif.DateTimeOriginal", value: v) }
            case "--lat":      if let v = next() { setEntry(key: "gps.Latitude", value: v) }
            case "--lon":      if let v = next() { setEntry(key: "gps.Longitude", value: v) }
            default: break
            }
            i += 1
        }
        do {
            try svc.writePhotoMetadataSync(url: url, entries: entries)
            if jsonMode {
                let obj: [String: Any] = ["path": path, "ok": true]
                if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                   let s = String(data: d, encoding: .utf8) { print(s) }
            } else {
                print("Metadaten gespeichert: \(path)")
            }
        } catch {
            fputs("Fehler beim Schreiben: \(error.localizedDescription)\n", stderr); return 1
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli metadata get|set\n", stderr)
        return 1
    }
}

// MARK: - Cache

private func runCache(_ args: [String]) -> Int32 {
    let sub = args.first ?? ""
    let cache = ThumbnailDiskCache.shared
    switch sub {
    case "stats":
        let s = cache.stats
        let mb = Double(s.bytes) / 1_048_576
        if args.contains("--json") {
            let obj: [String: Any] = ["count": s.count, "bytes": s.bytes,
                                      "mb": String(format: "%.2f", mb)]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
               let str = String(data: d, encoding: .utf8) { print(str) }
        } else {
            print("\(s.count) Thumbnails · \(String(format: "%.2f", mb)) MB")
        }
        return 0
    case "clear":
        cache.clearAll()
        print("Thumbnail-Cache geleert.")
        return 0
    default:
        fputs("Verwendung: iphoto-cli cache stats|clear [--json]\n", stderr)
        return 1
    }
}

// MARK: - Local Adjustments CLI

private func runLocalAdjustments(_ args: [String]) -> Int32 {
    let sub = args.first ?? ""
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    switch sub {
    case "list":
        guard let path = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli local-adjustments list <bildpfad> [--json]\n", stderr); return 1
        }
        guard let adj = catalog.loadAdjustments(path: path) else {
            if jsonMode {
                let d: [String: Any] = ["path": path, "count": 0, "masks": [Any]()]
                if let dd = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
                   let s = String(data: dd, encoding: .utf8) { print(s) }
            } else {
                print("Keine lokalen Anpassungen für: \(path)")
            }
            return 0
        }
        let masks = adj.localAdjustments
        if jsonMode {
            var items: [[String: Any]] = []
            for m in masks {
                var maskInfo: [String: Any] = [
                    "id": m.id.uuidString, "label": m.label,
                    "intensity": m.intensity, "inverted": m.inverted
                ]
                switch m.mask {
                case .linearGradient(let sx, let sy, let ex, let ey):
                    maskInfo["mask_type"] = "linear"
                    maskInfo["startX"] = sx; maskInfo["startY"] = sy
                    maskInfo["endX"] = ex;   maskInfo["endY"] = ey
                case .radialGradient(let cx, let cy, let r, let f):
                    maskInfo["mask_type"] = "radial"
                    maskInfo["centerX"] = cx; maskInfo["centerY"] = cy
                    maskInfo["radius"] = r;   maskInfo["feather"] = f
                }
                maskInfo["delta"] = [
                    "exposure": m.delta.exposure, "brightness": m.delta.brightness,
                    "contrast": m.delta.contrast, "saturation": m.delta.saturation,
                    "warmth": m.delta.warmth, "tint": m.delta.tint
                ]
                items.append(maskInfo)
            }
            let obj: [String: Any] = ["path": path, "count": masks.count, "masks": items]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if masks.isEmpty { print("Keine lokalen Anpassungen für: \(path)") }
            else {
                print("\(masks.count) lokale Maske(n) für: \(path)")
                for (i, m) in masks.enumerated() {
                    let typeStr: String
                    switch m.mask {
                    case .linearGradient: typeStr = "linear"
                    case .radialGradient: typeStr = "radial"
                    }
                    let label = m.label.isEmpty ? "(ohne Label)" : m.label
                    print("  \(i+1). [\(typeStr)] \(label)  Intensität: \(m.intensity)")
                }
            }
        }
        return 0

    case "clear":
        guard let path = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli local-adjustments clear <bildpfad> [--json]\n", stderr); return 1
        }
        guard var adj = catalog.loadAdjustments(path: path) else {
            if jsonMode {
                let d: [String: Any] = ["path": path, "cleared": 0, "ok": true]
                if let dd = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
                   let s = String(data: dd, encoding: .utf8) { print(s) }
            } else {
                print("Keine Anpassungen gefunden für: \(path)")
            }
            return 0
        }
        let count = adj.localAdjustments.count
        adj.localAdjustments = []
        catalog.saveAdjustments(path: path, adjustments: adj)
        if jsonMode {
            let d: [String: Any] = ["path": path, "cleared": count, "ok": true]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            print("\(count) lokale Maske(n) entfernt: \(path)")
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli local-adjustments list|clear <bildpfad> [--json]\n", stderr)
        return 1
    }
}

// MARK: - rating histogram

private func runRatingHistogram(_ args: [String]) -> Int32 {
    let jsonMode = args.contains("--json")
    if let bad = args.first(where: { $0 != "--json" }) {
        fputs("Fehler: Unbekanntes Argument '\(bad)'\nVerwendung: iphoto-cli rating histogram [--json]\n", stderr)
        return 1
    }
    let catalog = CatalogStore(dbPath: envDBPath())
    let dist = catalog.ratingDistribution()
    let catalogTotal = catalog.allImages().count
    var buckets: [Int] = Array(repeating: 0, count: 6)
    for (stars, n) in dist where stars >= 1 && stars <= 5 { buckets[stars] = n }
    let rated = buckets[1...5].reduce(0, +)
    // Ratings können für Pfade existieren, die (noch) nicht im images-Table stehen.
    let total = max(catalogTotal, rated)
    buckets[0] = total - rated
    let weighted = (1...5).reduce(0) { $0 + $1 * buckets[$1] }
    let avg = rated > 0 ? Double(weighted) / Double(rated) : 0
    if jsonMode {
        var byStars: [String: Int] = [:]
        for i in 0...5 { byStars[String(i)] = buckets[i] }
        let d: [String: Any] = ["total": total, "rated": rated, "unrated": buckets[0],
                                "average": (avg * 100).rounded() / 100, "byStars": byStars]
        if let dd = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: dd, encoding: .utf8) { print(s) }
    } else {
        let maxN = max(1, buckets.max() ?? 1)
        for i in stride(from: 5, through: 0, by: -1) {
            let label = i == 0 ? "ohne " : String(repeating: "★", count: i).padding(toLength: 5, withPad: " ", startingAt: 0)
            let bar = String(repeating: "█", count: buckets[i] * 30 / maxN)
            print("\(label) \(String(format: "%6ld", buckets[i]))  \(bar)")
        }
        print("Bewertet: \(rated) / \(total)  Ø \(String(format: "%.2f", avg))")
    }
    return 0
}

// MARK: - exif get / set / films

private func exifDict(path: String, _ e: (focalLength: Double?, iso: Int?, aperture: Double?, lensModel: String?, hdr: Bool, filmSimulation: String?, sequenceNumber: Int?, autoBracketing: Bool)) -> [String: Any] {
    var d: [String: Any] = ["path": path, "hdr": e.hdr, "autoBracketing": e.autoBracketing]
    func orNull<T>(_ v: T?) -> Any { if let v = v { return v } else { return NSNull() } }
    d["focalLength"] = orNull(e.focalLength)
    d["iso"] = orNull(e.iso)
    d["aperture"] = orNull(e.aperture)
    d["lens"] = orNull(e.lensModel)
    d["film"] = orNull(e.filmSimulation)
    d["sequenceNumber"] = orNull(e.sequenceNumber)
    return d
}

private func printExifJSON(_ obj: Any) {
    if let dd = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
       let s = String(data: dd, encoding: .utf8) { print(s) }
}

private func runExif(_ args: [String]) -> Int32 {
    let jsonMode = args.contains("--json")
    let sub = args.first ?? ""
    let rest = Array(args.dropFirst()).filter { $0 != "--json" }

    switch sub {
    case "get":
        guard let path = rest.first, !path.hasPrefix("--") else {
            fputs("Verwendung: iphoto-cli exif get <bildpfad> [--json]\n", stderr); return 1
        }
        let catalog = CatalogStore(dbPath: envDBPath())
        guard let e = catalog.exif(forPath: path) else {
            fputs("Fehler: Bild nicht im Katalog: \(path)\n", stderr); return 1
        }
        if jsonMode { printExifJSON(exifDict(path: path, e)) }
        else {
            func f<T>(_ v: T?) -> String { if let v = v { return "\(v)" } else { return "—" } }
            print("Pfad:        \(path)")
            print("Brennweite:  \(f(e.focalLength))")
            print("ISO:         \(f(e.iso))")
            print("Blende:      \(f(e.aperture))")
            print("Objektiv:    \(f(e.lensModel))")
            print("Filmsim.:    \(f(e.filmSimulation))")
            print("HDR:         \(e.hdr)")
            print("Sequenz:     \(f(e.sequenceNumber))")
            print("Bracketing:  \(e.autoBracketing)")
        }
        return 0

    case "set":
        guard let path = rest.first, !path.hasPrefix("--") else {
            fputs("Verwendung: iphoto-cli exif set <bildpfad> [--iso N] [--focal MM] [--aperture F] [--lens NAME] [--film NAME] [--hdr true|false] [--json]\n", stderr)
            return 1
        }
        let opts = Array(rest.dropFirst())
        guard !opts.isEmpty else {
            fputs("Fehler: Mindestens ein Feld angeben (--iso, --focal, --aperture, --lens, --film, --hdr)\n", stderr)
            return 1
        }
        let catalog = CatalogStore(dbPath: envDBPath())
        if catalog.image(forPath: path) == nil {
            guard FileManager.default.fileExists(atPath: path) else {
                fputs("Fehler: Bild weder im Katalog noch auf der Festplatte: \(path)\n", stderr); return 1
            }
            catalog.upsertImage(path: path, filename: URL(fileURLWithPath: path).lastPathComponent,
                                isRAW: ImageDocument.rawExtensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased()))
        }
        let cur = catalog.exif(forPath: path)
        var focal = cur?.focalLength, iso = cur?.iso, ap = cur?.aperture
        var lens = cur?.lensModel, film = cur?.filmSimulation, hdr = cur?.hdr ?? false
        var i = 0
        while i < opts.count {
            let key = opts[i]
            guard i + 1 < opts.count else {
                fputs("Fehler: Wert fehlt für \(key)\n", stderr); return 1
            }
            let val = opts[i + 1]
            switch key {
            case "--iso":
                guard let n = Int(val), n > 0 else { fputs("Fehler: Ungültiger ISO-Wert '\(val)'\n", stderr); return 1 }
                iso = n
            case "--focal":
                guard let v = Double(val), v > 0 else { fputs("Fehler: Ungültige Brennweite '\(val)'\n", stderr); return 1 }
                focal = v
            case "--aperture":
                guard let v = Double(val), v > 0 else { fputs("Fehler: Ungültige Blende '\(val)'\n", stderr); return 1 }
                ap = v
            case "--lens": lens = val.isEmpty ? nil : val
            case "--film": film = val.isEmpty ? nil : val
            case "--hdr":
                switch val.lowercased() {
                case "true", "1", "yes": hdr = true
                case "false", "0", "no": hdr = false
                default: fputs("Fehler: --hdr erwartet true|false (angegeben: \(val))\n", stderr); return 1
                }
            default:
                fputs("Fehler: Unbekannte Option '\(key)'\n", stderr); return 1
            }
            i += 2
        }
        catalog.upsertExif(path: path, focalLength: focal, iso: iso, aperture: ap, lensModel: lens,
                           hdr: hdr, filmSimulation: film, sequenceNumber: cur?.sequenceNumber,
                           autoBracketing: cur?.autoBracketing ?? false)
        guard let e = catalog.exif(forPath: path) else {
            fputs("Fehler: EXIF konnte nicht gespeichert werden: \(path)\n", stderr); return 1
        }
        if jsonMode {
            var d = exifDict(path: path, e); d["ok"] = true
            printExifJSON(d)
        } else {
            print("EXIF gespeichert: \(path)")
        }
        return 0

    case "films":
        let films = CatalogStore(dbPath: envDBPath()).allFilmSimulations()
        if jsonMode { printExifJSON(films) }
        else if films.isEmpty { print("(keine Filmsimulationen im Katalog)") }
        else { films.forEach { print($0) } }
        return 0

    default:
        fputs("Verwendung: iphoto-cli exif get|set|films ... [--json]\n", stderr)
        return 1
    }
}

// MARK: - Entry Point

let rawArgs = CommandLine.arguments
guard rawArgs.count >= 2 else { printUsage(); exit(0) }

let firstArg = rawArgs[1]
if firstArg == "preset" {
    exit(runPreset(Array(rawArgs.dropFirst(2))))
}
if firstArg == "plugins" {
    exit(runPlugins(Array(rawArgs.dropFirst(2))))
}
if firstArg == "viewmode" {
    exit(runViewMode(Array(rawArgs.dropFirst(2))))
}
if firstArg == "people" {
    exit(runPeople(Array(rawArgs.dropFirst(2))))
}
if firstArg == "album" {
    exit(runAlbum(Array(rawArgs.dropFirst(2))))
}
if firstArg == "quality" {
    exit(runQuality(Array(rawArgs.dropFirst(2))))
}
if firstArg == "version" {
    exit(runVersion(Array(rawArgs.dropFirst(2))))
}
if firstArg == "search" {
    exit(runSearch(Array(rawArgs.dropFirst(2))))
}
if firstArg == "catalog" {
    exit(runCatalog(Array(rawArgs.dropFirst(2))))
}
if firstArg == "motif" {
    exit(runMotif(Array(rawArgs.dropFirst(2))))
}
if firstArg == "elo" {
    exit(runElo(Array(rawArgs.dropFirst(2))))
}
// rating list is a subcommand; intercept before CLIArgs parsing
if firstArg == "rating", rawArgs.count >= 3, rawArgs[2] == "list" {
    exit(runRatingList(Array(rawArgs.dropFirst(3))))
}
if firstArg == "duplicate" {
    exit(runDuplicate(Array(rawArgs.dropFirst(2))))
}
if firstArg == "smartfolder" {
    exit(runSmartFolder(Array(rawArgs.dropFirst(2))))
}
if firstArg == "stack" {
    exit(runStack(Array(rawArgs.dropFirst(2))))
}
if firstArg == "trash" {
    exit(runTrash(Array(rawArgs.dropFirst(2))))
}
if firstArg == "adjustments" {
    exit(runAdjustments(Array(rawArgs.dropFirst(2))))
}
if firstArg == "export", rawArgs.contains("--list-formats") {
    let jsonMode = rawArgs.contains("--json")
    if jsonMode {
        print("[\"jpeg\", \"png\", \"tiff\", \"heif\"]")
    } else {
        print("jpeg\npng\ntiff\nheif")
    }
    exit(0)
}
// rating batch-set intercept before CLIArgs parsing
if firstArg == "rating", rawArgs.count >= 3, rawArgs[2] == "batch-set" {
    exit(runRatingBatchSet(Array(rawArgs.dropFirst(3))))
}
if firstArg == "config" {
    exit(runConfig(Array(rawArgs.dropFirst(2))))
}
if firstArg == "cache" {
    exit(runCache(Array(rawArgs.dropFirst(2))))
}
if firstArg == "watched" {
    exit(runWatched(Array(rawArgs.dropFirst(2))))
}
if firstArg == "backup" {
    exit(runBackupConfig(Array(rawArgs.dropFirst(2))))
}
if firstArg == "albumfolder" {
    exit(runAlbumFolder(Array(rawArgs.dropFirst(2))))
}
if firstArg == "metadata" {
    exit(runMetadata(Array(rawArgs.dropFirst(2))))
}
if firstArg == "local-adjustments" {
    exit(runLocalAdjustments(Array(rawArgs.dropFirst(2))))
}
if firstArg == "rating", rawArgs.count >= 3, rawArgs[2] == "histogram" {
    exit(runRatingHistogram(Array(rawArgs.dropFirst(3))))
}
if firstArg == "exif" {
    exit(runExif(Array(rawArgs.dropFirst(2))))
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
