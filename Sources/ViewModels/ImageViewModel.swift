import SwiftUI
import Combine
import AppKit

class ImageViewModel: ObservableObject {
    @Published var collection = ImageCollection()
    @Published var zoomFactor: CGFloat = 1.0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var fitToWindowRequested: Bool = false
    @Published var showExportSheet: Bool = false
    @Published var inspectorVisible: Bool = false
    @Published var isSavingMetadata: Bool = false
    @Published var navSidebarVisible: Bool = true
    @Published var navSelection: NavSelection? = .library
    @Published var albums: [Album] = []

    private let metadataService = MetadataService()
    private var cancellables = Set<AnyCancellable>()
    private var loadToken: UUID = UUID()

    var currentImage: CGImage? { collection.currentDocument?.cgImage }
    var windowTitle: String { collection.currentDocument?.filename ?? "iPhoto" }
    var imageSize: CGSize { collection.currentDocument?.imageSize ?? .zero }

    var visibleDocuments: [ImageDocument] {
        switch navSelection {
        case .library, nil:
            return collection.documents
        case .album(let id):
            guard let album = albums.first(where: { $0.id == id }) else { return [] }
            return collection.documents.filter { album.photoURLs.contains($0.url) }
        }
    }

    func collectionIndex(for document: ImageDocument) -> Int? {
        collection.documents.firstIndex(where: { $0.id == document.id })
    }

