import Foundation

extension ImageExporter {
    static func exportBatch(
        documents: [ImageDocument],
        to folderURL: URL,
        format: ExportFormat,
        quality: Double,
        adjustmentsProvider: @escaping (ImageDocument) -> AdjustmentState? = { _ in nil },
        progressHandler: @escaping (Int, Int) -> Void,
        completion: @escaping (ExportResult) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var succeeded = 0
            var failed: [(String, String)] = []
            let total = documents.count

            for (i, doc) in documents.enumerated() {
                let image: CGImage
                do {
                    if let adj = adjustmentsProvider(doc) {
                        image = try AdjustmentRenderer.renderForExport(document: doc, adjustments: adj)
                    } else if let cached = doc.cgImage {
                        image = cached
                    } else {
                        image = try RAWImageDecoder.decode(url: doc.url)
                    }
                } catch {
                    failed.append((doc.filename, error.localizedDescription))
                    progressHandler(i + 1, total)
                    continue
                }

                let stem = (doc.filename as NSString).deletingPathExtension
                let outURL = folderURL
                    .appendingPathComponent(stem)
                    .appendingPathExtension(format.fileExtension)

                do {
                    try exportSingle(image: image, to: outURL, format: format, quality: quality)
                    succeeded += 1
                } catch {
                    failed.append((doc.filename, error.localizedDescription))
                }
                progressHandler(i + 1, total)
            }

            completion(ExportResult(total: total, succeeded: succeeded, failed: failed))
        }
    }
}
