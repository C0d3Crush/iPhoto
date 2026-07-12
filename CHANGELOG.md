# iPhoto – Release Notes

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
