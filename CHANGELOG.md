# iPhoto – Release Notes

---

## 0.47.9
**Bugfix: Tabs werden beim Öffnen von Anpassungen nicht mehr breiter; RGB-Parade zuverlässig schließbar**
- `Slider`-Controls haben eine System-Mindestbreite die ohne `frame(maxWidth: .infinity)` den Inspector-Container auf Fensterbreite aufzieht. Fix: Constraint auf `adjRow`-VStack und `Slider` in `AdjustmentsPanel`.
- `.allowsHitTesting(false)` auf alle rein visuellen Analyse-Diagramme (Histogramm, Waveform, RGB-Parade) — verhindert zuverlässig, dass unsichtbare ZStack-Hit-Bereiche den Collapse-Button überdecken. Nur Kurven-Tab behält Hit-Testing.

---

## 0.47.8
**Bugfix: Inspector-Tabs (Anpassungen etc.) fließen nicht mehr über den Rand**
- `InspectorBlock` fehlte `.clipShape(Rectangle())` am Content-Wrapper — gleicher Hit-Test-Overflow wie zuvor in AnalysePanel behoben.

---

## 0.47.7
**Bugfix: Analyse-Tabs zuverlässig zuklappbar**
- `.clipped()` unterdrückt nur das visuelle Rendering, nicht aber den Hit-Test-Bereich. Die Diagramm-Bilder (`Image.resizable().fill`) hatten weiterhin einen übergroßen Tap-Bereich, der den Header des nächsten Tabs überdeckte. Fix: `.clipShape(Rectangle())` auf dem Content-Wrapper (clippt auch Hit-Testing) und `.allowsHitTesting(false)` auf allen rein visuellen Diagramm-Bildern.

---

## 0.47.6
**Bugfix: Waveform/RGB-Parade lassen sich zuklappen; kein Layout-Überlauf mehr**
- Waveform- und RGB-Parade-Tabs ließen sich nicht zuklappen, weil der Bild-Inhalt horizontal über den Container hinausfloss und den Tap-Bereich des Headers überdeckte. Fix: `.frame(maxWidth: .infinity)` + `.clipShape(...)` auf den inneren ZStacks, `.clipped()` auf dem Tool-Block-Wrapper.

---

## 0.47.5
**Bugfix: Thumbnail-Ladebalken springt nicht mehr**
- `loadThumbnails()` wird mehrfach gleichzeitig aufgerufen (Import, Sync, Undo …). Jeder Aufruf erstellte einen eigenen `ProgressCounter` mit eigenem Nenner — beide schrieben auf dasselbe `thumbnailLoadProgress` und überschrieben sich abwechselnd → Zahlen sprangen zufällig vor und zurück.
- Fix: Einzelner gemeinsamer Akkumulator (`thumbQueued`/`thumbDone`) in `ImageViewModel`, der über alle parallelen Aufrufe hinweg akkumuliert. Fortschritt ist dadurch immer monoton steigend. Anzeige zeigt jetzt echte `done / total`-Werte statt der falsch berechneten `progress × documents.count`.

---

## 0.47.4
**Bugfix: Histogramm/Waveform/RGB-Parade aktualisieren sich beim Bildwechsel**
- `HistogramView` und `WaveformView` deklarierten `let engine: AnalysisEngine` statt `@ObservedObject` — SwiftUI hat keine Subscription auf `engine.objectWillChange` eingerichtet, weshalb die Views bei fertiggestellter Analyse nie neu gerendert wurden. Nur das manuelle Auf-/Zuklappen erzwang ein Re-Render (das dann den bereits berechneten Wert las). Fix: `@ObservedObject var engine` in beiden Views.

---

## 0.47.3
**Bugfix: Analyse-Diagramme bei Bildwechsel sofort leeren**
- Histogramm, Waveform und RGB-Parade zeigten beim Navigieren mit den Pfeiltasten so lange das alte Bild an, bis der Preview des neuen Bilds geladen war (bis zu 2 Sekunden)
- Fix: `onChange(of: currentIndex)` leert die Diagramme sofort beim Bildwechsel; sobald das neue Bild verfügbar ist, wird die Analyse automatisch neu gestartet

---

## 0.47.2
**Bugfix: SIGSEGV beim Durchblättern von RAF-Ordnern**
- `BookmarkStore.bookmarks` (Swift Dictionary) wurde ohne Lock von mehreren Hintergrund-Threads gleichzeitig gelesen und vom Haupt-Thread (Import/Sync) beschrieben → Read+Write-Data-Race → Speicherkorruption → SIGSEGV. Fix: `NSLock` schützt jetzt alle Lese- und Schreibzugriffe auf das Dictionary.
- Signal-Handler rief `"\(name)"` auf — Swift-String-Interpolation verwendet `malloc`, das nicht async-signal-safe ist. Wenn der Absturz selbst `malloc` unterbrochen hatte, crashte der Handler erneut (daher doppelter `[SIGNAL] SIGSEGV` in manchen Reports). Fix: Vorallozierte globale `[CChar]`-Puffer pro Signal, keine Allokation im Handler mehr.

---

## 0.47.1
**Bugfix: Pfeiltasten-Navigation in gefilterten Ordnern**
- Pfeiltasten navigieren jetzt ausschließlich durch die Bilder des aktuell aktiven Ordners/Intelligenten Ordners – kein Überspringen zu Bildern außerhalb des Filters mehr
- Beim Wechsel in einen anderen Ordner werden Bilder außerhalb des neuen Kontexts automatisch entladen (Performance)
- Prefetch der Nachbarbilder berücksichtigt ebenfalls den aktiven Filter

---

