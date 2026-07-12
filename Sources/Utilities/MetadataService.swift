import Foundation
import ImageIO

final class MetadataService {

    func readPhotoMetadata(from url: URL) -> [MetadataEntry] {
        var props: [String: Any]
        var fujiDynamicRange: Int? = nil
        var fujiFilmSim: String? = nil
        var fujiWhiteBalance: String? = nil
        var fujiSequenceNumber: Int? = nil
        var fujiAutoBracketing: Int? = nil

        if url.pathExtension.lowercased() == "raf" {
            let jpegData = rafEmbeddedJPEGData(url: url)
            let mnValues = jpegData.flatMap { fujiMakerNoteValues(from: $0) }
            fujiDynamicRange = mnValues?.dr
            fujiFilmSim = MetadataService.resolveFilmSim(filmSim: mnValues?.filmSim, saturation: mnValues?.saturation)
            fujiWhiteBalance = mnValues.flatMap { MetadataService.fujiWhiteBalanceDisplay($0) }
            fujiSequenceNumber = mnValues?.sequenceNumber
            fujiAutoBracketing = mnValues?.autoBracketing

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
                        fujiWhiteBalance = MetadataService.fujiWhiteBalanceDisplay(mnValues)
                        fujiSequenceNumber = mnValues.sequenceNumber
                        fujiAutoBracketing = mnValues.autoBracketing
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
        if fujiFilmSim == nil || fujiWhiteBalance == nil || fujiSequenceNumber == nil {
            if let mnData = exif[kCGImagePropertyExifMakerNote as String] as? Data {
                let r = parseFujiMakerNoteBytes(mnData)
                if fujiDynamicRange == nil { fujiDynamicRange = r.dr }
                if fujiFilmSim == nil {
                    fujiFilmSim = MetadataService.resolveFilmSim(filmSim: r.filmSim, saturation: r.saturation)
                }
                if fujiWhiteBalance == nil {
                    fujiWhiteBalance = MetadataService.fujiWhiteBalanceDisplay(r)
                }
                if fujiSequenceNumber == nil { fujiSequenceNumber = r.sequenceNumber }
                if fujiAutoBracketing == nil { fujiAutoBracketing = r.autoBracketing }
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

        if let pw = props[kCGImagePropertyPixelWidth as String] as? Int,
           let ph = props[kCGImagePropertyPixelHeight as String] as? Int {
            entries.append(roEntry("Größe", "image.PixelSize", .general, "\(pw) × \(ph) px"))
        }

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

        // Weißabgleich: Fuji-MakerNote liefert den konkreten Modus (Tageslicht, Kelvin …),
        // Standard-EXIF nur Automatisch/Manuell (0/1).
        var wbValue = fujiWhiteBalance ?? ""
        if wbValue.isEmpty, let exifWB = exif[kCGImagePropertyExifWhiteBalance as String] as? Int {
            wbValue = exifWB == 1 ? "Manuell" : "Automatisch"
        }
        if !wbValue.isEmpty {
            entries.append(roEntry("Weißabgleich", "exif.WhiteBalance", .camera, wbValue))
        }

        let customRendered = exif[kCGImagePropertyExifCustomRendered as String] as? Int ?? 0
        let isHDR = customRendered >= 2 || (fujiDynamicRange ?? 100) > 100
        entries.append(roEntry("HDR", "exif.HDR", .camera, isHDR ? "Ja" : "Nein"))
        if let sim = fujiFilmSim {
            entries.append(roEntry("Filmsimulation", "exif.FilmSimulation", .camera, sim))
        }
        if let seq = fujiSequenceNumber, seq > 0 {
            entries.append(roEntry("Serienbild-Nr.", "exif.SequenceNumber", .camera, "\(seq)"))
        }
        if let bkt = fujiAutoBracketing {
            entries.append(roEntry("Auto-Bracketing", "exif.AutoBracketing", .camera, bkt != 0 ? "Ja" : "Nein"))
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

    struct FujiMakerNoteValues {
        var dr: Int? = nil
        var filmSim: Int? = nil
        var saturation: Int? = nil
        var whiteBalance: Int? = nil
        var colorTemp: Int? = nil
        // WB-Feintuning in Kamera-Schritten (Rot/Blau, jeweils −9…+9)
        var wbShiftR: Int? = nil
        var wbShiftB: Int? = nil
        // Serienbild/Bracketing: 0x1100 (AutoBracketing), 0x1101 (SequenceNumber, 0 = Einzelbild)
        var autoBracketing: Int? = nil
        var sequenceNumber: Int? = nil

        var isEmpty: Bool {
            dr == nil && filmSim == nil && saturation == nil && whiteBalance == nil
        }
    }

    // Parst rohe Fujifilm MakerNote-Bytes (Signatur "FUJIFILM" + LE IFD-Offset + IFD).
    // Genutzt als Fallback wenn ImageIO die MakerNote via kCGImagePropertyExifMakerNote liefert.
    // saturation: Tag 0x1003 — kodiert B&W/Acros-Modus auf neueren Kameras (X-T4+),
    // die Tag 0x1401 für diese Simulationen nicht setzen.
    func parseFujiMakerNoteBytes(_ data: Data) -> FujiMakerNoteValues {
        guard data.count >= 12,
              data.subdata(in: 0..<8) == Data("FUJIFILM".utf8) else { return FujiMakerNoteValues() }
        let ifdOff = Int(data.readUInt32LE(at: 8))
        let ifd = ifdOff
        guard ifd + 2 <= data.count else { return FujiMakerNoteValues() }
        let count = Int(data.readUInt16LE(at: ifd))
        guard count > 0, count < 500 else { return FujiMakerNoteValues() }
        var v = FujiMakerNoteValues()
        var dr1403: Int? = nil
        var dr140B: Int? = nil
        for j in 0..<count {
            let fe = ifd + 2 + j * 12
            guard fe + 12 <= data.count else { break }
            let ftag = data.readUInt16LE(at: fe)
            // UInt32 lesen und auf 16 Bit maskieren — robuster als reines UInt16 für LONG-Einträge
            if ftag == 0x1002 { v.whiteBalance = Int(data.readUInt32LE(at: fe + 8)) & 0xFFFF }
            if ftag == 0x1100 { v.autoBracketing = Int(data.readUInt32LE(at: fe + 8)) & 0xFFFF }
            if ftag == 0x1101 { v.sequenceNumber = Int(data.readUInt32LE(at: fe + 8)) & 0xFFFF }
            if ftag == 0x1003 { v.saturation = Int(data.readUInt16LE(at: fe + 8)) }
            if ftag == 0x1005 { v.colorTemp  = Int(data.readUInt16LE(at: fe + 8)) }
            if ftag == 0x1401 { v.filmSim    = Int(data.readUInt32LE(at: fe + 8)) & 0xFFFF }
            if ftag == 0x1403 { dr1403       = Int(data.readUInt16LE(at: fe + 8)) }
            if ftag == 0x140B { dr140B       = Int(data.readUInt16LE(at: fe + 8)) }
            // Tag 0x100A: WhiteBalanceFineTune — 2× SLONG (8 Bytes passen nicht ins
            // Wertfeld, dort steht ein Offset relativ zum MakerNote-Anfang).
            // Rohwerte in Einheiten von 20 pro Kamera-Schritt (Rot, Blau).
            if ftag == 0x100A {
                let valOff = Int(data.readUInt32LE(at: fe + 8))
                if valOff + 8 <= data.count {
                    let rawR = Int(Int32(bitPattern: data.readUInt32LE(at: valOff)))
                    let rawB = Int(Int32(bitPattern: data.readUInt32LE(at: valOff + 4)))
                    // Plausibilität: ±9 Schritte à 20
                    if abs(rawR) <= 180, abs(rawB) <= 180 {
                        v.wbShiftR = rawR / 20
                        v.wbShiftB = rawB / 20
                    }
                }
            }
        }
        v.dr = dr1403 ?? dr140B
        return v
    }

    // Sucht die "FUJIFILM"-MakerNote-Signatur direkt in den Rohdaten (kein TIFF-Traversal nötig).
    func fujiMakerNoteValues(from data: Data) -> FujiMakerNoteValues {
        let sig = Data("FUJIFILM".utf8)
        var lo = data.startIndex
        while let r = data.range(of: sig, options: [], in: lo..<data.endIndex) {
            let result = parseFujiMakerNoteBytes(data.subdata(in: r.lowerBound..<data.endIndex))
            if !result.isEmpty { return result }
            lo = r.upperBound
        }
        return FujiMakerNoteValues()
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

    // Kombiniert Modus (0x1002), Kelvin-Temperatur (0x1005) und Feintuning-Shift
    // (0x100A) zu einem Anzeige-String, z. B. „Tageslicht (R+2, B−1)".
    static func fujiWhiteBalanceDisplay(_ v: FujiMakerNoteValues) -> String? {
        guard let wb = v.whiteBalance else { return nil }
        var name = fujiWhiteBalanceName(wb, colorTemp: v.colorTemp)
        guard !name.isEmpty else { return nil }
        if let r = v.wbShiftR, let b = v.wbShiftB, r != 0 || b != 0 {
            name += String(format: " (R%+d, B%+d)", r, b)
        }
        return name
    }

    // Tag 0x1002: Fuji-Weißabgleich-Modus (deutlich feiner als EXIF-Auto/Manuell).
    // Kelvin-Modus (0xFF0) zeigt zusätzlich die Farbtemperatur aus Tag 0x1005.
    static func fujiWhiteBalanceName(_ raw: Int, colorTemp: Int?) -> String {
        let name: String
        switch raw {
        case 0x000: name = "Automatisch"
        case 0x001: name = "Automatisch (Weiß-Priorität)"
        case 0x002: name = "Automatisch (Umgebungs-Priorität)"
        case 0x100: name = "Tageslicht"
        case 0x200: name = "Bewölkt"
        case 0x300: name = "Leuchtstoff (Tageslicht)"
        case 0x301: name = "Leuchtstoff (Neutralweiß)"
        case 0x302: name = "Leuchtstoff (Weiß)"
        case 0x303: name = "Leuchtstoff (Warmweiß)"
        case 0x304: name = "Leuchtstoff (Wohnraum-Warmweiß)"
        case 0x400: name = "Glühlampe"
        case 0x500: name = "Blitz"
        case 0x600: name = "Unterwasser"
        case 0xF00: name = "Benutzerdefiniert"
        case 0xF01: name = "Benutzerdefiniert 2"
        case 0xF02: name = "Benutzerdefiniert 3"
        case 0xF03: name = "Benutzerdefiniert 4"
        case 0xF04: name = "Benutzerdefiniert 5"
        case 0xFF0: name = "Kelvin"
        default: return ""
        }
        if raw == 0xFF0, let t = colorTemp, t > 0 {
            return "Kelvin (\(t) K)"
        }
        return name
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

