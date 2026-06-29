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
    @Published var tetherMode: Bool = false
    @Published var hotPixelPhase: HotPixelPhase = .idle
    @Published var inspectorVisible: Bool = false
    @Published var isSavingMetadata: Bool = false
    @Published var navSidebarVisible: Bool = true
    @Published var navSelection: NavSelection? = .library
    @Published var showingLibraryDetail: Bool = false
    @Published var albums: [Album] = []
    @Published var watchedFolders: [WatchedFolder] = []
    @Published var smartFolders: [SmartFolder] = []

    struct ImportProgress {
        var folderName: String
        var completed: Int
        var total: Int
    }
    @Published var importProgress: [UUID: ImportProgress] = [:]

    // MARK: - Adjustments
    @Published var adjustments: AdjustmentState = AdjustmentState()
    @Published var adjustedImage: CGImage? = nil
    @Published var displayImageVersion: UUID = UUID()
    @Published var cropToolActive: Bool = false
    @Published var showOriginal: Bool = false
    @Published var thumbnailLoadProgress: Double? = nil
    @Published var thumbnailLoadDone: Int = 0
    @Published var thumbnailLoadTotal: Int = 0
    @Published var copiedAdjustments: AdjustmentState? = nil
    @Published var userPresets: [Preset] = []

    // MARK: - Version history
    @Published var savedVersions: [ImageVersionMeta] = []
    @Published var showVersionHistory: Bool = false
    @Published var isSavingToFile: Bool = false
    @Published var undoStack: [ImageVersionMeta] = []
    @Published var redoStack: [ImageVersionMeta] = []
    @Published var pendingMetadataEntries: [MetadataEntry]? = nil

    var hasMetadataChanges: Bool { pendingMetadataEntries != nil }

    var hasActiveAdjustments: Bool { adjustments != AdjustmentState() }
    var currentDocIsRAW: Bool { collection.currentDocument?.isRAW ?? false }

    @Published var adjUndoStack: [AdjustmentState] = []
    @Published var adjRedoStack: [AdjustmentState] = []
    private var isUndoRedoing = false
    private var lastCommittedAdjustments = AdjustmentState()

    private(set) var lastClickModifiers: NSEvent.ModifierFlags = []
    private let metadataService = MetadataService()
    private var cancellables = Set<AnyCancellable>()
    private var loadToken: UUID = UUID()
    private var adjToken: UUID = UUID()
    private let adjCIContext: CIContext = {
        var opts: [CIContextOption: Any] = [.useSoftwareRenderer: false]
        if let linearSRGB = CGColorSpace(name: CGColorSpace.linearSRGB) {
            opts[.workingColorSpace] = linearSRGB
        }
        opts[.workingFormat] = CIFormat.RGBAh
        return CIContext(options: opts)
    }()
    private var folderWatchers: [UUID: DispatchSourceFileSystemObject] = [:]
    private var isLoadingFullRes = false
    // Shared accumulator for all concurrent loadThumbnails() calls.
    // Written only on the main thread, so no lock needed.
    private var thumbQueued: Int = 0
    private var thumbDone: Int = 0
    private var thumbHideTask: DispatchWorkItem? = nil
    private var thumbInFlight: Set<URL> = []

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
        case .smartFolder(let id):
            guard let sf = smartFolders.first(where: { $0.id == id }) else { return [] }
            return collection.documents.filter { smartFolderMatches($0, sf: sf) }
        }
    }

    private func smartFolderMatches(_ doc: ImageDocument, sf: SmartFolder) -> Bool {
        guard !sf.criteria.isEmpty else { return true }
        let results = sf.criteria.map { c -> Bool in
            switch c.attribute {
            case .flag:
                return applyEnumOp(c.op, lhs: doc.flagStatus, rhs: c.flagValue)
            case .colorLabel:
                return applyEnumOp(c.op, lhs: doc.colorLabel, rhs: c.colorValue)
            case .isRAW:
                return applyEnumOp(c.op, lhs: doc.isRAW, rhs: c.boolValue)
            case .rating:
                return applyNumericOp(c.op, value: Double(doc.rating), lo: Double(c.ratingValue), hi: Double(c.ratingValue2))
            case .iso:
                guard let v = metadataDouble(doc, key: "exif.ISO", prefix: "ISO ") else { return false }
                return applyNumericOp(c.op, value: v, lo: c.numericValue, hi: c.numericValue2)
            case .focalLength:
                guard let v = metadataDouble(doc, key: "exif.FocalLength", suffix: " mm") else { return false }
                return applyNumericOp(c.op, value: v, lo: c.numericValue, hi: c.numericValue2)
            case .aperture:
                guard let v = metadataDouble(doc, key: "exif.FNumber", prefix: "f/") else { return false }
                return applyNumericOp(c.op, value: v, lo: c.numericValue, hi: c.numericValue2)
            case .cameraMake:
                return applyTextOp(c.op, haystack: metadataString(doc, key: "tiff.Make"), needle: c.textValue)
            case .cameraModel:
                return applyTextOp(c.op, haystack: metadataString(doc, key: "tiff.Model"), needle: c.textValue)
            case .lens:
                return applyTextOp(c.op, haystack: metadataString(doc, key: "exif.LensModel"), needle: c.textValue)
            case .filename:
                return applyTextOp(c.op, haystack: doc.filename, needle: c.textValue)
            }
        }
        return sf.matchAll ? results.allSatisfy { $0 } : results.contains { $0 }
    }

    private func applyEnumOp<T: Equatable>(_ op: SmartFolderOperator, lhs: T, rhs: T) -> Bool {
        switch op {
        case .isExact: return lhs == rhs
        case .isNot:   return lhs != rhs
        default:       return false
        }
    }

    private func applyNumericOp(_ op: SmartFolderOperator, value: Double, lo: Double, hi: Double) -> Bool {
        switch op {
        case .isExact:     return value == lo
        case .isNot:       return value != lo
        case .greaterThan: return value > lo
        case .lessThan:    return value < lo
        case .inRange:     return value >= lo && value <= hi
        default:           return false
        }
    }

    private func applyTextOp(_ op: SmartFolderOperator, haystack: String, needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        switch op {
        case .contains:    return haystack.localizedCaseInsensitiveContains(needle)
        case .notContains: return !haystack.localizedCaseInsensitiveContains(needle)
        case .isExact:     return haystack.localizedCaseInsensitiveCompare(needle) == .orderedSame
        case .isNot:       return haystack.localizedCaseInsensitiveCompare(needle) != .orderedSame
        case .beginsWith:  return haystack.lowercased().hasPrefix(needle.lowercased())
        case .endsWith:    return haystack.lowercased().hasSuffix(needle.lowercased())
        default:           return false
        }
    }

    private func metadataString(_ doc: ImageDocument, key: String) -> String {
        doc.metadata.first(where: { $0.key == key })?.value ?? ""
    }

    private func metadataDouble(_ doc: ImageDocument, key: String, prefix: String = "", suffix: String = "") -> Double? {
        guard let raw = doc.metadata.first(where: { $0.key == key })?.value else { return nil }
        var s = raw
        if !prefix.isEmpty, s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)) }
        if !suffix.isEmpty, s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)) }
        return Double(s.trimmingCharacters(in: .whitespaces))
    }

    func collectionIndex(for document: ImageDocument) -> Int? {
        collection.documents.firstIndex(where: { $0.id == document.id })
    }

    init() {
        loadAlbums()
        loadWatchedFolders()
        loadSmartFolders()
        userPresets = CatalogStore.shared.allUserPresets()
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
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.collection.selectedIndices = []
                let visible = self.visibleDocuments
                let curInVisible = self.collection.currentDocument.map { doc in
                    visible.contains(where: { $0.id == doc.id })
                } ?? false
                if !curInVisible, let first = visible.first, let idx = self.collectionIndex(for: first) {
                    self.collection.select(index: idx)
                    self.loadCurrentImage()
                }
                self.evictDistantImages()
            }
            .store(in: &cancellables)

        // Wechselmedien: auto-sync wenn Datenträger eingeführt wird
        NSWorkspace.shared.notificationCenter
            .publisher(for: Notification.Name("NSWorkspaceDidMountNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let volumeURL = notification.userInfo?["NSWorkspaceVolumeURLKey"] as? URL
                else { return }
                let volumePath = volumeURL.standardized.path
                for folder in self.watchedFolders where folder.autoSync {
                    guard let bookmarkPath = folder.bookmarkPath,
                          bookmarkPath.hasPrefix(volumePath) else { continue }
                    self.syncFolder(folder)
                    self.navSelection = .folder(folder.id)
                    if folder.importDestinationPath != nil {
                        self.importImages(from: folder)
                    }
                }
            }
            .store(in: &cancellables)

        $adjustments
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyAdjustments() }
            .store(in: &cancellables)

        $adjustments
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self = self, !self.isUndoRedoing,
                      newState != self.lastCommittedAdjustments else { return }
                self.adjUndoStack.append(self.lastCommittedAdjustments)
                self.adjRedoStack.removeAll()
                self.lastCommittedAdjustments = newState
                if self.adjUndoStack.count > 50 { self.adjUndoStack.removeFirst() }
            }
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
                DispatchQueue.main.async {
                    if !self.adjUndoStack.isEmpty { self.undoAdjustments() }
                    else { self.undoSave() }
                }; return nil
            case 6 where cmdShiftDown && !textFieldFocused:
                DispatchQueue.main.async {
                    if !self.adjRedoStack.isEmpty { self.redoAdjustments() }
                    else { self.redoSave() }
                }; return nil
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

        // Release large cgImage objects under memory pressure (macOS 11 compatible).
        let memSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        memSource.setEventHandler { [weak self] in self?.evictDistantImages(keepRadius: 0) }
        memSource.resume()
        // Retain the source for the lifetime of the view model.
        cancellables.insert(AnyCancellable { memSource.cancel() })
    }

    private func evictDistantImages(keepRadius: Int = 2) {
        let current = collection.currentIndex
        let visibleIDs: Set<UUID>?
        switch navSelection {
        case .library, nil: visibleIDs = nil
        default: visibleIDs = Set(visibleDocuments.map { $0.id })
        }
        for i in 0..<collection.documents.count {
            let dist = abs(i - current)
            let outsideContext = visibleIDs.map { !$0.contains(collection.documents[i].id) } ?? false
            if dist > keepRadius || outsideContext {
                collection.documents[i].cgImage = nil
            }
            if dist > max(keepRadius * 3, 5) || outsideContext {
                collection.documents[i].previewImage = nil
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
    func importFiles(_ urls: [URL], selectFirst: Bool = true) {
        let supported = urls.filter { isSupportedFormat($0) }
        guard !supported.isEmpty else { return }

        let existingURLs = Set(collection.documents.map { $0.url })
        let newURLs = supported.filter { !existingURLs.contains($0) }
        guard !newURLs.isEmpty else { return }

        newURLs.forEach { BookmarkStore.shared.save(url: $0) }
        let newDocs = newURLs
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url -> ImageDocument in
                var doc = ImageDocument(url: url)
                if let r = CatalogStore.shared.rating(forPath: url.path) {
                    doc.rating = r.rating
                    doc.flagStatus = FlagStatus(rawValue: r.flag) ?? .none
                    doc.colorLabel = ColorLabel(rawValue: r.colorLabel) ?? .none
                } else if let entry = RatingStore.shared.load(for: url) {
                    doc.rating = entry.rating
                    doc.flagStatus = entry.flagStatus
                    doc.colorLabel = entry.colorLabel
                }
                return doc
            }

        let firstNewIndex = collection.documents.count
        collection.appendDocuments(newDocs)
        if selectFirst || collection.documents.count == newDocs.count {
            collection.select(index: firstNewIndex)
            loadCurrentImage()
        }
        loadThumbnails()
        loadMetadataInBackground()
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
        persistAdjustmentsForCurrent()
        collection.select(index: index)
        loadCurrentImage()
    }

    func next() {
        persistAdjustmentsForCurrent()
        let visible = visibleDocuments
        guard let cur = collection.currentDocument,
              let visPos = visible.firstIndex(where: { $0.id == cur.id }),
              visPos + 1 < visible.count,
              let nextIdx = collectionIndex(for: visible[visPos + 1]) else { return }
        collection.select(index: nextIdx)
        evictDistantImages()
        loadCurrentImage()
        prefetchAdjacent()
    }

    func previous() {
        persistAdjustmentsForCurrent()
        let visible = visibleDocuments
        guard let cur = collection.currentDocument,
              let visPos = visible.firstIndex(where: { $0.id == cur.id }),
              visPos > 0,
              let prevIdx = collectionIndex(for: visible[visPos - 1]) else { return }
        collection.select(index: prevIdx)
        evictDistantImages()
        loadCurrentImage()
        prefetchAdjacent()
    }

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
        case .album(let id):
            // Remove from album only — don't touch the file
            for colIdx in collection.selectedIndices {
                guard colIdx < collection.documents.count else { continue }
                removeFromAlbum(collection.documents[colIdx], albumID: id)
            }
            collection.selectedIndices = []
        default:
            // Folder, Library, or any other context: move files to trash
            confirmTrashFiles()
        }
    }

    private func confirmTrashFiles() {
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

    // MARK: - Smart Folders

    func createSmartFolder(_ sf: SmartFolder) {
        smartFolders.append(sf)
        saveSmartFolders()
        navSelection = .smartFolder(sf.id)
    }

    func deleteSmartFolder(_ sf: SmartFolder) {
        smartFolders.removeAll { $0.id == sf.id }
        if navSelection == .smartFolder(sf.id) { navSelection = .library }
        saveSmartFolders()
    }

    func updateSmartFolder(_ sf: SmartFolder) {
        guard let idx = smartFolders.firstIndex(where: { $0.id == sf.id }) else { return }
        smartFolders[idx] = sf
        saveSmartFolders()
    }

    private var smartFoldersFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPhoto")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("smartFolders.json")
    }

    func loadSmartFolders() {
        guard let data = try? Data(contentsOf: smartFoldersFileURL),
              let decoded = try? JSONDecoder().decode([SmartFolder].self, from: data) else { return }
        smartFolders = decoded
    }

    func saveSmartFolders() {
        guard let data = try? JSONEncoder().encode(smartFolders) else { return }
        try? data.write(to: smartFoldersFileURL, options: .atomic)
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

    func toggleAutoSync(for folder: WatchedFolder) {
        guard let idx = watchedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        watchedFolders[idx].autoSync.toggle()
        saveWatchedFolders()
    }

    func setImportDestination(for folder: WatchedFolder, path: String?) {
        guard let idx = watchedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        watchedFolders[idx].importDestinationPath = path
        saveWatchedFolders()

        // Auto-add destination as watched folder so imports stay in Library after drive removal
        guard let path = path else { return }
        let destURL = URL(fileURLWithPath: path)
        let alreadyWatched = watchedFolders.contains {
            $0.bookmarkPath.map { URL(fileURLWithPath: $0).standardized } == destURL.standardized
        }
        guard !alreadyWatched, let destFolder = try? WatchedFolder(url: destURL) else { return }
        watchedFolders.append(destFolder)
        saveWatchedFolders()
        syncFolder(destFolder)
        startWatching(destFolder)
    }

    func importImages(from folder: WatchedFolder) {
        guard let (sourceURL, stop) = folder.resolveURL(),
              let destURL = folder.importDestinationURL
        else { return }

        let folderID = folder.id
        let folderName = folder.name
        importProgress[folderID] = ImportProgress(folderName: folderName, completed: 0, total: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            defer { stop() }

            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: sourceURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                DispatchQueue.main.async { self.importProgress.removeValue(forKey: folderID) }
                return
            }

            var sourceFiles: [URL] = []
            for case let fileURL as URL in enumerator {
                if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                   ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    sourceFiles.append(fileURL)
                }
            }

            try? fm.createDirectory(at: destURL, withIntermediateDirectories: true)
            let existingNames = Set((try? fm.contentsOfDirectory(atPath: destURL.path).map { $0.lowercased() }) ?? [])
            let newFiles = sourceFiles.filter { !existingNames.contains($0.lastPathComponent.lowercased()) }

            DispatchQueue.main.async {
                self.importProgress[folderID] = ImportProgress(folderName: folderName, completed: 0, total: newFiles.count)
            }

            var completed = 0
            var newURLs: [URL] = []
            for file in newFiles {
                let dest = destURL.appendingPathComponent(file.lastPathComponent)
                if (try? fm.copyItem(at: file, to: dest)) != nil {
                    newURLs.append(dest)
                }
                completed += 1
                let c = completed
                DispatchQueue.main.async {
                    self.importProgress[folderID] = ImportProgress(folderName: folderName, completed: c, total: newFiles.count)
                }
            }

            DispatchQueue.main.async {
                self.importProgress.removeValue(forKey: folderID)
                if !newURLs.isEmpty { self.importFiles(newURLs, selectFirst: false) }
            }
        }
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
                self.importFiles(found, selectFirst: false)
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
        adjustments = AdjustmentState()
        adjustedImage = nil
        pendingMetadataEntries = nil
    }

    func undoAdjustments() {
        guard !adjUndoStack.isEmpty else { return }
        isUndoRedoing = true
        adjRedoStack.append(lastCommittedAdjustments)
        let prev = adjUndoStack.removeLast()
        adjustments = prev
        lastCommittedAdjustments = prev
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.isUndoRedoing = false
        }
    }

    func redoAdjustments() {
        guard !adjRedoStack.isEmpty else { return }
        isUndoRedoing = true
        adjUndoStack.append(lastCommittedAdjustments)
        let next = adjRedoStack.removeLast()
        adjustments = next
        lastCommittedAdjustments = next
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.isUndoRedoing = false
        }
    }

    // MARK: - Presets / Rezepte

    func applyPreset(_ preset: Preset) {
        adjustments = preset.adjustments
    }

    func saveCurrentAsPreset(name: String, author: String? = nil) {
        var p = Preset(name: name, author: author, adjustments: adjustments)
        CatalogStore.shared.savePreset(p)
        userPresets = CatalogStore.shared.allUserPresets()
    }

    func deletePreset(_ preset: Preset) {
        CatalogStore.shared.deletePreset(id: preset.id)
        userPresets = CatalogStore.shared.allUserPresets()
    }

    func exportRecipe(_ preset: Preset) {
        guard let data = try? JSONEncoder().encode(preset) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(preset.name).iphotorecipe"
        panel.allowedFileTypes = ["iphotorecipe"]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    func importRecipe() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["iphotorecipe"]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url,
                  let data = try? Data(contentsOf: url),
                  var preset = try? JSONDecoder().decode(Preset.self, from: data) else { return }
            preset.id = UUID()
            CatalogStore.shared.savePreset(preset)
            DispatchQueue.main.async { self?.userPresets = CatalogStore.shared.allUserPresets() }
        }
    }

    private func persistAdjustmentsForCurrent() {
        guard let doc = collection.currentDocument else { return }
        if adjustments != AdjustmentState() {
            CatalogStore.shared.saveAdjustments(path: doc.url.path, adjustments: adjustments)
        } else {
            CatalogStore.shared.deleteAdjustments(path: doc.url.path)
        }
    }

    // MARK: - Save / Export

    func saveMetadata() {
        guard hasMetadataChanges, let entries = pendingMetadataEntries else { return }
        saveOnlyMeta(entries: entries, label: "Metadaten")
    }

    // MARK: - Copy / Paste Adjustments

    func copyAdjustments() {
        copiedAdjustments = adjustments
    }

    func pasteAdjustments() {
        guard let src = copiedAdjustments else { return }
        let targets: [Int] = collection.selectedIndices.isEmpty
            ? [collection.currentIndex]
            : Array(collection.selectedIndices)
        for idx in targets where idx < collection.documents.count {
            if idx == collection.currentIndex {
                adjustments = src
            } else {
                CatalogStore.shared.saveAdjustments(
                    path: collection.documents[idx].url.path,
                    adjustments: src
                )
            }
        }
    }

    private func adjustmentLabel() -> String {
        var parts: [String] = []
        if adjustments.exposure   != 0 { parts.append(String(format: "Belichtung %+.1f EV", adjustments.exposure)) }
        if adjustments.brightness != 0 { parts.append(String(format: "Helligkeit %+.2f",    adjustments.brightness)) }
        if adjustments.contrast   != 1 { parts.append(String(format: "Kontrast %.2f",       adjustments.contrast)) }
        if adjustments.saturation != 1 { parts.append(String(format: "Sättigung %.2f",      adjustments.saturation)) }
        if adjustments.warmth     != 0 { parts.append(String(format: "Wärme %+.2f",         adjustments.warmth)) }
        if adjustments.rotation   != 0 { parts.append(String(format: "Rotation %.1f°",      adjustments.rotation)) }
        if adjustments.cropRect != CGRect(x: 0, y: 0, width: 1, height: 1) { parts.append("Zugeschnitten") }
        let curveDefault = zip(adjustments.curvePoints, CurvesView.defaultPoints).allSatisfy {
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
        let indices = collection.selectedIndices.isEmpty
            ? (collection.currentIndex < collection.documents.count ? [collection.currentIndex] : [])
            : Array(collection.selectedIndices)
        guard !indices.isEmpty else { return }
        let allSet = indices.allSatisfy { collection.documents[$0].flagStatus == flag }
        let newStatus: FlagStatus = allSet ? .none : flag
        for idx in indices {
            collection.documents[idx].flagStatus = newStatus
            persistRating(at: idx)
        }
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

    // MARK: - Local Adjustments

    private func applyLocalAdjustments(_ locals: [LocalAdjustment], to ci: CIImage) -> CIImage {
        var result = ci
        let ext = ci.extent

        for adj in locals {
            guard !adj.delta.isNeutral else { continue }
            guard var mask = buildMask(adj.mask, extent: ext) else { continue }

            // Scale mask by intensity
            if adj.intensity < 1.0, let f = CIFilter(name: "CIColorMatrix") {
                let v = CGFloat(adj.intensity)
                f.setValue(mask, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: v, y: 0, z: 0, w: 0), forKey: "inputRVector")
                f.setValue(CIVector(x: 0, y: v, z: 0, w: 0), forKey: "inputGVector")
                f.setValue(CIVector(x: 0, y: 0, z: v, w: 0), forKey: "inputBVector")
                f.setValue(CIVector(x: 0, y: 0, z: 0, w: v), forKey: "inputAVector")
                if let out = f.outputImage { mask = out }
            }

            if adj.inverted, let f = CIFilter(name: "CIColorInvert") {
                f.setValue(mask, forKey: kCIInputImageKey)
                if let out = f.outputImage { mask = out }
            }

            mask = mask.cropped(to: ext)

            // Apply delta to the current image
            var deltaCI = result
            let d = adj.delta
            if d.exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
                f.setValue(deltaCI, forKey: kCIInputImageKey)
                f.setValue(d.exposure, forKey: kCIInputEVKey)
                if let out = f.outputImage { deltaCI = out }
            }
            if d.brightness != 0 || d.contrast != 1.0 || d.saturation != 1.0,
               let f = CIFilter(name: "CIColorControls") {
                f.setValue(deltaCI, forKey: kCIInputImageKey)
                f.setValue(d.brightness, forKey: kCIInputBrightnessKey)
                f.setValue(d.contrast, forKey: kCIInputContrastKey)
                f.setValue(d.saturation, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { deltaCI = out }
            }
            if (d.warmth != 0 || d.tint != 0), let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(deltaCI, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: CGFloat(6500 - d.warmth * 2500), y: CGFloat(-d.tint * 150)),
                           forKey: "inputTargetNeutral")
                if let out = f.outputImage { deltaCI = out }
            }

            if let blend = CIFilter(name: "CIBlendWithMask") {
                blend.setValue(result,   forKey: kCIInputBackgroundImageKey)
                blend.setValue(deltaCI,  forKey: kCIInputImageKey)
                blend.setValue(mask,     forKey: kCIInputMaskImageKey)
                if let out = blend.outputImage { result = out }
            }
        }
        return result
    }

    private func buildMask(_ shape: MaskShape, extent: CGRect) -> CIImage? {
        let w = extent.width, h = extent.height
        switch shape {
        case .linearGradient(let sx, let sy, let ex, let ey):
            // Flip Y: normalized top-left → CIImage bottom-left
            let p0 = CIVector(x: extent.minX + CGFloat(sx) * w,
                              y: extent.minY + (1 - CGFloat(sy)) * h)
            let p1 = CIVector(x: extent.minX + CGFloat(ex) * w,
                              y: extent.minY + (1 - CGFloat(ey)) * h)
            guard let f = CIFilter(name: "CILinearGradient") else { return nil }
            f.setValue(p0, forKey: "inputPoint0")
            f.setValue(p1, forKey: "inputPoint1")
            f.setValue(CIColor.white, forKey: "inputColor0")
            f.setValue(CIColor.black, forKey: "inputColor1")
            return f.outputImage

        case .radialGradient(let cx, let cy, let r, let feather):
            let center = CIVector(x: extent.minX + CGFloat(cx) * w,
                                  y: extent.minY + (1 - CGFloat(cy)) * h)
            let innerR = CGFloat(r) * min(w, h)
            let outerR = innerR * CGFloat(1 + max(0.01, feather))
            guard let f = CIFilter(name: "CIRadialGradient") else { return nil }
            f.setValue(center,    forKey: "inputCenter")
            f.setValue(innerR,    forKey: "inputRadius0")
            f.setValue(outerR,    forKey: "inputRadius1")
            f.setValue(CIColor.white, forKey: "inputColor0")
            f.setValue(CIColor.black, forKey: "inputColor1")
            return f.outputImage
        }
    }

    func applyAdjustments() {
        guard hasActiveAdjustments, let source = currentImage else {
            adjustedImage = nil
            displayImageVersion = UUID()
            return
        }

        let snap = adjustments
        let token = UUID()
        adjToken = token

        let useRAWPipeline = collection.currentDocument?.isRAW ?? false
        let rawURL = collection.currentDocument?.url
        let nativeSize = imageSize

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var ci: CIImage
            var exposureApplied = false
            var wbApplied = false
            var stopRAWAccess: (() -> Void)? = nil

            if useRAWPipeline, let url = rawURL {
                let longestEdge = max(nativeSize.width, nativeSize.height)
                let previewScale = longestEdge > 0
                    ? min(1.0, 1500.0 / Double(longestEdge))
                    : 1.0
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                if let rf = CIFilter(imageURL: accessURL, options: nil) {
                    let keys = rf.inputKeys
                    if keys.contains(kCIInputEVKey as String) {
                        rf.setValue(Float(snap.exposure), forKey: kCIInputEVKey)
                    }
                    if keys.contains("inputAllowDraftMode") {
                        rf.setValue(true, forKey: "inputAllowDraftMode")
                    }
                    if keys.contains("inputScaleFactor") {
                        rf.setValue(Float(previewScale), forKey: "inputScaleFactor")
                    }
                    if snap.warmth != 0 || snap.tint != 0 {
                        let kelvin = Float(6500.0 - snap.warmth * 2500.0)
                        let tintVal = Float(-snap.tint * 150.0)
                        if keys.contains("inputNeutralTemperature") {
                            rf.setValue(kelvin,  forKey: "inputNeutralTemperature")
                        }
                        if keys.contains("inputNeutralTint") {
                            rf.setValue(tintVal, forKey: "inputNeutralTint")
                        }
                        wbApplied = true
                    }
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

            // Chromatic Aberration correction (R out, B in from center)
            if snap.caAmount > 0, let k = LensFilters.caKernel {
                if let out = k.apply(extent: ci.extent,
                                     roiCallback: { _, r in r },
                                     arguments: [ci, Float(snap.caAmount)]) { ci = out }
            }

            // Lens Distortion correction (barrel/pincushion radial polynomial)
            if snap.distortion != 0, let k = LensFilters.distortKernel {
                let k1  = Float(-snap.distortion * 0.003)   // neg slider = barrel = pos k1
                let ext = CIVector(cgRect: ci.extent)
                if let out = k.apply(extent: ci.extent,
                                     roiCallback: { _, r in r.insetBy(dx: -4, dy: -4) },
                                     image: ci,
                                     arguments: [ext, k1]) {
                    ci = out.cropped(to: ci.extent)
                }
            }

            if !exposureApplied, snap.exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(snap.exposure, forKey: kCIInputEVKey)
                if let out = f.outputImage { ci = out }
            }

            if snap.brightness != 0 || snap.contrast != 1 || snap.saturation != 1,
               let f = CIFilter(name: "CIColorControls") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(snap.brightness, forKey: kCIInputBrightnessKey)
                f.setValue(snap.contrast, forKey: kCIInputContrastKey)
                f.setValue(snap.saturation, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { ci = out }
            }

            if !wbApplied, snap.warmth != 0 || snap.tint != 0,
               let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: CGFloat(6500 - snap.warmth * 2500), y: CGFloat(-snap.tint * 150)), forKey: "inputTargetNeutral")
                if let out = f.outputImage { ci = out }
            }

            // Luminance Noise Reduction
            if snap.lumaNoise > 0, let f = CIFilter(name: "CINoiseReduction") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(snap.lumaNoise * 0.001, forKey: "inputNoiseLevel")  // 0.001–0.1
                f.setValue(0.4, forKey: kCIInputSharpnessKey)
                if let out = f.outputImage { ci = out }
            }

            // Color Noise Reduction via CILuminosityBlendMode:
            // luma from original (foreground), chroma from blurred (background)
            if snap.colorNoise > 0, let blurF = CIFilter(name: "CIGaussianBlur") {
                blurF.setValue(ci, forKey: kCIInputImageKey)
                blurF.setValue(snap.colorNoise * 0.25, forKey: kCIInputRadiusKey)
                if let blurred = blurF.outputImage?.cropped(to: ci.extent),
                   let blendF  = CIFilter(name: "CILuminosityBlendMode") {
                    blendF.setValue(ci,      forKey: kCIInputImageKey)
                    blendF.setValue(blurred, forKey: kCIInputBackgroundImageKey)
                    if let out = blendF.outputImage { ci = out }
                }
            }

            // Capture Sharpening (fine-radius USM, applied before tone)
            if snap.sharpenAmount > 0, let f = CIFilter(name: "CIUnsharpMask") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(snap.sharpenRadius,         forKey: kCIInputRadiusKey)
                f.setValue(snap.sharpenAmount / 100.0, forKey: kCIInputIntensityKey)
                if let out = f.outputImage { ci = out }
            }

            let curveDef = zip(snap.curvePoints, CurvesView.defaultPoints).allSatisfy {
                abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001
            }
            if !curveDef, let f = CIFilter(name: "CIToneCurve") {
                f.setValue(ci, forKey: kCIInputImageKey)
                for (i, pt) in snap.curvePoints.enumerated() {
                    f.setValue(CIVector(x: pt.x, y: pt.y), forKey: "inputPoint\(i)")
                }
                if let out = f.outputImage { ci = out }
            }

            // Per-channel RGB curves via CIColorCube
            let rDef = self.isDefaultCurve(snap.curveR)
            let gDef = self.isDefaultCurve(snap.curveG)
            let bDef = self.isDefaultCurve(snap.curveB)
            if !rDef || !gDef || !bDef {
                let lutR = CurvesView.evaluateSpline(snap.curveR)
                let lutG = CurvesView.evaluateSpline(snap.curveG)
                let lutB = CurvesView.evaluateSpline(snap.curveB)
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
            if snap.clarity != 0, let f = CIFilter(name: "CIUnsharpMask") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(20.0, forKey: kCIInputRadiusKey)
                f.setValue(Swift.max(0, snap.clarity) * 2.0, forKey: kCIInputIntensityKey)
                if let out = f.outputImage { ci = out }
            }
            // Texture (fine detail)
            if snap.texture != 0, let f = CIFilter(name: "CIUnsharpMask") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(4.0, forKey: kCIInputRadiusKey)
                f.setValue(Swift.max(0, snap.texture) * 2.5, forKey: kCIInputIntensityKey)
                if let out = f.outputImage { ci = out }
            }
            // Dehaze (contrast/brightness manipulation)
            if snap.dehaze != 0, let f = CIFilter(name: "CIColorControls") {
                f.setValue(ci, forKey: kCIInputImageKey)
                f.setValue(-snap.dehaze * 0.05, forKey: kCIInputBrightnessKey)
                f.setValue(1.0 + snap.dehaze * 0.25, forKey: kCIInputContrastKey)
                f.setValue(1.0, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { ci = out }
            }

            // Local adjustments (gradient masks)
            if !snap.localAdjustments.isEmpty {
                ci = self.applyLocalAdjustments(snap.localAdjustments, to: ci)
            }

            // Rotation (around image center)
            if snap.rotation != 0 {
                let angle = CGFloat(snap.rotation) * .pi / 180.0
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
            if !snap.cropRect.equalTo(CGRect(x: 0, y: 0, width: 1, height: 1)) {
                let ext = ci.extent
                let px = CGRect(
                    x: ext.minX + snap.cropRect.minX * ext.width,
                    y: ext.minY + (1.0 - snap.cropRect.maxY) * ext.height,
                    width: snap.cropRect.width  * ext.width,
                    height: snap.cropRect.height * ext.height
                )
                let cropped = ci.cropped(to: px)
                ci = cropped.transformed(by: CGAffineTransform(
                    translationX: -cropped.extent.minX,
                    y: -cropped.extent.minY))
            }

            // Vignette (applied last — purely cosmetic, after all geometry)
            if snap.vignetteAmount != 0, let f = CIFilter(name: "CIVignetteEffect") {
                let center = CIVector(x: ci.extent.midX, y: ci.extent.midY)
                let radius = hypot(ci.extent.width, ci.extent.height) * 0.55
                f.setValue(ci,                              forKey: kCIInputImageKey)
                f.setValue(center,                          forKey: kCIInputCenterKey)
                f.setValue(radius,                          forKey: kCIInputRadiusKey)
                f.setValue(-snap.vignetteAmount / 100.0,    forKey: kCIInputIntensityKey)
                f.setValue(0.5,                             forKey: "inputFalloff")
                if let out = f.outputImage { ci = out }
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
        adjUndoStack.removeAll()
        adjRedoStack.removeAll()
        isUndoRedoing = false
        if let saved = CatalogStore.shared.loadAdjustments(path: doc.url.path) {
            adjustments = saved
        }
        lastCommittedAdjustments = adjustments
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
        // Auf dem Main-Thread lesen bevor wir in den Hintergrund gehen (kein Data Race)
        let preloadedMetadata = index < collection.documents.count ? collection.documents[index].metadata : []

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
                // Metadaten nur lesen wenn noch nicht im Hintergrund geladen
                let metadata = preloadedMetadata.isEmpty
                    ? self.metadataService.readPhotoMetadata(from: accessURL)
                    : preloadedMetadata
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
        let pending = collection.documents.enumerated().filter {
            $0.element.placeholderThumbnailImage == nil &&
            $0.element.thumbnailImage == nil &&
            !thumbInFlight.contains($0.element.url)
        }
        guard !pending.isEmpty else { return }

        // Cancel any pending "hide bar" task and add to the shared accumulator.
        thumbHideTask?.cancel()
        thumbHideTask = nil
        for (_, doc) in pending { thumbInFlight.insert(doc.url) }
        thumbQueued += pending.count
        thumbnailLoadTotal = thumbQueued
        thumbnailLoadDone  = thumbDone
        thumbnailLoadProgress = thumbQueued > 0 ? Double(thumbDone) / Double(thumbQueued) : 0

        for (index, doc) in pending {
            let url = doc.url
            DispatchQueue.global(qos: .background).async { [weak self] in
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                let nsImage = (try? RAWImageDecoder.thumbnail(url: accessURL, maxDimension: 80))
                    .map { NSImage(cgImage: $0, size: .zero) }
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.thumbInFlight.remove(url)
                    if let img = nsImage,
                       index < self.collection.documents.count,
                       self.collection.documents[index].url == url,
                       self.collection.documents[index].thumbnailImage == nil {
                        self.collection.documents[index].placeholderThumbnailImage = img
                    }
                    self.thumbDone += 1
                    self.thumbnailLoadDone  = self.thumbDone
                    self.thumbnailLoadTotal = self.thumbQueued
                    self.thumbnailLoadProgress = Double(self.thumbDone) / Double(self.thumbQueued)
                    if self.thumbDone >= self.thumbQueued {
                        self.thumbDone   = 0
                        self.thumbQueued = 0
                        self.thumbInFlight.removeAll()
                        let task = DispatchWorkItem { [weak self] in
                            self?.thumbnailLoadProgress = nil
                        }
                        self.thumbHideTask = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
                    }
                }
            }
        }
    }

    private func loadMetadataInBackground() {
        let pending = collection.documents.enumerated().filter { $0.element.metadata.isEmpty }
        guard !pending.isEmpty else { return }
        for (index, doc) in pending {
            let url = doc.url
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                let (accessURL, stopAccess) = BookmarkStore.shared.access(url: url)
                defer { stopAccess() }
                let metadata = self.metadataService.readPhotoMetadata(from: accessURL)
                guard !metadata.isEmpty else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          index < self.collection.documents.count,
                          self.collection.documents[index].url == url,
                          self.collection.documents[index].metadata.isEmpty else { return }
                    self.collection.documents[index].metadata = metadata
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
        let visible = visibleDocuments
        guard let cur = collection.currentDocument,
              let visPos = visible.firstIndex(where: { $0.id == cur.id }) else { return }
        for offset in [-1, 1] {
            let neighborPos = visPos + offset
            guard neighborPos >= 0, neighborPos < visible.count,
                  let colIdx = collectionIndex(for: visible[neighborPos]),
                  collection.documents[colIdx].cgImage == nil else { continue }
            let url = collection.documents[colIdx].url
            let idx = colIdx
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

