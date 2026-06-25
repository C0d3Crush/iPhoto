import Foundation
import CoreGraphics
import ImageIO
import CoreImage

// MARK: - Timing

private func measure(warmup: Int = 1, runs: Int, block: () -> Void) -> [Double] {
    for _ in 0..<warmup { block() }
    var samples: [Double] = []
    for _ in 0..<runs {
        let t0 = Date()
        block()
        samples.append(Date().timeIntervalSince(t0) * 1000)
    }
    return samples
}

// MARK: - Statistik

struct Stats {
    let label: String
    let samples: [Double]
    let threshold: Double

    var min: Double  { samples.min()! }
    var max: Double  { samples.max()! }
    var avg: Double  { samples.reduce(0, +) / Double(samples.count) }
    var median: Double {
        let s = samples.sorted(); let m = s.count / 2
        return s.count % 2 == 0 ? (s[m-1] + s[m]) / 2 : s[m]
    }
    var p95: Double {
        let s = samples.sorted()
        return s[Swift.min(s.count - 1, Int(Double(s.count) * 0.95))]
    }
    var passed: Bool { avg < threshold }
}

struct Bench {
    let label: String
    let warmup: Int
    let runs: Int
    let threshold: Double
    let block: () -> Void
}

// MARK: - Testbild-Generierung

private func makeTestImage(width: Int, height: Int) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    let step = Swift.max(1, height / 50)
    for y in stride(from: 0, to: height, by: step) {
        let t = CGFloat(y) / CGFloat(height)
        ctx.setFillColor(CGColor(red: 0.2 + 0.6*t, green: 0.4 - 0.2*t, blue: 0.7 - 0.4*t, alpha: 1))
        ctx.fill(CGRect(x: 0, y: y, width: width, height: step))
    }
    return ctx.makeImage()
}

private func writeAsJPEG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
    CGImageDestinationFinalize(dest)
}

private func writeAsPNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// MARK: - Output

private let COL_W = 32
private let NUM_W = 8

private func printHeader() {
    let line = String(repeating: "-", count: COL_W + NUM_W * 5 + 14)
    print(line)
    func pad(_ s: String, _ w: Int, right: Bool = false) -> String {
        right ? String(s.prefix(w)).padding(toLength: w, withPad: " ", startingAt: 0)
              : String(repeating: " ", count: Swift.max(0, w - s.count)) + s.prefix(w)
    }
    let cols = ["Min","Avg","Med","p95","Max"]
    print(pad("Test", COL_W, right: true) + " " + cols.map { pad($0, NUM_W) }.joined(separator: " ") + "       Schwelle")
    print(pad("", COL_W, right: true) + " " + cols.map { _ in pad("(ms)", NUM_W) }.joined(separator: " ") + "       (ms)")
    print(line)
}

private func printRow(_ s: Stats) {
    func num(_ v: Double) -> String { String(format: "%\(NUM_W).1f", v) }
    func lpad(_ str: String, _ w: Int) -> String {
        str.count >= w ? String(str.prefix(w)) : str.padding(toLength: w, withPad: " ", startingAt: 0)
    }
    let status = s.passed ? " PASS" : " FAIL"
    let limit  = String(format: "< %.0f", s.threshold)
    print(lpad(s.label, COL_W) + " " + [num(s.min), num(s.avg), num(s.median), num(s.p95), num(s.max)].joined(separator: " ")
          + "  [\(status)]  \(limit)")
}

private func printFooter(_ results: [Stats]) {
    let line = String(repeating: "-", count: COL_W + NUM_W * 5 + 14)
    print(line)
    let passed = results.filter { $0.passed }.count
    let failed = results.filter { !$0.passed }.count
    print("Ergebnis: \(passed) PASS, \(failed) FAIL  |  alle Werte in ms")
    print(line)
}

// MARK: - Main

let tmpDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("iphoto_bench_\(Int(Date().timeIntervalSince1970))")
try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tmpDir) }

let arch = ProcessInfo.processInfo.environment["CPU_ARCH"] ?? "unknown"
let cpuCount = ProcessInfo.processInfo.processorCount
let mem = ProcessInfo.processInfo.physicalMemory / (1024 * 1024)

print("")
print("iPhoto Performance Benchmark")
print(String(repeating: "=", count: COL_W + NUM_W * 5 + 14))
print("Plattform : \(arch)  |  \(cpuCount) CPU-Kerne  |  \(mem) MB RAM")
let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm:ss"
print("Datum     : \(df.string(from: Date()))")
print("")

// ── Testbilder ────────────────────────────────────────────────────────────

let sizes: [(String, Int, Int)] = [
    ("2 MP  (1920×1080)",  1920, 1080),
    ("12 MP (4000×3000)", 4000, 3000),
    ("24 MP (6000×4000)", 6000, 4000),
]

