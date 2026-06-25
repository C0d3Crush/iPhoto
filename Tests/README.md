# iPhoto – Tests

## Alle Tests ausführen

```bash
./Tests/run_library.sh   # Bibliotheks-Skalierungstest
./Tests/run_bench.sh     # Performance-Benchmarks
./Tests/run_catalog.sh   # SQLite-Katalog-Tests
./Tests/test_formats.sh  # Export-Format-Regression
```

Voraussetzung: macOS Command Line Tools (`xcode-select --install`).  
Kein Xcode, kein Swift Package Manager — alles wird direkt via `swiftc` kompiliert.

---

## run_library.sh — Bibliotheks-Skalierungstest

**Was wird getestet:** Verarbeitung großer Bildbibliotheken (10 / 100 / 500 / 1000 Bilder).

**Kompilierte Dateien:** `RAWImageDecoder.swift`, `ImageExporter.swift`, `Log.swift`, `BookmarkStore.swift`, `Tests/library/main.swift`

| Sektion | Was geprüft wird | Schwellwert |
|---------|-----------------|-------------|
| 1 Thumbnail sequenziell | Durchsatz 160 px, ein Thread | ≥ 100 Bilder/s |
| 2 Thumbnail parallel | Speedup durch 8 Threads | ≥ 2× Speedup |
| 3 Vorschau parallel | Durchsatz 1500 px | ≥ 5 Bilder/s |
| 4 Vollbild-Decode | Sequenziell bis 100 Bilder | ≥ 1 Bild/s |
| 5 Batch-Export JPEG | Parallel 8 Threads | ≥ 1 Bild/s |
| 6 Speicher-Skalierung | RAM-Verbrauch je Bild | < 10 MB/Bild |
| 7 Stabilitätstest | 1000 × Thumbnail + Vorschau + Export gleichzeitig | 0 Fehler |

**FAIL bedeutet:** Durchsatz zu niedrig, Speicher zu hoch oder Dekodierung/Export schlägt fehl.  
Laufzeit: ~5–7 Minuten (dominiert von Sektion 7: 1000 Export-Operationen parallel).

---

## run_bench.sh — Performance-Benchmarks

**Was wird getestet:** Absolute Geschwindigkeit der Kern-Operationen, gemessen an 3 Bildgrößen.

**Kompilierte Dateien:** `RAWImageDecoder.swift`, `ImageExporter.swift`, `Log.swift`, `BookmarkStore.swift`, `Tests/bench/main.swift`

| Benchmark | 2 MP | 12 MP | 24 MP |
|-----------|------|-------|-------|
| Decode JPEG | < 500 ms | < 1500 ms | < 2500 ms |
| Decode PNG | < 800 ms | < 2500 ms | < 4000 ms |
| Thumbnail 160 px | < 300 ms | < 300 ms | < 300 ms |
| Thumbnail 1500 px | < 500 ms | < 1200 ms | < 2000 ms |
| Export JPEG | < 600 ms | < 1800 ms | < 3000 ms |
| Export PNG | < 1500 ms | < 4000 ms | < 6000 ms |
| Export TIFF | < 1500 ms | < 4000 ms | < 6000 ms |

Ausgabe: Min / Avg / Median / p95 / Max pro Benchmark.  
**FAIL bedeutet:** Avg-Wert überschreitet die Schwelle (alle anderen Statistiken sind informativ).  
Laufzeit: ~1–3 Minuten.

---

## run_catalog.sh — SQLite-Katalog-Tests

**Was wird getestet:** Korrektheit und Robustheit von `CatalogStore`.

**Kompilierte Dateien:** `Sources/Utilities/CatalogStore.swift`, `Tests/catalog/main.swift`

| Test | Was geprüft wird |
|------|-----------------|
| 1 Schema-Init | DB-Datei wird angelegt, alle 4 Tabellen vorhanden |
| 2 Upsert Image | Einfügen und Abrufen per Pfad; allImages() |
| 3 Duplikat-Handling | Gleicher Pfad → UPDATE statt Fehler; removeImage() |
| 4 Rating CRUD | Speichern, Überschreiben, Löschen |
| 5 Album CRUD | Album erstellen/umbenennen/löschen; Fotos hinzufügen/entfernen; ON DELETE CASCADE |
| 6 Suche | Dateiname-Suche; Flag-Filter; Rating-Mindest-Filter |
| 7 Performance | 10.000 batchUpsertImages() in < 2 s |
| 8 Concurrent | 8 Threads gleichzeitig schreiben/lesen — kein Crash, alle 800 Bilder vorhanden |
| 9 Migration | Frische DB ohne albums.json → kein Fehler, leere Tabellen |
| 10 Persistenz | DB schließen und neu öffnen → alle Daten noch vorhanden |

**FAIL bedeutet:** Falsches Ergebnis, fehlende Daten, Crash oder Timeout.  
Laufzeit: < 30 Sekunden.

---

## test_formats.sh — Export-Format-Regression

**Was wird getestet:** CLI-Tool `build/iphoto-cli` exportiert alle Formate korrekt.

Voraussetzung: `./build.sh` muss vorher ausgeführt worden sein.

| Test | Was geprüft wird |
|------|-----------------|
| JPEG-Export | Ausgabedatei existiert und hat Inhalt |
| PNG-Export | Ausgabedatei existiert und hat Inhalt |
| TIFF-Export | Ausgabedatei existiert und hat Inhalt |
| HEIF-Export | Als SKIP markiert (benötigt Display-Server) |
| Batch a | Zwei Dateien gleichzeitig exportieren |
| Batch b | Export in Ausgabeverzeichnis |
| info-Kommando | Zeigt Bildgröße und Dateiformat |

**FAIL bedeutet:** `iphoto-cli` gibt Exit-Code ≠ 0 zurück oder Ausgabedatei fehlt.  
Laufzeit: < 10 Sekunden.

---

## Hinweise

- Alle Test-Binaries werden nach dem Lauf automatisch gelöscht (`rm -f "$BIN"`)
- Temporäre Testbilder und Verzeichnisse werden ebenfalls bereinigt
- Test-Ausgaben gehen auf stdout; Fehlermeldungen auf stderr
- Exit-Code 0 = alle Tests bestanden, Exit-Code 1 = mindestens ein FAIL
