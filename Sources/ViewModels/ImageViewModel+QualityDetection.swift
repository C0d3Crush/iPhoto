import AppKit
import Foundation

// Bildanalyse (Duplikate, Unschärfe, Belichtung) — nicht Teil der Lade-Pipeline,
// sondern Auswertungen auf bereits geladene Dokumente/Thumbnails.
extension ImageViewModel {

    func detectDuplicates() {
        let docs = collection.documents.filter { !$0.isTrashed && !$0.metadata.isEmpty }
        guard docs.count > 1 else {
            quality.duplicateGroups = []
            return
        }
        let taskID = UUID()
        activity.enqueue(id: taskID, label: "Duplikate suchen…",
                         icon: "square.on.square",
                         done: 0, total: docs.count, summaryVerb: "geprüft")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var byKey: [String: [ImageDocument]] = [:]
            for (i, doc) in docs.enumerated() {
                if let dateTaken = doc.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value,
                   !dateTaken.isEmpty,
                   let size = (try? doc.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap({ $0 }),
                   size > 0 {
                    let key = "\(dateTaken)|\(size)"
                    byKey[key, default: []].append(doc)
                }
                let done = i + 1
                if done % 25 == 0 || done == docs.count {
                    DispatchQueue.main.async { [weak self] in
                        self?.activity.update(id: taskID, done: done, total: docs.count)
                    }
                }
            }
            let groups = byKey.values
                .filter { $0.count > 1 }
                .map { $0.sorted { $0.url.path < $1.url.path } }
                .sorted { $0[0].filename < $1[0].filename }
            DispatchQueue.main.async { [weak self] in
                self?.quality.duplicateGroups = groups
                self?.activity.dequeue(id: taskID)
            }
        }
    }

    func detectBlurryImages() {
        let docs = collection.documents.filter { !$0.isTrashed }
        guard !docs.isEmpty else { quality.blurryDocuments = []; return }
        let threshold = quality.blurThreshold
        let taskID = UUID()
        activity.enqueue(id: taskID, label: "Unschärfe analysieren…",
                         icon: "drop.triangle.fill",
                         done: 0, total: docs.count, summaryVerb: "analysiert")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var blurry: [ImageDocument] = []
            for (i, doc) in docs.enumerated() {
                let src: CGImage?
                if let thumb = doc.thumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = thumb
                } else if let placeholder = doc.placeholderThumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = placeholder
                } else {
                    src = try? RAWImageDecoder.thumbnail(url: doc.url, maxDimension: 512)
                }
                if let img = src, BlurDetector.score(from: img) < threshold {
                    blurry.append(doc)
                }
                let done = i + 1
                if done % 10 == 0 || done == docs.count {
                    DispatchQueue.main.async { [weak self] in
                        self?.activity.update(id: taskID, done: done, total: docs.count)
                    }
                }
            }
            let sorted = blurry.sorted { $0.filename < $1.filename }
            DispatchQueue.main.async {
                self?.quality.blurryDocuments = sorted
                self?.activity.dequeue(id: taskID)
            }
        }
    }

    func detectExposureIssues() {
        let docs = collection.documents.filter { !$0.isTrashed }
        guard !docs.isEmpty else { quality.underexposedDocuments = []; quality.overexposedDocuments = []; return }
        let shadowThresh = quality.shadowClipThreshold
        let highlightThresh = quality.highlightClipThreshold
        let taskID = UUID()
        activity.enqueue(id: taskID, label: "Belichtung analysieren…",
                         icon: "sun.max",
                         done: 0, total: docs.count, summaryVerb: "analysiert")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var under: [ImageDocument] = []
            var over:  [ImageDocument] = []
            for (i, doc) in docs.enumerated() {
                let src: CGImage?
                if let thumb = doc.thumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = thumb
                } else if let ph = doc.placeholderThumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = ph
                } else {
                    src = try? RAWImageDecoder.thumbnail(url: doc.url, maxDimension: 512)
                }
                if let img = src {
                    let result = ExposureDetector.analyze(from: img)
                    if result.underRatio >= shadowThresh    { under.append(doc) }
                    if result.overRatio  >= highlightThresh { over.append(doc) }
                }
                let done = i + 1
                if done % 10 == 0 || done == docs.count {
                    DispatchQueue.main.async { [weak self] in
                        self?.activity.update(id: taskID, done: done, total: docs.count)
                    }
                }
            }
            let sortedUnder = under.sorted { $0.filename < $1.filename }
            let sortedOver  = over.sorted  { $0.filename < $1.filename }
            DispatchQueue.main.async {
                self?.quality.underexposedDocuments = sortedUnder
                self?.quality.overexposedDocuments  = sortedOver
                self?.activity.dequeue(id: taskID)
            }
        }
    }
}
