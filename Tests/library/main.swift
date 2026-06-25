import Foundation
import CoreGraphics
import ImageIO
import CoreImage
import Darwin

// MARK: - Hilfsfunktionen

private func memoryMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<Int32>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return kr == KERN_SUCCESS ? Double(info.phys_footprint) / (1_048_576) : 0
}

private func elapsed(from t0: Date) -> Double { Date().timeIntervalSince(t0) }

private func makeTestJPEG(width: Int, height: Int, index: Int) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    let t = CGFloat(index % 64) / 64
    ctx.setFillColor(CGColor(red: 0.1 + 0.7*t, green: 0.3 + 0.4*(1-t), blue: 0.5, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
    for i in 0..<8 {
        ctx.fill(CGRect(x: i * width/8, y: i * height/8,
                        width: width/16, height: height/16))
    }
    return ctx.makeImage()
}

private func writeJPEG(_ img: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil)
    else { return }
    CGImageDestinationAddImage(dest, img,
        [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
    CGImageDestinationFinalize(dest)
}

// MARK: - Ausgabe

private func header(_ title: String) {
    print("")
    print("[\(title)]")
    print(String(repeating: "-", count: 72))
}

private func tableRow(_ cols: [String], widths: [Int]) {
    print(zip(cols, widths).map { s, w in
        s.count >= w ? String(s.prefix(w)) : s.padding(toLength: w, withPad: " ", startingAt: 0)
    }.joined(separator: "  "))
}

// MARK: - Testergebnis

struct TestResult {
    let section: String
    let n: Int
    let elapsed: Double
    let throughput: Double   // Bilder/Sekunde
    let memDelta: Double     // MB
    let errors: Int
    var passed: Bool         // kein Fehler, Throughput > Mindest-Schwelle
    let minThroughput: Double
}

// MARK: - Testgenerator

private func generateLibrary(n: Int, width: Int, height: Int, dir: URL) -> [URL] {
    var urls: [URL] = []
    for i in 0..<n {
        guard let img = makeTestJPEG(width: width, height: height, index: i) else { continue }
        let url = dir.appendingPathComponent(String(format: "img_%04d.jpg", i))
        writeJPEG(img, to: url)
        urls.append(url)
    }
    return urls
}

// MARK: - Einzeltests

private func benchThumbnailSequential(urls: [URL], dim: Int) -> (Double, Int) {
    var errors = 0
    let t0 = Date()
    for url in urls {
        if (try? RAWImageDecoder.thumbnail(url: url, maxDimension: dim)) == nil { errors += 1 }
    }
    return (elapsed(from: t0), errors)
}

private func benchThumbnailParallel(urls: [URL], dim: Int, threads: Int) -> (Double, Int) {
    var errors = 0
    let lock = NSLock()
    let t0 = Date()
    DispatchQueue.concurrentPerform(iterations: urls.count) { i in
        if (try? RAWImageDecoder.thumbnail(url: urls[i], maxDimension: dim)) == nil {
            lock.lock(); errors += 1; lock.unlock()
        }
    }
    return (elapsed(from: t0), errors)
}

private func benchDecodeSequential(urls: [URL]) -> (Double, Int) {
    var errors = 0
    let t0 = Date()
    for url in urls {
        if (try? RAWImageDecoder.decode(url: url)) == nil { errors += 1 }
    }
    return (elapsed(from: t0), errors)
}

private func benchExportSequential(urls: [URL], outDir: URL, format: ExportFormat) -> (Double, Int) {
    var errors = 0
    let t0 = Date()
    for (i, url) in urls.enumerated() {
        guard let img = try? RAWImageDecoder.decode(url: url) else { errors += 1; continue }
        let out = outDir.appendingPathComponent(String(format: "export_%04d.\(format.fileExtension)", i))
        do { try ImageExporter.exportSingle(image: img, to: out, format: format, quality: 0.9) }
        catch { errors += 1 }
    }
    return (elapsed(from: t0), errors)
}

private func benchExportParallel(urls: [URL], outDir: URL, format: ExportFormat) -> (Double, Int) {
    var errors = 0
    let lock = NSLock()
    let t0 = Date()
    DispatchQueue.concurrentPerform(iterations: urls.count) { i in
        let url = urls[i]
        guard let img = try? RAWImageDecoder.decode(url: url) else {
            lock.lock(); errors += 1; lock.unlock(); return
        }
        let out = outDir.appendingPathComponent(String(format: "export_p_%04d.\(format.fileExtension)", i))
        do { try ImageExporter.exportSingle(image: img, to: out, format: format, quality: 0.9) }
        catch { lock.lock(); errors += 1; lock.unlock() }
    }
    return (elapsed(from: t0), errors)
}

// MARK: - Main

let tmpDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("iphoto_lib_\(Int(Date().timeIntervalSince1970))")
try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tmpDir) }

