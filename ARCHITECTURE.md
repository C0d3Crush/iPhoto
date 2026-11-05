# iPhoto – Architecture

## Übersicht

iPhoto ist eine native macOS-Fotobetrachtungs- und Bearbeitungs-App.  
Geschrieben in Swift/SwiftUI, kompiliert direkt via `swiftc` ohne Xcode-Projekt.  
Minimum Deployment Target: **macOS 11.0 (Big Sur)**.

```
┌─────────────────────────────────────────────────────────────────┐
│                          SwiftUI Views                          │
│  ContentView · SidebarView · InspectorView · LibraryGridView   │
│  ThumbnailCell · ZoomableScrollView · CropEditor · CurvesView  │
└──────────────────────────┬──────────────────────────────────────┘
                           │  @EnvironmentObject / @Published
┌──────────────────────────▼──────────────────────────────────────┐
│                       ImageViewModel (+Extensions)              │
│  Selektion · Zoom · Export · Crop · Bewertung · Album · Ordner │
│  People · HDR · Inpaint · SmartFolders · Volumes · Backup      │
└──────┬──────────┬──────────┬──────────┬────────────────────────┘
       │          │          │          │
  ImageCollection │    AnalysisEngine   MetadataService
  (Docs/Index)    │    (Histogramm/     (EXIF/IPTC lesen/
                  │     Waveform/       schreiben)
                  │     Rust-FFI)
                  │
         ┌────────▼──────────────────────────────────────────┐
         │                  Utilities                        │
         │  RAWImageDecoder · ImageExporter · CatalogStore   │
         │  RatingStore · BookmarkStore · VersionStore · Log │
         │  FaceDetector · QualityAssessor · EloRating       │
         │  ThumbnailDiskCache · BackupService · PluginStore │
         └─────────────────────┬─────────────────────────────┘
                               │  C-FFI
         ┌─────────────────────▼─────────────────────────────┐
         │              Rust/FFI Core (libiphoto_rs)         │
         │  blur · exposure · phash · hotpixel · waveform    │
         └───────────────────────────────────────────────────┘
```

---

## Schichten

### Views (`Sources/Views/`)

Reine SwiftUI-Views ohne eigene Logik. Alle Aktionen delegieren an `ImageViewModel`.

| Datei | Zweck |
|-------|-------|
| `ContentView.swift` | Haupt-Layout: NavSidebar links, ZoomableScrollView Mitte, Inspector rechts |
| `LibraryGridView.swift` | Horizontaler Thumbnail-Strip unten |
| `SidebarView.swift` | Horizontaler Thumbnail-Strip (Album-/Ordner-Ansicht) |
| `ThumbnailCell.swift` | Einzelne Thumbnail-Zelle mit Bewertungs-Badge |
| `ZoomableScrollView.swift` | `NSViewRepresentable`-Wrapper um `NSScrollView` für Zoom/Pan |
| `InspectorView.swift` | Rechte Sidebar mit Plugin-Blöcken (Drag & Drop, ein-/ausklappbar) |
| `AdjustmentsPanel.swift` | Belichtung, Kontrast, Sättigung, Kurven, Crop |
| `AnalysePanel.swift` | Histogramm, Waveform, RGB-Parade, Gradationskurven |
| `MetadataPanel.swift` | EXIF/IPTC anzeigen und editieren |
| `VersionHistorySheet.swift` | Gespeicherte Bildversionen anzeigen und wiederherstellen |
| `CropEditor.swift` | Interaktiver Zuschnitt-Editor |
| `CurvesView.swift` | Tonwertkurven-Editor mit 5 Kontrollpunkten |

### ViewModel (`Sources/ViewModels/`)

Single Source of Truth. Alle `@Published` Properties; SwiftUI leitet alle Änderungen davon ab. `ImageViewModel.swift` ist in thematische Extensions aufgeteilt:

