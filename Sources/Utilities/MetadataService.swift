import Foundation
import ImageIO

final class MetadataService {

    func readPhotoMetadata(from url: URL) -> [MetadataEntry] {
        var props: [String: Any]
        var fujiDynamicRange: Int? = nil
        var fujiFilmSim: String? = nil

        if url.pathExtension.lowercased() == "raf" {
            let jpegData = rafEmbeddedJPEGData(url: url)
            let mnValues = jpegData.flatMap { fujiMakerNoteValues(from: $0) }
            fujiDynamicRange = mnValues?.dr
            fujiFilmSim = MetadataService.resolveFilmSim(filmSim: mnValues?.filmSim, saturation: mnValues?.saturation)

            if #available(macOS 12.0, *) {
                // macOS 12+: ImageIO unterstützt RAF nativ
                guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
                props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] ?? [:]
                let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
                let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
                if (tiff[kCGImagePropertyTIFFMake as String] as? String ?? "").isEmpty,
                   (exif[kCGImagePropertyExifDateTimeOriginal as String] as? String ?? "").isEmpty,
                   let jd = jpegData, let jpegProps = propertiesFromJPEGData(jd) {
                    props = jpegProps
                }
            } else {
                // macOS 11: CGImageSourceCreateWithURL auf RAF-Dateien ruft den Apple Fujifilm-Plugin auf → SIGSEGV.
                // Direkt aus dem eingebetteten JPEG-Preview lesen.
                props = jpegData.flatMap { propertiesFromJPEGData($0) } ?? [:]
            }
        } else {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
            props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] ?? [:]
            // Fuji JPEG: MakerNote aus rohen Dateidaten parsen (ImageIO liefert MakerNote nicht)
            let ext = url.pathExtension.lowercased()
            if ["jpg", "jpeg"].contains(ext) {
                let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
                let make = tiff[kCGImagePropertyTIFFMake as String] as? String ?? ""
                if make.localizedCaseInsensitiveContains("fuji"),
                   let handle = try? FileHandle(forReadingFrom: url) {
                    let raw = handle.readData(ofLength: 524_288)
                    handle.closeFile()
                    if raw.count >= 2, raw[0] == 0xFF, raw[1] == 0xD8 {
                        let mnValues = fujiMakerNoteValues(from: raw)
                        fujiDynamicRange = mnValues.dr
                        fujiFilmSim = MetadataService.resolveFilmSim(filmSim: mnValues.filmSim, saturation: mnValues.saturation)
                    }
                }
            }
        }

        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let iptc = props[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        let gps  = props[kCGImagePropertyGPSDictionary  as String] as? [String: Any] ?? [:]
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]

        // Fallback: kCGImagePropertyExifMakerNote direkt von ImageIO parsen.
        // ImageIO liefert die rohen MakerNote-Bytes bei Fuji RAFs und JPEGs — zuverlässiger als
        // manuelles JPEG-Segment-Scanning und deckt B&W-Simulationen (Monochrome/Acros) ab.
        if fujiFilmSim == nil {
            if let mnData = exif[kCGImagePropertyExifMakerNote as String] as? Data {
                let r = parseFujiMakerNoteBytes(mnData)
                if fujiDynamicRange == nil { fujiDynamicRange = r.dr }
                fujiFilmSim = MetadataService.resolveFilmSim(filmSim: r.filmSim, saturation: r.saturation)
            }
        }

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

        let customRendered = exif[kCGImagePropertyExifCustomRendered as String] as? Int ?? 0
        let isHDR = customRendered >= 2 || (fujiDynamicRange ?? 100) > 100
        entries.append(roEntry("HDR", "exif.HDR", .camera, isHDR ? "Ja" : "Nein"))
        if let sim = fujiFilmSim {
            entries.append(roEntry("Filmsimulation", "exif.FilmSimulation", .camera, sim))
        }

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

    // RAF v0200/v0201: JPEG-Offset/Länge als Big-Endian UInt32 bei Byte 0x54 / 0x58.
    // Liest max. 128 KB (APP-Segmente enthalten alle EXIF/MakerNote-Daten; spart ~40× RAM).
    private func rafEmbeddedJPEGData(url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }
        let header = handle.readData(ofLength: 96)
        guard header.count >= 96,
              (String(bytes: header.prefix(16), encoding: .ascii) ?? "").hasPrefix("FUJIFILMCCD-RAW") else { return nil }
        let jpegOffset = header.readUInt32BE(at: 0x54)
        let jpegLength = header.readUInt32BE(at: 0x58)
        guard jpegOffset > 0, jpegLength > 0 else { return nil }
        handle.seek(toFileOffset: UInt64(jpegOffset))
        let data = handle.readData(ofLength: min(Int(jpegLength), 524_288))
        guard data.count >= 4, data[0] == 0xFF, data[1] == 0xD8 else { return nil }
        return data
    }

    private func propertiesFromJPEGData(_ data: Data) -> [String: Any]? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any]
    }

    // Parst rohe Fujifilm MakerNote-Bytes (Signatur "FUJIFILM" + LE IFD-Offset + IFD).
    // Genutzt als Fallback wenn ImageIO die MakerNote via kCGImagePropertyExifMakerNote liefert.
    // saturation: Tag 0x1003 — kodiert B&W/Acros-Modus auf neueren Kameras (X-T4+),
    // die Tag 0x1401 für diese Simulationen nicht setzen.
    func parseFujiMakerNoteBytes(_ data: Data) -> (dr: Int?, filmSim: Int?, saturation: Int?) {
        guard data.count >= 12,
              data.subdata(in: 0..<8) == Data("FUJIFILM".utf8) else { return (nil, nil, nil) }
        let ifdOff = Int(data.readUInt32LE(at: 8))
        let ifd = ifdOff
        guard ifd + 2 <= data.count else { return (nil, nil, nil) }
        let count = Int(data.readUInt16LE(at: ifd))
        guard count > 0, count < 500 else { return (nil, nil, nil) }
        var filmSim: Int? = nil
        var saturation: Int? = nil
        var dr1403: Int? = nil
        var dr140B: Int? = nil
        for j in 0..<count {
            let fe = ifd + 2 + j * 12
            guard fe + 12 <= data.count else { break }
            let ftag = data.readUInt16LE(at: fe)
            // UInt32 lesen und auf 16 Bit maskieren — robuster als reines UInt16 für LONG-Einträge
            if ftag == 0x1003 { saturation = Int(data.readUInt16LE(at: fe + 8)) }
            if ftag == 0x1401 { filmSim    = Int(data.readUInt32LE(at: fe + 8)) & 0xFFFF }
            if ftag == 0x1403 { dr1403     = Int(data.readUInt16LE(at: fe + 8)) }
            if ftag == 0x140B { dr140B     = Int(data.readUInt16LE(at: fe + 8)) }
        }
        return (dr1403 ?? dr140B, filmSim, saturation)
    }

    // Sucht die "FUJIFILM"-MakerNote-Signatur direkt in den Rohdaten (kein TIFF-Traversal nötig).
    func fujiMakerNoteValues(from data: Data) -> (dr: Int?, filmSim: Int?, saturation: Int?) {
        let sig = Data("FUJIFILM".utf8)
        var lo = data.startIndex
        while let r = data.range(of: sig, options: [], in: lo..<data.endIndex) {
            let result = parseFujiMakerNoteBytes(data.subdata(in: r.lowerBound..<data.endIndex))
            if result.dr != nil || result.filmSim != nil || result.saturation != nil { return result }
            lo = r.upperBound
        }
        return (nil, nil, nil)
    }

    // Löst Film-Simulation aus Tag 0x1401 (primär) oder 0x1003 (Fallback für B&W/Acros).
    static func resolveFilmSim(filmSim: Int?, saturation: Int?) -> String? {
        if let fs = filmSim {
            let name = filmSimulationName(fs)
            if !name.isEmpty { return name }
        }
        if let sat = saturation {
            let name = filmSimulationFromSaturation(sat)
            if !name.isEmpty { return name }
        }
        return nil
    }

    // Tag 0x1401: standard Film-Simulations-Code (Farb-Simulationen)
    static func filmSimulationName(_ raw: Int) -> String {
        switch raw {
        case 0x0000: return "Provia/Standard"
        case 0x0100: return "Velvia/Vivid"
        case 0x0110: return "Velvia"
        case 0x0120: return "Astia/Soft"   // X-T4 custom-profile variant
        case 0x0200: return "Astia/Soft"
        case 0x0300: return "Classic Chrome"
        case 0x0400: return "Pro Neg. Hi"
        case 0x0500: return "Pro Neg. Std"
        case 0x0501: return "Pro Neg. Hi"  // X-T4 variant code
        case 0x0600: return "Classic Neg."
        case 0x0700: return "Eterna/Cinema"
        case 0x0800: return "Eterna Bleach Bypass"
        case 0x0900: return "Nostalgic Neg."
        case 0x0A00: return "Reala ACE"
        case 0x8000: return "Monochrome"
        case 0x8001: return "Monochrome+R Filter"
        case 0x8002: return "Monochrome+Ye Filter"
        case 0x8003: return "Monochrome+G Filter"
        case 0x8100: return "Sepia"
        case 0x8200: return "Acros"
        case 0x8201: return "Acros+R Filter"
        case 0x8202: return "Acros+Ye Filter"
        case 0x8203: return "Acros+G Filter"
        default: return ""
        }
    }

    // Tag 0x1003 (Saturation): kodiert B&W/Acros auf X-T4+ wenn 0x1401 fehlt
    static func filmSimulationFromSaturation(_ raw: Int) -> String {
        switch raw {
        case 0x0300: return "Monochrome"
        case 0x0301: return "Monochrome+R Filter"
        case 0x0302: return "Monochrome+Ye Filter"
        case 0x0303: return "Monochrome+G Filter"
        case 0x0310: return "Sepia"
        case 0x0500: return "Acros"
        case 0x0501: return "Acros+R Filter"
        case 0x0502: return "Acros+Ye Filter"
        case 0x0503: return "Acros+G Filter"
        default: return ""
        }
    }

    static let allFilmSimulations: [String] = [
        "Provia/Standard", "Velvia/Vivid", "Velvia", "Astia/Soft",
        "Classic Chrome", "Pro Neg. Hi", "Pro Neg. Std", "Classic Neg.",
        "Eterna/Cinema", "Eterna Bleach Bypass", "Nostalgic Neg.", "Reala ACE",
        "Monochrome", "Monochrome+R Filter", "Monochrome+Ye Filter", "Monochrome+G Filter",
        "Sepia", "Acros", "Acros+R Filter", "Acros+Ye Filter", "Acros+G Filter",
    ]

}

