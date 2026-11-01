import Foundation

// Translates a SmartFolder and its criteria into a SQL SELECT statement.
// The generated SQL queries tables: images (i), ratings (r), album_images/albums for album criterion.
// colorRatio and smartFolderRef are left as comments — they require runtime analysis.
enum SmartFolderSQLGenerator {

    static func generate(for sf: SmartFolder, version: String = "?") -> String {
        let dateStr = ISO8601DateFormatter().string(from: Date())
        var header = """
        -- SmartFolder: \(sf.name)
        -- ID: \(sf.id.uuidString)
        -- Generated: \(dateStr) by iPhoto \(version)
        -- matchAll: \(sf.matchAll)
        """

        var clauses: [String] = []
        var notes: [String] = []

        for c in sf.criteria {
            if let clause = whereClause(for: c) {
                clauses.append(clause)
            } else {
                notes.append("-- [runtime] \(c.attribute.displayName): nicht in SQL darstellbar")
            }
        }

        let joiner = sf.matchAll ? "\n  AND " : "\n  OR "
        let whereBlock = clauses.isEmpty
            ? "1=1"
            : clauses.joined(separator: joiner)

        var limitLine = ""
        if sf.limitEnabled && sf.limitCount > 0 {
            let order = limitOrder(for: sf)
            limitLine = "\nORDER BY \(order)\nLIMIT \(sf.limitCount)"
        } else {
            limitLine = "\nORDER BY i.date_taken DESC"
        }

        if !notes.isEmpty { header += "\n" + notes.joined(separator: "\n") }

        return """
        \(header)

        SELECT DISTINCT i.path
        FROM images i
        LEFT JOIN ratings r ON r.image_path = i.path
        WHERE \(whereBlock)\(limitLine);
        """
    }

    // Returns a SQL expression for the given criterion, or nil if it needs runtime evaluation.
    private static func whereClause(for c: SmartFolderCriterion) -> String? {
        switch c.attribute {

        // ── Enum / Bool ─────────────────────────────────────────────────────
        case .flag:
            let val = c.flagValue.rawValue
            return c.op == .isNot ? "COALESCE(r.flag,'none') != '\(val)'"
                                  : "COALESCE(r.flag,'none') = '\(val)'"
        case .colorLabel:
            let val = c.colorValue.rawValue
            return c.op == .isNot ? "COALESCE(r.color_label,'none') != '\(val)'"
                                  : "COALESCE(r.color_label,'none') = '\(val)'"
        case .isRAW:
            let bit = c.boolValue ? 1 : 0
            return "i.is_raw = \(bit)"
        case .hdr:
            let bit = c.boolValue ? 1 : 0
            return "COALESCE(i.hdr,0) = \(bit)"
        case .orientation:
            // boolValue true = portrait, false = landscape
            return c.boolValue ? "i.height > i.width" : "i.width >= i.height"

        // ── Numeric ──────────────────────────────────────────────────────────
        case .rating:
            return numericClause("COALESCE(r.rating,0)", op: c.op,
                                 lo: Double(c.ratingValue), hi: Double(c.ratingValue2))
        case .eloRating:
            return numericClause("COALESCE(r.elo,1500)", op: c.op,
                                 lo: c.numericValue, hi: c.numericValue2)
        case .iso:
            return numericClause("i.iso", op: c.op, lo: c.numericValue, hi: c.numericValue2)
        case .focalLength:
            return numericClause("i.focal_length", op: c.op, lo: c.numericValue, hi: c.numericValue2)
        case .aperture:
            return numericClause("i.aperture", op: c.op, lo: c.numericValue, hi: c.numericValue2)

        // ── Text ─────────────────────────────────────────────────────────────
        case .cameraMake:
            return textClause("LOWER(COALESCE(i.camera_make,''))", op: c.op, val: c.textValue)
        case .cameraModel:
            return textClause("LOWER(COALESCE(i.camera_model,''))", op: c.op, val: c.textValue)
        case .lens:
            return textClause("LOWER(COALESCE(i.lens_model,''))", op: c.op, val: c.textValue)
        case .filmSimulation:
            return textClause("LOWER(COALESCE(i.film_simulation,''))", op: c.op, val: c.textValue)
        case .filename:
            return textClause("LOWER(i.filename)", op: c.op, val: c.textValue)
        case .motif:
            return textClause("LOWER(COALESCE(i.motif_tags,''))", op: c.op, val: c.textValue)

        // ── Date ─────────────────────────────────────────────────────────────
        case .captureDate:
            return dateClause("i.date_taken", op: c.op,
                              lo: c.dateValue, hi: c.dateValue2,
                              dynamic: c.dynamicDateRange)

        // ── Album ────────────────────────────────────────────────────────────
        case .album:
            let escaped = c.textValue.lowercased().replacingOccurrences(of: "'", with: "''")
            let invert = (c.op == .isNot || c.op == .notContains) ? "NOT " : ""
            return """
            i.path \(invert)IN (
              SELECT ai.image_path FROM album_images ai
              JOIN albums a ON a.id = ai.album_id
              WHERE LOWER(a.name) LIKE '%\(escaped)%'
            )
            """

        // ── Nicht in Album ───────────────────────────────────────────────────
        case .notInAlbum:
            return "i.path NOT IN (SELECT ai.image_path FROM album_images ai)"

        // ── Runtime-only ─────────────────────────────────────────────────────
        case .colorRatio, .smartFolderRef:
            return nil
        }
    }

