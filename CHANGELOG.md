# iPhoto – Release Notes

---

## 1.47.2
**Feature — Thumbnail-Leiste skaliert mit Höhe, Minimum = 138 px**

- Thumbnails wachsen proportional mit der Leistenhöhe (GeometryReader, kein Parameter-Passing)
- Mindesthöhe ist 138 px (Standard) — kleiner ziehen nicht möglich

---

## 1.47.1
**Bugfix — Cover-Foto als einziges Hauptbild**

- Wenn ein Cover-Foto für ein Album gesetzt ist, wird nur dieses Bild angezeigt (kein 4-Bild-Mosaik mehr) — gilt für AlbumBannerView und AlbumGridCell

---

## 1.47.0
**Feature — Suchergebnis-Zusammenfassung wie Google**

- Nach einer gefilterten Suche erscheint unterhalb der Filter-Chips: „X Bilder in 0,03 Sek."
- Zeigt sich nur wenn aktive Filter vorhanden sind; verschwindet beim Leeren der Suche

---

## 1.46.2
**Bugfix — Thumbnail-Skalierung rückgängig, nur Drag-Richtung korrigiert**

- Thumbnail-Breite wieder fest auf 156 px (Skalierung hatte Drag blockiert)
- Drag-Richtung bleibt korrigiert: runter = größer, hoch = kleiner

---

## 1.46.1
**Bugfix — Drag-Richtung korrigiert + Thumbnails skalieren mit Leistenhöhe**

- Drag nach unten vergrößert die Leiste (war invertiert)
- Thumbnail-Breite skaliert proportional zur Leistenhöhe — mehr Platz = größere Vorschaubilder

---

## 1.46.0
**Feature — Galerieansicht: Thumbnail-Leiste vertikal verschiebbar**

- Die untere Thumbnail-Leiste in der Galerieansicht lässt sich per Drag am Trennbalken nach oben/unten ziehen (80–600 px)
- Höhe wird persistent gespeichert (`gallery.stripHeight`)
- Trennbalken färbt sich beim Hovern blau (wie Seitenleisten-Divider)

---

## 1.45.3
**Bugfix — Album-Banner in allen drei Ansichten fest verankert**

- Symbole (Grid), Liste und Spalten: AlbumBannerView erscheint jetzt als fixes Element oberhalb des scrollbaren Inhalts, scrollt nicht mehr mit

---

## 1.45.2
**Bugfix — Album-Banner auch in der Spaltenansicht (LibraryColumnsView)**

- AlbumBannerView wird nun auch in der Spaltenansicht (HSplitView-Modus) als festes Element oberhalb des Split-Bereichs gerendert

---

## 1.45.1
**Bugfix — Album-Banner in Listenansicht oberhalb der Spalten-Header**

- AlbumBannerView wird nun als festes Element vor dem Spalten-Header (`Name / Datum / Größe / Art / ...`) gerendert, nicht mehr als Teil des scrollbaren Inhalts

---

## 1.45.0
**Feature — Panel-Toggle-Gruppe + einklappbare Metadaten-Sektionen**

- Toolbar: `sidebar.left` + `sidebar.right` als visuell gruppierten Button-Cluster (Xcode-Stil) mit geteiltem Hintergrund und Rahmen
- Metadaten-Inspector: Sektionen „Kamera" und „Qualität" sind per Klick auf den Header ein- und ausklappbar (Chevron-Indikator)

---

## 1.44.5
**Bugfix — Ladebalken und Log auch im Symbole-Modus sichtbar**

- AlbumGridExpandedView zeigt jetzt denselben Footer wie NavSidebarView: Ladebalken, Abschluss-Zusammenfassung und Log/Konsole-Tabs

---

## 1.44.4
**Bugfix — Alle 5 Sterne immer in einer Reihe**

- RatingPanel: Sterne bekommen feste 32×32 px Tappfläche, `fixedSize()` verhindert Kompression durch schmalen Inspector
- ThumbnailCell: `fixedSize()` statt `.frame(width:)` — keine Kompression bei kleinen Thumbnails

---

## 1.44.3
**Feature + Bugfix — Panel-Toggles im Toolbar + breitere Seitenleiste**

- Linke und rechte Seitenleiste können jetzt über zwei nebeneinander liegende Buttons (Xcode-Stil) ein-/ausgeblendet werden — beide Buttons links im Toolbar
- Doppelter Sidebar-Toggle in LibraryFullGridView entfernt
- Seitenleiste kann jetzt bis auf Fensterbreite minus 120 px gezogen werden (vorher 250 px Mindestbreite für Hauptinhalt)

---

## 1.44.2
**Bugfix — Cover-Foto des Albums wird korrekt als erstes Bild angezeigt**

- `coverImages` verwendet jetzt `map` statt `compactMap` — Bilder ohne geladenes Thumbnail werden nicht mehr übersprungen und verschieben die Reihenfolge
- Das ausgewählte Cover-Foto bleibt immer an Position 0 des Mosaics, auch wenn sein Thumbnail noch nicht im Cache ist

---

## 1.44.1
**Bugfix + Feature — Library-Zelle mit Vorschau, kein Bildvergleich in Seitenleiste**

- Library wird jetzt wie ein Album mit Foto-Mosaik angezeigt (Liste: kompakter Thumbnail-Row, Symbole: volle Grid-Zelle)
- Bildvergleich aus der Seitenleiste entfernt
- Ansichtsmodus (Liste/Symbole) wird beim Anklicken eines Albums nicht mehr zurückgesetzt — nur der Toggle-Button wechselt den Modus

---

## 1.44.0
**Feature — Einheitliche Seitenleiste mit Listen- und Symbolmodus**

- Seitenleiste zeigt immer Suche + Bibliothek-Sektion + Alben, egal ob Listen- oder Symbole-Modus
- Umschalter: `⊞`-Icon wechselt zu Symbolen, `≡`-Icon zurück zur Liste
- Symbole-Ansicht (AlbumGridExpandedView) hat jetzt Suche und Bibliothek-Einträge (Library, Bildvergleich)
- Seitenleiste ist in beiden Modi per Drag in der Breite anpassbar
- Inspector bleibt in beiden Modi sichtbar
- Album-Banner passt Layout automatisch an: unter 320 px Breite wechselt er zu gestapeltem Layout (Bild oben, Titel darunter)
- Gelöschte Bilder werden sofort aus allen Album-Referenzen entfernt

---

## 1.43.2
**Bugfix — Album-Panel Resize sofort sichtbar**

- Live-Breite per `@State` getrennt von `@AppStorage` — Panel aktualisiert sich jetzt sofort beim Ziehen
- Breite wird erst beim Loslassen persistiert (kein UserDefaults-Lag mehr)

---

## 1.43.1
**Feature — Album-Panel resizable + Banner-Aktionen**

- Album-Panel (expandierte Seitenleiste) ist per Drag frei in der Breite verschiebbar
- Breite wird gespeichert und beim nächsten Start wiederhergestellt
- Zu schmal gezogen → Panel schließt automatisch
- Banner: Titel direkt anklicken zum Inline-Bearbeiten
- Banner: „…"-Menü für Informationen / Bearbeiten / Löschen
- Resizable Divider hebt sich blau hervor und zeigt Resize-Cursor

---

## 1.43.0
**Feature — Listenansicht & Album-Banner überarbeitet**

- Listenansicht: Qualitätsbadges (Unscharf, Unter-/Überbelichtet, Augen, Stapel, Anpassungen, HDR) in der Markierung-Spalte
- Listenansicht: abwechselnde Graustufen für Zeilen wie in iTunes
- Album-Banner jetzt auch in der Rasteransicht (scrollbar als erster Eintrag)
- Album-Banner in der Listenansicht scrollt mit den Einträgen mit

---

## 1.42.3
**Bugfix — Ansichtsmodi im Album-Kontext**

- Toolbar zeigt das Ansichtsmenü (Raster / Liste / Spalten / Galerie) jetzt auch wenn ein Album oder iAlbum geöffnet ist
- Der gewählte Modus gilt global — wechselt man zurück zur Bibliothek bleibt er erhalten

---

## 1.42.2
**Perf — iAlbum-Filterung via SQL**

- iAlbum-Filterung nutzt jetzt SQLite statt In-Memory-Loop über alle Dokumente
- Sidebar-Zähler ebenfalls per SQL (`COUNT(DISTINCT path)`) — kein O(n × m)-Scan mehr
- Fallback auf In-Memory bleibt für Kriterien die Runtime-Daten brauchen (Farbanteil, iAlbum-Referenz)
- `SmartFolderSQLGenerator` in CLI-Build aufgenommen

---

## 1.42.1
**Feature — Album-Banner + Ansichtsmodi im Album-Kontext**

- Beim Öffnen eines Albums oder iAlbums erscheint oben ein Banner mit Mosaik, Name und Fotoanzahl
- Ansichtsmodi (Raster, Liste, Spalten, Galerie) funktionieren jetzt auch im Album-Kontext
- Beschreibung aus den Album-Details wird im Banner angezeigt

---

## 1.42.0
**Feature — Album-Detailansicht & iAlbum-Kontextmenü**

- Rechtsklick auf Album im Raster → „Informationen…" öffnet Detail-Sheet (iTunes-Stil)
  - Tab „Details": Name und Beschreibung bearbeiten, Fotoanzahl
  - Tab „Cover": Titelbild aus Album-Fotos auswählen
- Rechtsklick auf iAlbum → „iAlbum bearbeiten…" öffnet Kriterien-Editor, „iAlbum löschen"
- Neues Feld `albumDescription` im Album-Modell (rückwärtskompatibel)

---

## 1.41.2
**Feature — ELO-Suchoperatoren**

- Suche unterstützt jetzt `elo:>=1600`, `elo:<=1800`, `elo:>1500`, `elo:<2000`
- Vorschläge in der Suchleiste zeigen Beispiele für alle Operatoren

---

## 1.41.1
**Bugfix — iAlben-Mosaik-Thumbnails**

- iAlben im erweiterten Albumraster zeigen jetzt Foto-Mosaike statt Platzhalter-Icons

---

## 1.41.0
**Feature — iAlbum, Nicht-in-Album-Filter, Album-Eigenschaften**

- Intelligente Ordner heißen jetzt **iAlbum** / iAlben in der gesamten UI
- Neues SmartFolder-Kriterium „Nicht in Album": findet Fotos die keinem Album zugeordnet sind
- Albumraster: Rechtsklick → Umbenennen / Titelbild festlegen / Löschen
- Album-Titelbild: beliebiges Foto aus dem Album als Cover festlegbar

---

## 1.40.0
**Feature — Inspector erweiterbar (rechte Seite)**

- Inspector-Header zeigt Expand-Button (↗) analog zum Sidebar-Expand links
- Beim Expandieren nimmt der Inspector die volle Breite ein — eine Bildspalte bleibt links sichtbar
- Collapse-Button (↙) verkleinert den Inspector zurück auf normale Breite (280 px)

---

## 1.39.2
**Bugfix — Album-Mosaik zeigt Thumbnails für alle Alben**

- `CGImageSourceCreateThumbnailAtIndex` ist auf macOS 11 nicht thread-safe → hat für die meisten Alben lautlos versagt
- Album-Cover nutzen jetzt die bereits geladenen Thumbnails aus dem Collection-Cache via `requestVisibleThumbnail` — kein direkter Disk-Zugriff auf Background-Thread mehr

---

## 1.39.1
**Bugfix — SmartFolder Farbanteil: Eingabefeld statt Stepper**

- Prozentwert-Eingabe bei „Farbanteil (%)" nutzt jetzt ein Textfeld (wie ISO, ELO, mm) statt eines unsichtbaren Steppers — Wert ist klar sichtbar und editierbar

---

## 1.39.0
**Feature — Thumbnail-Symbol-Verwaltung + SmartFolder-Layout-Fix**

- Einstellungen → Thumbnails (neuer Tab): jedes Badge einzeln ein-/ausblendbar (Sterne, Farblabel, Markierung, Unscharf, Belichtung, Augen, Stapel-Krone, Bearbeitungen, HDR)
- SmartFolder „Farbanteil (%)": Reihenfolge korrigiert — Prozentwert erscheint jetzt vor dem Kanal-Picker statt dahinter

---

## 1.38.1
**Bugfix — Seitenleisten-Expand im richtigen Modus**

- Der schmale Bild-Streifen beim Expand zeigt jetzt immer die Rasteransicht (eine Spalte), egal welcher Darstellungsmodus aktiv ist — Liste/Spalten/Galerie hätten dort keinen Platz

---

## 1.38.0
**Feature — Einheitliche Toolbar-Liste + Seitenleiste halb-expandierbar**

- Einstellungen → Toolbar: Navigationsleiste und Toolbar-Buttons jetzt in einer einzigen Drag-and-Drop-Liste zusammengeführt
- Alle 14 Toolbar-Elemente (6 Nav + 8 Aktions-Buttons) per Drag neuordnen und einzeln ein-/ausblenden
- Expand-Button in der Seitenleiste zeigt jetzt Album-Raster auf erweiterter Breite — eine Bildspalte bleibt rechts sichtbar (kein Vollbild mehr)

---

## 1.37.0
**Feature — Toolbar in nativer Leiste, Album-Mosaik, Seitenleiste konfigurierbar**

- Toolbar-Buttons (Sort, Auge, Drehen, Zoom) sind jetzt Teil der nativen macOS-Titelleiste — keine zweite Zeile mehr
- Einstellungen → Toolbar: Drag-and-Drop-Liste zum Neuordnen und Ein-/Ausblenden einzelner Buttons
- Album-Vollbild: Jedes Album zeigt jetzt ein 2×2-Mosaik aus den ersten 4 Fotos (Apple-Photos-Stil)
- Einstellungen → Seitenleiste: Neue Tab zum Ein-/Ausblenden einzelner Seitenleisten-Bereiche (Bibliothek, Alben, Intelligente Ordner, Wechseldatenträger, Papierkorb, Duplikate, Qualität)
- SmartFolderSQLGenerator: Grundlage für SQL-basierte Intelligente Ordner (Playlists-Feature, folgt)

---

## 1.36.0
**Feature — Discord-Suche, Album-Vollbild, Geeks-Konsole**

- Suche unterstützt jetzt Filter wie Discord: `bewertung:5`, `typ:raw`, `vor:2024`, `nach:2023`, `kamera:canon`, `album:urlaub`, `markiert:pick`, `unscharf:ja`, `motiv:hund`, `elo:1700`, `farbe:rot` — kombinierbar mit freiem Text
- Dropdown zeigt verfügbare Filter mit Icon + Hinweistext; nach `key:` erscheinen Wertvorschläge aus echten Daten (Alben, Kameramodelle, Motive)
- Aktive Filter werden als entfernbare Chips unterhalb des Suchfelds angezeigt
- Vollbild-Symbol in der Seitenleiste: klappt die Alben als Symbolraster auf und nimmt dabei Seitenleiste + Mittelbereich ein; Klick auf ein Album navigiert direkt dorthin
- Geeks-Konsole: zweiter Tab neben „Log" — Befehle wie `viewmode get`, `catalog stats` etc. direkt in der App eingeben; Ausgabe erscheint farbkodiert; iphoto-cli wird automatisch neben der .app gesucht

---

## 1.35.1
**Bugfix — Suche aktualisiert Bildliste**

- Sucheingabe hat die sichtbare Bildliste nicht aktualisiert, da der visibleDocuments-Cache nie invalidiert wurde — behoben

---

## 1.35.0
**Feature — Toolbar-Jiggle, Suche, Werkzeuge-Panel + „Für Geeks"-Log**

- Toolbar-Buttons (Sort, Auge, Drehen, Zoom) wackeln jetzt im iPhone-Stil bei langem Druck; Reihenfolge per Drag-and-Drop veränderbar; „Fertig" oder Escape beendet den Modus
- Suchfeld oben in der Seitenleiste: Suche nach Dateinamen und Metadaten-Werten mit Autocomplete-Vorschlägen (min. 2 Zeichen, bis zu 8 Treffer)
- Neues Inspector-Plugin „Werkzeuge" (Photoshop-Stil): 2-spaltiges Tool-Raster mit Bewegen, Zuschneiden, Zoom, Drehen, Inpaint und lokalem Pinsel; per Einstellungen → Funktionen aktivierbar
- Einstellung „Für Geeks": aktiviert einen ausklappbaren Live-Log-Bereich am unteren Rand der Seitenleiste — zeigt die letzten 50 Log-Zeilen mit Farb-Kodierung (PERF = grün, WARN = orange, ERROR = rot), aktualisiert sich alle 1,5 s automatisch
- `SortMenuButton` in der Toolbar wird nicht mehr zu breit gerendert (`.fixedSize()`)

---

## 1.34.0
**Feature — Finder-Listenansicht + Jiggle-Fix**

- Listenansicht (Als Liste) jetzt mit Finder-ähnlichem Spalten-Header: Name (↑↓), Datum (↑↓), Größe, Art, Bewertung, Markierung
- Rechtsklick auf den Header blendet Spalten ein/aus; Auswahl wird in UserDefaults gespeichert
- Klick auf sortierbare Spalten-Header toggelt Sortierrichtung mit Pfeilindikator
- Bugfix: Jiggle-Modus konnte bei Abschnitts-Headern mit Button (Alben, Intelligente Ordner) nicht durch Langer-Druck ausgelöst werden — `.simultaneousGesture` statt `.onLongPressGesture` behebt das

---

## 1.33.0
**Feature — Jiggle-Reorder für Nav-Sektionen + persistente PERF-Metriken**

- Lange auf einen Abschnitts-Header in der Seitenleiste drücken → Wackel-Modus: alle Sektionen oszillieren ±2° (iPhone-Stil); per Drag-and-Drop neu anordnen; „Fertig" oder Escape beendet den Modus und speichert die Reihenfolge dauerhaft
- `Log.perf()` hinzugefügt; alle Performance-relevanten Operationen werden jetzt als `PERF`-Zeilen ins Log geschrieben: `THUMBNAILS N Bilder X ms`, `SCAN EXIF N Bilder X ms`, `SCAN QUALITY N Bilder X ms`, `IMPORT N Dateien X ms`, `EXPORT N Dateien X ms`
- Log-Rotationsgrenze von 2 MB auf 10 MB erhöht, damit Langzeit-Metriken nicht vorzeitig verloren gehen

---

## 1.32.0
**Feature — Ansichts-Wechsler (Als Symbole / Als Liste / Als Spalten / Als Galerie)**

- Neues `LibraryViewMode`-Enum (`grid`, `list`, `columns`, `gallery`) mit Persistenz in UserDefaults (`library.viewMode`)
- Toolbar zeigt im Bibliothek-Modus ein Menü mit allen vier Ansichten; aktive Ansicht wird per Häkchen markiert
- „Als Symbole" (`square.grid.2x2`): bestehende `LibraryFullGridView`
- „Als Liste" (`list.bullet`): neue `LibraryListView` — kompakte Tabellenzeilen mit Thumbnail, Dateiname, Bewertung und Flag
- „Als Spalten" (`rectangle.split.2x1.fill`): neue `LibraryColumnsView` — schmale Thumbnail-Liste links, Detailansicht rechts (HSplitView)
- „Als Galerie" (`photo`): bestehende Detail- + Filmstreifen-Ansicht
- `iphoto-cli viewmode get` und `iphoto-cli viewmode set <modus>` zum Lesen/Setzen der Ansicht
- `Tests/run_plugins.sh` um drei viewmode-CLI-Tests erweitert

---

## 1.31.0
**Feature — SmartFolder Farbanteil-Filter + Panel-Bug behoben + Toolbar-Trenner entfernt**

- Neues SmartFolder-Kriterium „Farbanteil (%)" (R/G/B-Kanal): filtert Bilder nach dem durchschnittlichen Anteil eines Farbkanals (Operatoren: größer als, kleiner als, im Bereich)
- Bugfix: `Plugin.Codable` nutzte Swift-Standardwerte nicht für fehlende JSON-Felder — alle Panels wurden lautlos verworfen, sodass der Inspector immer „Kein Panel aktiv" zeigte; eigener `init(from decoder:)` mit `decodeIfPresent` behebt das
- Bugfix: Zwei getrennte `ToolbarItemGroup(placement: .automatic)` erzeugten einen überzähligen Trenner in der Toolbar; zu einer Gruppe zusammengeführt

