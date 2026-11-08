import AppKit
import Foundation

// Prozess-weite Koordinations-Primitiven (kein per-Instanz-State):
// OperationQueues statt "ein GCD-Block pro Bild + Semaphore" — Hunderte wartende
// Blöcke erschöpften GCDs Thread-Pool (Soft-Limit 64) → Bug #35.
private let thumbnailBatchQueue: OperationQueue = {
    let q = OperationQueue()
    q.name = "iphoto.thumbnails.batch"
    q.maxConcurrentOperationCount = 2
    q.qualityOfService = .background
    return q
}()

private let visibleThumbnailQueue: OperationQueue = {
    let q = OperationQueue()
    q.name = "iphoto.thumbnails.visible"
    q.maxConcurrentOperationCount = 2
    q.qualityOfService = .userInitiated
    return q
}()

// Deckelt parallele Metadaten-Reads (RAF: 128 KB JPEG-Header pro Datei).
private let metadataQueue: OperationQueue = {
    let q = OperationQueue()
    q.name = "iphoto.metadata"
    q.maxConcurrentOperationCount = 4
    q.qualityOfService = .background
    return q
}()

// Serialisiert Voll-Decodes — nur ein RAF/JPEG gleichzeitig, sonst OOM → SIGSEGV.
private let fullResDecodeSemaphore = DispatchSemaphore(value: 1)

// Kapselt die gesamte Bild-, Thumbnail- und Metadaten-Lade-Pipeline.
// Zuvor lag der State (15 Felder + 4 Queues) direkt auf ImageViewModel und wurde
// über 3 Extension-Dateien verteilt manipuliert — die VM war dadurch ein „god object".
// Orchestrator besitzt den State selbst; die VM hält nur noch eine Referenz und
// leitet Aufrufe über dünne Wrapper (ImageViewModel+Loading/Thumbnails/MetadataScan)
// weiter, damit die 14 Aufrufer-Dateien unverändert bleiben.
//
// Der Rückgriff auf VM-Zustand (collection, adj, activity, errorMessage etc.)
// erfolgt über `weak var host` — VM lebt so lange wie die App, aber `weak` ist
// konsistent mit den [weak self]-Patterns in der bestehenden Code-Basis.
final class ImageLoadingOrchestrator {

    weak var host: ImageViewModel?

    // MARK: - State (zuvor auf ImageViewModel)

    var loadToken: UUID = UUID()
    var currentlyLoadingURL: URL? = nil
    // Verhindert 7+ Duplikat-Decode-Tasks pro URL bei schnellem Alben-Wechsel.
    var previewLoadInFlight: Set<URL> = []
    var isLoadingFullRes = false
    var activeFullResToken: UUID? = nil
    var fullResWorkItem: DispatchWorkItem? = nil
    var thumbQueued: Int = 0
    var thumbDone: Int = 0
    var thumbBatchStart: Date = Date()
    var thumbHideTask: DispatchWorkItem? = nil
    var thumbInFlight: Set<URL> = []
    var hiResInFlight: Set<URL> = []
    let thumbnailTaskID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var metaDone: Int = 0
    var metaTotal: Int = 0
    let metaTaskID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    var prefetchInFlight: Set<URL> = []
    // Completion callbacks to fire when a prefetch for a URL finishes.
    // loadFullRes() registers here when the target URL is already being prefetched,
    // so the prefetch result is reused instead of decoding the same image twice.
    var prefetchCompletions: [URL: [() -> Void]] = [:]

    // Metadata batch-flush buffer — accumulates per-URL results from the metadata queue;
    // flushed to collection.documents in one write every 150 ms (#14).
    var metadataPendingFlush: [URL: [MetadataEntry]] = [:]
    var metadataFlushScheduled = false

    // Perf-Instrumentierung: Zeitpunkt, an dem der Nutzer ein neues Bild ausgewählt hat.
    // Speedmetriken (SWITCH cache/preview/full) messen von hier bis zum ersten Display.
    // Der Programmier-Build behält dieses Logging bewusst: Regressionen der
    // Switch-Latenz sind sonst unsichtbar, bis der User es merkt.
    var switchStartedAt: Date? = nil
    var switchLoggedFirstFrame: Bool = false