    init() {
        loadAlbums()
        // Änderungen in collection (z.B. neue Thumbnails) an SwiftUI weiterleiten
        collection.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .importRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.importFileDialog() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .openURLs)
            .receive(on: DispatchQueue.main)
            .compactMap { $0.object as? [URL] }
            .sink { [weak self] urls in
                guard let self = self else { return }
                self.importFiles(urls)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .clearCollection)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.clearAll() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .exportRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.showExportSheet = true }
            .store(in: &cancellables)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            switch event.keyCode {
            case 123: DispatchQueue.main.async { self.previous() }; return nil
            case 124: DispatchQueue.main.async { self.next()     }; return nil
            default:  return event
            }
        }
    }

    func importFileDialog() {
        FileOpenHelper.openPanel { [weak self] urls in
            guard let self = self, !urls.isEmpty else { return }
            self.importFiles(urls)
        }
    }

    // Fügt Bilder zur bestehenden Sammlung hinzu (keine Duplikate)
    func importFiles(_ urls: [URL]) {
        let supported = urls.filter { isSupportedFormat($0) }
        guard !supported.isEmpty else { return }

        let existingURLs = Set(collection.documents.map { $0.url })
        let newURLs = supported.filter { !existingURLs.contains($0) }
        guard !newURLs.isEmpty else { return }

        newURLs.forEach { BookmarkStore.shared.save(url: $0) }
        let newDocs = newURLs
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { ImageDocument(url: $0) }

        let firstNewIndex = collection.documents.count
        collection.appendDocuments(newDocs)
        collection.select(index: firstNewIndex)
        loadCurrentImage()
        loadThumbnails()
    }

    func clearAll() {
        collection.documents = []
        collection.currentIndex = 0
        isLoading = false
        errorMessage = nil
        fitToWindowRequested = false
    }

    func selectDocument(at index: Int) {
        collection.select(index: index)
        loadCurrentImage()
    }

    func next()     { collection.next();     loadCurrentImage(); prefetchAdjacent() }
    func previous() { collection.previous(); loadCurrentImage(); prefetchAdjacent() }

    func zoomIn()           { zoomFactor = min(zoomFactor * 1.25, 32.0) }
    func zoomOut()          { zoomFactor = max(zoomFactor / 1.25, 0.05) }
    func actualSize()       { zoomFactor = 1.0 }
    func fitToWindow()      { fitToWindowRequested = true }
    func toggleInspector()  { inspectorVisible.toggle() }

    // MARK: - Albums

    func selectAlbum(_ album: Album) {
        navSelection = .album(album.id) as NavSelection?
        Log.info("Album gewählt: '\(album.name)' (\(album.photoURLs.count) Fotos)")

        // Import photos not yet in collection
        let missing = album.photoURLs.filter { url in
            !collection.documents.contains(where: { $0.url == url })
        }
        if !missing.isEmpty {
            Log.info("Importiere \(missing.count) fehlende Album-Fotos")
            importFiles(missing)
        }

        // Select first album photo that's already in collection
        if let firstURL = album.photoURLs.first,
           let idx = collection.documents.firstIndex(where: { $0.url == firstURL }) {
            Log.info("Wähle erstes Album-Foto bei Index \(idx)")
            selectDocument(at: idx)
        }
    }

    func createAlbum(name: String) {
        let album = Album(name: name)
        albums.append(album)
        saveAlbums()
        navSelection = .album(album.id) as NavSelection?
    }

    func deleteAlbum(_ album: Album) {
        albums.removeAll { $0.id == album.id }
        if navSelection == .album(album.id) { navSelection = .library as NavSelection? }
        saveAlbums()
    }

    func renameAlbum(_ album: Album, to name: String) {
        guard let idx = albums.firstIndex(where: { $0.id == album.id }) else { return }
        albums[idx].name = name
        saveAlbums()
    }

    func addToAlbum(_ document: ImageDocument, albumID: UUID) {
        guard let idx = albums.firstIndex(where: { $0.id == albumID }) else { return }
        guard !albums[idx].photoURLs.contains(document.url) else { return }
        albums[idx].photoURLs.append(document.url)
        saveAlbums()
    }

    func removeFromAlbum(_ document: ImageDocument, albumID: UUID) {
        guard let idx = albums.firstIndex(where: { $0.id == albumID }) else { return }
        albums[idx].photoURLs.removeAll { $0 == document.url }
        saveAlbums()
    }

    private var albumsFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("albums.json")
    }

    func loadAlbums() {
        guard let data = try? Data(contentsOf: albumsFileURL),
              let decoded = try? JSONDecoder().decode([Album].self, from: data) else { return }
        albums = decoded
    }

    func saveAlbums() {
        guard let data = try? JSONEncoder().encode(albums) else { return }
        try? data.write(to: albumsFileURL, options: .atomic)
    }

    func saveMetadata(_ entries: [MetadataEntry]) {
        guard let doc = collection.currentDocument else { return }
        let index = collection.currentIndex
        isSavingMetadata = true
        Log.info("Speichere Metadaten für \(doc.filename) (\(entries.count) Einträge)")
        metadataService.writePhotoMetadata(url: doc.url, entries: entries) { [weak self] error in
            guard let self = self else { return }
            self.isSavingMetadata = false
            if let error = error {
                Log.error("Metadaten speichern fehlgeschlagen: \(error.localizedDescription)")
            } else {
                Log.info("Metadaten erfolgreich gespeichert")
                let updated = self.metadataService.readPhotoMetadata(from: doc.url)
                guard index < self.collection.documents.count,
                      self.collection.documents[index].url == doc.url else { return }
                self.collection.documents[index].metadata = updated
            }
        }
    }

    // MARK: - Private

    func loadCurrentImage() {
        guard let doc = collection.currentDocument else { return }
        let index = collection.currentIndex

        if doc.cgImage != nil {
            fitToWindowRequested = true
            return
        }

        isLoading = true
        errorMessage = nil
        let url = doc.url
        let token = UUID()
        loadToken = token

        Log.info("Lade Bild: \(url.lastPathComponent)")
        DispatchQueue.global(qos: .userInitiated).async {
            let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
            defer { stopAccess() }
            do {
                let image = try RAWImageDecoder.decode(url: accessURL)
                let size = CGSize(width: image.width, height: image.height)
                let metadata = self.metadataService.readPhotoMetadata(from: accessURL)
                Log.info("Bild dekodiert: \(url.lastPathComponent) \(Int(size.width))×\(Int(size.height)), \(metadata.count) Metadaten-Einträge")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.loadToken == token else {
                        Log.debug("Bild verworfen (Token ungültig): \(url.lastPathComponent)")
                        return
                    }
                    guard index < self.collection.documents.count,
                          self.collection.documents[index].url == url else {
                        self.isLoading = false
                        return
                    }
                    var updated = self.collection.documents[index]
                    updated.cgImage = image
                    updated.imageSize = size
                    updated.metadata = metadata
                    self.collection.update(document: updated, at: index)
                    self.isLoading = false
                    self.fitToWindowRequested = true
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                }
            } catch {
                Log.error("Bild laden fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.loadToken == token else { return }
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func loadThumbnails() {
        for (index, doc) in collection.documents.enumerated() {
            guard doc.thumbnail == nil else { continue }
            let url = doc.url
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                guard let thumb = try? RAWImageDecoder.thumbnail(url: accessURL) else { return }
                let nsImage = NSImage(cgImage: thumb, size: .zero)
                DispatchQueue.main.async {
                    guard let self = self,
                          index < self.collection.documents.count,
                          self.collection.documents[index].url == url else { return }
                    self.collection.documents[index].thumbnail = thumb
                    self.collection.documents[index].thumbnailImage = nsImage
                }
            }
        }
    }

    private func prefetchAdjacent() {
        let docs = collection.documents
        let current = collection.currentIndex
        for offset in [-1, 1] {
            let i = current + offset
            guard i >= 0, i < docs.count, docs[i].cgImage == nil else { continue }
            let url = docs[i].url
            let idx = i
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                guard let image = try? RAWImageDecoder.decode(url: accessURL) else { return }
                let size = CGSize(width: image.width, height: image.height)
                DispatchQueue.main.async {
                    guard let self = self,
                          idx < self.collection.documents.count,
                          self.collection.documents[idx].url == url,
                          self.collection.documents[idx].cgImage == nil else { return }
                    self.collection.documents[idx].cgImage = image
                    self.collection.documents[idx].imageSize = size
                }
            }
        }
    }

    private func isSupportedFormat(_ url: URL) -> Bool {
        ImageDocument.supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
