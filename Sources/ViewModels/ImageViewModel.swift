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
    @Published var compareModeActive: Bool = false
    @Published var compareLeftID: UUID? = nil
    @Published var compareRightID: UUID? = nil
    var compareLoadInFlight: Set<URL> = []
    var lastComparePair: Set<UUID> = []
    let library = LibraryStore()

    /// Lade-Queue + Import-Fortschritt (Sidebar). Änderungen werden via objectWillChange
    /// weitergeleitet, Views können weiterhin nur ImageViewModel beobachten.
    let activity = BackgroundActivityState()
    var folderSyncDebounce: [UUID: DispatchWorkItem] = [:]

    // MARK: - Adjustments

    /// Anpassungs-Session des aktuellen Bildes (Regler, Historie, Presets, Renderer)
    let adj = AdjustmentSessionState()

    // MARK: - Version history

    var versions = VersionHistoryState()

    var hasMetadataChanges: Bool { versions.pendingMetadataEntries != nil }
    var hasActiveAdjustments: Bool { adj.hasActiveAdjustments }
    var currentDocIsRAW: Bool { collection.currentDocument?.isRAW ?? false }

    // MARK: - HDR Merge
    var hdr = HDRMergeState()

    // MARK: - Internal state (accessible from extension files via internal access)

    private(set) var lastClickModifiers: NSEvent.ModifierFlags = []
    let metadataService = MetadataService()
    private var cancellables = Set<AnyCancellable>()
    var loadToken: UUID = UUID()
    var currentlyLoadingURL: URL? = nil
    // Tracks URLs that have an active 1500px-preview background task.
    // Prevents 7+ duplicate decode tasks when albums are switched rapidly.
    var previewLoadInFlight: Set<URL> = []
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

    // Reihenfolge-Cache für visibleDocuments: Filter+Sortierung (800+ teure
    // localizedStandardCompare) wird als ID-Liste gecacht, die Dokument-Inhalte
    // kommen immer frisch aus der Collection. So invalidieren Thumbnail-/Bild-
    // Mutationen den Cache nicht — nur Attribute, die Filter/Sortierung ändern
    // (Rating, Flag, Metadaten), bumpen visibleOrderVersion.
    struct VisibleOrderKey: Equatable {
        let count: Int
        let nav: NavSelection?
        let sort: SortCriterion
        let shuffle: [UUID]
        let version: Int
        let expanded: Set<String>
    }
    var visibleOrderCache: [UUID]? = nil
    var visibleOrderCacheKey: VisibleOrderKey? = nil
    var visibleOrderVersion = 0
    // Aufgelöste Dokument-Kopien zum Order-Cache — gültig solange documentsRevision
    // unverändert ist. Spart das Dictionary-Rebuild pro SwiftUI-Render-Zugriff.
    var visibleResolvedCache: [ImageDocument]? = nil
    var visibleResolvedRevision: UInt64 = 0
    var prefetchInFlight: Set<URL> = []

    // Serienbild-/Bracketing-Stapel (Fuji 0x1101 SequenceNumber):
    // Anführer-Pfad → aufgeklappt; Zähler/Zuordnung als Nebenprodukt der Order-Berechnung.
    var expandedStacks: Set<String> = []
    var stackCounts: [UUID: Int] = [:]
    var stackLeaderByMember: [UUID: UUID] = [:]
    var stackMembersByLeader: [UUID: [UUID]] = [:]

    // Smart-Folder-Zähler: Live-Filtern aller Dokumente (inkl. SQLite-Fallbacks)
    // kostete ~480 ms pro Render-Pass — daher debounced im Hintergrund berechnet.
    var smartFolderCounts: [UUID: Int] = [:]
    var sfCountRefreshScheduled = false

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
                self?.adj.userPresets = presets
                self?.isStartupLoading = false
            }
        }

        collection.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.scheduleSmartFolderCountRefresh()
            }
            .store(in: &cancellables)

        // Kind-ViewModels: Änderungen an Views weiterleiten, die nur ImageViewModel beobachten
        for child in [activity.objectWillChange, hdr.objectWillChange, versions.objectWillChange, adj.objectWillChange] {
            child
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        library.objectWillChange
            .sink { [weak self] _ in
                // Alben/Ordner beeinflussen die Filterung in visibleDocuments
                self?.invalidateVisibleOrder()
                self?.objectWillChange.send()
                self?.scheduleSmartFolderCountRefresh()
            }
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
                var handledByFolder = false
                for folder in self.library.watchedFolders where folder.autoSync {
                    guard let bookmarkPath = folder.bookmarkPath,
                          bookmarkPath.hasPrefix(volumePath) else { continue }
                    self.syncedFolderIDs.remove(folder.id)
                    self.syncFolder(folder)
                    self.navSelection = .folder(folder.id)
                    if folder.importDestinationPath != nil {
                        self.importImages(from: folder)
                        handledByFolder = true
                    }
                }
                if let volume = self.addDetectedVolumeIfRemovable(volumeURL), !handledByFolder {
                    self.offerVolumeSync(volume)
                }
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

        adj.$adjustments
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyAdjustments() }
            .store(in: &cancellables)

        adj.$adjustments
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self = self, !self.adj.isUndoRedoing else { return }
                self.adj.history.commit(newState)
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
                    if self.adj.history.canUndo { self.undoAdjustments() }
                    else { self.undoSave() }
                }; return nil
            case 6 where cmdShiftDown && !textFieldFocused:
                DispatchQueue.main.async {
                    if self.adj.history.canRedo { self.redoAdjustments() }
                    else { self.redoSave() }
                }; return nil
            default:
                guard mods.isEmpty, !textFieldFocused else { return event }
                let char = event.characters ?? ""
                if char == "\\" {
                    DispatchQueue.main.async { self.adj.showOriginal.toggle() }
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

        // Bookmarks im Hintergrund anlegen — innerhalb der Session greift access()
        // auch ohne Bookmark direkt auf die URLs zu.
        DispatchQueue.global(qos: .utility).async {
            BookmarkStore.shared.save(urls: newURLs)
        }
        let catalogRatings = CatalogStore.shared.allRatings()
        let trashedPaths = CatalogStore.shared.trashedPaths()
        let newDocs = newURLs
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url -> ImageDocument in
                var doc = ImageDocument(url: url)
                doc.isTrashed = trashedPaths.contains(url.path)
                if let r = catalogRatings[url.path] {
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
        let batchItems = newDocs.map { doc in
            (path: doc.url.path, filename: doc.url.lastPathComponent, isRAW: doc.isRAW,
             width: 0, height: 0, sizeBytes: Int64(0),
             dateTaken: nil as String?, cameraMake: nil as String?, cameraModel: nil as String?)
        }
        DispatchQueue.global(qos: .utility).async {
            CatalogStore.shared.batchUpsertImages(batchItems)
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
        Log.trace("selectDocument(\(index)) — Klick angekommen")
        persistAdjustmentsForCurrent()
        collection.select(index: index)
        loadCurrentImage()
    }

    func next() {
        Log.trace("next() — Taste/Klick angekommen")
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
        Log.trace("previous() — Taste/Klick angekommen")
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
        // Distanz in Anzeige-Reihenfolge messen, nicht im Collection-Index:
        // bei Shuffle/Sortierung liegen die sichtbaren Nachbarn sonst außerhalb
        // jedes Index-Radius und frisch geprefetchte Bilder würden sofort verworfen.
        let visible = visibleDocuments
        let curID = collection.currentDocument?.id
        let farRadius = max(keepRadius * 3, 5)
        var keepNear: Set<UUID> = []
        var keepFar: Set<UUID> = []
        if let curID = curID {
            keepNear.insert(curID)
            keepFar.insert(curID)
            if let pos = visible.firstIndex(where: { $0.id == curID }) {
                for off in -farRadius...farRadius {
                    let i = pos + off
                    guard i >= 0, i < visible.count else { continue }
                    keepFar.insert(visible[i].id)
                    if abs(off) <= keepRadius { keepNear.insert(visible[i].id) }
                }
            }
        }
        // Auf lokaler Kopie mutieren und einmalig zurückschreiben: jede einzelne
        // Subscript-Zuweisung an das @Published-Array feuert sonst einen kompletten
        // Combine-Send mit Array-Kopie + -Freigabe → O(N²) pro Aufruf. Bei Key-Repeat
        // staute das den Main-Thread minutenlang (Bug #33).
        var docs = collection.documents
        var changed = false
        for i in 0..<docs.count {
            let id = docs[i].id
            if !keepNear.contains(id), docs[i].cgImage != nil {
                docs[i].cgImage = nil
                changed = true
            }
            if !keepFar.contains(id), docs[i].previewImage != nil {
                docs[i].previewImage = nil
                changed = true
            }
        }
        if changed { collection.documents = docs }
    }

    // MARK: - Helpers

    func isSupportedFormat(_ url: URL) -> Bool {
        ImageDocument.supportedExtensions.contains(url.pathExtension.lowercased())
    }

}
