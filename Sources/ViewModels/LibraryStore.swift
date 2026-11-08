import Foundation
import Combine

/// Besitzt den Bibliotheks-State (Alben, überwachte Ordner, intelligente Ordner,
/// erkannte Volumes) und dessen JSON-Persistenz in Application Support.
/// Orchestrierung (Filesystem-Sync, Ordner-Überwachung, Navigation) bleibt im
/// ImageViewModel. Zugriff nur vom Main-Thread (gleiche Invariante wie ImageCollection).
final class LibraryStore: ObservableObject {
    @Published var albums: [Album] = []
    @Published var albumFolders: [AlbumFolder] = []
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
    private var albumFoldersFileURL: URL   { supportDirectory.appendingPathComponent("albumFolders.json") }
    private var watchedFoldersFileURL: URL { supportDirectory.appendingPathComponent("watchedFolders.json") }
    private var smartFoldersFileURL: URL   { supportDirectory.appendingPathComponent("smartFolders.json") }

    // MARK: - Laden

    func loadAlbums() {
        if let decoded = load([Album].self, from: albumsFileURL, description: "Album-Datei") {
            albums = decoded
        }
    }

    func loadAlbumFolders() {
        // Datei existiert erst nach dem ersten Anlegen eines Ordners — leer = ok.
        if let decoded = load([AlbumFolder].self, from: albumFoldersFileURL, description: "Album-Ordner-Datei") {
            albumFolders = decoded
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

    func saveAlbums() { asyncPersist(albums, to: albumsFileURL, description: "Album-Datei") }

    func saveAlbumFolders() { asyncPersist(albumFolders, to: albumFoldersFileURL, description: "Album-Ordner-Datei") }

    func saveWatchedFolders() { asyncPersist(watchedFolders, to: watchedFoldersFileURL, description: "Ordner-Datei") }

    func saveSmartFolders() { asyncPersist(smartFolders, to: smartFoldersFileURL, description: "SmartFolder-Datei") }

    // Encoder + atomic write auf Utility-Queue — kein Haupt-Thread-Blocking für
    // JSON-Encode (100–600 µs bei 30+ Alben) + Disk-Write (.atomic = rename-after-write).
    private func asyncPersist<T: Encodable>(_ value: T, to url: URL, description: String) {
        let capturedURL = url
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let data = try? JSONEncoder().encode(value) else { return }
            do {
                try data.write(to: capturedURL, options: .atomic)
            } catch {
                Log.error("\(description) konnte nicht gespeichert werden: \(error)")
                self?.reportError("\(description): \(error.localizedDescription)")
            }
        }
    }

    private func reportError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onError?(message)
        }
    }
}
