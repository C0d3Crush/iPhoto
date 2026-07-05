import Foundation
import AppKit

extension ImageViewModel {

    var selectedDocsForHDR: [ImageDocument] {
        collection.selectedIndices.sorted().compactMap { idx in
            guard idx < collection.documents.count else { return nil }
            return collection.documents[idx]
        }
    }

    var canMergeHDR: Bool { selectedDocsForHDR.count >= 2 }

    func mergeHDR(docs: [ImageDocument], options: HDRMerger.Options = .init()) {
        guard docs.count >= 2 else { return }

        let taskID = UUID()
        let task = LoadingTask(
            id: taskID, label: "HDR zusammenführen…",
            icon: "sparkles", done: 0, total: docs.count + 1
        )
        loadingQueue.append(task)
        hdrMergeError = nil
        hdrMergeResultURL = nil
        isHDRMerging = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var images: [CGImage] = []
            for (i, doc) in docs.enumerated() {
                if let img = doc.cgImage ?? (try? RAWImageDecoder.decode(url: doc.url)) {
                    images.append(img)
                }
                DispatchQueue.main.async {
                    if let idx = self.loadingQueue.firstIndex(where: { $0.id == taskID }) {
                        self.loadingQueue[idx].done = i + 1
                    }
                }
            }

            guard let merged = HDRMerger.merge(cgImages: images, options: options) else {
                DispatchQueue.main.async {
                    self.loadingQueue.removeAll { $0.id == taskID }
                    self.hdrMergeError = "Zusammenführung fehlgeschlagen."
                    self.isHDRMerging = false
                }
                return
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let name = "HDR_\(formatter.string(from: Date())).tiff"
            let outputURL = docs[0].url.deletingLastPathComponent().appendingPathComponent(name)

            do {
                try ImageExporter.exportSingle(image: merged, to: outputURL, format: .tiff, quality: 100)
                DispatchQueue.main.async {
                    self.loadingQueue.removeAll { $0.id == taskID }
                    self.isHDRMerging = false
                    self.hdrMergeResultURL = outputURL
                    self.importFiles([outputURL])
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingQueue.removeAll { $0.id == taskID }
                    self.hdrMergeError = error.localizedDescription
                    self.isHDRMerging = false
                }
            }
        }
    }

    // MARK: - Exposure info helper

    static func exposureBias(at url: URL) -> Double? {
        let ext = url.pathExtension.lowercased()
        var src: CGImageSource?
        if ext == "raf" {
            if #available(macOS 12.0, *) {
                src = CGImageSourceCreateWithURL(url as CFURL, nil)
            } else {
                return nil
            }
        } else {
            src = CGImageSourceCreateWithURL(url as CFURL, nil)
        }
        guard let s = src,
              let props = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [String: Any],
              let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let bias = exif[kCGImagePropertyExifExposureBiasValue as String] as? Double
        else { return nil }
        return bias
    }
}