| Datei | Zuständigkeit |
|-------|--------------|
| `ImageViewModel.swift` | Kern-State, Init, `importFiles()`, Dispatch |
| `ImageViewModel+Loading.swift` | 3-Phasen-Ladelogik, `loadCurrentImage()`, `loadThumbnails()` |
| `ImageViewModel+Adjustments.swift` | `AdjustmentState`, Live-Pipeline, `applyAdjustments()` |
| `ImageViewModel+Albums.swift` | Album-CRUD, Zuordnung |
| `ImageViewModel+AlbumFolders.swift` | Album-Ordner-Verwaltung |
| `ImageViewModel+Ratings.swift` | Sterne, Flags, Farbmarken |
| `ImageViewModel+Selection.swift` | Mehrfachauswahl |
| `ImageViewModel+Thumbnails.swift` | Thumbnail-Cache, `ThumbnailDiskCache`-Integration |
| `ImageViewModel+People.swift` | Gesichtserkennung, Clustering, Namen |
| `ImageViewModel+SmartFolders.swift` | Smart-Folder-Abfragen + Sync |
| `ImageViewModel+HDR.swift` | HDR-Merge-Workflow |
| `ImageViewModel+Inpaint.swift` | KI-Inpainting (Python/CMT-Bridge) |
| `ImageViewModel+Compare.swift` | Side-by-Side-Vergleich |
| `ImageViewModel+Backup.swift` | Backup-Einstellungen + Ausführung |
| `ImageViewModel+Context.swift` | Kontextmenü-Aktionen |
| `ImageViewModel+MetadataScan.swift` | Hintergrund-EXIF-Scan |
| `ImageViewModel+QualityDetection.swift` | Blur-/Belichtungs-/Closed-Eye-Scan |
| `ImageViewModel+Save.swift` | Nicht-destruktives Speichern, Versionierung |
| `ImageViewModel+Volumes.swift` | Eingehängte Volumes erkennen |
| `ImageViewModel+WatchedFolders.swift` | Überwachte Ordner, Auto-Import |
| `ImageLoadingOrchestrator.swift` | Koordiniert Phase-1/2/3-Laden; emittiert `SWITCH`-Metriken |
| `LibraryStore.swift` | JSON-Persistenz für Alben, SmartFolders, WatchedFolders |
| `AdjustmentSessionState.swift` | Flüchtiger Edit-Session-Zustand |
| `BackgroundActivityState.swift` | Fortschrittsanzeige für Hintergrund-Scans |
| `ComparisonState.swift` | State für Side-by-Side |
| `HDRMergeState.swift` | HDR-Job-State |
| `QualityDetectionState.swift` | Scan-Fortschritt Qualitätsprüfung |
| `VersionHistoryState.swift` | Aktive Versionshistorie |

**Datenladen (3 Phasen):**
1. **Phase 1** (sofort): vorhandenes 160 px Thumbnail anzeigen, `fitToWindowRequested = true`
2. **Phase 2** (`userInitiated`): 1500 px Vorschau dekodieren, Hauptviewer updaten
3. **Phase 3** (nach 1,5 s Betrachtungszeit oder Zoom >1): Vollbild dekodieren

### Models (`Sources/Models/`)

| Datei | Zweck |
|-------|-------|
| `ImageDocument.swift` | Struct pro Foto: URL, Pixeldaten (cgImage/previewImage/thumbnail), Metadaten, Bewertung |
| `ImageCollection.swift` | Observable Array + Index + Mehrfachauswahl |
| `RAWImageDecoder.swift` | Dekodierung via ImageIO; RAF-Fallback (Fujifilm embedded JPEG) |
| `AdjustmentState.swift` | Codable/Equatable-Struct mit allen 16 Edit-Parametern |
| `AdjustmentHistory.swift` | Undo/Redo-Stack von `AdjustmentState`-Snapshots |
| `AdjustmentRenderer.swift` | Rendert `AdjustmentState` via CoreImage-Pipeline |
| `RatingStore.swift` | Bewertungen als JSON — Legacy, Fallback zu `CatalogStore` |
| `Album.swift` | Album-Struct + `NavSelection`-Enum |
| `SmartFolder.swift` | Smart-Folder-Struct mit Filterdefinition |
| `WatchedFolder.swift` | Ordner mit Security-Scoped-Bookmark |
| `MetadataEntry.swift` | EXIF/IPTC-Eintrag (displayName, key, category, value) |
| `Preset.swift` | Benanntes Anpassungs-Preset (Codable, `.iphotorecipe`-kompatibel) |
| `Plugin.swift` | Plugin-Descriptor (Metadaten + UI-Konfiguration) |
| `FaceRecord.swift` | Erkanntes Gesicht mit Embedding-Vektor + Cluster-ID |
| `LocalAdjustment.swift` | Lokale Anpassungs-Maske (Pinsel/Gradient + Parameter) |
| `StackDetector.swift` | Erkennt Bracket-/Burst-Sequenzen aus EXIF-Daten |
| `PeopleState.swift` | Observable State für Gesichtserkennung |
| `LibraryViewMode.swift` | Enum: grid / list / columns / gallery |
| `BackupSettings.swift` | Backup-Konfiguration (Qualität, Modus, Zielordner) |
| `DetectedVolume.swift` | Eingehängtes Volume (Name, URL, Kapazität) |
| `HDRMerger.swift` | HDR-Merge-Logik (Belichtungsreihe → HDR-Stack) |
| `HotPixelResult.swift` | Ergebnis der Hotpixel-Analyse |
| `SearchParser.swift` | Parst `iphoto-cli search`-Tokens in `CatalogStore`-Abfragen |

