# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Requires macOS Command Line Tools (`xcode-select --install`). No Xcode project — compiled directly via `swiftc`.

```bash
./build.sh          # compiles all Sources/**/*.swift → build/iPhoto.app
open build/iPhoto.app
```

The build script auto-detects architecture (arm64/x86_64) and the best available macOS SDK ≥ 11. No test suite exists.

## Architecture

SwiftUI MVVM app targeting macOS 11.7+. Frameworks: SwiftUI, AppKit, CoreImage, ImageIO, PDFKit.

**Data flow:**
1. User imports files (NSOpenPanel or drag-drop) → `ImageViewModel.importFiles()`
2. `ImageViewModel` appends to `ImageCollection`, triggers `loadCurrentImage()` + `loadThumbnails()` on background threads
3. `RAWImageDecoder` decodes images; EXIF orientation applied via `CIImage.oriented()`
4. `@Published` properties propagate changes to SwiftUI views

**Key relationships:**
- `ImageCollection` — observable array of `ImageDocument` + current selection index; sorts by filename on load
- `ImageViewModel` — single source of truth; owns `ImageCollection`, all UI state (`zoomFactor`, `isLoading`, `showExportSheet`), and load-cancellation via UUID token to discard stale decodes
- `AppDelegate` decouples from `ImageViewModel` entirely via `NotificationCenter` (named notifications for open/import/export/clear)

**Image decoding (`RAWImageDecoder`):**
- Primary: `CGImageSourceCreateImageAtIndex` via ImageIO (handles standard + RAW on macOS 12+)
- Fallback: manually parses RAF header (Fujifilm) to extract embedded JPEG preview (Big-Endian UInt32 offset/length at bytes 0x54/0x58)
- Thumbnails use `kCGImageSourceCreateThumbnailWithTransform: true` — full images require explicit `applyExifOrientation()` via `CIImage`

**AppKit bridges (NSViewRepresentable):**
- `ZoomableScrollView` — NSScrollView with magnification (0.01×–32×), custom `PanScrollView` subclass for hand-cursor panning, fit-to-window support
- `DropTargetView` — registers for file URL drops, validates extensions, passes URLs to `ImageViewModel`

**Export (`ImageExporter`):**
- Formats: JPEG, PNG, TIFF, HEIF; converts to sRGB for cross-version Preview compatibility
- Batch export runs in parallel; progress tracked via `ExportState` observable

## Commit & Push Convention

Prefix all commit messages with a type label: `bugfix:`, `feature:`, `refactor:`, `chore:`, etc.

**Auto-push after every prompt:** After completing any code change, automatically stage, commit, and push to `origin main`. Only skip if there are no changes.

**SSH access:** The first push of each day requires the user to authenticate SSH first. Before the first push of the day, tell the user to run the following in the terminal, then proceed once confirmed:
```
! ssh -T git@github.com
```

## Versioning & Changelog

**Semantic versioning** (`MAJOR.MINOR.PATCH`):
- `feature:` commit → bump MINOR, reset PATCH (e.g. 0.14.0 → 0.15.0)
- `bugfix:` / `chore:` commit → bump PATCH (e.g. 0.15.0 → 0.15.1)
- MAJOR stays 0 until the app is considered stable for general release

**After every commit, update both:**

1. `Resources/Info.plist` — set `CFBundleShortVersionString` and `CFBundleVersion` to the new version string.

2. `CHANGELOG.md` — prepend a new entry at the top following the existing format:
   - `## X.Y.Z` heading
   - Bold one-line section title
   - Bullet points describing changes (user-facing language, German)
   - Group multiple same-type commits in one version block when they form a logical unit

## Bug-Tracking

Bug-Reports werden vom `CrashReporter` automatisch beim nächsten App-Start erkannt und dem Nutzer angezeigt. Der Nutzer legt sie manuell ab unter:

```
~/Documents/bugreports/iPhoto_Crash_<datum>.txt        ← offen / zu bearbeiten
~/Documents/bugreports/fixed/iPhoto_Crash_<datum>.txt  ← behoben
```

**Workflow beim Auftreten eines neuen Bug-Reports:**
1. Datei unter `~/Documents/bugreports/` lesen und analysieren
2. Ursache identifizieren, Fehler professionell beheben (kein Quick-Fix ohne Ursachenanalyse)
3. Build mit `./build.sh` verifizieren
4. Behobene Datei nach `~/Documents/bugreports/fixed/` verschieben
5. Tabelle unten mit Ergebnis aktualisieren
6. Commit + Push wie gewohnt

**Wichtig:** Jeden Bug ernst nehmen. Crashes sind kein akzeptabler Zustand — Ursache finden, nicht umschiffen.

### Bekannte Bugs & Status

| # | Datum | Version | Symptom | Ursache | Behoben in | Test |
|---|-------|---------|---------|---------|------------|------|
| 1 | 2026-06-27 | 0.38.2 | Crash nach ~10 Min Betrieb; Bug-Report zeigte letzten Log-Eintrag abgeschnitten | `CrashReporter.buildReport()` splittete Log-Datei an `=== iPhoto gestartet ===`, das aber auch als Teilstring in normalen Log-Einträgen vorkommt → letzter Eintrag der abgestürzten Session wurde mitten im Text getrennt | 0.39.1 | Nächsten Crash provozieren und prüfen ob der Report vollständig ist; kein abgeschnittener letzter Eintrag mehr |
| 2 | 2026-06-27 | 0.39.0 | Hot-Pixel-Analyse schlägt bei RAF-Dateien fehl (kein Ergebnis) | `frameDimensions()` verwendete nur `CGImageSourceCreateImageAtIndex` ohne CIFilter-Pfad → RAF-Dateien wurden nie dekodiert; außerdem verwendete `decodeFrame()` `[CIRAWFilterOption: Any]`-Options-Dict statt `setValue`-Ansatz wie im Rest der Codebase | 0.39.1 | Ordner mit Fuji RAF-Dateien auswählen → Analyse muss durchlaufen und Ergebnis zeigen |
| 3 | 2026-06-27 | 0.39.0 | Crash-Loop beim Start: App startet, lädt 1-2 Bilder, crasht sofort, Neustart → selber Crash | `CatalogStore.bind()` übergab `(v as NSString).utf8String` mit `SQLITE_STATIC` (nil-Destruktor) an SQLite. ARC konnte die NSString-Temporary freigeben bevor `sqlite3_step` auf den Pointer zugriff → Use-after-free in SQLite | 0.39.2 | App mit mehreren Bildern öffnen, durch Bibliothek navigieren; kein Crash beim Start oder beim Laden von Bildern |
