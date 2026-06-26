import SwiftUI
import Combine
import AppKit
import CoreImage

class ImageViewModel: ObservableObject {
    @Published var collection = ImageCollection()
    @Published var zoomFactor: CGFloat = 1.0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var fitToWindowRequested: Bool = false
    @Published var showExportSheet: Bool = false
    @Published var pendingCrashReport: String? = nil
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
    @Published var adjTint: Double = 0.0
    @Published var adjClarity: Double = 0.0
    @Published var adjTexture: Double = 0.0
    @Published var adjDehaze: Double = 0.0
    @Published var adjCurvePoints: [CGPoint] = CurvesView.defaultPoints
    @Published var adjCurveR: [CGPoint] = CurvesView.defaultPoints
    @Published var adjCurveG: [CGPoint] = CurvesView.defaultPoints
    @Published var adjCurveB: [CGPoint] = CurvesView.defaultPoints
    @Published var adjCropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @Published var adjRotation: Double = 0.0
    @Published var adjustedImage: CGImage? = nil
    @Published var displayImageVersion: UUID = UUID()
    @Published var cropToolActive: Bool = false
    @Published var showOriginal: Bool = false

    // MARK: - Version history
    @Published var savedVersions: [ImageVersionMeta] = []
    @Published var showVersionHistory: Bool = false
    @Published var isSavingToFile: Bool = false
    @Published var undoStack: [ImageVersionMeta] = []
    @Published var redoStack: [ImageVersionMeta] = []
    @Published var pendingMetadataEntries: [MetadataEntry]? = nil

    var hasMetadataChanges: Bool { pendingMetadataEntries != nil }

    var hasActiveAdjustments: Bool {
        adjExposure != 0 || adjBrightness != 0 || adjContrast != 1 ||
        adjSaturation != 1 || adjWarmth != 0 || adjTint != 0 ||
        adjClarity != 0 || adjTexture != 0 || adjDehaze != 0 ||
        adjRotation != 0 ||
        adjCropRect != CGRect(x: 0, y: 0, width: 1, height: 1) ||
        !isDefaultCurve(adjCurvePoints) ||
        !isDefaultCurve(adjCurveR) || !isDefaultCurve(adjCurveG) || !isDefaultCurve(adjCurveB)
    }
    var currentDocIsRAW: Bool { collection.currentDocument?.isRAW ?? false }

    private(set) var lastClickModifiers: NSEvent.ModifierFlags = []
    private let metadataService = MetadataService()
    private var cancellables = Set<AnyCancellable>()
    private var loadToken: UUID = UUID()
    private var adjToken: UUID = UUID()
    private let adjCIContext = CIContext(options: [.useSoftwareRenderer: false])
    private var folderWatchers: [UUID: DispatchSourceFileSystemObject] = [:]
    private var isLoadingFullRes = false

