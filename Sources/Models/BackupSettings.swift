import Foundation
import Combine
import AppKit

/// Konfiguration für die Backup-Funktion (Kontextmenü → „Backup"/„Backup + Papierkorb").
/// Werte werden in UserDefaults persistiert. Zielordner via Security-Scoped-Bookmark,
/// damit die Berechtigung App-Restarts übersteht.
final class BackupSettings: ObservableObject {

    enum CollisionMode: String, CaseIterable, Identifiable {
        case rename    // "foto.jpg" → "foto-2.jpg", "foto-3.jpg", …
        case skip      // vorhandene Datei nicht überschreiben
        case overwrite // überschreiben

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .rename:    return "Umbenennen (foto-2.jpg)"
            case .skip:      return "Überspringen"
            case .overwrite: return "Überschreiben"
            }
        }
    }

    // MARK: - Persistierte Werte

    @Published var jpegQuality: Double {
        didSet { UserDefaults.standard.set(jpegQuality, forKey: Keys.jpegQuality) }
    }
    @Published var copyMetadata: Bool {
        didSet { UserDefaults.standard.set(copyMetadata, forKey: Keys.copyMetadata) }
    }
    @Published var downscaleEnabled: Bool {
        didSet { UserDefaults.standard.set(downscaleEnabled, forKey: Keys.downscaleEnabled) }
    }
    @Published var longSidePixels: Int {
        didSet { UserDefaults.standard.set(longSidePixels, forKey: Keys.longSidePixels) }
    }
    @Published var collisionMode: CollisionMode {
        didSet { UserDefaults.standard.set(collisionMode.rawValue, forKey: Keys.collisionMode) }
    }
    /// Security-Scoped Bookmark auf den gewählten Zielordner. Wird direkt in UserDefaults
    /// gespeichert (keine BookmarkStore-Doppelhaltung nötig — der Zielordner ist einmalig,
    /// nicht per-Bild).
    @Published private(set) var destinationBookmark: Data? {
        didSet { UserDefaults.standard.set(destinationBookmark, forKey: Keys.destinationBookmark) }
    }
    /// Zuletzt gewählter Zielordner (unverschlüsselt, nur zur Anzeige in Settings).
    @Published private(set) var destinationDisplayPath: String {
        didSet { UserDefaults.standard.set(destinationDisplayPath, forKey: Keys.destinationDisplayPath) }
    }

    // MARK: - Defaults

    static let defaultQuality: Double = 0.85
    static let defaultLongSide: Int   = 2560
    static var defaultDestinationURL: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
            .appendingPathComponent("Backups")
    }

    init() {
        let d = UserDefaults.standard
        self.jpegQuality       = (d.object(forKey: Keys.jpegQuality) as? Double) ?? Self.defaultQuality
        self.copyMetadata      = (d.object(forKey: Keys.copyMetadata) as? Bool) ?? true
        self.downscaleEnabled  = (d.object(forKey: Keys.downscaleEnabled) as? Bool) ?? false
        self.longSidePixels    = (d.object(forKey: Keys.longSidePixels) as? Int) ?? Self.defaultLongSide
        let mode = d.string(forKey: Keys.collisionMode).flatMap(CollisionMode.init(rawValue:))
        self.collisionMode     = mode ?? .rename
        self.destinationBookmark    = d.data(forKey: Keys.destinationBookmark)
        self.destinationDisplayPath = d.string(forKey: Keys.destinationDisplayPath)
            ?? Self.defaultDestinationURL.path
    }

    // MARK: - Zielordner-Handling

    /// Setzt den Zielordner. Legt ein Security-Scoped-Bookmark an, das App-Restarts übersteht.
    func setDestination(_ url: URL) {
        let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        destinationBookmark = data
        destinationDisplayPath = url.path
    }

    /// Auflösung des gespeicherten Bookmarks. Fällt zurück auf `defaultDestinationURL`,
    /// wenn (noch) kein Bookmark existiert — z. B. beim ersten Backup nach Installation.
    /// Der Aufrufer MUSS `stop()` aufrufen, sobald er mit dem URL fertig ist.
    func resolveDestination() -> (url: URL, stop: () -> Void) {
        if let data = destinationBookmark {
            var stale = false
            if let resolved = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                let didStart = resolved.startAccessingSecurityScopedResource()
                if stale { setDestination(resolved) }
                return (resolved, { if didStart { resolved.stopAccessingSecurityScopedResource() } })
            }
        }
        // Kein Bookmark oder Auflösung fehlgeschlagen → Default in ~/Pictures/iPhoto/Backups/.
        // Ordner unterhalb von ~/Pictures ist unter macOS ohne User-Prompt beschreibbar,
        // solange die App den entsprechenden Berechtigungshinweis bekommt.
        let url = Self.defaultDestinationURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return (url, {})
    }

    // MARK: - Storage keys

    private enum Keys {
        static let jpegQuality           = "backup.jpegQuality"
        static let copyMetadata          = "backup.copyMetadata"
        static let downscaleEnabled      = "backup.downscaleEnabled"
        static let longSidePixels        = "backup.longSidePixels"
        static let collisionMode         = "backup.collisionMode"
        static let destinationBookmark   = "backup.destinationBookmark"
        static let destinationDisplayPath = "backup.destinationDisplayPath"
    }
}
