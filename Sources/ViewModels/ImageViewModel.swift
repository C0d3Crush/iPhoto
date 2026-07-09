import SwiftUI
import Combine
import AppKit
import CoreImage

class ImageViewModel: ObservableObject {

    // MARK: - Published state

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
    @Published var showFullGrid: Bool = false
    @Published var gridThumbnailSize: CGFloat = 160
    @Published var isStartupLoading: Bool = true
    @Published var sortCriterion: SortCriterion = .filenameAsc
    @Published var shuffledOrder: [UUID] = []
    let library = LibraryStore()

    struct ImportProgress {
        var folderName: String
        var completed: Int
        var total: Int
    }
    struct LoadingTask: Identifiable {
        let id: UUID
        var label: String
        var icon: String
        var done: Int
        var total: Int
        var progress: Double { total > 0 ? Double(done) / Double(total) : 0 }
    }
    @Published var importProgress: [UUID: ImportProgress] = [:]
    @Published var completedImports: Set<UUID> = []
    @Published var loadingQueue: [LoadingTask] = []

    // MARK: - Adjustments

    @Published var adjustments: AdjustmentState = AdjustmentState()
    @Published var adjustedImage: CGImage? = nil
    @Published var displayImageVersion: UUID = UUID()
    @Published var cropToolActive: Bool = false
    @Published var showOriginal: Bool = false
    /// Temporär ausgeblendete Einzel-Effekte (Auge-Toggle) — wird nicht persistiert
    @Published var bypassedAdjustments: Set<PartialKeyPath<AdjustmentState>> = []
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
    var isUndoRedoing = false
    var lastCommittedAdjustments = AdjustmentState()

    // MARK: - HDR Merge
    @Published var showHDRMergeSheet: Bool = false
    @Published var isHDRMerging: Bool = false
    @Published var hdrMergeError: String? = nil
    @Published var hdrMergeResultURL: URL? = nil

    // MARK: - Internal state (accessible from extension files via internal access)

    private(set) var lastClickModifiers: NSEvent.ModifierFlags = []
    let metadataService = MetadataService()
    private var cancellables = Set<AnyCancellable>()
    var loadToken: UUID = UUID()
    var currentlyLoadingURL: URL? = nil
    // Tracks URLs that have an active 1500px-preview background task.
    // Prevents 7+ duplicate decode tasks when albums are switched rapidly.
    var previewLoadInFlight: Set<URL> = []
    var adjToken: UUID = UUID()
    let adjCIContext: CIContext = {
        var opts: [CIContextOption: Any] = [.useSoftwareRenderer: false]
        if let linearSRGB = CGColorSpace(name: CGColorSpace.linearSRGB) {
            opts[.workingColorSpace] = linearSRGB
        }
        opts[.workingFormat] = CIFormat.RGBAh
        return CIContext(options: opts)
    }()
    var folderWatchers: [UUID: DispatchSourceFileSystemObject] = [:]
    private var eventMonitors: [Any] = []
    var syncedFolderIDs: Set<UUID> = []
    var isLoadingFullRes = false
    var activeFullResToken: UUID? = nil
    var fullResWorkItem: DispatchWorkItem? = nil
    var thumbQueued: Int = 0
    var thumbDone: Int = 0
    var thumbHideTask: DispatchWorkItem? = nil
    var thumbInFlight: Set<URL> = []
    var hiResInFlight: Set<URL> = []
    let thumbnailTaskID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var metaDone: Int = 0
    var metaTotal: Int = 0
    let metaTaskID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // MARK: - Computed properties

    var currentImage: CGImage? {
        guard let doc = collection.currentDocument else { return nil }
        return doc.cgImage ?? doc.previewImage ?? doc.thumbnail
    }
    var windowTitle: String { collection.currentDocument?.filename ?? "iPhoto" }
    var imageSize: CGSize { collection.currentDocument?.imageSize ?? .zero }

    func collectionIndex(for document: ImageDocument) -> Int? {
        collection.documents.firstIndex(where: { $0.id == document.id })
    }

    // MARK: - Init

    init() {
        library.onError = { [weak self] msg in self?.errorMessage = msg }
        library.loadAlbums()
        library.loadSmartFolders()
        library.loadWatchedFolders()
        // Backward compat: Filesystem-Verzeichnisse für bestehende Alben anlegen
        for album in library.albums { syncAlbumToFilesystem(album) }
        setupWatchedFolders()

        // CatalogStore.init() opens SQLite, runs schema migrations, and loads the full EXIF
        // cache — this can take 200–800 ms on large libraries. Warm it up on a background
        // thread so the UI is not frozen while the first frame renders.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let presets = CatalogStore.shared.allUserPresets()
            DispatchQueue.main.async {
                self?.userPresets = presets
                self?.isStartupLoading = false
            }
        }