let cpuCount = ProcessInfo.processInfo.processorCount
let arch     = ProcessInfo.processInfo.environment["CPU_ARCH"] ?? "unknown"
let totalMem = ProcessInfo.processInfo.physicalMemory / (1_048_576)

let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm:ss"

print("")
print("iPhoto Bibliotheks-Skalierungstest")
print(String(repeating: "=", count: 72))
print("Plattform : \(arch)  |  \(cpuCount) Kerne  |  \(totalMem) MB RAM")
print("Datum     : \(df.string(from: Date()))")

// ── Konfiguration ─────────────────────────────────────────────────────────

let scales   = [10, 100, 500, 1000]
let imgW     = 2048
let imgH     = 1365    // ~3 MP — realistisch für schnellen Test
let cpus     = cpuCount

var allResults: [TestResult] = []

// ── Bibliotheken generieren ───────────────────────────────────────────────

print("")
print("Generiere Testbibliotheken (\(imgW)×\(imgH) JPEG, ~3 MP) …")
var libraries: [Int: [URL]] = [:]
var libDirs:   [Int: URL]   = [:]
var outDirs:   [Int: URL]   = [:]

for n in scales {
    let dir    = tmpDir.appendingPathComponent("lib_\(n)")
    let outDir = tmpDir.appendingPathComponent("out_\(n)")
    try! FileManager.default.createDirectory(at: dir,    withIntermediateDirectories: true)
    try! FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let t0 = Date()
    let urls = generateLibrary(n: n, width: imgW, height: imgH, dir: dir)
    let dt   = elapsed(from: t0)
    libraries[n] = urls
    libDirs[n]   = dir
    outDirs[n]   = outDir
    print(String(format: "  %4d Bilder  →  %.1f s  (%.0f Bilder/s)", n, dt, Double(n)/dt))
}

// ── 1. Thumbnail-Durchsatz sequenziell ───────────────────────────────────

header("1  Thumbnail-Durchsatz  160 px — sequenziell")
tableRow(["N", "Zeit (s)", "Bilder/s", "RAM Δ (MB)", "Fehler", ""], widths: [6,10,10,12,8,6])
print(String(repeating: "-", count: 72))

for n in scales {
    let m0 = memoryMB()
    let (dt, errs) = benchThumbnailSequential(urls: libraries[n]!, dim: 160)
    let m1 = memoryMB()
    let tp = Double(n) / dt
    let minTp: Double = n >= 500 ? 30 : 40
    let r = TestResult(section: "Thumb-seq", n: n, elapsed: dt, throughput: tp,
                       memDelta: m1 - m0, errors: errs, passed: errs == 0 && tp >= minTp, minThroughput: minTp)
    allResults.append(r)
    tableRow(["\(n)",
              String(format: "%.2f", dt),
              String(format: "%.0f", tp),
              String(format: "+%.1f", r.memDelta),
              "\(errs)",
              r.passed ? "PASS" : "FAIL"], widths: [6,10,10,12,8,6])
}

// ── 2. Thumbnail-Durchsatz parallel ──────────────────────────────────────

header("2  Thumbnail-Durchsatz  160 px — parallel (\(cpus) Threads)")
tableRow(["N", "Zeit (s)", "Bilder/s", "Speedup", "Fehler", ""], widths: [6,10,10,10,8,6])
print(String(repeating: "-", count: 72))

var seqTimes: [Int: Double] = [:]
for n in scales {
    let (seqDt, _) = benchThumbnailSequential(urls: libraries[n]!, dim: 160)
    seqTimes[n] = seqDt
}

for n in scales {
    let (dt, errs) = benchThumbnailParallel(urls: libraries[n]!, dim: 160, threads: cpus)
    let tp      = Double(n) / dt
    let speedup = (seqTimes[n] ?? dt) / dt
    let minTp: Double = n >= 500 ? 60 : 80
    let r = TestResult(section: "Thumb-par", n: n, elapsed: dt, throughput: tp,
                       memDelta: 0, errors: errs, passed: errs == 0 && tp >= minTp, minThroughput: minTp)
    allResults.append(r)
    tableRow(["\(n)",
              String(format: "%.2f", dt),
              String(format: "%.0f", tp),
              String(format: "%.1f×", speedup),
              "\(errs)",
              r.passed ? "PASS" : "FAIL"], widths: [6,10,10,10,8,6])
}

