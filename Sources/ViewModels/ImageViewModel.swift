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
    @Published var watchedFolders: [WatchedFolder] = []

    // MARK: - Adjustments
    @Published var adjExposure: Double = 0.0
    @Published var adjBrightness: Double = 0.0
    @Published var adjContrast: Double = 1.0
    @Published var adjSaturation: Double = 1.0
    @Published var adjWarmth: Double = 0.0
    @Published var adjCurvePoints: [CGPoint] = CurvesView.defaultPoints
    @Published var adjustedImage: CGImage? = nil
    @Published var displayImageVersion: UUID = UUID()

    // MARK: - Version history
    @Published var savedVersions: [ImageVersionMeta] = []
    @Published var showVersionHistory: Bool = false
    @Published var isSavingToFile: Bool = false
    @Published var undoStack: [ImageVersionMeta] = []
    @Published var redoStack: [ImageVersionMeta] = []

    var hasActiveAdjustments: Bool {
        adjExposure != 0 || adjBrightness != 0 || adjContrast != 1 ||
        adjSaturation != 1 || adjWarmth != 0 ||
        !zip(adjCurvePoints, CurvesView.defaultPoints).allSatisfy {
            abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001
        }
    }
    var currentDocIsRAW: Bool { collection.currentDocument?.isRAW ?? false }

    private(set) var lastClickModifiers: NSEvent.ModifierFlags = []
    private let metadataService = MetadataService()
    private var cancellables = Set<AnyCancellable>()
    private var loadToken: UUID = UUID()
    private var adjToken: UUID = UUID()
    private let adjCIContext = CIContext(options: [.useSoftwareRenderer: false])
    private var folderWatchers: [UUID: DispatchSourceFileSystemObject] = [:]

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
        case .folder(let id):
            guard let folder = watchedFolders.first(where: { $0.id == id }),
                  let (folderURL, stop) = folder.resolveURL() else { return [] }
            defer { stop() }
            let prefix = folderURL.standardized.path
            return collection.documents.filter { $0.url.standardized.path.hasPrefix(prefix) }
        }
    }

    func collectionIndex(for document: ImageDocument) -> Int? {
        collection.documents.firstIndex(where: { $0.id == document.id })
    }

    init() {
        loadAlbums()
        loadWatchedFolders()
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

        // Auswahl zurücksetzen wenn Navigationskontext wechselt
        $navSelection
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.collection.selectedIndices = [] }
            .store(in: &cancellables)

        let adjPublishers: [AnyPublisher<Void, Never>] = [
            $adjExposure.map { _ in () }.eraseToAnyPublisher(),
            $adjBrightness.map { _ in () }.eraseToAnyPublisher(),
            $adjContrast.map { _ in () }.eraseToAnyPublisher(),
            $adjSaturation.map { _ in () }.eraseToAnyPublisher(),
            $adjWarmth.map { _ in () }.eraseToAnyPublisher(),
            $adjCurvePoints.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(adjPublishers)
            .dropFirst(6)
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyAdjustments() }
            .store(in: &cancellables)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let onlyCmdDown  = mods == .command
            let cmdShiftDown = mods == [.command, .shift]
            let textFieldFocused = NSApp.keyWindow?.firstResponder is NSTextView
            switch event.keyCode {
            case 123: DispatchQueue.main.async { self.previous() }; return nil
            case 124: DispatchQueue.main.async { self.next()     }; return nil
            case 0 where onlyCmdDown:  DispatchQueue.main.async { self.selectAll()     }; return nil
            case 51 where onlyCmdDown: DispatchQueue.main.async { self.removeSelected() }; return nil
            case 6 where onlyCmdDown && !textFieldFocused:
                DispatchQueue.main.async { self.undoSave() }; return nil
            case 6 where cmdShiftDown && !textFieldFocused:
                DispatchQueue.main.async { self.redoSave() }; return nil
            default: return event
            }
        }

        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.lastClickModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return event
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
        collection.selectedIndices = []
        isLoading = false
        errorMessage = nil
        fitToWindowRequested = false
        resetAdjustments()
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
        Log.info("Album gewählt: '\(album.name)' (\(album.photoURLs.count) Fotos)")
        let albumID = album.id
        let photoURLs = album.photoURLs

        // navSelection sofort setzen → Sidebar zeigt Album als aktiv
        navSelection = .album(albumID)

        // Import + Selektion in nächsten Run-Loop verschieben,
        // damit nicht zu viele objectWillChange-Events in einem Zyklus feuern
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let missing = photoURLs.filter { url in
                !self.collection.documents.contains(where: { $0.url == url })
            }
            if !missing.isEmpty {
                Log.info("Importiere \(missing.count) fehlende Album-Fotos")
                let newDocs = missing
                    .filter { self.isSupportedFormat($0) }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                    .map { ImageDocument(url: $0) }
                if !newDocs.isEmpty {
                    self.collection.appendDocuments(newDocs)
                    self.loadThumbnails()
                }
            }

            if let firstURL = photoURLs.first,
               let idx = self.collection.documents.firstIndex(where: { $0.url == firstURL }) {
                Log.info("Wähle erstes Album-Foto bei Index \(idx)")
                self.collection.select(index: idx)
                self.loadCurrentImage()
            }
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

    func removeSelected() {
        guard !collection.selectedIndices.isEmpty else { return }
        switch navSelection {
        case .folder:
            confirmDeleteFromFolder()
        case .album(let id):
            for colIdx in collection.selectedIndices {
                guard colIdx < collection.documents.count else { continue }
                removeFromAlbum(collection.documents[colIdx], albumID: id)
            }
            collection.selectedIndices = []
        default:
            let sorted = collection.selectedIndices.sorted().reversed()
            for idx in sorted {
                guard idx < collection.documents.count else { continue }
                collection.documents.remove(at: idx)
            }
            collection.selectedIndices = []
            if collection.documents.isEmpty {
                collection.currentIndex = 0
            } else {
                let newIdx = min(collection.currentIndex, collection.documents.count - 1)
                collection.currentIndex = newIdx
                collection.selectedIndices = [newIdx]
                loadCurrentImage()
            }
        }
    }

    private func confirmDeleteFromFolder() {
        let count = collection.selectedIndices.count
        let alert = NSAlert()
        alert.messageText = count == 1 ? "Datei in den Papierkorb?" : "\(count) Dateien in den Papierkorb?"
        alert.informativeText = count == 1
            ? "Die Originaldatei wird vom Datenträger in den Papierkorb verschoben."
            : "Die \(count) Originaldateien werden vom Datenträger in den Papierkorb verschoben."
        alert.addButton(withTitle: "In Papierkorb")
        alert.addButton(withTitle: "Abbrechen")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let indices = collection.selectedIndices.sorted().reversed()
        for idx in indices {
            guard idx < collection.documents.count else { continue }
            let url = collection.documents[idx].url
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            try? FileManager.default.trashItem(at: accessURL, resultingItemURL: nil)
            stop()
            collection.documents.remove(at: idx)
        }
        collection.selectedIndices = []
        if !collection.documents.isEmpty {
            let newIdx = min(collection.currentIndex, collection.documents.count - 1)
            collection.currentIndex = newIdx
            collection.selectedIndices = [newIdx]
            loadCurrentImage()
        }
    }

    func toggleSelection(at index: Int) {
        if collection.selectedIndices.contains(index) {
            collection.selectedIndices.remove(index)
            if collection.currentIndex == index {
                collection.currentIndex = collection.selectedIndices.first ?? index
            }
        } else {
            collection.selectedIndices.insert(index)
            collection.currentIndex = index
            loadCurrentImage()
        }
    }

    func extendSelection(to index: Int) {
        let visibleColIndices = visibleDocuments.compactMap { collectionIndex(for: $0) }
        guard let fromPos = visibleColIndices.firstIndex(of: collection.currentIndex),
              let toPos = visibleColIndices.firstIndex(of: index) else {
            collection.selectedIndices.insert(index)
            collection.currentIndex = index
            loadCurrentImage()
            return
        }
        let lo = min(fromPos, toPos), hi = max(fromPos, toPos)
        visibleColIndices[lo...hi].forEach { collection.selectedIndices.insert($0) }
        collection.currentIndex = index
        loadCurrentImage()
    }

    func selectAll() {
        let indices = Set(visibleDocuments.compactMap { collectionIndex(for: $0) })
        collection.selectedIndices = indices
    }

    func addToAlbum(_ document: ImageDocument, albumID: UUID) {
        guard let idx = albums.firstIndex(where: { $0.id == albumID }) else { return }
        guard !albums[idx].photoURLs.contains(document.url) else { return }
        albums[idx].photoURLs.append(document.url)
        saveAlbums()
    }

    func addSelectedToAlbum(albumID: UUID) {
        guard let idx = albums.firstIndex(where: { $0.id == albumID }) else { return }
        for colIdx in collection.selectedIndices {
            guard colIdx < collection.documents.count else { continue }
            let url = collection.documents[colIdx].url
            guard !albums[idx].photoURLs.contains(url) else { continue }
            albums[idx].photoURLs.append(url)
        }
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

    // MARK: - Watched Folders

    func addFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Ordner hinzufügen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !watchedFolders.contains(where: { $0.resolveURL()?.url.standardized == url.standardized }) else { return }
        guard let folder = try? WatchedFolder(url: url) else { return }
        watchedFolders.append(folder)
        saveWatchedFolders()
        syncFolder(folder)
        startWatching(folder)
        navSelection = .folder(folder.id)
    }

    func deleteWatchedFolder(_ folder: WatchedFolder) {
        stopWatching(folder)
        watchedFolders.removeAll { $0.id == folder.id }
        if navSelection == .folder(folder.id) { navSelection = .library }
        saveWatchedFolders()
    }

    func syncFolder(_ folder: WatchedFolder) {
        guard let (folderURL, stop) = folder.resolveURL() else { return }
        DispatchQueue.global(qos: .utility).async {
            defer { stop() }
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return }
            var found: [URL] = []
            for case let fileURL as URL in enumerator {
                if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                   ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    found.append(fileURL)
                }
            }
            let folderPrefix = folderURL.standardized.path
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Remove docs from this folder that no longer exist on disk
                let toRemove = self.collection.documents.filter {
                    $0.url.standardized.path.hasPrefix(folderPrefix) && !found.map { $0.standardized }.contains($0.url.standardized)
                }
                self.collection.documents.removeAll { doc in toRemove.contains(where: { $0.id == doc.id }) }
                // Import new files
                self.importFiles(found)
            }
        }
    }

    private func startWatching(_ folder: WatchedFolder) {
        guard let (folderURL, stop) = folder.resolveURL() else { return }
        let fd = open(folderURL.path, O_EVTONLY)
        stop()
        guard fd != -1 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self = self,
                  let f = self.watchedFolders.first(where: { $0.id == folder.id }) else { return }
            self.syncFolder(f)
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        folderWatchers[folder.id] = source
    }

    private func stopWatching(_ folder: WatchedFolder) {
        folderWatchers[folder.id]?.cancel()
        folderWatchers[folder.id] = nil
    }

    private var watchedFoldersFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("watchedFolders.json")
    }

    func loadWatchedFolders() {
        guard let data = try? Data(contentsOf: watchedFoldersFileURL),
              let decoded = try? JSONDecoder().decode([WatchedFolder].self, from: data) else { return }
        watchedFolders = decoded
        for folder in watchedFolders {
            syncFolder(folder)
            startWatching(folder)
        }
    }

    func saveWatchedFolders() {
        guard let data = try? JSONEncoder().encode(watchedFolders) else { return }
        try? data.write(to: watchedFoldersFileURL, options: .atomic)
    }

    // MARK: - Version history

    func loadVersionsForCurrentImage() {
        guard let url = collection.currentDocument?.url else { savedVersions = []; return }
        let (accessURL, stop) = BookmarkStore.shared.access(url: url)
        savedVersions = VersionStore.shared.loadVersions(for: accessURL)
        stop()
    }

    func saveAdjustedToFile() {
        guard let doc = collection.currentDocument else { return }
        guard !doc.isRAW else {
            Log.info("RAW-Dateien können nicht überschrieben werden")
            return
        }
        let image = adjustedImage ?? currentImage
        guard let image = image else { return }

        isSavingToFile = true
        let url = doc.url
        let idx = collection.currentIndex

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                let meta = try VersionStore.shared.backupFile(at: accessURL)
                try VersionStore.shared.writeImage(image, to: accessURL)
                Log.info("Bild gespeichert: \(url.lastPathComponent)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.undoStack.append(meta)
                    self.redoStack.removeAll()
                    self.resetAdjustments()
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].cgImage = nil
                        self.collection.documents[idx].thumbnail = nil
                    }
                    self.loadVersionsForCurrentImage()
                    self.loadCurrentImage()
                    self.loadThumbnails()
                }
            } catch {
                Log.error("Speichern fehlgeschlagen: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.isSavingToFile = false
                    self?.errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }

    func revertToVersion(_ meta: ImageVersionMeta) {
        guard let doc = collection.currentDocument else { return }
        isSavingToFile = true
        let url = doc.url
        let idx = collection.currentIndex

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                try VersionStore.shared.backupFile(at: accessURL)
                try VersionStore.shared.restoreVersion(meta, to: accessURL)
                Log.info("Version wiederhergestellt: \(meta.date)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.resetAdjustments()
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].cgImage = nil
                        self.collection.documents[idx].thumbnail = nil
                    }
                    self.loadVersionsForCurrentImage()
                    self.loadCurrentImage()
                    self.loadThumbnails()
                }
            } catch {
                Log.error("Revert fehlgeschlagen: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in self?.isSavingToFile = false }
            }
        }
    }

    func undoSave() {
        guard !undoStack.isEmpty, let doc = collection.currentDocument else { return }
        let undoMeta = undoStack.removeLast()
        let url = doc.url
        let idx = collection.currentIndex
        isSavingToFile = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                let redoMeta = try VersionStore.shared.backupFile(at: accessURL)
                try VersionStore.shared.restoreVersion(undoMeta, to: accessURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.redoStack.append(redoMeta)
                    self.resetAdjustments()
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].cgImage = nil
                        self.collection.documents[idx].thumbnail = nil
                    }
                    self.loadVersionsForCurrentImage()
                    self.loadCurrentImage()
                    self.loadThumbnails()
                }
            } catch {
                Log.error("Undo fehlgeschlagen: \(error)")
                DispatchQueue.main.async { [weak self] in self?.isSavingToFile = false }
            }
        }
    }

    func redoSave() {
        guard !redoStack.isEmpty, let doc = collection.currentDocument else { return }
        let redoMeta = redoStack.removeLast()
        let url = doc.url
        let idx = collection.currentIndex
        isSavingToFile = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                let undoMeta = try VersionStore.shared.backupFile(at: accessURL)
                try VersionStore.shared.restoreVersion(redoMeta, to: accessURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.undoStack.append(undoMeta)
                    self.resetAdjustments()
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].cgImage = nil
                        self.collection.documents[idx].thumbnail = nil
                    }
                    self.loadVersionsForCurrentImage()
                    self.loadCurrentImage()
                    self.loadThumbnails()
                }
            } catch {
                Log.error("Redo fehlgeschlagen: \(error)")
                DispatchQueue.main.async { [weak self] in self?.isSavingToFile = false }
            }
        }
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

    // MARK: - Adjustments

    func resetAdjustments() {
        adjExposure = 0; adjBrightness = 0; adjContrast = 1; adjSaturation = 1; adjWarmth = 0
        adjCurvePoints = CurvesView.defaultPoints
        adjustedImage = nil
    }

    private func applyAdjustments() {
        let curveDefault = zip(adjCurvePoints, CurvesView.defaultPoints).allSatisfy {
            abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001
        }
        let isNeutral = adjExposure == 0 && adjBrightness == 0 && adjContrast == 1
            && adjSaturation == 1 && adjWarmth == 0 && curveDefault
        guard !isNeutral, let source = currentImage else {
            adjustedImage = nil
            displayImageVersion = UUID()
            return
        }

        let (exposure, brightness, contrast, saturation, warmth, curvePoints) =
            (adjExposure, adjBrightness, adjContrast, adjSaturation, adjWarmth, adjCurvePoints)
        let token = UUID()
        adjToken = token

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var ci = CIImage(cgImage: source)

            if exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(exposure, forKey: kCIInputEVKey)
                if let out = f.outputImage { ci = out }
            }

            if brightness != 0 || contrast != 1 || saturation != 1,
               let f = CIFilter(name: "CIColorControls") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(brightness, forKey: kCIInputBrightnessKey)
                f.setValue(contrast, forKey: kCIInputContrastKey)
                f.setValue(saturation, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { ci = out }
            }

            if warmth != 0, let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: CGFloat(6500 - warmth * 2500), y: 0), forKey: "inputTargetNeutral")
                if let out = f.outputImage { ci = out }
            }

            let curveDef = zip(curvePoints, CurvesView.defaultPoints).allSatisfy {
                abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001
            }
            if !curveDef, let f = CIFilter(name: "CIToneCurve") {
                f.setValue(ci, forKey: kCIInputImageKey)
                for (i, pt) in curvePoints.enumerated() {
                    f.setValue(CIVector(x: pt.x, y: pt.y), forKey: "inputPoint\(i)")
                }
                if let out = f.outputImage { ci = out }
            }

            let result = self.adjCIContext.createCGImage(ci, from: ci.extent)
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.adjToken == token else { return }
                self.adjustedImage = result
                self.displayImageVersion = UUID()
            }
        }
    }

    // MARK: - Private

    func loadCurrentImage() {
        guard let doc = collection.currentDocument else { return }
        let index = collection.currentIndex
        resetAdjustments()

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
                    self.displayImageVersion = UUID()
                    self.loadVersionsForCurrentImage()
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
