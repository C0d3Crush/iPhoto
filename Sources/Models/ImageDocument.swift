import Foundation
import CoreGraphics

struct ImageDocument: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var cgImage: CGImage?
    var thumbnail: CGImage?
    var imageSize: CGSize
    var isRAW: Bool
    var errorMessage: String?

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