---

## 1.30.0
**Feature — Bildvergleich als Plugin + iphoto-cli plugins-Befehl + PluginStore-Initialisierung repariert**

- `PluginStore.init()` lädt Plugins jetzt synchron, sodass `InspectorView` beim ersten Rendern nie mehr „Kein Panel aktiv" zeigt
- Bildvergleich als eingebautes Plugin `com.iphoto.builtin.compare` (order: 0) hinzugefügt — mit eigenem `ComparePanel` im Inspector
- `NavSidebarView` und `ModeSwitcherView` prüfen die Bildvergleich-Anzeige jetzt über `PluginStore.isEnabled(...)` statt `viewModel.compareFeatureEnabled`
- `iphoto-cli plugins list [--json]` zeigt alle installierten Plugins/Panels
- `iphoto-cli plugins dir` gibt den Plugin-Ordner-Pfad aus
- `Tests/run_plugins.sh` um drei neue CLI-Tests für den `plugins`-Befehl erweitert

---

## 1.29.1
**Bugfix — Builtin-Panel-Dateien immer sichtbar**

- `builtin-*.json`-Dateien werden bei jedem App-Start in den Plugin-Ordner geschrieben (nicht mehr nur beim ersten Start), sodass sie sofort im Finder sichtbar sind

---

## 1.29.0
**Feature — Eingebaute Panels als Dateien im Plugin-Ordner**

- Alle neun eingebauten Inspector-Panels (Bewertung, Metadaten, Anpassungen, Lokal, Rezepte, Analyse, Navigation, Hotpixel, Inpaint) werden beim ersten Start als `builtin-*.json`-Dateien in `~/Library/Application Support/iPhoto/Plugins/` angelegt
- Externes Plugin-System und eingebaute Panels sind jetzt vollständig vereint — ein einziger `PluginStore` verwaltet beides
- Panels können in den JSON-Dateien umbenannt, umsortiert oder deaktiviert werden ohne Neucompilierung
- `PanelStore` / `PanelDescriptor` entfernt; `Resources/Panels/` entfernt
- Menü heißt jetzt „Panels" und zeigt alle Einträge dynamisch aus der Dateiliste

---

## 1.28.0
**Feature — Dateibasierte Inspector-Panels**

- Eingebaute Inspector-Panels (Bewertung, Metadaten, Anpassungen, Lokal, Rezepte, Analyse, Navigation, Hotpixel, Inpaint) sind jetzt als JSON-Dateien in `Resources/Panels/` definiert
- `PanelStore` lädt Panel-Metadaten (Name, Icon, Standard-Aktivierung, Reihenfolge) dynamisch aus dem App-Bundle
- Reihenfolge, Aktivierung und Einklapp-Zustand bleiben wie bisher per UserDefaults erhalten; bestehende Einstellungen bleiben durch identische Storage-Keys kompatibel
- Menü „Panels" zeigt die Panels direkt aus der Dateiliste — keine hardcodierten Einträge mehr im Swift-Code

---

## 1.27.5
**Feature — Änderungs-Badge auf Thumbnails**

- Bilder mit gespeicherten Anpassungen zeigen ein lila △-Badge oben rechts auf dem Thumbnail
- Flag wird beim Startup aus der Datenbank geladen (eine SQL-Abfrage für alle Bilder) und live aktualisiert wenn Anpassungen gespeichert oder zurückgesetzt werden

---

## 1.27.4
**Bugfix/Chore — Build-Bereinigung**

