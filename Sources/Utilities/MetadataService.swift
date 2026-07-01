import Foundation
import ImageIO

final class MetadataService {

    func readPhotoMetadata(from url: URL) -> [MetadataEntry] {
        var props: [String: Any]

        if url.pathExtension.lowercased() == "raf" {
            if #available(macOS 12.0, *) {
                // macOS 12+: ImageIO unterstützt RAF nativ
                guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
                props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] ?? [:]
                let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
                let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
                if (tiff[kCGImagePropertyTIFFMake as String] as? String ?? "").isEmpty,
                   (exif[kCGImagePropertyExifDateTimeOriginal as String] as? String ?? "").isEmpty,
                   let jpegProps = rafEmbeddedJPEGProperties(url: url) {
                    props = jpegProps
                }
            } else {
                // macOS 11: CGImageSourceCreateWithURL auf RAF-Dateien ruft den Apple Fujifilm-Plugin auf → SIGSEGV.
                // Direkt aus dem eingebetteten JPEG-Preview lesen.
                props = rafEmbeddedJPEGProperties(url: url) ?? [:]
            }
        } else {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
            props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] ?? [:]
        }

        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let iptc = props[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        let gps  = props[kCGImagePropertyGPSDictionary  as String] as? [String: Any] ?? [:]
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]

        var entries: [MetadataEntry] = []

        entries += [
            entry("Titel",        "iptc.ObjectName", .general,
                  iptc[kCGImagePropertyIPTCObjectName as String] as? String ?? ""),
            entry("Beschreibung", "iptc.Caption",    .general,
                  iptc[kCGImagePropertyIPTCCaptionAbstract as String] as? String ?? ""),
            entry("Stichwörter",  "iptc.Keywords",   .general,
                  (iptc[kCGImagePropertyIPTCKeywords as String] as? [String] ?? []).joined(separator: ", ")),
            entry("Copyright",    "iptc.Copyright",  .general,
                  iptc[kCGImagePropertyIPTCCopyrightNotice as String] as? String
                  ?? tiff[kCGImagePropertyTIFFCopyright as String] as? String ?? ""),
            entry("Urheber",      "iptc.Creator",    .general,
                  (iptc[kCGImagePropertyIPTCByline as String] as? [String])?.first
                  ?? tiff[kCGImagePropertyTIFFArtist as String] as? String ?? ""),
        ]

        let dateStr = exif[kCGImagePropertyExifDateTimeOriginal  as String] as? String
                   ?? exif[kCGImagePropertyExifDateTimeDigitized as String] as? String
                   ?? tiff[kCGImagePropertyTIFFDateTime          as String] as? String ?? ""
        entries.append(entry("Aufnahmedatum", "exif.DateTimeOriginal", .dateTime, dateStr))

        entries += [
            roEntry("Hersteller",    "tiff.Make",         .camera,
                    tiff[kCGImagePropertyTIFFMake  as String] as? String ?? ""),
            roEntry("Modell",        "tiff.Model",        .camera,
                    tiff[kCGImagePropertyTIFFModel as String] as? String ?? ""),
            roEntry("Objektiv",      "exif.LensModel",    .camera,
                    exif[kCGImagePropertyExifLensModel as String] as? String ?? ""),
            roEntry("Brennweite",    "exif.FocalLength",  .camera,
                    (exif[kCGImagePropertyExifFocalLength as String] as? Double).map { "\(Int($0)) mm" } ?? ""),
            roEntry("Blende",        "exif.FNumber",      .camera,
                    (exif[kCGImagePropertyExifFNumber as String] as? Double).map { String(format: "f/%.1f", $0) } ?? ""),
            roEntry("Belichtung",    "exif.ExposureTime", .camera,
                    (exif[kCGImagePropertyExifExposureTime as String] as? Double).map { formatShutter($0) } ?? ""),
            roEntry("ISO",           "exif.ISO",          .camera,
                    ((exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first).map { "ISO \($0)" } ?? ""),
        ]

        if !gps.isEmpty {
            let lat    = gps[kCGImagePropertyGPSLatitude     as String] as? Double ?? 0
            let latRef = gps[kCGImagePropertyGPSLatitudeRef  as String] as? String ?? "N"
            let lon    = gps[kCGImagePropertyGPSLongitude    as String] as? Double ?? 0
            let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
            entries += [
                entry("Breitengrad",  "gps.Latitude",  .location,
                      String(format: "%.6f", latRef == "S" ? -lat : lat)),
                entry("Längengrad",   "gps.Longitude", .location,
                      String(format: "%.6f", lonRef == "W" ? -lon : lon)),
            ]
            if let alt = gps[kCGImagePropertyGPSAltitude as String] as? Double {
                entries.append(roEntry("Höhe", "gps.Altitude", .location,
                                       String(format: "%.1f m", alt)))
            }
        }

        return entries.filter { !$0.value.isEmpty || $0.isEditable }
    }

    func writePhotoMetadata(url: URL, entries: [MetadataEntry], completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let rawData = try Data(contentsOf: url)
                guard let src  = CGImageSourceCreateWithData(rawData as CFData, nil) else {
                    throw MetadataError.cannotReadFile
                }
                guard let type = CGImageSourceGetType(src) else {
                    throw MetadataError.unknownFileType
                }

                let allProps = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as NSDictionary?
                let exif = NSMutableDictionary(dictionary: (allProps?[kCGImagePropertyExifDictionary] as? NSDictionary) ?? [:])
                let iptc = NSMutableDictionary(dictionary: (allProps?[kCGImagePropertyIPTCDictionary] as? NSDictionary) ?? [:])
                let gps  = NSMutableDictionary(dictionary: (allProps?[kCGImagePropertyGPSDictionary]  as? NSDictionary) ?? [:])
                let tiff = NSMutableDictionary(dictionary: (allProps?[kCGImagePropertyTIFFDictionary] as? NSDictionary) ?? [:])

                for e in entries where e.isEditable && !e.value.isEmpty {
                    switch e.key {
                    case "iptc.ObjectName":
                        iptc[kCGImagePropertyIPTCObjectName] = e.value
                    case "iptc.Caption":
                        iptc[kCGImagePropertyIPTCCaptionAbstract] = e.value
                    case "iptc.Keywords":
                        iptc[kCGImagePropertyIPTCKeywords] = e.value
                            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } as NSArray
                    case "iptc.Copyright":
                        iptc[kCGImagePropertyIPTCCopyrightNotice] = e.value
                        tiff[kCGImagePropertyTIFFCopyright] = e.value
                    case "iptc.Creator":
                        iptc[kCGImagePropertyIPTCByline] = [e.value] as NSArray
                        tiff[kCGImagePropertyTIFFArtist] = e.value
                    case "exif.DateTimeOriginal":
                        exif[kCGImagePropertyExifDateTimeOriginal] = e.value
                    case "gps.Latitude":
                        if let lat = Double(e.value) {
                            gps[kCGImagePropertyGPSLatitude]    = abs(lat) as NSNumber
                            gps[kCGImagePropertyGPSLatitudeRef] = lat >= 0 ? "N" : "S"
                        }
                    case "gps.Longitude":
                        if let lon = Double(e.value) {
                            gps[kCGImagePropertyGPSLongitude]    = abs(lon) as NSNumber
                            gps[kCGImagePropertyGPSLongitudeRef] = lon >= 0 ? "E" : "W"
                        }
                    default: break
                    }
                }

                let options = NSMutableDictionary()
                options[kCGImagePropertyExifDictionary] = exif
                options[kCGImagePropertyIPTCDictionary] = iptc
                options[kCGImagePropertyTIFFDictionary] = tiff
                if gps.count > 0 { options[kCGImagePropertyGPSDictionary] = gps }

                let outData = NSMutableData()
                guard let dest = CGImageDestinationCreateWithData(outData as CFMutableData, type, 1, nil) else {
                    throw MetadataError.cannotWriteFile
                }
                CGImageDestinationAddImageFromSource(dest, src, 0, options as CFDictionary)
                guard CGImageDestinationFinalize(dest) else {
                    throw MetadataError.writeFailed("Finalize fehlgeschlagen")
                }

                try (outData as Data).write(to: url, options: .atomic)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    func writePhotoMetadataSync(url: URL, entries: [MetadataEntry]) throws {
        let rawData = try Data(contentsOf: url)
        guard let src = CGImageSourceCreateWithData(rawData as CFData, nil) else {
            throw MetadataError.cannotReadFile
        }
        guard let type = CGImageSourceGetType(src) else {
            throw MetadataError.unknownFileType
        }
        let allProps = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as NSDictionary?
        let exif = NSMutableDictionary(dictionary: (allProps?[kCGImagePropertyExifDictionary] as? NSDictionary) ?? [:])
        let iptc = NSMutableDictionary(dictionary: (allProps?[kCGImagePropertyIPTCDictionary] as? NSDictionary) ?? [:])
        let gps  = NSMutableDictionary(dictionary: (allProps?[kCGImagePropertyGPSDictionary]  as? NSDictionary) ?? [:])
        let tiff = NSMutableDictionary(dictionary: (allProps?[kCGImagePropertyTIFFDictionary] as? NSDictionary) ?? [:])
        for e in entries where e.isEditable && !e.value.isEmpty {
            switch e.key {
            case "iptc.ObjectName":      iptc[kCGImagePropertyIPTCObjectName] = e.value
            case "iptc.Caption":         iptc[kCGImagePropertyIPTCCaptionAbstract] = e.value
            case "iptc.Keywords":
                iptc[kCGImagePropertyIPTCKeywords] = e.value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } as NSArray
            case "iptc.Copyright":
                iptc[kCGImagePropertyIPTCCopyrightNotice] = e.value
                tiff[kCGImagePropertyTIFFCopyright] = e.value
            case "iptc.Creator":
                iptc[kCGImagePropertyIPTCByline] = [e.value] as NSArray
                tiff[kCGImagePropertyTIFFArtist] = e.value
            case "exif.DateTimeOriginal": exif[kCGImagePropertyExifDateTimeOriginal] = e.value
            case "gps.Latitude":
                if let lat = Double(e.value) {
                    gps[kCGImagePropertyGPSLatitude]    = abs(lat) as NSNumber
                    gps[kCGImagePropertyGPSLatitudeRef] = lat >= 0 ? "N" : "S"
                }
            case "gps.Longitude":
                if let lon = Double(e.value) {
                    gps[kCGImagePropertyGPSLongitude]    = abs(lon) as NSNumber
                    gps[kCGImagePropertyGPSLongitudeRef] = lon >= 0 ? "E" : "W"
                }
            default: break
            }
        }
        let options = NSMutableDictionary()
        options[kCGImagePropertyExifDictionary] = exif
        options[kCGImagePropertyIPTCDictionary] = iptc
        options[kCGImagePropertyTIFFDictionary] = tiff
        if gps.count > 0 { options[kCGImagePropertyGPSDictionary] = gps }
        let outData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(outData as CFMutableData, type, 1, nil) else {
            throw MetadataError.cannotWriteFile
        }
        CGImageDestinationAddImageFromSource(dest, src, 0, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw MetadataError.writeFailed("Finalize fehlgeschlagen")
        }
        try (outData as Data).write(to: url, options: .atomic)
    }

    func defaultEntries() -> [MetadataEntry] {
        [
            entry("Titel",        "iptc.ObjectName",       .general,  ""),
            entry("Beschreibung", "iptc.Caption",          .general,  ""),
            entry("Stichwörter",  "iptc.Keywords",         .general,  ""),
            entry("Copyright",    "iptc.Copyright",        .general,  ""),
            entry("Urheber",      "iptc.Creator",          .general,  ""),
            entry("Aufnahmedatum","exif.DateTimeOriginal", .dateTime, ""),
        ]
    }

    // MARK: – Helpers

    private func entry(_ name: String, _ key: String, _ cat: MetadataCategory, _ val: String) -> MetadataEntry {
        MetadataEntry(displayName: name, key: key, category: cat, value: val, isEditable: true)
    }

    private func roEntry(_ name: String, _ key: String, _ cat: MetadataCategory, _ val: String) -> MetadataEntry {
        MetadataEntry(displayName: name, key: key, category: cat, value: val, isEditable: false)
    }

    private func formatShutter(_ s: Double) -> String {
        s >= 1 ? String(format: "%.1f s", s) : "1/\(Int(1 / s)) s"
    }

    // Extrahiert den eingebetteten JPEG-Preview aus einem RAF-Binärheader und liest dessen EXIF-Properties.
    // RAF v0200/v0201: JPEG-Offset/Länge als Big-Endian UInt32 bei Byte 0x54 / 0x58.
    private func rafEmbeddedJPEGProperties(url: URL) -> [String: Any]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }

        let header = handle.readData(ofLength: 96)
        guard header.count >= 96 else { return nil }

        let sig = String(bytes: header.prefix(16), encoding: .ascii) ?? ""
        guard sig.hasPrefix("FUJIFILMCCD-RAW") else { return nil }

        let jpegOffset = header.readUInt32BE(at: 0x54)
        let jpegLength = header.readUInt32BE(at: 0x58)
        guard jpegOffset > 0, jpegLength > 0 else { return nil }

        // EXIF/IPTC/GPS-Daten stehen immer in den APP-Segmenten am JPEG-Anfang (typisch 2–16 KB).
        // 128 KB reichen auch für große APP1-Blöcke mit eingebettetem Thumbnail.
        // Nur diesen Ausschnitt lesen statt des gesamten ~5.5 MB JPEG → 40× weniger RAM pro Task.
        let readLength = min(Int(jpegLength), 131_072)
        handle.seek(toFileOffset: UInt64(jpegOffset))
        let jpegData = handle.readData(ofLength: readLength)
        guard jpegData.count >= 4,
              jpegData[0] == 0xFF, jpegData[1] == 0xD8 else { return nil }

        guard let src = CGImageSourceCreateWithData(jpegData as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] else { return nil }
        return props
    }
}
