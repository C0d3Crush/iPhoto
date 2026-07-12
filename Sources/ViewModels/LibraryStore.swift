import Foundation
import Combine

/// Besitzt den Bibliotheks-State (Alben, überwachte Ordner, intelligente Ordner,
/// erkannte Volumes) und dessen JSON-Persistenz in Application Support.
/// Orchestrierung (Filesystem-Sync, Ordner-Überwachung, Navigation) bleibt im
/// ImageViewModel. Zugriff nur vom Main-Thread (gleiche Invariante wie ImageCollection).
final class LibraryStore: ObservableObject {
    @Published var albums: [Album] = []
    @Published var watchedFolders: [WatchedFolder] = []
    @Published var smartFolders: [SmartFolder] = []
    @Published var detectedVolumes: [DetectedVolume] = []

    /// Wird bei Persistenz-Fehlern mit einer nutzerlesbaren Meldung aufgerufen.
    var onError: ((String) -> Void)?

    // MARK: - Datei-Pfade

    // Injizierbar für Tests — nil = Application Support/iPhoto (App-Standard)
    private let directoryOverride: URL?

    init(directory: URL? = nil) {
        self.directoryOverride = directory
    }

    // lazy: Verzeichnis nur einmal anlegen; Fehler wird gemeldet statt still verschluckt
    // (sonst evaporieren Alben/Ordner beim nächsten Speichern kommentarlos).
    private lazy var supportDirectory: URL = {
        let dir = directoryOverride
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("iPhoto")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Log.error("Bibliotheks-Verzeichnis konnte nicht erstellt werden: \(error)")
            reportError("Bibliotheks-Verzeichnis: \(error.localizedDescription)")
        }
        return dir
    }()

    private var albumsFileURL: URL         { supportDirectory.appendingPathComponent("albums.json") }
    private var watchedFoldersFileURL: URL { supportDirectory.appendingPathComponent("watchedFolders.json") }
    private var smartFoldersFileURL: URL   { supportDirectory.appendingPathComponent("smartFolders.json") }

    // MARK: - Laden

    func loadAlbums() {
        if let decoded = load([Album].self, from: albumsFileURL, description: "Album-Datei") {
            albums = decoded
        }
    }

    func loadWatchedFolders() {
        if let decoded = load([WatchedFolder].self, from: watchedFoldersFileURL, description: "Ordner-Datei") {
            watchedFolders = decoded
        }
    }

    func loadSmartFolders() {
        if let decoded = load([SmartFolder].self, from: smartFoldersFileURL, description: "SmartFolder-Datei") {
            smartFolders = decoded
        }
    }

    // Fehlende Datei = Erststart (kein Fehler). Vorhandene, aber unlesbare Datei
    // wird gemeldet — der nächste save() würde sie sonst kommentarlos überschreiben.
    private func load<T: Decodable>(_ type: T.Type, from url: URL, description: String) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Log.error("\(description) konnte nicht geladen werden: \(error)")
            reportError("\(description) konnte nicht geladen werden: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Speichern

    func saveAlbums() {
        guard let data = try? JSONEncoder().encode(albums) else { return }
        persist(data, to: albumsFileURL, description: "Album-Datei")
    }

    func saveWatchedFolders() {
        guard let data = try? JSONEncoder().encode(watchedFolders) else { return }
        persist(data, to: watchedFoldersFileURL, description: "Ordner-Datei")
    }

    func saveSmartFolders() {
        guard let data = try? JSONEncoder().encode(smartFolders) else { return }
        persist(data, to: smartFoldersFileURL, description: "SmartFolder-Datei")
    }

    private func persist(_ data: Data, to url: URL, description: String) {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            Log.error("\(description) konnte nicht gespeichert werden: \(error)")
            reportError("\(description): \(error.localizedDescription)")
        }
    }

    private func reportError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onError?(message)
        }
    }
}