### Utilities (`Sources/Utilities/`)

| Datei | Zweck |
|-------|-------|
| `CatalogStore.swift` | **SQLite-Katalog** — primäre Persistenz (Schema + Migration) |
| `CatalogStore+Ratings.swift` | ELO, Sterne, Flags, Farbmarken |
| `CatalogStore+Adjustments.swift` | `AdjustmentState` pro Bild speichern/laden |
| `CatalogStore+Albums.swift` | Album-CRUD + `album_images` |
| `CatalogStore+Backup.swift` | Backup-Job-State persistieren |
| `CatalogStore+People.swift` | `faces` + `people` Tabellen |
| `CatalogStore+Quality.swift` | Qualitäts-Columns + Overrides |
| `CatalogStore+Motifs.swift` | Motiv-Tag-Columns |
| `ImageExporter.swift` | JPEG/PNG/TIFF/HEIF-Export; Metal-GPU sRGB-Konvertierung (CIContext) |
| `ImageExporter+Batch.swift` | `exportBatch()` als Extension (CLI-kompatibel, kein AppKit) |
| `AnalysisEngine.swift` | Histogramm (vImage/SIMD), Waveform, RGB-Parade (teils via Rust-FFI) |
| `MetadataService.swift` | EXIF/IPTC lesen (ImageIO) und schreiben (CGImageDestination) |
| `BookmarkStore.swift` | Security-Scoped Bookmarks für Sandbox-Dateizugriff |
| `VersionStore.swift` | Backup-Versionen (Dateisystem + JSON-Index) |
| `ThumbnailDiskCache.swift` | Disk-basierter Thumbnail-Cache (160 px, LRU) |
| `FaceDetector.swift` | Vision-Framework-Wrapper für Gesichtserkennung |
| `FaceClusterer.swift` | Embedding-Clustering (DBSCAN) → `people`-Zuordnung |
| `ClosedEyeDetector.swift` | Eye-Aspect-Ratio-Erkennung (geschlossene Augen) |
| `BlurDetector.swift` | Schärfe-Score via Rust-FFI (`iphoto_blur_score`) |
| `ExposureDetector.swift` | Über-/Unterbelichtungs-Ratio via Rust-FFI (BT.709-Luma) |
| `QualityAssessor.swift` | Kombiniert Blur + Belichtung + Closed-Eye zu Qualitätsurteil |
| `SimilarityGrouper.swift` | Gruppiert Bilder per pHash + Union-Find |
| `EloRating.swift` | ELO-Algorithmus für paarweise Bildvergleiche |
| `MotifAssessor.swift` | Schreibt/liest manuelle Motiv-Tags |
| `HotPixelAnalyzer.swift` | Hotpixel-Erkennung via Rust-FFI |
| `ImageAutoEnhancer.swift` | Auto-Enhance (Bildanalyse → vorgeschlagene Anpassungen) |
| `BackupService.swift` | Backup-Job ausführen (Resizing, Metadaten, Zielordner) |
| `SmartFolderSQLGenerator.swift` | Übersetzt SmartFolder-Filter in SQL-Abfragen |
| `SmartFolderFileSync.swift` | Synchronisiert Smart-Folder-Ergebnisse auf Disk |
| `AppConfig.swift` | Key-Value-Konfigurationsdatei (`config.json`) |
| `PluginStore.swift` | Plugin-Verzeichnis einlesen, laden, auflisten |
| `InpaintProcessor.swift` | Bridge zu Python/CMT-Inpainting-Skript |
| `LensFilters.swift` | Vignette + Verzeichnung via CoreImage |
| `TetherManager.swift` | Tethered-Shooting-Verbindung |
| `Heartbeat.swift` | Laufzeitstatus (App-Aliveness-Signal für CLI-Skripte) |
| `Log.swift` | File-Logger → `~/Library/Logs/iPhoto/iPhoto.log` |
| `CrashReporter.swift` | Uncaught-Exception-Handler mit Sheet-Anzeige |
| `FileOpenHelper.swift` | `NSOpenPanel`-Wrapper |
| `Data+Extensions.swift` | Allgemeine Data-Hilfsmethoden |

