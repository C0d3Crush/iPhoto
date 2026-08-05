import AppKit
import Foundation

// OperationQueues statt "ein GCD-Block pro Bild + Semaphore": Hunderte an einer
// Semaphore wartende Blöcke erschöpften GCDs Thread-Pool (Soft-Limit 64,
// "too many dispatch threads blocked in synchronous operations") — serielle
// Queues (z. B. CatalogStore) bekamen keinen Thread mehr, queue.sync auf dem
// Main-Thread blockierte minutenlang (Bug #35). OperationQueues halten Arbeit
// als Datenstruktur, nicht als blockierten Thread; maxConcurrentOperationCount
// ersetzt die Semaphore (Speicher-Deckel bleibt identisch).
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

extension ImageViewModel {

    func loadThumbnails() {
        guard activity.importProgress.isEmpty else { return }
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
        activity.enqueue(id: thumbnailTaskID, label: "Lade Thumbnails",
                       icon: "photo", done: thumbDone, total: thumbQueued)

        let thumbTaskID = thumbnailTaskID
        for (_, doc) in pending {
            let url = doc.url
            thumbnailBatchQueue.addOperation { [weak self] in
                // Pausierte Aufgaben blockieren höchstens die 2 Queue-Slots — der
                // GCD-Thread-Pool bleibt frei (kein Block-pro-Bild mehr).
                self?.activity.waitWhilePaused(id: thumbTaskID)
                autoreleasepool {
                    let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                    defer { stopAccess() }
                    let nsImage: NSImage?
                    var decodeError: String? = nil
                    do {
                        let cg = try RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 80)
                        nsImage = NSImage(cgImage: cg, size: .zero)
                    } catch {
                        Log.error("Thumbnail-Decode fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                        nsImage = nil
                        decodeError = error.localizedDescription
                    }
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.thumbInFlight.remove(url)
                        if let idx = self.collection.documents.firstIndex(where: { $0.url == url }) {
                            if let img = nsImage, self.collection.documents[idx].thumbnailImage == nil {
                                self.collection.documents[idx].placeholderThumbnailImage = img
                            } else if let msg = decodeError,
                                      self.collection.documents[idx].errorMessage == nil {
                                self.collection.documents[idx].errorMessage = msg
                            }
                        }
                        self.thumbDone += 1
                        self.activity.update(id: self.thumbnailTaskID,
                                           done: self.thumbDone, total: self.thumbQueued)
                        if self.thumbDone >= self.thumbQueued {
                            self.thumbDone   = 0
                            self.thumbQueued = 0
                            self.thumbInFlight.removeAll()
                            let taskID = self.thumbnailTaskID
                            let task = DispatchWorkItem { [weak self] in
                                self?.activity.dequeue(id: taskID)
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
        visibleThumbnailQueue.addOperation { [weak self] in
            autoreleasepool {
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                let thumb: CGImage
                do {
                    thumb = try RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 160)
                } catch {
                    Log.error("Thumbnail-Decode (160px) fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.hiResInFlight.remove(url)
                        if let idx = self.collection.documents.firstIndex(where: { $0.url == url }),
                           self.collection.documents[idx].errorMessage == nil {
                            self.collection.documents[idx].errorMessage = error.localizedDescription
                        }
                    }
                    return
                }
                let nsImage = NSImage(cgImage: thumb, size: .zero)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.hiResInFlight.remove(url)
                    guard let idx = self.collection.documents.firstIndex(where: { $0.url == url }) else { return }
                    self.collection.documents[idx].thumbnail = thumb
                    self.collection.documents[idx].thumbnailImage = nsImage
                    self.collection.documents[idx].placeholderThumbnailImage = nil
                }
            }
        }
    }
}
