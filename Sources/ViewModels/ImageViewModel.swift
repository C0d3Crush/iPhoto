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

    private let metadataService = MetadataService()
    private var cancellables = Set<AnyCancellable>()
    private var loadToken: UUID = UUID()

    var currentImage: CGImage? { collection.currentDocument?.cgImage }
    var windowTitle: String { collection.currentDocument?.filename ?? "iPhoto" }
    var imageSize: CGSize { collection.currentDocument?.imageSize ?? .zero }

    init() {
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

    func saveMetadata(_ entries: [MetadataEntry]) {
        guard let doc = collection.currentDocument else { return }
        let index = collection.currentIndex
        isSavingMetadata = true
        metadataService.writePhotoMetadata(url: doc.url, entries: entries) { [weak self] error in
            guard let self = self else { return }
            self.isSavingMetadata = false
            if error == nil {
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

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let image = try RAWImageDecoder.decode(url: url)
                let size = CGSize(width: image.width, height: image.height)
                let metadata = self.metadataService.readPhotoMetadata(from: url)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.loadToken == token else { return }
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
                guard let thumb = try? RAWImageDecoder.thumbnail(url: url) else { return }
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
                guard let image = try? RAWImageDecoder.decode(url: url) else { return }
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
