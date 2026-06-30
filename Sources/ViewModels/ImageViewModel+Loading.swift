import AppKit
import Foundation

// Caps concurrent thumbnail decode pipelines to prevent memory exhaustion.
// Each RAF thumbnail reads ~5 MB JPEG and creates a ~30 MB CGImage.
// 8 concurrent decodes ≈ 240 MB peak; combined with ciSemaphore(4) in RAWImageDecoder,
// at most 4 of those 8 will be doing GPU rendering at any given time.
private let thumbnailDecodeSemaphore = DispatchSemaphore(value: 8)

// MARK: - Image Loading Pipeline

extension ImageViewModel {

    func loadCurrentImage() {
        guard let doc = collection.currentDocument else { return }
        guard doc.url != currentlyLoadingURL || doc.cgImage == nil else { return }
        currentlyLoadingURL = doc.url
        let index = collection.currentIndex
        evictFarImages(currentIndex: index)
        resetAdjustments()
        adjUndoStack.removeAll()
        adjRedoStack.removeAll()
        isUndoRedoing = false
        if let saved = CatalogStore.shared.loadAdjustments(path: doc.url.path) {
            adjustments = saved
        }
        lastCommittedAdjustments = adjustments
        activeFullResToken = nil
        isLoadingFullRes = false

        if doc.cgImage != nil {
            fitToWindowRequested = true
            displayImageVersion = UUID()
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

        if doc.previewImage != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self, self.loadToken == token else { return }
                self.loadFullRes(url: url, index: index, token: token)
            }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self, self.loadToken == token else { return }
                self.loadFullRes(url: url, index: index, token: token)
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
            guard let self = self else { return }
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
                    var updated = self.collection.documents[index]
                    updated.cgImage = image
                    updated.imageSize = size
                    updated.metadata = metadata
                    if let r = CatalogStore.shared.rating(forPath: url.path) {
                        updated.rating = r.rating
                        updated.flagStatus = FlagStatus(rawValue: r.flag) ?? .none
                        updated.colorLabel = ColorLabel(rawValue: r.colorLabel) ?? .none
                    } else if let entry = RatingStore.shared.load(for: url) {
                        updated.rating = entry.rating
                        updated.flagStatus = entry.flagStatus
                        updated.colorLabel = entry.colorLabel
                    }
                    self.collection.update(document: updated, at: index)
                    let sizeBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
                    let dateTaken  = updated.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value
                    let camMake    = updated.metadata.first(where: { $0.key == "tiff.Make" })?.value
                    let camModel   = updated.metadata.first(where: { $0.key == "tiff.Model" })?.value
                    CatalogStore.shared.upsertImage(path: url.path, filename: url.lastPathComponent,
                                                    isRAW: updated.isRAW, width: Int(size.width),
                                                    height: Int(size.height), sizeBytes: sizeBytes,
                                                    dateTaken: dateTaken, cameraMake: camMake, cameraModel: camModel)
                    self.isLoadingFullRes = false
                    self.activeFullResToken = nil
                    self.currentlyLoadingURL = nil
                    self.displayImageVersion = UUID()
                    if self.hasActiveAdjustments { self.applyAdjustments() }
                    self.loadVersionsForCurrentImage()
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
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
        let pending = collection.documents.enumerated().filter {
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            autoreleasepool {
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                guard let thumb = try? RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 160) else { return }
                let nsImage = NSImage(cgImage: thumb, size: .zero)
                DispatchQueue.main.async {
                    guard let self = self,
                          index < self.collection.documents.count,
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
        for offset in [-1, 1] {
            let neighborPos = visPos + offset
            guard neighborPos >= 0, neighborPos < visible.count,
                  let colIdx = collectionIndex(for: visible[neighborPos]),
                  collection.documents[colIdx].cgImage == nil else { continue }
            let url = collection.documents[colIdx].url
            let idx = colIdx
            DispatchQueue.global(qos: .utility).async { [weak self] in
                autoreleasepool {
                    let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                    defer { stopAccess() }
                    guard let image = try? RAWImageDecoder.decode(url: accessURL) else { return }
                    let size = CGSize(width: image.width, height: image.height)
                    DispatchQueue.main.async {
                        guard let self = self,
                              idx < self.collection.documents.count,
                              self.collection.documents[idx].url == url,
                              self.collection.documents[idx].cgImage == nil else { return }
                        self.collection.documents[idx].cgImage = image
                        self.collection.documents[idx].imageSize = size
                    }
                }
            }
        }
    }

    func loadMetadataInBackground() {
        let pending = collection.documents.enumerated().filter { $0.element.metadata.isEmpty }
        guard !pending.isEmpty else { return }
        for (index, doc) in pending {
            let url = doc.url
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                let metadata = self.metadataService.readPhotoMetadata(from: accessURL)
                guard !metadata.isEmpty else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          index < self.collection.documents.count,
                          self.collection.documents[index].url == url,
                          self.collection.documents[index].metadata.isEmpty else { return }
                    self.collection.documents[index].metadata = metadata
                }
            }
        }
    }

    // MARK: - Memory Management

    private func evictFarImages(currentIndex: Int) {
        let keepRadius = 3
        let lo = max(0, currentIndex - keepRadius)
        let hi = min(collection.documents.count - 1, currentIndex + keepRadius)
        for i in 0 ..< collection.documents.count where i < lo || i > hi {
            if collection.documents[i].cgImage != nil || collection.documents[i].previewImage != nil {
                collection.documents[i].cgImage = nil
                collection.documents[i].previewImage = nil
            }
        }
    }
}
