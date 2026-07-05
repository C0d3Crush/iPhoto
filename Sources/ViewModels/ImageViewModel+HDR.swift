import Foundation
import AppKit
import ImageIO

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
            var evOffsets: [Double] = []

            for (i, doc) in docs.enumerated() {
                if let img = doc.cgImage ?? (try? RAWImageDecoder.decode(url: doc.url)) {
                    images.append(img)
                    // EV aus EXIF lesen; fehlt er, wird 0 angenommen (keine Normierung für dieses Bild)
                    evOffsets.append(ImageViewModel.exposureBias(at: doc.url) ?? 0.0)
                }
                DispatchQueue.main.async {
                    if let idx = self.loadingQueue.firstIndex(where: { $0.id == taskID }) {
                        self.loadingQueue[idx].done = i + 1
                    }
                }
            }

            // Wenn kein einziges Bild einen EV-Wert hat, sind alle EV = 0 → kein EV-Scaling.
            // Dann wird sigma etwas größer gesetzt damit überhaupt Pixel beitragen.
            var mergeOptions = options
            let allZero = evOffsets.allSatisfy { $0 == 0.0 }
            if allZero { mergeOptions.sigma = max(options.sigma, 0.35) }

            guard let merged = HDRMerger.merge(cgImages: images, evOffsets: evOffsets, options: mergeOptions) else {
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

    // MARK: - EV aus EXIF

    // Liest ExposureBiasValue aus den EXIF-Daten.
    // Für RAF auf macOS 11 (wo CGImageSourceCreateWithURL auf RAF crasht) wird das
    // eingebettete JPEG-Preview als Fallback verwendet.
    static func exposureBias(at url: URL) -> Double? {
        let ext = url.pathExtension.lowercased()

        if ext == "raf" {
            if #available(macOS 12.0, *) {
                return exifBias(cgSource: CGImageSourceCreateWithURL(url as CFURL, nil))
            } else {
                return exifBias(from: rafEmbeddedJPEGData(url: url))
            }
        }
        return exifBias(cgSource: CGImageSourceCreateWithURL(url as CFURL, nil))
    }

    private static func exifBias(cgSource src: CGImageSource?) -> Double? {
        guard let s = src,
              let props = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [String: Any],
              let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let bias = exif[kCGImagePropertyExifExposureBiasValue as String] as? Double
        else { return nil }
        return bias
    }

    private static func exifBias(from jpegData: Data?) -> Double? {
        guard let data = jpegData,
              let src = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }
        return exifBias(cgSource: src)
    }

    // RAF: JPEG-Preview-Extraktion (identisch zur privaten Logik in MetadataService)
    private static func rafEmbeddedJPEGData(url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }
        let header = handle.readData(ofLength: 96)
        guard header.count >= 96,
              (String(bytes: header.prefix(16), encoding: .ascii) ?? "").hasPrefix("FUJIFILMCCD-RAW")
        else { return nil }
        let offset = header.readUInt32BE(at: 0x54)
        let length = header.readUInt32BE(at: 0x58)
        guard offset > 0, length > 0 else { return nil }
        handle.seek(toFileOffset: UInt64(offset))
        let data = handle.readData(ofLength: min(Int(length), 131_072))
        guard data.count >= 4, data[0] == 0xFF, data[1] == 0xD8 else { return nil }
        return data
    }
}
