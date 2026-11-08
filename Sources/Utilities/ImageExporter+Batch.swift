import Foundation
import CoreGraphics

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
            let exportStart = Date()
            let total = documents.count

            // Pre-assign output filenames on the serial setup thread to avoid races.
            var usedNames = Set<String>()
            var assignments: [(doc: ImageDocument, outURL: URL)] = []
            assignments.reserveCapacity(total)
            for doc in documents {
                let stem = (doc.filename as NSString).deletingPathExtension
                let ext = format.fileExtension
                var candidate = "\(stem).\(ext)"
                var counter = 2
                while usedNames.contains(candidate) || FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(candidate).path) {
                    candidate = "\(stem)-\(counter).\(ext)"
                    counter += 1
                }
                usedNames.insert(candidate)
                assignments.append((doc, folderURL.appendingPathComponent(candidate)))
            }

            // Parallel encode — up to 4 concurrent decode+write operations.
            let opQueue = OperationQueue()
            opQueue.maxConcurrentOperationCount = 4
            opQueue.qualityOfService = .userInitiated

            let lock = NSLock()
            var succeeded = 0
            var failed: [(String, String)] = []
            var doneCount = 0

            for pair in assignments {
                let doc = pair.doc; let outURL = pair.outURL
                opQueue.addOperation {
                    var localOK = false
                    var localErr: (String, String)? = nil
                    do {
                        let image: CGImage
                        if let adj = adjustmentsProvider(doc) {
                            image = try AdjustmentRenderer.renderForExport(document: doc, adjustments: adj)
                        } else if let cached = doc.cgImage {
                            image = cached
                        } else {
                            image = try RAWImageDecoder.decode(url: doc.url)
                        }
                        try exportSingle(image: image, to: outURL, format: format, quality: quality)
                        localOK = true
                    } catch {
                        localErr = (doc.filename, error.localizedDescription)
                    }
                    lock.lock()
                    doneCount += 1
                    if localOK { succeeded += 1 } else if let e = localErr { failed.append(e) }
                    let done = doneCount
                    lock.unlock()
                    progressHandler(done, total)
                }
            }
            opQueue.waitUntilAllOperationsAreFinished()
            Log.perf(String(format: "EXPORT %d Dateien %.0f ms (%d ok, %d fehler)",
                           total, Date().timeIntervalSince(exportStart) * 1000, succeeded, failed.count))
            completion(ExportResult(total: total, succeeded: succeeded, failed: failed))
        }
    }
}
