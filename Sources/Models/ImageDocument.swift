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
