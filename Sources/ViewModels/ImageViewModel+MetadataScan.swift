import Foundation

// Deckelt parallele Metadaten-Reads (RAF: 128 KB JPEG-Header pro Datei).
private let metadataQueue: OperationQueue = {
    let q = OperationQueue()
    q.name = "iphoto.metadata"
    q.maxConcurrentOperationCount = 4
    q.qualityOfService = .background
    return q
}()

extension ImageViewModel {

    // urls: die gerade importierten Bilder — zeigt genau deren Anzahl in der Loading-Bar.
    // Auf startup werden alle Ordner importiert, d.h. alle Bilder erscheinen hier.
    func loadMetadataInBackground(for urls: [URL]) {
        let urlSet = Set(urls)
        let pending = collection.documents.filter {
            urlSet.contains($0.url) && $0.metadata.isEmpty
        }
        guard !pending.isEmpty else { return }

        metaTotal += pending.count
        activity.enqueue(id: metaTaskID, label: "Metadaten laden",
                       icon: "doc.text.magnifyingglass", done: metaDone, total: metaTotal)

        let metaID = metaTaskID
        for doc in pending {
            let url = doc.url
            metadataQueue.addOperation { [weak self] in
                self?.activity.waitWhilePaused(id: metaID)
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
                    self.activity.update(id: self.metaTaskID,
                                       done: self.metaDone, total: self.metaTotal)
                    if self.metaDone >= self.metaTotal {
                        self.metaDone  = 0
                        self.metaTotal = 0
                        self.activity.dequeue(id: self.metaTaskID)
                        self.detectDuplicates()
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
        activity.enqueue(id: taskID, label: "Metadaten lesen", icon: "info.circle",
                       done: 0, total: paths.count)

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let total = paths.count
            var done = 0
            for path in paths {
                self.activity.waitWhilePaused(id: taskID)
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
                        self.activity.update(id: taskID, done: d, total: t)
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.activity.dequeue(id: taskID)
                // Frisch gescannte Sequenz-Nummern können neue Stapel ergeben
                self.invalidateVisibleOrder()
                self.objectWillChange.send()
                Log.info("EXIF-Scan abgeschlossen: \(total) Bilder")
            }
        }
    }
}
