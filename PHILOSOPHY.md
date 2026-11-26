# Philosophie — Photo α

> Diese Datei hält die Grundsatzfragen fest, die hinter jeder Architektur- und Produktentscheidung stehen.  
> Offene Fragen (`**Status:** offen`) werden vom Dokumentations-Agenten beantwortet, sobald ausreichend Code-Kontext vorhanden ist.  
> Beantwortete Fragen (`**Status:** beantwortet`) werden aktualisiert, wenn sich die Realität ändert.

---

## 1. Produktphilosophie

### F: Warum Fuji-first statt Allround-Editor?
**Status:** beantwortet

Fuji-Shooter haben einen spezifischen Schmerz: Sie lieben Film-Simulationen und Rezepte, aber kein Tool bedient diesen Fokus nativ und kostenlos. Lightroom ist gut, kostet aber Abo. Capture One kann Fuji, ist aber teuer. darktable ist mächtig, aber berüchtigt komplex in der UX.

Gleichzeitig löst Apples `CIRAWFilter` das harte X-Trans-Demosaicing-Problem von Haus aus — das technische Haupthindernis, an dem viele Tools scheitern, fällt für eine native macOS-App weg. Dieser Stack-Vorteil kombiniert mit Fuji-Spezialisierung (Rezepte, Film-Look, EXIF-Auswertung) ergibt eine scharfe Differenzierung, die mit Allround-Ambition sofort verwässert würde.

**Konsequenz:** Jede Feature-Entscheidung wird gefiltert durch: „Hilft das einem Fuji-Shooter?" Wenn nein, gehört es nicht ins Kern-Produkt.

---

### F: Warum kein Abo, warum Freeware?
**Status:** beantwortet

Das Abo-Modell erzeugt strukturellen Interessenkonflikt: Der Hersteller gewinnt, wenn Nutzer zahlen, nicht wenn sie Fotos machen. Freeware dreht diesen Anreiz um — die App muss gut genug sein, dass Nutzer sie freiwillig empfehlen und (optional) unterstützen.

Für die Fuji-Community, die ohnehin schon gegen Lightroom-Abos rebelliert, ist „gratis + lokal + kein Account" ein echter, kommunizierbarer Wert — kein Marketing-Versprechen. Der Rezept-Sharing-Effekt (jedes geteilte Rezept ist kostenlose Werbung) funktioniert nur, wenn die App selbst keine Zugangshürde ist.

**Konsequenz:** Kernfunktionen bleiben immer frei. Einnahmen nur additiv und freiwillig (Spenden, optionaler Supporter-Tier). Keine Features hinter Paywall.

---

### F: Was ist der Unterschied zwischen einem Foto-Viewer und einem RAW-Editor?
**Status:** beantwortet

Ein Viewer zeigt, was ist. Ein RAW-Editor definiert, was sein könnte. Photo α ist klar ein Editor: Jede Anpassung ist ein Parameter, der lazy auf den Roh-Sensordaten rechnet — nie wird das Original angefasst. Das Original ist heilig; der Katalog ist die Quelle der Wahrheit.

Diese Trennung ist nicht nur technisch, sondern philosophisch: Der Fotograf entscheidet, wie ein Bild aussieht. Die App stellt das Handwerkszeug bereit, ohne die Entscheidung zu erzwingen.

---

### F: Warum lokal — warum keine Cloud-Sync?
**Status:** beantwortet

Fotos sind persönlich. Cloud-Sync bedeutet: Daten auf fremden Servern, Abhängigkeit von einem Dienst, der ggf. eingestellt wird, und potenzielle Datenschutz-Probleme. Für eine Dateimanagement-App, bei der die Originalfotos ohnehin auf dem Mac liegen, bringt Cloud-Sync keinen Kern-Mehrwert — nur Komplexität und Risiko.

Lokal bedeutet auch: volle Kontrolle, volle Geschwindigkeit (kein Netz-Roundtrip), funktioniert offline. Das passt zum Fuji-Ethos (Kamera als eigenständiges Gerät, nicht als Cloud-Endpoint).

