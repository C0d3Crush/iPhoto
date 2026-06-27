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
      iphoto-cli info <eingabe>
      iphoto-cli hotpixel <ordner>

    Formate:  jpeg (Standard), png, tiff, heif
    Quality:  0.0–1.0, nur für jpeg und heif (Standard: 0.9)
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
        default:
            result.inputs.append(URL(fileURLWithPath: arg))
        }
        i += 1
    }
    return result
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
    guard let source = CGImageSourceCreateWithURL(input as CFURL, nil) else {
        fputs("Fehler: Datei konnte nicht geöffnet werden: \(input.path)\n", stderr)
        return 1
    }
    let type = CGImageSourceGetType(source) as String? ?? "Unbekannt"
    print("Datei  : \(input.lastPathComponent)")
    print("Typ    : \(type)")
    if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
        let w = props["PixelWidth"] as? Int ?? 0
        let h = props["PixelHeight"] as? Int ?? 0
        if w > 0 { print("Größe  : \(w) × \(h) px") }
        if let exif = props["{Exif}"] as? [String: Any] {
            if let iso = exif["ISOSpeedRatings"] as? [Int] { print("ISO    : \(iso.first ?? 0)") }
            if let ss = exif["ExposureTime"] as? Double { print("Belicht: 1/\(Int(1/ss))s") }
            if let ap = exif["FNumber"] as? Double { print("Blende : f/\(ap)") }
        }
        if let tiff = props["{TIFF}"] as? [String: Any] {
            if let make = tiff["Make"] as? String { print("Kamera : \(make) \(tiff["Model"] as? String ?? "")") }
        }
    }
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

// MARK: - Entry Point

let args = CommandLine.arguments
guard args.count >= 2 else { printUsage(); exit(0) }

guard let parsed = parseArgs(args) else { exit(1) }

let exitCode: Int32
switch parsed.command {
case "export":
    exitCode = runExport(parsed)
case "info":
    exitCode = runInfo(parsed)
case "hotpixel":
    exitCode = runHotPixel(parsed)
case "--help", "-h", "help":
    printUsage()
    exitCode = 0
default:
    fputs("Fehler: Unbekannter Befehl '\(parsed.command)'\n", stderr)
    printUsage()
    exitCode = 1
}

exit(exitCode)
