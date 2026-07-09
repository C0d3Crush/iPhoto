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

    private var supportDirectory: URL {
        let dir = directoryOverride
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var albumsFileURL: URL         { supportDirectory.appendingPathComponent("albums.json") }
    private var watchedFoldersFileURL: URL { supportDirectory.appendingPathComponent("watchedFolders.json") }
    private var smartFoldersFileURL: URL   { supportDirectory.appendingPathComponent("smartFolders.json") }

    // MARK: - Laden

    func loadAlbums() {
        guard let data = try? Data(contentsOf: albumsFileURL),
              let decoded = try? JSONDecoder().decode([Album].self, from: data) else { return }
        albums = decoded
    }

    func loadWatchedFolders() {
        guard let data = try? Data(contentsOf: watchedFoldersFileURL),
              let decoded = try? JSONDecoder().decode([WatchedFolder].self, from: data) else { return }
        watchedFolders = decoded
    }

    func loadSmartFolders() {
        guard let data = try? Data(contentsOf: smartFoldersFileURL),
              let decoded = try? JSONDecoder().decode([SmartFolder].self, from: data) else { return }
        smartFolders = decoded
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
            DispatchQueue.main.async { [weak self] in
                self?.onError?("\(description): \(error.localizedDescription)")
            }
        }
    }
}
