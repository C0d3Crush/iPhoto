import AppKit
import Foundation

// Caps concurrent thumbnail decode pipelines to prevent memory exhaustion.
// RAF thumbnails use CGImageSourceCreateThumbnailAtIndex (direct downsample),
// peak ~5 MB JPEG data + internal decode buffer per slot.
// 2 concurrent decodes keep RAM well below 100 MB total for thumbnails.
private let thumbnailDecodeSemaphore = DispatchSemaphore(value: 2)

// Caps concurrent metadata reads. On macOS 11, each RAF metadata read calls
// rafEmbeddedJPEGProperties which reads 128 KB JPEG header per file.
// Without this limit, loadMetadataInBackground spawns one task per document —
// for 200 files that's 200 parallel reads filling GCD's thread pool.
private let metadataReadSemaphore = DispatchSemaphore(value: 4)

// Serializes full-res decodes — only one RAF/JPEG full-decode in flight at a time.
// loadCurrentImage resets isLoadingFullRes=false eagerly (for UX), but the BG task
// is already dispatched and still consuming ~37–100 MB. Without this semaphore,
// rapid navigation starts a second decode before the first finishes → OOM → SIGSEGV.
private let fullResDecodeSemaphore = DispatchSemaphore(value: 1)

// MARK: - Image Loading Pipeline

extension ImageViewModel {

    func loadCurrentImage() {
        guard let doc = collection.currentDocument else { return }
        guard doc.url != currentlyLoadingURL || doc.cgImage == nil else { return }
        currentlyLoadingURL = doc.url
        let index = collection.currentIndex
        evictDistantImages(keepRadius: 3)
        resetAdjustments()
        adjUndoStack.removeAll()
        adjRedoStack.removeAll()
        isUndoRedoing = false
        if let saved = CatalogStore.shared.loadAdjustments(path: doc.url.path) {
            adjustments = saved
        }
        lastCommittedAdjustments = adjustments
        lastPersistedAdjustments = adjustments
        activeFullResToken = nil
        isLoadingFullRes = false
        fullResWorkItem?.cancel()
        fullResWorkItem = nil

        if doc.cgImage != nil {
            Log.trace("Bild bereits im Cache: \(doc.url.lastPathComponent)")
            fitToWindowRequested = true
            displayImageVersion = UUID()
            prefetchAdjacent()
            return
        }

        errorMessage = nil
        let url = doc.url
        let token = UUID()
        loadToken = token

        let hasQuickPreview = doc.thumbnail != nil || doc.previewImage != nil
        if hasQuickPreview {
            displayImageVersion = UUID()
            fitToWindowRequested = true
            isLoading = false
        } else {
            isLoading = true
        }

        // RAF auf macOS 11: "Vollbild" ist ohnehin nur das eingebettete JPEG (~100 ms) —
        // Preview-Phase und 1,5-s-Dwell entfallen, direkt Vollbild laden.
        if RAWImageDecoder.fullDecodeIsCheap(url: url) {
            Log.info("Lade Bild (direkt voll): \(url.lastPathComponent)")
            loadFullRes(url: url, index: index, token: token)
            return
        }

        if doc.previewImage != nil {
            Log.trace("Dwell geplant (previewImage vorhanden): \(url.lastPathComponent) token=\(token)")
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, self.loadToken == token else { return }
                self.fullResWorkItem = nil
                self.loadFullRes(url: url, index: index, token: token)
            }
            fullResWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
            return
        }