// ── 3. Vorschau-Durchsatz 1500 px parallel ───────────────────────────────

header("3  Vorschau-Durchsatz  1500 px — parallel (\(cpus) Threads)")
tableRow(["N", "Zeit (s)", "Bilder/s", "RAM Δ (MB)", "Fehler", ""], widths: [6,10,10,12,8,6])
print(String(repeating: "-", count: 72))

for n in scales {
    let m0 = memoryMB()
    let (dt, errs) = benchThumbnailParallel(urls: libraries[n]!, dim: 1500, threads: cpus)
    let m1 = memoryMB()
    let tp = Double(n) / dt
    let minTp: Double = n >= 500 ? 5 : 8
    let r = TestResult(section: "Preview-par", n: n, elapsed: dt, throughput: tp,
                       memDelta: m1 - m0, errors: errs, passed: errs == 0 && tp >= minTp, minThroughput: minTp)
    allResults.append(r)
    tableRow(["\(n)",
              String(format: "%.2f", dt),
              String(format: "%.1f", tp),
              String(format: "+%.1f", r.memDelta),
              "\(errs)",
              r.passed ? "PASS" : "FAIL"], widths: [6,10,10,12,8,6])
}

// ── 4. Vollbild-Decode sequenziell (nur bis 100 Bilder — langsam) ─────────

header("4  Vollbild-Decode — sequenziell  (max. 100 Bilder)")
tableRow(["N", "Zeit (s)", "Bilder/s", "ms/Bild", "Fehler", ""], widths: [6,10,10,10,8,6])
print(String(repeating: "-", count: 72))

for n in scales.filter({ $0 <= 100 }) {
    let (dt, errs) = benchDecodeSequential(urls: libraries[n]!)
    let tp = Double(n) / dt
    let minTp: Double = 2
    let r = TestResult(section: "Decode-seq", n: n, elapsed: dt, throughput: tp,
                       memDelta: 0, errors: errs, passed: errs == 0 && tp >= minTp, minThroughput: minTp)
    allResults.append(r)
    tableRow(["\(n)",
              String(format: "%.2f", dt),
              String(format: "%.1f", tp),
              String(format: "%.0f", dt / Double(n) * 1000),
              "\(errs)",
              r.passed ? "PASS" : "FAIL"], widths: [6,10,10,10,8,6])
}

// ── 5. Export-Durchsatz JPEG parallel ────────────────────────────────────

header("5  Batch-Export JPEG — parallel (\(cpus) Threads)")
tableRow(["N", "Zeit (s)", "Bilder/s", "MB/s (est.)", "Fehler", ""], widths: [6,10,10,14,8,6])
print(String(repeating: "-", count: 72))

let jpegSizeEstMB = Double(imgW * imgH * 3) / (1_048_576) * 0.08  // ~8 % Kompressions-Ratio

for n in scales.filter({ $0 <= 500 }) {
    let (dt, errs) = benchExportParallel(urls: libraries[n]!, outDir: outDirs[n]!, format: .jpeg)
    let tp    = Double(n) / dt
    let mbps  = tp * jpegSizeEstMB
    let minTp: Double = 1.5
    let r = TestResult(section: "Export-JPEG-par", n: n, elapsed: dt, throughput: tp,
                       memDelta: 0, errors: errs, passed: errs == 0 && tp >= minTp, minThroughput: minTp)
    allResults.append(r)
    tableRow(["\(n)",
              String(format: "%.2f", dt),
              String(format: "%.1f", tp),
              String(format: "%.1f", mbps),
              "\(errs)",
              r.passed ? "PASS" : "FAIL"], widths: [6,10,10,14,8,6])
}

// ── 6. Speicher-Skalierung: Thumbnails im Cache ───────────────────────────

header("6  Speicher-Skalierung — Thumbnails im Speicher halten")
tableRow(["N", "RAM (MB)", "MB/Bild", "Δ zum Vorg.", "Fehler", ""], widths: [6,10,10,14,8,6])
print(String(repeating: "-", count: 72))

var thumbCaches: [Int: [CGImage]] = [:]
var prevMem = memoryMB()
var prevN   = 0