### App (`Sources/App/`)

| Datei | Zweck |
|-------|-------|
| `iPhotoApp.swift` | SwiftUI App-Einstiegspunkt, Szenen-Konfiguration |
| `AppDelegate.swift` | AppKit-Lifecycle, `NotificationCenter`-Brücke zu `ImageViewModel` |
| `PluginCommands.swift` | Menükommandos für geladene Plugins |

---

## Rust/FFI Core (`Rust/crates/iphoto_rs/`)

Performance-kritische Algorithmen sind in eine Rust-Library (`libiphoto_rs`) ausgelagert, die via C-FFI (`BridgingHeader.h`) in Swift eingebunden wird.

| Modul | Funktion |
|-------|---------|
| `blur.rs` | Laplacian-Schärfe-Score (Varianz) |
| `exposure.rs` | BT.709-Luma-Histogramm, Unter-/Überbelichtungs-Ratio |
| `phash.rs` | 64-Bit perceptual Hash (DCT) + vertikaler Hash |
| `hotpixel.rs` | Hotpixel-Erkennung |
| `waveform.rs` | Waveform-Daten für `AnalysisEngine` |
| `similarity.rs` | Hamming-Distanz für pHash-Vergleiche |

---

## Datenfluß

```
Nutzer öffnet Datei(en)
        │
        ▼
ImageViewModel.importFiles()
        │
        ├── BookmarkStore.createBookmark()   (Sandbox-Zugriff sichern)
        ├── ImageCollection.append()
        ├── loadThumbnails()                 (.background QoS — 80 px Platzhalter)
        └── loadCurrentImage()
                │
                ├── Phase 1: doc.thumbnail anzeigen (sofort, 160 px aus ThumbnailDiskCache)
                ├── Phase 2: RAWImageDecoder.thumbnail(1500 px)  (.userInitiated)
                └── Phase 3: RAWImageDecoder.decode()  (nach 1,5 s / Zoom)
                        │
                        ├── MetadataService.readPhotoMetadata()
                        ├── RatingStore.load() / CatalogStore.rating()
                        └── CatalogStore.upsertImage()

Bild anzeigen
        │
        ▼
ZoomableScrollView (NSScrollView)
        │
        ├── Proportionaler Zoom bei Qualitäts-Upgrade (ratio = oldWidth/newWidth)
        └── fitToWindow() bei neuem Bild (synchron in updateNSView)

Anpassungen
        │
        ▼
ImageViewModel.applyAdjustments()
        │
        └── CIImage-Pipeline (AdjustmentRenderer):
            Belichtung → Helligkeit/Kontrast → Sättigung → Farbwärme → Farbstich
            → Klarheit/Textur/Dunst → R/G/B-Kurven (CIColorCube LUT)
            → Lokale Anpassungen → Crop + Rotation → Metal-GPU Render (adjCIContext)

Export
        │
        ▼
ImageExporter.exportSingle()
        │
        ├── convertToSRGB() via CIContext (Metal GPU)
        └── CGImageDestinationFinalize() → JPEG/PNG/TIFF/HEIF
```

---

## Persistenz

Alle persistenten Daten liegen in `~/Library/Application Support/iPhoto/`:

| Datei/Ordner | Format | Inhalt |
|---|---|---|
| `catalog.db` | SQLite (WAL) | **Primäre Datenquelle**: Bilder, Bewertungen, ELO, Alben, Presets, Anpassungen, Gesichter |
| `ratings.json` | JSON | Legacy-Bewertungen (Fallback, bleibt parallel) |
| `albums.json` | JSON | Legacy-Alben (Fallback, wird bei erstem Start migriert) |
| `bookmarks.json` | JSON | Security-Scoped Bookmarks für importierte URLs |
| `watchedFolders.json` | JSON | Überwachte Ordner (URL + Bookmark) |
| `versions/<hash>/` | Verzeichnisse | Backup-Versionen je Bild (index.json + Pixeldateien) |
| `thumbnails/` | JPEG-Dateien | ThumbnailDiskCache (160 px, LRU) |
| `config.json` | JSON | App-Konfiguration (`AppConfig`) |

Logging: `~/Library/Logs/iPhoto/iPhoto.log`

### CatalogStore — Schema

```sql
images       (id, path UNIQUE, filename, size_bytes, width, height,
              date_taken, camera_make, camera_model, is_raw, imported_at,
              focal_length, iso, aperture, lens_model, film_simulation,
              sequence_number, auto_bracket, hdr, exif_scanned,
              blur_score, under_ratio, over_ratio, phash, phash_v,
              blur_override, under_override, over_override, eyes_closed_override,
              eye_openness, quality_scanned,
              duplicate_group_id, similar_group_id,
              face_scanned, motif_scanned)

ratings      (image_path PK, rating, flag, color_label, updated_at,
              elo REAL DEFAULT 1500, elo_matches INTEGER DEFAULT 0)

trash        (image_path PK, trashed_at)

albums       (id PK, name, created_at)

album_images (album_id FK→albums, image_path, sort_order)
             PRIMARY KEY (album_id, image_path)

adjustments  (image_path PK, data TEXT, updated_at)

presets      (id PK, name, author, data TEXT, created_at)

faces        (id PK, image_path, bbox_x/y/w/h, embedding BLOB,
              cluster_id, confirmed_name)
             INDEX idx_faces_image_path, idx_faces_cluster_id

people       (id PK, name, created_at)
```

**WAL-Modus** (`PRAGMA journal_mode=WAL`) erlaubt parallele Lesezugriffe ohne Schreibsperre.  
**Fremdschlüssel** (`PRAGMA foreign_keys=ON`) sorgen für automatisches Kaskadieren beim Album-Löschen.  
**batchUpsertImages()** verpackt N Inserts in eine einzige Transaktion (10.000 Einträge ≈ 0,08 s).  
**Migrationen** laufen via `ALTER TABLE ... ADD COLUMN` — idempotent, safe für bestehende DBs.

---

## AppKit-Bridges

- **`ZoomableScrollView`** — `NSViewRepresentable` um `NSScrollView`. Zoom-Korrektur bei Qualitäts-Upgrade wird **synchron** in `updateNSView` angewendet (verhindert einen Frame mit falscher Vergrößerung).
- **`DropTargetView`** — registriert sich für Datei-URL-Drops, validiert Erweiterungen, delegiert an `ImageViewModel`.
- **`PanScrollView`** — `NSScrollView`-Subklasse mit Hand-Cursor, Drag-to-Pan und Mausrad-Zoom.

---

## CLI (`Sources/CLI/main.swift`)

`build/iphoto-cli` ist ein eigenständiges Kommandozeilen-Tool. Kompiliert **ohne AppKit**.