**Konsequenz:** Netzwerk-Features (falls je) sind additiv, nie Pflicht. Die App muss ohne Internetverbindung vollständig funktionieren.

---

## 2. Technische Philosophie

### F: Warum GCD statt Swift Concurrency (async/await)?
**Status:** beantwortet

Die Deployment-Target-Realität: macOS 11 (Big Sur). Swift Concurrency benötigt macOS 12+ für die vollständige Runtime. Die App wird via `swiftc` ohne Xcode-Projekt gebaut — der Compiler-Support für `async/await` unter dem macOS-11-Runtime-ABI ist unzuverlässig und hat historisch SIGILL-Crashes verursacht (siehe Bug #43/#44 in BUGS.md).

GCD ist battle-tested, vollständig auf macOS 11 verfügbar, und erzwingt explizites Denken über Queue-Übergänge — was in einer App, die MainThread-Latenz als Produkt-Metrik behandelt, ein Feature ist, kein Bug.

**Konsequenz:** `DispatchQueue.global(qos:).async` für Hintergrundarbeit, Main nur für UI-Updates. Kein `async/await`, kein `Task { }`, kein `actor`. Diese Regel gilt, bis das Deployment-Target auf macOS 12+ angehoben wird.

---

### F: Warum Rust für den Performance-Kern?
**Status:** beantwortet

Blur-Score (Laplacian-Varianz), pHash, BT.709-Luma-Histogramm und Hotpixel-Erkennung sind tight-loop-Algorithmen, die auf Pixel-Arrays operieren. Swift ist hier langsamer als notwendig; Objective-C würde unsafe Pointer-Arithmetik erfordern; Python wäre inakzeptabel langsam.

Rust bietet C-Performance, Speichersicherheit ohne GC, und einen sauberen C-FFI (`libiphoto_rs`). Der Rust-Core ist bewusst klein gehalten — nur Algorithmen, die messbar von der nativen Performance profitieren. Kein Rust für Business-Logik, keine Rust-UI.

**Konsequenz:** Der Rust-Core ist ein Werkzeugkasten, kein Fundament. Neue Algorithmen kommen nur dann dorthin, wenn Swift/CoreImage nachweislich zu langsam ist.

---

### F: Warum SQLite als Katalog statt einer Document-basierten Architektur?
**Status:** beantwortet

Fotos werden nicht „geöffnet" wie Dokumente — sie werden in einer Bibliothek verwaltet, die Tausende Einträge hat. SQLite (WAL-Modus) erlaubt gleichzeitige Lesezugriffe ohne Schreibsperre, Batch-Upserts (10.000 Einträge ≈ 0,08 s), und SQL-Abfragen für SmartFolders. Eine JSON-Datei würde bei 1.000 Bildern mit EXIF, Ratings, und Adjustments unkontrollierbar groß.

Der Katalog ist die Wahrheit — nicht das Filesystem. Das Original-Foto wird nie modifiziert. Alle Metadaten, Anpassungen, Ratings, Alben sind im Katalog gespeichert.

---

### F: Warum non-destruktiv?
**Status:** beantwortet

Ein bearbeitetes Original ist unwiederbringlich. Non-destruktiv bedeutet: der `AdjustmentState` ist ein Codable-Struct von Parametern, das lazy auf das Original gerechnet wird. `CIImage` ist per Design ein Rezept — das Rendering passiert erst beim Export oder beim Anzeigen. Das ist nicht nur sicherer für den Nutzer, sondern auch schneller: Slider-Bewegungen ändern nur einen Float, nicht Pixel.

**Konsequenz:** `ImageExporter` ist der einzige Ort, an dem Pixel materialisiert werden. Alles andere operiert auf Parametern.

---

### F: Was bedeutet „Performance als Produkt-Wert"?
**Status:** beantwortet

Bild-Switch-Latenz ist nicht eine technische Metrik — sie ist das primäre UX-Erlebnis. Ein Fotograf scrollt durch hunderte Bilder; jede wahrnehmbare Verzögerung unterbricht den Workflow. Photo α behandelt Millisekunden wie andere Apps Pixel-Perfektheit behandeln: als Qualitätsmerkmal, das messbar ist und dessen Regression ein Bug ist.

Deshalb emittiert `ImageLoadingOrchestrator` `SWITCH <path> <ms>` Zeilen — nicht für Debugging, sondern weil Perf-Regression ohne Messung unsichtbar bleibt. Wer die Pipeline anfasst, liest diese Zeilen.

**Konsequenz:** Jede neue Codezeile auf dem Bild-Switch-Pfad braucht eine Latenz-Rechtfertigung.

---

## 3. Offene Fragen (werden durch den Doku-Agenten beantwortet)

### F: Welche Kompromisse macht die 3-Phasen-Ladelogik?
**Status:** offen

*Zu untersuchen: Was geht bei Phase-1/2/3 verloren? Wann ist ein Nutzer auf Phase-2 statt Phase-3? Wie verhält sich das bei RAF-Dateien vs. JPEG?*

---

### F: Wie verhält sich der AdjustmentRenderer bei RAW vs. Bitmap?
**Status:** offen

*Zu untersuchen: Wo divergieren die Pfade in `AdjustmentRenderer.swift`? Was kann bei RAW, was bei Bitmap nicht? Welche Parameter greifen vor dem Demosaicing?*

---

### F: Warum ist `ImageViewModel` eine einzelne Klasse statt aufgeteilt?
**Status:** offen

*Zu untersuchen: `ImageViewModel` hat ~20 Extensions. Ist das eine bewusste Entscheidung oder gewachsene Komplexität? Was würde eine Aufteilung erfordern und was wäre der Tradeoff?*

---

### F: Wie skaliert der Thumbnail-Cache bei sehr großen Bibliotheken (5.000+ Bilder)?
**Status:** offen

*Zu untersuchen: `ThumbnailDiskCache` hat ein 1-GB-Limit. Was passiert bei Überschreitung? Wie verhält sich die Verdrängungsstrategie? Gibt es Metriken dazu?*

---

### F: Was ist die langfristige Strategie für Objektivkorrekturen?
**Status:** offen

*Zu untersuchen: `LensFilters.swift` existiert. Was fehlt für die UI-Integration? Welche Korrekturen (Vignette, Verzeichnung, CA) sind bereits implementiert? Ist das für Fuji-Shooter relevant?*

---

### F: Wie wird die Film-Simulation aus dem Fuji-MakerNote ausgelesen?
**Status:** offen

*Zu untersuchen: Wo im Code passiert das? Welche Film-Simulationen werden erkannt? Was passiert bei unbekannten Werten?*

---

### F: Welche Rolle spielen Plugins in der langfristigen Architektur?
**Status:** offen

*Zu untersuchen: `PluginStore`, `PluginPanelView`, `InspectorView`. Was können Plugins tun/nicht tun? Ist das ein Erweiterungspunkt für Community-Contributions?*

---

## 4. Leitprinzipien (unveränderlich)

Diese Prinzipien stehen über allen anderen Entscheidungen:

1. **Das Original ist heilig.** Kein Schreiben auf die Quelldatei. Niemals.
2. **Geschwindigkeit ist kein Feature — sie ist Grundvoraussetzung.** Langsam ist kaputt.
3. **Lokal first.** Die App funktioniert vollständig ohne Internetverbindung.
4. **Kein Abo, kein Account, keine Paywall auf Kernfunktionen.** Immer.
5. **Fuji-first.** Generische Features verdünnen den Fokus. Wenn es nicht einem Fuji-Shooter hilft, gehört es nicht ins Produkt-Kern.
6. **Katalog ist die Wahrheit.** Das Filesystem ist Input, der Katalog ist der Zustand der App.