- Redundante Archive-Implementierung entfernt (Funktion existierte bereits als „Als JPEG sichern" im Kontextmenü)

---

## 1.27.3
**Feature — Histogramme im Bildvergleich einklappbar**

- Histogramm-Panels im Bildvergleich (links/rechts oben) lassen sich per Chevron-Button einzeln ein- und ausklappen

---

## 1.27.2
**Feature — Archiv-Funktion + Plugin-System + Papierkorb-Speicheranzeige**

- Plugin-System: JSON-Dateien in `~/Library/Application Support/iPhoto/Plugins/` werden automatisch als Inspector-Panels geladen — mit Shell-Befehlen pro Zeile und Action-Buttons
- Menü „Plugins" → „Externe Plugins neu laden" (⌘⌥R) und „Plugin-Ordner öffnen" hinzugefügt
- Papierkorb: Speicheranzeige am unteren Rand zeigt, wie viel Speicher beim Leeren freigegeben würde

---

## 1.27.1
**Feature — ELO-Score im Metadaten-Panel**

- ELO-Wert und Anzahl der Duelle werden im Inspector unter „Qualität" angezeigt (nur bei Bildern mit mindestens einem Duell)

---

## 1.27.0
**Feature — Kachel-Ansichtswähler (Metro-Stil) + ELO Champions + Graph einklappen**

- Neuer Kachel-Modus (⌘M): Windows-8-artiges Vollbild-Overlay zeigt alle Ansichten als farbige Kacheln — Bibliothek, ELO Champions, Bildvergleich, Duplikate, Ähnliche Bilder, Qualitätsmodi, Papierkorb
- Neuer Tab „ELO Champions" in der Sidebar: zeigt die 10 besten und 10 schlechtesten Bilder nach ELO-Score als horizontale Bildleiste mit Medaillen-Badge
- ELO-Verteilungsgraph im Bildvergleich lässt sich per Chevron-Button ein- und ausklappen

---

## 1.26.2
**Feature — Sortierung nach ELO-Score**

- Neue Sortieroptionen im Sortier-Menü: „ELO ↓" (beste zuerst) und „ELO ↑" (schwächste zuerst)
- Sekundärsortierung nach Dateiname für stabile Reihenfolge bei gleichem ELO

---

## 1.26.1
**Bugfix — SIGILL-Diagnose im Bildvergleichs-Modus verbessert (Bug #36)**

- Main-Thread-Breadcrumbs in `resolveCompare`, `applyEloUpdate` und `nextComparePair` — zukünftige Crashes zeigen korrekten `[SIGNAL_LAST_OP]` statt veralteten BG-Decode-Wert
- Defensive Bounds-Check in `applyEloUpdate` vor Subscript-Zugriff

---

## 1.26.0
**Feature — Tägliches Duell-Limit + ELO-Konvergenz-Anzeige**

- Neues konfigurierbares Tageslimit für Bildvergleiche (Standard: 50 Duelle/Tag, 0 = unbegrenzt)
- Limit und heutiger Fortschritt einstellbar unter Einstellungen → Funktionen → Tageslimit
- Verbleibende Duelle werden im Vergleichs-Header angezeigt (rot wenn aufgebraucht)
- Einstellungen → Funktionen: neuer ELO-Konvergenz-Balken zeigt wie stabil das Ranking ist (Ziel: 20 Duelle/Bild ≈ 100 %)

---

## 1.25.3
**Bugfix — Regression SIGSEGV/SIGILL durch @Published in SwiftUI-Render-Pfad behoben**

- `bestInStackIDs` war fälschlicherweise `@Published` — `applyStacking()` wurde von `visibleDocuments` direkt aus einem SwiftUI `body` aufgerufen, dabei feuerte `objectWillChange` mitten im Render → "Modifying state during view update" → SIGSEGV/SIGILL bei jeder Navigation nach längerem Gebrauch
- Fix: `@Published` entfernt; der Wert wird in `applyStacking()` vor dem Return gesetzt, die View liest ihn im selben Render-Zyklus korrekt

---

## 1.25.2
**Feature — Verwerfen-Button in Anpassungen**

- Neuer "Verwerfen"-Button neben "Zurücksetzen": setzt alle Anpassungen auf den zuletzt gespeicherten Stand zurück (nicht auf neutral), deaktiviert wenn keine ungespeicherten Änderungen vorhanden

---

## 1.25.1
**Bugfix — SIGSEGV-Crash bei Bildnavigation behoben**

- `bestInStackIDs` war eine computed property die pro SwiftUI-Grid-Zelle ein `Dictionary` über alle 2000+ Dokumente neu aufbaute (O(N) pro Zelle, O(N²) pro Render-Frame) — das führte unter Speicherdruck zu SIGSEGV auf dem Main-Thread beim Bildwechsel
- Jetzt cached `@Published var bestInStackIDs` — wird einmalig in `applyStacking()` berechnet und nur bei Stapel-Erkennung aktualisiert

---

## 1.25.0
**Feature — CLI-Support für alle Plugins + Plugin-Testsuite**

- `rating` — Bewertung, Flag und Farblabel lesen/schreiben; `--json` für maschinenlesbare Ausgabe
- `adjust` — Bildanpassungen (Belichtung, Helligkeit, Kontrast, Sättigung, Wärme, Lebendigkeit, Farbton, Klarheit, Schärfen) anwenden und exportieren; `--preset <name>` als Basis
- `preset list` — alle Built-in- und Nutzer-Presets auflisten; `preset apply <datei> --name <name>` für direktes Anwenden
- `analyse` — Schärfe (Laplacian-Varianz via Rust) und Belichtung (Schatten-/Lichterclipping) pro Bild oder Ordner; Tabelle oder `--json`
- `inpaint` — KI-Inpainting via CMT; Setup wird vorab validiert und Fehler klar gemeldet wenn Python/CMT nicht installiert
- Neue Testsuite `Tests/run_plugins.sh`: 10 Tests decken alle Plugin-Befehle ab (10/10 grün)
- Bugfix: `analyse`-Tabellenausgabe crashte durch `%s`-Format mit Swift String (SIGSEGV) — auf String-Interpolation umgestellt

---

## 1.24.1
**Bugfix/Feature — Bildvergleich standardmäßig deaktiviert, in Einstellungen aktivierbar**

- Der Bildvergleichs-Modus (ELO-Duell) ist jetzt standardmäßig ausgeblendet
- In „Einstellungen → Funktionen" kann er dauerhaft aktiviert werden (UserDefaults-persistent)
- Deaktivieren beendet einen laufenden Vergleich sofort und blendet den Sidebar-Eintrag aus

---

## 1.24.0
**Feature — Draft-Pipeline, Smart-Folder-Regelbäume & normalisierte Vignette**

- **Sofortiges Hi-Res nach Slider-Loslassen**: Anpassungs-Schieberegler lösen den Hi-Res-Render (1500 px) direkt beim Loslassen aus — nicht erst nach 250 ms Wartezeit
- **Smart-Folder-Regelbäume**: Intelligente Ordner können jetzt andere Intelligente Ordner als Kriterium referenzieren (Attribut „Intelligenter Ordner") — ermöglicht verschachtelte Filter-Hierarchien
- **Zykluserkennung**: Gegenseitige Referenzen zwischen Intelligenten Ordnern werden erkannt und sicher abgebrochen (kein Endlos-Rekursion-Absturz)
- **Vignetten-Radius**: Neuer Schieberegler „Vignetten-Radius" (0,30–1,00, Wert relativ zur Bilddiagonalen) erscheint, sobald eine Vignette aktiv ist — der Radius ist bildgrößenunabhängig gespeichert

---

## 1.23.0
**Feature — OkLab-Farbanpassungen: Lebendigkeit & Farbton via Rust-3D-LUT**

- Zwei neue Schieberegler im Anpassungspanel: „Lebendigkeit" (−1…+1) und „Farbton" (−180°…+180°)
- Basiert auf dem perceptuellen OkLab-Farbraum (Björn Ottosson 2020) für natürliche, artefaktfreie Anpassungen
- Rust generiert eine 32³-Eintrags-3D-LUT (`iphoto_oklab_lut`), die als `CIColorCube`-Filter angewendet wird
- Lebendigkeit erhöht die Sättigung selektiv: ungesättigte Farben werden stärker angehoben als bereits kräftige
- Farbton rotiert den (a,b)-Vektor im OkLab-Raum für gleichmäßige, helligkeitsneutrale Verschiebungen

---

## 1.22.0
**Feature — "Best of Burst": Krone-Badge für das schärfste Bild im Stapel**

- Das schärfste Bild in einem Bracketing-/Burst-Stapel erhält ein gelbes Krone-Badge (`crown.fill`) oben rechts im Thumbnail
- Auswertung basiert auf `blurScore` (Laplacian-Varianz aus `QualityAssessor`): nur gescannte Bilder (`blurScore > 0`) werden berücksichtigt
- Badge erscheint nur, wenn der Stapel ≥2 gescannte Mitglieder hat **und** das beste Bild mindestens 15 % schärfer ist als das zweitbeste (Ratio > 1,15)
- Neues computed property `bestInStackIDs: Set<UUID>` in `ImageViewModel+Context`

---

## 1.21.5
**Feature — ELO-Bereich per Drag auswählen → gefilterter Bilder-View**

- Drag auf der ELO-Kurve im Vergleichsmodus wählt einen ELO-Bereich aus (blaues Highlight + Bereichsgrenzen als Labels)
- Loslassen beendet den Vergleich und öffnet einen gefilterten Grid-View mit nur den Bildern im gewählten ELO-Bereich
- Neues `NavSelection.eloRange(min, max)` als vollwertige Navigation — Sortierung, Stacking, alle Grid-Funktionen funktionieren normal
- Banner am oberen Rand zeigt "ELO 1450–1550 · 23 Bilder" mit ×-Button zum Zurückkehren zur Bibliothek

---

## 1.21.4
**Feature — ELO-Kurve klickbar: Navigiert zum nächsten Bild**

- Klick auf die ELO-Verteilungskurve beendet den Vergleich und wählt das Bild mit dem nächsten ELO-Wert an der Klickposition aus
- Hover-Cursor zeigt eine gestrichelte Linie + ELO-Label beim Überfahren der Kurve
- Zeigefinger-Cursor beim Hover signalisiert Klickbarkeit

---

## 1.21.3
**Feature — ELO-Kurve mit echten Datenpunkten (KDE)**

- ELO-Verteilungsdiagramm zeigt jetzt eine Kernel-Density-Estimation (Gauß-Kernel, Scott's Bandwidth) über alle tatsächlichen ELO-Werte der Bibliothek — statt 6 fixer Buckets eine glatte, datengetreue Dichtefunktion
- X-Achse zeigt den realen ELO-Bereich der Bibliothek mit 6 gleichmäßig verteilten Tick-Labels
- Zwei vertikale Marker (blau = links, orange = rechts) zeigen wo die aktuell verglichenen Bilder im Spektrum liegen, mit Punkt auf der Kurve

---

## 1.21.2
**Bugfix — Bibliothek zeigt nicht alle Bilder**

- Beim App-Start werden jetzt alle im Katalog bekannten Bilder wiederhergestellt, auch solche, die außerhalb überwachter Ordner importiert wurden (z. B. vom Desktop oder Downloads). `restoreCatalogImages()` prüft im Hintergrund, welche Katalog-Pfade noch auf der Festplatte existieren, und fügt fehlende Bilder zur Kollektion hinzu

---

## 1.21.1
**Bugfix — Bibliothek beim App-Start leer**

- Beim Start wurde `loadContentForSelection(.library)` nie aufgerufen, da `$navSelection.dropFirst()` den initialen Wert überspringt — überwachte Ordner wurden erst nach einem manuellen Navigationswechsel geladen. Fix: expliziter Aufruf am Ende von `init()`

---

## 1.21.0
**Feature — Rust-Core unter der Haube (iPhoto 1.2)**

- **Rust-Bibliothek `iphoto_rs`:** Blur-Erkennung (Laplacian-Varianz), Belichtungsanalyse (Histogramm-Clipping), pHash-Paar (dHash bitidentisch zu bisheriger SQLite-Cache-kompatibel) und HotPixel-Akkumulierung/Suche laufen jetzt in Rust via C-FFI
- **rayon-Parallelismus:** HotPixel-Akkumulierung nutzt `par_iter_mut` für schnellere Multi-Frame-Analyse
- **Zweite Build-Variante:** Branch erzeugt `build/iPhoto 1.2.app` (Bundle-ID `com.c0d3cru5h.iPhoto12`) — läuft parallel zu `build/iPhoto.app` auf `main`, teilt dieselbe Datenbank
- **`import Accelerate` entfernt** aus BlurDetector und ExposureDetector — kein Framework-Overhead mehr für diese Berechnungen
- `build.sh` baut automatisch Rust-Core via `cargo build --release` vor Swift-Kompilierung

---

## 1.20.1
**Bugfix — App-Start-Crash nach Motiverkennung-Feature**

- Deadlock behoben: `loadMotifCache()` rief `queue.sync` auf, obwohl `open()` bereits innerhalb von `queue.sync` lief → `dispatch_sync`-Deadlock (SIGILL) beim ersten Start

---

## 1.20.0
**Feature — Automatische Motiverkennung + ELO als Intelligenter-Ordner-Filter**

- **Motiverkennung per KI (VNClassifyImageRequest):** Beim Import analysiert iPhoto jedes Bild automatisch im Hintergrund und erkennt bis zu 8 Motive (Himmel, Natur, Hund, Person, Wasser, Architektur u.v.m.) mit einem Konfidenz-Schwellenwert von 0,25. Ergebnisse werden in SQLite (`motif_tags`, `motif_scanned`) persistiert und gecacht — kein SQLite-Zugriff aus Render-Pfaden
- **Intelligente Ordner: Motiv (KI)** — neues Kriterium „Motiv (KI)" mit Dropdown der bekannten Labels (Himmel, Hund, Strand …) und den Operatoren „ist" / „ist nicht". Matching prüft via `contains()` auf Prefix-Match, sodass spezifischere Labels (z.B. „dog_domestic") auf den Parent-Begriff „dog" treffen
- **Intelligente Ordner: ELO-Rating** — neues numerisches Kriterium „ELO-Rating" mit allen Operatoren (größer als, kleiner als, im Bereich …). Voreinstellung 1500 (ELO-Baseline) beim ersten Öffnen
- SQLite-Migration: neue Spalten `motif_tags TEXT` + `motif_scanned INTEGER` in der `images`-Tabelle, Index auf `motif_scanned`
- Neue Dateien: `Sources/Utilities/MotifAssessor.swift`, `Sources/Utilities/CatalogStore+Motifs.swift`

---

## 1.19.0
**Feature — Bildvergleich mit ELO-Rating (getrennt von Sternen)**

- Der Duell-Modus verändert nicht mehr die Sterne-Bewertung, sondern pflegt einen separaten **ELO-Score pro Bild** (Standard-Baseline 1500). Sterne bleiben manuelle Nutzerbewertung, ELO ist der aus paarweisen Vergleichen errechnete Ranking-Score
- Neues Verdict-Handling: Sieger und Verlierer werden nach Standard-ELO-Formel neu berechnet (K-Faktor mit Decay: 40 für neue Bilder → 16 nach ~30 Duellen, verhindert Zappeln stabilisierter Bilder). „Gleich gut" wertet als 0.5:0.5
- Paar-Auswahl neu: bevorzugt Bilder mit den wenigsten bisherigen Matches (Anchor) und paart sie mit dem nächstgelegenen ELO — statt Blowouts gibt es aussagekräftige Duelle
- CompareView zeigt pro Bild `ELO 1523 · 7 Duelle` statt der Sterne-Zeile. Die Verteilungs-Leiste ist jetzt ein Histogramm über sechs ELO-Buckets (<1300, 1300, 1400, 1500, 1600, 1700+) mit Farbverlauf rot→gelb→grün
- SQLite-Migration: neue Spalten `elo REAL NOT NULL DEFAULT 1500` + `elo_matches INTEGER NOT NULL DEFAULT 0` in der `ratings`-Tabelle plus Index auf `elo`. Bestehende Zeilen starten sauber bei 1500 / 0 Matches
- Persistenz sauber getrennt: neuer `saveElo(path:elo:eloMatches:)` schreibt nur die ELO-Spalten; `saveRating(...)` schreibt weiterhin nur Sterne/Flag/Farb-Label — Sterne-Änderungen setzen ELO nicht zurück und umgekehrt
- `RatingEntry` (JSON-Fallback) tolerant erweitert um `elo`/`eloMatches` mit Default-Werten — bestehende `ratings.json` bleibt kompatibel
- Neue Dateien: `Sources/Utilities/EloRating.swift` (Standard-ELO-Formel). Angepasst: `Sources/Models/ImageDocument.swift`, `Sources/Models/RatingStore.swift`, `Sources/Utilities/CatalogStore.swift`, `Sources/Utilities/CatalogStore+Ratings.swift`, `Sources/ViewModels/ImageViewModel+Compare.swift`, `Sources/ViewModels/ImageViewModel.swift`, `Sources/ViewModels/ImageViewModel+Ratings.swift`, `Sources/ViewModels/ImageLoadingOrchestrator.swift`, `Sources/Views/CompareView.swift`

---

## 1.18.1
**Bugfix — 0★-Spalte in der Vergleichs-Verteilung sichtbar**

- Prozent-Übersicht im Bildvergleich zeigt jetzt alle sechs Bucket-Stufen (0★ bis 5★) statt nur 1★–5★. Die 0★-Spalte war seit Umstellung der Zielkurve in v1.18.0 in der Datenlogik enthalten, wurde aber nicht gezeichnet — Ziel- und Ist-Prozente sind jetzt komplett sichtbar
- Datei: `Sources/Views/CompareView.swift` (`distributionPanel`)

---

## 1.18.0
**Feature — Bildvergleich verteilt jetzt über 0–5 Sterne**

- Ziel-Verteilung im Duell-Modus umgestellt von 1–5 auf **0–5** Sterne: 0★ 5 %, 1★ 15 %, 2★ 30 %, 3★ 30 %, 4★ 15 %, 5★ 5 % (symmetrischer Gauß um 2.5)
- 0★ ist damit eine reguläre Bucket-Stufe der Zielkurve — Verlierer eines Duells können jetzt auch tatsächlich nach 0★ absinken, statt dort nur „geparkt" zu bleiben. Die Paar-Auswahl bevorzugt weiterhin die Sternstufe mit dem größten Überschuss gegenüber der Zielkurve
- Datei: `Sources/ViewModels/ImageViewModel+Compare.swift` (`compareRatingTargets`)

---

## 1.17.0
**Feature — Geschlossene Augen erkennen**

- Neuer Sidebar-Eintrag **„Augen zu"** (pink, Icon `eye.slash.fill`) neben Unschärfe/Über-/Unterbelichtung. Zählt Bilder mit erkannten geschlossenen Augen und öffnet eine dedizierte Übersicht mit Schwellenwert-Slider (0.05–0.35, Default 0.18 EAR)
- Analyse läuft mit dem Rest der Qualitätsprüfung während des Imports (Vision `VNDetectFaceLandmarksRequest` Rev 3): pro Bild wird die kleinste Eye-Aspect-Ratio (EAR) über alle erkannten Gesichter berechnet und in SQLite persistiert. Kein Gesicht ⇒ kein Flag (keine False Positives auf Landschaften/Produktfotos)
- Thumbnails erhalten ein pinkes `eye.slash.fill`-Badge in der oberen rechten Ecke — parallel zu den bestehenden Blur-/Belichtungs-Badges. Metadaten-Inspektor zeigt Status **„Offen (EAR x.xx)"** / **„Augen zu (EAR x.xx)"** / **„Kein Gesicht erkannt"**
- Kontextmenü-Override **„Augen sind offen"** korrigiert Fehlerkennungen und lernt gleichzeitig den Schwellenwert nach (Gewicht 10 %, gedeckelt bei 0.30), wie schon bei Blur/Belichtung. Umgekehrt gibt es „Augen-Override entfernen", sobald ein Bild manuell freigegeben wurde
- SQLite-Migration: neue Spalten `eye_openness REAL` + `eyes_closed_override INTEGER` in `images`. Beim ersten Start nach dem Update wird `quality_scanned=0` gesetzt, damit bestehende Bilder das neue Signal beim nächsten Scan bekommen
- Build linkt jetzt zusätzlich `-framework Vision`. `Tests/run_catalog.sh` compiliert `CatalogStore+Backup.swift` mit (Lücke aus v1.4.0 mitgeschlossen), damit die Test-Suite nach der Schema-Erweiterung wieder durchläuft

---

## 1.16.0
**Feature — Verschachtelte Album-Ordner**

- Neuer Container-Typ `AlbumFolder`: hält Alben (und weitere AlbumFolders) beliebig tief verschachtelt. Alben behalten ihre Fotos, Ordner enthalten selbst keine Fotos — beim Klick auf einen Ordner werden alle Fotos aller enthaltenen Alben rekursiv aggregiert (wie in Fotos.app)
- „+"-Button im Alben-Header hat jetzt ein Popup mit **Neues Album…** und **Neuer Ordner…**. Kontextmenü auf Ordner/Album bietet Umbenennen, „Verschieben nach…" (Root oder beliebiger Zielordner), Löschen
- Drag-and-Drop: Alben und Ordner lassen sich per Drag zwischen Ordnern verschieben oder auf die Root-Zone (Alben-Sektion) fallen; Zyklus-Schutz verhindert, dass ein Ordner in sich selbst oder einen seiner Nachfahren gezogen wird
- Beim Löschen eines Ordners werden enthaltene Alben und Sub-Ordner auf die nächsthöhere Ebene promotet (kein Datenverlust). Bestehende Alben laden ohne Migration weiter — alte JSON-Dateien ohne `parentID` landen automatisch auf Root
- Persistenz: neue `~/Library/Application Support/iPhoto/albumFolders.json`, Alben-JSON um optionales `parentID` erweitert

---

## 1.15.0
**Feature — JPEG-Backup direkt aus dem Kontextmenü**

- Rechtsklick auf ein Bild (Grid, Stapel oder Multi-Selection) hat zwei neue Einträge: **„Als JPEG sichern"** (Original bleibt) und **„Sichern & Original in Papierkorb"** (Original wandert nach erfolgreichem Backup in den iPhoto-Papierkorb, ist dort wiederherstellbar). Beide Aktionen wirken auf alle Mitglieder eines eingeklappten Stapels und auf die komplette Mehrfachauswahl
- Backups landen in `~/Pictures/iPhoto/Backups/<Jahr>/<Monat>/` (Aufnahmedatum aus EXIF, Fallback: Dateidatum). Zielordner ist im Settings-Reiter **Backup** frei wählbar (Security-Scoped-Bookmark bleibt über App-Restarts erhalten)
- Konfigurierbar in Settings: JPEG-Qualität (50–100 %, Default 85 %), EXIF/GPS-Kopie an/aus, optionaler Long-Side-Downscale (z. B. 2560 px), Kollisionsverhalten (Umbenennen `foto-2.jpg` / Überspringen / Überschreiben)
- Läuft auf Background-Queue mit sichtbarem Fortschritt in der Sidebar (`BackgroundActivityState`); Pick-geschützte Bilder blockieren nur die Delete-Variante — reine Backups sind non-destruktiv und immer erlaubt. Fehlerhafte Backups verhindern das anschließende Papierkorb-Verschieben (kein Datenverlust)

---

## 1.14.0
**Feature — View-Rendering-Smoketest im CI**

- Neuer `Tests/run_viewsmoke.sh` startet die gebaute `iPhoto.app` mit `IPHOTO_SMOKETEST=1`, wartet 2 s auf sauberes Rendern und beendet mit exit(0). Fängt Regressionen ab, die Model-/CatalogStore-Tests nicht sehen: Force-Unwraps in SwiftUI-Views, Threading-Verstöße bei `@Published`-Zugriff aus BG-Threads, kaputte Combine-Ketten beim Initialstart
- CI-Workflow (`.github/workflows/build.yml`) ruft den Smoketest zusammen mit den anderen Suites auf. Kein Snapshot-Test — nur "startet ohne Crash", aber deutlich näher an der Realität als isolierte Unit-Tests
- Kosten: ~3 s pro CI-Lauf. Bei Crash landet der CrashReporter-Bericht wie üblich in `~/Documents/bugreports/`, sodass das Fehlerbild reproduzierbar bleibt

---

## 1.13.1
**Chore — Notarization-Skript + Sparkle-Integrationsplan**

- Neues `notarize.sh` signiert `build/iPhoto.app` mit einer Developer-ID, sendet per `xcrun notarytool` an Apple, wartet auf das Ticket und `staple`t es in die .app. Voraussetzung: `xcrun notarytool store-credentials iPhoto-Notary` einmalig laufen lassen. Damit ist der Vertrieb ausserhalb des App Store ohne Gatekeeper-Warnung moeglich
- Der Sparkle-Integrationsplan (Framework-Ablage ohne SPM, Info.plist-Keys, Ed25519-Signatur, GitHub-Pages-Appcast) steht als Kommentar-Block oben im Skript. Umsetzung wird spaeter angestossen, wenn Auto-Update-Bedarf konkret wird

---

## 1.13.0
**Feature — Draft-Mode für Adjustments + ADJUST-Perf-Log**

- Slider-Bewegungen rendern jetzt zuerst bei 800 px längster Kante (Draft), 250 ms nach dem letzten Wert erfolgt automatisch ein Hi-Res-Upgrade auf 1500 px. Bei RAWs im hundertstel-MP-Bereich fühlt sich das Ziehen dadurch sichtbar direkter an — der finale Preview bleibt qualitativ unverändert
- Umgesetzt als Debouncer-Kaskade (50 ms Draft, 250 ms Hi-Res, 500 ms Undo-Commit) statt als Slider-Gesture-Wrapper. Kein SwiftUI-`DragGesture` nötig, funktioniert automatisch für alle 16 vorhandenen Regler
- Neue Log-Zeile `ADJUST draft|hi-res N ms scale=X.XX` pro Render — sichtbar via `tail -f ~/Library/Logs/iPhoto/iPhoto.log | grep ADJUST`. Perf-Regressionen der Adjustment-Pipeline sind damit im Log statt in Bauchgefühl-Reports messbar

---

## 1.12.0
**Feature — O(1)-Position-Lookups + EXIF-Cache-Invalidation nach Metadata-Write**

- Dictionary-Cache für `visibleDocuments`-Positionen: `next()`/`previous()`, Selection-Extension, Adjacent-Prefetch, Evict-Distant und die drei `scrollToCurrent`-Aufrufer (Sidebar, LibraryGrid, LibraryFullGrid) benutzten bislang `firstIndex(where:)` — O(N) pro Klick. Neuer `visiblePositionCache: [UUID: Int]` wird synchron zu `visibleResolvedCache` gebaut und über alle 9 Call-Sites per `visiblePosition(for:)` mit O(1) genutzt. `dispatchPrecondition(.onQueue(.main))` sichert die Main-Thread-Zusage ab
- Bugfix Stale-EXIF-Cache: nach `Metadaten speichern` blieb der In-Memory-EXIF-Cache in `CatalogStore` stehen — Smart-Folder-Filter (ISO/Blende/Brennweite/Objektiv) lieferten alte Werte bis zum Neustart. Alle drei Save-Pfade rufen jetzt `CatalogStore.shared.invalidateExifCache(path:)` auf und markieren die Datei per `exif_scanned=0` für den nächsten Rescan. Invalidate-Call sitzt im ViewModel, damit die CLI ohne CatalogStore-Abhängigkeit weiter baut

---

## 1.11.0
**Feature — Speed-Metriken pro Bild-Switch im Log**

- Jeder Bild-Switch loggt jetzt Millisekunden vom User-Klick bis zum ersten sichtbaren Frame, kategorisiert nach Display-Pfad: `SWITCH cache-hit`, `SWITCH thumbnail-hit`, `SWITCH preview-hit`, `SWITCH preview-decoded`, `SWITCH full-res` — plus separater `SWITCH full-res-decode` für die reine Dekoder-Zeit. Live-Beobachtung: `tail -f ~/Library/Logs/iPhoto/iPhoto.log | grep SWITCH`
- Ziel: Perf-Regressionen der Bild-Switch-Latenz nicht mehr manuell erraten, sondern in der App-Log-Datei nachweisen. Ist ein Programmier-Build — Metriken bleiben dauerhaft drin
- Neue Hot-Paths sollen konsistent eine eigene SWITCH-Zeile emittieren, damit Regressionen sich nicht in Timings verstecken können

---

## 1.10.1
**Bugfix — Bild-Switch nicht mehr blockiert vom Quality-Scan**

- Der v1.10.0-Rescan (ausgelöst durch die `phash_v`-Migration) schrieb pro gescanntem Bild sechsmal einzeln in `collection.documents[idx]`. Jeder Subscript-Write auf einem `@Published`-Array triggert eine komplette Array-Kopie — bei einer 5000-Bilder-Library summierte sich das zu O(N²) Publishes, saturierte den Main-Thread und riss die Bild-Switch-Latenz von wenigen Millisekunden auf mehrere hundert hoch
- Scan-Ergebnisse werden jetzt in Batches à 100 Docs gesammelt und in einem einzigen Main-Thread-Dispatch geflusht: lokale Kopie mutieren, Pfad→Index-Dictionary einmal pro Batch (statt `firstIndex` pro Doc), dann ein Write-Back. Ergibt ~N/100 Publishes statt 6·N mit jeweils O(N) Suche

---

## 1.10.0
**Feature — Zweite Hash-Achse für Similarity + Ähnliche-Gruppe als Album im Viewer**

- Similarity-Grouping nutzt jetzt zwei orthogonale dHash-Signale (horizontale + vertikale Gradienten). Ein einzelner dHash lieferte bei dunklen/kontrastarmen Motiven zu viele identische Bits und clusterte unähnliche Bilder zusammen. Beide Achsen müssen matchen (≤ 6 Bits Hamming pro Achse) — die effektive Diskriminierung ist damit deutlich strenger, Bracketing-Serien bleiben aber weiterhin zusammen
- Migration: neue Spalte `phash_v` in der Katalog-DB. Alte Records werden beim App-Start für einen Rescan markiert (`quality_scanned=0 WHERE phash_v IS NULL`) — der Import-Scan berechnet den zweiten Hash automatisch mit
- Klick auf ein Tile in „Ähnliche Bilder" öffnet die Gruppe jetzt im Haupt-Viewer, nicht mehr in einer separaten Lightbox. Pfeiltasten navigieren nur innerhalb der Gruppe, exakt wie in einem Album. Rückkehr zur Übersicht über den Sidebar-Eintrag „Ähnliche Bilder"

---

## 1.9.1
**Bugfix — Ähnliche-Bilder-Cluster und Duplikat-Erkennung robuster**

- Ähnliche-Bilder-Gruppierung: Union-Find erzeugte transitive Ketten (A~B, B~C, C~D → alle in einer Gruppe, auch wenn A und D visuell nichts gemein hatten). Speziell bei dunklen/kontrastarmen Motiven bildeten sich Riesen-Cluster mit völlig unähnlichen Bildern. Neu: Seed-and-Pull — jede Gruppe hat einen Seed, alle Mitglieder liegen garantiert innerhalb `maxDistance` vom Seed
- Ähnlichkeits-Schwelle von 10 → 8 Bits Hamming-Distanz gesenkt (12,5 % statt 15,6 % Unterschied) — Bracketing-Serien bleiben zusammen, unähnliche Motive nicht mehr
- „Neu gruppieren" reagiert nicht mehr stumm, wenn noch kein pHash vorliegt: der Quality-Scan wird automatisch gestartet, Fortschritt sichtbar in der Statuszeile
- Duplikat-Erkennung: bisherige Priorisierung (pHash → EXIF-Datum → Filename) fiel auseinander, sobald ein Duplikat-Paar aus zwei unterschiedlichen Tiers kam (z. B. ein Bild mit pHash, das andere nur mit Filename+Größe). Neu: Multi-Key-Bucketing mit Union-Find — jeder Doc trägt bis zu 3 Signale bei, teilen sich zwei Docs *irgendeines*, gelten sie als Kandidat
- Kandidaten werden anschließend per SHA über die ersten 256 KB der Datei verifiziert — echte Progress-Anzeige und belastbare Duplikat-Aussage statt millisekunden-schneller Wörterbuch-Aggregation

---

## 1.9.0
**Feature — Persistierte Duplikat- und Similarity-Gruppen**

- Duplikat- und Ähnlichkeits-Gruppen werden jetzt im Katalog gespeichert (neue Spalten `duplicate_group_id`, `similar_group_id`) — beim App-Neustart auf dieselbe Library sind die Gruppen sofort verfügbar, ohne dass Union-Find über alle pHashes neu laufen muss
- Nach jedem `detectDuplicates`/`detectSimilarImages`-Lauf wird der Katalog idempotent aktualisiert (vorher alle IDs geNULLt, dann neu gesetzt) — gelöschte oder umsortierte Gruppen leben nicht als Geister weiter

---

## 1.8.0
**Feature — Ähnliche-Bilder-Lightbox mit Pfeiltasten + verbesserte Duplikat-Erkennung**

- Klick auf ein Bild in „Ähnliche Bilder" öffnet jetzt eine Vollbild-Lightbox mit Preview (1600 px). Pfeiltasten ◄ ► navigieren durch die Gruppe, Leertaste markiert das aktuelle Bild als „Beste", ESC schließt
- Thumbnails in der Ähnliche-Bilder-Übersicht wurden bei frisch gescanntem Grouping nicht angezeigt: die persistierten Snapshots hielten stale `thumbnailImage`-Werte — jetzt werden die Dokumente pro Render aus der Collection re-resolved
- Duplikat-Erkennung greift jetzt auch ohne EXIF-Datum: Primär pHash + Dateigröße (findet bit-exakte Kopien und Exports ohne EXIF), Fallback auf DateTimeOriginal + Größe, letzter Fallback Dateiname + Größe

---

## 1.7.1
**Feature — Qualitäts-Metadaten-Eintrag + Icon-Fix für Belichtungs-Badges**

- Neue Kategorie „Qualität" im Metadaten-Panel: zeigt Schärfe-Score, Schatten-/Lichter-Clipping mit aktueller Klassifikation (Scharf/Unscharf, OK/Unter-/Überbelichtet) sowie Override-Status
- Icons für Unter-/Überbelichtung in Sidebar, Thumbnails und Belichtungs-View: `circle.lefthalf.filled`/`circle.righthalf.filled` sind auf macOS 11 nicht verfügbar — Fallback auf `moon.fill` (Unterbelichtet) und `sun.max.fill` (Überbelichtet)

---

## 1.7.0
**Feature — Persistierte Qualitäts-Flags, Ähnlichkeits-Gruppen und globales Lernen**

- Qualitätsanalyse (Unschärfe, Über-/Unterbelichtung) läuft jetzt einmalig beim Import und speichert Scores + pHash im Katalog — die Ansichten „Unscharf“, „Unter-/Überbelichtet“ leiten ihre Listen aus den persistierten Werten ab und öffnen sich sofort
- Thumbnails zeigen kleine farbige Badges für Blur (lila Tropfen), Unterbelichtung (blauer Kreis) und Überbelichtung (gelber Kreis) — wirken in allen Rasteransichten
- Rechtsklick-Overrides „Doch nicht unscharf / unter- / überbelichtet“ entfernen das Flag am Bild und verschieben den globalen Schwellenwert Richtung Bild-Score (Gewicht 0,1) — der Detektor lernt so die Präferenzen des Nutzers
- Neuer Bereich „Ähnliche Bilder“ in der Seitenleiste unter Duplikate: visuelle Cluster (pHash + Union-Find) für Belichtungsreihen und Serienaufnahmen, mit „Beste“-Wahl und optionalem Verschieben der Übrigen in den Papierkorb
- Neues Einstellungen-Panel (⌘,) mit Schiebereglern für Blur-/Shadow-/Highlight-Schwellenwerte plus „Auf Standardwerte zurücksetzen“ — Werte werden in `UserDefaults` persistiert

---

## 1.6.1
**Refactor — ImageViewModel entkoppelt, Main-Thread-Invarianten erweitert**

- Vergleichsmodus-State (aktiv, links/rechts, Load-Tracking) in `ComparisonState` ausgelagert — Views greifen via `viewModel.compare.active` etc. zu
- Qualitätsanalyse-State (Duplikate, Unschärfe, Belichtung, Schwellenwerte) in `QualityDetectionState` ausgelagert — reduziert `ImageViewModel` um 12 Felder
- Main-Thread-Preconditions (`dispatchPrecondition`) auf risikoreichen `@Published`-Feldern (Loading-Flags, Fehlermeldungen, Qualitäts-Listen, Hot-Pixel-Phase) — CoW-Data-Races werden jetzt sofort erkannt statt später als Speicherkorruption zu manifestieren (vgl. Bugs #7, #29, #33)
- `HotPixelAnalyzer` nutzt jetzt den geteilten `sharedSRGBCIContext` statt einen frischen Metal-Context pro Scan (Konsistenz mit Bug-#15-Fix)

---

## 1.6.0
**Feature — Fortschrittsanzeige für Qualitäts-Scans und Batch-Bearbeitung**

- Scans in den Ansichten „Unscharf“, „Unter-/Überbelichtet“ und „Duplikate“ zeigen jetzt Fortschritt im Ladebalken (Sidebar) inklusive Bildanzahl und Zeit
- Bewertungen, Pick-/Reject-Markierungen und Farb-Labels für viele Bilder gleichzeitig (ab 20 Bildern) laufen im Hintergrund und zeigen ebenfalls Fortschritt — das UI bleibt bei großen Auswahlen reaktionsfähig
- Kleine Bearbeitungen (< 20 Bilder) bleiben synchron und ohne Ladebalken

---

## 1.5.1
**Feature — Pick-Schutz beim Löschen**

- Als „Pick“ markierte Bilder können nicht mehr in den Papierkorb verschoben oder endgültig gelöscht werden — die Operation wird komplett abgebrochen und ein Hinweis zeigt die betroffenen Bilder
- Der Schutz greift überall: Kontextmenü, „Alle in Papierkorb“ in Unscharf-/Belichtungs-Views, Duplikate-Ausführen und Papierkorb-Leeren
- Um ein Pick-Bild zu löschen, muss zuerst die Pick-Markierung entfernt werden

---

## 1.5.0
**Feature — Auswahl, Kontextmenü und Detail-Ansicht in Qualitäts-Views**

- In den Ansichten „Unscharfe Bilder“, „Unterbelichtet“ und „Überbelichtet“ können Bilder jetzt per Klick markiert werden (⌘-Klick für Mehrfachauswahl, ⇧-Klick für Bereich)
- Rechtsklick auf ein Bild öffnet das bekannte Kontextmenü (Pick/Reject, Bewertung, Farb-Label, Export, In Papierkorb, Album, …)
- Doppelklick öffnet das Bild in der Detail-Ansicht mit Filmstreifen — der Streifen zeigt nur die Bilder der jeweiligen Qualitäts-Liste, ⌘Pfeile navigieren nur innerhalb dieser
- Toolbar-Button „Zurück zur Übersicht“ führt zurück zum Raster

---

## 1.4.3
**Bugfix — Inpaint-Pipeline korrigiert**

- Bild und Maske werden jetzt in separate Verzeichnisse (`img/inpaint.png`, `mask/inpaint.png`) geschrieben — `demo.py` matcht beide anhand des Dateinamens
- Aufruf erfolgt über Wrapper-Script `run_inpaint.sh` im CMT-Verzeichnis (Environment-Setup lebt dort), statt `python3 demo.py` direkt
- Maskenkonvertierung liest jetzt den Alpha-Kanal des Pinselstrichs und erzeugt eine binäre Schwarz-Weiß-Maske (vorher gingen die Pinselstriche beim Zeichnen in den Grau-Kontext verloren)
- Fehlermeldung enthält jetzt kombiniertes stdout + stderr statt nur den letzten 500 Zeichen von stderr

---

## 1.4.2
**Refactor — Lade-Pipeline in ImageLoadingOrchestrator ausgelagert**

- Neue Klasse `ImageLoadingOrchestrator` besitzt den kompletten Lade-State (15 Felder + 4 Queues + Semaphore) und die Implementierung von Bild-, Thumbnail- und Metadaten-Pipeline
- `ImageViewModel` hält nur noch eine `lazy var loader`-Referenz; die 8 öffentlichen Lade-Methoden werden über dünne Wrapper (`+Loading`, `+Thumbnails`, `+MetadataScan`, ~20 Zeilen zusammen) an den Orchestrator delegiert
- Alle 14 Aufrufer-Dateien bleiben unverändert — keine API-Änderung
- Motivation: `ImageViewModel` shrinkt um 15 State-Felder und die Lade-Logik lebt nun in einer verantwortlichen Klasse

---

## 1.4.1
**Refactor — ImageViewModel+Loading in fokussierte Extensions aufgeteilt**

- `ImageViewModel+Loading.swift` (614 Zeilen) auf 282 Zeilen reduziert (nur noch die Bild-Pipeline)
- Neue Extensions: `+Thumbnails.swift` (Grid- und High-Res-Thumbnails), `+MetadataScan.swift` (Metadaten + EXIF-Library-Scan), `+QualityDetection.swift` (Duplikate, Unschärfe, Belichtung)
- Keine API-Änderung, keine funktionale Änderung — nur Datei-Organisation

---

## 1.4.0
**Feature — Automatische Katalog-Backups**

- Beim App-Start wird der SQLite-Katalog (Ratings, Alben, Anpassungen, EXIF-Cache) via `VACUUM INTO` gesichert
- Speicherort: `~/Library/Application Support/iPhoto/backups/catalog-<Zeitstempel>.db`
- Die letzten 5 Backups werden aufbewahrt, ältere automatisch gelöscht
- Backup läuft asynchron auf der Katalog-Queue und blockiert weder Start noch UI

---

## 1.3.1
**Refactor — Doppelte CIContext-Instanzen zusammengefasst**

- `ImageExporter` und `RAWImageDecoder` teilen sich jetzt einen gemeinsamen sRGB-CIContext (`sharedSRGBCIContext`)
- `AdjustmentSessionState.ciContext` verweist jetzt auf `AdjustmentRenderer.context` — beide Konfigurationen waren identisch (linear-sRGB, RGBAh)
- Weniger GPU-Ressourcen bei parallelen Export/Decode-Vorgängen, keine funktionale Änderung

---

## 1.3.0
**Feature — Unter- und Überbelichtung erkennen**

- Neue Sidebar-Einträge „Unterbelichtet" und „Überbelichtet" unter der Sektion „Qualität"
- Erkennung per vImage-Histogramm: Anteil geclippter Schatten- bzw. Lichter-Pixel wird gemessen
- Schwellenwert per Slider einstellbar (Standard: 6 % geclippte Pixel)
- Grid-Ansicht mit Einzellösch- und „Alle in Papierkorb"-Aktion

---

## 1.2.0
**Feature — Unscharfe Bilder erkennen**

- Neue Sidebar-Sektion „Qualität" mit Eintrag „Unscharf"
- Erkennung basiert auf Laplacian-Varianz (Accelerate/vImage) auf Thumbnails — niedriger Score = unscharf
- Schwellenwert per Slider einstellbar (Standard: 120)
- Ergebnis als Grid: jedes Bild einzeln oder alle auf einmal in den Papierkorb verschieben
- Kontextmenü in der Sidebar: „Neu scannen"

---

## 1.1.3
**Bugfix — Cmd+A wählt alle Bilder aus, auch in Stapeln**

- „Alle auswählen" (Cmd+A) markiert jetzt alle Bilder innerhalb eingeklappter Stapel — nicht nur das jeweils oberste Bild

---

## 1.1.2
**Chore — Python-Standardpfad korrigiert**

- Python-Standardpfad im Inpaint-Panel von `/usr/bin/python3` auf `/usr/local/bin/python3.10` geändert

---

## 1.1.0
**Feature — Inpaint: Bereiche mit CMT ausfüllen**

- Neues Inspector-Panel „Inpaint" (über Plugins-Menü aktivierbar)
- Pinsel-Tool: Bereich im Bild mit roter Maske anmalen (Größe 5–200 px einstellbar)
- Masken-Zeichnen per Maus direkt im Bildbereich — Cursor wechselt auf Fadenkreuz
- Inpaint-Engine: ruft [CMT](https://github.com/keunsoo-ko/CMT) (Continuously Masked Transformer, ICCV 2023) via Python-Subprocess auf
- Pfade für Python 3, CMT-Verzeichnis und Checkpoint im Panel konfigurierbar
- Ergebnis wird sofort angezeigt; beim Bildwechsel automatisch zurückgesetzt
- „Maske löschen"- und „Zurücksetzen"-Buttons

---

## 1.0.3
**Bugfix — Zoom-Explosion im Vergleich (echter Fix)**

- `ZoomableScrollView` bekommt neuen Parameter `alwaysFitOnImageChange`: bei jedem Bildwechsel wird immer an die Pane angepasst, kein Ratio-Scaling
- Damit werden alle Fälle abgedeckt: neues Paar, Thumbnail→Preview→Vollauflösung

---

## 1.0.2
**Bugfix — Zoom-Explosion beim Bildwechsel im Vergleich**

- Zoom sprang manchmal auf 800%+, wenn ein hochauflösendes Bild durch ein neues Thumbnail ersetzt wurde (Ratio 6000px/150px = 40×)
- Fix: ScrollView wird beim Dokumentwechsel komplett neu erstellt, kein fehlerhafter Ratio-Carry-over mehr

---

## 1.0.1
**Feature — Zoom im Bildvergleich**

- Beide Vergleichspanes unterstützen jetzt Zoom: Pinch, Mausrad und Hand-Drag
- Jede Seite zoomt unabhängig; Zoomlevel wird in der Infozeile angezeigt
- Fit-Button setzt den Zoom zurück, Daumen-hoch-Button ersetzt den alten Tap-Gesture zum Auswählen

---

## 1.0.0
**Feature — iOrdner-Limit & Toolbar im Bildvergleich**

- Intelligente Ordner können jetzt auf eine maximale Anzahl von Bildern begrenzt werden (wie iTunes Smart-Playlists)
- Auswahlstrategie wählbar: Zufällig, Beste Bewertung, Schlechteste Bewertung, Neueste oder Älteste zuerst
- Limit-Zeile erscheint unterhalb der Kriterien im Erstellungs-/Bearbeitungsdialog; bei deaktiviertem Limit abgeblendet
- Toolbar (Sidebar, Inspector, Navigation usw.) ist jetzt auch im Bildvergleich sichtbar

---

## 0.99.1
**Feature — SD-Karten-Sync vergibt automatisch 3 Sterne**

- Bilder, die über „Synchronisieren" von einer Speicherkarte in die Bibliothek kopiert werden, erhalten automatisch eine 3-Sterne-Bewertung

---

## 0.99.0
**Feature — Duplikate-Tab als Sidebar-Eintrag mit Qualitätsempfehlung**

- Duplikate haben jetzt einen eigenen Tab in der Sidebar (wie Papierkorb), mit orangem Badge wenn Gruppen gefunden wurden
- Die Duplikat-Ansicht zeigt jede Gruppe mit Thumbnails, grünem Haken für die empfohlene Behalte-Datei und rotem Papierkorb für die vorgeschlagene Löschdatei
- Qualitätsempfehlung: RAW-Dateien werden gegenüber JPEG/anderen Formaten bevorzugt; bei gleichem Format bleibt das Original (kürzester Pfad, keine Kopie/Backup-Indikatoren im Namen)
- Per Klick auf eine Datei kann die Empfehlung umgekehrt werden ("Stattdessen behalten")
- "Ausführen" pro Gruppe oder "Alle ausführen" verschiebt die markierten Duplikate in den App-Papierkorb

## 0.98.0
**Feature — Duplikatserkennung**

- Neue Funktion: Duplikate erkennen — nach dem Laden der Metadaten werden Bilder mit identischem Aufnahmezeitpunkt und gleicher Dateigröße automatisch gruppiert
- In der Sidebar erscheint ein oranges Banner mit der Anzahl der gefundenen Duplikat-Gruppen
- „Prüfen"-Button öffnet einen Sheet mit einer Übersicht aller Gruppen inkl. Thumbnails, Dateiname und Pfad
- Standardmäßig werden alle Duplikate außer dem ersten in jeder Gruppe zum Löschen vorgeschlagen
- Per Klick oder Checkbox lässt sich die Auswahl pro Datei anpassen
- „In Papierkorb"-Button verschiebt alle markierten Dateien in den App-internen Papierkorb

---

## 0.97.0
**Feature — Sequenzielle Ladeaufgaben, Vergleichs-Verteilungsanzeige, Trash-Fix im Duell**

- Ladeaufgaben (Thumbnails, Metadaten, EXIF-Scan) laufen jetzt nacheinander statt gleichzeitig — unten links wird immer nur eine Sache auf einmal angezeigt
- Duell-Modus zeigt jetzt eine Sterne-Verteilungsleiste: aktueller Ist-Anteil vs. Gauß-Zielkurve pro Sternstufe
- Fix: Bilder im Papierkorb konnten weiterhin als Duell-Kandidaten ausgewählt werden; `compareLeftDocument`/`compareRightDocument` filtern jetzt getrashte Bilder aus
- Fix: Wird ein aktuell verglichenes Bild in den Papierkorb verschoben, wird sofort zum nächsten Paar weitergesprungen

---

## 0.96.0
**Feature — Bildvergleich: Pfeiltasten-Fix, zufälliges Auf/Ab, gezielte Klassen-Auswahl**

- Pfeiltasten funktionieren jetzt im Vergleichsmodus: Sie trugen unsichtbare System-Modifier (Funktions-/Ziffernblock-Flag), wodurch die Duell-Steuerung übersprungen und stattdessen das Bild gewechselt wurde
- Nach einer Entscheidung wird jetzt zufällig entweder der Gewinner eine Sternstufe erhöht oder der Verlierer eine gesenkt; steht der Gewinner bereits auf 5★, wird immer gesenkt, steht der Verlierer auf 0★, immer erhöht
- Paarauswahl nimmt jetzt immer die Sternstufe mit dem größten Überschuss gegenüber der Gauß-Zielkurve statt gewichteter Auslosung

---

## 0.95.0
**Feature — Bildvergleich: Gauß-Zielverteilung, Pfeiltasten-Steuerung, Lade-Fix**

- Paarauswahl steuert jetzt auf eine Gauß-artige Sterneverteilung zu (1★ 10 %, 2★ 20 %, 3★ 40 %, 4★ 20 %, 5★ 10 %): Verglichen werden bevorzugt Bilder aus Stufen, die über ihrem Ziel-Anteil liegen; unbewertete Bilder werden zuerst einsortiert
- Pfeiltasten im Vergleichsmodus: ← links besser, → rechts besser, ↑ gleich gut, ↓ überspringen
- Fix: Nach einer Entscheidung blieben die nächsten Bilder dauerhaft im Lade-Zustand — die Speicher-Aufräumroutine verwarf frisch geladene Vergleichs-Previews sofort wieder (Duell-Bilder liegen meist weit vom aktuellen Bild entfernt); Duell-Bilder sind jetzt vor der Räumung geschützt
- Bis das große Preview geladen ist, wird sofort das Raster-Thumbnail angezeigt statt eines Spinners

---

## 0.94.1
**Bugfix — SIGILL-Crash der Lade-Leiste + UI-Freeze durch Thread-Pool-Erschöpfung**

- Crash (SIGILL) beim Ausblenden der Lade-Leiste behoben: Die Leiste griff auf den ersten Queue-Eintrag zu, während die Queue gerade geleert wurde (Bug #34, 3 Abstürze am 15./16.07.)
- Minutenlanger UI-Freeze beim Thumbnail-Laden großer Alben behoben: Pro Bild wartete ein eigener GCD-Thread an einer Semaphore — bei hunderten Bildern war der Thread-Pool (Limit 64) erschöpft und der Main-Thread hing an Datenbank-Zugriffen (Bug #35)
- Lade-Pipelines (Thumbnails, sichtbare Vorschauen, Metadaten) laufen jetzt über OperationQueues mit fester Parallelität statt Block-pro-Bild — gleiches Speicherverhalten, keine blockierten Threads

---

## 0.94.0
**Feature — Bildvergleich (Duell-Modus)**

- Neuer Knopf „Bildvergleich" in der linken Seitenleiste: zwei Bilder werden nebeneinander im Hauptbereich angezeigt
- Klick auf das bessere Bild (oder Buttons „Links/Rechts ist besser", „Gleich gut", „Überspringen") entscheidet das Duell
- Der Gewinner steigt eine Sternstufe auf (max. 5); steht er bereits bei 5 Sternen, wird stattdessen der Verlierer eine Stufe gesenkt
- Verglichen werden bevorzugt Bilder mit gleicher Sternezahl aus dem aktuellen Kontext (Bibliothek, Album, Smart-Ordner)
- Beenden per X-Knopf, erneutem Klick auf „Bildvergleich" oder Wechsel der Navigation

---

## 0.93.1
**Bugfix — Pause stoppte das Laden nicht zuverlässig**

- Ladeblöcke, die beim Drücken von Pause bereits auf einen Decode-Slot warteten, liefen trotzdem weiter durch
- Fix: Nach dem Erhalt eines Decode-Slots wird der Pausen-Status erneut geprüft; pausierte Aufgaben geben den Slot sofort wieder frei und warten

---

## 0.93.0
**Feature — Ladeaufgaben pausieren**

- Hintergrund-Ladeaufgaben (Thumbnails, Metadaten, EXIF-Scan) lassen sich jetzt pausieren und fortsetzen
- Neuer Pause/Play-Button direkt in der Lade-Leiste der Seitenleiste für die aktive Aufgabe
- Im „+N"-Popover hat jede Aufgabe in der Warteschlange einen eigenen Pause-Button; pausierte Aufgaben zeigen den Status „Pausiert" mit abgedunkeltem Fortschrittsbalken
- Pausierte Aufgaben geben ihre Decode-Slots frei — andere Aufgaben laufen ungebremst weiter

---

## 0.92.11
**Bugfix — Minutenlanger UI-Freeze bei schneller Navigation behoben**

- Bei gehaltener Pfeiltaste (Key-Repeat) fror die App minutenlang ein, der Speicher wuchs dabei Richtung 1 GB — vermutlich die wahre Ursache der stillen App-Enden aus Bug #32
- Ursache: Die Speicher-Aufräumroutine (`evictDistantImages`) schrieb pro Bild einzeln ins beobachtete Dokument-Array — jede Zuweisung löste eine komplette Array-Kopie samt Freigabe aus (quadratischer Aufwand pro Tastendruck)
- Fix: Aufräumen läuft jetzt auf einer lokalen Kopie und schreibt genau einmal zurück (und gar nicht, wenn nichts freizugeben ist)
- Diagnose erstmals live per Heartbeat (0.92.10) belegt: „main blockiert seit 113s" + Sample-Backtrace

---

## 0.92.10
**Diagnose — Heartbeat-Logging schließt SIGKILL-Blindstelle**

- Neuer Heartbeat: alle 10 Sekunden wird Speicherverbrauch und Main-Thread-Responsivität geloggt — stille App-Enden (OOM-Kill, Force-Quit nach Freeze) sind damit künftig im Crash-Report unterscheidbar
- Bug #32 analysiert und dokumentiert: die zwei Reports vom 11./12.07. (v0.87.0/0.89.0) endeten per SIGKILL ohne Signal-Eintrag — wahrscheinlichste Ursache sind die in 0.87.1 und 0.91.0 bereits behobenen UI-Freezes mit anschließendem Force-Quit

---

## 0.92.9
**Code-Qualität — CatalogStore aufgeteilt, Save-Pfad entdoppelt, Cache-Invariante abgesichert**

- `CatalogStore` (726 Zeilen) in thematische Dateien aufgeteilt: Ratings/Papierkorb, Alben/Suche und Anpassungen/Presets liegen jetzt in eigenen Extensions — Kern-Datei enthält nur noch Schema, Migration und Bilder-CRUD
- Speicher-/Undo-/Redo-/Revert-Pfad: fünffach dupliziertes Hintergrund-Task-Gerüst (Security-Scoped-Access, Fehlerbehandlung, UI-Status) in einen gemeinsamen Helper extrahiert — Undo und Redo teilen sich jetzt eine Implementierung
- `visibleDocuments`-Cache erzwingt jetzt per Precondition Main-Thread-Zugriff (crasht sofort statt still zu korrumpieren, gleiche Invariante wie `ImageCollection`)

## 0.92.8
**Robustheit — SQLite-Fehler sichtbar, Crash-Diagnose thread-sicher, RAF-Fehler mit Kontext**

- Katalog-Datenbank: Fehlgeschlagene SQLite-Operationen (z. B. bei beschädigter Datenbank) werden jetzt geloggt statt still ignoriert — auch fehlgeschlagene `prepare`-Aufrufe melden die Ursache
- Crash-Diagnose: Der Breadcrumb-Puffer der Decode-Pipeline wird jetzt lock-serialisiert beschrieben — parallele Decodes können den Puffer nicht mehr gegenseitig korrumpieren, Crash-Reports bleiben lesbar
- RAF-Decoder: Fehlgeschlagene Schritte (Datei öffnen, Header lesen, ungültige Signatur, fehlendes/unlesbares eingebettetes JPEG) loggen jetzt die konkrete Ursache statt nur „Bild konnte nicht dekodiert werden"
- Test-Suites repariert: `run_bench` und `run_library` kompilierten nicht mehr (fehlende `Data+Extensions.swift`); `run_catalog` um `Log.swift` ergänzt

## 0.92.7
**Build & Qualität — Inkrementeller Build, vollständigere CI, Bildgröße in Metadaten**

- `build.sh` kompiliert jetzt inkrementell: nur geänderte Dateien werden neu übersetzt (unveränderter Rebuild ~1 s, einzelne Datei ~3 s statt ~70 s Vollbuild); `./build.sh --clean` erzwingt weiterhin einen Vollbuild
- CLI-Tool wird übersprungen, wenn sich keine seiner Quelldateien geändert hat
- CI führt jetzt zusätzlich die LibraryStore- und Dateiformat-Tests aus (5 statt 3 Test-Suites)
- Metadaten zeigen jetzt die Bildgröße in Pixeln („Größe" unter Allgemein) — behebt zugleich den fehlschlagenden `info`-Formattest

---

## 0.92.6
**Architektur — ImageViewModel-Zerlegung Stufe 2: Anpassungen & intelligente Ordner**

- Kompletter Anpassungs-State (Regler, gerendertes Bild, Undo/Redo-Historie, Presets, Kopieren/Einfügen, Render-Kontext) in eigenes Kind-ViewModel `AdjustmentSessionState` ausgelagert — 8 weitere @Published-Properties verlassen das ImageViewModel, Verhalten unverändert
- Symlink-Spiegelung der intelligenten Ordner (Anlegen, Aufräumen, Gruppen-Verzeichnisse) als eigenständiger, testbarer Helper `SmartFolderFileSync` extrahiert — reine Dateisystem-Logik ohne ViewModel-Bezug

---

## 0.92.5
**Architektur — ImageViewModel in Teilbereiche zerlegt (Stufe 1)**

- Lade-Queue/Import-Fortschritt (`BackgroundActivityState`), HDR-Merge-State (`HDRMergeState`) und Datei-Versionshistorie (`VersionHistoryState`) sind jetzt eigenständige, vom ImageViewModel besessene ViewModels — 14 der 42 @Published-Properties ausgelagert, Verhalten unverändert
- Änderungen der Kind-ViewModels werden per objectWillChange weitergeleitet, bestehende Views funktionieren ohne Beobachtungs-Änderungen

---

## 0.92.4
**Undo/Redo-Historie der Anpassungen isoliert testbar**

- Undo/Redo-Logik der Bildanpassungen als eigenständige `AdjustmentHistory` extrahiert — identisches Verhalten, jetzt ohne UI-Abhängigkeiten testbar
- 11 neue Tests (`Tests/run_adjustments.sh`): Commit-Deduplizierung, Undo/Redo-Roundtrips, Redo-Verwurf nach Commit, 50er-Tiefenbegrenzung, Reset beim Bildwechsel
- CI führt die neue Test-Suite bei jedem Push mit aus

---

## 0.92.3
**Stabilität — stille Fehler werden gemeldet, schnelleres Grid-Rendering**

- Thumbnail-Decode-Fehler (defekte/abgeschnittene Dateien) werden jetzt protokolliert und am Bild vermerkt statt still verschluckt — betroffene Bilder blieben bisher kommentarlos ohne Vorschau
- Bibliothek: unlesbare Album-/Ordner-/SmartFolder-Dateien und ein nicht erstellbares Application-Support-Verzeichnis lösen jetzt eine Fehlermeldung aus, statt Daten beim nächsten Speichern kommentarlos zu überschreiben
- Sichtbare Bildliste wird pro Render-Zugriff aus dem Cache bedient statt jedes Mal neu aufgelöst — spürbar flüssigeres Grid bei großen Alben

---

## 0.92.2
**Unit-Tests für kritische Pfade + Tests laufen jetzt in der CI**

- Stapel-Erkennung (BKT/CH/CL-Serien) als eigenständiger `StackDetector` extrahiert — identisches Verhalten, jetzt isoliert testbar
- 15 neue Tests für Stapel-Erkennung und Anzeige-Reihenfolge (`Tests/run_stacking.sh`): Läufe, Sequenz-Resets, RAF+JPEG-Paare, Auf-/Zuklappen
- Catalog-Tests erweitert (39 gesamt): Papierkorb-Tabelle (Markieren, Wiederherstellen, Persistenz) und Serienbild-EXIF (SequenceNumber/AutoBracketing)
- GitHub-Actions-Workflow führt beide Test-Suiten bei jedem Push aus

---

## 0.92.1
**Stabilität — Bildlade-Pipeline robuster gegen gleichzeitiges Löschen**

- Bild-, Preview- und Thumbnail-Ergebnisse werden jetzt per Datei-URL statt Positionsindex zugeordnet — verhindert verworfene oder falsch zugeordnete Ladeergebnisse, wenn sich die Sammlung währenddessen ändert (z. B. durch Löschen oder Ordner-Sync)
- Hängenbleibender Vollbild-Lademodus nach Sammlungsänderung behoben (Folge-Ladevorgänge wurden blockiert)
- Fehler beim Speichern von Tether-Aufnahmen werden jetzt protokolliert statt still verschluckt

---

## 0.92.0
**Interner Papierkorb — Löschen ist jetzt zweistufig**

- Neuer Tab „Papierkorb" in der Seitenleiste (mit Zähler): Gelöschte Bilder landen zuerst dort, die Dateien bleiben unangetastet auf dem Datenträger
- Im Papierkorb per Rechtsklick: Wiederherstellen, Endgültig löschen oder Papierkorb leeren (auch per Rechtsklick auf den Tab)
- Endgültiges Löschen verschiebt die Originaldateien in den macOS-Papierkorb (mit Fortschrittsbalken)
- Pick-Warnung und Stapel-/Mehrfachauswahl-Löschen funktionieren wie bisher

---

## 0.91.0
**Pick-Warnung beim Löschen + UI-Freeze beim Batch-Löschen behoben**

- Sind als Pick markierte Bilder beim Löschen dabei, warnt ein Dialog (mit Dateinamen) — „Trotzdem in Papierkorb" oder „Abbrechen" (dann wird nichts gelöscht)
- App fror beim Löschen vieler Bilder ein: Die Ordnerüberwachung feuerte pro gelöschter Datei einen teuren Abgleich auf dem Main-Thread — jetzt entprellt (1 s) und mit schnellem Set-Abgleich

---

## 0.90.0
**Ladebalken beim Löschen**

- Das Verschieben in den Papierkorb läuft jetzt im Hintergrund mit Fortschrittsbalken in der Seitenleiste — die App blockiert nicht mehr bei vielen Dateien
- Nach Abschluss erscheint „x Bilder in y Sekunden gelöscht"

---

## 0.89.0
**Lade-Zusammenfassung nach Abschluss**

- Nach Abschluss des Ladebalkens in der Seitenleiste erscheint kurz „x Bilder in y Sekunden geladen" (mit grünem Häkchen, blendet nach 6 Sekunden aus)
- Wird nur bei erfolgreich abgeschlossenen Ladevorgängen angezeigt, nicht bei Abbruch oder Fehler

---

## 0.88.0
**Aktionen auf ganze Serienbild-Stapel (CH/CL/BKT)**

- Rechtsklick auf einen eingeklappten Stapel: Papierkorb, Aus Sammlung entfernen, Bewertung, Pick/Abgelehnt, Farblabel, Album hinzufügen/entfernen und Export wirken jetzt auf alle Bilder des Stapels
- Menüeinträge zeigen die Stapelgröße an (z. B. „Stapel (7) in Papierkorb")
- Aufgeklappte Stapel und Mehrfachauswahl verhalten sich wie bisher

---

## 0.87.1
**Bildwechsel wieder schnell (~800 ms Verzögerung behoben)**

- Beim Bildwechsel wurden pro Tastendruck für jedes Bild der Bibliothek synchrone Datenbank-Abfragen ausgelöst, wenn Bilder (noch) nicht im Katalog waren — Fehlschläge werden jetzt gemerkt und nicht erneut abgefragt
- Die Serienbild-Stapelerkennung überspringt ihre aufwendige Dateinamens-Sortierung, wenn gar keine Serienbilder vorhanden sind

---

## 0.87.0
**Export per AirDrop — Bilder direkt ans iPhone senden**

- Neuer Punkt „Ziel" im Export-Dialog: wahlweise Speicherort wählen (wie bisher) oder AirDrop
- Bei AirDrop werden die Bilder im gewählten Format/Qualität exportiert und anschließend öffnet sich das AirDrop-Fenster zur Geräteauswahl (z. B. iPhone)
- Funktioniert für das aktuelle Bild, die Auswahl oder alle Bilder — Anpassungen werden wie beim normalen Export mitgerendert

---

## 0.86.2
**Hartnäckigste Crash-Ursache behoben: Absturz beim Scrollen/Rendern der Thumbnail-Leiste und Raster (Bug #31)**

- 18 von 23 Absturz-Berichten der letzten Wochen hatten dieselbe Ursache: das programmatische Zentrieren der Auswahl (`scrollTo`) hinterlässt auf macOS 11 ein internes Scroll-Ziel, das nach Änderungen der Bildliste (Bewertung, Thumbnail-Laden) auf freigegebenen Speicher zeigt — der nächste Scroll oder Fenster-Resize stürzte ab
- Thumbnail-Leiste und beide Raster-Ansichten zentrieren die Auswahl jetzt direkt über AppKit — ohne das fehleranfällige SwiftUI-Scroll-Ziel
- Verhalten unverändert: Auswahl wird weiterhin beim Bildwechsel zentriert

---

## 0.86.1
**Bewertungs-Sprung in intelligenten Ordnern + schnellerer Bildwechsel bei Shuffle**

- Fällt ein Bild nach dem Bewerten aus einem intelligenten Ordner heraus, springt die Auswahl jetzt zum nächsten Bild in der Anzeige-Reihenfolge — nicht mehr zum nächsten in Aufnahmereihenfolge
- Bild-Cache und Prefetch orientieren sich jetzt an der Anzeige-Reihenfolge: bei Zufalls-Sortierung wurden vorgeladene Nachbarbilder bisher sofort wieder verworfen, was jeden Bildwechsel deutlich verlangsamte
- Speicherkarten lassen sich jetzt auch nachträglich synchronisieren: Sync-Button beim Überfahren der Karte in der Seitenleiste sowie im Kontextmenü (für Karten, die schon vor dem App-Start eingesteckt waren)

---

## 0.86.0
**SD-Karten-Dialog: Synchronisieren mit optionalem Speicher-Freimachen**

- Beim Einstecken einer Speicherkarte mit Bildern erscheint ein Dialog mit drei Optionen: „Synchronisieren“, „Synchronisieren und Speicher freimachen“ und „Abbrechen“
- Synchronisieren kopiert alle neuen Bilder in die iPhoto-Bibliothek (~/Bilder/iPhoto); bereits vorhandene Dateien werden übersprungen
- „Speicher freimachen“ löscht anschließend nur Bilder von der Karte, die verifiziert in der Bibliothek liegen — fehlgeschlagene Kopien bleiben erhalten und werden gemeldet
- Karten, die bereits über einen überwachten Ordner mit Auto-Sync importiert werden, zeigen den Dialog nicht doppelt

---

## 0.85.0
**Serienbild- und Bracketing-Stapel (Fuji BKT & CH/CL)**

- Bilder aus Serienaufnahmen (CH/CL) und Belichtungsreihen (BKT) werden in Thumbnail-Leiste und Raster als ein Stapel angezeigt — das erste Bild trägt ein Zähler-Badge (z. B. „▣ 7")
- Klick auf das Badge klappt den Stapel inline auf und wieder zu; aufgeklappte Mitglieder sind dezent markiert
- Pfeiltasten überspringen eingeklappte Stapel-Mitglieder automatisch
- Erkennung über die Fuji-MakerNote (AutoBracketing/SequenceNumber); neue Metadaten-Einträge „Serienbild-Nr." und „Auto-Bracketing" im Inspector
- Bestehende Bibliotheken werden beim ersten Start automatisch nachgescannt

---

## 0.84.2
**Bildwechsel dramatisch beschleunigt (~3 s → ~35 ms)**

- Die Smart-Folder-Zähler in der Seitenleiste filterten bei jedem UI-Update alle Bilder neu (inkl. Datenbank-Zugriffen pro Bild, ~480 ms pro Durchlauf) — die Zähler werden jetzt entkoppelt im Hintergrund berechnet
- Nachbarbilder werden nach jedem Bildwechsel im Hintergrund vorgeladen: Beim Weiterschalten kommt das Bild direkt aus dem Speicher statt neu dekodiert zu werden
- Die sortierte Bilderliste wird als Reihenfolge-Cache gehalten und übersteht jetzt Thumbnail-/Bild-Updates — die teure Neusortierung bei jedem Tastendruck entfällt
- RAF-Dateien auf macOS 11 laden direkt das Vollbild (eingebettetes JPEG) statt Preview-Phase mit 1,5-s-Wartezeit
- Versions-Historie und Katalog-Schreibzugriffe beim Bildwechsel laufen nicht mehr auf dem Hauptthread; unveränderte Anpassungen werden nicht mehr erneut gespeichert

---

## 0.84.1
**Deutlich schnellerer App-Start bei großen Bibliotheken**

- Beim Import blockierte der Hauptthread bis zu ~25 Sekunden: Für jede Datei wurde einzeln ein Security-Scoped-Bookmark erzeugt und die komplette Bookmark-Datei neu geschrieben, außerdem lief pro Datei eine eigene SQLite-Transaktion (Rating-Abfrage + Upsert)
- Bookmarks werden jetzt gesammelt im Hintergrund angelegt und nur einmal gespeichert
- Katalog-Einträge werden als ein Batch in einer einzigen Transaktion geschrieben; Ratings werden mit einer Abfrage für alle Bilder vorab geladen
- Zusätzliche Trace-Logs in der Dekodier-Pipeline zur weiteren Analyse der Ladezeiten

---

## 0.84.0
**Weißabgleich-Feintuning (R/B-Shift) in den Metadaten**

- Der an der Kamera eingestellte Weißabgleich-Shift (Rot/Blau, ±9 Schritte) wird jetzt hinter dem Modus angezeigt, z. B. „Automatisch (R+9, B+2)" — gelesen aus Fuji-MakerNote-Tag 0x100A
- Bilder ohne Feintuning (R±0, B±0) zeigen weiterhin nur den Modus
- Werte gegen exiftool verifiziert (Rohwerte in 20er-Einheiten pro Kamera-Schritt)

---

## 0.83.0
**Weißabgleich in den Metadaten**

- Die Metadaten-Ansicht zeigt jetzt den bei der Aufnahme verwendeten Weißabgleich
- Bei Fujifilm-Kameras (RAF und JPEG) wird der konkrete Modus aus der MakerNote gelesen: Automatisch (inkl. Weiß-/Umgebungs-Priorität), Tageslicht, Bewölkt, Leuchtstoff-Varianten, Glühlampe, Blitz, Unterwasser, Benutzerdefiniert sowie Kelvin mit Farbtemperatur (z. B. „Kelvin (5600 K)")
- Bei allen anderen Kameras wird das Standard-EXIF-Feld angezeigt (Automatisch/Manuell)

---

## 0.82.3
**Tests: LibraryStore-Testsuite + erweiterte Katalog-Tests**

- Neue Testsuite für die Bibliotheks-Persistenz (`Tests/run_librarystore.sh`, 11 Tests): Speichern/Laden von Alben, intelligenten Ordnern und überwachten Ordnern, Verhalten bei fehlenden/korrupten Dateien sowie Fehler-Callback bei nicht beschreibbarem Verzeichnis
- Katalog-Tests um Anpassungen, Presets und EXIF erweitert (21 → 32 Tests) und Kompilierung nach den Preset-/Adjustment-Erweiterungen repariert
- Testkataloge sind jetzt vollständig isoliert: Die JSON-Legacy-Migration läuft nur noch für den echten Standard-Katalog, nicht für injizierte Datenbankpfade — Tests importieren keine echten Nutzerdaten mehr
- LibraryStore akzeptiert für Tests ein eigenes Speicherverzeichnis (`LibraryStore(directory:)`); Standardverhalten der App unverändert

---

## 0.82.2
**Refactoring: Bibliotheks-State in eigenständigen LibraryStore entkoppelt**

- Alben, überwachte Ordner, intelligente Ordner und erkannte Volumes leben jetzt in einem eigenen `LibraryStore` mit gekapselter JSON-Persistenz — das zentrale ViewModel ist dadurch schlanker und die Bibliotheksverwaltung unabhängig testbar
- Keine Funktionsänderung; alle Ansichten und Abläufe bleiben identisch
- Hinweis: Eine Migration auf Swift Concurrency (async/await, @MainActor) wurde bewusst zurückgestellt, da die App macOS 11 unterstützt und dort die Concurrency-Runtime beim direkten swiftc-Build nicht verfügbar ist

---

## 0.82.1
**Refactoring: Code-Struktur & Absturz-Prävention**

- Die große Bibliotheks-Logik (1.369 Zeilen) wurde in sieben thematische Dateien aufgeteilt (Sortierung/Kontext, Alben, Intelligente Ordner, Überwachte Ordner, Auswahl/Papierkorb, Bewertungen, Volumes) — keine Funktionsänderung
- Bildersammlung erkennt fehlerhafte Zugriffe von Hintergrund-Threads jetzt sofort und eindeutig, statt still den Speicher zu beschädigen (Schutz gegen die Absturzklasse aus Bugs #7, #8, #13, #28, #29)
- Ordner-Überwachung, Tastatur-/Maus-Monitore und offene Hintergrund-Aufgaben werden beim Beenden sauber aufgeräumt
- Zwei potenzielle Abstürze in der Histogramm-/Parade-Darstellung bei leeren Daten entschärft

---

## 0.82.0
**Feature: Zahleneingabe bei Anpassungen erlaubt Werte außerhalb des Slider-Bereichs**

- Im Textfeld neben den Anpassungs-Reglern (auch lokale Anpassungen) können jetzt Werte über/unter dem Slider-Bereich eingegeben werden — der Slider zeigt dann den Anschlag, der eingegebene Wert wird aber voll angewendet

---

## 0.81.0
**Feature: Werte eintippen + Auge-Toggle bei Anpassungen — Export rendert jetzt Anpassungen mit**

- Der Wert neben jedem Anpassungs-Regler ist jetzt ein Textfeld — Zahl eintippen und mit Enter bestätigen (Komma oder Punkt als Dezimaltrenner, Werte werden auf den gültigen Bereich begrenzt)
- Neues Auge-Symbol neben jedem Regler: Effekt einzeln temporär ausblenden, um den Unterschied zu sehen — Reglerwert bleibt dabei erhalten
- Bugfix: Exportieren rendert jetzt die Anpassungen ins exportierte Bild (volle Auflösung, inkl. lokaler Anpassungen, Kurven, Zuschnitt) — vorher wurde nur das unbearbeitete Original gespeichert
- Batch-Export wendet gespeicherte Anpassungen jedes Bildes aus dem Katalog an

---

## 0.80.1
**Bugfix: Crash beim Navigieren durch Thumbnails behoben (macOS 11)**

- Animiertes Scrollen zur Auswahl (Thumbnail-Leiste, Raster, Sidebar) verursachte auf macOS 11 einen SwiftUI-Absturz (EXC_BAD_ACCESS in HostingScrollView), wenn das Ziel-Thumbnail beim Abschluss der Animation nicht mehr existierte — Scrollen erfolgt jetzt ohne Animation

---

## 0.80.0
**Feature: Metadaten-Ladefortschritt in der Loading-Bar + Fuji B&W/Acros-Erkennung**

- Metadaten werden jetzt beim App-Start und beim Öffnen eines Ordners automatisch im Hintergrund geladen — Fortschritt erscheint in der Loading-Bar unten links
- Ladebalken zeigt genau die Anzahl der Bilder des aktuell geladenen Ordners (nicht die gesamte Bibliothek)
- Fuji B&W-Filmsimulationen (Monochrome, Monochrome+Filter, Sepia, Acros, Acros+Filter) werden jetzt über EXIF-Tag 0x1003 (Saturation) erkannt — betrifft X-T4 und neuere Modelle
- Neue Filmsimualtions-Codes: Astia/Soft (0x0120) und Pro Neg. Hi (0x0501) für X-T4
- Alle Fuji-Dateien werden beim nächsten App-Start erneut gescannt (Migration v4)
- Bugfix: Smart-Folder-Erstellen duplizierte ungegruppierte Ordner statt sie zu verschieben
- Bugfix: Crash-Fixes in RAF-Decoder — Semaphore-Limit für parallele ImageIO-Decodes, korrekte Semaphore-Position vor CIImage-Rotation, FileHandle auf werfende API umgestellt

---

## 0.79.4
**Feature: `iphoto-cli info` gibt jetzt alle EXIF/IPTC/GPS-Metadaten aus**

- `iphoto-cli info <datei>` nutzt jetzt `MetadataService` — zeigt Kamera, Objektiv, ISO, Blende, Belichtung, Datum, Filmsimulation, GPS u.v.m. in gruppierten Abschnitten
- `--json`-Flag für maschinenlesbare JSON-Ausgabe
- `MetadataService.swift` und `MetadataEntry.swift` in den CLI-Build aufgenommen

---

## 0.79.3
**Bugfix: Fuji Filmsimulation — alle Simulationen außer Provia wurden nicht erkannt**

- Ursache: Die TIFF-IFD-Navigation (IFD0 → ExifIFD → MakerNote-Zeiger) schlug bei vielen Dateien still fehl; da 0x0000 (Provia) dem Rückgabewert 0 bei Out-of-Bounds-Reads entspricht, schien nur Provia zu funktionieren
- Lösung: TIFF-Navigation vollständig ersetzt durch direkte Suche nach der „FUJIFILM"-Byte-Signatur im Rohdaten-Buffer — kein IFD-Traversal mehr nötig
- Alle Fuji-Dateien werden beim nächsten App-Start erneut gescannt (Migration v3)

---

## 0.79.2
**Bugfix: Filmsimulation bei bereits gescannten Fuji-Dateien fehlte nach Update**

- Dateien, die unter v0.79.0 gescannt wurden, behielten leere Filmsimulations-Felder, weil die Migrations-Version nicht erhöht war — alle Fuji-Dateien werden beim nächsten App-Start erneut gescannt (Migration v2)

---

## 0.79.1
**Bugfix: Fuji Schwarz-Weiß-Filmsimulationen (Monochrome, Acros) wurden nicht erkannt**

- Monochrome, Monochrome+R/G/Ye-Filter, Acros und Acros+R/G/Ye-Filter haben im MakerNote-Tag 0x1401 Werte mit gesetztem High-Bit (≥ 0x8000) — diese wurden beim 16-Bit-Lesen abgeschnitten; Lesen auf UInt32-Maske umgestellt
- Zusätzlicher Fallback über `kCGImagePropertyExifMakerNote` (ImageIO) eingebaut: liefert den rohen MakerNote-Block direkt, ohne manuelles JPEG-Segment-Parsing
- Leselimit für eingebettete JPEG-Previews und JPEG-Dateien von 128 KB auf 512 KB erhöht
- Bestehende Fuji-Dateien werden beim nächsten App-Start automatisch neu gescannt (einmalige Migration via `filmSimParserVersion`)

---

## 0.79.0
**Feature: Fuji Filmsimulation — Filterkriterium und automatische Ordner**

- Fuji Filmsimulation wird jetzt aus RAW- und JPEG-Dateien von Fujifilm-Kameras ausgelesen (Provia, Velvia, Classic Chrome, Eterna, Acros u.v.m.)
- Die erkannte Simulation erscheint im Metadaten-Panel als „Filmsimulation"
- Neues Kriterium „Filmsimulation" in Intelligenten Ordnern — Dropdown mit allen 21 bekannten Simulationsnamen
- Neuer Kamera-Filter-Button in der Sidebar erstellt automatisch einen Intelligenten Ordner pro erkannter Simulation (Gruppe „Filmsimulationen")
- Bestehende Fuji-Dateien werden beim nächsten App-Start automatisch neu gescannt

## 0.78.4
**Bugfix: HDR-Ergebnis zu hell — Farbraum auf sRGB (gamma) zurückgestellt**

- HDR-Merge erzeugte überbelichtete Ausgaben, weil die Well-Exposedness-Funktion (σ=0.2, Mittlton 0.216) für lineares Licht falsch kalibriert war: Im linearen Farbraum deckt σ=0.2 zu großen Helligkeitsbereich ab und bevorzugt helle Pixel
- Farbraum-Verarbeitung auf **sRGB (gamma)** zurückgestellt — exakt wie im Mertens-Original-Paper und OpenCV MergeMertens; Well-Exposedness-Mittelpunkt wieder bei 0.5 (perceptual Mittlton in gamma)
- Guided Image Filter und Laplacian-Pyramid-Blending bleiben erhalten

---

## 0.78.3
**Bugfix: HDR-Halo-Artefakte — state-of-the-art Überarbeitung**

- **Lineares Licht** (größter Einzeleffekt): Bilder werden jetzt in linearem sRGB dekodiert statt in Gamma-sRGB. Gauß-Blur und Pyramid-Operationen in Gamma-Raum erzeugen physikalisch falsche dunkle Werte an Hell-Dunkel-Grenzen — ≈1⅓ Stop zu dunkel pro Stufe — was dunkle Halo-Kränze erzeugt. Gamma-Kodierung erfolgt erst beim 8-Bit-Output (IEC 61966-2-1)
- **Guided Image Filter** (He et al. 2013): Gewichtskarten werden edge-aware geglättet bevor sie in die Pyramide fließen. Der Filter nutzt das Graustufenbild als Guide — Gewichtsübergänge folgen damit Bildkanten statt eigene Halo-Formen zu bilden. Implementiert als O(N) separable Box-Blur-Approximation
- **Well-Exposedness-Mittelpunkt** auf lineares Licht angepasst (0.216 statt 0.5 — entspricht dem perceptual Mittlton in linearem Raum)
- **Laplacian Randpixel**: Edge-Extension statt Null-Auffüllung an Bildrändern

---

## 0.78.2
**Bugfix: Halo-Artefakte beim HDR-Merge behoben**

- Beim Zusammenführen von Belichtungen entstanden dunkle/helle Übergangszonen (Halos) — Ursache war der Lanczos-Upsampler im Laplacian-Pyramid-Blending: Lanczos hat negative Nebenkeulen, die beim `r − upsample(rBlurred)` Schritt als Ringing in die Residualdaten übernommen wurden
- Upsample jetzt mit bilinearer Interpolation (`kvImageNoFlags`) statt Lanczos (`kvImageHighQualityResampling`) — kein Ringing, saubere Übergänge
- Downsample nutzt jetzt 2×2-Box-Mittelwert statt Punkt-Sampling für genauere Gewichtskarten in der Pyramide

---

## 0.78.1
**Bugfix: HDR-Merge ohne abrupte Übergänge (Laplacian-Pyramid-Fusion)**

- Abrupte Pixelübergänge beim Reinzoomen behoben — Ursache war einfacher gewichteter Durchschnitt im Ortsbereich
- Algorithmus komplett neu: **Mertens Exposure Fusion mit Laplacian-Pyramid-Blending** (State of the Art für LDR-Ausgabe, identisch mit OpenCV MergeMertens und Photomatix Exposure Blending)
- Gewichte werden vollautomatisch aus Kontrast × Sättigung × Belichtung berechnet — kein manueller Sigma-Slider mehr nötig
- Sigma-Slider im Dialog entfernt, EV-Versatz weiterhin zur Information angezeigt
- Arbeitet in sRGB (Gamma) wie im Originalpaper spezifiziert; kein fehlerhaftes Linearisieren mehr

---

## 0.78.0
**Feature: HDR-Zusammenführung für Belichtungsreihen (Fuji BKT)**

- Mehrere Belichtungen (z. B. aus dem Fuji X-T4 BKT-Modus) können per Rechtsklick → „HDR zusammenführen…" zu einem Bild kombiniert werden
- EV-Versatz wird automatisch aus den EXIF-Daten gelesen (inkl. RAF auf macOS 12+)
- Bilder werden in linearem Licht normiert und EV-kalibriert zusammengeführt (physikalisch korrekt, kein Gamma-Fehler)
- Extended-Reinhard-Tone-Mapping erhält Mitteltöne und komprimiert Highlights sanft
- Belichtungstoleranz (σ) im Dialog einstellbar; Ergebnis als TIFF im selben Ordner
- Belichtungstoleranz (σ) einstellbar: engerer Wert bevorzugt exakt mittelgraue Pixel, größerer Wert weichere Übergänge
- Ergebnis wird als TIFF im selben Ordner gespeichert und automatisch importiert
- Fortschrittsanzeige in der Statusleiste während der Berechnung

---

## 0.77.1
**Bugfix: Falsches Bild nach Metadaten-Änderung in intelligentem Ordner**

- Wenn ein Bild durch eine Metadaten-Änderung (Bewertung, Flagge, Farbmarkierung) nicht mehr in einen intelligenten Ordner passt, springt der Fokus jetzt korrekt zum nächsten Bild in der aktuellen Reihenfolge (inkl. Zufalls-Sortierung) — anstatt zu einem falschen Bild zu springen

---

## 0.77.0
**Feature: Sortierung innerhalb jeder Ansicht**

- Bilder können jetzt in jeder Ansicht (Bibliothek, Alben, Ordner, intelligente Ordner) nach Kriterium sortiert werden
- Sortieroptionen: Name ↑/↓, Datum ↑/↓, Bewertung, Zufall
- Sortiermenü (↑↓-Symbol) erscheint in der Toolbar der Rasteransicht und der Detailansicht
- Zufalls-Sortierung bleibt stabil über Renders hinweg (kein Neuordnen beim Scrollen)

---

## 0.76.0
**Feature: Bildanzahl in der Seitenleiste & Drag-and-Drop Gruppen repariert**

- Alben, intelligente Ordner und Ordner zeigen jetzt die Anzahl der enthaltenen Bilder rechts in der Seitenleiste
- Drag-and-Drop von intelligenten Ordnern in Gruppen funktioniert jetzt zuverlässig — das Problem war ein UTI-Mismatch (`public.plain-text` vs. `public.utf8-plain-text`); es wird jetzt ein privater App-eigener Typ (`com.c0d3cru5h.iphoto.smartfolder-id`) verwendet

---

## 0.75.2
**Bugfix: Drag-and-Drop in Gruppen, Doppelklick und Crash-Log**

- Drag-and-Drop von intelligenten Ordnern in Gruppen funktioniert jetzt zuverlässig — auf macOS 11 liefert `loadItem` einen `NSString` statt `Data`; beide Fälle werden jetzt abgefangen
- Doppelklick in der Rasteransicht öffnet wieder die Detailansicht (auch in Album- und Ordner-Kontexten)
- Crash-Log-Rotation behoben: der Absturzbericht wird jetzt gelesen, bevor `Log.init()` die Logdatei eventuell rotiert (löscht) — leere Berichte werden damit verhindert

---

## 0.75.1
**Bugfix: Drag-and-Drop für iOrdner-Gruppen und Rastergröße**

- Drag-and-Drop von intelligenten Ordnern in Gruppen funktioniert jetzt korrekt — der Button-Gesture-Konflikt mit `onDrag` wurde behoben (Plain-View statt Button)
- Der Größenregler im Raster skaliert jetzt die Thumbnails selbst (Bild + Textzeile), nicht nur die äußere Box
- Die Thumbnail-Größe im Detail-Strip (untere Leiste) bleibt weiterhin fest auf 148 px

---

## 0.75.0
**Feature: Ladeindikator beim App-Start & schnelleres Starten**

- Beim App-Start erscheint in der linken Seitenleiste ein Ladeindikator „Bibliothek wird geladen…" mit einem Spinner
- Der Ladeindikator verschwindet automatisch, sobald die Bibliothek vollständig initialisiert ist
- `CatalogStore` (SQLite-Datenbank, Migrations, EXIF-Cache) wird jetzt im Hintergrund initialisiert statt auf dem Main-Thread — die UI ist sofort nach dem Start bedienbar
- Der bisherige Einfriereffekt (200–800 ms je nach Bibliotheksgröße) beim ersten Öffnen entfällt

---

## 0.74.0
**Feature: Rasteransicht für alle Kontexte & Drag-and-Drop für iOrdner-Gruppen**

- Rasteransicht ist jetzt in allen Kontexten verfügbar — nicht mehr nur in der Bibliothek, sondern auch in Alben, Ordnern und intelligenten Ordnern
- Umschalten zwischen Raster- und Detail-Ansicht per Toolbar-Button (Raster-Icon) in der oberen Leiste
- Neuer Größenregler in der Toolbar der Rasteransicht: Thumbnails können zwischen 80 und 400 px angepasst werden
- Intelligente Ordner können jetzt per Drag-and-Drop in eine Gruppe gezogen werden — einfach einen iOrdner auf einen Gruppen-Header ziehen
- Auf die Sektion „Intelligente Ordner" ziehen entfernt einen Ordner aus seiner Gruppe

---

## 0.73.0
**Feature: Alben als echte Systemordner mit Symlinks**

- Für jedes Album wird jetzt automatisch ein Ordner unter `~/Pictures/iPhoto/Alben/<Albumname>/` angelegt
- Der Ordner enthält Symlinks zu allen Fotos des Albums — so sind Alben direkt im Finder sichtbar
- Beim Erstellen, Umbenennen, Löschen und bei jeder Änderung der Album-Mitglieder wird der Ordner aktualisiert
- Bestehende Alben erhalten ihre Systemordner automatisch beim nächsten App-Start (rückwärtskompatibel)
- Die Bibliothek-Synchronisation überspringt `Alben/` genauso wie `Intelligente Ordner/`, um Symlinks nicht als echte Fotos zu importieren

---

## 0.72.0
**Feature: Einklappbare Seitenleisten-Sektionen**

- „Alben" und „Intelligente Ordner" in der Seitenleiste können jetzt einzeln ein- und ausgeklappt werden
- Chevron-Icon zeigt den aktuellen Zustand an (animiert)
- Gruppen innerhalb der intelligenten Ordner sind ebenfalls einklappbar
- Einrückung und Zustände bleiben innerhalb der Sitzung erhalten

---

## 0.71.0
**Feature: Gruppen für intelligente Ordner**

- Intelligente Ordner können jetzt in benannte Gruppen organisiert werden (Ordner in Ordnern)
- Im Sheet „Intelligenter Ordner bearbeiten" gibt es ein neues Feld „Gruppe" mit Freitexteingabe und Menü zur Auswahl bestehender Gruppen
- In der Seitenleiste werden Gruppen als aufklappbare Zeilen (Chevron + Ordner-Icon) angezeigt; Mitglieder werden eingerückt darunter aufgelistet
- Kontextmenü auf einer Gruppe: „Umbenennen" und „Auflösen" (Ordner werden ungrouped)
- Kontextmenü auf einem intelligenten Ordner: neuer Eintrag „In Gruppe verschieben" öffnet ein Sheet zur Gruppen-Auswahl oder -Erstellung
- Filesystem-Sync: Gruppenordner werden als Unterverzeichnis in `~/Pictures/iPhoto/Intelligente Ordner/GruppenName/` angelegt; beim Umbenennen oder Auflösen werden veraltete, leere Verzeichnisse automatisch bereinigt
- Rückwärtskompatibel: bestehende gespeicherte intelligente Ordner ohne Gruppe funktionieren weiterhin

---

## 0.70.1
**Bugfix: SIGSEGV durch Data-Race beim Synchronisieren intelligenter Ordner**

- `syncSmartFolderToFilesystem` las `collection.documents` von einem Background-Thread während Main gleichzeitig schrieb → Read-Write-Race auf Swift-Array-CoW-Buffer → Speicherkorruption → SIGSEGV (oft erst 2–3 s verzögert beim nächsten Album-Wechsel)
- Fix: Filterung (`collection.documents.filter { smartFolderMatches(...) }`) läuft jetzt immer auf dem Main-Thread; nur das langsame Filesystem-I/O (Symlinks anlegen/löschen) wird in den Background dispatched
- Zusätzlich: Bug im Symlink-Namens-Loop behoben — doppelte Dateinamen wurden nicht korrekt in `existingLinks` eingetragen, was beim nächsten Anlauf wieder den selben Namen produzieren konnte

---

## 0.70.0
**Feature: Seitenleisten-Scrolling & Seitenverhältnis-Presets beim Zuschnitt**

- Seitenleiste scrollt jetzt korrekt, wenn viele Alben/Ordner vorhanden sind
- Zuschnitt-Editor hat jetzt Seitenverhältnis-Presets: Frei, Original, 1:1, 4:3, 3:2, 16:9
- Aktiver Preset wird hervorgehoben; Auswahl eines Presets passt den Zuschnitt sofort an
- Beim freien Ziehen wird das gewählte Seitenverhältnis automatisch beibehalten
- „Zurücksetzen" setzt auch das Seitenverhältnis auf Frei zurück

---

## 0.69.1
**Bugfix: Fokus springt beim Filtern in intelligenten Ordnern auf das nächste Bild**

- Wenn ein Bild durch eine Bewertungs-/Flag-/Label-Änderung aus einem intelligenten Ordner herausfällt, wird sofort das nächste Bild in der Reihenfolge fokussiert (statt das ausgeblendete Bild weiter anzuzeigen)
- Fällt kein nächstes Bild, wird das vorherige gewählt
- Gilt auch für alle anderen Kontextwechsel (z.B. Kriterien-Änderung am Ordner)

---

## 0.69.0
**Feature: Intelligente Ordner als echte Systemordner**

- Jeder intelligente Ordner bekommt einen echten Ordner unter `~/Pictures/iPhoto/Intelligente Ordner/<Name>/`
- Der Ordner enthält Symlinks zu allen passenden Fotos — keine Kopien, keine Duplikate
- Wird automatisch aktualisiert beim Erstellen, Bearbeiten, Umbenennen, Löschen und beim Navigieren zum Ordner
- Beim Umbenennen wird der alte Ordner entfernt und ein neuer angelegt
- Der Bibliotheks-Watcher ignoriert dieses Verzeichnis (Symlinks werden nicht als Duplikate eingelesen)

---

## 0.68.1
**Feature: Album-Häkchen und Entfernen im Rechtsklick-Menü**

- Alben, in denen das Bild bereits enthalten ist, werden im Kontextmenü mit einem Häkchen markiert
- Klick auf ein bereits enthaltenes Album entfernt das Bild daraus (Toggle)
- „Aus Album entfernen" erscheint weiterhin direkt wenn man sich in einem Album befindet

---

## 0.68.0
**Feature: Bilder in 90°-Schritten drehen**

- Neue Schaltflächen „90° links drehen" und „90° rechts drehen" in der Toolbar und im Anpassungen-Panel
- Tastaturkürzel: ⌘[ (links) und ⌘] (rechts)
- Rotation wird als Anpassung gespeichert (Undo/Redo unterstützt) und beim Export angewendet
- Mehrfaches Drehen akkumuliert sich korrekt (0° → 90° → 180° → 270° → 0°)

---

## 0.67.3
**Bugfix: SIGSEGV bei schneller Navigation durch RAF-Bilder**

- Behoben: SIGSEGV wenn der Nutzer schnell durch Bilder navigiert und zwei Vollbild-Decodes gleichzeitig liefen
- Ursache: `loadCurrentImage` setzt `isLoadingFullRes=false` sofort zurück (für flüssige UX), der alte Hintergrund-Thread lief aber noch und belegte ~37–100 MB — der Guard im neuen `loadFullRes`-Aufruf passierte, beide Decodes liefen parallel → OOM
- Fix: `fullResDecodeSemaphore(value: 1)` serialisiert alle Vollbild-Decodes im BG-Task; stale Tokens werden nach dem Warten erkannt und `upgradeToFullResIfNeeded()` lädt das aktuelle Bild nach

---

## 0.67.2
**Bugfix: SIGSEGV/SIGILL beim Laden von Thumbnails neuerer Fujifilm-RAFs**

- Behoben: 3 Abstürze (SIGSEGV + SIGILL) beim Laden von 80px-Thumbnails aus RAF-Dateien mit großem embedded JPEG (>3 MB, z.B. neuere Fujifilm-Kameras)
- Ursache: `kCGImageSourceCreateThumbnailFromImageIfAbsent` nutzt ein eingebettetes EXIF-Thumbnail (9 KB) wenn vorhanden — fehlt dieses in neueren RAFs, dekodierte ImageIO das komplette JPEG (~52–100 MB Zwischenbild) → Speicherkorruption
- Fix: `kCGImageSourceCreateThumbnailFromImageAlways` — ImageIO nutzt immer JPEG-DCT-Sub-Sampling und respektiert die maximale Pixelgröße effizient (~1 MB Zwischenbild statt 100 MB)

---

## 0.67.1
**Bugfix: Absturz beim Entfernen von Kriterien in intelligenten Ordnern**

- Behoben: SIGILL beim Klick auf Minus-Button in einem intelligenten Ordner mit mehreren Kriterien
- Ursache: `ForEach` über Array-Indices — beim Entfernen eines Elements griff SwiftUI noch auf den verschobenen Index zu (Out-of-Bounds → Swift Bounds-Check → SIGILL)
- Fix: stabiles `ForEach` mit UUID-Identity + Custom Binding per Element + Löschung via `removeAll(where:)`

---

## 0.67.0
**Feature: Album-Filter in intelligenten Ordnern**

- Neues Kriterium „Album" in intelligenten Ordnern — Fotos lassen sich nach Zugehörigkeit zu einem Album filtern
- Operatoren: „ist" (Foto ist im Album) und „ist nicht" (Foto ist nicht im Album)
- Album wird per Dropdown aus allen vorhandenen Alben ausgewählt

---

## 0.66.0
**Feature: Datumsfilter mit dynamischen Zeiträumen in intelligenten Ordnern**

- Neues Kriterium „Aufnahmedatum" in intelligenten Ordnern — Fotos lassen sich jetzt nach EXIF-Aufnahmedatum filtern
- Operatoren: „ist vor", „ist nach", „liegt zwischen" (mit DatePicker) und „ist in" für dynamische Zeiträume
- Dynamische Zeiträume: Heute, Gestern, Diese Woche, Letzte Woche, Dieser Monat, Letzter Monat, Dieses Jahr, Letzte 7/30/90 Tage
- Abwärtskompatibel: bestehende gespeicherte intelligente Ordner werden weiterhin korrekt geladen

---

## 0.65.3
**Bugfix: Absturz beim Löschen eines aktiven Ordners behoben**

- Behoben: Ordner löschen während Thumbnails laden → navSelection wechselt zu Library → 100+ Thumbnail-Decodes mit je ~120 MB RAM → SIGILL
- `deleteWatchedFolder` entfernt jetzt die Bilder des gelöschten Ordners aus `collection.documents` — sie erschienen zuvor fälschlicherweise weiter in der Library
- `syncedFolderIDs` wird beim Löschen ebenfalls bereinigt, sodass der Ordner bei erneutem Hinzufügen korrekt neu synchronisiert wird

---

## 0.65.2
**Bugfix: SIGSEGV beim RAF-Thumbnail-Laden durch ~120 MB RAM-Spike behoben**

- Behoben: `CGImageSourceCreateThumbnailFromImageAlways` dekodierte das volle 7728×5152-Bild (~120 MB) nur um ein 80px-Thumbnail zu erzeugen — bei zwei parallelen Decodes ~240 MB Peak → SIGSEGV
- Fix: `CGImageSourceCreateThumbnailFromImageIfAbsent` nutzt jetzt das eingebettete EXIF-Thumbnail (IFD1, ~9 KB) direkt, ohne das Vollbild zu dekodieren

---

## 0.65.1
**Bugfix: SIGILL/SIGSEGV-Absturz beim Thumbnail-Laden behoben**

- Behoben: Bei schnellen SwiftUI-Re-Renders (z. B. nach Inspector-Änderungen) wurde dasselbe Bild bis zu 7× gleichzeitig als 160px-Thumbnail dekodiert — das führte zu Speicherüberlauf und anschließendem SIGILL/SIGSEGV/SIGABRT
- `requestVisibleThumbnail` prüft jetzt per `hiResInFlight`-Set, ob ein 160px-Decode bereits läuft, und überspringt doppelte Anfragen

---

## 0.65.0
**Feature: Lazy Thumbnail-Loading — nur sichtbare Bilder laden**

- Thumbnails werden jetzt nur noch für den aktuell ausgewählten Ordner/Album geladen, nicht mehr für die gesamte Bibliothek
- EXIF-Metadaten werden weiterhin für alle Bilder im Hintergrund gescannt (damit intelligente Ordner korrekt funktionieren)
- Beim Wechsel des Ordners/Albums werden automatisch die Thumbnails des neuen Kontexts nachgeladen
- Deutlich geringerer Speicherverbrauch und schnellerer Start bei großen Bibliotheken

---

## 0.64.1
**Bugfix: Fujifilm Auto-DR-Modus jetzt als HDR erkannt**

- Behoben: Bilder im automatischen DR-Erweiterungsmodus (Tag `0x140B` – `AutoDynamicRange`) wurden nicht als HDR erkannt — jetzt wird zusätzlich zu `0x1403` auch `0x140B` ausgewertet
- Alle betroffenen RAF-Dateien in bestehenden Bibliotheken werden automatisch neu gescannt

---

## 0.64.0
**Feature: Fujifilm MakerNote HDR-Erkennung + HDR-Badge im Bild**

- Behoben: Fujifilm-RAFs wurden nie als HDR erkannt — das Standard-EXIF-Feld `CustomRendered` gibt bei Fujifilm immer „Normal" zurück; stattdessen wird jetzt der MakerNote-Tag `0x1403` (`DevelopmentDynamicRange`) im Fujifilm-IFD geparst (Werte 200/400/800 = DR-Erweiterungsmodus = HDR)
- Im Vorschau-Bereich erscheint oben rechts ein oranger „HDR"-Badge, wenn das aktuelle Bild als HDR erkannt wurde
- Bestehende Bibliotheken werden beim nächsten EXIF-Scan automatisch neu ausgewertet (Spalte `hdr` in der Datenbank wird korrekt befüllt)

---

## 0.63.0
**Feature: HDR-Erkennung via EXIF `CustomRendered`**

- Bilder mit HDR-Aufnahme werden automatisch erkannt: der EXIF-Wert `CustomRendered ≥ 2` (Werte 6 = HDR nicht final, 7 = HDR final, wie von Fujifilm, Sony und anderen Kameras geschrieben) markiert ein Bild als HDR
- Im Inspector (Metadaten-Tab) erscheint bei HDR-Fotos der Eintrag „HDR: Ja" im Kamera-Abschnitt — Standard-Fotos zeigen dieses Feld nicht
- Intelligente Ordner unterstützen jetzt das Kriterium „HDR" (ist / ist nicht) — damit lassen sich z.B. alle HDR-Aufnahmen in einem Ordner zusammenfassen
- Beim EXIF-Scan (`scanExifForLibrary`) wird `CustomRendered` mit gespeichert und in der Katalog-Datenbank in der neuen Spalte `hdr` hinterlegt; bestehende Bilder werden automatisch neu gescannt

---

## 0.62.2
**Bugfix: SIGSEGV beim Öffnen intelligenter Ordner — EXIF-Cache verhindert blockierende SQLite-Lesevorgänge auf dem Main-Thread**

- Behoben: App crashte reproduzierbar beim Öffnen eines intelligenten Ordners — `smartFolderMatches` rief bei jeder SwiftUI-Neuzeichnung `CatalogStore.exif(forPath:)` auf, das via `queue.sync` synchron SQLite vom Main-Thread las. Während des Thumbnail-Ladens (100+ Thumbnail-Completions) bedeutete das 30.000+ blockierende DB-Zugriffe pro Sekunde auf dem Main-Thread → Deadlock-Risiko → SIGSEGV
- `CatalogStore` lädt jetzt beim Start alle EXIF-Daten aus der Datenbank in einen in-memory Cache (`[String: ExifEntry]`, geschützt durch `NSLock`). `exif(forPath:)` gibt Cache-Treffer ohne Queue-Zugriff zurück; neue Werte werden via `upsertExif` sofort in beide Orte geschrieben

---

## 0.62.1
**Bugfix: SIGABRT/SIGSEGV nach `loadFullRes`-Completion + Blenden-Picker + i-Ordner-Bearbeitungsdialog + Ladebalken in Sidebar**

- Behoben: `ImageCollection.update(document:at:)` und `appendDocuments(_:)` schachteln ihre SwiftUI-`@Published`-Mutationen nicht mehr in `DispatchQueue.main.async` — die vorherige Implementierung akkumulierte bei schneller Navigation N×37 MB CGImage-Closures im Main-Queue-Puffer → Speicherdruck → SIGABRT oder SIGSEGV auf dem Main-Thread
- Behoben: Blenden-Picker in intelligenten Ordnern zeigte dreifach „f/1" (alle Werte < 2.0 wurden auf 1 gerundet) und wissenschaftliche Notation für f/11, f/16, f/22 (`%.1g` = 1 signifikante Stelle) — ersetzt durch korrekte Formatierung: ganzzahlige Werte ohne Dezimalstelle, Dezimalwerte mit einer Stelle
- Behoben: Bearbeitungsdialog für intelligente Ordner öffnete manchmal leer statt mit vorhandenen Feldern — SwiftUI-Timing-Problem bei gleichzeitigem `editingSmartFolder = sf; showSmartFolderSheet = true`; umgestellt auf `.sheet(item:)` mit `SmartFolderSheetItem` (Identifiable) — Dialog ist jetzt immer korrekt vorausgefüllt
- Ladebalken (EXIF-Scan, Thumbnail-Laden) aus dem Haupt-Viewer in die linke Sidebar verschoben

---

## 0.62.0
**Feature: EXIF-Metadaten-Scan beim Start + Brennweite-Speicherfehler behoben**

- Beim Öffnen einer Bibliothek werden EXIF-Daten aller Bilder (Brennweite, ISO, Blende, Objektiv) im Hintergrund gelesen und in der Katalog-Datenbank gespeichert — der Fortschritt wird im Ladebalken angezeigt
- Intelligente Ordner filtern jetzt nach Brennweite/ISO/Blende/Objektiv/Kamera auch ohne die Bilder vollständig zu laden — Metadaten werden direkt aus der SQLite-Datenbank abgerufen
- Behoben: Werte für Brennweite (und andere numerische Felder) in intelligenten Ordnern wurden nicht gespeichert, wenn der Benutzer direkt auf „Speichern" klickte ohne die Eingabe zu bestätigen (TextField-Commit-Bug auf macOS)

---

## 0.61.5
**Bugfix: SIGILL durch doppelten Vollbild-Ladeauftrag bei mehrfachem `loadCurrentImage`-Aufruf**

- `loadCurrentImage` plante bei jedem Aufruf einen neuen `asyncAfter(1.5)`-Dwell-Timer für `loadFullRes` — wenn die Funktion mehrfach aufgerufen wurde (z. B. via SwiftUI-Observer), liefen zwei Vollbild-Decodes gleichzeitig → Speicherkorruption → SIGILL auf dem Main-Thread
- Dwell-Timer wird jetzt als `DispatchWorkItem` (cancellable) verwaltet: jeder neue `loadCurrentImage`-Aufruf cancelt den vorherigen Timer, bevor ein neuer gesetzt wird — zu jedem Zeitpunkt ist nur ein Dwell-Timer aktiv

---

## 0.61.4
**Bugfix: SIGSEGV durch `prefetchAdjacent()` nach `loadFullRes`-Abschluss**

- `loadFullRes`-Completion rief `prefetchAdjacent()` auf — startete unmittelbar einen weiteren Full-Decode (~111 MB) für das Nachbar-Bild; bei Navigation startete `loadFullRes` für das neue Bild → beide in `applyExifOrientation` gleichzeitig → Speicherkorruption → SIGSEGV
- `prefetchAdjacent()` komplett entfernt — die 1500px-Preview (via `CGImageSourceCreateThumbnailAtIndex`) lädt bereits sehr schnell und macht Prefetch überflüssig; dafür wird `evictDistantImages()` am Ende der Completion aufgerufen

---

## 0.61.3
**Bugfix: SIGKILL (OOM) durch unbegrenzte parallele Metadaten-Reads + übermäßig großes JPEG-Read**

- `loadMetadataInBackground()` spawnte einen Background-Task **pro Dokument** ohne Semaphore — bei 200 RAF-Dateien liefen 200 Tasks gleichzeitig, jeder rief `rafEmbeddedJPEGProperties` auf und las ~5.5 MB JPEG-Daten → 200 × 5.5 MB = ~1.1 GB RAM für Metadaten allein → SIGKILL
- `rafEmbeddedJPEGProperties` liest jetzt nur die ersten **128 KB** des embedded JPEG (statt des gesamten ~5.5 MB-Bildes) — EXIF/IPTC/GPS-Daten stecken immer in den ersten APP-Segmenten (typisch 2–16 KB, max. 128 KB sicher)
- `loadMetadataInBackground` wird jetzt durch `metadataReadSemaphore(4)` auf 4 gleichzeitige Reads begrenzt
- `thumbnailDecodeSemaphore` von 4 auf 2 reduziert (zusätzliche Sicherheitsmarge)

---

## 0.61.2
**Bugfix: SIGSEGV durch gleichzeitige Full-Decodes in `loadFullRes` + `prefetchAdjacent`**

- `next()` und `previous()` riefen `prefetchAdjacent()` direkt nach `loadCurrentImage()` auf — `prefetchAdjacent()` startete sofort einen Full-Decode (~111 MB) für das Nachbar-Bild; 1,5 s später feuerte der Dwell-Timer `loadFullRes` für das aktuelle Bild → zwei gleichzeitige Full-Decodes (je ~111 MB = ~222 MB Peak) → Speicherkorruption → SIGSEGV auf dem Main-Thread
- `prefetchAdjacent()` wird jetzt ausschließlich am Ende der `loadFullRes`-Completion aufgerufen — Prefetch startet erst nach Abschluss des aktuellen Full-Decodes; zu jedem Zeitpunkt läuft maximal ein Full-Decode

---

## 0.61.1
**Bugfix: SIGABRT/SIGSEGV durch übermäßigen RAM-Peak beim parallelen Thumbnail-Decode auf macOS 11**

- `decodeEmbeddedJPEG` dekodierte für jeden 80px/160px-Thumbnail das vollständige 4416×2944-JPEG (~37 MB) und erzeugte via `applyExifOrientation` nochmals ein CIImage + CGImage — insgesamt ~75–150 MB pro parallelem Thread; bei 8 gleichzeitigen Decodes bis zu 800 MB nur für Thumbnails → OOM → SIGABRT oder Speicherkorruption → SIGSEGV
- `decodeEmbeddedJPEG` nutzt jetzt `CGImageSourceCreateThumbnailAtIndex` mit `kCGImageSourceThumbnailMaxPixelSize` + `kCGImageSourceCreateThumbnailWithTransform` für den Thumbnail-Pfad — dekodiert direkt auf Zielgröße (≤ 1 MB), kein CIImage-Zwischenschritt mehr; EXIF-Rotation wird automatisch vom API übernommen
- `requestVisibleThumbnail` (160px-Thumbnails für sichtbare Zellen) fehlte jeder Semaphore — unbegrenzte parallele Decodes wurden durch denselben `thumbnailDecodeSemaphore` wie die Batch-Thumbnails begrenzt
- `thumbnailDecodeSemaphore` von 8 auf 4 reduziert; `ciSemaphore` von 4 auf 2 (nur noch für Vollbild-Decodes relevant)

---

## 0.61.0
**Feature: SD-Karten-Erkennung in der Sidebar + Ausrichtungsfilter für intelligente Ordner**

- Wechseldatenträger (SD-Karten, USB-Laufwerke) werden beim App-Start und beim Einlegen automatisch in einer neuen Sektion „Wechseldatenträger" in der Sidebar erkannt und angezeigt
- Bilder auf der Karte werden beim Anklicken des Eintrags geladen; ⏏-Button zum Auswerfen erscheint beim Hover
- Beim Auswerfen oder Abziehen werden die Bilder aus der Collection entfernt und die Auswahl springt zurück zur Bibliothek
- Intelligente Ordner: neues Kriterium „Ausrichtung" — filtert nach Hochformat oder Querformat

---

## 0.60.12
**Bugfix: Thread-Sicherheit in `ImageCollection`, `RatingStore` und `CatalogStore`**

- `ImageCollection.update(document:at:)` und `appendDocuments(_:)` wurden von Hintergrund-Threads aufgerufen und mutierten `@Published`-Properties außerhalb des Main-Threads — beide Methoden dispatchen jetzt via `DispatchQueue.main.async`, damit alle `@Published`-Änderungen korrekt auf dem Haupt-Thread landen
- `RatingStore.cache` (Dictionary) wurde ohne Synchronisierung von mehreren Threads gelesen und geschrieben — `NSLock` schützt jetzt alle Zugriffe auf `cache` und `loaded` in `load(for:)` und `save(_:for:)`
- `CatalogStore.saveAdjustments()` verwendete `queue.async` statt `queue.sync` — ein unmittelbar danach gerufenes `loadAdjustments()` konnte die noch nicht persistierten Daten lesen; jetzt wie alle anderen Schreib-Operationen `queue.sync`

---

## 0.60.11
**Bugfix: SIGSEGV durch doppelte `loadCurrentImage`-Hintergrundaufgaben beim schnellen Album-Wechsel**

- Bei schnellem Album-Wechsel wurden bis zu 7 gleichzeitige 1500px-Preview-Decode-Aufgaben für dieselbe Datei gestartet — `loadCurrentImage` prüfte nur ob `cgImage == nil`, nicht ob ein Decode bereits läuft; das Token-System verhinderte zwar doppelte UI-Updates, nicht aber den parallelen Speicherverbrauch
- 7 × ~30 MB CGImage + gleichzeitige Thumbnail-Loads = Speicherkorruption → SIGSEGV auf dem Main-Thread
- `previewLoadInFlight: Set<URL>` verhindert nun mehrere gleichzeitige 1500px-Decodes derselben URL; der Eintrag wird nach Abschluss des Background-Tasks via `defer` wieder entfernt

---

## 0.60.10
**Bugfix: Thread-sicherer Logger, atomarer Signal-Handler, gedrosseltes Thumbnail-Laden**

- `Log.trace()` rief `appendRaw()` direkt auf dem aufrufenden Hintergrund-Thread auf — ohne jede Serialisierung. 50+ Threads gleichzeitig → open/seek/write/close-Race → abgeschnittene und interleaved Log-Einträge; alle Writes (sync und async) laufen jetzt über die serielle Queue (`queue.sync` für `writeSync`, `queue.async` für `write`); persistentes `FileHandle` vermeidet das pro-Write open/close
- Signal-Handler rief `write()` viermal hintereinander auf → Log-Writes aktiver Hintergrund-Threads landeten zwischen den SIGNAL-Zeilen → `[SIGNAL_LAST_OP]` zeigte fälschlicherweise eine vollständige Log-Zeile; jetzt wird der gesamte SIGNAL-Block in einem Pre-Alloc-Buffer assembled und in einem einzigen `write()`-Aufruf geleert (O_APPEND-atomar)
- Signal-Handler feuerte von zwei Threads gleichzeitig (SIGABRT als prozessweites Signal) → `[SIGNAL_THREAD] background` erschien zweifach; `OSAtomicCompareAndSwap32`-Guard stellt sicher, dass nur der erste Thread Diagnostics schreibt
- `loadThumbnails()` dispatched alle ausstehenden Thumbnails ohne Limit gleichzeitig; 50 RAF-Dateien → ~1,5 GB RAM-Spitze → Allocator ruft `abort()` → SIGABRT; `thumbnailDecodeSemaphore(value: 8)` begrenzt parallele Decodes auf 8 (~240 MB Peak)

---

## 0.60.9
**Bugfix: SIGABRT durch Metal-Überlastung beim parallelen Thumbnail-Laden**

- `loadThumbnails()` dispatcht alle ausstehenden Thumbnails ohne Limit gleichzeitig; bei großen RAF-Alben (20+ Dateien) rief jeder Thread `makeCIContext()` auf — es entstanden 20+ GPU-Kontexte gleichzeitig → Metal erschöpfte seine Ressourcen und rief `abort()` auf → SIGABRT
- `CIContext` wird jetzt als gemeinsame Instanz (`sharedCIContext`) geteilt — laut Apple-Dokumentation ist `CIContext` thread-safe für Rendering-Operationen; der bisherige Ansatz (ein Context pro Thread) war die Ursache der GPU-Überlastung
- Semaphore begrenzt gleichzeitige GPU-Renders (`createCGImage`) auf 4 — schützt vor Metal-Absturz auch bei sehr großen Alben

---

## 0.60.8
**Bugfix: Data Race auf `loadToken` und ungeschützter ImageIO-Fallback in HotPixelAnalyzer**

- `loadFullRes()` las `self.loadToken` vom Background-Thread, während der Haupt-Thread gleichzeitig schrieb → klassischer Read-Write-Data-Race → Speicherkorruption → SIGSEGV mit Verzögerung (1–2 s nach erfolgreichem Decode sichtbar); Background-Thread-Check entfernt, Token-Validierung erfolgt ausschließlich auf dem Haupt-Thread
- `activeFullResToken` wurde im Verwerfen-Pfad des Haupt-Thread-Callbacks nicht zurückgesetzt → künftige `loadFullRes`-Aufrufe konnten am `activeFullResToken == nil`-Guard hängen bleiben; jetzt in allen Exit-Pfaden korrekt zurückgesetzt
- `HotPixelAnalyzer.decodeFrame()` fiel bei fehlgeschlagenem `CIFilter` auf `CGImageSourceCreateWithURL` zurück — auf macOS 11.7.x löst das den Apple Fujifilm-Plugin aus → SIGSEGV; der ImageIO-Fallback wird für RAF-Dateien auf macOS 11 übersprungen und fällt stattdessen auf den bereits vorhandenen `RAWImageDecoder`-Fallback durch

---

## 0.60.7
**Bugfix: SIGSEGV beim Lesen von RAF-Metadaten auf macOS 11**

- `MetadataService.readPhotoMetadata()` rief `CGImageSourceCreateWithURL` direkt auf RAF-Dateien auf — der Apple Fujifilm-RAW-Plugin crasht dabei auf macOS 11.7.x mit SIGSEGV
- Betroffen waren alle Codepfade, die nach einer erfolgreichen RAF-Dekodierung Metadaten lesen: `loadFullRes` (nach 1,5 s Dwell), `loadMetadataInBackground` und `loadCurrentImage` nach Album-Wechsel
- Auf macOS 11 wird die Metadata jetzt direkt aus dem eingebetteten JPEG-Preview des RAF-Headers gelesen (gleicher Pfad wie bei der Bilddarstellung); auf macOS 12+ bleibt das Verhalten unverändert

---

## 0.60.6
**Bugfix: SIGSEGV beim Thumbnail-Laden von RAF-Dateien auf macOS 11**

- `RAWImageDecoder.thumbnail()` fiel bei fehlgeschlagenem `decodeEmbeddedJPEG` auf den ImageIO-Pfad zurück — der Apple Fujifilm-RAW-Plugin crasht dort auf macOS 11.7.x mit SIGSEGV
- Der macOS-11-Guard war in `decode()` vorhanden (seit 0.60.2), aber nicht in `thumbnail()` — dadurch crashten Thumbnail-Ladeoperationen (80px, 160px, 1500px) beim Öffnen von RAF-Alben
- `thumbnail()` überspringt den ImageIO-Pfad für RAF auf macOS 11 jetzt genauso wie `decode()`

---

## 0.60.5
**Bugfix: Speichererschöpfung beim langen Browsen durch große Bildordner**

- `cgImage`- und `previewImage`-Objekte (je ~50 MB bei 4416×2944) wurden beim Navigieren nie aus dem Speicher entlassen — alle bisher besuchten Bilder blieben dauerhaft geladen
- Nach einigen Dutzend Bildern führte der Speicherdruck dazu, dass `CGImageSourceCreateImageAtIndex` auch für zuvor erfolgreich geladene Dateien (inkl. JPEGs) fehlschlug, gefolgt von SIGABRT oder SIGSEGV
- `evictFarImages()` wird jetzt bei jedem Bildwechsel aufgerufen und gibt `cgImage`/`previewImage` für alle Dokumente frei, die mehr als 3 Positionen vom aktuellen Bild entfernt sind
- Thumbnails bleiben erhalten; beim Zurückblättern zu einem eviktierten Bild wird es neu geladen

---

## 0.60.4
**Bugfix: Karte leeren trotz fehlgeschlagenem Import verhindert**

- `wipeFolder` prüft jetzt vor dem Löschen, ob alle Bilddateien auf der Karte im Zielordner vorhanden sind — fehlt auch nur eine Datei, wird der Vorgang mit einer Fehlermeldung abgebrochen
- Beim Import werden fehlgeschlagene Kopiervorgänge separat gezählt; `completedImports` (und damit der „Karte leeren"-Button) wird nur gesetzt, wenn alle Dateien erfolgreich übertragen wurden
- Verhindert Datenverlust durch stille Kopierfehler (z. B. bei vollem Speicher oder Berechtigungsproblemen)

---

## 0.60.3
**Bugfix: Kontextmenü-Export ignorierte Mehrfachauswahl**

- Rechtsklick → „Exportieren..." auf einem bereits markierten Thumbnail hat die Mehrfachauswahl durch eine Einzelauswahl ersetzt — dadurch wurde nur ein Bild exportiert
- Die Auswahl bleibt jetzt erhalten wenn das angeklickte Bild Teil der aktuellen Mehrfachauswahl ist
- Kontextmenü-Eintrag zeigt bei Mehrfachauswahl die Anzahl der Bilder an: „X Bilder exportieren..."

---

## 0.60.2
**Bugfix: SIGSEGV beim Öffnen von RAF-Dateien auf macOS 11**

- `RAWImageDecoder.decode()` überspringt auf macOS 11 den ImageIO-Pfad für RAF-Dateien — der System-RAW-Decoder von Apple crashte dort konsistent mit SIGSEGV
- Auf macOS 11 wird direkt der Embedded-JPEG-Preview aus dem RAF-Header verwendet (gleicher Pfad wie bei Thumbnails)
- Auf macOS 12+ bleibt das Verhalten unverändert (ImageIO mit nativem RAW-Decoder)

---

## 0.60.1
**Refactoring & Bugfixes: ViewModel-Aufteilung, Fehlerbehandlung, Navigation**

- `ImageViewModel` (2158 Zeilen) in vier fokussierte Extension-Dateien aufgeteilt: `+Library`, `+Loading`, `+Adjustments`, `+Save` — bessere Übersichtlichkeit und Wartbarkeit
- Alle stillen Schreibfehler (Albums, SmartFolders, beobachtete Ordner, Rezept-Export) zeigen jetzt eine Fehlermeldung
- Fehlerbehandlung bei Undo/Redo und Version-Revert ergänzt
- SmartFolder-Kriterien-Änderung aktualisiert die Ansicht sofort — das aktuelle Bild wird automatisch deselektiert wenn es nicht mehr passt
- `autoreleasepool` in Thumbnail-Lade-Loops verhindert Speicherspitzen im Hintergrund
- Force-Unwrap in Thumbnail-Task-Callback behoben (potentieller Crash)
- Thumbnail-Strip scrollt beim Öffnen einer Detail-Ansicht automatisch zum aktuellen Bild
- Shift+Pfeiltasten erweitert die Auswahl im Thumbnail-Strip
- SQLite-Index auf `filename`-Spalte für schnelleres Sortieren

---

## 0.60.0
**Bugfix: SIGSEGV beim schnellen Navigieren durch RAW-Dateien**
- `CIContext` war ein globaler Singleton und wurde von mehreren Background-Threads gleichzeitig verwendet (nicht thread-safe) — jeder Decode-Vorgang erstellt jetzt seinen eigenen Context.
- `isLoadingFullRes` konnte durch veraltete Callbacks fälschlicherweise zurückgesetzt werden und parallele Full-Res-Dekodierungen ermöglichen — fixiert mit tokenbasiertem `activeFullResToken`-Guard.
- `loadCurrentImage()` wird für dieselbe URL nicht mehr mehrfach parallel ausgeführt.
- Kontextmenü: „In Papierkorb" für Thumbnails (Einzel- und Mehrfachauswahl).

---

## 0.59.0
**Feature: Externe Datenträger importieren immer in iPhoto-Bibliothek**
- Beim Hinzufügen eines Wechselmediums (USB, SD-Karte) wird `~/Pictures/iPhoto` automatisch als Importziel gesetzt.
- Das Importziel für Wechselmedien kann nicht mehr manuell geändert werden — „Importziel festlegen" und „Importziel entfernen" erscheinen im Kontextmenü nur noch für normale Ordner.
- „Jetzt importieren" ist für Wechselmedien immer direkt verfügbar.

---

## 0.58.0
**Feature: Erweiterte Smart-Ordner-Kriterien**
- Neue Attribute: ISO, Brennweite, Blende, Objektiv, Dateiname, Dateityp (RAW/Nicht-RAW), Bewertung.
- Neuer Operator-Picker pro Kriterium: „ist", „ist nicht", „enthält", „beginnt mit", „endet mit", „größer als", „kleiner als", „im Bereich".
- Bereichsfilter für numerische Werte (z.B. ISO 400–1600, Blende f/1.4–f/2.8).
- RAF-EXIF-Fallback: Kamera-Metadaten werden jetzt auch auf macOS 11 korrekt aus eingebetteten JPEG-Previews gelesen.
- `readUInt32BE` in eigene `Data+Extensions.swift` ausgelagert.

---

## 0.57.0
**Feature: ~/Pictures/iPhoto als Standard-Bibliotheksordner**
- Beim ersten Start wird `~/Pictures/iPhoto` automatisch angelegt und als Watched Folder eingerichtet.
- Der Ordner erscheint immer in der Sidebar mit eigenem Icon und kann nicht entfernt werden.
- Alle importierten Bilder können dort zentral gespeichert werden.

---

## 0.56.0
**Feature: Lazy Loading — Bilder erst beim Navigieren laden**
- Beim App-Start werden keine Bilder mehr automatisch geladen.
- Thumbnails und Ordner-Inhalte werden erst geladen wenn der Nutzer Library, einen Ordner, ein Album oder einen Smart-Ordner anklickt.
- Verbessert den Start drastisch bei großen Bibliotheken.

---

## 0.55.0
**Feature: Einheitliche Ladefortschrittsleiste am unteren Rand**
- Thumbnails und Sync-Vorgänge erscheinen jetzt in einer gemeinsamen Warteschlange unten in der App.
- Die Leiste zeigt Icon, Beschriftung (z. B. „Lade Thumbnails" / „Synchronisiere 'SONY'"), Fortschrittsbalken und Zähler.
- Laufen mehrere Vorgänge gleichzeitig, wird einer angezeigt und der Rest mit „+N weitere" gekennzeichnet.

---

## 0.54.0
**Feature: SD-Karte nach Sync leeren**
- Nach einem erfolgreichen Import von einer SD-Karte / einem Wechselmedium erscheint ein roter "Karte leeren"-Button direkt im Sync-Panel.
- Ein Bestätigungsdialog zeigt die genaue Anzahl der Bilddateien vor dem Löschen.
- Alle Bilddateien auf dem Medium werden unwiderruflich gelöscht (Nicht-Bilddateien bleiben erhalten).

---

## 0.53.0
**Feature: Kontextmenü auf Thumbnails**
- Rechtsklick auf ein Thumbnail öffnet ein Menü mit: Pick/Abgelehnt setzen, Bewertung (1–5 Sterne), Farblabel, Exportieren, Im Finder zeigen, Album-Aktionen, Aus Sammlung entfernen.
- Farblabel wird jetzt auch im macOS Finder gesetzt (via `URLResourceKey.labelNumberKey`).
- Bei Mehrfachauswahl werden Aktionen auf alle markierten Bilder angewendet.

---

## 0.52.1
**Bugfix: Thumbnail-Ladefortschritt zeigt korrekte Zahlen**
- Der Fortschrittszähler (z. B. „1000/9250") war stark überhöht, weil noch ladende Bilder bei jedem erneuten Aufruf doppelt gezählt wurden.
- Neu: In-Flight-Tracking verhindert, dass dasselbe Bild mehrfach in die Warteschlange kommt.

---

## 0.52.0
**Feature: iTunes-Style Filter in Intelligenten Ordnern**
- Kriterien bestehen jetzt aus drei Teilen: Attribut-Picker → Operator-Picker → Wert.
- Operator passt sich automatisch dem Attribut an: Text-Attribute bieten „enthält / ist / beginnt mit / endet mit", numerische Attribute „ist größer als / ist im Bereich" usw., Enum-Attribute nur „ist / ist nicht".
- Bei „ist im Bereich" erscheinen zwei Felder (von / bis).
- Neue Attribute: Bewertung, ISO, Brennweite, Blende, Objektiv, Dateiname, Dateityp, Farblabel.

---

## 0.51.0
**Feature: Erweiterte Filter für Intelligente Ordner**
- Neue Filterkriterien: Objektiv, ISO (mindestens/höchstens), Brennweite (ab/bis), Blende (offen bis / geschlossen ab), Dateiname enthält, Dateityp (RAW / nicht RAW).
- Blende wird als Picker mit Standard-f-Werten angeboten (f/1.0 bis f/22).
- ISO und Brennweite werden als Zahlenfeld eingegeben.

---

## 0.50.1
**Bugfix: RAF-Metadaten korrekt gelesen + Metadaten beim Start vorgeladen**
- RAF-Dateien: Metadaten werden jetzt aus dem eingebetteten JPEG-Preview extrahiert, falls ImageIO keine vollständigen EXIF-Daten liefert (betrifft besonders macOS 11).
- Metadaten aller Bilder werden beim Import im Hintergrund vorgeladen – kein Warten mehr auf das Vollbild nötig, um Kamerainfo/Datum zu sehen.
- In `loadFullRes` werden bereits geladene Metadaten nicht mehr doppelt gelesen.

---

## 0.50.0
**Feature: Mehrfachmarkierung als Pick / Ablehnen**
- Wenn mehrere Bilder per Cmd+Klick oder Shift+Klick ausgewählt sind, setzt `P` (Pick) oder `X` (Ablehnen) den Status für alle markierten Bilder gleichzeitig.
- Sind alle markierten Bilder bereits mit dem gleichen Status versehen, wird er entfernt (Toggle).

---

## 0.49.1
**Bugfix: Sync springt nicht mehr zur neu hinzugefügten Datei**
- Beim automatischen Sync von überwachten Ordnern bleibt die aktuelle Bildauswahl erhalten. Nur beim manuellen Import per Dialog oder Drag & Drop wird das erste neue Bild automatisch fokussiert.

---

## 0.49.0
**Feature: Doppelklick im Library-Grid öffnet Bild in der Fokus-Ansicht**
- Doppelklick auf ein Bild im Library-Grid wechselt in die Detail-Ansicht (Viewer + Strip). Ein neuer Toolbar-Button (Raster-Symbol) führt zurück zur Bibliothek. Beim Wechsel in ein Album oder einen Ordner wird die Fokus-Ansicht automatisch geschlossen.

---

## 0.48.0
**Feature: Library-Ansicht zeigt jetzt ein Vollbild-Raster**
- Klick auf "Library" in der Sidebar zeigt alle Bilder in einem adaptiven LazyVGrid statt der Detail+Strip-Ansicht. Album-, Ordner- und Smart-Ordner-Ansichten behalten das bisherige Layout (Detail-Viewer + horizontaler Strip unten). Auswahl (Cmd/Shift-Klick), Kontextmenü und Drag & Drop funktionieren im Grid-View.

---

## 0.47.12
**Bugfix: SIGSEGV mit geöffnetem Analyse-Tab beim Bildwechsel (Bug #8)**
- `AnalysisEngine.analyze()` las `self.token` im Background-Thread (Zeile 95), während der Main-Thread gleichzeitig `token = UUID()` schrieb. Read-Write-Data-Race → Speicherkorruption → SIGSEGV. Eingeführt in 0.47.3 beim Verbinden der AnalysisEngine mit SwiftUI `onChange`-Callbacks. Fix: Token-Prüfung aus dem Background-Thread entfernt — die Prüfung auf dem Main-Thread (letzter Guard vor dem Publishen der Ergebnisse) ist ausreichend.

---

## 0.47.11
**Bugfix: Anpassungen-Tab zieht den Inspector nicht mehr auf volle Fensterbreite**
- Die drei Buttons ("Zurücksetzen", "Kopieren", "Einfügen") verwendeten den macOS-Default-`ButtonStyle` mit 13pt-Font und System-Mindestbreite — zusammen ca. 282pt, mehr als die 248pt die im 280pt-Inspector nach dem Padding bleiben. `.frame(maxWidth: .infinity)` gibt diesen Überlauf nach oben weiter statt ihn zu kappen. Fix: `PlainButtonStyle()` + `.font(.caption)` auf den Buttons-HStack. Zusätzlich `.clipped()` auf den InspectorView-Container als Schutz vor zukünftigen Overflows.

---

## 0.47.10
**Bugfix: Inspector-Tabs laufen nicht mehr über den Rand (Root Cause)**
- Der `VStack` innerhalb des `ScrollView(.vertical)` im Inspector hatte kein `.frame(maxWidth: .infinity)`. SwiftUI misst in diesem Fall den VStack nach idealen Inhaltsbreiten statt nach der angebotenen ScrollView-Breite — macOS-Slider-Controls haben eine System-Idealbreite >280pt und ziehen den gesamten Inspector mit. Fix: `.frame(maxWidth: .infinity)` auf den ScrollView-VStack in `InspectorView` und auf den äußeren VStack in `AnalysePanel`.

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
