# Dev Plan — Photo α · Alpha → Beta

> **Stand:** v1.114.2 · Alpha · 2026-11-26  
> **Ziel dieser Datei:** Klare Kriterien definieren, wann wir aus der Alpha heraus sind und Beta-Tester onboarden können.

---

## Was bedeutet Alpha vs. Beta vs. 1.0?

| Phase | Definition |
|---|---|
| **Alpha** | Aktive Entwicklung, Breaking-Bugs erwartet, nur Eigennutzung |
| **Beta** | Stabil genug für externe Fuji-Tester; Core-Loop (Import → Edit → Export) zuverlässig; keine Datenverlust-Risiken; Perf auf Zielgerät akzeptabel |
| **1.0** | Öffentlicher Launch (Show HN / Product Hunt); Sparkle-Auto-Update; Open-Source-Flip möglich |

---

## Ziel-Version für Beta

**v1.120.0** — MINOR-Bump, da Film-Presets und Lokale-Anpassungen-UI als neue Features einfließen.

---

## Beta-Kriterien (alle müssen grün sein)

### A. Datenverlust-Risiken — Null-Toleranz

| Issue | Titel | Status |
|---|---|---|
| #104 | Export verliert alle Metadaten (EXIF, GPS, Datum, Copyright) | ✅ erledigt |
| #101 | Version-Restore/Undo trifft nach Index-Shift falsches Dokument | ✅ erledigt |
| #103 | RatingStore-Key basiert auf hashValue (zufällig pro Prozess) → Ratings-Datei wächst unbegrenzt | ✅ erledigt |
| #89  | App-Beenden wartet nicht auf async-Saves → letzte Änderungen gehen verloren | ✅ erledigt |

### B. Crash- und Stabilitäts-Bugs

| Issue | Titel | Status |
|---|---|---|
| #1   | SIGILL nach fehlgeschlagenen Vergleichs-Previews (gelöschte Quelldateien) | ⬜ offen |
| #111 | PluginPanelView: Data Race + nicht abbrechbare zsh-Prozesskette | ✅ erledigt |
| #112 | Tethering: NSException-Crash bei Kamera-Trennung während Session | ✅ erledigt |
| #119 | CrashReporter: falsche Session im Report oder Log-Rotation löscht Report | ✅ erledigt |

### C. Core-UX-Bugs (kaputte Basisfunktionen)

| Issue | Titel | Status |
|---|---|---|
| #127 | „Öffnen mit Photo α" öffnet falsches Projekt / ignoriert Ordner-Kontext | ✅ erledigt |
| #82  | SmartFolder-Cache wird von Album- und Motiv-Writes nicht invalidiert | ✅ erledigt |
| #83  | CatalogStore.imageCache nicht synchron nach batchUpsert/delete | ✅ erledigt |
| #92  | Duplicate-Detection: überlappende Läufe überschreiben sich (last-finisher wins) | ✅ erledigt |

### D. Performance-Schwellen für Beta

