# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Performance is Priority #1

**Speed is the primary product value.** Image loading, thumbnail generation, view switching, scan pipelines — everything must feel instant. Bild-Switch-Latenz misst in Millisekunden, nicht Hundertstelsekunden.

**Every change must be perf-reviewed before it ships.** After editing, ask yourself:
1. Did I add work on the main thread? Move it off.
2. Did I touch a `@Published` array via subscript? That's an O(N) copy per write — batch mutations into one write-back (see `project_perf_diagnosis.md` / Bug #33).
3. Did I add per-doc `firstIndex(where:)` in a loop? That's O(N²) — build a `[Path: Int]` dictionary once.
4. Did I add synchronous I/O (SQLite, disk) in a render or hot path? Move to background, cache, or debounce.
5. Did I add an observer/publish that fires per-frame or per-doc? Consolidate.

**Look for new speedups proactively.** When touching a path, check whether the surrounding code is already optimal. If not, propose the improvement in the same change (or flag it explicitly). Don't leave known-slow code alone just because the current task doesn't require touching it.

**Measure, don't guess.** Trace-Logs in `~/Library/Logs/iPhoto/iPhoto.log` have timestamps — compare cache-hit vs. UI-display deltas. Suspicious latency is a bug, even if the feature "works."

**Built-in speed metrics.** `ImageLoadingOrchestrator` emits `SWITCH <path> <ms>` info-lines per image switch, tagged with the display path (`cache-hit`, `thumbnail-hit`, `preview-hit`, `preview-decoded`, `full-res`) plus `full-res-decode <ms>` for the decoder itself. This is a programmer build — keep these metrics in and read them (`tail -f ~/Library/Logs/iPhoto/iPhoto.log | grep SWITCH`) whenever you touch the load pipeline. If you add a new hot path, add its own SWITCH-style line so regressions cannot hide.

## CLI & Tests sind Pflicht

**Jedes neue Feature bekommt CLI-Support und einen Test — ohne Ausnahme.**

1. **CLI-Befehl**: Jede neue Funktion muss über `iphoto-cli` bedienbar sein. Subcommand-Muster: `iphoto-cli <feature> <subcommand> [flags]`. Neuen Befehl in `Sources/CLI/main.swift` registrieren und in `printUsage()` dokumentieren.
2. **Test in `Tests/run_plugins.sh`**: Jeden neuen CLI-Pfad mit mindestens einem `pass`/`fail`-Case abdecken. Test läuft mit temporärer Katalog-DB (`IPHOTO_CATALOG_DB`). Neuen Test **vor** dem Summary-Block einfügen.
3. **Nach jedem Feature**: `./build.sh` + `./Tests/run_plugins.sh` ausführen. Kein Commit ohne grüne Tests.

## Build & Run

Requires macOS Command Line Tools (`xcode-select --install`). No Xcode project — compiled directly via `swiftc`.

```bash
./build.sh          # compiles all Sources/**/*.swift → build/iPhoto.app + build/iphoto-cli
open build/iPhoto.app
```

The build script auto-detects architecture (arm64/x86_64) and the best available macOS SDK ≥ 11. Produces two artifacts: the SwiftUI app and a headless CLI (`iphoto-cli`) built from `Sources/CLI/main.swift` — used for export regression tests and scripting.

## Tests

No XCTest / SPM. Each test suite is its own `swiftc` compile + run, driven by shell scripts. All test binaries and temp files are cleaned up on exit; exit-code 1 signals at least one FAIL.

```bash
./Tests/run_library.sh       # Skalierungstest 10/100/500/1000 Bilder (5–7 min)
./Tests/run_bench.sh         # Absolute Perf-Benchmarks 2/12/24 MP (1–3 min)
./Tests/run_catalog.sh       # SQLite-Katalog-Korrektheit (<30 s)
./Tests/run_librarystore.sh  # JSON-Persistenz für Alben/SmartFolders/WatchedFolders (<10 s)
./Tests/run_adjustments.sh   # Adjustment-Pipeline Roundtrips
./Tests/run_stacking.sh      # Bracketing-/Sequenz-Erkennung
./Tests/test_formats.sh      # CLI-Export Regression (setzt build/iphoto-cli voraus)
```

CI (`.github/workflows/build.yml`) runs on macos-latest against every push/PR to `main`: `./build.sh` + stacking + catalog + adjustments + librarystore + test_formats. The heavy `run_library.sh` and `run_bench.sh` are **not** part of CI — run them locally when touching decoder/export/thumbnail paths.

Deep context lives in `ARCHITECTURE.md` (module map, threading model) and `STRATEGY.md` (product direction). `Tests/README.md` documents each suite's thresholds and pass/fail semantics.

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

## Multi-Akteur-Workflow

Dieses Repo wird von mehreren Akteuren gleichzeitig bearbeitet (Nutzer lokal + Cloud-Agents alle 2h). **Vor jeder Arbeitssitzung zuerst pullen:**

```bash
git pull origin main
git pull origin feature/rust-core   # falls auf diesem Branch
```

Konflikte sofort auflösen, nie einfach force-pushen. Beim Starten einer neuen Sitzung immer prüfen ob Remote-Commits vorliegen.

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

Bug-Reports und die Tabelle bekannter Fehler: siehe **[BUGS.md](BUGS.md)**

Bug-Reports werden vom `CrashReporter` automatisch beim nächsten App-Start erkannt und in `~/Documents/bugreports/` gespeichert — kein Dialog mehr. Behobene Bugs in `~/Documents/bugreports/fixed/` verschieben und Tabelle in BUGS.md aktualisieren.