for n in scales {
    // Thumbnails laden und im Speicher halten
    var cache: [CGImage] = []
    var errors = 0
    for url in libraries[n]! {
        if let t = try? RAWImageDecoder.thumbnail(url: url, maxDimension: 160) {
            cache.append(t)
        } else { errors += 1 }
    }
    thumbCaches[n] = cache
    let m = memoryMB()
    let delta = n > 0 && prevN > 0 ? m - prevMem : 0
    let perImg = n > 0 ? m / Double(n) : 0
    let r = TestResult(section: "Mem-scale", n: n, elapsed: 0, throughput: 0,
                       memDelta: m, errors: errors, passed: errors == 0, minThroughput: 0)
    allResults.append(r)
    tableRow(["\(n)",
              String(format: "%.1f", m),
              String(format: "%.2f", perImg),
              n > 0 && prevN > 0 ? String(format: "+%.1f", delta) : "-",
              "\(errors)",
              r.passed ? "PASS" : "FAIL"], widths: [6,10,10,14,8,6])
    prevMem = m; prevN = n
}
thumbCaches.removeAll()   // Freigeben

// ── 7. Stabilitätstest: 1000 Bilder komplett durchlaufen ─────────────────

header("7  Stabilitätstest — 1000 Bilder Thumbnail + Vorschau + Export")
let stabN    = scales.last!
let stabURLs = libraries[stabN]!
var stabErrors = 0
let m0stab = memoryMB()
let t0stab = Date()

var thumbOK = 0; var prevOK = 0; var expOK = 0
let stabLock = NSLock()

DispatchQueue.concurrentPerform(iterations: stabURLs.count) { i in
    let url = stabURLs[i]
    var lok = 0; var pok = 0; var eok = 0

    if (try? RAWImageDecoder.thumbnail(url: url, maxDimension: 160)) != nil { lok = 1 }
    if (try? RAWImageDecoder.thumbnail(url: url, maxDimension: 1500)) != nil { pok = 1 }
    let out = tmpDir.appendingPathComponent(String(format: "stab_%04d.jpg", i))
    if let img = try? RAWImageDecoder.decode(url: url),
       let _ = try? ImageExporter.exportSingle(image: img, to: out, format: .jpeg, quality: 0.9) { eok = 1 }
    if lok == 0 || pok == 0 || eok == 0 { stabLock.lock(); stabErrors += 1; stabLock.unlock() }

    stabLock.lock(); thumbOK += lok; prevOK += pok; expOK += eok; stabLock.unlock()
}

let dtStab  = elapsed(from: t0stab)
let memPeak = memoryMB() - m0stab
let stabPass = stabErrors == 0

print(String(format: "  Bilder gesamt  : %d", stabN))
print(String(format: "  Thumbnails OK  : %d / %d", thumbOK, stabN))
print(String(format: "  Vorschauen OK  : %d / %d", prevOK, stabN))
print(String(format: "  Exports OK     : %d / %d", expOK, stabN))
print(String(format: "  Laufzeit       : %.1f s", dtStab))
print(String(format: "  RAM-Peak       : +%.1f MB", memPeak))
print(String(format: "  Fehler         : %d", stabErrors))
print(String(format: "  Ergebnis       : %@", stabPass ? "PASS" : "FAIL"))

allResults.append(TestResult(section: "Stabilitaet", n: stabN, elapsed: dtStab,
                             throughput: Double(stabN) / dtStab, memDelta: memPeak,
                             errors: stabErrors, passed: stabPass, minThroughput: 0))

// ── Gesamtergebnis ────────────────────────────────────────────────────────

let passed = allResults.filter { $0.passed }.count
let failed = allResults.filter { !$0.passed }.count

print("")
print(String(repeating: "=", count: 72))
print(String(format: "Gesamtergebnis: %d PASS  |  %d FAIL", passed, failed))

if failed > 0 {
    print("")
    print("FAIL-Details:")
    for r in allResults.filter({ !$0.passed }) {
        if r.throughput > 0 {
            print(String(format: "  %-20@ N=%-4d  Durchsatz %.1f img/s  < %.0f img/s  Fehler: %d",
                         r.section, r.n, r.throughput, r.minThroughput, r.errors))
        } else {
            print(String(format: "  %-20@ N=%-4d  Fehler: %d", r.section, r.n, r.errors))
        }
    }
}
print(String(repeating: "=", count: 72))
print("")

exit(failed > 0 ? 1 : 0)