```
# Export & Info
iphoto-cli export <datei> --format jpeg|png|tiff|heif [--output <pfad>] [--quality 0.9] [--json]
iphoto-cli export <datei1> <datei2> ... --format jpeg --output-dir <ordner> [--json]
iphoto-cli export --list-formats [--json]
iphoto-cli info <datei> [--json]

# Bildanpassungen
iphoto-cli adjust <datei> --output <ziel> [--exposure N] [--brightness N] [--contrast N]
                  [--saturation N] [--warmth N] [--clarity N] [--sharpen N]
                  [--crop x,y,w,h] [--rotate 90|180|270] [--preset <name>]
iphoto-cli adjustments list|get|delete [<bildpfad>] [--json]
iphoto-cli local-adjustments list|clear <bildpfad> [--json]

# Presets
iphoto-cli preset list|apply|save|export|import|delete [--name <name>] [--json]

# Bewertungen & ELO
iphoto-cli rating <datei> [--set 0-5] [--flag pick|reject|none] [--color farbe] [--json]
iphoto-cli rating list [--flag ...] [--min-rating N] [--json]
iphoto-cli rating histogram [--json]
iphoto-cli rating export [--output <datei.json|.csv>] [--format json|csv] [--include-unrated] [--json]
iphoto-cli rating import <datei.json|.csv> [--skip-existing] [--dry-run] [--json]
iphoto-cli rating batch-set <bild1> [...] [--set N] [--flag ...] [--json]
iphoto-cli elo get|list|set|match|reset [<bildpfad>] [--winner left|right|draw] [--json]

# Katalog & Suche
iphoto-cli catalog stats|path|vacuum|export|scan-needed|backup-now|list|remove|get|add|prune [--json]
iphoto-cli search <text> [--flag ...] [--rating N] [--color ...] [--camera ...] [--date ...] [--json]
iphoto-cli duplicate list|similar [--json]

# Alben & Ordner
iphoto-cli album list|create|delete|add|remove|images|reorder|rename|export [--json]
iphoto-cli albumfolder list|create|rename|delete [--json]
iphoto-cli bookmarks list [--missing] [--json]
iphoto-cli bookmarks stats|path [--json]
iphoto-cli bookmarks remove <pfad|file-url> [...] [--json]
iphoto-cli bookmarks prune [--dry-run] [--json]
iphoto-cli watched list|add|remove|check [<pfad>] [--auto-sync] [--json]
iphoto-cli smartfolder list|query|create|update|rename|delete|sync [<name>] [--json]
iphoto-cli smartfolder sql <name> [--count] [--json]
iphoto-cli smartfolder count [<name>] [--json]

# Metadaten & EXIF
iphoto-cli metadata get|set <bildpfad> [--title X] [--caption X] [--keywords X]
                    [--copyright X] [--lat N] [--lon N] [--json]
iphoto-cli exif get|set|films <bildpfad> [--iso N] [--focal MM] [--aperture F]
               [--lens NAME] [--film NAME] [--json]

# Qualität & Analyse
iphoto-cli analyse <datei|ordner> [--blur-threshold N] [--shadow N] [--highlight N] [--json]
iphoto-cli quality scan|list|get|override [--blur|--under|--over|--eyes-closed on|off] [--json]
iphoto-cli hotpixel <ordner>

# Gesichter / People
iphoto-cli people scan|list|faces|cluster|rename|delete|reset|export-names|import-names [--json]

# Motiv-Tags
iphoto-cli motif get|list|set|find|stats <bildpfad> [<tags>] [--json]

# Weitere
iphoto-cli hdr <ordner> --output-dir <ziel> [--json]
iphoto-cli inpaint <datei> --output <ziel> [--python ...] [--cmt ...] [--json]
iphoto-cli query filters|parse|run [<suchtext>] [--blur-threshold N] [--include-trashed] [--json]
iphoto-cli stack list|query [<bildpfad>] [--json]
iphoto-cli trash list|mark|mark-rejected|restore|empty [--json]
iphoto-cli version list|backup|restore|delete [--json]
iphoto-cli cache stats|clear [--json]
iphoto-cli backup get|set [--quality N] [--mode rename|skip|overwrite] [--json]
iphoto-cli config show|get|set|export|import [<key>] [<wert>] [--json]
iphoto-cli plugins list|dir [--json]
iphoto-cli bugreport list|show|fix|reopen|path [--fixed|--all] [--json]
iphoto-cli viewmode get|set <grid|list|columns|gallery> [--json]
```

---

## Build

```bash
./build.sh         # → build/iPhoto.app + build/iphoto-cli
open build/iPhoto.app
```

Auto-Erkennung von Architektur (arm64/x86_64) und bestem verfügbaren macOS SDK ≥ 11.  
Alle `Sources/**/*.swift` außer `Sources/CLI/` werden zu `iPhoto.app` kompiliert.  
Die Rust-Library (`libiphoto_rs.a`) wird via `cargo build --release` erzeugt und statisch gelinkt.
