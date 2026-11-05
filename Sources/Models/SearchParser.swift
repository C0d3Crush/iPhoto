import Foundation

struct SearchToken: Equatable {
    let key: String   // empty = free text
    let value: String
    var isFilter: Bool { !key.isEmpty }
}

struct SearchQuery: Equatable {
    let tokens: [SearchToken]
    let raw: String

    var freeText: String {
        tokens.filter { !$0.isFilter }.map { $0.value }.joined(separator: " ")
    }
    var filters: [SearchToken] { tokens.filter { $0.isFilter } }

    static func parse(_ raw: String) -> SearchQuery {
        var tokens: [SearchToken] = []
        for part in raw.components(separatedBy: " ") where !part.isEmpty {
            if let ci = part.firstIndex(of: ":"), ci != part.startIndex {
                let key = String(part[..<ci]).lowercased()
                let value = String(part[part.index(after: ci)...])
                if !value.isEmpty, FilterDefinition.all.contains(where: { $0.key == key }) {
                    tokens.append(SearchToken(key: key, value: value))
                    continue
                }
            }
            tokens.append(SearchToken(key: "", value: part))
        }
        return SearchQuery(tokens: tokens, raw: raw)
    }
}

struct FilterDefinition {
    let key: String
    let icon: String
    let label: String
    let hint: String
    let valueSuggestions: [String]

    static let all: [FilterDefinition] = [
        .init(key: "bewertung",  icon: "star.fill",                         label: "Bewertung",      hint: "1–5",                    valueSuggestions: ["5","4","3","2","1"]),
        .init(key: "typ",        icon: "doc",                               label: "Typ",             hint: "jpg, raw, png, heic…",   valueSuggestions: ["jpg","raw","png","heic","tiff"]),
        .init(key: "vor",        icon: "calendar",                          label: "Vor Datum",       hint: "JJJJ oder JJJJ-MM-TT",  valueSuggestions: ["2025","2024","2023","2022"]),
        .init(key: "nach",       icon: "calendar.badge.clock",              label: "Nach Datum",      hint: "JJJJ oder JJJJ-MM-TT",  valueSuggestions: ["2025","2024","2023","2022"]),
        .init(key: "kamera",     icon: "camera",                            label: "Kamera",          hint: "Hersteller oder Modell", valueSuggestions: []),
        .init(key: "album",      icon: "photo.on.rectangle",                label: "Album",           hint: "Albumname",              valueSuggestions: []),
        .init(key: "markiert",   icon: "flag",                              label: "Markiert",        hint: "pick, reject",           valueSuggestions: ["pick","reject"]),
        .init(key: "unscharf",   icon: "eye.trianglebadge.exclamationmark", label: "Unscharf",        hint: "ja / nein",              valueSuggestions: ["ja","nein"]),
        .init(key: "motiv",      icon: "tag",                               label: "Motiv",           hint: "erkanntes Motiv",        valueSuggestions: []),
        .init(key: "elo",        icon: "chart.line.uptrend.xyaxis",         label: "ELO",             hint: ">=1600  <=1800  >1500  <2000",   valueSuggestions: [">=1600",">=1700",">=1800","<=1600","<=1500","<1500"]),
        .init(key: "farbe",      icon: "circle.fill",                       label: "Farbmarkierung",  hint: "rot, gelb, grün, blau",  valueSuggestions: ["rot","gelb","grün","blau"]),
    ]
}