    // Computes per-channel (R, G, B) averages as 0–100 % from a CGImage on a BG thread (#31).
    static func computeColorRatios(_ cgImg: CGImage) -> (Double?, Double?, Double?) {
        let w = cgImg.width, h = cgImg.height
        guard w > 0, h > 0 else { return (nil, nil, nil) }
        let bpp = 4, bpr = bpp * w
        var pixels = [UInt8](repeating: 0, count: bpr * h)
        guard let ctx = CGContext(
            data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: bpr,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (nil, nil, nil) }
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var rSum: Double = 0, gSum: Double = 0, bSum: Double = 0
        var i = 0
        while i < pixels.count {
            rSum += Double(pixels[i]); gSum += Double(pixels[i+1]); bSum += Double(pixels[i+2])
            i += bpp
        }
        let n = Double(w * h) * 2.55
        return (rSum / n, gSum / n, bSum / n)
    }

    // Loggt Millisekunden seit `switchStartedAt` mit Kategorielabel (cache/preview/full).
    // Nur der *erste* Frame pro Switch zählt — sonst überschriebe der spätere
    // Full-Res-Decode die eigentliche Nutzer-Wahrnehmung des Bild-Switchens.
    func logSwitchDisplay(_ label: String, url: URL) {
        guard let t0 = switchStartedAt, !switchLoggedFirstFrame else { return }
        switchLoggedFirstFrame = true
        let ms = -t0.timeIntervalSinceNow * 1000
        Log.info(String(format: "SWITCH %@ %.1f ms: %@", label, ms, url.lastPathComponent))
    }

    // Zusatzmetrik: Dauer vom Full-Res-Decode-Start bis zum on-screen Frame.
    // Läuft unabhängig vom Switch-Timer, weil Full-Res oft *nach* dem ersten Preview-Frame
    // kommt (Dwell 1.5 s) und trotzdem eine eigene Perf-Größe ist.
    func logFullResDisplay(startedAt: Date, url: URL, size: CGSize) {
        let ms = -startedAt.timeIntervalSinceNow * 1000
        Log.info(String(format: "SWITCH full-res-decode %.1f ms: %@ %d×%d",
                        ms, url.lastPathComponent, Int(size.width), Int(size.height)))
    }

    // MARK: - Deinit / Cleanup

    func cancelPendingWork() {
        fullResWorkItem?.cancel()
        thumbHideTask?.cancel()
    }

    // MARK: - Bild-Pipeline

    func loadCurrentImage() {
        guard let host = host else { return }
        guard let doc = host.collection.currentDocument else { return }
        guard doc.url != currentlyLoadingURL || doc.cgImage == nil else { return }
        switchStartedAt = Date()
        switchLoggedFirstFrame = false
        currentlyLoadingURL = doc.url
        host.evictDistantImages(keepRadius: 3)
        host.resetAdjustments()
        host.clearInpaint()
        host.adj.isUndoRedoing = false
        if let saved = CatalogStore.shared.loadAdjustments(path: doc.url.path) {
            host.adj.adjustments = saved
        }
        host.adj.history.reset(to: host.adj.adjustments)
        host.adj.lastPersisted = host.adj.adjustments
        activeFullResToken = nil
        isLoadingFullRes = false
        fullResWorkItem?.cancel()
        fullResWorkItem = nil

        if doc.cgImage != nil {
            Log.trace("Bild bereits im Cache: \(doc.url.lastPathComponent)")
            host.fitToWindowRequested = true
            host.adj.displayImageVersion = UUID()
            logSwitchDisplay("cache-hit", url: doc.url)
            prefetchAdjacent()
            return
        }

        host.errorMessage = nil
        let url = doc.url
        let token = UUID()
        loadToken = token

        let hasQuickPreview = doc.thumbnail != nil || doc.previewImage != nil
        if hasQuickPreview {
            host.adj.displayImageVersion = UUID()
            host.fitToWindowRequested = true
            host.isLoading = false
            let label = doc.previewImage != nil ? "preview-hit" : "thumbnail-hit"
            logSwitchDisplay(label, url: doc.url)
        } else {
            host.isLoading = true
        }

        // RAF auf macOS 11: „Vollbild" ist ohnehin nur das eingebettete JPEG (~100 ms) —
        // Preview-Phase und 1,5-s-Dwell entfallen, direkt Vollbild laden.
        if RAWImageDecoder.fullDecodeIsCheap(url: url) {
            Log.info("Lade Bild (direkt voll): \(url.lastPathComponent)")
            loadFullRes(url: url, token: token)
            return
        }

        if doc.previewImage != nil {
            Log.trace("Dwell geplant (previewImage vorhanden): \(url.lastPathComponent) token=\(token)")
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, self.loadToken == token else { return }
                self.fullResWorkItem = nil
                self.loadFullRes(url: url, token: token)
            }
            fullResWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
            return
        }