        collection.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        library.objectWillChange
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
                self.loadThumbnails()
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter
            .publisher(for: Notification.Name("NSWorkspaceDidMountNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let volumeURL = notification.userInfo?["NSWorkspaceVolumeURLKey"] as? URL
                else { return }
                let volumePath = volumeURL.standardized.path
                for folder in self.library.watchedFolders where folder.autoSync {
                    guard let bookmarkPath = folder.bookmarkPath,
                          bookmarkPath.hasPrefix(volumePath) else { continue }
                    self.syncedFolderIDs.remove(folder.id)
                    self.syncFolder(folder)
                    self.navSelection = .folder(folder.id)
                    if folder.importDestinationPath != nil {
                        self.importImages(from: folder)
                    }
                }
                self.addDetectedVolumeIfRemovable(volumeURL)
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter
            .publisher(for: Notification.Name("NSWorkspaceDidUnmountNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let volumeURL = notification.userInfo?["NSWorkspaceVolumeURLKey"] as? URL
                else { return }
                self.removeDetectedVolume(at: volumeURL)
            }
            .store(in: &cancellables)

        scanForRemovableVolumes()

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

        $navSelection
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selection in self?.loadContentForSelection(selection) }
            .store(in: &cancellables)

        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let onlyCmdDown  = mods == .command
            let cmdShiftDown = mods == [.command, .shift]
            let textFieldFocused = NSApp.keyWindow?.firstResponder is NSTextView
            switch event.keyCode {
            case 123:
                if mods.contains(.shift) {
                    DispatchQueue.main.async { self.extendSelectionToPrevious() }
                } else {
                    DispatchQueue.main.async { self.previous() }
                }
                return nil
            case 124:
                if mods.contains(.shift) {
                    DispatchQueue.main.async { self.extendSelectionToNext() }
                } else {
                    DispatchQueue.main.async { self.next() }
                }
                return nil
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

        let mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.lastClickModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return event
        }
        eventMonitors = [keyMonitor, mouseMonitor].compactMap { $0 }

        let memSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        memSource.setEventHandler { [weak self] in self?.evictDistantImages(keepRadius: 0) }
        memSource.resume()
        cancellables.insert(AnyCancellable { memSource.cancel() })
    }

    deinit {
        folderWatchers.values.forEach { $0.cancel() }
        fullResWorkItem?.cancel()
        thumbHideTask?.cancel()
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
    }

    // MARK: - Core operations

    func importFileDialog() {
        FileOpenHelper.openPanel { [weak self] urls in
            guard let self = self, !urls.isEmpty else { return }
            self.importFiles(urls)
        }
    }

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
                CatalogStore.shared.upsertImage(path: url.path, filename: url.lastPathComponent, isRAW: doc.isRAW)
                return doc
            }

        let firstNewIndex = collection.documents.count
        collection.appendDocuments(newDocs)
        if selectFirst || collection.documents.count == newDocs.count {
            collection.select(index: firstNewIndex)
            loadCurrentImage()
        }
        loadThumbnails()
        loadMetadataInBackground(for: newDocs.map { $0.url })
        scanExifForLibrary()
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
    }

    func zoomIn()          { zoomFactor = min(zoomFactor * 1.25, 32.0) }
    func zoomOut()         { zoomFactor = max(zoomFactor / 1.25, 0.05) }
    func actualSize()      { zoomFactor = 1.0 }
    func fitToWindow()     { fitToWindowRequested = true }
    func toggleInspector() { inspectorVisible.toggle() }

    // MARK: - Memory management

    func evictDistantImages(keepRadius: Int = 2) {
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

    // MARK: - Loading queue (shared across extensions)

    func enqueueLoading(id: UUID, label: String, icon: String, done: Int = 0, total: Int = 0) {
        if let idx = loadingQueue.firstIndex(where: { $0.id == id }) {
            loadingQueue[idx].label = label
            loadingQueue[idx].done  = done
            loadingQueue[idx].total = total
        } else {
            loadingQueue.append(LoadingTask(id: id, label: label, icon: icon, done: done, total: total))
        }
    }

    func updateLoading(id: UUID, done: Int, total: Int) {
        guard let idx = loadingQueue.firstIndex(where: { $0.id == id }) else { return }
        loadingQueue[idx].done  = done
        loadingQueue[idx].total = total
    }

    func dequeueLoading(id: UUID) {
        loadingQueue.removeAll { $0.id == id }
    }

    // MARK: - Helpers

    func isSupportedFormat(_ url: URL) -> Bool {
        ImageDocument.supportedExtensions.contains(url.pathExtension.lowercased())
    }

}
