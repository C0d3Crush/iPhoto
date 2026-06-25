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
case "--help", "-h", "help":
    printUsage()
    exitCode = 0
default:
    fputs("Fehler: Unbekannter Befehl '\(parsed.command)'\n", stderr)
    printUsage()
    exitCode = 1
}

exit(exitCode)
