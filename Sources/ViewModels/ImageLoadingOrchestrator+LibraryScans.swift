import AppKit
import Foundation

// Bibliotheks-weite Hintergrund-Scans: EXIF, Qualität (Blur/Belichtung/pHash), Motive.
// Diese Funktionen laufen komplett auf Hintergrund-Threads; der einzige gemeinsame
// Zustand mit dem Orchestrator ist `host` (schwache Referenz auf ImageViewModel).
// Batch-Flush-Strategie (100er-Batches, einmaliger Array-Write auf Main) verhindert
// die O(N²)-Publish-Kaskade aus Bug #33.
extension ImageLoadingOrchestrator {

    // MARK: - Bibliotheks-Scans

    func scanExifForLibrary() {
        guard let host = host else { return }
        // Snapshot main-thread-only state before dispatching; CatalogStore query moves to BG.
        let inProjectMode = host.isProjectMode
        let projectPaths: Set<String>? = inProjectMode
            ? Set(host.collection.documents.map { $0.url.path }) : nil
        let taskID = UUID()

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let host = self.host else { return }
            var paths = CatalogStore.shared.pathsNeedingExifScan()
            if let projectPaths = projectPaths {
                paths = paths.filter { projectPaths.contains($0) }
            }
            guard !paths.isEmpty else { return }
            let total = paths.count
            DispatchQueue.main.async { [weak self] in
                self?.host?.activity.enqueue(id: taskID, label: "Metadaten lesen",
                                             icon: "info.circle", done: 0, total: total)
            }
            let scanStart = Date()
            var done = 0
            for path in paths {
                host.activity.waitWhilePaused(id: taskID)
                autoreleasepool {
                    let url = URL(fileURLWithPath: path)
                    let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                    defer { stopAccess() }
                    let metadata = host.metadataService.readPhotoMetadata(from: accessURL)
                    let fl = (metadata.first(where: { $0.key == "exif.FocalLength" })?.value)
                        .flatMap { s -> Double? in
                            var t = s
                            if t.hasSuffix(" mm") { t = String(t.dropLast(3)) }
                            return Double(t)
                        }
                    let iso = (metadata.first(where: { $0.key == "exif.ISO" })?.value)
                        .flatMap { s -> Int? in
                            var t = s
                            if t.hasPrefix("ISO ") { t = String(t.dropFirst(4)) }
                            return Int(t)
                        }
                    let ap = (metadata.first(where: { $0.key == "exif.FNumber" })?.value)
                        .flatMap { s -> Double? in
                            var t = s
                            if t.hasPrefix("f/") { t = String(t.dropFirst(2)) }
                            return Double(t)
                        }
                    let lens = metadata.first(where: { $0.key == "exif.LensModel" })?.value
                    let hdr = metadata.first(where: { $0.key == "exif.HDR" })?.value == "Ja"
                    let filmSim = metadata.first(where: { $0.key == "exif.FilmSimulation" })?.value
                    let seq = (metadata.first(where: { $0.key == "exif.SequenceNumber" })?.value).flatMap { Int($0) }
                    let bkt = metadata.first(where: { $0.key == "exif.AutoBracketing" })?.value == "Ja"
                    CatalogStore.shared.upsertExif(path: path, focalLength: fl, iso: iso, aperture: ap, lensModel: lens, hdr: hdr, filmSimulation: filmSim, sequenceNumber: seq, autoBracketing: bkt)
                    done += 1
                    let d = done, t = total
                    DispatchQueue.main.async { [weak self] in
                        self?.host?.activity.update(id: taskID, done: d, total: t)
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let host = self?.host else { return }
                host.activity.dequeue(id: taskID)
                // Frisch gescannte Sequenz-Nummern können neue Stapel ergeben
                host.invalidateVisibleOrder()
                host.objectWillChange.send()
                Log.info("EXIF-Scan abgeschlossen: \(total) Bilder")
                Log.perf(String(format: "SCAN EXIF %d Bilder %.0f ms", total, Date().timeIntervalSince(scanStart) * 1000))
            }
        }
    }

    // Analysiert Blur/Belichtung/pHash pro Bild und persistiert die Werte im Katalog.
    // Ergänzt zusätzlich die in-memory ImageDocument-Kopie, damit BlurryView/ExposureView
    // die Werte ohne SQLite-Roundtrip lesen können.
    //
    // Perf-kritisch: Scan-Ergebnisse werden in Batches à ~100 gesammelt und in *einem*
    // Main-Thread-Dispatch geflusht — sonst ergäbe 6 Subscript-Writes × N Docs eine
    // O(N²)-Publish-Kaskade, die den Bild-Switcher auf hunderte ms hochzieht
    // (siehe project_perf_diagnosis.md, Bug #33).
    func scanQualityForLibrary() {
        guard let host = host else { return }
        let inProjectMode = host.isProjectMode
        let projectPaths: Set<String>? = inProjectMode
            ? Set(host.collection.documents.map { $0.url.path }) : nil

        let taskID = UUID()
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let host = self.host else { return }
            var paths = CatalogStore.shared.pathsNeedingQualityScan()
            if let projectPaths = projectPaths {
                paths = paths.filter { projectPaths.contains($0) }
            }
            guard !paths.isEmpty else { return }
            let total = paths.count
            DispatchQueue.main.async { [weak self] in
                self?.host?.activity.enqueue(id: taskID, label: "Qualität analysieren",
                                             icon: "wand.and.stars",
                                             done: 0, total: total, summaryVerb: "analysiert")
            }
            let scanStart = Date()
            var done = 0
            var pending: [(String, QualityAssessor.Result)] = []
            pending.reserveCapacity(128)
            let flushBatch: ([(String, QualityAssessor.Result)], Int, Int) -> Void = { batch, d, t in
                DispatchQueue.main.async { [weak self] in
                    guard let host = self?.host else { return }
                    host.activity.update(id: taskID, done: d, total: t)
                    guard !batch.isEmpty else { return }
                    var docs = host.collection.documents
                    var indexByPath: [String: Int] = [:]
                    indexByPath.reserveCapacity(docs.count)
                    for (i, doc) in docs.enumerated() { indexByPath[doc.url.path] = i }
                    var touched = false
                    for (path, result) in batch {
                        guard let idx = indexByPath[path] else { continue }
                        docs[idx].blurScore      = result.blurScore
                        docs[idx].underRatio     = result.underRatio
                        docs[idx].overRatio      = result.overRatio
                        docs[idx].phash          = result.phash
                        docs[idx].phashV         = result.phashV
                        docs[idx].eyeOpenness    = result.eyeOpenness
                        docs[idx].qualityScanned = true
                        touched = true
                    }
                    if touched { host.collection.documents = docs }
                }
            }
            for path in paths {
                host.activity.waitWhilePaused(id: taskID)
                autoreleasepool {
                    let url = URL(fileURLWithPath: path)
                    let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                    defer { stopAccess() }
                    guard let result = QualityAssessor.assess(url: accessURL) else {
                        done += 1
                        return
                    }
                    CatalogStore.shared.upsertQuality(
                        path: path,
                        blurScore: result.blurScore,
                        underRatio: result.underRatio,
                        overRatio: result.overRatio,
                        phash: result.phash,
                        phashV: result.phashV,
                        eyeOpenness: result.eyeOpenness
                    )
                    done += 1
                    pending.append((path, result))
                    if pending.count >= 100 {
                        let batch = pending
                        pending.removeAll(keepingCapacity: true)
                        flushBatch(batch, done, total)
                    }
                }
            }
            if !pending.isEmpty {
                let batch = pending
                pending.removeAll(keepingCapacity: true)
                flushBatch(batch, done, total)
            }
            DispatchQueue.main.async { [weak self] in
                guard let host = self?.host else { return }
                host.activity.dequeue(id: taskID)
                host.invalidateVisibleOrder()
                host.refreshQualityLists()
                host.objectWillChange.send()
                Log.info("Quality-Scan abgeschlossen: \(total) Bilder")
                Log.perf(String(format: "SCAN QUALITY %d Bilder %.0f ms", total, Date().timeIntervalSince(scanStart) * 1000))
            }
        }
    }

