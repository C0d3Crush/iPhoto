import SwiftUI
import Combine
import AppKit
import CoreImage

class ImageViewModel: ObservableObject {

    // MARK: - Published state

    // Main-Thread-Invariante: Alle @Published-Schreibzugriffe müssen auf dem Main-Thread erfolgen.
    // Producers in BG-Threads dispatchen via DispatchQueue.main.async zurück — siehe
    // ImageViewModel+QualityDetection.swift, MetadataService.writePhotoMetadata etc.
    // Verletzungen sind CoW-Data-Races → Speicherkorruption (vgl. Bugs #7, #29, #33).
    @Published var collection = ImageCollection()
    @Published var zoomFactor: CGFloat = 1.0
    @Published var isLoading: Bool = false                       { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var errorMessage: String? = nil                   { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var fitToWindowRequested: Bool = false
    @Published var showExportSheet: Bool = false
    @Published var tetherMode: Bool = false
    @Published var hotPixelPhase: HotPixelPhase = .idle          { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var inspectorVisible: Bool = false
    @Published var isSavingMetadata: Bool = false                { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var navSidebarVisible: Bool = true
    @Published var navSelection: NavSelection? = .library
    @Published var showingLibraryDetail: Bool = false
    @Published var showFullGrid: Bool = false
    // Detail-Ansicht aus Qualitäts-Views (Unscharf/Belichtung) heraus: gleiche
    // Logik wie showingLibraryDetail, aber für navSelection = .blurry/.under-/.overexposed.
    @Published var qualityDetailActive: Bool = false
    @Published var gridThumbnailSize: CGFloat = 160
    @Published var isStartupLoading: Bool = true                 { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var sortCriterion: SortCriterion = .filenameAsc
    @Published var shuffledOrder: [UUID] = []
    /// Qualitätsanalyse-Ergebnisse (Duplikate, Unschärfe, Belichtung) + Schwellenwerte.
    /// Views greifen via `viewModel.quality.blurryDocuments` etc. zu.
    let quality = QualityDetectionState()

    /// Duell-/Vergleichsmodus (State + Load-Tracking). Änderungen laufen via
    /// objectWillChange-Forwarding an SwiftUI-Views weiter.
    let compare = ComparisonState()

    let library = LibraryStore()

    /// Konfiguration für die Backup-Funktion (Kontextmenü → „Backup"/„Backup + Papierkorb").
    /// Werte in UserDefaults persistiert; Zielordner via Security-Scoped-Bookmark.
    let backupSettings = BackupSettings()

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

    // MARK: - Inpaint
    var inpaint = InpaintState()

    // MARK: - Internal state (accessible from extension files via internal access)

    private(set) var lastClickModifiers: NSEvent.ModifierFlags = []
    let metadataService = MetadataService()
    private var cancellables = Set<AnyCancellable>()
    // Lade-Pipeline (Bild, Thumbnails, Metadaten) — kompletter State + Queues lebt
    // im Orchestrator; VM ruft nur noch die passenden Methoden auf.
    lazy var loader: ImageLoadingOrchestrator = {
        let o = ImageLoadingOrchestrator()
        o.host = self
        return o
    }()
    var folderWatchers: [UUID: DispatchSourceFileSystemObject] = [:]
    private var eventMonitors: [Any] = []
    var syncedFolderIDs: Set<UUID> = []

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
    // Positions-Lookup für visibleDocuments: id → Index. Ersetzt firstIndex(where:)
    // in next()/previous()/evictDistantImages/Grid-Views (bisher O(N) pro Aufruf,
    // bei 10k+ Bildern spürbar). Gebaut synchron zu visibleResolvedCache.
    var visiblePositionCache: [UUID: Int]? = nil

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
        library.loadAlbumFolders()
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
        for child in [activity.objectWillChange, hdr.objectWillChange, versions.objectWillChange, adj.objectWillChange, inpaint.objectWillChange, compare.objectWillChange, quality.objectWillChange, backupSettings.objectWillChange] {
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

        // Qualitäts-Listen fließen in visibleDocuments ein (blurry/underexposed/overexposed),
        // Order-Cache muss invalidieren wenn sich die Listen ändern.
        for pub in [quality.$blurryDocuments.map { _ in () },
                    quality.$underexposedDocuments.map { _ in () },
                    quality.$overexposedDocuments.map { _ in () }] {
            pub.dropFirst()
                .sink { [weak self] _ in self?.invalidateVisibleOrder() }
                .store(in: &cancellables)
        }

        // Schwellenwert-Änderungen sofort auf die Listen anwenden (kein Re-Decode nötig —
        // Scores stecken schon persistiert in den Documents).
        for pub in [quality.$blurThreshold.map { _ in () },
                    quality.$shadowClipThreshold.map { _ in () },
                    quality.$highlightClipThreshold.map { _ in () }] {
            pub.dropFirst()
                .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in self?.refreshQualityLists() }
                .store(in: &cancellables)
        }

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

        // Draft-Render (kleiner, schneller) für jedes Slider-Tick nach 50 ms Ruhe.
        adj.$adjustments
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyAdjustments(hiRes: false) }
            .store(in: &cancellables)

        // Hi-Res-Upgrade: 250 ms nach dem letzten Slider-Wechsel erneut rendern,
        // diesmal mit 1500 px. Erwischt den "Loslassen"-Zeitpunkt ohne Slider-
        // Gesture-Wrapper und bleibt bei aktiver Slider-Bewegung inaktiv.
        adj.$adjustments
            .dropFirst()
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyAdjustments(hiRes: true) }
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
            // Pfeiltasten tragen .function/.numericPad — für den Vergleich ausblenden
            let realMods = mods.subtracting([.function, .numericPad])
            if self.compare.active, realMods.isEmpty, !textFieldFocused {
                switch event.keyCode {
                case 123: DispatchQueue.main.async { self.resolveCompare(.left) };  return nil // ←
                case 124: DispatchQueue.main.async { self.resolveCompare(.right) }; return nil // →
                case 126: DispatchQueue.main.async { self.resolveCompare(.equal) }; return nil // ↑
                case 125: DispatchQueue.main.async { self.nextComparePair() };      return nil // ↓
                default: break
                }
            }
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
        loader.cancelPendingWork()
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
        let qualityRecords = CatalogStore.shared.allQualityRecords()
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
                if let q = qualityRecords[url.path] {
                    doc.blurScore      = q.blurScore
                    doc.underRatio     = q.underRatio
                    doc.overRatio      = q.overRatio
                    doc.phash          = q.phash
                    doc.phashV         = q.phashV
                    doc.qualityScanned = q.scanned
                    doc.blurOverride   = q.blurOverride
                    doc.underOverride  = q.underOverride
                    doc.overOverride   = q.overOverride
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
        // Persistierte Qualitätsflags der eben importierten Docs sofort in die Listen aufnehmen —
        // der neue Scan im Hintergrund kann Minuten dauern, aber bereits gescannte Bilder
        // (z. B. beim App-Neustart auf gleiche Library) sollen sofort sichtbar sein.
        refreshQualityLists()
        loadPersistedGroupsIfAvailable()
        if selectFirst || collection.documents.count == newDocs.count {
            collection.select(index: firstNewIndex)
            loadCurrentImage()
        }
        let metaURLs = newDocs.map { $0.url }
        activity.enqueueWork { [weak self] in self?.loadThumbnails() }
        activity.enqueueWork { [weak self] in self?.loadMetadataInBackground(for: metaURLs) }
        activity.enqueueWork { [weak self] in self?.scanExifForLibrary() }
        activity.enqueueWork { [weak self] in self?.scanQualityForLibrary() }
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
              let visPos = visiblePosition(for: cur.id),
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
              let visPos = visiblePosition(for: cur.id),
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
        // Vergleichsmodus: die beiden Duell-Bilder liegen meist weit vom currentIndex —
        // ohne Schutz würden ihre frisch geladenen Previews sofort wieder verworfen.
        for id in [compare.leftID, compare.rightID].compactMap({ $0 }) {
            keepNear.insert(id)
            keepFar.insert(id)
        }
        if let curID = curID {
            keepNear.insert(curID)
            keepFar.insert(curID)
            if let pos = visiblePosition(for: curID) {
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
