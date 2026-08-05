import AppKit
import Foundation

// Serializes full-res decodes — only one RAF/JPEG full-decode in flight at a time.
// loadCurrentImage resets isLoadingFullRes=false eagerly (for UX), but the BG task
// is already dispatched and still consuming ~37–100 MB. Without this semaphore,
// rapid navigation starts a second decode before the first finishes → OOM → SIGSEGV.
// Auch von prefetchAdjacent verwendet, damit nie zwei Voll-Decodes parallel laufen.
private let fullResDecodeSemaphore = DispatchSemaphore(value: 1)

// MARK: - Image Loading Pipeline

extension ImageViewModel {

    func loadCurrentImage() {
        guard let doc = collection.currentDocument else { return }
        guard doc.url != currentlyLoadingURL || doc.cgImage == nil else { return }
        currentlyLoadingURL = doc.url
        evictDistantImages(keepRadius: 3)
        resetAdjustments()
        clearInpaint()
        adj.isUndoRedoing = false
        if let saved = CatalogStore.shared.loadAdjustments(path: doc.url.path) {
            adj.adjustments = saved
        }
        adj.history.reset(to: adj.adjustments)
        adj.lastPersisted = adj.adjustments
        activeFullResToken = nil
        isLoadingFullRes = false
        fullResWorkItem?.cancel()
        fullResWorkItem = nil

        if doc.cgImage != nil {
            Log.trace("Bild bereits im Cache: \(doc.url.lastPathComponent)")
            fitToWindowRequested = true
            adj.displayImageVersion = UUID()
            prefetchAdjacent()
            return
        }

        errorMessage = nil
        let url = doc.url
        let token = UUID()
        loadToken = token

        let hasQuickPreview = doc.thumbnail != nil || doc.previewImage != nil
        if hasQuickPreview {
            adj.displayImageVersion = UUID()
            fitToWindowRequested = true
            isLoading = false
        } else {
            isLoading = true
        }

        // RAF auf macOS 11: "Vollbild" ist ohnehin nur das eingebettete JPEG (~100 ms) —
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
                    // Index per URL auflösen — Positionsindex kann durch Löschen/Sync verschoben sein
                    guard let idx = self.collection.documents.firstIndex(where: { $0.url == url }) else { return }
                    self.collection.documents[idx].previewImage = preview
                    self.isLoading = false
                    self.fitToWindowRequested = true
                    self.adj.displayImageVersion = UUID()
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
                    self.loadFullRes(url: url, token: token)
                }
                self.fullResWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
            }
        }
    }

    func loadFullRes(url: URL, token: UUID) {
        guard !isLoadingFullRes,
              activeFullResToken == nil,
              token == loadToken,
              let idx = collection.documents.firstIndex(where: { $0.url == url }),
              collection.documents[idx].cgImage == nil else { return }
        isLoadingFullRes = true
        activeFullResToken = token
        let preloadedMetadata = collection.documents[idx].metadata

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
                    // Index nach dem Decode neu per URL auflösen — Collection kann sich geändert haben
                    guard let idx = self.collection.documents.firstIndex(where: { $0.url == url }) else {
                        self.isLoadingFullRes = false
                        self.activeFullResToken = nil
                        return
                    }
                    let old = self.collection.documents[idx]
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
                    self.collection.update(document: updated, at: idx)
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
                    self.adj.displayImageVersion = UUID()
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
        loadFullRes(url: doc.url, token: loadToken)
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
                    let image: CGImage?
                    do {
                        image = try RAWImageDecoder.decode(url: accessURL)
                    } catch {
                        // Nur loggen — beim aktiven Navigieren meldet loadFullRes den Fehler sichtbar.
                        Log.error("Prefetch-Decode fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                        image = nil
                    }
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
}
