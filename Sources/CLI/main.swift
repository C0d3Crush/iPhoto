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
      iphoto-cli people delete <id> [--json]
      iphoto-cli people reset [--json]
      iphoto-cli people export-names [--output <datei.csv>] [--json]
      iphoto-cli people import-names <datei.csv> [--json]
      iphoto-cli album list|create|delete|add|remove|images|reorder [--json]
      iphoto-cli album rename <album-id|name> <neuer-name> [--json]
      iphoto-cli album export <album-id|name> --output-dir <ordner> [--dry-run] [--overwrite] [--json]
      iphoto-cli quality scan|list|get [--json]
      iphoto-cli quality override list | <bildpfad> [--blur|--under|--over|--eyes-closed on|off] [--clear] [--json]
      iphoto-cli version list|backup|restore|delete [--json]
      iphoto-cli search <text> [--flag pick|reject|none] [--rating N] [--color farbe] [--camera modell] [--date YYYY-MM-DD] [--json]
      iphoto-cli catalog stats|path|vacuum|export|scan-needed|backup-now|list|remove|get|add|prune|cameras|timeline|orphans [--json]
      iphoto-cli albumfolder list|create|rename|delete [--json]
      iphoto-cli motif get <bildpfad> [--json]
      iphoto-cli motif list [--json]
      iphoto-cli motif set <bildpfad> <tag1,tag2,...> [--json]
      iphoto-cli motif find <tag> [--json]
      iphoto-cli motif stats [--json]
      iphoto-cli motif rename <alt> <neu> [--dry-run] [--json]
      iphoto-cli motif remove <tag> [--dry-run] [--json]
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
      iphoto-cli smartfolder sql <name> [--count] [--json]
      iphoto-cli smartfolder count [<name>] [--json]
      iphoto-cli local-adjustments list <bildpfad> [--json]
      iphoto-cli local-adjustments clear <bildpfad> [--json]
      iphoto-cli rating histogram [--json]
      iphoto-cli rating export [--output <datei.json|.csv>] [--format json|csv] [--include-unrated] [--json]
      iphoto-cli rating import <datei.json|.csv> [--skip-existing] [--dry-run] [--json]
      iphoto-cli exif get <bildpfad> [--json]
      iphoto-cli exif set <bildpfad> [--iso N] [--focal MM] [--aperture F] [--lens NAME]
                          [--film NAME] [--hdr true|false] [--json]
      iphoto-cli exif films [--json]
      iphoto-cli exif stats [--by lens|iso|aperture|focal|film|camera] [--limit N] [--json]
      iphoto-cli stack list [--json]
      iphoto-cli stack query <bildpfad> [--json]
      iphoto-cli trash list [--json]
      iphoto-cli trash mark <bildpfad> [--json]
      iphoto-cli trash mark-rejected [--dry-run] [--json]
      iphoto-cli trash restore <bildpfad>|--all [--json]
      iphoto-cli trash empty [--json]
      iphoto-cli elo get <bildpfad> [--json]
      iphoto-cli elo list [--json]
      iphoto-cli elo set <bildpfad> <wert> [--matches N] [--json]
      iphoto-cli elo match <links> <rechts> [--winner left|right|draw] [--json]
      iphoto-cli elo reset <bildpfad> [<bildpfad>...] | --all [--json]
      iphoto-cli adjustments list [--json]
      iphoto-cli adjustments get <bildpfad> [--json]
      iphoto-cli adjustments delete <bildpfad> [--json]
      iphoto-cli rating batch-set <bild1> [<bild2>...] [--set N] [--flag pick|reject|none] [--color farbe] [--json]
      iphoto-cli export --list-formats [--json]
      iphoto-cli catalog scan-needed [--json]
      iphoto-cli catalog backup-now [--json]
      iphoto-cli catalog list [--limit N] [--json]
      iphoto-cli catalog remove <pfad> [<pfad> ...] [--json]
      iphoto-cli catalog get <pfad> [--json]
      iphoto-cli catalog add <pfad> [<pfad> ...] [--json]
      iphoto-cli catalog prune [--dry-run] [--json]
      iphoto-cli catalog cameras [--json]
      iphoto-cli catalog timeline [--by year|month|day] [--json]
      iphoto-cli catalog orphans [--fix] [--json]
      iphoto-cli query filters [--json]
      iphoto-cli query parse <suchtext> [--json]
      iphoto-cli query run <suchtext> [--blur-threshold 80] [--include-trashed] [--json]
      iphoto-cli bugreport list [--fixed|--all] [--json]
      iphoto-cli bugreport show <name> [--json]
      iphoto-cli bugreport fix <name> [<name>...] [--json]
      iphoto-cli bugreport reopen <name> [<name>...] [--json]
      iphoto-cli bugreport path [--json]
      iphoto-cli bookmarks list [--missing] [--json]
      iphoto-cli bookmarks stats [--json]
      iphoto-cli bookmarks remove <pfad|file-url> [...] [--json]
      iphoto-cli bookmarks prune [--dry-run] [--json]
      iphoto-cli bookmarks path [--json]
      iphoto-cli gear summary [--json]
      iphoto-cli gear cameras|lenses [--limit N] [--json]
      iphoto-cli gear focal|iso|aperture [--limit N] [--json]
      iphoto-cli perf path [--json]
      iphoto-cli perf switch [--log <datei>] [--last-session] [--label <tag>] [--slowest N] [--json]
      iphoto-cli collect --output-dir <ordner> [--flag pick|reject|none] [--color farbe] [--min-rating N]
                         [--include-trashed] [--dry-run] [--overwrite] [--json]

    Formate:  jpeg (Standard), png, tiff, heif
    Quality:  0.0–1.0, nur für jpeg und heif (Standard: 0.9)
    hdr:      Erzeugt 6 Preset-Varianten aus allen RAWs im Ordner (Vergleich); --json
    info:     Gibt alle EXIF/IPTC/GPS-Metadaten aus; --json für maschinenlesbare Ausgabe
    rating:   Liest/schreibt Bewertung, Flag und Farblabel; 'list' zeigt alle bewerteten Bilder;
              export/import sichert Bewertungen als JSON/CSV (Import validiert atomar)
    adjust:   Wendet Bildanpassungen an und exportiert das Ergebnis
    preset:   Zeigt Built-in-Presets oder wendet einen an
    analyse:  Analysiert Schärfe und Belichtung (Blur + Exposure)
    inpaint:  KI-basiertes Inpainting via CMT (benötigt Python + CMT-Installation); --json
    plugins:  Listet installierte Plugins/Panels auf oder zeigt den Plugin-Ordner; dir --json
    album:    Alben erstellen, bearbeiten, umbenennen, Bilder hinzufügen/entfernen, in Ordner exportieren
    quality:  Qualitätsanalyse (Blur, Belichtung, Closed-Eye) scannen und lesen; list --sort blur|rating|elo
    version:  Versionshistorie eines Bildes sichern, anzeigen oder wiederherstellen
    search:   Bilder im Katalog nach Text, Flag (none/pick/reject), Rating (0-5), Farbe, Kamera, Datum
    catalog:  Statistiken (inkl. ELO-Anzahl), Pfad, vacuum --json, export
              cameras: Bilder pro Kamera; timeline: Bilder pro Jahr/Monat/Tag (--by)
              orphans: verwaiste Bewertungen/Papierkorb/Album/Anpassungen/Gesichter (--fix löscht)
    motif:    Motiv-Tags eines Bildes anzeigen
    elo:      ELO-Scores lesen, auflisten (nach Score sortiert) und setzen
    duplicate:Duplikate und ähnliche Bilder aus dem Katalog anzeigen
    config:   Einstellungen anzeigen, lesen (get <key>), schreiben (set <key> <wert>), ex-/importieren
    query:    App-Suchsyntax (bewertung:5 typ:raw vor:2024 nach:2023-06 kamera:x album:x markiert:pick
              unscharf:ja motiv:x elo:>=1600 farbe:rot + Freitext) parsen oder gegen den Katalog ausführen
    bugreport:Crash-Berichte aus ~/Documents/bugreports auflisten, anzeigen, nach fixed/ verschieben
              (fix) oder wieder öffnen (reopen); Ordner per IPHOTO_BUGREPORT_DIR überschreibbar
    bookmarks:Security-Scoped-Bookmarks (bookmarks.json) auflisten, Statistik, einzeln entfernen oder
              verwaiste Einträge aufräumen (prune; offline-Volumes bleiben); Datei per IPHOTO_BOOKMARKS_FILE
    gear:     Kamera-/Objektiv-Statistik aus dem Katalog: Rangliste nach Häufigkeit (cameras/lenses),
              Histogramme für Brennweite/ISO/Blende, summary mit Min/Max/Median
    perf:     SWITCH-Latenzmetriken aus ~/Library/Logs/iPhoto/iPhoto.log auswerten: n/median/p95/max
              pro Anzeigepfad (cache-hit, preview-hit, full-res …), --slowest N; Datei per IPHOTO_LOG_FILE
    collect:  Kopiert alle Bilder, die Flag/Farbe/Mindest-Rating erfüllen (Standard: alle Picks), in einen
              Ordner; Papierkorb ausgeschlossen (außer --include-trashed), Namenskollisionen → name-2.ext
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
            // Face-Counts einmal vorberechnen statt allFaces() pro Person (war O(P·F) + P SQL-Queries)
            var faceCounts: [String: Int] = [:]
            for f in catalog.allFaces() { if let c = f.clusterID { faceCounts[c, default: 0] += 1 } }
            var arr: [[String: Any]] = []
            for p in people {
                var obj: [String: Any] = ["id": p.id]
                if let n = p.name { obj["name"] = n }
                obj["face_count"] = faceCounts[p.id] ?? 0
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

    case "delete":
        // people delete <id> [--json] — Person löschen, Gesichter bleiben (unzugeordnet)
        guard let personID = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli people delete <id> [--json]\n", stderr); return 1
        }
        guard catalog.allPeople().contains(where: { $0.id == personID }) else {
            fputs("Fehler: Person '\(personID)' nicht im Katalog\n", stderr); return 1
        }
        catalog.deletePerson(id: personID)
        if jsonMode {
            let obj: [String: Any] = ["id": personID, "deleted": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Person gelöscht: \(personID)")
        }
        return 0

    case "reset":
        // people reset [--json] — alle Cluster-Zuordnungen lösen, unbenannte Personen löschen
        let before = catalog.allPeople()
        catalog.resetAllClusters()
        let kept = catalog.allPeople().count
        let removed = before.count - kept
        if jsonMode {
            let obj: [String: Any] = ["removed_people": removed, "kept_named": kept, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Cluster zurückgesetzt: \(removed) unbenannte Person(en) gelöscht, \(kept) benannte behalten")
        }
        return 0

    default:
        fputs("Fehler: Unbekannter people-Unterbefehl '\(sub)'. Erlaubt: list, faces, cluster, rename, delete, reset, export-names, import-names\n", stderr)
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
        fputs("Verwendung: iphoto-cli smartfolder list|query|create|update|rename|delete|sync|sql|count [opts]\n", stderr)
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

    case "sql":
        // Zeigt das vom SmartFolderSQLGenerator erzeugte SQL — Debugging für Smart-Ordner-Regeln.
        guard let name = subArgs.first(where: { !$0.hasPrefix("--") }) else {
            fputs("Verwendung: iphoto-cli smartfolder sql <name> [--count] [--json]\n", stderr)
            return 1
        }
        guard let sf = loadSmartFolders().first(where: { $0.name == name }) else {
            fputs("Fehler: Smart-Ordner '\(name)' nicht gefunden\n", stderr)
            return 1
        }
        let countMode = subArgs.contains("--count")
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "cli"
        let sql = countMode
            ? SmartFolderSQLGenerator.generateCount(for: sf)
            : SmartFolderSQLGenerator.generate(for: sf, version: version)
        let runtimeOnly = SmartFolderSQLGenerator.hasRuntimeOnlyCriteria(sf)
        if jsonMode {
            let obj: [String: Any] = ["name": sf.name, "id": sf.id.uuidString,
                                      "kind": countMode ? "count" : "select",
                                      "criteria": sf.criteria.count,
                                      "matchAll": sf.matchAll,
                                      "runtimeOnly": runtimeOnly,
                                      "sql": sql]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print(sql)
            if runtimeOnly {
                fputs("Hinweis: enthält Laufzeit-Kriterien — SQL ist nicht vollständig ausführbar\n", stderr)
            }
        }
        return 0

    case "count":
        // Sidebar-Badge-Zähler (COUNT-Query ohne ORDER BY/LIMIT) für einen oder alle Smart-Ordner.
        let targetName = subArgs.first(where: { !$0.hasPrefix("--") })
        let folders = loadSmartFolders()
        let selected = targetName.map { n in folders.filter { $0.name == n } } ?? folders
        if let name = targetName, selected.isEmpty {
            fputs("Fehler: Smart-Ordner '\(name)' nicht gefunden\n", stderr)
            return 1
        }
        let catalog = CatalogStore(dbPath: envDBPath())
        let t0 = Date()
        var rows: [[String: Any]] = []
        rows.reserveCapacity(selected.count)
        for sf in selected {
            var row: [String: Any] = ["name": sf.name, "id": sf.id.uuidString]
            if let n = catalog.countForSmartFolder(sf) {
                row["count"] = n
                row["runtimeOnly"] = false
            } else {
                row["count"] = NSNull()
                row["runtimeOnly"] = true
            }
            rows.append(row)
        }
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        if jsonMode {
            let obj: [String: Any] = ["folders": rows, "total": rows.count, "ms": ms]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            if rows.isEmpty { print("(keine Smart-Ordner)") }
            for r in rows {
                let c = (r["count"] as? Int).map { String($0) } ?? "– (Laufzeit-Kriterien)"
                print("\(r["name"]!): \(c)")
            }
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli smartfolder list|query|create|update|rename|delete|sync|sql|count [opts]\n", stderr)
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
        fputs("Verwendung: iphoto-cli trash list|mark|mark-rejected|restore|empty [opts]\n", stderr)
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

    case "mark-rejected":
        // trash mark-rejected [--dry-run] [--json] — alle als "reject" markierten Bilder
        // in einem Rutsch in den Papierkorb legen (bereits getrashte werden übersprungen).
        let extra = args.dropFirst().filter { !$0.hasPrefix("-") }
        let unknownFlags = args.dropFirst().filter { $0.hasPrefix("-") && $0 != "--json" && $0 != "--dry-run" }
        guard extra.isEmpty, unknownFlags.isEmpty else {
            fputs("Verwendung: iphoto-cli trash mark-rejected [--dry-run] [--json]\n", stderr)
            return 1
        }
        let dryRun = args.contains("--dry-run")
        let already = catalog.trashedPaths()
        let rejected = catalog.images(flaggedAs: FlagStatus.reject.rawValue)
            .map { $0.path }
            .filter { !already.contains($0) }
            .sorted()
        if !dryRun && !rejected.isEmpty { catalog.setTrashed(paths: rejected, true) }
        if jsonMode {
            let obj: [String: Any] = ["paths": rejected, "count": rejected.count,
                                      "dry_run": dryRun, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            rejected.forEach { print($0) }
            print(dryRun ? "\(rejected.count) abgelehnte(s) Bild(er) würden in den Papierkorb verschoben (Probelauf)"
                         : "\(rejected.count) abgelehnte(s) Bild(er) in den Papierkorb verschoben")
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
        fputs("Verwendung: iphoto-cli trash list|mark|mark-rejected|restore|empty [opts]\n", stderr)
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

    case "rename":
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard positional.count >= 2 else {
            fputs("Verwendung: iphoto-cli album rename <album-id|name> <neuer-name> [--json]\n", stderr); return 1
        }
        let key = positional[0]
        let newName = positional[1].trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else {
            fputs("Fehler: Neuer Name darf nicht leer sein\n", stderr); return 1
        }
        let albums = catalog.allAlbums()
        guard let album = albums.first(where: { $0.id == key }) ?? albums.first(where: { $0.name == key }) else {
            fputs("Fehler: Album nicht gefunden: \(key)\n", stderr); return 1
        }
        catalog.saveAlbum(id: album.id, name: newName)
        if jsonMode {
            let obj: [String: Any] = ["id": album.id, "old_name": album.name, "name": newName, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Album umbenannt: \(album.name) → \(newName)")
        }
        return 0

    case "export":
        // Kopiert alle Bilder eines Albums (in Album-Reihenfolge) in einen Zielordner.
        var key: String? = nil
        var outDir: String? = nil
        var dryRun = false
        var overwrite = false
        var i = 1
        while i < args.count {
            let a = args[i]
            switch a {
            case "--output-dir":
                i += 1
                guard i < args.count else { fputs("Fehler: --output-dir braucht einen Pfad\n", stderr); return 1 }
                outDir = args[i]
            case "--dry-run": dryRun = true
            case "--overwrite": overwrite = true
            case "--json": break
            default:
                if a.hasPrefix("-") { fputs("Fehler: Unbekannte Option: \(a)\n", stderr); return 1 }
                if key == nil { key = a }
                else { fputs("Fehler: Unerwartetes Argument: \(a)\n", stderr); return 1 }
            }
            i += 1
        }
        guard let albumKey = key, let dest = outDir, !dest.isEmpty else {
            fputs("Verwendung: iphoto-cli album export <album-id|name> --output-dir <ordner> [--dry-run] [--overwrite] [--json]\n", stderr)
            return 1
        }
        let albums = catalog.allAlbums()
        guard let album = albums.first(where: { $0.id == albumKey }) ?? albums.first(where: { $0.name == albumKey }) else {
            fputs("Fehler: Album nicht gefunden: \(albumKey)\n", stderr); return 1
        }
        let fm = FileManager.default
        let destURL = URL(fileURLWithPath: (dest as NSString).expandingTildeInPath)
        if !dryRun {
            do { try fm.createDirectory(at: destURL, withIntermediateDirectories: true) }
            catch {
                fputs("Fehler: Zielordner kann nicht angelegt werden: \(error.localizedDescription)\n", stderr); return 1
            }
        }
        var copied: [String] = []
        var skipped: [String] = []
        var missing: [String] = []
        var failed: [String] = []
        for p in catalog.images(inAlbum: album.id) {
            guard fm.fileExists(atPath: p) else { missing.append(p); continue }
            let target = destURL.appendingPathComponent((p as NSString).lastPathComponent)
            if fm.fileExists(atPath: target.path) {
                if !overwrite { skipped.append(p); continue }
                if !dryRun { try? fm.removeItem(at: target) }
            }
            if dryRun { copied.append(p); continue }
            do { try fm.copyItem(at: URL(fileURLWithPath: p), to: target); copied.append(p) }
            catch { failed.append(p) }
        }
        if jsonMode {
            let obj: [String: Any] = [
                "album_id": album.id, "name": album.name, "output_dir": destURL.path,
                "dry_run": dryRun, "copied": copied.count, "skipped": skipped.count,
                "missing": missing.count, "failed": failed.count,
                "paths": copied, "ok": failed.isEmpty
            ]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            let verb = dryRun ? "würden kopiert" : "kopiert"
            print("Album \(album.name): \(copied.count) \(verb), \(skipped.count) übersprungen, \(missing.count) fehlend, \(failed.count) Fehler → \(destURL.path)")
        }
        return failed.isEmpty ? 0 : 1

    default:
        fputs("Verwendung: iphoto-cli album list|create|delete|add|remove|images|reorder|rename|export\n", stderr)
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

    case "override":
        return runQualityOverride(Array(args.dropFirst()), catalog: catalog, jsonMode: jsonMode)

    default:
        fputs("Verwendung: iphoto-cli quality scan|list|get|override\n", stderr)
        return 1
    }
}

// Nutzer-Korrekturen der Quality-Flags ("Bild ist doch nicht unscharf") — gleiche Spalten,
// die BlurryView/ExposureView in der App respektieren.
private func runQualityOverride(_ args: [String], catalog: CatalogStore, jsonMode: Bool) -> Int32 {
    let usage = "Verwendung: iphoto-cli quality override list [--json]\n" +
                "       iphoto-cli quality override <bildpfad> [--blur on|off] [--under on|off] [--over on|off] [--eyes-closed on|off] [--clear] [--json]\n"
    let rest = args.filter { $0 != "--json" }
    func emit(_ obj: Any) {
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: d, encoding: .utf8) { print(s) }
    }
    guard let first = rest.first, !first.hasPrefix("--") else {
        fputs(usage, stderr); return 1
    }

    if first == "list" {
        let all = catalog.allQualityOverrides().sorted { $0.key < $1.key }
        if jsonMode {
            emit(all.map { ["path": $0.key, "blur": $0.value.blur, "under": $0.value.under,
                            "over": $0.value.over, "eyes_closed": $0.value.eyesClosed] as [String: Any] })
        } else {
            if all.isEmpty { print("(keine Overrides)") }
            for (path, o) in all {
                var flags: [String] = []
                if o.blur { flags.append("blur") }
                if o.under { flags.append("under") }
                if o.over { flags.append("over") }
                if o.eyesClosed { flags.append("eyes-closed") }
                print("\(flags.joined(separator: ","))  \(path)")
            }
        }
        return 0
    }

    let path = first
    guard catalog.image(forPath: path) != nil else {
        fputs("Fehler: Bild nicht im Katalog: \(path)\n", stderr); return 1
    }
    var blur: Bool? = nil, under: Bool? = nil, over: Bool? = nil, eyes: Bool? = nil
    let opts = Array(rest.dropFirst())
    var i = 0
    while i < opts.count {
        let key = opts[i]
        if key == "--clear" {
            blur = false; under = false; over = false; eyes = false
            i += 1; continue
        }
        guard ["--blur", "--under", "--over", "--eyes-closed"].contains(key) else {
            fputs("Fehler: Unbekannte Option \(key)\n", stderr); fputs(usage, stderr); return 1
        }
        guard i + 1 < opts.count else {
            fputs("Fehler: Wert fehlt für \(key)\n", stderr); return 1
        }
        let val: Bool
        switch opts[i + 1].lowercased() {
        case "on", "true", "1", "yes":  val = true
        case "off", "false", "0", "no": val = false
        default:
            fputs("Fehler: Ungültiger Wert '\(opts[i + 1])' für \(key) (on|off)\n", stderr); return 1
        }
        switch key {
        case "--blur":  blur = val
        case "--under": under = val
        case "--over":  over = val
        default:        eyes = val
        }
        i += 2
    }
    let changed = blur != nil || under != nil || over != nil || eyes != nil
    if changed {
        catalog.setQualityOverride(path: path, blur: blur, under: under, over: over, eyesClosed: eyes)
    }
    let q = catalog.quality(forPath: path)
    let state: [String: Any] = ["path": path,
                                "blur": q?.blurOverride ?? false,
                                "under": q?.underOverride ?? false,
                                "over": q?.overOverride ?? false,
                                "eyes_closed": q?.eyesClosedOverride ?? false,
                                "changed": changed]
    if jsonMode { emit(state) }
    else {
        print("Pfad:         \(path)")
        print("Blur:         \(q?.blurOverride ?? false)")
        print("Unterbel.:    \(q?.underOverride ?? false)")
        print("Überbel.:     \(q?.overOverride ?? false)")
        print("Augen zu:     \(q?.eyesClosedOverride ?? false)")
    }
    return 0
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

/// Entfernt Bilder samt Bewertung, Gesichtern, Anpassungen, Album-Zuordnung und
/// Papierkorb-Eintrag aus dem Katalog. Dateien auf der Platte bleiben unberührt.
private func removeCatalogEntries(_ paths: [String], catalog: CatalogStore) {
    guard !paths.isEmpty else { return }
    let albumIDs = catalog.allAlbums().map { $0.id }
    for p in paths {
        for aid in albumIDs { catalog.removeImage(path: p, fromAlbum: aid) }
        catalog.removeRating(path: p)
        catalog.deleteFaces(forPath: p)
        catalog.deleteAdjustments(path: p)
        catalog.removeImage(path: p)
    }
    catalog.setTrashed(paths: paths, false)
}

private func runCatalog(_ args: [String]) -> Int32 {
    let sub = args.first ?? "stats"
    let jsonMode = args.contains("--json")
    let catalog = CatalogStore(dbPath: envDBPath())

    switch sub {
    case "stats":
        let dbPath = envDBPath() ?? "(Standard: ~/Library/Application Support/iPhoto/catalog.db)"
        let imageCount  = catalog.imageCount()
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

    case "list":
        // catalog list [--limit N] [--json]
        var limit: Int? = nil
        if let li = args.firstIndex(of: "--limit") {
            guard li + 1 < args.count, let n = Int(args[li + 1]), n > 0 else {
                fputs("Fehler: --limit erwartet eine positive Ganzzahl\n", stderr); return 1
            }
            limit = n
        }
        var images = catalog.allImages()
        if let n = limit, images.count > n { images = Array(images.prefix(n)) }
        if jsonMode {
            let arr: [[String: Any]] = images.map { (img: CatalogImage) -> [String: Any] in
                var o: [String: Any] = ["path": img.path, "filename": img.filename,
                                        "width": img.width, "height": img.height,
                                        "is_raw": img.isRAW, "size_bytes": img.sizeBytes]
                if let d = img.dateTaken { o["date_taken"] = d }
                let cam = [img.cameraMake, img.cameraModel].compactMap { $0 }.joined(separator: " ")
                if !cam.isEmpty { o["camera"] = cam }
                return o
            }
            if let d = try? JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else if images.isEmpty {
            print("(keine Bilder im Katalog)")
        } else {
            for img in images { print("\(img.width)x\(img.height)  \(img.path)") }
        }
        return 0

    case "remove":
        // catalog remove <pfad> [<pfad> ...] [--json]
        // Entfernt Bilder samt Bewertung, Gesichtern, Anpassungen, Album-Zuordnung und Papierkorb-Eintrag.
        // Die Dateien auf der Platte bleiben unberührt.
        let paths = args.dropFirst().filter { !$0.hasPrefix("-") }
        guard !paths.isEmpty else {
            fputs("Verwendung: iphoto-cli catalog remove <pfad> [<pfad> ...] [--json]\n", stderr); return 1
        }
        let missing = paths.filter { catalog.image(forPath: $0) == nil }
        guard missing.isEmpty else {
            missing.forEach { fputs("Fehler: Bild nicht im Katalog: \($0)\n", stderr) }
            return 1
        }
        removeCatalogEntries(Array(paths), catalog: catalog)
        if jsonMode {
            let obj: [String: Any] = ["removed": paths, "count": paths.count, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Aus Katalog entfernt: \(paths.count) Bild(er)")
        }
        return 0

    case "get":
        // catalog get <pfad> [--json] — einzelnen Katalog-Eintrag anzeigen
        guard let path = args.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            fputs("Verwendung: iphoto-cli catalog get <pfad> [--json]\n", stderr); return 1
        }
        guard let img = catalog.image(forPath: path) else {
            fputs("Fehler: Bild nicht im Katalog: \(path)\n", stderr); return 1
        }
        let cam = [img.cameraMake, img.cameraModel].compactMap { $0 }.joined(separator: " ")
        if jsonMode {
            var o: [String: Any] = ["path": img.path, "filename": img.filename,
                                    "width": img.width, "height": img.height,
                                    "is_raw": img.isRAW, "size_bytes": img.sizeBytes,
                                    "imported_at": img.importedAt]
            if let d = img.dateTaken { o["date_taken"] = d }
            if !cam.isEmpty { o["camera"] = cam }
            if let d = try? JSONSerialization.data(withJSONObject: o, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Pfad:       \(img.path)")
            print("Maße:       \(img.width)x\(img.height)")
            print("Größe:      \(img.sizeBytes) Bytes")
            print("RAW:        \(img.isRAW)")
            print("Aufnahme:   \(img.dateTaken ?? "—")")
            print("Kamera:     \(cam.isEmpty ? "—" : cam)")
            print("Importiert: \(img.importedAt)")
        }
        return 0

    case "add":
        // catalog add <pfad> [<pfad> ...] [--json]
        // Registriert Bilder direkt im Katalog. Liest nur Header-Properties (kein Pixel-Decode),
        // parallel über alle Dateien, dann ein einziger Batch-Insert in einer Transaktion.
        let paths = Array(args.dropFirst().filter { !$0.hasPrefix("-") })
        guard !paths.isEmpty else {
            fputs("Verwendung: iphoto-cli catalog add <pfad> [<pfad> ...] [--json]\n", stderr); return 1
        }
        let fm = FileManager.default
        let missing = paths.filter { !fm.fileExists(atPath: $0) }
        guard missing.isEmpty else {
            missing.forEach { fputs("Fehler: Datei nicht gefunden: \($0)\n", stderr) }
            return 1
        }
        typealias Item = (path: String, filename: String, isRAW: Bool, width: Int, height: Int,
                          sizeBytes: Int64, dateTaken: String?, cameraMake: String?, cameraModel: String?)
        var items = [Item?](repeating: nil, count: paths.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: paths.count) { idx in
            let p = paths[idx]
            let url = URL(fileURLWithPath: p)
            let attrs = try? FileManager.default.attributesOfItem(atPath: p)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            var w = 0, h = 0
            var date: String? = nil, make: String? = nil, model: String? = nil
            let opts = [kCGImageSourceShouldCache: false] as CFDictionary
            if let src = CGImageSourceCreateWithURL(url as CFURL, opts),
               let props = CGImageSourceCopyPropertiesAtIndex(src, 0, opts) as? [CFString: Any] {
                w = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
                h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
                if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                    date = exif[kCGImagePropertyExifDateTimeOriginal] as? String
                }
                if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                    make = tiff[kCGImagePropertyTIFFMake] as? String
                    model = tiff[kCGImagePropertyTIFFModel] as? String
                }
            }
            let item: Item = (path: p, filename: url.lastPathComponent,
                              isRAW: ImageDocument.rawExtensions.contains(url.pathExtension.lowercased()),
                              width: w, height: h, sizeBytes: size,
                              dateTaken: date, cameraMake: make, cameraModel: model)
            lock.lock(); items[idx] = item; lock.unlock()
        }
        catalog.batchUpsertImages(items.compactMap { $0 })
        if jsonMode {
            let obj: [String: Any] = ["added": paths, "count": paths.count, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            print("Im Katalog registriert: \(paths.count) Bild(er)")
        }
        return 0

    case "prune":
        // catalog prune [--dry-run] [--json]
        // Entfernt Katalog-Einträge, deren Datei nicht mehr auf der Platte liegt
        // (verschoben/gelöscht außerhalb der App). Existenz-Check parallel.
        let extra = args.dropFirst().filter { !$0.hasPrefix("-") }
        let unknownFlags = args.dropFirst().filter { $0.hasPrefix("-") && $0 != "--json" && $0 != "--dry-run" }
        guard extra.isEmpty, unknownFlags.isEmpty else {
            fputs("Verwendung: iphoto-cli catalog prune [--dry-run] [--json]\n", stderr); return 1
        }
        let dryRun = args.contains("--dry-run")
        let allPaths = catalog.allImages().map { $0.path }
        var exists = [Bool](repeating: true, count: allPaths.count)
        exists.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }   // leerer Katalog
            DispatchQueue.concurrentPerform(iterations: allPaths.count) { idx in
                base[idx] = FileManager.default.fileExists(atPath: allPaths[idx])
            }
        }
        let missing = zip(allPaths, exists).filter { !$0.1 }.map { $0.0 }.sorted()
        if !dryRun && !missing.isEmpty { removeCatalogEntries(missing, catalog: catalog) }
        if jsonMode {
            let obj: [String: Any] = ["missing": missing, "count": missing.count,
                                      "checked": allPaths.count, "dry_run": dryRun, "ok": true]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else {
            missing.forEach { print($0) }
            if dryRun {
                print("Fehlende Dateien: \(missing.count) von \(allPaths.count) (Probelauf, nichts entfernt)")
            } else {
                print("Aus Katalog entfernt: \(missing.count) von \(allPaths.count) Bild(er) (Datei fehlt)")
            }
        }
        return 0

    case "cameras":
        // catalog cameras [--json] — Bilder pro Kamera (Make + Model), ein Durchlauf O(N)
        let unknownFlags = args.dropFirst().filter { $0 != "--json" }
        guard unknownFlags.isEmpty else {
            fputs("Verwendung: iphoto-cli catalog cameras [--json]\n", stderr); return 1
        }
        var buckets: [String: (count: Int, raw: Int, bytes: Int64)] = [:]
        var unknown = 0
        let images = catalog.allImages()
        for img in images {
            let cam = [img.cameraMake, img.cameraModel]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if cam.isEmpty { unknown += 1; continue }
            var b = buckets[cam] ?? (count: 0, raw: 0, bytes: 0)
            b.count += 1
            if img.isRAW { b.raw += 1 }
            b.bytes += img.sizeBytes
            buckets[cam] = b
        }
        let sorted = buckets.sorted { $0.value.count != $1.value.count ? $0.value.count > $1.value.count : $0.key < $1.key }
        if jsonMode {
            let arr: [[String: Any]] = sorted.map {
                ["camera": $0.key, "count": $0.value.count, "raw": $0.value.raw, "size_bytes": $0.value.bytes] as [String: Any]
            }
            let obj: [String: Any] = ["cameras": arr, "unknown": unknown, "total": images.count]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else if images.isEmpty {
            print("(keine Bilder im Katalog)")
        } else {
            for (cam, b) in sorted { print(String(format: "%6ld  (%ld RAW)  ", b.count, b.raw) + cam) }
            if unknown > 0 { print(String(format: "%6ld  ", unknown) + "(ohne Kamera-Angabe)") }
            print("Kameras: \(sorted.count)  Bilder: \(images.count)")
        }
        return 0

    case "timeline":
        // catalog timeline [--by year|month|day] [--json] — Bilder pro Aufnahmezeitraum
        var granularity = "month"
        var rest = Array(args.dropFirst())
        if let bi = rest.firstIndex(of: "--by") {
            guard bi + 1 < rest.count, ["year", "month", "day"].contains(rest[bi + 1]) else {
                fputs("Fehler: --by erwartet year, month oder day\n", stderr); return 1
            }
            granularity = rest[bi + 1]
            rest.removeSubrange(bi...(bi + 1))
        }
        guard rest.allSatisfy({ $0 == "--json" }) else {
            fputs("Verwendung: iphoto-cli catalog timeline [--by year|month|day] [--json]\n", stderr); return 1
        }
        let prefixLen = granularity == "year" ? 4 : (granularity == "month" ? 7 : 10)
        var buckets: [String: Int] = [:]
        var undated = 0
        let images = catalog.allImages()
        for img in images {
            // EXIF "YYYY:MM:DD HH:MM:SS" oder ISO "YYYY-MM-DDTHH:MM:SS" → "YYYY-MM-DD"
            guard let raw = img.dateTaken, raw.count >= 10 else { undated += 1; continue }
            let datePart = String(raw.prefix(10)).replacingOccurrences(of: ":", with: "-")
            let comps = datePart.split(separator: "-")
            guard comps.count == 3, comps[0].count == 4, comps[1].count == 2, comps[2].count == 2,
                  comps.allSatisfy({ part in part.allSatisfy { ch in ch.isNumber } }),
                  !datePart.hasPrefix("0000") else { undated += 1; continue }
            buckets[String(datePart.prefix(prefixLen)), default: 0] += 1
        }
        let sorted = buckets.sorted { $0.key < $1.key }
        if jsonMode {
            let arr: [[String: Any]] = sorted.map { ["period": $0.key, "count": $0.value] as [String: Any] }
            let obj: [String: Any] = ["by": granularity, "periods": arr,
                                      "undated": undated, "total": images.count]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else if images.isEmpty {
            print("(keine Bilder im Katalog)")
        } else {
            let maxCount = max(sorted.map { $0.value }.max() ?? 1, 1)
            for (period, n) in sorted {
                let bar = String(repeating: "█", count: max(1, n * 40 / maxCount))
                print("\(period.padding(toLength: 10, withPad: " ", startingAt: 0)) \(String(format: "%6ld", n))  \(bar)")
            }
            if undated > 0 { print("ohne Datum \(String(format: "%6ld", undated))") }
        }
        return 0

    case "orphans":
        // catalog orphans [--fix] [--json]
        // Integritäts-Check: Bewertungen, Papierkorb-, Album-, Anpassungs- und Gesichts-Zeilen,
        // deren Bild nicht (mehr) im Katalog steht, plus Album-Zuordnungen auf gelöschte Alben.
        // Ohne --fix nur Bericht; mit --fix werden die Zeilen in einer Transaktion gelöscht.
        let rest = Array(args.dropFirst())
        guard rest.allSatisfy({ $0 == "--json" || $0 == "--fix" }) else {
            fputs("Verwendung: iphoto-cli catalog orphans [--fix] [--json]\n", stderr); return 1
        }
        let fix = rest.contains("--fix")
        let orphans = catalog.orphanRows()
        let keys = CatalogStore.orphanChecks.map { $0.key }
        let counts = orphans.mapValues { $0.count }
        let total = counts.values.reduce(0, +)
        let removed: [String: Int] = (fix && total > 0) ? catalog.deleteOrphanRows() : [:]
        if jsonMode {
            var obj: [String: Any] = ["orphans": orphans, "counts": counts, "total": total,
                                      "fixed": fix, "ok": true]
            if fix { obj["removed"] = removed.isEmpty ? Dictionary(uniqueKeysWithValues: keys.map { ($0, 0) }) : removed }
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { print(s) }
        } else if total == 0 {
            print("Keine verwaisten Einträge — Katalog konsistent")
        } else {
            for k in keys {
                guard let list = orphans[k], !list.isEmpty else { continue }
                print("\(k) (\(list.count)):")
                list.forEach { print("  \($0)") }
            }
            if fix {
                let n = removed.values.reduce(0, +)
                print("Entfernt: \(n) verwaiste Zeile(n)")
            } else {
                print("Verwaist: \(total) Eintrag/Einträge (Bericht; --fix zum Entfernen)")
            }
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli catalog stats|path|vacuum|export|scan-needed|backup-now|list|remove|get|add|prune|cameras|timeline|orphans [--json]\n", stderr)
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

    case "match":
        // Duell zwischen zwei Bildern — nutzt dieselbe EloRating.update-Logik wie der Duell-Modus der App.
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        let usage = "Verwendung: iphoto-cli elo match <links> <rechts> [--winner left|right|draw] [--json]\n"
        guard positional.count >= 2 else { fputs(usage, stderr); return 1 }
        let leftPath = positional[0], rightPath = positional[1]
        guard leftPath != rightPath else {
            fputs("Fehler: Ein Bild kann nicht gegen sich selbst antreten\n", stderr); return 1
        }
        var winner = "left"
        if let wi = args.firstIndex(of: "--winner") {
            guard wi + 1 < args.count else { fputs(usage, stderr); return 1 }
            winner = args[wi + 1].lowercased()
        }
        let leftScore: Double
        switch winner {
        case "left":  leftScore = 1.0
        case "right": leftScore = 0.0
        case "draw":  leftScore = 0.5
        default:
            fputs("Fehler: Ungültiger --winner '\(winner)'. Erlaubt: left, right, draw\n", stderr); return 1
        }
        let l = catalog.elo(forPath: leftPath) ?? (elo: EloRating.initial, matches: 0)
        let r = catalog.elo(forPath: rightPath) ?? (elo: EloRating.initial, matches: 0)
        let res = EloRating.update(leftRating: l.elo, leftMatches: l.matches,
                                   rightRating: r.elo, rightMatches: r.matches,
                                   leftScore: leftScore)
        catalog.saveElo(path: leftPath, elo: res.left, eloMatches: l.matches + 1)
        catalog.saveElo(path: rightPath, elo: res.right, eloMatches: r.matches + 1)
        if jsonMode {
            let d: [String: Any] = [
                "winner": winner,
                "left":  ["path": leftPath,  "before": l.elo, "elo": res.left,  "matches": l.matches + 1] as [String: Any],
                "right": ["path": rightPath, "before": r.elo, "elo": res.right, "matches": r.matches + 1] as [String: Any],
                "ok": true
            ]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            print(String(format: "Links:  %.1f → %.1f  %@", l.elo, res.left, leftPath))
            print(String(format: "Rechts: %.1f → %.1f  %@", r.elo, res.right, rightPath))
        }
        return 0

    case "reset":
        let resetAll = args.contains("--all")
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
        var targets: [String]
        if resetAll {
            targets = Array(catalog.allElos().keys).sorted()
        } else {
            guard !positional.isEmpty else {
                fputs("Verwendung: iphoto-cli elo reset <bildpfad> [<bildpfad>...] | --all [--json]\n", stderr); return 1
            }
            targets = []
            for p in positional {
                guard catalog.elo(forPath: p) != nil else {
                    fputs("Fehler: Kein ELO-Eintrag für '\(p)'\n", stderr); return 1
                }
                targets.append(p)
            }
        }
        for p in targets { catalog.saveElo(path: p, elo: EloRating.initial, eloMatches: 0) }
        if jsonMode {
            let d: [String: Any] = ["reset": targets.count, "paths": targets, "elo": EloRating.initial, "ok": true]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: []),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            print("\(targets.count) ELO-Eintrag/Einträge auf \(Int(EloRating.initial)) zurückgesetzt")
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli elo get|list|set|match|reset [opts]\n", stderr)
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
    var batch: [(path: String, rating: Int, flag: String, colorLabel: String)] = []
    batch.reserveCapacity(paths.count)
    for path in paths {
        let existing = catalog.rating(forPath: path)
        let r = ratingValue ?? (existing?.rating ?? 0)
        let f = flagValue != "none" ? flagValue : (existing?.flag ?? "none")
        let c = colorValue != "none" ? colorValue : (existing?.colorLabel ?? "none")
        batch.append((path, r, f, c))
        results.append(["path": path, "rating": r, "flag": f, "color": c])
    }
    catalog.saveRatings(batch)   // eine Transaktion statt N Commits
    if jsonMode {
        let obj: [String: Any] = ["count": paths.count, "results": results, "ok": true]
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
           let s = String(data: d, encoding: .utf8) { print(s) }
    } else {
        print("\(paths.count) Bild(er) bewertet")
    }
    return 0
}

// MARK: - Rating Export / Import CLI

private func ratingCSVField(_ s: String) -> String {
    if s.contains(",") || s.contains("\"") || s.contains("\n") {
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return s
}

/// Minimaler RFC-4180-Zeilenparser (Anführungszeichen, verdoppelte Quotes).
private func ratingCSVParseLine(_ line: String) -> [String] {
    var fields: [String] = []
    var cur = ""
    var inQuotes = false
    var chars = Array(line)
    var i = 0
    if chars.last == "\r" { chars.removeLast() }
    while i < chars.count {
        let c = chars[i]
        if inQuotes {
            if c == "\"" {
                if i + 1 < chars.count, chars[i + 1] == "\"" { cur.append("\""); i += 1 }
                else { inQuotes = false }
            } else { cur.append(c) }
        } else {
            if c == "\"" { inQuotes = true }
            else if c == "," { fields.append(cur); cur = "" }
            else { cur.append(c) }
        }
        i += 1
    }
    fields.append(cur)
    return fields
}

private func printRatingJSON(_ obj: [String: Any]) {
    if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
       let s = String(data: d, encoding: .utf8) { print(s) }
}

private func runRatingExport(_ args: [String]) -> Int32 {
    var jsonMode = false
    var outputPath: String? = nil
    var format: String? = nil
    var includeUnrated = false
    var i = 0
    while i < args.count {
        switch args[i] {
        case "--json": jsonMode = true; i += 1
        case "--include-unrated": includeUnrated = true; i += 1
        case "--output", "-o":
            guard i + 1 < args.count else { fputs("Fehler: --output braucht einen Pfad\n", stderr); return 1 }
            outputPath = args[i + 1]; i += 2
        case "--format":
            guard i + 1 < args.count else { fputs("Fehler: --format braucht json|csv\n", stderr); return 1 }
            format = args[i + 1].lowercased(); i += 2
        default:
            fputs("Fehler: Unbekannte Option '\(args[i])'\n", stderr)
            fputs("Verwendung: iphoto-cli rating export [--output <datei.json|.csv>] [--format json|csv] [--include-unrated] [--json]\n", stderr)
            return 1
        }
    }
    let fmt = format ?? ((outputPath?.lowercased().hasSuffix(".csv") ?? false) ? "csv" : "json")
    guard fmt == "json" || fmt == "csv" else {
        fputs("Fehler: Ungültiges Format '\(fmt)'. Erlaubt: json, csv\n", stderr); return 1
    }

    let catalog = CatalogStore(dbPath: envDBPath())
    let all = catalog.allRatings()
    let entries = all
        .filter { includeUnrated || $0.value.rating > 0 || $0.value.flag != "none" || $0.value.colorLabel != "none" }
        .sorted { $0.key < $1.key }

    let content: String
    if fmt == "csv" {
        var lines = ["path,rating,flag,color"]
        lines.reserveCapacity(entries.count + 1)
        for (p, v) in entries {
            lines.append("\(ratingCSVField(p)),\(v.rating),\(v.flag),\(v.colorLabel)")
        }
        content = lines.joined(separator: "\n") + "\n"
    } else {
        let arr = entries.map { (path, e) -> [String: Any] in
            ["path": path, "rating": e.rating, "flag": e.flag, "color": e.colorLabel]
        }
        let obj: [String: Any] = ["version": 1, "count": arr.count, "ratings": arr]
        guard let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: d, encoding: .utf8) else {
            fputs("Fehler: JSON-Serialisierung fehlgeschlagen\n", stderr); return 1
        }
        content = s + "\n"
    }

    guard let out = outputPath else {
        // Ohne --output: Inhalt direkt auf stdout (für Pipes)
        print(content, terminator: "")
        return 0
    }
    do {
        try content.write(toFile: out, atomically: true, encoding: .utf8)
    } catch {
        fputs("Fehler: Konnte '\(out)' nicht schreiben: \(error.localizedDescription)\n", stderr); return 1
    }
    if jsonMode {
        printRatingJSON(["ok": true, "count": entries.count, "format": fmt, "output": out])
    } else {
        print("\(entries.count) Bewertung(en) exportiert nach \(out) (\(fmt))")
    }
    return 0
}

private func runRatingImport(_ args: [String]) -> Int32 {
    var jsonMode = false
    var dryRun = false
    var skipExisting = false
    var inputPath: String? = nil
    for a in args {
        switch a {
        case "--json": jsonMode = true
        case "--dry-run": dryRun = true
        case "--skip-existing": skipExisting = true
        default:
            if a.hasPrefix("-") {
                fputs("Fehler: Unbekannte Option '\(a)'\n", stderr); return 1
            }
            if inputPath != nil { fputs("Fehler: Nur eine Eingabedatei erlaubt\n", stderr); return 1 }
            inputPath = a
        }
    }
    guard let input = inputPath else {
        fputs("Verwendung: iphoto-cli rating import <datei.json|.csv> [--skip-existing] [--dry-run] [--json]\n", stderr)
        return 1
    }
    guard let data = FileManager.default.contents(atPath: input),
          let text = String(data: data, encoding: .utf8) else {
        fputs("Fehler: Datei nicht lesbar: \(input)\n", stderr); return 1
    }

    // Rohe Einträge sammeln (JSON oder CSV, per Inhalt erkannt)
    var raw: [(line: Int, path: String, rating: String, flag: String, color: String)] = []
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else {
            fputs("Fehler: Ungültiges JSON in \(input)\n", stderr); return 1
        }
        let list: [Any]
        if let arr = obj as? [Any] { list = arr }
        else if let dict = obj as? [String: Any], let arr = dict["ratings"] as? [Any] { list = arr }
        else { fputs("Fehler: JSON braucht ein Array oder {\"ratings\": [...]}\n", stderr); return 1 }
        for (idx, item) in list.enumerated() {
            guard let d = item as? [String: Any] else {
                raw.append((idx + 1, "", "", "", "")); continue
            }
            let r: String
            if let s = d["rating"] as? String { r = s }
            else if let v = d["rating"] { r = "\(v)" }   // NSNumber → "4" bzw. "4.5" (→ ungültig)
            else { r = "0" }
            raw.append((idx + 1, d["path"] as? String ?? "", r,
                        (d["flag"] as? String) ?? "none",
                        (d["color"] as? String) ?? (d["colorLabel"] as? String) ?? "none"))
        }
    } else {
        let lines = text.components(separatedBy: "\n")
        var lineNo = 0
        for line in lines {
            lineNo += 1
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let f = ratingCSVParseLine(line)
            if lineNo == 1, f.first?.lowercased() == "path" { continue }  // Header
            raw.append((lineNo, f.count > 0 ? f[0] : "", f.count > 1 ? f[1] : "0",
                        f.count > 2 && !f[2].isEmpty ? f[2] : "none",
                        f.count > 3 && !f[3].isEmpty ? f[3] : "none"))
        }
    }

    // Validieren — bei Fehlern wird nichts geschrieben (atomar)
    var valid: [(path: String, rating: Int, flag: String, colorLabel: String)] = []
    var errors: [String] = []
    var seen: [String: Int] = [:]
    for e in raw {
        let flag = e.flag.lowercased(), color = e.color.lowercased()
        if e.path.isEmpty { errors.append("Eintrag \(e.line): Pfad fehlt"); continue }
        guard let r = Int(e.rating.trimmingCharacters(in: .whitespaces)), (0...5).contains(r) else {
            errors.append("Eintrag \(e.line): ungültige Bewertung '\(e.rating)' (0–5)"); continue
        }
        guard FlagStatus(rawValue: flag) != nil else {
            errors.append("Eintrag \(e.line): ungültiges Flag '\(e.flag)'"); continue
        }
        guard ColorLabel(rawValue: color) != nil else {
            errors.append("Eintrag \(e.line): ungültige Farbe '\(e.color)'"); continue
        }
        // Doppelte Pfade: letzter gewinnt (O(1) via Dictionary statt firstIndex)
        if let idx = seen[e.path] { valid[idx] = (e.path, r, flag, color) }
        else { seen[e.path] = valid.count; valid.append((e.path, r, flag, color)) }
    }
    if !errors.isEmpty {
        if jsonMode {
            printRatingJSON(["ok": false, "errors": errors, "imported": 0, "skipped": 0])
        }
        for err in errors { fputs("Fehler: \(err)\n", stderr) }
        fputs("Import abgebrochen — keine Bewertung geschrieben\n", stderr)
        return 1
    }

    let catalog = CatalogStore(dbPath: envDBPath())
    var toWrite = valid
    var skipped = 0
    if skipExisting {
        let existing = catalog.allRatings()   // ein Query statt N Einzel-Lookups
        toWrite = valid.filter { existing[$0.path] == nil }
        skipped = valid.count - toWrite.count
    }
    if !dryRun { catalog.saveRatings(toWrite) }

    if jsonMode {
        printRatingJSON(["ok": true, "imported": toWrite.count, "skipped": skipped,
                         "dry_run": dryRun, "errors": [String]()])
    } else {
        let prefix = dryRun ? "[Probelauf] " : ""
        print("\(prefix)\(toWrite.count) Bewertung(en) importiert, \(skipped) übersprungen")
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

    case "set":
        // motif set <bildpfad> <tag1,tag2,...> — manuelle Korrektur der Motiv-Tags.
        let positional = args.dropFirst().filter { !$0.hasPrefix("--") }
        guard positional.count >= 2 else {
            fputs("Verwendung: iphoto-cli motif set <bildpfad> <tag1,tag2,...> [--json]\n", stderr); return 1
        }
        let path = positional[positional.startIndex]
        guard catalog.image(forPath: path) != nil else {
            fputs("Fehler: Bild nicht im Katalog: \(path)\n", stderr); return 1
        }
        // Normalisieren: trimmen, lowercase, leere entfernen, Reihenfolge-stabil deduplizieren.
        var seen = Set<String>()
        let tags = positional.dropFirst()
            .flatMap { $0.split(separator: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        catalog.upsertMotifs(path: path, tags: tags)
        if jsonMode {
            let d: [String: Any] = ["path": path, "motifs": tags, "ok": true]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            print(tags.isEmpty ? "Motiv-Tags geleert: \(path)" : "Motiv-Tags gesetzt: \(tags.joined(separator: ", "))")
        }
        return 0

    case "find":
        guard let tag = args.dropFirst().first(where: { !$0.hasPrefix("-") })?
                .trimmingCharacters(in: .whitespaces).lowercased(), !tag.isEmpty else {
            fputs("Verwendung: iphoto-cli motif find <tag> [--json]\n", stderr); return 1
        }
        // Ein einziger SELECT über alle Motive, Filter in-memory (O(N)).
        let paths = catalog.allMotifs().filter { $0.tags.contains(tag) }.map { $0.path }
        if jsonMode {
            let d: [String: Any] = ["tag": tag, "count": paths.count, "paths": paths]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            if paths.isEmpty { print("(keine Bilder mit Motiv '\(tag)')") }
            else { paths.forEach { print($0) } }
        }
        return 0

    case "stats":
        var counts: [String: Int] = [:]
        let all = catalog.allMotifs()
        for entry in all { for t in entry.tags { counts[t, default: 0] += 1 } }
        let sorted = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        if jsonMode {
            let arr = sorted.map { ["tag": $0.key, "count": $0.value] as [String: Any] }
            let d: [String: Any] = ["images": all.count, "tags": arr]
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else {
            if sorted.isEmpty { print("(keine Motiv-Tags im Katalog)") }
            else {
                print("\(all.count) Bild(er) mit Motiv-Tags")
                sorted.forEach { e in
                    let n = String(e.value)
                    print(String(repeating: " ", count: max(0, 6 - n.count)) + n + "  " + e.key)
                }
            }
        }
        return 0

    case "rename", "remove":
        // motif rename <alt> <neu> | motif remove <tag> — Tag katalogweit umbenennen/entfernen.
        // Ein SELECT über alle Motive, Änderung in-memory, ein Batch-UPDATE in einer Transaktion.
        let isRename = sub == "rename"
        let dryRun = args.contains("--dry-run")
        let known: Set<String> = ["--json", "--dry-run"]
        if let bad = args.dropFirst().first(where: { $0.hasPrefix("-") && !known.contains($0) }) {
            fputs("Fehler: Unbekannte Option '\(bad)'\n", stderr); return 1
        }
        let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let usage = isRename
            ? "Verwendung: iphoto-cli motif rename <alt> <neu> [--dry-run] [--json]\n"
            : "Verwendung: iphoto-cli motif remove <tag> [--dry-run] [--json]\n"
        guard positional.count == (isRename ? 2 : 1), !positional.contains(where: { $0.isEmpty }) else {
            fputs(usage, stderr); return 1
        }
        let oldTag = positional[0]
        let newTag: String? = isRename ? positional[1] : nil
        if let n = newTag, n.contains(",") {
            fputs("Fehler: Tag darf kein Komma enthalten: \(n)\n", stderr); return 1
        }
        if let n = newTag, n == oldTag {
            fputs("Fehler: Alter und neuer Tag sind identisch: \(n)\n", stderr); return 1
        }
        var changes: [(path: String, tags: [String])] = []
        for entry in catalog.allMotifs() where entry.tags.contains(oldTag) {
            var seen = Set<String>()
            let updated = entry.tags
                .compactMap { (t: String) -> String? in t == oldTag ? newTag : t }
                .filter { seen.insert($0).inserted }
            changes.append((entry.path, updated))
        }
        if !dryRun { catalog.upsertMotifsBatch(changes) }
        if jsonMode {
            var d: [String: Any] = ["tag": oldTag, "count": changes.count,
                                    "paths": changes.map { $0.path }, "dryRun": dryRun]
            if let n = newTag { d["newTag"] = n }
            if let dd = try? JSONSerialization.data(withJSONObject: d, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: dd, encoding: .utf8) { print(s) }
        } else if changes.isEmpty {
            print("(keine Bilder mit Motiv '\(oldTag)')")
        } else {
            let verb = isRename ? "'\(oldTag)' → '\(newTag!)' umbenannt" : "'\(oldTag)' entfernt"
            print("\(dryRun ? "[Probelauf] " : "")\(verb) in \(changes.count) Bild(ern)")
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli motif get|list|set|find|stats|rename|remove [--json]\n", stderr)
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

    case "stats":
        // Ausrüstungs-/Aufnahme-Statistik: Häufigkeiten je EXIF-Feld per GROUP BY.
        let fieldMap: [(key: String, column: String, label: String)] = [
            ("camera", "camera_model", "Kamera"), ("lens", "lens_model", "Objektiv"),
            ("focal", "focal_length", "Brennweite"), ("aperture", "aperture", "Blende"),
            ("iso", "iso", "ISO"), ("film", "film_simulation", "Filmsimulation")]
        var selected = fieldMap
        var limit = 0
        var i = 0
        while i < rest.count {
            let a = rest[i]
            switch a {
            case "--by":
                guard i + 1 < rest.count else { fputs("Fehler: --by braucht einen Wert\n", stderr); return 1 }
                let keys = rest[i + 1].lowercased().split(separator: ",").map { String($0) }
                let unknown = keys.filter { k in !fieldMap.contains { $0.key == k } }
                if keys.isEmpty || !unknown.isEmpty {
                    fputs("Fehler: Unbekanntes Feld '\(unknown.joined(separator: ","))' — erlaubt: \(fieldMap.map { $0.key }.joined(separator: ", "))\n", stderr)
                    return 1
                }
                selected = fieldMap.filter { keys.contains($0.key) }
                i += 2
            case "--limit":
                guard i + 1 < rest.count, let n = Int(rest[i + 1]), n > 0 else {
                    fputs("Fehler: --limit erwartet eine positive Zahl\n", stderr); return 1
                }
                limit = n; i += 2
            default:
                fputs("Fehler: Unbekannte Option '\(a)'\n", stderr)
                fputs("Verwendung: iphoto-cli exif stats [--by lens|iso|aperture|focal|film|camera] [--limit N] [--json]\n", stderr)
                return 1
            }
        }
        let catalog = CatalogStore(dbPath: envDBPath())
        let total = catalog.imageCount()
        // REAL-Spalten liefern "35.0" — ganzzahlige Werte ohne Nachkomma ausgeben.
        func tidy(_ v: String) -> String { v.hasSuffix(".0") ? String(v.dropLast(2)) : v }
        var results: [(key: String, label: String, rows: [(value: String, count: Int)], distinct: Int)] = []
        for f in selected {
            let all = catalog.exifDistribution(column: f.column).map { (value: tidy($0.value), count: $0.count) }
            results.append((key: f.key, label: f.label, rows: limit > 0 ? Array(all.prefix(limit)) : all, distinct: all.count))
        }
        if jsonMode {
            var fields: [String: Any] = [:]
            for r in results {
                fields[r.key] = ["distinct": r.distinct,
                                 "values": r.rows.map { ["value": $0.value, "count": $0.count] as [String: Any] }] as [String: Any]
            }
            printExifJSON(["images": total, "fields": fields] as [String: Any])
        } else {
            print("Bilder im Katalog: \(total)")
            for r in results {
                print("")
                print("\(r.label) (\(r.distinct) verschiedene):")
                if r.rows.isEmpty { print("  (keine Daten)"); continue }
                let width = r.rows.map { $0.value.count }.max() ?? 0
                for row in r.rows {
                    let pct = total > 0 ? Double(row.count) * 100 / Double(total) : 0
                    print("  \(row.value.padding(toLength: width, withPad: " ", startingAt: 0))  \(String(format: "%5d", row.count))  \(String(format: "%5.1f%%", pct))")
                }
            }
        }
        return 0

    default:
        fputs("Verwendung: iphoto-cli exif get|set|films|stats ... [--json]\n", stderr)
        return 1
    }
}

// MARK: - query (App-Suchsyntax: bewertung:5 typ:raw elo:>=1600 …)

private let queryRawExts: Set<String> = ["cr2","cr3","nef","nrw","arw","srf","sr2","dng","orf","rw2","raf","pef","srw","erf","kdc","dcr","raw","rwl","mrw","3fr","mef","iiq","x3f"]

private func queryDateParse(_ s: String) -> Date? {
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.timeZone = TimeZone(identifier: "UTC")
    if s.count == 4 { fmt.dateFormat = "yyyy";    return fmt.date(from: s) }
    if s.count == 7 { fmt.dateFormat = "yyyy-MM"; return fmt.date(from: s) }
    fmt.dateFormat = "yyyy-MM-dd"; return fmt.date(from: s)
}

/// Parst date_taken aus dem Katalog (EXIF "yyyy:MM:dd HH:mm:ss" oder ISO-ähnlich).
private func queryDateKey(_ raw: String?) -> Date {
    guard let raw = raw, !raw.isEmpty else { return Date.distantPast }
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.timeZone = TimeZone(identifier: "UTC")
    for f in ["yyyy:MM:dd HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
        fmt.dateFormat = f
        if let d = fmt.date(from: String(raw.prefix(f.replacingOccurrences(of: "'", with: "").count))) { return d }
    }
    return Date.distantPast
}

private let queryColorMap: [String: String] = ["rot": "red", "gelb": "yellow", "grün": "green", "gruen": "green", "blau": "blue"]

private func queryEloPredicate(_ val: String) -> ((Double) -> Bool)? {
    if val.hasPrefix(">="), let t = Double(val.dropFirst(2)) { return { $0 >= t } }
    if val.hasPrefix("<="), let t = Double(val.dropFirst(2)) { return { $0 <= t } }
    if val.hasPrefix(">"),  let t = Double(val.dropFirst(1)) { return { $0 >  t } }
    if val.hasPrefix("<"),  let t = Double(val.dropFirst(1)) { return { $0 <  t } }
    if let t = Double(val) { return { $0 >= t } }
    return nil
}

/// Validiert einen Filter-Wert; nil = gültig, sonst Fehlermeldung.
private func queryValidate(_ tok: SearchToken) -> String? {
    let val = tok.value.lowercased()
    switch tok.key {
    case "bewertung":
        guard let r = Int(val), (0...5).contains(r) else { return "bewertung:\(tok.value) — erwartet 0–5" }
    case "vor", "nach":
        guard queryDateParse(val) != nil else { return "\(tok.key):\(tok.value) — erwartet JJJJ, JJJJ-MM oder JJJJ-MM-TT" }
    case "markiert":
        guard ["pick", "reject", "ja", "nein"].contains(val) else { return "markiert:\(tok.value) — erwartet pick, reject, ja, nein" }
    case "unscharf":
        guard ["ja", "nein"].contains(val) else { return "unscharf:\(tok.value) — erwartet ja, nein" }
    case "elo":
        guard queryEloPredicate(val) != nil else { return "elo:\(tok.value) — erwartet z.B. >=1600, <1500, 1700" }
    case "farbe":
        guard queryColorMap[val] != nil else { return "farbe:\(tok.value) — erwartet rot, gelb, grün, blau" }
    default: break
    }
    return nil
}

private func printQueryJSON(_ obj: Any) {
    if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
       let s = String(data: d, encoding: .utf8) { print(s) }
}

private func runQuery(_ args: [String]) -> Int32 {
    let jsonMode = args.contains("--json")
    let sub = args.first ?? ""
    var rest = Array(args.dropFirst()).filter { $0 != "--json" }

    switch sub {
    case "filters":
        if jsonMode {
            printQueryJSON(FilterDefinition.all.map {
                ["key": $0.key, "label": $0.label, "hint": $0.hint, "suggestions": $0.valueSuggestions] as [String: Any]
            })
        } else {
            for f in FilterDefinition.all {
                print("\(f.key.padding(toLength: 10, withPad: " ", startingAt: 0)) \(f.label.padding(toLength: 16, withPad: " ", startingAt: 0)) \(f.hint)")
            }
        }
        return 0

    case "parse":
        let raw = rest.joined(separator: " ")
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else {
            fputs("Verwendung: iphoto-cli query parse <suchtext> [--json]\n", stderr); return 1
        }
        let q = SearchQuery.parse(raw)
        let warnings = q.filters.compactMap { queryValidate($0) }
        if jsonMode {
            printQueryJSON([
                "raw": q.raw,
                "free_text": q.freeText,
                "filters": q.filters.map { ["key": $0.key, "value": $0.value] },
                "warnings": warnings,
            ] as [String: Any])
        } else {
            print("Freitext: \(q.freeText.isEmpty ? "—" : q.freeText)")
            if q.filters.isEmpty { print("Filter:   —") }
            for f in q.filters { print("Filter:   \(f.key) = \(f.value)") }
            for w in warnings { print("Warnung:  \(w)") }
        }
        return 0

    case "run":
        var blurT = 80.0
        if let bi = rest.firstIndex(of: "--blur-threshold") {
            guard bi + 1 < rest.count, let v = Double(rest[bi + 1]), v > 0 else {
                fputs("Fehler: --blur-threshold braucht eine positive Zahl\n", stderr); return 1
            }
            blurT = v
            rest.removeSubrange(bi...(bi + 1))
        }
        let includeTrashed = rest.contains("--include-trashed")
        rest.removeAll { $0 == "--include-trashed" }
        let raw = rest.joined(separator: " ")
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else {
            fputs("Verwendung: iphoto-cli query run <suchtext> [--blur-threshold N] [--include-trashed] [--json]\n", stderr); return 1
        }
        let q = SearchQuery.parse(raw)
        let errors = q.filters.compactMap { queryValidate($0) }
        guard errors.isEmpty else {
            errors.forEach { fputs("Fehler: Ungültiger Filter \($0)\n", stderr) }
            return 1
        }

        let catalog = CatalogStore(dbPath: envDBPath())
        var result = catalog.allImages()
        if !includeTrashed {
            let trashed = catalog.trashedPaths()
            if !trashed.isEmpty { result = result.filter { !trashed.contains($0.path) } }
        }
        // Lookup-Tabellen nur laden, wenn ein Filter sie braucht (je ein Bulk-SELECT, kein N+1).
        let keys = Set(q.filters.map { $0.key })
        let needRatings = keys.contains("bewertung") || keys.contains("markiert") || keys.contains("farbe")
        let ratings: [String: (rating: Int, flag: String, colorLabel: String)] = needRatings ? catalog.allRatings() : [:]
        let elos: [String: (elo: Double, matches: Int)] = keys.contains("elo") ? catalog.allElos() : [:]
        let motifs: [String: [String]] = keys.contains("motiv")
            ? Dictionary(catalog.allMotifs().map { ($0.path, $0.tags) }, uniquingKeysWith: { a, _ in a }) : [:]
        let quality: [String: QualityRecord] = keys.contains("unscharf") ? catalog.allQualityRecords() : [:]

        if !q.freeText.isEmpty {
            let t = q.freeText.lowercased()
            result = result.filter { img in
                img.filename.lowercased().contains(t)
                || (img.cameraModel?.lowercased().contains(t) ?? false)
                || (img.cameraMake?.lowercased().contains(t) ?? false)
            }
        }

        for f in q.filters {
            let val = f.value.lowercased()
            switch f.key {
            case "bewertung":
                let r = Int(val)!
                result = result.filter { (ratings[$0.path]?.rating ?? 0) == r }
            case "typ":
                if val == "raw" {
                    result = result.filter { $0.isRAW || queryRawExts.contains(($0.path as NSString).pathExtension.lowercased()) }
                } else {
                    let alt: Set<String> = val == "jpg" ? ["jpg", "jpeg"] : (val == "tiff" ? ["tif", "tiff"] : [val])
                    result = result.filter { alt.contains(($0.path as NSString).pathExtension.lowercased()) }
                }
            case "vor":
                let d = queryDateParse(val)!
                result = result.filter { queryDateKey($0.dateTaken) < d }
            case "nach":
                let d = queryDateParse(val)!
                result = result.filter { queryDateKey($0.dateTaken) > d }
            case "kamera":
                result = result.filter {
                    ($0.cameraModel?.lowercased().contains(val) ?? false) || ($0.cameraMake?.lowercased().contains(val) ?? false)
                }
            case "album":
                let ids = catalog.allAlbums().filter { $0.name.lowercased().contains(val) }.map { $0.id }
                var paths = Set<String>()
                for id in ids { paths.formUnion(catalog.images(inAlbum: id)) }
                result = result.filter { paths.contains($0.path) }
            case "markiert":
                result = result.filter {
                    let flag = ratings[$0.path]?.flag ?? "none"
                    switch val {
                    case "pick":   return flag == "pick"
                    case "reject": return flag == "reject"
                    case "ja":     return flag != "none"
                    default:       return flag == "none"
                    }
                }
            case "unscharf":
                let blurry: (String) -> Bool = { p in
                    guard let r = quality[p], !r.blurOverride, let s = r.blurScore else { return false }
                    return s < blurT
                }
                result = result.filter { val == "ja" ? blurry($0.path) : !blurry($0.path) }
            case "motiv":
                result = result.filter { img in motifs[img.path]?.contains { $0.lowercased().contains(val) } ?? false }
            case "elo":
                let pred = queryEloPredicate(val)!
                result = result.filter { pred(elos[$0.path]?.elo ?? EloRating.initial) }
            case "farbe":
                let c = queryColorMap[val]!
                result = result.filter { ratings[$0.path]?.colorLabel == c }
            default: break
            }
        }
        return printCatalogImages(result, jsonMode: jsonMode)

    default:
        fputs("Verwendung: iphoto-cli query filters|parse|run [--json]\n", stderr)
        return 1
    }
}

// MARK: - bookmarks (Security-Scoped-Bookmarks in bookmarks.json verwalten)

private func bookmarksFileURL() -> URL {
    if let override = ProcessInfo.processInfo.environment["IPHOTO_BOOKMARKS_FILE"], !override.isEmpty {
        return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
    }
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("iPhoto")
        .appendingPathComponent("bookmarks.json")
}

/// Lädt bookmarks.json im selben Format wie `BookmarkStore` ([absoluteString: Data]).
/// nil = Datei existiert, ist aber nicht dekodierbar; leeres Dict = Datei fehlt.
private func loadBookmarksFile(_ url: URL) -> [String: Data]? {
    guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
    guard let data = try? Data(contentsOf: url),
          let decoded = try? JSONDecoder().decode([String: Data].self, from: data) else { return nil }
    return decoded
}

private func saveBookmarksFile(_ dict: [String: Data], to url: URL) -> Bool {
    guard let data = try? JSONEncoder().encode(dict) else { return false }
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    return (try? data.write(to: url, options: .atomic)) != nil
}

/// Status eines Bookmark-Eintrags: ok, missing (Datei fehlt), offline (Volume nicht gemountet), invalid (kein file://-Key).
private func bookmarkStatus(key: String) -> (path: String?, status: String) {
    guard let u = URL(string: key), u.isFileURL else { return (nil, "invalid") }
    let path = u.path
    if FileManager.default.fileExists(atPath: path) { return (path, "ok") }
    // Externe Volumes: nicht gemountet ≠ gelöscht — solche Einträge nie automatisch entfernen.
    let comps = (path as NSString).pathComponents
    if comps.count >= 3, comps[1] == "Volumes" {
        let volRoot = "/Volumes/" + comps[2]
        if !FileManager.default.fileExists(atPath: volRoot) { return (path, "offline") }
    }
    return (path, "missing")
}

private func runBookmarks(_ args: [String]) -> Int32 {
    let sub = args.first ?? ""
    let jsonMode = args.contains("--json")
    let fileURL = bookmarksFileURL()
    let positional = args.dropFirst().filter { !$0.hasPrefix("-") }
    let flags = args.dropFirst().filter { $0.hasPrefix("-") }

    func checkFlags(_ allowed: [String]) -> Bool {
        for f in flags where !allowed.contains(f) {
            fputs("Fehler: Unbekannte Option: \(f)\n", stderr); return false
        }
        return true
    }
    func load() -> [String: Data]? {
        guard let d = loadBookmarksFile(fileURL) else {
            fputs("Fehler: bookmarks.json nicht lesbar: \(fileURL.path)\n", stderr); return nil
        }
        return d
    }

    switch sub {
    case "path":
        guard checkFlags(["--json"]) else { return 1 }
        if jsonMode { printBugReportJSON(["path": fileURL.path]) } else { print(fileURL.path) }
        return 0

    case "list":
        guard checkFlags(["--json", "--missing"]) else { return 1 }
        guard let dict = load() else { return 1 }
        let onlyBroken = args.contains("--missing")
        var rows: [[String: Any]] = []
        for key in dict.keys.sorted() {
            let st = bookmarkStatus(key: key)
            if onlyBroken && st.status == "ok" { continue }
            rows.append(["key": key, "path": st.path.map { $0 as Any } ?? NSNull(), "status": st.status,
                         "bytes": dict[key]?.count ?? 0])
        }
        if jsonMode {
            printBugReportJSON(rows)
        } else if rows.isEmpty {
            print(onlyBroken ? "(keine verwaisten Bookmarks)" : "(keine Bookmarks)")
        } else {
            for r in rows {
                let label = (r["path"] as? String) ?? (r["key"] as? String ?? "")
                print("[\(r["status"] as? String ?? "")] \(label)")
            }
        }
        return 0

    case "stats":
        guard checkFlags(["--json"]) else { return 1 }
        guard let dict = load() else { return 1 }
        var counts: [String: Int] = ["ok": 0, "missing": 0, "offline": 0, "invalid": 0]
        var totalBytes = 0
        for (key, data) in dict {
            counts[bookmarkStatus(key: key).status, default: 0] += 1
            totalBytes += data.count
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attrs?[.size] as? NSNumber)?.intValue ?? 0
        if jsonMode {
            printBugReportJSON(["total": dict.count, "ok": counts["ok"]!, "missing": counts["missing"]!,
                                "offline": counts["offline"]!, "invalid": counts["invalid"]!,
                                "bookmark_bytes": totalBytes, "file_bytes": fileSize, "path": fileURL.path] as [String: Any])
        } else {
            print("Bookmarks gesamt: \(dict.count)")
            print("  ok:       \(counts["ok"]!)")
            print("  fehlend:  \(counts["missing"]!)")
            print("  offline:  \(counts["offline"]!)")
            print("  ungültig: \(counts["invalid"]!)")
            print(String(format: "Dateigröße: %.1f KB", Double(fileSize) / 1024))
        }
        return 0

    case "remove":
        guard checkFlags(["--json"]) else { return 1 }
        guard !positional.isEmpty else {
            fputs("Verwendung: iphoto-cli bookmarks remove <pfad|file-url> [...] [--json]\n", stderr); return 1
        }
        guard var dict = load() else { return 1 }
        var removed: [String] = []
        var notFound: [String] = []
        for p in positional {
            // Pfad oder file://-URL akzeptieren; Key ist url.absoluteString wie im BookmarkStore.
            let key: String
            if p.hasPrefix("file://") { key = p }
            else { key = URL(fileURLWithPath: (p as NSString).expandingTildeInPath).absoluteString }
            if dict.removeValue(forKey: key) != nil { removed.append(key) }
            else if dict.removeValue(forKey: key + "/") != nil { removed.append(key + "/") }
            else { notFound.append(p) }
        }
        if !removed.isEmpty, !saveBookmarksFile(dict, to: fileURL) {
            fputs("Fehler: bookmarks.json konnte nicht geschrieben werden\n", stderr); return 1
        }
        if jsonMode {
            printBugReportJSON(["ok": notFound.isEmpty, "removed": removed, "not_found": notFound] as [String: Any])
        } else {
            for r in removed { print("Entfernt: \(r)") }
            for n in notFound { fputs("Nicht gefunden: \(n)\n", stderr) }
        }
        return notFound.isEmpty ? 0 : 1

    case "prune":
        guard checkFlags(["--json", "--dry-run"]) else { return 1 }
        guard var dict = load() else { return 1 }
        let dryRun = args.contains("--dry-run")
        var pruned: [String] = []
        var offline = 0
        for key in dict.keys.sorted() {
            switch bookmarkStatus(key: key).status {
            case "missing", "invalid": pruned.append(key)
            case "offline": offline += 1
            default: break
            }
        }
        if !dryRun && !pruned.isEmpty {
            for k in pruned { dict.removeValue(forKey: k) }
            guard saveBookmarksFile(dict, to: fileURL) else {
                fputs("Fehler: bookmarks.json konnte nicht geschrieben werden\n", stderr); return 1
            }
        }
        if jsonMode {
            printBugReportJSON(["dry_run": dryRun, "pruned": pruned.count, "kept": dict.count - (dryRun ? pruned.count : 0),
                                "offline_kept": offline, "keys": pruned] as [String: Any])
        } else {
            for k in pruned { print("\(dryRun ? "Würde entfernen" : "Entfernt"): \(k)") }
            print("\(pruned.count) verwaiste Bookmarks \(dryRun ? "gefunden" : "entfernt"); \(offline) offline (behalten)")
        }
        return 0

    default:
        fputs("""
        Verwendung:
          iphoto-cli bookmarks path [--json]
          iphoto-cli bookmarks list [--missing] [--json]
          iphoto-cli bookmarks stats [--json]
          iphoto-cli bookmarks remove <pfad|file-url> [...] [--json]
          iphoto-cli bookmarks prune [--dry-run] [--json]

        """, stderr)
        return 1
    }
}

// MARK: - bugreport (CrashReporter-Berichte in ~/Documents/bugreports verwalten)

private func bugReportDir() -> URL {
    if let override = ProcessInfo.processInfo.environment["IPHOTO_BUGREPORT_DIR"], !override.isEmpty {
        return URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/bugreports", isDirectory: true)
}

private struct BugReportEntry {
    let name: String
    let url: URL
    let fixed: Bool
    let size: Int64
    let modified: Date?
}

private func bugReportEntries(in dir: URL, fixed: Bool) -> [BugReportEntry] {
    let fm = FileManager.default
    let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
    guard let urls = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys,
                                                 options: [.skipsHiddenFiles]) else { return [] }
    var out: [BugReportEntry] = []
    for u in urls {
        guard let v = try? u.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
        out.append(BugReportEntry(name: u.lastPathComponent, url: u, fixed: fixed,
                                  size: Int64(v.fileSize ?? 0), modified: v.contentModificationDate))
    }
    // Dateinamen enthalten den Zeitstempel (iPhoto_Crash_yyyy-MM-dd_HHmmss) → neueste zuerst
    return out.sorted { $0.name > $1.name }
}

private func bugReportJSON(_ e: BugReportEntry) -> [String: Any] {
    var obj: [String: Any] = ["name": e.name, "path": e.url.path, "fixed": e.fixed, "size": e.size]
    if let m = e.modified { obj["modified"] = ISO8601DateFormatter().string(from: m) }
    return obj
}

private func printBugReportJSON(_ obj: Any) {
    if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
       let s = String(data: d, encoding: .utf8) { print(s) }
}

/// Nur reine Dateinamen zulassen — kein Pfad-Traversal aus dem Bugreport-Ordner heraus.
private func validBugReportName(_ name: String) -> Bool {
    !name.isEmpty && !name.contains("/") && name != "." && name != ".." && !name.hasPrefix(".")
}

private func runBugReport(_ args: [String]) -> Int32 {
    let sub = args.first ?? ""
    let jsonMode = args.contains("--json")
    let fm = FileManager.default
    let openDir = bugReportDir()
    let fixedDir = openDir.appendingPathComponent("fixed", isDirectory: true)
    let positional = args.dropFirst().filter { !$0.hasPrefix("-") }

    switch sub {
    case "path":
        if jsonMode { printBugReportJSON(["path": openDir.path, "fixed_path": fixedDir.path]) }
        else { print(openDir.path) }
        return 0

    case "list":
        for a in args.dropFirst() where a.hasPrefix("-") && !["--json", "--fixed", "--all"].contains(a) {
            fputs("Fehler: Unbekannte Option: \(a)\n", stderr); return 1
        }
        let showFixed = args.contains("--fixed")
        let showAll = args.contains("--all")
        var entries: [BugReportEntry] = []
        if !showFixed || showAll { entries += bugReportEntries(in: openDir, fixed: false) }
        if showFixed || showAll { entries += bugReportEntries(in: fixedDir, fixed: true) }
        if jsonMode {
            printBugReportJSON(entries.map(bugReportJSON))
        } else if entries.isEmpty {
            print(showFixed && !showAll ? "(keine behobenen Bugreports)" : "(keine offenen Bugreports)")
        } else {
            for e in entries {
                let kb = String(format: "%.1f KB", Double(e.size) / 1024)
                print("\(e.fixed ? "[behoben] " : "")\(e.name)  \(kb)")
            }
        }
        return 0

    case "show":
        guard let name = positional.first else {
            fputs("Verwendung: iphoto-cli bugreport show <name> [--json]\n", stderr); return 1
        }
        guard validBugReportName(name) else {
            fputs("Fehler: Ungültiger Bugreport-Name: \(name)\n", stderr); return 1
        }
        let candidates: [(URL, Bool)] = [(openDir.appendingPathComponent(name), false),
                                         (fixedDir.appendingPathComponent(name), true)]
        guard let hit = candidates.first(where: { fm.fileExists(atPath: $0.0.path) }) else {
            fputs("Fehler: Bugreport nicht gefunden: \(name)\n", stderr); return 1
        }
        let url = hit.0
        let isFixed = hit.1
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            fputs("Fehler: Bugreport nicht lesbar: \(url.path)\n", stderr); return 1
        }
        if jsonMode {
            printBugReportJSON(["name": name, "path": url.path, "fixed": isFixed, "content": content])
        } else {
            print(content)
        }
        return 0

    case "fix", "reopen":
        let fixing = sub == "fix"
        guard !positional.isEmpty else {
            fputs("Verwendung: iphoto-cli bugreport \(sub) <name> [<name>...] [--json]\n", stderr); return 1
        }
        let src = fixing ? openDir : fixedDir
        let dst = fixing ? fixedDir : openDir
        var moved: [String] = []
        var errors: [String] = []
        for name in positional {
            guard validBugReportName(name) else { errors.append("\(name): ungültiger Name"); continue }
            let from = src.appendingPathComponent(name)
            let to = dst.appendingPathComponent(name)
            guard fm.fileExists(atPath: from.path) else {
                errors.append("\(name): nicht gefunden in \(src.path)"); continue
            }
            if fm.fileExists(atPath: to.path) {
                errors.append("\(name): existiert bereits in \(dst.path)"); continue
            }
            do {
                try fm.createDirectory(at: dst, withIntermediateDirectories: true)
                try fm.moveItem(at: from, to: to)
                moved.append(name)
            } catch {
                errors.append("\(name): \(error.localizedDescription)")
            }
        }
        if jsonMode {
            printBugReportJSON(["action": sub, "moved": moved, "errors": errors,
                                "ok": errors.isEmpty, "destination": dst.path])
        } else {
            let verb = fixing ? "als behoben markiert" : "wieder geöffnet"
            for n in moved { print("\(n) \(verb)") }
        }
        for e in errors { fputs("Fehler: \(e)\n", stderr) }
        return errors.isEmpty ? 0 : 1

    default:
        fputs("Verwendung: iphoto-cli bugreport list [--fixed|--all]|show <name>|fix <name>...|reopen <name>...|path [--json]\n", stderr)
        return 1
    }
}

// MARK: - gear (Kamera-/Objektiv-/Belichtungsstatistik aus dem Katalog)

/// Zahl ohne überflüssige Nachkommastellen: 35.0 → "35", 2.8 → "2.8".
private func gearNumberLabel(_ v: Double) -> String {
    if v == v.rounded() && abs(v) < 1e9 { return String(Int(v)) }
    return String(format: "%.1f", v)
}

private func runGear(_ args: [String]) -> Int32 {
    let usage = "Verwendung: iphoto-cli gear summary|cameras|lenses|focal|iso|aperture [--limit N] [--json]\n"
    let jsonMode = args.contains("--json")
    let sub = args.first ?? "summary"
    let valid: Set<String> = ["summary", "cameras", "lenses", "focal", "iso", "aperture"]
    guard valid.contains(sub) else {
        fputs("Fehler: Unbekannter gear-Befehl '\(sub)'\n", stderr); fputs(usage, stderr); return 1
    }

    // Optionen parsen
    var limit: Int? = nil
    let opts = Array(args.dropFirst())
    var i = 0
    while i < opts.count {
        let key = opts[i]
        switch key {
        case "--json": i += 1
        case "--limit":
            guard i + 1 < opts.count, let n = Int(opts[i + 1]), n > 0 else {
                fputs("Fehler: --limit erwartet eine positive Ganzzahl\n", stderr); return 1
            }
            limit = n; i += 2
        default:
            fputs("Fehler: Unbekannte Option '\(key)'\n", stderr); fputs(usage, stderr); return 1
        }
    }

    let catalog = CatalogStore(dbPath: envDBPath())
    // Ein einziger SELECT für die Bilder; EXIF kommt aus dem beim Öffnen geladenen
    // In-Memory-Cache (kein SQLite-Query pro Bild).
    let images = catalog.allImages()
    let unknown = "(unbekannt)"

    var cameras: [String: Int] = [:]
    var lenses: [String: Int] = [:]
    var focal: [Double: Int] = [:]
    var iso: [Int: Int] = [:]
    var aperture: [Double: Int] = [:]
    var withExif = 0
    for img in images {
        let make = img.cameraMake?.trimmingCharacters(in: .whitespaces) ?? ""
        let model = img.cameraModel?.trimmingCharacters(in: .whitespaces) ?? ""
        let cam: String
        if model.isEmpty { cam = make.isEmpty ? unknown : make }
        else if make.isEmpty || model.lowercased().hasPrefix(make.lowercased()) { cam = model }
        else { cam = "\(make) \(model)" }
        cameras[cam, default: 0] += 1

        guard let e = catalog.exif(forPath: img.path) else {
            lenses[unknown, default: 0] += 1
            continue
        }
        if e.focalLength != nil || e.iso != nil || e.aperture != nil || e.lensModel != nil { withExif += 1 }
        let lens = e.lensModel?.trimmingCharacters(in: .whitespaces) ?? ""
        lenses[lens.isEmpty ? unknown : lens, default: 0] += 1
        if let f = e.focalLength, f > 0 { focal[(f * 10).rounded() / 10, default: 0] += 1 }
        if let n = e.iso, n > 0 { iso[n, default: 0] += 1 }
        if let a = e.aperture, a > 0 { aperture[(a * 10).rounded() / 10, default: 0] += 1 }
    }

    /// Nach Anzahl absteigend, bei Gleichstand alphabetisch; "(unbekannt)" immer zuletzt.
    func ranked(_ d: [String: Int]) -> [(name: String, count: Int)] {
        let sorted = d.map { (name: $0.key, count: $0.value) }.sorted {
            if ($0.name == unknown) != ($1.name == unknown) { return $1.name == unknown }
            return $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name
        }
        if let l = limit { return Array(sorted.prefix(l)) }
        return sorted
    }
    func histogram<K: Comparable & Hashable>(_ d: [K: Int], label: (K) -> String, value: (K) -> Any) -> [[String: Any]] {
        var rows = d.keys.sorted().map { k -> [String: Any] in ["value": value(k), "label": label(k), "count": d[k] ?? 0] }
        if let l = limit {
            // Bei Limit die häufigsten Werte behalten, Ausgabe bleibt aufsteigend sortiert.
            let top = Set(d.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                           .prefix(l).map { label($0.key) })
            rows = rows.filter { top.contains($0["label"] as? String ?? "") }
        }
        return rows
    }
    func median<K: Comparable & Hashable>(_ d: [K: Int]) -> K? {
        let total = d.values.reduce(0, +)
        guard total > 0 else { return nil }
        var acc = 0
        for k in d.keys.sorted() {
            acc += d[k] ?? 0
            if acc * 2 >= total { return k }
        }
        return nil
    }
    func printRows(_ rows: [[String: Any]], unit: String) {
        if rows.isEmpty { print("(keine Daten im Katalog)"); return }
        let maxCount = rows.compactMap { $0["count"] as? Int }.max() ?? 1
        for r in rows {
            let c = r["count"] as? Int ?? 0
            let bar = String(repeating: "█", count: max(1, c * 30 / max(1, maxCount)))
            let lbl = (r["label"] as? String ?? "") + unit
            let num = String(c)
            let numPadded = String(repeating: " ", count: max(0, 6 - num.count)) + num
            print(lbl.padding(toLength: 12, withPad: " ", startingAt: 0) + " " + numPadded + "  " + bar)
        }
    }

    switch sub {
    case "cameras", "lenses":
        let rows = ranked(sub == "cameras" ? cameras : lenses)
        let key = sub == "cameras" ? "camera" : "lens"
        if jsonMode {
            printExifJSON(rows.map { [key: $0.name, "count": $0.count] as [String: Any] })
        } else if rows.isEmpty {
            print("(keine Bilder im Katalog)")
        } else {
            let width = min(40, max(10, rows.map { $0.name.count }.max() ?? 10))
            for r in rows { print("\(r.name.padding(toLength: width, withPad: " ", startingAt: 0))  \(r.count)") }
        }
        return 0

    case "focal":
        let rows = histogram(focal, label: gearNumberLabel, value: { $0 as Any })
        if jsonMode { printExifJSON(rows) } else { printRows(rows, unit: " mm") }
        return 0

    case "iso":
        let rows = histogram(iso, label: { String($0) }, value: { $0 as Any })
        if jsonMode { printExifJSON(rows) } else { printRows(rows, unit: "") }
        return 0

    case "aperture":
        let rows = histogram(aperture, label: { "f/" + gearNumberLabel($0) }, value: { $0 as Any })
        if jsonMode { printExifJSON(rows) } else { printRows(rows, unit: "") }
        return 0

    default: // summary
        func orNull(_ v: Any?) -> Any { v ?? NSNull() }
        let topCam = ranked(cameras).first { $0.name != unknown }
        let topLens = ranked(lenses).first { $0.name != unknown }
        let obj: [String: Any] = [
            "images": images.count,
            "with_exif": withExif,
            "cameras": cameras.keys.filter { $0 != unknown }.count,
            "lenses": lenses.keys.filter { $0 != unknown }.count,
            "top_camera": orNull(topCam?.name),
            "top_lens": orNull(topLens?.name),
            "focal_min": orNull(focal.keys.min()), "focal_max": orNull(focal.keys.max()),
            "focal_median": orNull(median(focal)),
            "iso_min": orNull(iso.keys.min()), "iso_max": orNull(iso.keys.max()),
            "iso_median": orNull(median(iso)),
            "aperture_min": orNull(aperture.keys.min()), "aperture_max": orNull(aperture.keys.max()),
            "aperture_median": orNull(median(aperture))
        ]
        if jsonMode { printExifJSON(obj); return 0 }
        func range<T>(_ lo: T?, _ hi: T?, _ med: T?, _ fmt: (T) -> String) -> String {
            guard let lo = lo, let hi = hi else { return "—" }
            let m = med.map { " (Median \(fmt($0)))" } ?? ""
            return "\(fmt(lo)) – \(fmt(hi))\(m)"
        }
        print("Bilder:        \(images.count)")
        print("Mit EXIF:      \(withExif)")
        let camCount = cameras.keys.filter { $0 != unknown }.count
        let lensCount = lenses.keys.filter { $0 != unknown }.count
        var camLine = "Kameras:       \(camCount)"
        if let t = topCam { camLine += "  (meist: \(t.name), \(t.count)×)" }
        var lensLine = "Objektive:     \(lensCount)"
        if let t = topLens { lensLine += "  (meist: \(t.name), \(t.count)×)" }
        print(camLine)
        print(lensLine)
        let focalLine = range(focal.keys.min(), focal.keys.max(), median(focal), { (v: Double) -> String in gearNumberLabel(v) + " mm" })
        let isoLine = range(iso.keys.min(), iso.keys.max(), median(iso), { (v: Int) -> String in String(v) })
        let apLine = range(aperture.keys.min(), aperture.keys.max(), median(aperture), { (v: Double) -> String in "f/" + gearNumberLabel(v) })
        print("Brennweite:    \(focalLine)")
        print("ISO:           \(isoLine)")
        print("Blende:        \(apLine)")
        return 0
    }
}

// MARK: - perf (SWITCH-Latenzmetriken aus iPhoto.log)

/// Pfad des App-Logs. Überschreibbar per IPHOTO_LOG_FILE (Tests). Bewusst NICHT über
/// Log.shared — dessen init() schreibt einen Session-Marker in die Datei.
private func perfLogPath() -> String {
    if let override = ProcessInfo.processInfo.environment["IPHOTO_LOG_FILE"], !override.isEmpty {
        return (override as NSString).expandingTildeInPath
    }
    let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    return dir.appendingPathComponent("Logs/iPhoto/iPhoto.log").path
}

private struct PerfSwitchSample {
    let timestamp: String
    let label: String
    let ms: Double
    let file: String
}

/// Parst `SWITCH <label> <ms> ms: <datei>`-Zeilen (ImageLoadingOrchestrator).
/// Ein einziger Durchlauf über den Text, schneller Substring-Vorfilter pro Zeile.
private func parsePerfSwitchLines(_ text: String, lastSessionOnly: Bool) -> [PerfSwitchSample] {
    var body = Substring(text)
    if lastSessionOnly, let r = text.range(of: "###SESSION_START###", options: .backwards) {
        body = text[r.upperBound...]
    }
    var out: [PerfSwitchSample] = []
    for line in body.split(separator: "\n", omittingEmptySubsequences: true) {
        guard let r = line.range(of: "SWITCH ") else { continue }
        let rest = line[r.upperBound...]
        let parts = rest.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard parts.count >= 3, parts[2].hasPrefix("ms"), let ms = Double(parts[1]), ms >= 0 else { continue }
        var ts = ""
        if line.hasPrefix("["), let close = line.firstIndex(of: "]") {
            ts = String(line[line.index(after: line.startIndex)..<close])
        }
        let file = parts.count > 3 ? String(parts[3]) : ""
        out.append(PerfSwitchSample(timestamp: ts, label: String(parts[0]), ms: ms, file: file))
    }
    return out
}

/// Nearest-Rank-Perzentil auf bereits sortiertem Array.
private func perfPercentile(_ sorted: [Double], _ p: Double) -> Double {
    guard !sorted.isEmpty else { return 0 }
    let rank = Int((p / 100.0 * Double(sorted.count)).rounded(.up))
    return sorted[max(0, min(sorted.count - 1, rank - 1))]
}

private func runPerf(_ args: [String]) -> Int32 {
    let usage = """
    Verwendung: iphoto-cli perf path [--json]
                iphoto-cli perf switch [--log <datei>] [--last-session] [--label <tag>] [--slowest N] [--json]

    """
    let jsonMode = args.contains("--json")
    guard let sub = args.first else { fputs(usage, stderr); return 1 }

    func emit(_ obj: Any) {
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: d, encoding: .utf8) { print(s) }
    }
    func r1(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    switch sub {
    case "path":
        guard args.dropFirst().allSatisfy({ $0 == "--json" }) else {
            fputs("Fehler: Unbekannte Option für 'perf path'\n", stderr); fputs(usage, stderr); return 1
        }
        let path = perfLogPath()
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
        if jsonMode {
            let obj: [String: Any] = ["path": path, "exists": attrs != nil, "size_bytes": size]
            emit(obj)
        } else {
            print(path + (attrs == nil ? "  (nicht vorhanden)" : "  (\(size) Bytes)"))
        }
        return 0

    case "switch":
        var logPath = perfLogPath()
        var lastSession = false
        var labelFilter: String? = nil
        var slowest = 0
        let opts = Array(args.dropFirst())
        var i = 0
        while i < opts.count {
            let key = opts[i]
            switch key {
            case "--json": i += 1
            case "--last-session": lastSession = true; i += 1
            case "--log":
                guard i + 1 < opts.count, !opts[i + 1].hasPrefix("--") else {
                    fputs("Fehler: --log erwartet einen Dateipfad\n", stderr); return 1
                }
                logPath = (opts[i + 1] as NSString).expandingTildeInPath; i += 2
            case "--label":
                guard i + 1 < opts.count, !opts[i + 1].hasPrefix("--") else {
                    fputs("Fehler: --label erwartet einen Tag (z.B. cache-hit)\n", stderr); return 1
                }
                labelFilter = opts[i + 1]; i += 2
            case "--slowest":
                guard i + 1 < opts.count, let n = Int(opts[i + 1]), n > 0 else {
                    fputs("Fehler: --slowest erwartet eine positive Ganzzahl\n", stderr); return 1
                }
                slowest = n; i += 2
            default:
                fputs("Fehler: Unbekannte Option '\(key)'\n", stderr); fputs(usage, stderr); return 1
            }
        }

        guard let data = FileManager.default.contents(atPath: logPath) else {
            fputs("Fehler: Log-Datei nicht gefunden: \(logPath)\n", stderr); return 1
        }
        let text = String(decoding: data, as: UTF8.self)
        var samples = parsePerfSwitchLines(text, lastSessionOnly: lastSession)
        if let lf = labelFilter { samples = samples.filter { $0.label == lf } }

        // Gruppieren nach Label (ein Durchlauf, Dictionary statt firstIndex-Suche).
        var byLabel: [String: [Double]] = [:]
        for s in samples { byLabel[s.label, default: []].append(s.ms) }
        let order = ["cache-hit", "thumbnail-hit", "preview-hit", "preview-decoded", "full-res", "full-res-decode"]
        let labels = byLabel.keys.sorted {
            let a = order.firstIndex(of: $0) ?? order.count, b = order.firstIndex(of: $1) ?? order.count
            return a != b ? a < b : $0 < $1
        }
        func stats(_ values: [Double]) -> [String: Any] {
            let v = values.sorted()
            let mean = v.isEmpty ? 0 : v.reduce(0, +) / Double(v.count)
            return ["count": v.count, "min_ms": r1(v.first ?? 0), "max_ms": r1(v.last ?? 0),
                    "mean_ms": r1(mean), "median_ms": r1(perfPercentile(v, 50)), "p95_ms": r1(perfPercentile(v, 95))]
        }
        var rows: [[String: Any]] = []
        for l in labels {
            var row = stats(byLabel[l] ?? [])
            row["label"] = l
            rows.append(row)
        }
        // "switches" = echte Bildwechsel; full-res-decode ist eine Decoder-Teilmessung.
        let switchValues = samples.filter { $0.label != "full-res-decode" }.map { $0.ms }
        let total = stats(switchValues)
        let slow = slowest > 0 ? Array(samples.sorted { $0.ms > $1.ms }.prefix(slowest)) : []

        if jsonMode {
            var obj: [String: Any] = ["log": logPath, "last_session": lastSession,
                                      "samples": samples.count, "labels": rows, "switches": total]
            if let lf = labelFilter { obj["label_filter"] = lf }
            if slowest > 0 {
                obj["slowest"] = slow.map { s -> [String: Any] in
                    ["label": s.label, "ms": r1(s.ms), "file": s.file, "timestamp": s.timestamp]
                }
            }
            emit(obj)
        } else {
            if samples.isEmpty { print("Keine SWITCH-Einträge in \(logPath)"); return 0 }
            print("SWITCH-Latenzen (\(samples.count) Messungen)\(lastSession ? " — letzte Session" : "")")
            func pad(_ s: String, _ n: Int) -> String { s.count >= n ? s : s + String(repeating: " ", count: n - s.count) }
            func lpad(_ s: String, _ n: Int) -> String { s.count >= n ? s : String(repeating: " ", count: n - s.count) + s }
            func fmt(_ v: Any?) -> String { String(format: "%.1f", (v as? Double) ?? 0) }
            print(pad("Label", 18) + lpad("n", 6) + lpad("median", 10) + lpad("p95", 10) + lpad("max", 10))
            var totalRow = total
            totalRow["label"] = "= switches"
            for row in rows + [totalRow] {
                guard let n = row["count"] as? Int, n > 0 else { continue }
                print(pad(row["label"] as? String ?? "", 18) + lpad("\(n)", 6)
                      + lpad(fmt(row["median_ms"]), 10) + lpad(fmt(row["p95_ms"]), 10) + lpad(fmt(row["max_ms"]), 10))
            }
            if !slow.isEmpty {
                print("\nLangsamste \(slow.count):")
                for s in slow { print("  \(String(format: "%8.1f", s.ms)) ms  \(pad(s.label, 16)) \(s.file)  \(s.timestamp)") }
            }
        }
        return 0

    default:
        fputs("Fehler: Unbekannter perf-Befehl '\(sub)'\n", stderr); fputs(usage, stderr); return 1
    }
}

// MARK: - Collect (gefilterte Bilder in Ordner kopieren)

/// Kopiert alle Bilder, die einem Rating-/Flag-/Farb-Filter entsprechen, in einen Zielordner.
/// Ohne Filter werden alle Picks gesammelt. Papierkorb-Einträge sind standardmäßig ausgeschlossen.
private func runCollect(_ args: [String]) -> Int32 {
    let usage = "Verwendung: iphoto-cli collect --output-dir <ordner> [--flag pick|reject|none] [--color farbe] [--min-rating N] [--include-trashed] [--dry-run] [--overwrite] [--json]\n"
    var jsonMode = false
    var outDir: String? = nil
    var flagFilter: String? = nil
    var colorFilter: String? = nil
    var minRating: Int? = nil
    var includeTrashed = false
    var dryRun = false
    var overwrite = false
    var i = 0
    while i < args.count {
        let a = args[i]
        switch a {
        case "--output-dir":
            i += 1
            guard i < args.count, !args[i].isEmpty else { fputs("Fehler: --output-dir braucht einen Pfad\n", stderr); return 1 }
            outDir = args[i]
        case "--flag":
            i += 1
            guard i < args.count, FlagStatus(rawValue: args[i].lowercased()) != nil else {
                fputs("Fehler: Ungültiger Flag-Wert. Erlaubt: none, pick, reject\n", stderr); return 1
            }
            flagFilter = args[i].lowercased()
        case "--color":
            i += 1
            guard i < args.count, ColorLabel(rawValue: args[i].lowercased()) != nil else {
                fputs("Fehler: Ungültige Farbe. Erlaubt: none, red, yellow, green, blue\n", stderr); return 1
            }
            colorFilter = args[i].lowercased()
        case "--min-rating":
            i += 1
            guard i < args.count, let n = Int(args[i]), n >= 0, n <= 5 else {
                fputs("Fehler: --min-rating muss zwischen 0 und 5 liegen\n", stderr); return 1
            }
            minRating = n
        case "--include-trashed": includeTrashed = true
        case "--dry-run": dryRun = true
        case "--overwrite": overwrite = true
        case "--json": jsonMode = true
        default:
            fputs("Fehler: Unbekanntes Argument: \(a)\n", stderr)
            fputs(usage, stderr)
            return 1
        }
        i += 1
    }
    guard let dest = outDir else { fputs(usage, stderr); return 1 }
    if flagFilter == nil && colorFilter == nil && minRating == nil { flagFilter = "pick" }

    let catalog = CatalogStore(dbPath: envDBPath())
    let trashed: Set<String> = includeTrashed ? [] : catalog.trashedPaths()
    // Ein Durchlauf über alle Ratings, dann nach Pfad sortieren (deterministische Reihenfolge).
    let matches = catalog.allRatings().filter { (path, e) in
        if trashed.contains(path) { return false }
        if let f = flagFilter, e.flag != f { return false }
        if let c = colorFilter, e.colorLabel != c { return false }
        if let r = minRating, e.rating < r { return false }
        return true
    }.keys.sorted()

    let fm = FileManager.default
    let destURL = URL(fileURLWithPath: (dest as NSString).expandingTildeInPath)
    if !dryRun {
        do { try fm.createDirectory(at: destURL, withIntermediateDirectories: true) }
        catch { fputs("Fehler: Zielordner kann nicht angelegt werden: \(error.localizedDescription)\n", stderr); return 1 }
    }

    var copied: [[String: String]] = []
    var skipped: [String] = []
    var missing: [String] = []
    var failed: [String] = []
    var usedNames = Set<String>()   // Namenskollisionen innerhalb dieses Laufs (gleicher Dateiname, anderer Ordner)
    for p in matches {
        guard fm.fileExists(atPath: p) else { missing.append(p); continue }
        let base = (p as NSString).lastPathComponent
        var name = base
        if usedNames.contains(name.lowercased()) {
            let stem = (base as NSString).deletingPathExtension
            let ext = (base as NSString).pathExtension
            var n = 2
            repeat {
                name = ext.isEmpty ? "\(stem)-\(n)" : "\(stem)-\(n).\(ext)"
                n += 1
            } while usedNames.contains(name.lowercased())
        }
        usedNames.insert(name.lowercased())
        let target = destURL.appendingPathComponent(name)
        if fm.fileExists(atPath: target.path) {
            if !overwrite { skipped.append(p); continue }
            if !dryRun { try? fm.removeItem(at: target) }
        }
        if dryRun { copied.append(["source": p, "target": target.path]); continue }
        do {
            try fm.copyItem(at: URL(fileURLWithPath: p), to: target)
            copied.append(["source": p, "target": target.path])
        } catch { failed.append(p) }
    }

    if jsonMode {
        var filter: [String: Any] = ["include_trashed": includeTrashed]
        if let f = flagFilter { filter["flag"] = f }
        if let c = colorFilter { filter["color"] = c }
        if let r = minRating { filter["min_rating"] = r }
        let obj: [String: Any] = [
            "output_dir": destURL.path, "dry_run": dryRun, "filter": filter,
            "matched": matches.count, "copied": copied.count, "skipped": skipped.count,
            "missing": missing.count, "failed": failed.count,
            "files": copied, "missing_paths": missing, "ok": failed.isEmpty
        ]
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: d, encoding: .utf8) { print(s) }
    } else {
        let verb = dryRun ? "würden kopiert" : "kopiert"
        print("\(matches.count) Treffer: \(copied.count) \(verb), \(skipped.count) übersprungen, \(missing.count) fehlend, \(failed.count) Fehler → \(destURL.path)")
        for c in copied { print("  \(c["source"] ?? "") → \(c["target"] ?? "")") }
    }
    return failed.isEmpty ? 0 : 1
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
if firstArg == "rating", rawArgs.count >= 3, rawArgs[2] == "export" {
    exit(runRatingExport(Array(rawArgs.dropFirst(3))))
}
if firstArg == "rating", rawArgs.count >= 3, rawArgs[2] == "import" {
    exit(runRatingImport(Array(rawArgs.dropFirst(3))))
}
if firstArg == "rating", rawArgs.count >= 3, rawArgs[2] == "histogram" {
    exit(runRatingHistogram(Array(rawArgs.dropFirst(3))))
}
if firstArg == "exif" {
    exit(runExif(Array(rawArgs.dropFirst(2))))
}
if firstArg == "query" {
    exit(runQuery(Array(rawArgs.dropFirst(2))))
}
if firstArg == "bugreport" {
    exit(runBugReport(Array(rawArgs.dropFirst(2))))
}
if firstArg == "bookmarks" {
    exit(runBookmarks(Array(rawArgs.dropFirst(2))))
}
if firstArg == "gear" {
    exit(runGear(Array(rawArgs.dropFirst(2))))
}
if firstArg == "perf" {
    exit(runPerf(Array(rawArgs.dropFirst(2))))
}
if firstArg == "collect" {
    exit(runCollect(Array(rawArgs.dropFirst(2))))
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
