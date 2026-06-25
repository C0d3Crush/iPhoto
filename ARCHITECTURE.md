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
│                       ImageViewModel                            │
│  Selektion · Zoom · Export · Crop · Bewertung · Album · Ordner │
└──────┬──────────┬──────────┬──────────┬────────────────────────┘
       │          │          │          │
  ImageCollection │    AnalysisEngine   MetadataService
  (Docs/Index)    │    (Histogramm/     (EXIF/IPTC lesen/
                  │     Waveform/       schreiben)
                  │     Kurven)
                  │
         ┌────────▼──────────────────────────────────────────┐
         │                  Utilities                        │
         │  RAWImageDecoder · ImageExporter · CatalogStore   │
         │  RatingStore · BookmarkStore · VersionStore · Log │
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

### ViewModel (`Sources/ViewModels/ImageViewModel.swift`)

Single Source of Truth. Alle `@Published` Properties; SwiftUI leitet alle Änderungen davon ab.

**Wichtige Zustandsgruppen:**
- `collection: ImageCollection` — Array aller `ImageDocument`, aktueller Index, Mehrfachauswahl
- `zoomFactor`, `fitToWindowRequested` — Zoom-Steuerung via `ZoomableScrollView`
- `displayImageVersion: UUID` — Trick um SwiftUI zu zwingen `currentImage` neu auszuwerten
- `loadToken: UUID` — Stale-Decode-Schutz: veraltete Background-Decodes werden verworfen
- `adjCIContext`, `adjustedImage` — Live-Anpassungs-Pipeline (CoreImage)
- `albums: [Album]`, `watchedFolders: [WatchedFolder]` — Persistente Kollektionen

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
| `RatingStore.swift` | Bewertungen als JSON (`ratings.json`) — Legacy, wird von CatalogStore abgelöst |
| `Album.swift` | Album-Struct + `NavSelection`-Enum |
| `WatchedFolder.swift` | Ordner mit Security-Scoped-Bookmark |
| `MetadataEntry.swift` | EXIF/IPTC-Eintrag (displayName, key, category, value) |

### Utilities (`Sources/Utilities/`)

| Datei | Zweck |
|-------|-------|
| `CatalogStore.swift` | **SQLite-Katalog** — primäre Persistenz (siehe unten) |
| `ImageExporter.swift` | JPEG/PNG/TIFF/HEIF-Export; Metal-GPU sRGB-Konvertierung (CIContext) |
| `ImageExporter+Batch.swift` | `exportBatch()` als Extension (CLI-kompatibel, kein AppKit) |
| `AnalysisEngine.swift` | Histogramm (vImage/SIMD), Waveform, RGB-Parade |
| `MetadataService.swift` | EXIF/IPTC lesen (ImageIO) und schreiben (CGImageDestination) |
| `BookmarkStore.swift` | Security-Scoped Bookmarks für Sandbox-Dateizugriff |
| `VersionStore.swift` | Backup-Versionen (Dateisystem + JSON-Index) |
| `Log.swift` | File-Logger → `~/Library/Logs/iPhoto/iPhoto.log` |
| `CrashReporter.swift` | Uncaught-Exception-Handler mit Sheet-Anzeige |
| `FileOpenHelper.swift` | `NSOpenPanel`-Wrapper |

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
                ├── Phase 1: doc.thumbnail anzeigen (sofort, 160 px aus Cache)
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
        └── CIImage-Pipeline:
            Belichtung → Helligkeit/Kontrast → Sättigung → Farbwärme → Farbstich
            → Klarheit/Textur/Dunst → R/G/B-Kurven (CIColorCube LUT)
            → Crop + Rotation → Metal-GPU Render (adjCIContext)

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
| `catalog.db` | SQLite (WAL) | **Primäre Datenquelle**: Bilder, Bewertungen, Alben, Album-Fotos |
| `ratings.json` | JSON | Legacy-Bewertungen (Fallback, bleibt parallel) |
| `albums.json` | JSON | Legacy-Alben (Fallback, wird bei erstem Start migriert) |
| `bookmarks.json` | JSON | Security-Scoped Bookmarks für importierte URLs |
| `watchedFolders.json` | JSON | Überwachte Ordner (URL + Bookmark) |
| `versions/<hash>/` | Verzeichnisse | Backup-Versionen je Bild (index.json + Pixeldateien) |

Logging: `~/Library/Logs/iPhoto/iPhoto.log`

### CatalogStore — Schema

```sql
images       (id, path UNIQUE, filename, size_bytes, width, height,
              date_taken, camera_make, camera_model, is_raw, imported_at)

ratings      (image_path PK, rating, flag, color_label, updated_at)

albums       (id PK, name, created_at)

album_images (album_id FK→albums, image_path, sort_order)
             PRIMARY KEY (album_id, image_path)
```

**WAL-Modus** (`PRAGMA journal_mode=WAL`) erlaubt parallele Lesezugriffe ohne Schreibsperre.  
**Fremdschlüssel** (`PRAGMA foreign_keys=ON`) sorgen für automatisches Kaskadieren beim Album-Löschen.  
**batchUpsertImages()** verpackt N Inserts in eine einzige Transaktion (10.000 Einträge ≈ 0,08 s).

---

## AppKit-Bridges

- **`ZoomableScrollView`** — `NSViewRepresentable` um `NSScrollView`. Zoom-Korrektur bei Qualitäts-Upgrade wird **synchron** in `updateNSView` angewendet (verhindert einen Frame mit falscher Vergrößerung).
- **`DropTargetView`** — registriert sich für Datei-URL-Drops, validiert Erweiterungen, delegiert an `ImageViewModel`.
- **`PanScrollView`** — `NSScrollView`-Subklasse mit Hand-Cursor, Drag-to-Pan und Mausrad-Zoom.

---

## CLI (`Sources/CLI/main.swift`)

`build/iphoto-cli` ist ein eigenständiges Kommandozeilen-Tool:

```
iphoto-cli export <datei> --format jpeg|png|tiff|heif [--output <pfad>] [--quality 0.9]
iphoto-cli export <datei1> <datei2> --format png --output-dir <ordner>
iphoto-cli info <datei>
```

Kompiliert **ohne AppKit** — `ImageExporter+Batch.swift` trennt Batch-Logik von der App-Seite.

---

## Build

```bash
./build.sh         # → build/iPhoto.app + build/iphoto-cli
open build/iPhoto.app
```

Auto-Erkennung von Architektur (arm64/x86_64) und bestem verfügbaren macOS SDK ≥ 11.  
Alle `Sources/**/*.swift` außer `Sources/CLI/` werden zu `iPhoto.app` kompiliert.
