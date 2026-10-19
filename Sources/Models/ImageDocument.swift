import Foundation
import CoreGraphics
import AppKit

enum FlagStatus: String, Codable { case none, pick, reject }
enum ColorLabel: String, Codable {
    case none, red, yellow, green, blue
    var displayColor: NSColor {
        switch self {
        case .none:   return .clear
        case .red:    return .systemRed
        case .yellow: return .systemYellow
        case .green:  return .systemGreen
        case .blue:   return .systemBlue
        }
    }
    // Finder label index (used by URLResourceKey.labelNumberKey)
    var finderLabelNumber: Int {
        switch self {
        case .none:   return 0
        case .red:    return 6
        case .yellow: return 5
        case .green:  return 2
        case .blue:   return 4
        }
    }
}

struct ImageDocument: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var cgImage: CGImage?
    var previewImage: CGImage?
    var thumbnail: CGImage?
    var thumbnailImage: NSImage?
    var placeholderThumbnailImage: NSImage?
    var imageSize: CGSize
    var isRAW: Bool
    var errorMessage: String?
    var metadata: [MetadataEntry] = []
    var rating: Int = 0
    var flagStatus: FlagStatus = .none
    var colorLabel: ColorLabel = .none
    var isTrashed: Bool = false

    // v1.19.0: ELO-Rating aus Bildvergleich. Bewusst getrennt von rating (Sternen):
    // Sterne bleiben manuelle Nutzerbewertung, ELO ist ein aus paarweisen Duellen
    // errechnetes Ranking. Alle Bilder starten bei 1500 (Standard-ELO-Baseline).
    var elo: Double = 1500
    var eloMatches: Int = 0

    // Qualitäts-Analyse (persistiert in CatalogStore, hier gecacht damit Views nicht pro
    // Render SQLite abfragen). Nil = noch nicht analysiert. Overrides = Nutzer hat manuell
    // "Bild ist doch nicht unscharf/über-/unterbelichtet" gewählt.
    var blurScore: Double? = nil
    var underRatio: Double? = nil
    var overRatio: Double? = nil
    var phash: UInt64? = nil
    // Zweiter, orthogonaler Hash für Similarity — dHash allein (horizontale Gradienten)
    // gruppiert bei dunklen/kontrastarmen Motiven zu aggressiv. phashV (vertikale
    // Gradienten) unabhängig davon, Grouping verlangt Match in beiden Achsen.
    var phashV: UInt64? = nil
    // Kleinste Eye-Aspect-Ratio aller erkannten Gesichter (nil = kein Gesicht erkannt
    // oder noch nicht gescannt). Ein einziges geschlossenes Auge markiert das Bild —
    // "Gruppenfoto mit Blinzler" ist der typische Fehlerfall, den wir fangen wollen.
    var eyeOpenness: Double? = nil
    var qualityScanned: Bool = false
    var blurOverride: Bool = false
    var underOverride: Bool = false
    var overOverride: Bool = false
    var eyesClosedOverride: Bool = false

    // v1.20.0: Automatisch erkannte Motive (VNClassifyImageRequest). Leeres Array =
    // Scan hat keine Treffer ≥ Schwellenwert ergeben. Nil = noch nicht gescannt.
    var motifTags: [String]? = nil
    var motifScanned: Bool = false

    var filename: String { url.lastPathComponent }

    static let rawExtensions: Set<String> = [
        "cr2", "cr3", "nef", "nrw", "arw", "srf", "sr2",
        "dng", "orf", "rw2", "raf", "pef", "srw", "erf",
        "kdc", "dcr", "raw", "rwl", "mrw", "3fr", "mef",
        "iiq", "x3f"
    ]

    static let supportedExtensions: Set<String> = rawExtensions.union([
        "png", "jpg", "jpeg", "tiff", "tif", "gif", "bmp",
        "heic", "heif", "webp", "pdf"
    ])

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.cgImage = nil
        self.thumbnail = nil
        self.imageSize = .zero
        self.isRAW = Self.rawExtensions.contains(url.pathExtension.lowercased())
        self.errorMessage = nil
    }

    static func == (lhs: ImageDocument, rhs: ImageDocument) -> Bool {
        lhs.id == rhs.id
    }
}