    // Motiv-Scan: VNClassifyImageRequest pro Thumbnail → Motive speichern.
    // Gleiche Batch-Strategie wie Quality-Scan (100er-Batches, einmaliger Array-Write).
    func scanMotifForLibrary() {
        guard let host = host else { return }
        let inProjectMode = host.isProjectMode
        let projectPaths: Set<String>? = inProjectMode
            ? Set(host.collection.documents.map { $0.url.path }) : nil

        let taskID = UUID()
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let host = self.host else { return }
            var paths = CatalogStore.shared.pathsNeedingMotifScan()
            if let projectPaths = projectPaths {
                paths = paths.filter { projectPaths.contains($0) }
            }
            guard !paths.isEmpty else { return }
            let total = paths.count
            DispatchQueue.main.async { [weak self] in
                self?.host?.activity.enqueue(id: taskID, label: "Motive erkennen",
                                             icon: "eye.fill",
                                             done: 0, total: total, summaryVerb: "analysiert")
            }
            let scanStart = Date()
            var done = 0
            var pending: [(String, [String])] = []
            pending.reserveCapacity(128)
            let flushBatch: ([(String, [String])], Int, Int) -> Void = { batch, d, t in
                DispatchQueue.main.async { [weak self] in
                    guard let host = self?.host else { return }
                    host.activity.update(id: taskID, done: d, total: t)
                    guard !batch.isEmpty else { return }
                    var docs = host.collection.documents
                    var indexByPath: [String: Int] = [:]
                    indexByPath.reserveCapacity(docs.count)
                    for (i, doc) in docs.enumerated() { indexByPath[doc.url.path] = i }
                    var touched = false
                    for (path, tags) in batch {
                        guard let idx = indexByPath[path] else { continue }
                        docs[idx].motifTags    = tags
                        docs[idx].motifScanned = true
                        touched = true
                    }
                    if touched { host.collection.documents = docs }
                }
            }
            for path in paths {
                host.activity.waitWhilePaused(id: taskID)
                autoreleasepool {
                    let url = URL(fileURLWithPath: path)
                    let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                    defer { stopAccess() }
                    let result = MotifAssessor.assess(url: accessURL) ?? MotifAssessor.Result(tags: [])
                    CatalogStore.shared.upsertMotifs(path: path, tags: result.tags)
                    done += 1
                    pending.append((path, result.tags))
                    if pending.count >= 100 {
                        let batch = pending
                        pending.removeAll(keepingCapacity: true)
                        flushBatch(batch, done, total)
                    }
                }
            }
            if !pending.isEmpty {
                let batch = pending
                pending.removeAll(keepingCapacity: true)
                flushBatch(batch, done, total)
            }
            DispatchQueue.main.async { [weak self] in
                guard let host = self?.host else { return }
                host.activity.dequeue(id: taskID)
                host.scheduleSmartFolderCountRefresh()
                Log.info("Motiv-Scan abgeschlossen: \(total) Bilder")
                Log.perf(String(format: "SCAN MOTIF %d Bilder %.0f ms", total, Date().timeIntervalSince(scanStart) * 1000))
            }
        }
    }
}