## 0.47.0
**Feature: Capture Sharpening, Rauschreduzierung, Objektivkorrekturen**
- **Schärfen** — echter Unsharp Mask mit Stärke (0–150) und Radius (0.5–3.0 px), unabhängig von Klarheit/Textur
- **Luma-Rauschen** — `CINoiseReduction` reduziert Luminanzrauschen bei ISO 6400+, ohne Farbdetails zu zerstören
- **Farb-Rauschen** — chrominanzselektive Glättung via `CILuminosityBlendMode`: Farbflecken verschwinden, Textur bleibt erhalten (kein Metal-Kernel nötig)
- **Vignette** — `CIVignetteEffect`: −100 dunkelt Ecken ab (klassisch), +100 hellt sie auf
- **Verzeichnung** — radialer Warp-Kernel korrigiert Tonnen- (−100) und Kissenverzeichnung (+100)
- **Farbsaum (CA)** — R/B-Kanalversatz vom Bildzentrum aus korrigiert laterale chromatische Aberration
- Alle 7 Werte werden gespeichert, in Export gerendert und durch Reset zurückgesetzt
- Pipeline-Reihenfolge korrekt: CA/Verzeichnung → WB/Ton → NR → Schärfen → Kurven → Vignette

---

## 0.46.0
**Feature: Intelligente Ordner + Live View entfernt**
- Neue "Intelligente Ordner" in der Navigation (Sidebar und Navigationsbereich im Inspector)
- Ordner filtern Bilder dynamisch nach Kriterien: Markierung (Pick/Reject), Mindestbewertung, Farblabel, Kamera-Hersteller, Kamera-Modell
- Mehrere Kriterien kombinierbar (alle müssen zutreffen / mindestens eines muss zutreffen)
- Ordner erstellen, bearbeiten (Rechtsklick → Bearbeiten) und löschen
- Ordner und ihre Kriterien werden dauerhaft gespeichert (`smartFolders.json`)
- Live View / Kamera-Tethering aus der Navigation entfernt

---

## 0.45.2
**Bugfix: Trackpad Pinch-to-Zoom funktioniert jetzt**
- `InternalDropView` (Drop-Ziel für Datei-Drag) lag als oberste View im ZStack und hat alle Gesture-Events verschluckt
- Fix: `hitTest` gibt `nil` zurück → View ist für Pinch/Scroll/Klick transparent; Drag-and-Drop bleibt voll funktionsfähig

---

## 0.45.1
**Bugfix: Cmd+Delete löscht Dateien vom Datenträger**
- In der Library-Ansicht wurden Bilder bisher nur aus der App entfernt, die Datei blieb auf dem Datenträger
- Jetzt: Bestätigungs-Dialog + Datei wird in den Papierkorb verschoben (Library & Ordner-Ansicht)
- Album-Ansicht: entfernt weiterhin nur den Eintrag aus dem Album (keine Dateilöschung)

---

## 0.45.0
**Feature: Importierte Bilder bleiben in der Library + Fortschrittsleiste**
- Das Importziel wird automatisch als Ordner zur Library hinzugefügt — Bilder sind auch nach Entfernen der SD-Karte sichtbar und werden beim nächsten App-Start geladen
- Fortschrittsleiste über der Ordnerliste zeigt laufende Importe (Name, Ladebalken, X/Y Bilder)
- Warnung wenn Auto-Sync aktiv ist aber kein Importziel gesetzt wurde

---

## 0.44.0
**Feature: Rezepte rückgängig machen**
- Nach „Anwenden" erscheint direkt am Rezept ein „↩ Rückgängig"-Button — stellt den Zustand vor dem Anwenden wieder her
- Untere Leiste zeigt „Zurücksetzen" wenn Anpassungen aktiv sind — setzt alle auf Null zurück
- Wechsel zu einem anderen Bild setzt den Rückgängig-Button automatisch zurück

---

## 0.43.1
**Bugfix: App-Absturz beim Öffnen von RAF-Dateien mit Anpassungen (macOS 11)**
- `applyAdjustments()` setzte `inputAllowDraftMode`, `inputScaleFactor`, `inputNeutralTemperature` ohne vorherigen `inputKeys`-Check
- `CIRAWFilterImpl` kennt diese Keys auf macOS 11 nicht → `NSUnknownKeyException` → SIGABRT
- Fix: Alle `setValue:forKey:` für CIRAWFilter-Keys werden jetzt durch `rf.inputKeys.contains(...)` abgesichert

---