print("Erstelle Testbilder …")
var jpegURLs: [String: URL] = [:]
var pngURLs:  [String: URL] = [:]

for (sizeLabel, w, h) in sizes {
    guard let img = makeTestImage(width: w, height: h) else {
        fputs("Fehler: Testbild \(sizeLabel) konnte nicht erstellt werden\n", stderr); exit(1)
    }
    let key = "\(w)x\(h)"
    let ju = tmpDir.appendingPathComponent("\(key).jpg")
    let pu = tmpDir.appendingPathComponent("\(key).png")
    writeAsJPEG(img, to: ju)
    writeAsPNG(img, to: pu)
    jpegURLs[key] = ju; pngURLs[key] = pu
    let sz = (try? ju.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    print(String(format: "  %-20@  JPEG %4d KB  PNG %5d KB",
                 sizeLabel,
                 sz / 1024,
                 ((try? pu.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) / 1024))
}
print("")

// ── Benchmarks ───────────────────────────────────────────────────────────

var benches: [Bench] = []

for (_, w, h) in sizes {
    let key  = "\(w)x\(h)"
    let mp   = String(format: "%2.0f MP", Double(w * h) / 1_000_000)
    let jURL = jpegURLs[key]!
    let pURL = pngURLs[key]!
    let outJ = tmpDir.appendingPathComponent("out_\(key).jpg")
    let outP = tmpDir.appendingPathComponent("out_\(key).png")
    let outT = tmpDir.appendingPathComponent("out_\(key).tiff")

    benches += [
        Bench(label: "Decode JPEG \(mp)",         warmup: 1, runs: 5,
              threshold: w >= 6000 ? 2500 : (w >= 4000 ? 1500 : 500)) {
            _ = try? RAWImageDecoder.decode(url: jURL)
        },
        Bench(label: "Decode PNG \(mp)",          warmup: 1, runs: 5,
              threshold: w >= 6000 ? 4000 : (w >= 4000 ? 2500 : 800)) {
            _ = try? RAWImageDecoder.decode(url: pURL)
        },
        Bench(label: "Thumbnail  160 px \(mp)",   warmup: 2, runs: 8,
              threshold: 300) {
            _ = try? RAWImageDecoder.thumbnail(url: jURL, maxDimension: 160)
        },
        Bench(label: "Thumbnail 1500 px \(mp)",   warmup: 1, runs: 5,
              threshold: w >= 6000 ? 2000 : (w >= 4000 ? 1200 : 500)) {
            _ = try? RAWImageDecoder.thumbnail(url: jURL, maxDimension: 1500)
        },
        Bench(label: "Export JPEG \(mp)",         warmup: 1, runs: 5,
              threshold: w >= 6000 ? 3000 : (w >= 4000 ? 1800 : 600)) {
            guard let img = try? RAWImageDecoder.decode(url: jURL) else { return }
            try? ImageExporter.exportSingle(image: img, to: outJ, format: .jpeg, quality: 0.9)
        },
        Bench(label: "Export PNG \(mp)",          warmup: 1, runs: 5,
              threshold: w >= 6000 ? 6000 : (w >= 4000 ? 4000 : 1500)) {
            guard let img = try? RAWImageDecoder.decode(url: pURL) else { return }
            try? ImageExporter.exportSingle(image: img, to: outP, format: .png, quality: 1.0)
        },
        Bench(label: "Export TIFF \(mp)",         warmup: 1, runs: 5,
              threshold: w >= 6000 ? 6000 : (w >= 4000 ? 4000 : 1500)) {
            guard let img = try? RAWImageDecoder.decode(url: jURL) else { return }
            try? ImageExporter.exportSingle(image: img, to: outT, format: .tiff, quality: 1.0)
        },
    ]
}

// ── Ausführen ─────────────────────────────────────────────────────────────

print("Starte Messungen  (\(benches[0].runs)–\(benches.max(by: { $0.runs < $1.runs })!.runs) Iterationen je Test) …")
print("")

var results: [Stats] = []
printHeader()

for b in benches {
    let samples = measure(warmup: b.warmup, runs: b.runs, block: b.block)
    let s = Stats(label: b.label, samples: samples, threshold: b.threshold)
    results.append(s)
    printRow(s)
}

printFooter(results)
print("")

let exitCode: Int32 = results.allSatisfy { $0.passed } ? 0 : 1
if exitCode != 0 {
    print("FAIL-Details:")
    for s in results.filter({ !$0.passed }) {
        print(String(format: "  %-\(COL_W)@  Avg %.1f ms  >  Schwelle %.0f ms", s.label, s.avg, s.threshold))
    }
    print("")
}
exit(exitCode)