        // One active 1500px-preview task per URL at a time.
        // Without this guard, rapid album switching queues 7+ duplicate decode tasks
        // for the same file, exhausting memory and corrupting the main thread.
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
                    guard let self = self, self.loadToken == token else { return }
                    guard index < self.collection.documents.count,
                          self.collection.documents[index].url == url else { return }
                    self.collection.documents[index].previewImage = preview
                    self.isLoading = false
                    self.fitToWindowRequested = true
                    self.displayImageVersion = UUID()
                    if self.hasActiveAdjustments { self.applyAdjustments() }
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
                    self.loadFullRes(url: url, index: index, token: token)
                }
                self.fullResWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
            }
        }
    }

    func loadFullRes(url: URL, index: Int, token: UUID) {
        guard !isLoadingFullRes,
              activeFullResToken == nil,
              token == loadToken,
              index < collection.documents.count,
              collection.documents[index].url == url,
              collection.documents[index].cgImage == nil else { return }
        isLoadingFullRes = true
        activeFullResToken = token
        let preloadedMetadata = index < collection.documents.count ? collection.documents[index].metadata : []

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
            let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
            defer { stopAccess() }
            do {
                let image = try RAWImageDecoder.decode(url: accessURL)
                let size = CGSize(width: image.width, height: image.height)
                let metadata = preloadedMetadata.isEmpty
                    ? self.metadataService.readPhotoMetadata(from: accessURL)
                    : preloadedMetadata
                Log.info("Bild dekodiert (voll): \(url.lastPathComponent) \(Int(size.width))×\(Int(size.height)), \(metadata.count) Metadaten-Einträge")
                // SQLite-Zugriffe noch im BG-Thread erledigen — nicht auf dem Main-Thread blockieren
                let catalogRating = CatalogStore.shared.rating(forPath: url.path)
                let fallbackRating = catalogRating == nil ? RatingStore.shared.load(for: url) : nil
                let sizeBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.loadToken == token else {
                        Log.debug("Vollbild verworfen (Token ungültig): \(url.lastPathComponent)")
                        self?.isLoadingFullRes = false
                        self?.activeFullResToken = nil
                        return
                    }
                    guard index < self.collection.documents.count,
                          self.collection.documents[index].url == url else {
                        self.isLoadingFullRes = false
                        return
                    }
                    let old = self.collection.documents[index]
                    var updated = old
                    updated.cgImage = image
                    updated.imageSize = size
                    updated.metadata = metadata
                    if let r = catalogRating {
                        updated.rating = r.rating
                        updated.flagStatus = FlagStatus(rawValue: r.flag) ?? .none
                        updated.colorLabel = ColorLabel(rawValue: r.colorLabel) ?? .none
                    } else if let entry = fallbackRating {
                        updated.rating = entry.rating
                        updated.flagStatus = entry.flagStatus
                        updated.colorLabel = entry.colorLabel
                    }
                    self.collection.update(document: updated, at: index)
                    if old.metadata.count != updated.metadata.count
                        || old.rating != updated.rating
                        || old.flagStatus != updated.flagStatus
                        || old.colorLabel != updated.colorLabel {
                        self.invalidateVisibleOrder()
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
                    self.isLoading = false
                    // Erst-Anzeige ohne vorheriges Preview (Direktpfad): einpassen.
                    if updated.previewImage == nil && updated.thumbnail == nil {
                        self.fitToWindowRequested = true
                    }
                    self.displayImageVersion = UUID()
                    if self.hasActiveAdjustments { self.applyAdjustments() }
                    self.loadVersionsForCurrentImage()
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                    self.evictDistantImages()
                    self.prefetchAdjacent()
                }
            } catch {
                Log.error("Vollbild laden fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.loadToken == token else { return }
                    self.isLoadingFullRes = false
                    self.activeFullResToken = nil
                    if self.collection.currentDocument?.url == url {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func upgradeToFullResIfNeeded() {
        guard let doc = collection.currentDocument, doc.cgImage == nil else { return }
        loadFullRes(url: doc.url, index: collection.currentIndex, token: loadToken)
    }

    // MARK: - Thumbnails

    func loadThumbnails() {
        guard importProgress.isEmpty else { return }
        let visibleURLs = Set(visibleDocuments.map { $0.url })
        let pending = collection.documents.enumerated().filter {
            visibleURLs.contains($0.element.url) &&
            $0.element.placeholderThumbnailImage == nil &&
            $0.element.thumbnailImage == nil &&
            !thumbInFlight.contains($0.element.url)
        }
        guard !pending.isEmpty else { return }

        thumbHideTask?.cancel()
        thumbHideTask = nil
        for (_, doc) in pending { thumbInFlight.insert(doc.url) }
        thumbQueued += pending.count
        enqueueLoading(id: thumbnailTaskID, label: "Lade Thumbnails",
                       icon: "photo", done: thumbDone, total: thumbQueued)

        for (index, doc) in pending {
            let url = doc.url
            DispatchQueue.global(qos: .background).async { [weak self] in
                thumbnailDecodeSemaphore.wait()
                defer { thumbnailDecodeSemaphore.signal() }
                autoreleasepool {
                    let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                    defer { stopAccess() }
                    let nsImage = (try? RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 80))
                        .map { NSImage(cgImage: $0, size: .zero) }
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.thumbInFlight.remove(url)
                        if let img = nsImage,
                           index < self.collection.documents.count,
                           self.collection.documents[index].url == url,
                           self.collection.documents[index].thumbnailImage == nil {
                            self.collection.documents[index].placeholderThumbnailImage = img
                        }
                        self.thumbDone += 1
                        self.updateLoading(id: self.thumbnailTaskID,
                                           done: self.thumbDone, total: self.thumbQueued)
                        if self.thumbDone >= self.thumbQueued {
                            self.thumbDone   = 0
                            self.thumbQueued = 0
                            self.thumbInFlight.removeAll()
                            let taskID = self.thumbnailTaskID
                            let task = DispatchWorkItem { [weak self] in
                                self?.dequeueLoading(id: taskID)
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
        guard index < collection.documents.count else { return }
        let doc = collection.documents[index]
        guard doc.thumbnailImage == nil else { return }
        let url = doc.url
        guard !hiResInFlight.contains(url) else { return }
        hiResInFlight.insert(url)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            thumbnailDecodeSemaphore.wait()
            defer { thumbnailDecodeSemaphore.signal() }
            autoreleasepool {
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                guard let thumb = try? RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 160) else {
                    DispatchQueue.main.async { self?.hiResInFlight.remove(url) }
                    return
                }
                let nsImage = NSImage(cgImage: thumb, size: .zero)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.hiResInFlight.remove(url)
                    guard index < self.collection.documents.count,
                          self.collection.documents[index].url == url else { return }
                    self.collection.documents[index].thumbnail = thumb
                    self.collection.documents[index].thumbnailImage = nsImage
                    self.collection.documents[index].placeholderThumbnailImage = nil
                }
            }
        }
    }

    func prefetchAdjacent() {
        let visible = visibleDocuments
        guard let cur = collection.currentDocument,
              let visPos = visible.firstIndex(where: { $0.id == cur.id }) else { return }
        // Vorwärts zuerst — das ist die häufigste Navigationsrichtung.
        for offset in [1, -1] {
            let neighborPos = visPos + offset
            guard neighborPos >= 0, neighborPos < visible.count,
                  let colIdx = collectionIndex(for: visible[neighborPos]),
                  collection.documents[colIdx].cgImage == nil else { continue }
            let url = collection.documents[colIdx].url
            guard !prefetchInFlight.contains(url) else { continue }
            prefetchInFlight.insert(url)
            let idx = colIdx
            DispatchQueue.global(qos: .utility).async { [weak self] in
                // Gleiche Semaphore wie loadFullRes: nie zwei Voll-Decodes parallel (OOM).
                fullResDecodeSemaphore.wait()
                defer { fullResDecodeSemaphore.signal() }
                autoreleasepool {
                    let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                    defer { stopAccess() }
                    let image = try? RAWImageDecoder.decode(url: accessURL)
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.prefetchInFlight.remove(url)
                        guard let image = image,
                              idx < self.collection.documents.count,
                              self.collection.documents[idx].url == url,
                              self.collection.documents[idx].cgImage == nil else { return }
                        Log.trace("Prefetch fertig: \(url.lastPathComponent)")
                        self.collection.documents[idx].cgImage = image
                        self.collection.documents[idx].imageSize = CGSize(width: image.width, height: image.height)
                    }
                }
            }
        }
    }

    // urls: die gerade importierten Bilder — zeigt genau deren Anzahl in der Loading-Bar.
    // Auf startup werden alle Ordner importiert, d.h. alle Bilder erscheinen hier.
    func loadMetadataInBackground(for urls: [URL]) {
        let urlSet = Set(urls)
        let pending = collection.documents.filter {
            urlSet.contains($0.url) && $0.metadata.isEmpty
        }
        guard !pending.isEmpty else { return }

        metaTotal += pending.count
        enqueueLoading(id: metaTaskID, label: "Metadaten laden",
                       icon: "doc.text.magnifyingglass", done: metaDone, total: metaTotal)

        for doc in pending {
            let url = doc.url
            DispatchQueue.global(qos: .background).async { [weak self] in
                metadataReadSemaphore.wait()
                defer { metadataReadSemaphore.signal() }
                guard let self = self else { return }
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                let metadata = self.metadataService.readPhotoMetadata(from: accessURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if !metadata.isEmpty,
                       let idx = self.collection.documents.firstIndex(where: { $0.url == url }),
                       self.collection.documents[idx].metadata.isEmpty {
                        self.collection.documents[idx].metadata = metadata
                        // Metadaten beeinflussen Datums-Sortierung + Smart-Folder-Filter
                        self.invalidateVisibleOrder()
                    }
                    self.metaDone += 1
                    self.updateLoading(id: self.metaTaskID,
                                       done: self.metaDone, total: self.metaTotal)
                    if self.metaDone >= self.metaTotal {
                        self.metaDone  = 0
                        self.metaTotal = 0
                        self.dequeueLoading(id: self.metaTaskID)
                    }
                }
            }
        }
    }

    // MARK: - EXIF Background Scan for Smart Folders

    func scanExifForLibrary() {
        let paths = CatalogStore.shared.pathsNeedingExifScan()
        guard !paths.isEmpty else { return }

        let taskID = UUID()
        enqueueLoading(id: taskID, label: "Metadaten lesen", icon: "info.circle",
                       done: 0, total: paths.count)

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let total = paths.count
            var done = 0
            for path in paths {
                metadataReadSemaphore.wait()
                defer { metadataReadSemaphore.signal() }
                autoreleasepool {
                    let url = URL(fileURLWithPath: path)
                    let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                    defer { stopAccess() }
                    let metadata = self.metadataService.readPhotoMetadata(from: accessURL)
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
                        guard let self = self else { return }
                        self.updateLoading(id: taskID, done: d, total: t)
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.dequeueLoading(id: taskID)
                // Frisch gescannte Sequenz-Nummern können neue Stapel ergeben
                self.invalidateVisibleOrder()
                self.objectWillChange.send()
                Log.info("EXIF-Scan abgeschlossen: \(total) Bilder")
            }
        }
    }

}