Die App muss auf dem Zielgerät (MBP 15" Mid-2015, Intel Iris Pro, macOS 11) spürbar schnell sein. Folgende Issues blockieren Beta direkt, weil sie jeden Bild-Switch oder jeden App-Start treffen:

| Issue | Titel | Warum blockierend | Status |
|---|---|---|---|
| #2   | Synchroner SQLite-Read auf Main-Thread bei jedem Bild-Switch | Jeder Switch blockt UI | ⬜ offen |
| #3   | Thumbnail-Completion: O(N)-firstIndex + 3× @Published-Write (O(N²) bei großen Alben) | Grid friert bei >200 Bildern ein | ⬜ offen |
| #79  | Bild-Switch-Pipeline: O(N)-firstIndex + mehrfache Subscript-Writes | Jeder Switch | ✅ erledigt |
| #124 | Preview-Prewarming fehlt: Nachbarbilder werden erst nach Switch geladen | Wahrnehmbare Ladezeit beim Navigieren | ⬜ offen |

Performance-Issues, die Beta *nicht* blockieren (können nach Beta behoben werden):

- #113 objectWillChange Fan-in (komplexer Refactor, kein Absturz-Risiko)
- #96 Bibliotheks-Scans O(N²/100) (trifft nur große Bibliotheken)
- #6 PeoplePanel SQLite-Scan (trifft nur People-Tab)
- #8 FaceClusterer O(n³) (läuft im Hintergrund)

### E. Feature-Vollständigkeit für Beta

Diese Features sind Teil der Beta-Geschichte — ohne sie ist die App „noch ein Viewer":

| Feature | Referenz | Status |
|---|---|---|
| Film-Look Starter-Presets (Classic-Chrome-, Acros-, Velvia-, Classic-Neg-artig) | STRATEGY.md §12 | ⬜ offen |
| Lokale Anpassungen: Pinsel-/Gradient-UI vollständig ausgebaut | Phase 4 | ⬜ offen |
| Klarheit/Textur: negative Slider-Werte funktionieren (#107) | #107 | ✅ erledigt |

---

## Kann bis 1.0 warten (nicht Beta-blockierend)

| Issue / Thema | Begründung |
|---|---|
| #5 CLI main.swift aufteilen | Tech-Debt, kein Nutzer-Impact |
| #16 CLI-Tests nicht in CI | Tests existieren, laufen lokal |
| #39 Rust-Core-Tests | Rust-Logik funktioniert, kein Absturz-Risiko |
| #47 HotPixelPanel Chart-Performance | Nische |
| #51 HDR Memory-Spike | Nische, kein Absturz |
| #52 Qualitäts-Override Drift | Priority: low |
| #66 BackupService sequenziell | Hintergrundprozess |
| #88 CatalogStore.setBackedUp sync auf Main | Selten genutzt |
| #93 Batch-Export SQLite-Serialisierung | Nische |
| #99 BookmarkStore unnötig | App nicht sandboxed |
| #100 Inpaint-Token fehlt | Nische |
| #105 CLI adjust --crop/--rotate | CLI-only |
| #108 Adjustment-Cache nach Paste | Edge Case |
| #114 ThumbnailCell Equatable fehlt | Low Impact |
| #115 PluginStore Main-Thread I/O | Startup-Impact gering |
| #121 O(N)-Vollscans TrashSizeBar | Priority: low |
| Objektivkorrekturen UI | Phase 5 |
| KI-Denoise | Großes Projekt |
| Sparkle/Notarisierung | Phase 6, für 1.0 |
| Open-Source-Flip | Nach stabilem 1.0 |

---

## Phasen-Plan Alpha → Beta

```
Alpha (jetzt)
│
├── Sprint 1: Datenverlust stoppen
│   Issues: #104, #101, #103, #89
│   → v1.115.x
│
├── Sprint 2: Crash-Elimination
│   Issues: #1, #111, #112, #119
│   → v1.116.x
│
├── Sprint 3: Core-UX-Bugs
│   Issues: #127, #82, #83, #92
│   → v1.117.x
│
├── Sprint 4: Performance-Schwellen
│   Issues: #2, #3, #79, #124
│   → v1.118.x
│
├── Sprint 5: Feature-Completion
│   Film-Presets + Lokale-Anpassungen-UI + #107
│   → v1.119.x
│
└── Beta-Cut: v1.120.0
    Stiller Beta-Kreis (5–10 Fuji-Shooter)
    Sparkle-Infra aufsetzen (Phase 6)
    Feedback einarbeiten → 1.0
```

---

## Beta → 1.0 (nach Beta-Feedback)

- Sparkle-Auto-Update + Notarisierung (Phase 6)
- Performance-Issues der zweiten Reihe (#113, #96, #6)
- Umbenennung finalisieren (§3 STRATEGY.md — „Photo α" ist Interimslösung)
- README + Build-Doku für Open-Source-Flip vorbereiten
- Show HN + Product Hunt Launch

---

## Definition of Done je Sprint

Ein Sprint ist abgeschlossen, wenn:
1. Alle gelisteten Issues geschlossen sind (oder mit Begründung zurückgestellt)
2. `./build.sh` + `./Tests/run_plugins.sh` grün
3. CI auf `main` grün
4. CHANGELOG.md aktualisiert
5. Version in Info.plist gebumpt
