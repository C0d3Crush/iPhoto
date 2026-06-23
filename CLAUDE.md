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
