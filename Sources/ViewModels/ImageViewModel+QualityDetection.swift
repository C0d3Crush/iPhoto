import AppKit
import Foundation

// Bildanalyse (Duplikate, Unschärfe, Belichtung) — nicht Teil der Lade-Pipeline,
// sondern Auswertungen auf bereits geladene Dokumente/Thumbnails.
extension ImageViewModel {

    func detectDuplicates() {
        let docs = collection.documents.filter { !$0.isTrashed && !$0.metadata.isEmpty }
        guard docs.count > 1 else {
            duplicateGroups = []
            return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var byKey: [String: [ImageDocument]] = [:]
            for doc in docs {
                guard let dateTaken = doc.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value,
                      !dateTaken.isEmpty else { continue }
                guard let size = (try? doc.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap({ $0 }),
                      size > 0 else { continue }
                let key = "\(dateTaken)|\(size)"
                byKey[key, default: []].append(doc)
            }
            let groups = byKey.values
                .filter { $0.count > 1 }
                .map { $0.sorted { $0.url.path < $1.url.path } }
                .sorted { $0[0].filename < $1[0].filename }
            DispatchQueue.main.async { [weak self] in
                self?.duplicateGroups = groups
            }
        }
    }

    func detectBlurryImages() {
        let docs = collection.documents.filter { !$0.isTrashed }
        guard !docs.isEmpty else { blurryDocuments = []; return }
        let threshold = blurThreshold
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var blurry: [ImageDocument] = []
            for doc in docs {
                let src: CGImage?
                if let thumb = doc.thumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = thumb
                } else if let placeholder = doc.placeholderThumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = placeholder
                } else {
                    src = try? RAWImageDecoder.thumbnail(url: doc.url, maxDimension: 512)
                }
                guard let img = src else { continue }
                let score = BlurDetector.score(from: img)
                if score < threshold { blurry.append(doc) }
            }
            let sorted = blurry.sorted { $0.filename < $1.filename }
            DispatchQueue.main.async { self?.blurryDocuments = sorted }
        }
    }

    func detectExposureIssues() {
        let docs = collection.documents.filter { !$0.isTrashed }
        guard !docs.isEmpty else { underexposedDocuments = []; overexposedDocuments = []; return }
        let shadowThresh = shadowClipThreshold
        let highlightThresh = highlightClipThreshold
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var under: [ImageDocument] = []
            var over:  [ImageDocument] = []
            for doc in docs {
                let src: CGImage?
                if let thumb = doc.thumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = thumb
                } else if let ph = doc.placeholderThumbnailImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    src = ph
                } else {
                    src = try? RAWImageDecoder.thumbnail(url: doc.url, maxDimension: 512)
                }
                guard let img = src else { continue }
                let result = ExposureDetector.analyze(from: img)
                if result.underRatio >= shadowThresh    { under.append(doc) }
                if result.overRatio  >= highlightThresh { over.append(doc) }
            }
            let sortedUnder = under.sorted { $0.filename < $1.filename }
            let sortedOver  = over.sorted  { $0.filename < $1.filename }
            DispatchQueue.main.async {
                self?.underexposedDocuments = sortedUnder
                self?.overexposedDocuments  = sortedOver
            }
        }
    }
}