    var currentImage: CGImage? {
        guard let doc = collection.currentDocument else { return nil }
        return doc.cgImage ?? doc.previewImage ?? doc.thumbnail
    }
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
            $adjCurvePoints.map { _ in () }.eraseToAnyPublisher(),
            $adjCropRect.map { _ in () }.eraseToAnyPublisher(),
            $adjRotation.map { _ in () }.eraseToAnyPublisher(),
            $adjTint.map { _ in () }.eraseToAnyPublisher(),
            $adjClarity.map { _ in () }.eraseToAnyPublisher(),
            $adjTexture.map { _ in () }.eraseToAnyPublisher(),
            $adjDehaze.map { _ in () }.eraseToAnyPublisher(),
            $adjCurveR.map { _ in () }.eraseToAnyPublisher(),
            $adjCurveG.map { _ in () }.eraseToAnyPublisher(),
            $adjCurveB.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(adjPublishers)
            .dropFirst(15)
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyAdjustments() }
            .store(in: &cancellables)

        $zoomFactor
            .filter { $0 > 1.0 }
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: false)
            .sink { [weak self] _ in self?.upgradeToFullResIfNeeded() }
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
            default:
                guard mods.isEmpty, !textFieldFocused else { return event }
                let char = event.characters ?? ""
                if char == "\\" {
                    DispatchQueue.main.async { self.showOriginal.toggle() }
                    return nil
                }
                switch char {
                case "p", "P":
                    DispatchQueue.main.async { self.toggleFlag(.pick) }; return nil
                case "x", "X":
                    DispatchQueue.main.async { self.toggleFlag(.reject) }; return nil
                case "0", "1", "2", "3", "4", "5":
                    if let r = Int(char) {
                        DispatchQueue.main.async { self.setRating(r) }; return nil
                    }
                case "6":
                    DispatchQueue.main.async { self.setColorLabel(.red) }; return nil
                case "7":
                    DispatchQueue.main.async { self.setColorLabel(.yellow) }; return nil
                case "8":
                    DispatchQueue.main.async { self.setColorLabel(.green) }; return nil
                case "9":
                    DispatchQueue.main.async { self.setColorLabel(.blue) }; return nil
                default: break
                }
                return event
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
        CatalogStore.shared.saveAlbum(id: album.id.uuidString, name: album.name)
        navSelection = .album(album.id) as NavSelection?
    }

    func deleteAlbum(_ album: Album) {
        albums.removeAll { $0.id == album.id }
        if navSelection == .album(album.id) { navSelection = .library as NavSelection? }
        saveAlbums()
        CatalogStore.shared.deleteAlbum(id: album.id.uuidString)
    }

    func renameAlbum(_ album: Album, to name: String) {
        guard let idx = albums.firstIndex(where: { $0.id == album.id }) else { return }
        albums[idx].name = name
        saveAlbums()
        CatalogStore.shared.saveAlbum(id: album.id.uuidString, name: name)
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
        CatalogStore.shared.addImage(path: document.url.path, toAlbum: albumID.uuidString,
                                     order: albums[idx].photoURLs.count - 1)
    }

    func addSelectedToAlbum(albumID: UUID) {
        guard let idx = albums.firstIndex(where: { $0.id == albumID }) else { return }
        for colIdx in collection.selectedIndices {
            guard colIdx < collection.documents.count else { continue }
            let url = collection.documents[colIdx].url
            guard !albums[idx].photoURLs.contains(url) else { continue }
            albums[idx].photoURLs.append(url)
            CatalogStore.shared.addImage(path: url.path, toAlbum: albumID.uuidString,
                                         order: albums[idx].photoURLs.count - 1)
        }
        saveAlbums()
    }

    func removeFromAlbum(_ document: ImageDocument, albumID: UUID) {
        guard let idx = albums.firstIndex(where: { $0.id == albumID }) else { return }
        albums[idx].photoURLs.removeAll { $0 == document.url }
        saveAlbums()
        CatalogStore.shared.removeImage(path: document.url.path, fromAlbum: albumID.uuidString)
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

    private func saveAdjustedToFile(label: String, metaEntries: [MetadataEntry]? = nil) {
        guard let doc = collection.currentDocument, !doc.isRAW else { return }
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
                let meta = try VersionStore.shared.backupFile(at: accessURL, label: label)
                try VersionStore.shared.writeImage(image, to: accessURL)
                if let entries = metaEntries {
                    try self.metadataService.writePhotoMetadataSync(url: accessURL, entries: entries)
                }
                Log.info("Bild gespeichert: \(url.lastPathComponent)")
                let updatedMeta = self.metadataService.readPhotoMetadata(from: accessURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.undoStack.append(meta)
                    self.redoStack.removeAll()
                    self.pendingMetadataEntries = nil
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].cgImage = image
                        self.collection.documents[idx].thumbnail = nil
                        self.collection.documents[idx].metadata = updatedMeta
                    }
                    self.adjustedImage = nil
                    self.displayImageVersion = UUID()
                    self.loadVersionsForCurrentImage()
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
        adjTint = 0; adjClarity = 0; adjTexture = 0; adjDehaze = 0
        adjCurvePoints = CurvesView.defaultPoints
        adjCurveR = CurvesView.defaultPoints
        adjCurveG = CurvesView.defaultPoints
        adjCurveB = CurvesView.defaultPoints
        adjCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        adjRotation = 0
        adjustedImage = nil
        pendingMetadataEntries = nil
    }

    // MARK: - Unified save

    func saveAll() {
        guard let doc = collection.currentDocument else { return }
        let hasAdj = hasActiveAdjustments && !doc.isRAW
        let hasMeta = hasMetadataChanges
        guard hasAdj || hasMeta else { return }

        var parts: [String] = []
        if hasAdj  { parts.append(adjustmentLabel()) }
        if hasMeta { parts.append("Metadaten") }
        let label = parts.joined(separator: " · ")

        if hasAdj {
            saveAdjustedToFile(label: label, metaEntries: hasMeta ? pendingMetadataEntries : nil)
        } else if let entries = pendingMetadataEntries {
            saveOnlyMeta(entries: entries, label: label)
        }
    }

    private func adjustmentLabel() -> String {
        var parts: [String] = []
        if adjExposure   != 0 { parts.append(String(format: "Belichtung %+.1f EV", adjExposure)) }
        if adjBrightness != 0 { parts.append(String(format: "Helligkeit %+.2f",    adjBrightness)) }
        if adjContrast   != 1 { parts.append(String(format: "Kontrast %.2f",       adjContrast)) }
        if adjSaturation != 1 { parts.append(String(format: "Sättigung %.2f",      adjSaturation)) }
        if adjWarmth     != 0 { parts.append(String(format: "Wärme %+.2f",         adjWarmth)) }
        if adjRotation   != 0 { parts.append(String(format: "Rotation %.1f°",      adjRotation)) }
        if adjCropRect != CGRect(x: 0, y: 0, width: 1, height: 1) { parts.append("Zugeschnitten") }
        let curveDefault = zip(adjCurvePoints, CurvesView.defaultPoints).allSatisfy {
            abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001
        }
        if !curveDefault { parts.append("Kurve") }
        return parts.isEmpty ? "Anpassungen" : parts.joined(separator: " · ")
    }

    private func saveOnlyMeta(entries: [MetadataEntry], label: String) {
        guard let doc = collection.currentDocument else { return }
        let url = doc.url
        let idx = collection.currentIndex
        isSavingToFile = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stop) = BookmarkStore.shared.access(url: url)
            defer { stop() }
            do {
                let meta = try VersionStore.shared.backupFile(at: accessURL, label: label)
                try self.metadataService.writePhotoMetadataSync(url: accessURL, entries: entries)
                let updatedMeta = self.metadataService.readPhotoMetadata(from: accessURL)
                Log.info("Metadaten gespeichert: \(url.lastPathComponent)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isSavingToFile = false
                    self.undoStack.append(meta)
                    self.redoStack.removeAll()
                    self.pendingMetadataEntries = nil
                    if idx < self.collection.documents.count {
                        self.collection.documents[idx].metadata = updatedMeta
                    }
                    self.loadVersionsForCurrentImage()
                }
            } catch {
                Log.error("Metadaten speichern fehlgeschlagen: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.isSavingToFile = false
                    self?.errorMessage = "Metadaten speichern fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Rating / Flags / Color Labels

    func setRating(_ r: Int) {
        let idx = collection.currentIndex
        guard idx < collection.documents.count else { return }
        collection.documents[idx].rating = r
        persistRating(at: idx)
    }

    func toggleFlag(_ flag: FlagStatus) {
        let idx = collection.currentIndex
        guard idx < collection.documents.count else { return }
        let cur = collection.documents[idx].flagStatus
        collection.documents[idx].flagStatus = (cur == flag) ? .none : flag
        persistRating(at: idx)
    }

    func setColorLabel(_ label: ColorLabel) {
        let idx = collection.currentIndex
        guard idx < collection.documents.count else { return }
        let cur = collection.documents[idx].colorLabel
        collection.documents[idx].colorLabel = (cur == label) ? .none : label
        persistRating(at: idx)
    }

    private func persistRating(at idx: Int) {
        guard idx < collection.documents.count else { return }
        let doc = collection.documents[idx]
        let entry = RatingEntry(rating: doc.rating, flagStatus: doc.flagStatus, colorLabel: doc.colorLabel)
        RatingStore.shared.save(entry, for: doc.url)
        CatalogStore.shared.saveRating(path: doc.url.path, rating: doc.rating,
                                       flag: doc.flagStatus.rawValue, colorLabel: doc.colorLabel.rawValue)
    }

    // MARK: - Curve helper

    private func isDefaultCurve(_ pts: [CGPoint]) -> Bool {
        zip(pts, CurvesView.defaultPoints).allSatisfy { abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001 }
    }

    func applyAdjustments() {
        let cropDefault = adjCropRect == CGRect(x: 0, y: 0, width: 1, height: 1)
        let isNeutral = !hasActiveAdjustments && cropDefault
        guard hasActiveAdjustments, let source = currentImage else {
            adjustedImage = nil
            displayImageVersion = UUID()
            return
        }

        let (exposure, brightness, contrast, saturation, warmth, tint, clarity, texture, dehaze,
             curvePoints, curveR, curveG, curveB, rotation, cropRect) = (
            adjExposure, adjBrightness, adjContrast, adjSaturation, adjWarmth, adjTint,
            adjClarity, adjTexture, adjDehaze,
            adjCurvePoints, adjCurveR, adjCurveG, adjCurveB, adjRotation, adjCropRect
        )
        let _ = isNeutral
        let token = UUID()
        adjToken = token

        let useRAWPipeline = collection.currentDocument?.isRAW ?? false
        let rawURL = collection.currentDocument?.url

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var ci: CIImage
            var exposureApplied = false
            var stopRAWAccess: (() -> Void)? = nil

            if useRAWPipeline, let url = rawURL {
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                if let rf = CIFilter(imageURL: accessURL, options: nil) {
                    rf.setValue(Float(exposure), forKey: kCIInputEVKey)
                    if let rawCI = rf.outputImage {
                        ci = rawCI
                        exposureApplied = true
                        stopRAWAccess = stopAccess
                    } else {
                        stopAccess()
                        ci = CIImage(cgImage: source)
                    }
                } else {
                    stopAccess()
                    ci = CIImage(cgImage: source)
                }
            } else {
                ci = CIImage(cgImage: source)
            }

            if !exposureApplied, exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
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

            if warmth != 0 || tint != 0, let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: CGFloat(6500 - warmth * 2500), y: CGFloat(-tint * 150)), forKey: "inputTargetNeutral")
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

            // Per-channel RGB curves via CIColorCube
            let rDef = self.isDefaultCurve(curveR)
            let gDef = self.isDefaultCurve(curveG)
            let bDef = self.isDefaultCurve(curveB)
            if !rDef || !gDef || !bDef {
                let lutR = CurvesView.evaluateSpline(curveR)
                let lutG = CurvesView.evaluateSpline(curveG)
                let lutB = CurvesView.evaluateSpline(curveB)
                let size = 32
                var cubeData = [Float]()
                cubeData.reserveCapacity(size * size * size * 4)
                for b in 0..<size {
                    for g in 0..<size {
                        for r in 0..<size {
                            let ri = Swift.min(255, r * 255 / (size - 1))
                            let gi = Swift.min(255, g * 255 / (size - 1))
                            let bi = Swift.min(255, b * 255 / (size - 1))
                            cubeData.append(Float(lutR[ri]))
                            cubeData.append(Float(lutG[gi]))
                            cubeData.append(Float(lutB[bi]))
                            cubeData.append(1.0)
                        }
                    }
                }
                if let f = CIFilter(name: "CIColorCube") {
                    f.setValue(size, forKey: "inputCubeDimension")
                    f.setValue(Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size) as NSData, forKey: "inputCubeData")
                    f.setValue(ci, forKey: kCIInputImageKey)
                    if let out = f.outputImage { ci = out }
                }
            }

            // Clarity (local contrast, large radius)
            if clarity != 0, let f = CIFilter(name: "CIUnsharpMask") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(20.0, forKey: kCIInputRadiusKey)
                f.setValue(Swift.max(0, clarity) * 2.0, forKey: kCIInputIntensityKey)
                if let out = f.outputImage { ci = out }
            }
            // Texture (fine detail)
            if texture != 0, let f = CIFilter(name: "CIUnsharpMask") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(4.0, forKey: kCIInputRadiusKey)
                f.setValue(Swift.max(0, texture) * 2.5, forKey: kCIInputIntensityKey)
                if let out = f.outputImage { ci = out }
            }
            // Dehaze (contrast/brightness manipulation)
            if dehaze != 0, let f = CIFilter(name: "CIColorControls") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(-dehaze * 0.05, forKey: kCIInputBrightnessKey)
                f.setValue(1.0 + dehaze * 0.25, forKey: kCIInputContrastKey)
                f.setValue(1.0, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { ci = out }
            }

            // Rotation (around image center)
            if rotation != 0 {
                let angle = CGFloat(rotation) * .pi / 180.0
                let cx = ci.extent.midX
                let cy = ci.extent.midY
                var t = CGAffineTransform(translationX: cx, y: cy)
                t = t.rotated(by: angle)
                t = t.translatedBy(x: -cx, y: -cy)
                let rotated = ci.transformed(by: t)
                ci = rotated.transformed(by: CGAffineTransform(
                    translationX: -rotated.extent.minX,
                    y: -rotated.extent.minY))
            }

            // Crop (normalized rect, y-axis flipped for CIImage)
            if !cropRect.equalTo(CGRect(x: 0, y: 0, width: 1, height: 1)) {
                let ext = ci.extent
                let px = CGRect(
                    x: ext.minX + cropRect.minX * ext.width,
                    y: ext.minY + (1.0 - cropRect.maxY) * ext.height,
                    width: cropRect.width  * ext.width,
                    height: cropRect.height * ext.height
                )
                let cropped = ci.cropped(to: px)
                ci = cropped.transformed(by: CGAffineTransform(
                    translationX: -cropped.extent.minX,
                    y: -cropped.extent.minY))
            }

            let result = self.adjCIContext.createCGImage(ci, from: ci.extent)
            stopRAWAccess?()
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
        isLoadingFullRes = false

        if doc.cgImage != nil {
            fitToWindowRequested = true
            displayImageVersion = UUID()
            return
        }

        errorMessage = nil
        let url = doc.url
        let token = UUID()
        loadToken = token

        // Phase 1: sofort Thumbnail/Preview anzeigen falls vorhanden
        let hasQuickPreview = doc.thumbnail != nil || doc.previewImage != nil
        if hasQuickPreview {
            displayImageVersion = UUID()
            fitToWindowRequested = true
            isLoading = false
        } else {
            isLoading = true
        }

        // Falls Preview schon geladen → direkt zu Phase 3 (Vollbild nach Dwell)
        if doc.previewImage != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self, self.loadToken == token else { return }
                self.loadFullRes(url: url, index: index, token: token)
            }
            return
        }

        Log.info("Lade Bild: \(url.lastPathComponent)")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
            defer { stopAccess() }

            // Phase 2: Preview in Bildschirmauflösung (~1500px) — sehr schnell
            if let preview = try? RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 1500) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.loadToken == token else { return }
                    guard index < self.collection.documents.count,
                          self.collection.documents[index].url == url else { return }
                    self.collection.documents[index].previewImage = preview
                    self.isLoading = false
                    self.fitToWindowRequested = true
                    self.displayImageVersion = UUID()
                    if self.hasActiveAdjustments { self.applyAdjustments() }
                }
            }

            // Phase 3: Vollbild nach Dwell-Zeit (1.5 s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self, self.loadToken == token else { return }
                self.loadFullRes(url: url, index: index, token: token)
            }
        }
    }

    private func loadFullRes(url: URL, index: Int, token: UUID) {
        guard !isLoadingFullRes,
              index < collection.documents.count,
              collection.documents[index].url == url,
              collection.documents[index].cgImage == nil else { return }
        isLoadingFullRes = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, self.loadToken == token else {
                DispatchQueue.main.async { self?.isLoadingFullRes = false }
                return
            }
            let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
            defer { stopAccess() }
            do {
                let image = try RAWImageDecoder.decode(url: accessURL)
                let size = CGSize(width: image.width, height: image.height)
                let metadata = self.metadataService.readPhotoMetadata(from: accessURL)
                Log.info("Bild dekodiert (voll): \(url.lastPathComponent) \(Int(size.width))×\(Int(size.height)), \(metadata.count) Metadaten-Einträge")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.loadToken == token else {
                        Log.debug("Vollbild verworfen (Token ungültig): \(url.lastPathComponent)")
                        self?.isLoadingFullRes = false
                        return
                    }
                    guard index < self.collection.documents.count,
                          self.collection.documents[index].url == url else {
                        self.isLoadingFullRes = false
                        return
                    }
                    var updated = self.collection.documents[index]
                    updated.cgImage = image
                    updated.imageSize = size
                    updated.metadata = metadata
                    // Load rating from Catalog first, fall back to legacy RatingStore
                    if let r = CatalogStore.shared.rating(forPath: url.path) {
                        updated.rating = r.rating
                        updated.flagStatus = FlagStatus(rawValue: r.flag) ?? .none
                        updated.colorLabel = ColorLabel(rawValue: r.colorLabel) ?? .none
                    } else if let entry = RatingStore.shared.load(for: url) {
                        updated.rating = entry.rating
                        updated.flagStatus = entry.flagStatus
                        updated.colorLabel = entry.colorLabel
                    }
                    self.collection.update(document: updated, at: index)
                    // Register image in catalog for search/browse
                    let sizeBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
                    let dateTaken = updated.metadata.first(where: { $0.key == "exif.DateTimeOriginal" })?.value
                    let camMake = updated.metadata.first(where: { $0.key == "tiff.Make" })?.value
                    let camModel = updated.metadata.first(where: { $0.key == "tiff.Model" })?.value
                    CatalogStore.shared.upsertImage(path: url.path, filename: url.lastPathComponent,
                                                    isRAW: updated.isRAW, width: Int(size.width),
                                                    height: Int(size.height), sizeBytes: sizeBytes,
                                                    dateTaken: dateTaken, cameraMake: camMake, cameraModel: camModel)
                    self.isLoadingFullRes = false
                    self.displayImageVersion = UUID()
                    if self.hasActiveAdjustments { self.applyAdjustments() }
                    self.loadVersionsForCurrentImage()
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                }
            } catch {
                Log.error("Vollbild laden fehlgeschlagen '\(url.lastPathComponent)': \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.loadToken == token else { return }
                    self.isLoadingFullRes = false
                    if self.collection.currentDocument?.url == url {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func upgradeToFullResIfNeeded() {
        guard let doc = collection.currentDocument, doc.cgImage == nil else { return }
        loadFullRes(url: doc.url, index: collection.currentIndex, token: loadToken)
    }

    func loadThumbnails() {
        // Load cheap 80px placeholders for all docs in background so cells have something to show immediately.
        for (index, doc) in collection.documents.enumerated() {
            guard doc.placeholderThumbnailImage == nil && doc.thumbnailImage == nil else { continue }
            let url = doc.url
            DispatchQueue.global(qos: .background).async { [weak self] in
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                guard let thumb = try? RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 80) else { return }
                let nsImage = NSImage(cgImage: thumb, size: .zero)
                DispatchQueue.main.async {
                    guard let self = self,
                          index < self.collection.documents.count,
                          self.collection.documents[index].url == url,
                          self.collection.documents[index].thumbnailImage == nil else { return }
                    self.collection.documents[index].placeholderThumbnailImage = nsImage
                }
            }
        }
    }

    func requestVisibleThumbnail(at index: Int) {
        guard index < collection.documents.count else { return }
        let doc = collection.documents[index]
        guard doc.thumbnailImage == nil else { return }
        let url = doc.url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
            defer { stopAccess() }
            guard let thumb = try? RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 160) else { return }
            let nsImage = NSImage(cgImage: thumb, size: .zero)
            DispatchQueue.main.async {
                guard let self = self,
                      index < self.collection.documents.count,
                      self.collection.documents[index].url == url else { return }
                self.collection.documents[index].thumbnail = thumb
                self.collection.documents[index].thumbnailImage = nsImage
                self.collection.documents[index].placeholderThumbnailImage = nil
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