## 0.43.0
**Feature: Bilder-Import + Bugfix Bewertungen**
- Ordner können jetzt ein lokales Importziel haben (Rechtsklick → „Importziel festlegen…")
- Neue Bilder vom Wechselmedium werden beim Einführen (Auto-Sync) oder manuell auf den Mac kopiert
- Fortschrittsanzeige direkt unter dem Ordnernamen während des Imports
- Bugfix: Bewertungen, Pick/Reject und Farb-Labels gingen nach App-Neustart verloren — werden jetzt sofort beim Laden der Bilder aus der Datenbank wiederhergestellt

---

## 0.42.1
**Bugfix: Crash-Reports wurden nicht gespeichert**
- Ursache: App-Sandbox blockierte Schreibzugriff auf `~/Documents/bugreports/` still (kein Fehler, kein Report)
- Fix: Sandbox-Entitlement entfernt — die App ist ad-hoc signiert und nicht im App Store
- Reports landen jetzt zuverlässig in `~/Documents/bugreports/iPhoto_Crash_<datum>.txt`

---

## 0.42.0
**Feature: Auto-Sync für Wechselmedien**
- Jeder Ordner kann per Rechtsklick → „Auto-Sync bei Einführen" aktiviert werden
- Wird die SD-Karte / der USB-Stick eingeführt, synchronisiert iPhoto automatisch neue Bilder und wechselt zur Ordneransicht
- Aktive Ordner zeigen ein kleines Sync-Icon neben dem Namen
- Einstellung wird pro Ordner gespeichert

---

## 0.41.0
**Feature: Wechselmedium-Erkennung + Auswahl-Export**
- Ordner auf SD-Karten oder USB-Laufwerken werden mit Festplatten-Icon dargestellt
- Ist das Medium nicht eingeführt, erscheint die Warnung „Speichermedium nicht verfügbar"
- Export-Dialog: neuer Umfang „Auswahl (X Bilder)" — wird automatisch vorgewählt wenn mehrere Bilder markiert sind

---

## 0.40.0
**Feature: Sternebewertungs-Panel**
- Neues Inspector-Plugin „Bewertung" (standardmäßig aktiv)
- 5 anklickbare Sterne – erneutes Klicken der aktuellen Bewertung setzt auf 0 zurück
- Pick/Reject-Buttons mit farblicher Hervorhebung
- Farb-Label-Picker (rot, gelb, grün, blau) als Punkte-Auswahl
- Alle Bewertungen werden wie gewohnt via RatingStore + CatalogStore persistiert

---

## 0.39.5
**Feature: Crash-Reports werden automatisch gespeichert**
- Kein Crash-Report-Dialog mehr beim App-Start
- Reports werden direkt in `~/Documents/bugreports/` abgelegt (`iPhoto_Crash_<datum>.txt`)

---

## 0.39.4
**Bugfix: Hot-Pixel-Analyse crasht auf macOS 11 bei RAF-Dateien**
- `setValue:forKey:inputAllowDraftMode` warf `NSUnknownKeyException` auf macOS 11 (Key in `CIRAWFilterImpl` nicht vorhanden) → SIGABRT
- Fix: `filter.inputKeys.contains(...)` prüft vor jedem `setValue` ob der Key unterstützt wird

---

## 0.39.3
**Bugfix: Memory-Eviction + POSIX-Signal-Handler**
- `cgImage`-Objekte (bis zu ~200 MB pro Bild) werden beim Navigieren automatisch freigegeben: aktuelle Position ±2 bleibt im Speicher, alles weitere wird verworfen und bei Bedarf neu geladen
- Bei System-Memory-Pressure (DispatchSource) werden alle nicht sichtbaren Vollbilder sofort freigegeben
- POSIX-Signal-Handler für SIGSEGV, SIGABRT, SIGBUS, SIGILL: zukünftige Crashes hinterlassen jetzt einen Log-Eintrag (`[SIGNAL] SIGSEGV` o.ä.) im Crash-Report

---

## 0.39.2
**Bugfix: Startup-Crash durch Use-after-free in CatalogStore**
- CatalogStore übergab SQLite Strings per `SQLITE_STATIC` (nil-Destruktor): ARC konnte die NSString-Temporary freigeben bevor `sqlite3_step` auf den Pointer zugegriffen hatte
- Fix: `SQLITE_TRANSIENT` als Destruktor — SQLite kopiert den String sofort beim Bind, der Pointer wird danach nicht mehr benötigt
- Behebt Crash-Loop beim Start (App crashte nach dem Laden von 1-2 Bildern)

---

## 0.39.1
**Bugfix: CrashReporter Session-Splitting + Hot-Pixel RAF-Dekodierung**
- CrashReporter erkennt den abgestürzten Session-Block jetzt korrekt (neuer Marker `###SESSION_START###` verhindert Verwechslung mit Log-Einträgen)
- Unkorrekte Ausnahmen werden via `NSSetUncaughtExceptionHandler` geloggt bevor der Prozess beendet wird
- Hot-Pixel-Analyse lädt RAF-Dateien zuverlässig (gleicher `CIFilter(imageURL:options:nil)` + `setValue`-Ansatz wie der Rest der App)
- Bug-Report-Datei `iPhoto_Crash_2026-06-27_011610.txt` als behoben archiviert

---

## 0.39.0
**Feature: Hot-Pixel-Detektor**
- Neues Plugin „Hotpixel" im Plugins-Menü und Inspector-Panel
- Dunkelbilder-Ordner auswählen und automatisch alle RAF/JPEG/TIFF/PNG-Frames analysieren
- Algorithmus: 16-Bit-Graustufen-Stack, Schwelle = Mittelwert + 5σ (Einzelframe-Rauschen)
- Ergebnis-Bewertung in Klassen A (hervorragend) bis F (defekt) nach Anzahl der Hot Pixel
- Drei CoreGraphics-Diagramme: Hot-Pixel-Karte, 20×20-Cluster-Grid mit Farbskala, Verteilungshistogramm
- Top-10-Tabelle der hellsten Hot Pixel mit X/Y-Position und Wert
- Vollständig in sich geschlossen – keine Änderungen an ImageViewModel erforderlich

---

## 0.38.2
**Bugfix: Kamera-Vorschau direkt im Hauptfenster**
- Live-Vorschau öffnet kein separates Fenster mehr — sie lebt jetzt im normalen Bildbereich
- Kamera-Button in der linken Navigation wechselt in den Kamera-Modus (erneut klicken zum Beenden)
- Auslöser, Video und Gerätewahl als transparente Leiste am unteren Bildrand

---

## 0.38.1
**Bugfix: iPhone Continuity Camera wird erkannt**
- iPhone erscheint jetzt korrekt in der Kameraliste (macOS 13+)

---

## 0.38.0
**Tethered Shooting — Live-Vorschau & Kameraauslöser**
- Neuer „Kamera"-Button in der linken Navigation öffnet Live-Vorschau-Fenster
- Unterstützt Fujifilm X-T4 (USB-Webcam-Modus), iPhone (Continuity Camera, macOS 13+) und alle UVC-Kameras
- Foto auslösen direkt aus iPhoto heraus (Leertaste), aufgenommene Bilder automatisch importiert
- Videoaufnahme starten/stoppen, Video wird ebenfalls importiert
- Aufnahmen landen in `~/Pictures/iPhoto Tethered/` und sofort in der aktuellen Bibliothek
- Fehlende Plugin-Einträge ergänzt: Navigation, Rezepte und Lokal jetzt im Plugins-Menü ein-/ausschaltbar

---

## 0.37.0
**Lokale Anpassungen mit Verlaufsmasken (Phase 4)**
- Neues „Lokal"-Panel im Inspector für nicht-destruktive lokale Anpassungen
- Linearer Verlauf: Maske von Punkt A zu Punkt B — z. B. Himmel abdunkeln oder Boden aufhellen
- Radialer Verlauf: Kreisförmige Maske mit einstellbarem Radius und Weichzeichnung
- Pro Maske: Belichtung, Helligkeit, Kontrast, Sättigung, Wärme und Farbstich unabhängig anpassbar
- Stärke-Regler (0–100 %) und Invertieren-Option für jede Maske
- Masken werden in der nicht-destruktiven Pipeline angewendet — Original bleibt unberührt
- Masken-Einstellungen werden im SQLite-Katalog gespeichert und sind Undo/Redo-fähig

---

## 0.36.0
**Film-Simulationen + Rezept-System (Phase 3)**
- 6 eingebaute Film-Looks: Chrome, Schwarz, Velvet, Nostalgie, Kino, Morgen
- Neues „Rezepte"-Panel im Inspector: Film-Looks + eigene Rezepte mit einem Klick anwenden
- Eigene Rezepte speichern (aktuelle Anpassungen als Preset sichern)
- Rezepte exportieren (`.iphotorecipe`-Datei) und importieren — teilbar, kein Account nötig
- `Preset`-Modell ist `Codable` — Format ist offen und erweiterbar

---

## 0.35.1
**Undo/Redo für Anpassungen (Cmd+Z / Cmd+Shift+Z)**
- Jede Slider-Bewegung (500 ms nach letzter Änderung) wird auf einen Undo-Stack geschrieben (max. 50 Schritte)
- Cmd+Z macht den letzten Adjustment-Schritt rückgängig; Cmd+Shift+Z stellt ihn wieder her
- Wenn kein Adjustment-Undo vorhanden ist, fällt Cmd+Z auf den Versions-Undo zurück
- Stacks werden beim Bildwechsel geleert — jedes Bild hat seine eigene Session-History

---

## 0.35.0
**Export-Modell + Batch-Sync (Phase 2)**
- „Speichern" für Anpassungen entfernt — Originaldatei wird nie verändert
- Stattdessen: „Exportieren"-Button öffnet den Export-Dialog zum Rendern in eine neue Datei
- „Metadaten"-Button speichert nur EXIF/IPTC (weiterhin sicher in-place)
- Neue Buttons „Kopieren" / „Einfügen" im Anpassungen-Panel: Einstellungen auf aktuelles Bild oder die gesamte Auswahl übertragen
- Batch-Paste schreibt die kopierten Anpassungen für alle markierten Bilder direkt in den Katalog

---

## 0.34.0
**Edits pro Bild persistiert — Katalog als Wahrheit (Phase 2)**
- Alle Anpassungen (Belichtung, WB, Kurven, Crop …) werden beim Bildwechsel automatisch im SQLite-Katalog gespeichert
- Beim Zurückwechseln zu einem Bild werden die Regler exakt so wiederhergestellt wie verlassen
- Neue `adjustments`-Tabelle im Katalog (JSON-kodiertes `AdjustmentState`)
- Default-Edits (alle Regler neutral) werden nicht gespeichert — der Eintrag wird gelöscht

---

## 0.33.1
**Nativer Weißabgleich direkt am RAW-Decoder**
- Wärme- und Farbstich-Regler setzen bei RAW-Dateien jetzt `inputNeutralTemperature` / `inputNeutralTint` am `CIFilter(imageURL:)` — Weißabgleich greift vor dem Demosaicing auf die Rohdaten
- Ohne Anpassung verwendet der Decoder den eingebetteten Kamera-WB (korrektes Standardverhalten)
- `CITemperatureAndTint` auf dem gerenderten Bild entfällt für RAW — nur noch für JPEG/PNG aktiv

---

## 0.33.0
**Preview-Auflösung + Half-Float-Pipeline für RAW-Editing**
- RAW-Slider-Moves rendern jetzt in max. 1500 px (`inputScaleFactor`) + Draft-Mode (`inputAllowDraftMode`) — deutlich schneller auf älterer Hardware
- `CIContext` arbeitet jetzt in halbfloat (RGBAh) und linearem sRGB — kein Banding mehr in Lichtern/Schatten bei starken Edits
- Volle Auflösung wird nur beim Export verwendet (RAW-Speichern bleibt bewusst blockiert)

---

## 0.32.1
**Ladebalken beim Thumbnail-Import**
- Schlanke Fortschrittsleiste erscheint unten zwischen Viewer und Thumbnail-Strip wenn Bilder geladen werden
- Zeigt „X / Y" Bilder als Zähler rechts daneben
- Verschwindet automatisch 0,4 s nach Abschluss

---

## 0.32.0
**Navigation als Inspector-Panel**
- Neue Panel-Option „Navigation" im rechten Inspector (aktivierbar über Plugin-Menü)
- Zeigt Bibliothek, Alben und Ordner direkt in der rechten Seitenleiste
- Ordner aufklappbar mit Bildliste und Thumbnail-Vorschau — identisch zur linken Sidebar
- `AdjustmentState` jetzt `Codable` (Vorbereitung für Pro-Bild-Persistenz)

---

## 0.31.1
**Refactor: 16 einzelne Adjustment-Properties zu `AdjustmentState` zusammengefasst**
- `ImageViewModel` verwendet jetzt ein einzelnes `@Published var adjustments: AdjustmentState` statt 16 separater `adj*`-Properties
- `AdjustmentState` ist ein `Equatable`-Struct mit allen Bildbearbeitungs-Parametern
- Combine-Pipeline vereinfacht: ein einziger `$adjustments`-Publisher statt `MergeMany` über 15 Publisher
- Keine Verhaltensänderung — reine interne Umbenennung

---

## 0.31.0
**CIRAWFilter-Pipeline — volle Sensor-Latitude für RAW-Dateien**
- RAW-Dateien (CR2, NEF, ARW, DNG, …) werden jetzt direkt über `CIFilter(imageURL:)` verarbeitet — keine Vorkonvertierung auf 8-Bit sRGB mehr
- Belichtungsanpassung greift jetzt auf die echten 12–14 Bit Sensordaten zu (volle Latitude)
- Fallback auf Bitmap-Pipeline bleibt erhalten (nicht-RAW-Formate unverändert)

---

## 0.30.2
**Inspector scrollt als Ganzes — keine internen Scrollbereiche mehr**
- Scrollen im Inspector bewegt jetzt alle Panels zusammen (außen)
- Metadaten- und Anpassungen-Panel haben keinen eigenen Scrollbereich mehr

---

## 0.30.1
**RGB-Parade untereinander + Kurven-Canvas begrenzt**
- RGB-Parade zeigt R / G / B vertikal gestapelt (je 80 px) mit Farb-Label links
- Kurven-Canvas hat jetzt eine maximale Höhe von 200 px — kein Scrollen nötig

---

## 0.30.0
**Ordner in der Sidebar aufklappbar**
- Pfeil-Button klappt Ordner auf/zu (mit Animation, unabhängig von Auswahl)
- Klick auf Ordnername wählt Ordner aus und klappt ihn gleichzeitig auf
- Ausgeklappter Ordner zeigt alle enthaltenen Bilder mit Vorschau-Thumbnail und Dateiname
- Klick auf ein Bild in der Liste wählt es direkt im Hauptviewer aus
- Aktuell angezeigtes Bild wird in der Liste hervorgehoben

---

## 0.29.2
**Dokumentation**
- `ARCHITECTURE.md`: Systemübersicht (ASCII-Diagramm), Datenfluß, Schichtmodell, Persistenz-Schema, AppKit-Bridges, CLI
- `Tests/README.md`: Wie man alle Tests ausführt, was jeder Test prüft, Schwellwerte und FAIL-Bedeutung

---

## 0.29.1
**Katalog-Tests (21 PASS)**
- `Tests/catalog/main.swift` + `Tests/run_catalog.sh`: 21 Tests über Schema, CRUD, Suche, Performance und Persistenz
- `batchUpsertImages()` in CatalogStore: 10.000 Einträge in einer Transaktion (&lt; 0.1 s)

---

## 0.29.0
**SQLite-Katalog (`CatalogStore`)**
- Neue Datei `~/Library/Application Support/iPhoto/catalog.db` mit WAL-Modus
- Tabellen: `images`, `ratings`, `albums`, `album_images` — mit Fremdschlüsseln und Indizes
- Bilder werden beim Vollbild-Load automatisch im Katalog registriert (Pfad, Größe, Kamera, Datum)
- Bewertungen/Flags/Farbmarken werden parallel in JSON und SQLite gespeichert
- Album-Operationen (erstellen, umbenennen, löschen, Fotos hinzufügen/entfernen) spiegeln sich im Katalog
- Migration: bestehende `albums.json` wird beim ersten Start importiert
- Ratings-Fallback: CatalogStore → RatingStore (JSON) für rückwärtskompatibles Laden
- Suchfunktion nach Dateiname, Kamera, Datum; Filter nach Flag und Mindestbewertung

---

## 0.28.2
**Fix: Erstes Bild nicht mehr rangezoomt**
- Fix: Wenn das 160 px Thumbnail schon geladen war bevor die 1500 px Vorschau ankam, wurde fitToWindow übersprungen — das Bild erschien 1:1 (zu groß)

---

## 0.28.1
**Viewport-basiertes Thumbnail-Laden mit Qualitätsstufen**
- Nur sichtbare Thumbnails werden sofort in 160 px geladen (höhere Priorität)
- Alle anderen Bilder erhalten zuerst ein günstiges 80 px Platzhalter-Thumbnail im Hintergrund
- Beim Scrollen wird jede neu sichtbare Zelle automatisch auf 160 px hochgeladen
- Weicher Überblendeffekt beim Qualitätswechsel (80 px → 160 px)

---

## 0.28.0
**Bibliotheks-Skalierungstest**
- `Tests/library/main.swift` + `Tests/run_library.sh`: 7 Sektionen, 22 Tests über 10/100/500/1000 Bilder
- Misst sequenziellen/parallelen Thumbnail-Durchsatz, Vorschau-Throughput, Vollbild-Decode, Batch-Export, Speicherskalierung und Stabilitätstest
- Stabilitätstest: 1000 Bilder × Thumbnail + Vorschau + Export gleichzeitig, kein Fehler erlaubt

---

## 0.27.2
**Performance-Benchmark-Suite**
- `Tests/bench/main.swift` + `Tests/run_bench.sh`: 21 Benchmarks über 3 Bildgrößen (2/12/24 MP)
- Misst Decode (JPEG/PNG), Thumbnail (160 px / 1500 px), Export (JPEG/PNG/TIFF) mit Min/Avg/Median/p95/Max
- Definierte Schwellwerte je Größe; Exit-Code 1 bei Überschreitung
- Ausgabe mit Plattform, CPU-Anzahl, RAM und Zeitstempel

---

## 0.27.1
**Sanfterer Bildwechsel beim progressiven Laden**
- Beim Qualitäts-Upgrade (Thumbnail → Vorschau → Vollbild) wird der Zoom jetzt proportional skaliert statt zurückgesetzt
- Kein Sprung mehr beim Bildwechsel wenn der Nutzer bereits gezoomt oder gescrollt hat

---

## 0.27.0
**CLI-Tool: `iphoto-cli` für Kommandozeilenexport**
- `./build.sh` erstellt jetzt zusätzlich `build/iphoto-cli`
- `iphoto-cli export <datei> --format jpeg|png|tiff|heif [--output <pfad>] [--quality 0.9]`
- `iphoto-cli export <datei1> <datei2> --format png --output-dir <ordner>` (Batch)
- `iphoto-cli info <datei>` zeigt Bildgröße, Kamera, ISO, Belichtung, Blende
- `Tests/test_formats.sh` testet alle Export-Formate automatisch (7 Tests, HEIF als Skip im CLI)

---

## 0.26.0
**Progressives Laden — stufenweise Bildqualität ohne Stottern**
- Bilder erscheinen sofort als Thumbnail (Phase 1), dann schnell in ~1500px Vorschau (Phase 2), schließlich in voller Auflösung nach 1,5 s Betrachtungszeit (Phase 3)
- Beim Hineinzoomen über 1:1 wird automatisch das Vollbild nachgeladen
- Ladeindikator erscheint nur noch wenn kein Thumbnail verfügbar ist

---

## 0.25.1
**Performance-Messungen in Log**
- Histogramm-Analysezeit (Pixel-Pass + Render) wird in `~/Library/Logs/iPhoto/iPhoto.log` geloggt
- Export-sRGB-Konvertierungszeit pro Datei wird geloggt

---

## 0.25.0
**GPU-Beschleunigung für Histogramm und Export**
- RGB-Histogramm wird jetzt per SIMD (vImage/Accelerate) berechnet – deutlich schneller bei jedem Slider-Move
- sRGB-Konvertierung beim Export läuft jetzt über Metal (Core Image) statt CPU

---

## 0.24.1
**Deployment Target zurück auf macOS 11**
- Minimum Deployment Target wieder auf macOS 11.0 (Big Sur) gesenkt
- Kompatibilität mit älteren macOS-Versionen wiederhergestellt

---

## 0.24.0
**Minimum macOS 13 — modernisierte APIs**
- Minimum Deployment Target auf macOS 13.0 (Ventura) angehoben
- onChange-Handler auf neue Zwei-Parameter-Syntax umgestellt
- Textauswahl im Crash-Report-Sheet aktiviert
- macOS-11-Workarounds entfernt

---

## 0.23.1
**Inspector-Fixes & Crash-Behebung**
- Fix: Crash auf macOS 11 durch Layout-Loop im Inspector (verschachtelte ScrollViews)
- Fix: Plugin-Header klappt jetzt beim Klick auf den gesamten Header auf/zu (nicht nur Pfeil-Button) — gilt für Inspector und Analyse-Panel
- Fix: Inspector-Header oben angeheftet, Speichern-Leiste immer unten fixiert
- Fix: Inspector-Button in die Toolbar ganz rechts verschoben

---

## 0.23.0
**Lightroom-Features: Farbstich, Detail, Before/After, Bewertung, R/G/B-Kurven**
- Farbstich-Regler (−1…+1) für Grün-/Magenta-Balance via CITemperatureAndTint
- Klarheit (radius 20), Textur (radius 4) und Dunst-Entfernung als Detailregler
- Before/After-Toggle: Augensymbol in der Toolbar oder `\`-Taste zeigt das Original
- Bewertungssystem: Sterne (0–5 via Zifferntasten), Aufnahme-Flag (p = Auswählen, x = Ablehnen), Farbmarken (6–9: rot/gelb/grün/blau) — Werte werden persistent in AppSupport gespeichert
- Badges im Thumbnail-Strip: Sterne, Fähnchen und Farbpunkt sichtbar
- Separate R/G/B-Kurven: Kanalwahl-Picker (RGB / R / G / B) im Kurven-Editor, CIColorCube-LUT für pixelgenaue Kanal-Isolation
- Alle neuen Regler in `hasActiveAdjustments` und `resetAdjustments()` integriert

---

## 0.22.0
**Crop & Straighten**
- Neues Zuschneiden-Werkzeug im Anpassungen-Plugin ("Zuschneiden & Begradigen")
- Interaktiver Crop-Editor mit 8 Ziehpunkten (Ecken + Kanten) und Verschieben per Drag auf die Fläche
- Drittel-Linien (Rule of Thirds) erscheinen beim Ziehen
- Begradigen-Slider (−45° bis +45°) dreht das Bild — Zuschnitt und Rotation zusammen in einer Ansicht
- Crop und Rotation sind non-destruktiv: "Anwenden" schreibt die Werte in die bestehende Anpassungs-Pipeline
- Speichern über die untere Inspector-Leiste bakt Crop + Rotation ins Bild ein
- Versions-Label zeigt "Rotation X.Y° · Zugeschnitten" wenn aktiv

---

## 0.21.0
**Versionslabel + Metadaten über untere Leiste speichern**
- Jede gespeicherte Version zeigt jetzt, was geändert wurde (z.B. "Belichtung +1.0 EV · Kontrast 1.20" oder "Metadaten")
- Metadaten-Speichern ist in die untere Inspector-Leiste gewandert — kein separater "Speichern"-Button mehr im Metadaten-Plugin
- "Speichern" in der unteren Leiste speichert Bild-Anpassungen und/oder Metadaten in einem Schritt
- Metadatenänderungen erzeugen ebenfalls einen Versions-Eintrag mit Wiederherstellungsmöglichkeit
- Bei RAW-Dateien: Metadaten können weiterhin gespeichert werden

---

## 0.20.1
**Speichern-Leiste am Inspector-Boden + Undo/Redo**
- "Speichern"-Button und Versions-Link aus dem Anpassungen-Plugin in eine fixe Leiste am unteren Rand des Inspectors verschoben
- Leiste ist immer sichtbar, unabhängig vom aktiven Plugin
- Cmd+Z macht das letzte Speichern rückgängig, Cmd+Shift+Z wiederholt es (Undo/Redo-Stack)

---

## 0.20.0
**Anpassungen speichern & Versionshistorie**
- "Speichern"-Button im Anpassungen-Plugin schreibt bearbeitetes Bild ins Original zurück (JPEG/PNG/TIFF)
- Vor jedem Speichern wird automatisch ein Backup der Vorgängerversion angelegt
- Versionshistorie zeigt alle gespeicherten Versionen mit Datum, Uhrzeit und Vorschau
- "Wiederherstellen" setzt das Bild auf eine beliebige frühere Version zurück (sichert vorher den aktuellen Stand)
- Einzelne Versionen können gelöscht werden
- RAW-Dateien werden nicht überschrieben (Hinweis im Panel)

---

## 0.19.3
**Analyse-Werkzeuge als Blöcke mit Drag & Drop**
- Histogramm, Waveform, RGB-Parade und Kurven werden jetzt als übereinandergestapelte Blöcke angezeigt statt als Tabs
- Reihenfolge per Drag & Drop am Header-Griff verschiebbar
- Jeder Block einzeln ein-/ausklappbar

---

## 0.19.2
**RGB-Parade passt jetzt in die Inspector-Breite**
- Fix: Parade-Ausgabe war 3× zu breit — R/G/B-Kanäle werden jetzt auf je 1/3 der Gesamtbreite komprimiert

---

## 0.19.1
**Inspector: Plugins als scrollbare Blöcke mit Drag & Drop**
- Alle aktiven Plugins werden jetzt als vertikale Blöcke übereinander angezeigt statt als Tabs
- Jeder Block hat einen Header zum Ein-/Ausklappen (Chevron-Button)
- Reihenfolge per Drag & Drop am Header-Griff verschiebbar (Reihenfolge wird gespeichert)
- Inspector-Bereich ist scrollbar wenn Inhalte die Fensterhöhe überschreiten

---

## 0.19.0
**Analysewerkzeuge Plugin: Histogramm, Waveform, RGB-Parade & Gradationskurven**
- Neues Plugin "Analyse" in der rechten Sidebar (Plugins-Menü → Analyse)
- Histogramm: R/G/B- und Luma-Verteilung als Screen-Blend überlagert
- Waveform: Luma-Dichte-Scope zur Helligkeitskontrolle
- RGB-Parade: R/G/B-Kanäle nebeneinander für Farbbalance-Analyse
- Gradationskurve: 5 verschiebbare Kontrollpunkte mit monotoner kubischer Spline-Interpolation
- S-Kurve-Preset für filmischen Look, Zurücksetzen-Button
- Kurve greift in die CIImage-Pipeline ein (CIToneCurve) — non-destructiv

---

## 0.18.0
**Photo-Editor Plugin mit Live-Anpassungen**
- Neues Plugin "Anpassungen" in der rechten Sidebar (Plugins-Menü → Anpassungen)
- Regler für Belichtung (EV), Helligkeit, Kontrast, Sättigung und Farbwärme
- Live-Vorschau via CoreImage-Filter-Pipeline ohne Originaldatei zu verändern
- Regler werden beim Bildwechsel automatisch zurückgesetzt

---

## 0.17.5
**Album-Crash beim Öffnen behoben**
- Fix: selectAlbum setzt navSelection sofort, verschiebt Import + Bildladen in nächsten Run-Loop-Zyklus (DispatchQueue.main.async)
- Verhindert Cascade von objectWillChange-Events die auf macOS 11 den HIMenuBarView-Crash auslösten

---

## 0.17.4
**Crash beim Öffnen persistierter Alben behoben**
- Fix: Album-Fotos werden jetzt vor dem Navigationswechsel importiert (kein ungültiger Zustand mehr)
- Fix: selectedIndices wird beim Wechsel der Ansicht zurückgesetzt (verhindert Out-of-Bounds-Crash)
- Fix: Bounds-Check im Drag & Drop Handler der Album-Sidebar

---

## 0.17.3
**Tastaturkürzel in Ordner- und Album-Ansicht korrigiert**
- Fix: Cmd+A, Cmd-Klick, Shift-Klick funktionieren jetzt auch in Ordner- und Album-Ansicht

---

## 0.17.2
**Löschen in Ordner-Ansicht mit Bestätigung**
- Cmd+Delete in der Ordner-Ansicht zeigt Warndialog: Originaldateien werden in den Papierkorb verschoben
- Thumbnails im unteren Strip etwas kleiner (148×99) für bessere Passform

---

## 0.17.1 — in 0.17.2 zusammengefasst

---

## 0.17.0
**Ordner-Support mit automatischer Synchronisierung**
- Ordner über "+" in der Sidebar hinzufügen — alle Bilder darin werden automatisch importiert
- Ordner werden live überwacht: neue Bilder erscheinen automatisch, gelöschte verschwinden
- Ordner sind eine eigene Kategorie (kein Album) — Änderungen von außen werden reflektiert
- Rechtsklick auf Ordner in der Sidebar zum Entfernen

---

## 0.16.2
**"Über iPhoto"-Panel mit Versionsnummer**
- Menüeintrag "Über iPhoto" zeigt Version, Copyright und App-Info an

---

## 0.16.1
**Shift-Klick Bereichsauswahl im Album-Modus korrigiert**
- Fix: Shift-Klick wählt nun nur sichtbare Album-Fotos im Bereich aus, keine Library-Fotos dazwischen

---

## 0.16.0
**Cmd+Delete entfernt markierte Fotos**
- In der Library-Ansicht: markierte Fotos aus der Sammlung entfernen
- In der Album-Ansicht: markierte Fotos aus dem Album entfernen (bleiben in der Library)

---

## 0.15.1
**Cmd/Shift-Klick Erkennung korrigiert**
- Fix: Modifier-Flags werden bei mouseDown gecaptured statt bei onTapGesture, um Timing-Probleme zu beheben

---

## 0.15.0
**Erweiterte Tastaturauswahl**
- Cmd+Klick: einzelnes Foto zur Auswahl hinzufügen oder entfernen
- Shift+Klick: alle Fotos zwischen zwei Positionen auswählen

---

## 0.14.1
**Drag & Drop Mehrfachauswahl korrigiert**
- Fix: Drag & Drop auf ein Album fügt jetzt alle markierten Fotos hinzu, nicht nur das gezogene

---

## 0.14.0
**Mehrfachauswahl mit Cmd+A**
- Cmd+A markiert alle sichtbaren Fotos auf einmal
- Rechtsklick-Menü zeigt "Alle (N) zu Album hinzufügen" bei Mehrfachauswahl

---

## 0.13.0 – 0.13.3
**Album-Drag & Drop + Stabilitätsfixes**
- Fotos per Drag & Drop auf ein Album in der Sidebar ziehen
- Album-Fotos werden nach Neustart wieder geladen
- Sidebar-Navigation auf custom Buttons umgestellt (Auswahl-Bug behoben)
- Fix: Erstes Foto wird beim Öffnen eines Albums automatisch geladen
- Fix: Security-Scoped Bookmarks für Dateizugriff nach Neustart (Sandbox-Kompatibilität)

---

## 0.12.0
**Album-Verwaltung**
- Alben erstellen, umbenennen und löschen in der linken Sidebar
- Fotos per Rechtsklick einem Album zuweisen oder entfernen

---

## 0.11.0 – 0.11.13
**Library-Grid & Thumbnail-Optimierungen**
- Neuer horizontaler Thumbnail-Strip mit fixer Zellgröße (168×113 px)
- Automatisches Scrollen zur aktuellen Auswahl
- Zahlreiche Größen- und Layout-Korrekturen am Thumbnail-Strip

---

## 0.10.0
**Navigations-Sidebar (links)**
- Neue linke Sidebar mit Mediathek-Eintrag und Album-Liste

---

## 0.9.0
**Plugin-Menü**
- Neuer Menüleisten-Eintrag für zukünftige Plugin-Erweiterungen

---

## 0.8.0
**File-Logger**
- Persistentes Logging in Datei für Crash-Diagnose

---

## 0.7.0 – 0.7.2
**Inspector-Sidebar & Metadaten**
- Rechte Sidebar mit Metadaten-Panel (EXIF, IPTC etc.)
- Fix: Crash im MetadataPanel beim Bildladen
- Fix: LazyVStack-Kompatibilität mit macOS 11

---

## 0.6.0 – 0.6.1
**Zuverlässiges Pinch-to-Zoom**
- NSMagnificationGestureRecognizer für stabiles Trackpad-Zoomen
- Fix: Konfliktierende Gesture Recognizer entfernt

---

## 0.5.0
**Vollständiger Trackpad-Support**
- Pinch-to-Zoom, Two-Finger-Scroll, Smart Zoom (Doppeltipp)

---

## 0.4.0 – 0.4.6
**Performance & Stabilität**
- Bild-Cache, Prefetch der Nachbarbilder, schnellere Thumbnails
- Fix: Thumbnail-Ladeprobleme (RAF/PNG)
- Fix: Erstes importiertes Bild wird automatisch ausgewählt und geladen

---

## 0.3.0 – 0.3.2
**Auto-Zentrierung & Mausrad-Zoom**
- Bild wird beim Laden automatisch eingepasst (Fit to Window)
- Mausrad-Zoom
- Fix: Bild-Drift beim Zoomen behoben

---

## 0.2.0
**Horizontaler Thumbnail-Strip**
- Thumbnail-Leiste unten statt Raster-Ansicht

---

## 0.1.0
**Erstveröffentlichung**
- RAW- und JPEG-Bildanzeige mit EXIF-Orientierung
- Zoom, Pan, Tastaturnavigation (Pfeiltasten)
- Import via Datei-Dialog und Drag & Drop
- Export als JPEG, PNG, TIFF, HEIF