        guard !previewLoadInFlight.contains(url) else { return }
        previewLoadInFlight.insert(url)

        Log.info("Lade Bild: \(url.lastPathComponent)")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                DispatchQueue.main.async { self?.previewLoadInFlight.remove(url) }
            }
            guard let self = self else { return }
            Log.trace("loadCurrentImage thumbnail-Phase BG: \(url.lastPathComponent) token=\(token)")
            let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
            defer { stopAccess() }

            // Phase 2: Preview in Bildschirmauflösung (~1500px)
            if let preview = try? RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 1500) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let host = self.host, self.loadToken == token else { return }
                    guard let idx = host.collection.documentIndexByURL[url] else { return }
                    host.collection.documents[idx].previewImage = preview
                    host.isLoading = false
                    host.fitToWindowRequested = true
                    host.adj.displayImageVersion = UUID()
                    self.logSwitchDisplay("preview-decoded", url: url)
                    if host.hasActiveAdjustments { host.applyAdjustments() }
                }
            }

            // Phase 3: Vollbild nach Dwell-Zeit (1.5 s)
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.loadToken == token else { return }
                self.fullResWorkItem?.cancel()
                Log.trace("Dwell geplant (Phase 3): \(url.lastPathComponent) token=\(token)")
                let item = DispatchWorkItem { [weak self] in
                    guard let self = self, self.loadToken == token else { return }
                    Log.trace("Dwell gefeuert: \(url.lastPathComponent) token=\(token)")
                    self.fullResWorkItem = nil
                    self.loadFullRes(url: url, token: token)
                }
                self.fullResWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
            }
        }
    }

    func loadFullRes(url: URL, token: UUID) {
        guard let host = host else { return }
        guard !isLoadingFullRes,
              activeFullResToken == nil,
              token == loadToken,
              let idx = host.collection.documentIndexByURL[url],
              host.collection.documents[idx].cgImage == nil else { return }

        // Priority-inversion guard: if a prefetch is already decoding this URL,
        // subscribe to its completion instead of launching a second decode.
        if prefetchInFlight.contains(url) {
            isLoadingFullRes = true
            activeFullResToken = token
            prefetchCompletions[url, default: []].append { [weak self] in
                guard let self = self else { return }
                self.isLoadingFullRes = false
                self.activeFullResToken = nil
                // cgImage is now set by the prefetch; upgradeToFullResIfNeeded will
                // return early because cgImage != nil.
            }
            return
        }

        isLoadingFullRes = true
        activeFullResToken = token
        let preloadedMetadata = host.collection.documents[idx].metadata

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            fullResDecodeSemaphore.wait()
            defer { fullResDecodeSemaphore.signal() }
            guard let self = self else { return }
            // Token-Prüfung nach dem Warten: stale wenn Nutzer weitergeklickt hat.
            guard self.loadToken == token else {
                DispatchQueue.main.async {
                    self.isLoadingFullRes = false
                    self.activeFullResToken = nil
                    self.upgradeToFullResIfNeeded()
                }
                return
            }
            Log.trace("loadFullRes BG gestartet: \(url.lastPathComponent) token=\(token)")
            let decodeStart = Date()
            let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
            defer { stopAccess() }
            do {
                let image = try RAWImageDecoder.decode(url: accessURL)
                let size = CGSize(width: image.width, height: image.height)
                let decodeMs = -decodeStart.timeIntervalSinceNow * 1000
                let metadata: [MetadataEntry]
                if preloadedMetadata.isEmpty, let host = self.host {
                    metadata = host.metadataService.readPhotoMetadata(from: accessURL)
                } else {
                    metadata = preloadedMetadata
                }
                Log.info(String(format: "Bild dekodiert (voll) %.1f ms: %@ %d×%d, %d Metadaten-Einträge",
                                decodeMs, url.lastPathComponent, Int(size.width), Int(size.height), metadata.count))
                // SQLite-Zugriffe noch im BG-Thread erledigen — nicht auf dem Main-Thread blockieren
                let catalogRating = CatalogStore.shared.rating(forPath: url.path)
                let catalogElo = CatalogStore.shared.elo(forPath: url.path)
                let fallbackRating = catalogRating == nil ? RatingStore.shared.load(for: url) : nil
                let sizeBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let host = self.host, self.loadToken == token else {
                        Log.debug("Vollbild verworfen (Token ungültig): \(url.lastPathComponent)")
                        self?.isLoadingFullRes = false
                        self?.activeFullResToken = nil
                        return
                    }
                    guard let idx = host.collection.documentIndexByURL[url] else {
                        self.isLoadingFullRes = false
                        self.activeFullResToken = nil
                        return
                    }
                    let old = host.collection.documents[idx]
                    var updated = old
                    updated.cgImage = image
                    updated.imageSize = size
                    updated.metadata = metadata
                    updated.fileSize = sizeBytes
                    if let r = catalogRating {
                        updated.rating = r.rating
                        updated.flagStatus = FlagStatus(rawValue: r.flag) ?? .none
                        updated.colorLabel = ColorLabel(rawValue: r.colorLabel) ?? .none
                    } else if let entry = fallbackRating {
                        updated.rating = entry.rating
                        updated.flagStatus = entry.flagStatus
                        updated.colorLabel = entry.colorLabel
                        updated.elo = entry.elo
                        updated.eloMatches = entry.eloMatches
                    }
                    if let e = catalogElo {
                        updated.elo = e.elo
                        updated.eloMatches = e.matches
                    }
                    host.collection.update(document: updated, at: idx)
                    if old.metadata.count != updated.metadata.count
                        || old.rating != updated.rating
                        || old.flagStatus != updated.flagStatus
                        || old.colorLabel != updated.colorLabel {
                        host.invalidateVisibleOrder()
                    }
                    let dateTaken  = updated.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value
                    let camMake    = updated.metadata.first(where: { $0.key == "tiff.Make" })?.value
                    let camModel   = updated.metadata.first(where: { $0.key == "tiff.Model" })?.value
                    let isRAW = updated.isRAW
                    DispatchQueue.global(qos: .utility).async {
                        CatalogStore.shared.upsertImage(path: url.path, filename: url.lastPathComponent,
                                                        isRAW: isRAW, width: Int(size.width),
                                                        height: Int(size.height), sizeBytes: sizeBytes,
                                                        dateTaken: dateTaken, cameraMake: camMake, cameraModel: camModel)
                    }
                    self.isLoadingFullRes = false
                    self.activeFullResToken = nil
                    self.currentlyLoadingURL = nil
                    host.isLoading = false
                    if updated.previewImage == nil && updated.thumbnail == nil {
                        host.fitToWindowRequested = true
                    }
                    host.adj.displayImageVersion = UUID()
                    self.logSwitchDisplay("full-res", url: url)
                    self.logFullResDisplay(startedAt: decodeStart, url: url, size: size)
                    if host.hasActiveAdjustments { host.applyAdjustments() }
                    host.loadVersionsForCurrentImage()
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                    host.evictDistantImages()
                    self.prefetchAdjacent()
                }
            } catch {
                Log.error("Vollbild laden fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let host = self.host, self.loadToken == token else { return }
                    self.isLoadingFullRes = false
                    self.activeFullResToken = nil
                    if host.collection.currentDocument?.url == url {
                        host.isLoading = false
                        host.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func upgradeToFullResIfNeeded() {
        guard let host = host, let doc = host.collection.currentDocument, doc.cgImage == nil else { return }
        loadFullRes(url: doc.url, token: loadToken)
    }

    func prefetchAdjacent() {
        guard let host = host else { return }
        let visible = host.visibleDocuments
        guard let cur = host.collection.currentDocument,
              let visPos = host.visiblePosition(for: cur.id) else { return }
        // Vorwärts zuerst — häufigste Navigationsrichtung.
        for offset in [1, -1] {
            let neighborPos = visPos + offset
            guard neighborPos >= 0, neighborPos < visible.count,
                  let colIdx = host.collectionIndex(for: visible[neighborPos]),
                  host.collection.documents[colIdx].cgImage == nil else { continue }
            let url = host.collection.documents[colIdx].url
            guard !prefetchInFlight.contains(url) else { continue }
            prefetchInFlight.insert(url)
            let idx = colIdx
            DispatchQueue.global(qos: .utility).async { [weak self] in
                fullResDecodeSemaphore.wait()
                defer { fullResDecodeSemaphore.signal() }

                // Stale-neighbor check: after waiting for the semaphore the user
                // may have navigated far away; skip decode to avoid wasting memory.
                var isStillNeeded = false
                DispatchQueue.main.sync { [weak self] in
                    guard let self = self, let host = self.host,
                          let cur = host.collection.currentDocument,
                          let visPos = host.visiblePosition(for: cur.id) else { return }
                    let vis = host.visibleDocuments
                    for off in [-1, 1] {
                        let pos = visPos + off
                        guard pos >= 0, pos < vis.count,
                              let ci = host.collectionIndex(for: vis[pos]) else { continue }
                        if host.collection.documents[ci].url == url {
                            isStillNeeded = true
                            break
                        }
                    }
                }
                guard isStillNeeded else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.prefetchInFlight.remove(url)
                        if let completions = self.prefetchCompletions.removeValue(forKey: url) {
                            for c in completions { c() }
                        }
                    }
                    return
                }

                autoreleasepool {
                    let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                    defer { stopAccess() }
                    let image: CGImage?
                    do {
                        image = try RAWImageDecoder.decode(url: accessURL)
                    } catch {
                        Log.error("Prefetch-Decode fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                        image = nil
                    }
                    DispatchQueue.main.async {
                        guard let self = self, let host = self.host else { return }
                        self.prefetchInFlight.remove(url)
                        // Fire any loadFullRes completions waiting on this prefetch.
                        if let completions = self.prefetchCompletions.removeValue(forKey: url) {
                            for c in completions { c() }
                        }
                        guard let image = image,
                              idx < host.collection.documents.count,
                              host.collection.documents[idx].url == url,
                              host.collection.documents[idx].cgImage == nil else { return }
                        Log.trace("Prefetch fertig: \(url.lastPathComponent)")
                        host.collection.documents[idx].cgImage = image
                        host.collection.documents[idx].imageSize = CGSize(width: image.width, height: image.height)
                    }
                }
            }
        }
    }

    // MARK: - Thumbnails

    func loadThumbnails() {
        guard let host = host else { return }
        guard host.activity.importProgress.isEmpty else { return }
        let visibleURLs = Set(host.visibleDocuments.map { $0.url })
        let pending = host.collection.documents.enumerated().filter {
            visibleURLs.contains($0.element.url) &&
            $0.element.placeholderThumbnailImage == nil &&
            $0.element.thumbnailImage == nil &&
            !thumbInFlight.contains($0.element.url)
        }
        guard !pending.isEmpty else { return }

        thumbHideTask?.cancel()
        thumbHideTask = nil
        for (_, doc) in pending { thumbInFlight.insert(doc.url) }
        if thumbQueued == 0 { thumbBatchStart = Date() }
        thumbQueued += pending.count
        host.activity.enqueue(id: thumbnailTaskID, label: "Lade Thumbnails",
                              icon: "photo", done: thumbDone, total: thumbQueued)

        let thumbTaskID = thumbnailTaskID
        for (_, doc) in pending {
            let url = doc.url
            thumbnailBatchQueue.addOperation { [weak self] in
                self?.host?.activity.waitWhilePaused(id: thumbTaskID)
                autoreleasepool {
                    let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                    defer { stopAccess() }
                    let nsImage: NSImage?
                    var decodeError: String? = nil
                    var colorR: Double? = nil
                    var colorG: Double? = nil
                    var colorB: Double? = nil
                    do {
                        let cg: CGImage
                        if let cached = ThumbnailDiskCache.shared.load(for: accessURL, maxDimension: 80) {
                            cg = cached
                        } else {
                            let decoded = try RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 80)
                            ThumbnailDiskCache.shared.save(decoded, for: accessURL, maxDimension: 80)
                            cg = decoded
                        }
                        // Compute R/G/B averages once here on BG thread (#31).
                        (colorR, colorG, colorB) = Self.computeColorRatios(cg)
                        nsImage = NSImage(cgImage: cg, size: .zero)
                    } catch {
                        Log.error("Thumbnail-Decode fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                        nsImage = nil
                        decodeError = error.localizedDescription
                    }
                    DispatchQueue.main.async {
                        guard let self = self, let host = self.host else { return }
                        self.thumbInFlight.remove(url)
                        // Batch all field updates into one write to avoid 4× O(N) CoW copies (#3).
                        if let idx = host.collection.documentIndexByURL[url] {
                            var doc = host.collection.documents[idx]
                            if let img = nsImage, doc.thumbnailImage == nil {
                                doc.placeholderThumbnailImage = img
                                if let r = colorR { doc.colorRatioR = r }
                                if let g = colorG { doc.colorRatioG = g }
                                if let b = colorB { doc.colorRatioB = b }
                            } else if let msg = decodeError, doc.errorMessage == nil {
                                doc.errorMessage = msg
                            }
                            host.collection.documents[idx] = doc
                        }
                        self.thumbDone += 1
                        host.activity.update(id: self.thumbnailTaskID,
                                             done: self.thumbDone, total: self.thumbQueued)
                        if self.thumbDone >= self.thumbQueued {
                            let elapsed = Date().timeIntervalSince(self.thumbBatchStart) * 1000
                            Log.perf(String(format: "THUMBNAILS %d Bilder %.0f ms (%.1f ms/Bild)",
                                           self.thumbDone, elapsed, elapsed / Double(max(1, self.thumbDone))))
                            self.thumbDone   = 0
                            self.thumbQueued = 0
                            self.thumbInFlight.removeAll()
                            let taskID = self.thumbnailTaskID
                            let task = DispatchWorkItem { [weak self] in
                                self?.host?.activity.dequeue(id: taskID)
                            }
                            self.thumbHideTask = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
                        }
                    }
                }
            }
        }
    }

    func requestVisibleThumbnail(at index: Int) {
        guard let host = host else { return }
        guard index < host.collection.documents.count else { return }
        let doc = host.collection.documents[index]
        guard doc.thumbnailImage == nil else { return }
        let url = doc.url
        guard !hiResInFlight.contains(url) else { return }
        hiResInFlight.insert(url)
        visibleThumbnailQueue.addOperation { [weak self] in
            autoreleasepool {
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                let thumb: CGImage
                do {
                    if let cached = ThumbnailDiskCache.shared.load(for: accessURL, maxDimension: 160) {
                        thumb = cached
                    } else {
                        let decoded = try RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 160)
                        ThumbnailDiskCache.shared.save(decoded, for: accessURL, maxDimension: 160)
                        thumb = decoded
                    }
                } catch {
                    Log.error("Thumbnail-Decode (160px) fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        guard let self = self, let host = self.host else { return }
                        self.hiResInFlight.remove(url)
                        if let idx = host.collection.documentIndexByURL[url],
                           host.collection.documents[idx].errorMessage == nil {
                            host.collection.documents[idx].errorMessage = error.localizedDescription
                        }
                    }
                    return
                }
                let nsImage = NSImage(cgImage: thumb, size: .zero)
                DispatchQueue.main.async {
                    guard let self = self, let host = self.host else { return }
                    self.hiResInFlight.remove(url)
                    guard let idx = host.collection.documentIndexByURL[url] else { return }
                    var doc = host.collection.documents[idx]
                    doc.thumbnail = thumb
                    doc.thumbnailImage = nsImage
                    doc.placeholderThumbnailImage = nil
                    host.collection.documents[idx] = doc
                }
            }
        }
    }

    // MARK: - Metadaten-Scans

    // urls: die gerade importierten Bilder — zeigt genau deren Anzahl in der Loading-Bar.
    func loadMetadataInBackground(for urls: [URL]) {
        guard let host = host else { return }
        let urlSet = Set(urls)
        let pending = host.collection.documents.filter {
            urlSet.contains($0.url) && $0.metadata.isEmpty
        }
        guard !pending.isEmpty else { return }

        metaTotal += pending.count
        host.activity.enqueue(id: metaTaskID, label: "Metadaten laden",
                              icon: "doc.text.magnifyingglass", done: metaDone, total: metaTotal)

        let metaID = metaTaskID
        for doc in pending {
            let url = doc.url
            metadataQueue.addOperation { [weak self] in
                self?.host?.activity.waitWhilePaused(id: metaID)
                guard let self = self, let host = self.host else { return }
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                let metadata = host.metadataService.readPhotoMetadata(from: accessURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Buffer the result; a single flush will apply all in one array write.
                    if !metadata.isEmpty {
                        self.metadataPendingFlush[url] = metadata
                    }
                    self.metaDone += 1
                    self.scheduleMetadataFlush()
                }
            }
        }
    }

    private func scheduleMetadataFlush() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let host = host else { return }
        // Update progress bar on every completion — it's cheap.
        host.activity.update(id: metaTaskID, done: metaDone, total: metaTotal)
        let isLast = metaDone >= metaTotal
        // Flush the buffer now if this is the last item, or after 150 ms if not yet scheduled.
        if isLast {
            flushMetadataPending(isLast: true)
        } else if !metadataFlushScheduled {
            metadataFlushScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.metadataFlushScheduled = false
                self?.flushMetadataPending(isLast: false)
            }
        }
    }

    private func flushMetadataPending(isLast: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let host = host, !metadataPendingFlush.isEmpty else {
            if isLast {
                metaDone = 0; metaTotal = 0
                host?.activity.dequeue(id: metaTaskID)
                host?.detectDuplicates()
            }
            return
        }
        let t0 = Date()
        let flush = metadataPendingFlush
        metadataPendingFlush.removeAll(keepingCapacity: true)
        // Build URL→index map once; apply all mutations; write back in one assignment.
        let indexByURL = Dictionary(uniqueKeysWithValues: host.collection.documents.enumerated().map { ($1.url, $0) })
        var docs = host.collection.documents
        var changed = false
        for (url, entries) in flush {
            guard let idx = indexByURL[url], docs[idx].metadata.isEmpty else { continue }
            docs[idx].metadata = entries
            changed = true
        }
        if changed {
            host.collection.documents = docs
            host.invalidateVisibleOrder()
        }
        Log.perf(String(format: "META-FLUSH %d docs %.0f ms", flush.count, Date().timeIntervalSince(t0) * 1000))
        if isLast {
            metaDone = 0; metaTotal = 0
            host.activity.dequeue(id: metaTaskID)
            host.detectDuplicates()
        }
    }

    func scanExifForLibrary() {
        guard let host = host else { return }
        var paths = CatalogStore.shared.pathsNeedingExifScan()
        if host.isProjectMode {
            let inCollection = Set(host.collection.documents.map { $0.url.path })
            paths = paths.filter { inCollection.contains($0) }
        }
        guard !paths.isEmpty else { return }

        let taskID = UUID()
        host.activity.enqueue(id: taskID, label: "Metadaten lesen", icon: "info.circle",
                              done: 0, total: paths.count)

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let host = self.host else { return }
            let scanStart = Date()
            let total = paths.count
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
        var paths = CatalogStore.shared.pathsNeedingQualityScan()
        if host.isProjectMode {
            let inCollection = Set(host.collection.documents.map { $0.url.path })
            paths = paths.filter { inCollection.contains($0) }
        }
        guard !paths.isEmpty else { return }

        let taskID = UUID()
        host.activity.enqueue(id: taskID, label: "Qualität analysieren",
                              icon: "wand.and.stars",
                              done: 0, total: paths.count, summaryVerb: "analysiert")

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let host = self.host else { return }
            let scanStart = Date()
            let total = paths.count
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
        var paths = CatalogStore.shared.pathsNeedingMotifScan()
        if host.isProjectMode {
            let inCollection = Set(host.collection.documents.map { $0.url.path })
            paths = paths.filter { inCollection.contains($0) }
        }
        guard !paths.isEmpty else { return }

        let taskID = UUID()
        host.activity.enqueue(id: taskID, label: "Motive erkennen",
                              icon: "eye.fill",
                              done: 0, total: paths.count, summaryVerb: "analysiert")

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let host = self.host else { return }
            let total = paths.count
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
            }
        }
    }
}