    // MARK: - Clause helpers

    private static func numericClause(_ col: String, op: SmartFolderOperator,
                                      lo: Double, hi: Double) -> String {
        switch op {
        case .isExact:     return "\(col) = \(lo)"
        case .isNot:       return "\(col) != \(lo)"
        case .greaterThan: return "\(col) >= \(lo)"
        case .lessThan:    return "\(col) <= \(lo)"
        case .inRange:     return "\(col) BETWEEN \(lo) AND \(hi)"
        default:           return "\(col) = \(lo)"
        }
    }

    private static func textClause(_ col: String, op: SmartFolderOperator, val: String) -> String {
        let esc = val.lowercased().replacingOccurrences(of: "'", with: "''")
        switch op {
        case .contains:    return "\(col) LIKE '%\(esc)%'"
        case .notContains: return "\(col) NOT LIKE '%\(esc)%'"
        case .beginsWith:  return "\(col) LIKE '\(esc)%'"
        case .endsWith:    return "\(col) LIKE '%\(esc)'"
        case .isExact:     return "\(col) = '\(esc)'"
        case .isNot:       return "\(col) != '\(esc)'"
        default:           return "\(col) LIKE '%\(esc)%'"
        }
    }

    private static func dateClause(_ col: String, op: SmartFolderOperator,
                                   lo: Date, hi: Date,
                                   dynamic: DynamicDateRange) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"

        switch op {
        case .isBefore:    return "\(col) < '\(fmt.string(from: lo))'"
        case .isAfter:     return "\(col) > '\(fmt.string(from: lo))'"
        case .inDateRange: return "\(col) BETWEEN '\(fmt.string(from: lo))' AND '\(fmt.string(from: hi))'"
        case .isDynamic:   return dynamicDateSQL(col: col, range: dynamic)
        default:           return "\(col) = '\(fmt.string(from: lo))'"
        }
    }

    // SQLite date functions for dynamic ranges
    private static func dynamicDateSQL(col: String, range: DynamicDateRange) -> String {
        switch range {
        case .today:      return "\(col) >= date('now','start of day')"
        case .yesterday:  return "\(col) >= date('now','-1 day','start of day') AND \(col) < date('now','start of day')"
        case .thisWeek:   return "\(col) >= date('now','weekday 1','-7 days')"
        case .lastWeek:   return "\(col) >= date('now','weekday 1','-14 days') AND \(col) < date('now','weekday 1','-7 days')"
        case .thisMonth:  return "\(col) >= date('now','start of month')"
        case .lastMonth:  return "\(col) >= date('now','start of month','-1 month') AND \(col) < date('now','start of month')"
        case .thisYear:   return "\(col) >= date('now','start of year')"
        case .last7Days:  return "\(col) >= date('now','-7 days')"
        case .last30Days: return "\(col) >= date('now','-30 days')"
        case .last90Days: return "\(col) >= date('now','-90 days')"
        }
    }

    private static func limitOrder(for sf: SmartFolder) -> String {
        switch sf.limitSelection {
        case .newest:        return "i.date_taken DESC"
        case .oldest:        return "i.date_taken ASC"
        case .highestRating: return "COALESCE(r.rating,0) DESC"
        case .lowestRating:  return "COALESCE(r.rating,0) ASC"
        case .random:        return "RANDOM()"
        }
    }
}
