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
    @Published var inspectorExpanded: Bool = false
    @Published var isSavingMetadata: Bool = false                { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var navSidebarVisible: Bool = true
    @Published var sidebarAlbumExpanded: Bool = false
    @Published var navSelection: NavSelection? = .library
    @Published var searchQuery: String = ""
    @Published var searchResultSummary: String? = nil
    @Published var toolbarSearchVisible: Bool = false
    var searchStartTime: Date? = nil
    @Published var showingLibraryDetail: Bool = false
    @Published var showFullGrid: Bool = false
    @Published var libraryViewMode: LibraryViewMode = {
        let raw = UserDefaults.standard.string(forKey: "library.viewMode") ?? "gallery"
        return LibraryViewMode(rawValue: raw) ?? .gallery
    }() {
        didSet { UserDefaults.standard.set(libraryViewMode.rawValue, forKey: "library.viewMode") }
    }
    // Detail-Ansicht aus Qualitäts-Views (Unscharf/Belichtung) heraus: gleiche
    // Logik wie showingLibraryDetail, aber für navSelection = .blurry/.under-/.overexposed.
    @Published var qualityDetailActive: Bool = false
    @Published var compareFeatureEnabled: Bool = UserDefaults.standard.bool(forKey: "feature.compareEnabled") {
        didSet { UserDefaults.standard.set(compareFeatureEnabled, forKey: "feature.compareEnabled") }
    }
    /// Maximale Duelle pro Tag. 0 = unbegrenzt. Erstes Starten: Default 50.
    @Published var compareDailyLimit: Int = {
        if UserDefaults.standard.object(forKey: "compare.dailyLimit") == nil { return 50 }
        return UserDefaults.standard.integer(forKey: "compare.dailyLimit")
    }() {
        didSet { UserDefaults.standard.set(compareDailyLimit, forKey: "compare.dailyLimit") }
    }
    @Published var gridThumbnailSize: CGFloat = 120
    /// Aktuelle Spaltenanzahl des 2D-Grids; wird von LibraryFullGridView aktualisiert.
    var gridColumnCount: Int = 1
    // Sidebar-Mehrfachauswahl (Alben / iAlben)
    /// true = letzter Klick war in der Sidebar → Pfeiltasten navigieren Alben/iAlben
    var sidebarNavigationFocused: Bool = false
    @Published var sidebarSelectedAlbumIDs: Set<UUID> = []
    var sidebarAnchorAlbumID: UUID? = nil
    @Published var sidebarSelectedSmartFolderIDs: Set<UUID> = []
    var sidebarAnchorSmartFolderID: UUID? = nil
    @Published var isStartupLoading: Bool = true                 { didSet { dispatchPrecondition(condition: .onQueue(.main)) } }
    @Published var sortCriterion: SortCriterion = .filenameAsc
    @Published var shuffledOrder: [UUID] = []
    @Published var activeProjectName: String? = nil
    @Published var projectSubdirectories: [URL] = []
    var isProjectMode: Bool = false
    private var projectLoadToken: UUID = UUID()
    var versionHistoryURL: URL? = nil
    private var pendingOpenURLs: [URL] = []
    // Set to true once openProject/openWithoutProject has been called at least once.
    private var projectInitialized: Bool = false
    @Published var showModeSwitcher: Bool = false
    @Published var modeSwitcherEnabled: Bool = UserDefaults.standard.object(forKey: "feature.modeSwitcherEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(modeSwitcherEnabled, forKey: "feature.modeSwitcherEnabled")
            if !modeSwitcherEnabled { showModeSwitcher = false }
        }
    }
    /// Qualitätsanalyse-Ergebnisse (Duplikate, Unschärfe, Belichtung) + Schwellenwerte.
    /// Views greifen via `viewModel.quality.blurryDocuments` etc. zu.
    let quality = QualityDetectionState()

    /// Gesichts-/Personen-Erkennung (Phase 1: Scan, Zuordnung, Benennung).
    let people = PeopleState()

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
    var projectFolderWatchers: [String: [DispatchSourceFileSystemObject]] = [:]
    var projectFolderSyncDebounce: [String: DispatchWorkItem] = [:]

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

    // MARK: - Undo stacks (non-adjustment)

    struct CompareUndoEntry {
        let leftID: UUID; let rightID: UUID
        let leftElo: Double; let rightElo: Double
        let leftMatches: Int; let rightMatches: Int
    }
    /// Last compare verdict, overwritten each round (single-step undo).
    var compareUndoEntry: CompareUndoEntry? = nil
    /// Stack of path batches moved to trash — each entry is one moveToAppTrash call.
    var trashUndoStack: [[String]] = []

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
    var folderWatchers: [UUID: [DispatchSourceFileSystemObject]] = [:]
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
        let search: String
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
    var bestInStackIDs: Set<UUID> = []

    // Smart-Folder-Zähler: Live-Filtern aller Dokumente (inkl. SQLite-Fallbacks)
    // kostete ~480 ms pro Render-Pass — daher debounced im Hintergrund berechnet.
    var smartFolderCounts: [UUID: Int] = [:]
    var sfCountRefreshScheduled = false

    // Cover-ID-Caches: erste 4 Dokument-IDs pro SmartFolder/Album — verhindert
    // O(N×M) smartFolderMatches und O(N) Set-Scan pro Render-Pass im AlbumGrid.
    var smartFolderCoverIDs: [UUID: [UUID]] = [:]
    var albumCoverIDs: [UUID: [UUID]] = [:]

    // MARK: - Computed properties

    var currentImage: CGImage? {
        guard let doc = collection.currentDocument else { return nil }
        return doc.cgImage ?? doc.previewImage ?? doc.thumbnail
    }
    var windowTitle: String {
        if let doc = collection.currentDocument { return doc.filename }
        if let project = activeProjectName { return project }
        return "iPhoto"
    }
    var imageSize: CGSize { collection.currentDocument?.imageSize ?? .zero }

    func collectionIndex(for document: ImageDocument) -> Int? {
        collection.documents.firstIndex(where: { $0.id == document.id })
    }

    // MARK: - Init

    init() {
        // Set project mode before any folder loading so watched folders are skipped on startup
        if ProjectStore.shared.lastProject != nil {
            isProjectMode = true
        }
        library.onError = { [weak self] msg in self?.errorMessage = msg }
        library.loadAlbums()
        library.loadAlbumFolders()
        library.loadSmartFolders()
        library.loadWatchedFolders()
        // Backward compat: Filesystem-Verzeichnisse für bestehende Alben anlegen
        for album in library.albums { syncAlbumToFilesystem(album) }
        // Verweise auf gelöschte Dateien beim Start bereinigen (Snapshot auf Main, BG fileExists, Write auf Main)
        let albumsSnapshot = library.albums
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.purgeStaleAlbumReferences(snapshot: albumsSnapshot)
        }
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
        for child in [activity.objectWillChange, hdr.objectWillChange, versions.objectWillChange, adj.objectWillChange, inpaint.objectWillChange, compare.objectWillChange, quality.objectWillChange, backupSettings.objectWillChange, people.objectWillChange] {
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

        $searchQuery
            .dropFirst()
            .sink { [weak self] query in
                self?.searchResultSummary = nil
                self?.searchStartTime = query.isEmpty ? nil : Date()
                self?.invalidateVisibleOrder()
                self?.objectWillChange.send()
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
                if self.projectInitialized {
                    self.importFiles(urls)
                } else {
                    // Project picker not yet dismissed — buffer; drained in openProject/openWithoutProject.
                    self.pendingOpenURLs.append(contentsOf: urls)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .clearCollection)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.clearAll() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .flagPickRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.toggleFlag(.pick) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .flagRejectRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.toggleFlag(.reject) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .exportRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.showExportSheet = true }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .undoRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.performUndo() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .redoRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.redoAdjustments() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .backupRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let targets = self.backupTargetsForCurrentSelection()
                self.backupDocuments(targets, deleteOriginal: false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .backupAndTrashRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let targets = self.backupTargetsForCurrentSelection()
                self.backupDocuments(targets, deleteOriginal: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .emptyTrashRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.emptyTrash() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .checkDuplicatesRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.navSelection = .duplicates }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .openBackupFolderRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let (root, stop) = self.backupSettings.resolveDestination()
                NSWorkspace.shared.open(root)
                stop()
            }
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
            if textFieldFocused { return event }
            switch event.keyCode {
            case 123: // ←
                if self.sidebarNavigationFocused {
                    // in Sidebar: ignorieren
                } else if realMods.isEmpty {
                    // ← aus Bildbereich → Fokus zur Sidebar wechseln
                    DispatchQueue.main.async { self.sidebarNavigationFocused = true }
                } else if mods.contains(.shift) {
                    DispatchQueue.main.async { self.extendSelectionToPrevious() }
                } else {
                    DispatchQueue.main.async { self.previous() }
                }
                return nil
            case 124: // →
                if self.sidebarNavigationFocused {
                    // → aus Sidebar → Fokus zum Bildbereich wechseln
                    DispatchQueue.main.async { self.sidebarNavigationFocused = false }
                } else if mods.contains(.shift) {
                    DispatchQueue.main.async { self.extendSelectionToNext() }
                } else {
                    DispatchQueue.main.async { self.next() }
                }
                return nil
            case 126: // ↑
                let ext126 = mods.contains(.shift)
                if self.sidebarNavigationFocused {
                    switch self.navSelection {
                    case .album:
                        DispatchQueue.main.async { self.navigateSidebarAlbum(forward: false, extending: ext126) }
                    case .smartFolder:
                        DispatchQueue.main.async { self.navigateSidebarSmartFolder(forward: false, extending: ext126) }
                    default: break
                    }
                } else {
                    DispatchQueue.main.async { ext126 ? self.extendSelectionByRow(forward: false) : self.navigateByRow(forward: false) }
                }
                return nil
            case 125: // ↓
                let ext125 = mods.contains(.shift)
                if self.sidebarNavigationFocused {
                    switch self.navSelection {
                    case .album:
                        DispatchQueue.main.async { self.navigateSidebarAlbum(forward: true, extending: ext125) }
                    case .smartFolder:
                        DispatchQueue.main.async { self.navigateSidebarSmartFolder(forward: true, extending: ext125) }
                    default: break
                    }
                } else {
                    DispatchQueue.main.async { ext125 ? self.extendSelectionByRow(forward: true) : self.navigateByRow(forward: true) }
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

        // Content loading is deferred to openProject() / openWithoutProject(),
        // which are called after the user makes a project selection in the picker.
        // syncBackupCatalog is triggered there after scans complete — not here,
        // because the collection is empty at init time.
    }

    // MARK: - Projects

    func openProject(_ project: Project) {
        isProjectMode = true
        activeProjectName = project.name
        projectLoadToken = UUID()
        syncedFolderIDs = Set(library.watchedFolders.map { $0.id })
        collection.documents = []
        collection.selectedIndices = []
        collection.currentIndex = 0
        projectSubdirectories = []
        navSelection = .library
        // Discover subdirectories for sidebar sections in background — filesystem I/O off Main.
        let folderPaths = project.folderPaths
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            var subdirs: [URL] = []
            for path in folderPaths {
                let root = URL(fileURLWithPath: path)
                if let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                    let dirs = entries.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                    subdirs.append(contentsOf: dirs.sorted { $0.lastPathComponent < $1.lastPathComponent })
                }
            }
            DispatchQueue.main.async { [weak self] in self?.projectSubdirectories = subdirs }
        }
        for path in project.folderPaths {
            let url = URL(fileURLWithPath: path)
            scanProjectFolder(url)
            startWatchingProjectFolder(url)
        }
        projectInitialized = true
        let pending = pendingOpenURLs; pendingOpenURLs = []
        if !pending.isEmpty { importFiles(pending, selectFirst: true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.syncBackupCatalog()
        }
    }

    func openWithoutProject() {
        isProjectMode = false
        activeProjectName = nil
        projectLoadToken = UUID()
        projectSubdirectories = []
        syncedFolderIDs = []
        stopAllProjectFolderWatchers()
        collection.documents = []
        collection.selectedIndices = []
        collection.currentIndex = 0
        navSelection = .library
        loadContentForSelection(.library)
        restoreCatalogImages()
        projectInitialized = true
        let pending = pendingOpenURLs; pendingOpenURLs = []
        if !pending.isEmpty { importFiles(pending, selectFirst: true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.syncBackupCatalog()
        }
    }

    func scanProjectFolder(_ folderURL: URL) {
        let folderName = folderURL.lastPathComponent
        let taskID = UUID()
        let token = projectLoadToken
        DispatchQueue.main.async { self.activity.enqueue(id: taskID, label: "Lade \"\(folderName)\"", icon: "folder", done: 0, total: 0) }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                DispatchQueue.main.async { self.activity.dequeue(id: taskID) }
                return
            }
            var found: [URL] = []
            for case let fileURL as URL in enumerator {
                guard self.projectLoadToken == token else { break }
                let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if vals?.isRegularFile == true,
                   vals?.isSymbolicLink != true,
                   ImageDocument.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    found.append(fileURL)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.projectLoadToken == token else {
                    self?.activity.dequeue(id: taskID)
                    return
                }
                self.importFiles(found, selectFirst: false)
                self.activity.dequeue(id: taskID)
            }
        }
    }

    deinit {
        folderWatchers.values.forEach { $0.forEach { $0.cancel() } }
        projectFolderWatchers.values.forEach { $0.forEach { $0.cancel() } }
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

    // Returns true for paths managed internally (album copies, smart-folder symlinks).
    // These must never enter the user-visible collection or catalog.
    private func isSystemManagedPath(_ url: URL) -> Bool {
        let p = url.standardized.path
        let albumRoot = albumsSystemRoot.standardized.path
        let smartRoot = SmartFolderFileSync.root.standardized.path
        return p.hasPrefix(albumRoot + "/") || p == albumRoot
            || p.hasPrefix(smartRoot + "/") || p == smartRoot
    }

    func importFiles(_ urls: [URL], selectFirst: Bool = true) {
        let importStart = Date()
        let supported = urls.filter { isSupportedFormat($0) && !isSystemManagedPath($0) }
        guard !supported.isEmpty else { return }

        let existingURLs = Set(collection.documents.map { $0.url })
        let newURLs = supported.filter { !existingURLs.contains($0) }
        guard !newURLs.isEmpty else { return }

        // Bookmarks im Hintergrund anlegen — innerhalb der Session greift access()
        // auch ohne Bookmark direkt auf die URLs zu.
        DispatchQueue.global(qos: .utility).async {
            BookmarkStore.shared.save(urls: newURLs)
        }
        let sortedNewURLs = newURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }

        // SQLite reads and doc construction on background thread — these are full-table scans
        // that block Main at O(catalog size), regardless of import batch size.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let catalogRatings = CatalogStore.shared.allRatings()
            let catalogElos = CatalogStore.shared.allElos()
            let modifiedPaths = CatalogStore.shared.allModifiedPaths()
            let trashedPaths = CatalogStore.shared.trashedPaths()
            let backedUpPaths = CatalogStore.shared.backedUpPaths()
            let qualityRecords = CatalogStore.shared.allQualityRecords()
            let newDocs = sortedNewURLs.map { url -> ImageDocument in
                var doc = ImageDocument(url: url)
                doc.isTrashed = trashedPaths.contains(url.path)
                doc.isBackedUp = backedUpPaths.contains(url.path)
                doc.hasPersistedAdjustments = modifiedPaths.contains(url.path)
                if let r = catalogRatings[url.path] {
                    doc.rating = r.rating
                    doc.flagStatus = FlagStatus(rawValue: r.flag) ?? .none
                    doc.colorLabel = ColorLabel(rawValue: r.colorLabel) ?? .none
                } else if let entry = RatingStore.shared.load(for: url) {
                    doc.rating = entry.rating
                    doc.flagStatus = entry.flagStatus
                    doc.colorLabel = entry.colorLabel
                    doc.elo = entry.elo
                    doc.eloMatches = entry.eloMatches
                }
                if let e = catalogElos[url.path] {
                    doc.elo = e.elo
                    doc.eloMatches = e.matches
                }
                if let q = qualityRecords[url.path] {
                    doc.blurScore          = q.blurScore
                    doc.underRatio         = q.underRatio
                    doc.overRatio          = q.overRatio
                    doc.phash              = q.phash
                    doc.phashV             = q.phashV
                    doc.eyeOpenness        = q.eyeOpenness
                    doc.qualityScanned     = q.scanned
                    doc.blurOverride       = q.blurOverride
                    doc.underOverride      = q.underOverride
                    doc.overOverride       = q.overOverride
                    doc.eyesClosedOverride = q.eyesClosedOverride
                }
                return doc
            }
            let batchItems = newDocs.map { doc in
                (path: doc.url.path, filename: doc.url.lastPathComponent, isRAW: doc.isRAW,
                 width: 0, height: 0, sizeBytes: Int64(0),
                 dateTaken: nil as String?, cameraMake: nil as String?, cameraModel: nil as String?)
            }
            CatalogStore.shared.batchUpsertImages(batchItems)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let firstNewIndex = self.collection.documents.count
                self.collection.appendDocuments(newDocs)
                // Persistierte Qualitätsflags der eben importierten Docs sofort in die Listen aufnehmen.
                self.refreshQualityLists()
                self.loadPersistedGroupsIfAvailable()
                self.loadPeople()
                if selectFirst || self.collection.documents.count == newDocs.count {
                    self.collection.select(index: firstNewIndex)
                    self.loadCurrentImage()
                }
                let metaURLs = newDocs.map { $0.url }
                self.activity.enqueueWork { [weak self] in self?.loadMetadataInBackground(for: metaURLs) }
                self.activity.enqueueWork { [weak self] in self?.scanExifForLibrary() }
                Log.perf(String(format: "IMPORT %d Dateien %.0f ms", newDocs.count, Date().timeIntervalSince(importStart) * 1000))
            }
        }
    }

    // Restores all catalog-known image paths that still exist on disk but are not yet
    // in the in-memory collection (e.g. files imported in a previous session from outside
    // any watched folder). Runs async; importFiles() deduplicates against watched-folder
    // results that may arrive concurrently.
    private func restoreCatalogImages() {
        guard !isProjectMode else { return }
        let albumRoot = albumsSystemRoot.standardized.path
        let smartRoot = SmartFolderFileSync.root.standardized.path
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let fm = FileManager.default
            // Purge system-managed paths that were accidentally catalogued previously
            let allPaths = CatalogStore.shared.allImages().map { $0.path }
            let stale = allPaths.filter {
                $0.hasPrefix(albumRoot + "/") || $0 == albumRoot
                    || $0.hasPrefix(smartRoot + "/") || $0 == smartRoot
            }
            if !stale.isEmpty {
                CatalogStore.shared.deleteImages(paths: stale)
                Log.info("Catalog purge: \(stale.count) system-managed Pfade entfernt")
            }
            let cleanPaths = allPaths.filter {
                !$0.hasPrefix(albumRoot) && !$0.hasPrefix(smartRoot) && fm.fileExists(atPath: $0)
            }
            guard !cleanPaths.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let existing = Set(self.collection.documents.map { $0.url.path })
                let newURLs = cleanPaths
                    .filter { !existing.contains($0) }
                    .map { URL(fileURLWithPath: $0) }
                guard !newURLs.isEmpty else { return }
                self.importFiles(newURLs, selectFirst: false)
            }
        }
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
        sidebarNavigationFocused = false
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
