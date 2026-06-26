# Strategischer Gesamtplan
### Fuji-first RAW-Editor für macOS · Freeware · später Open Source

> **North Star:** Der beste *Fuji-native* RAW-Editor auf dem Mac werden — schnell,
> lokal, kein Abo. Nicht „Lightroom schlagen", sondern eine Lücke besetzen, die
> Lightroom strukturell offen lässt.

---

## 0. Ehrliche Bestandsaufnahme — wo du stehst

**Was steht (stark!):**
- Solide App-Basis: SQLite-Katalog (WAL, Migration), Alben, Ratings/Flags/Farbmarken,
  Suche, progressives Laden, Benchmark- + Skalierungstests bis 1000 Bilder, CLI-Tool,
  ARCHITECTURE.md. Das ist weit jenseits Prototyp.
- Non-destruktive Live-Pipeline über CoreImage mit echten Edit-Werkzeugen
  (Belichtung, WB, Kontrast, Kurven R/G/B, Klarheit, Textur, Dunst, Crop/Straighten).
- `AdjustmentState`-Refactor abgeschlossen (v0.31.1): alle 16 Edit-Parameter in einem
  `Codable, Equatable`-Struct — Fundament für Persistenz, Undo, Presets.
- RAW-Pipeline gestartet (v0.31.0): `CIFilter(imageURL:)` ersetzt ImageIO-Bitmap für
  RAW-Dateien — Belichtung greift jetzt auf Sensordaten, kein 8-Bit-Clip mehr.

**Was noch fehlt um Phase 1 abzuschließen:**
- **Preview-Auflösung beim Editieren** (`scaleFactor` / `allowDraftMode`) — auf der
  Iris Pro ist jeder Slider-Move mit voller RAW-Auflösung zu langsam. Das *muss* rein.
- **CIContext auf half-float (RGBAh)** + linearer Working Space → verhindert Banding
  in Lichtern/Schatten bei starken Edits.
- **Saubere Pfad-Trennung:** RAW → `CIFilter(imageURL:)`, JPEG/PNG → Bitmap wie bisher.
  Aktuell gibt es einen Fallback, aber keine explizite Kommunikation in der UI.

**Läuft gerade:** Phase 1 — Preview-Auflösung + half-float Context.

**Hardware-Realität:** MacBook Pro 15" Mid-2015, 16 GB, SSD, Intel Iris Pro (keine dGPU),
macOS 11. Ausreichend — zwingt aber zu Preview-Auflösung beim Editieren (siehe §5).
Ubuntu/Dell kann **nur** plattformunabhängige Logik testen (Katalog/Business-Logik),
nicht die GUI/CoreImage-Schicht.

---

## 1. Die Wette / Positionierung

**Wer ist die Zielgruppe?** Fuji-Shooter (X-Trans-Sensor), die unter macOS arbeiten,
kein Abo zahlen wollen und Film-Look lieben.

**Was die App IST:**
- Nativer, schneller RAW-Editor speziell für Fuji-Files
- Non-destruktiv, Katalog-basiert, lokal (keine Cloud-Pflicht)
- Film-Simulationen / Rezepte als Herzstück
- Freeware, kein Abo, kein Account-Zwang

**Was die App NICHT ist (und nie sein will):**
- Kein 1:1-Lightroom-Klon (das sind hunderte Personenjahre)
- Kein Allround-Editor für jede Kamera am Tag 1
- Kein Cloud-/DAM-Monster

**Zur „Blender für Lightroom"-Idee — ehrlich:** Das *Ethos* ist goldrichtig
(frei, offen, gegen Abo-Zwang). Die *Skala* ist eine andere Liga: Blender ist eine
20-Jahre-Institution mit Foundation, bezahlten Entwicklern und Millionen-Crowdfunding.
Als Solo-Dev wirst du nicht Blenders Umfang erreichen — **und das ist okay, weil dein
Fokus deine Stärke ist.** Sei nicht „Blender", sei „das beste Fuji-Tool auf dem Mac".
Den Abo-Frust kannst du brechen; eine Foundation ist ein Ziel für *falls es groß wird*,
keine Voraussetzung.

---

## 2. Strategischer Reality-Check — das Wettbewerbsfeld

| Tool | Stärke | Schwäche / deine Chance |
|---|---|---|
| **Lightroom** | Standard, Ökosystem | Abo-Zwang, kein natives Linux, bei Fuji nur „okay" |
| **Capture One** | Profi, gute Fuji-Unterstützung | teuer, schwer, Abo/teures Perpetual |
| **darktable** | mächtig, frei (GPLv3) | UX berüchtigt steil |
| **RawTherapee / ART** | top Demosaicing, frei | klobige UI, X-Trans mittelmäßig |
| **Photomator / Darkroom** | Mac-nativ, schick | nicht Fuji-spezialisiert |
| **Dehancer u.ä.** | Film-Emulation | Plugin, kostenpflichtig |

**Warum Fuji-first gewinnt:**
1. Apples `CIRAWFilter` macht **X-Trans-Demosaicing von Haus aus ordentlich** — das harte
   Problem, an dem viele Tools scheitern, hast du durch deinen Stack gratis gelöst.
2. Die Fuji-Community ist **besessen von Film-Simulationen** (siehe Fuji X Weekly und
   die Rezept-Szene). Es gibt nachweisbar Appetit.
3. Mac-nativ + schnell + **kein Abo + offen** ist 2026 ein echter, klar
   kommunizierbarer Unterschied.

**Ehrlich bleiben:** Fuji-Shooter haben Optionen (C1 kann Fuji gut, LR hat Fuji-Profile).
Deine Differenzierung muss *scharf* sein: **gratis + offen + Mac-schnell + Rezept-zentriert
+ kein Abo**. Genau dieser Stapel, nicht ein einzelnes Feature.

---

## 3. ⚠️ Namens- & Rechts-Warnung — VOR jedem öffentlichen Schritt

- **„iPhoto" ist Apples eigener (eingestellter) Produktname.** Unter diesem Namen
  öffentlich zu releasen ist ein Marken-Minenfeld. **Jetzt umbenennen** (intern egal,
  aber vor dem ersten öffentlichen Build). Billig jetzt, teuer später.
- **Fujifilm-Marken vorsichtig behandeln:** Du darfst *beschreibend* sagen „für
  Fujifilm-Kameras" / „X-Trans". Du darfst **nicht** Endorsement suggerieren oder
  Fujis geschützte Namen (die konkreten Film-Simulationsnamen) als deine ausgeben.
  → Liefere Rezepte, die den *Look* emulieren, und benenne sie eigenständig
  (Anlehnung an Film-Ästhetik, nicht Marken-Klau).
- Neuer Name idealerweise: kurz, film-/analog-angehaucht, frei von Apple- und
  Fujifilm-Marken, .com/Domain + GitHub-Handle verfügbar.

---

## 4. Technische Roadmap (phasenweise)

> Regel: **eine Phase nach der anderen.** Jede Phase ist verhaltensgleich abschließbar
> und liefert für sich Wert. Nicht vermischen.

### Phase 0 — `AdjustmentState`-Refactor ✅ *abgeschlossen (v0.31.1)*
16 lose `@Published` → ein `Codable, Equatable`-Struct. Verhaltensgleich.
Fundament für Persistenz, Undo/Redo, RAW-Node, Presets.

### Phase 1 — Echter RAW-Entwickler werden *(in Arbeit)*
- ✅ Source-Node getauscht: `CIFilter(imageURL:options:)` für RAW (v0.31.0).
  Belichtung greift jetzt vor dem Demosaicing auf Sensordaten.
- ⬜ **Preview-Auflösung beim Editieren** — `scaleFactor` / `allowDraftMode` setzen,
  volle Auflösung nur beim Export. Pflicht auf Iris Pro.
- ⬜ **CIContext auf half-float (RGBAh)** + linearer Working Space → kein Banding.
- ⬜ WB auf native RAW-Parameter (`neutralChromaticity` / `neutralTemperature`) —
  echter Weißabgleich vor Demosaicing, nicht CITemperatureAndTint auf 8-Bit.
- ⬜ Saubere Pfad-Trennung in der UI (RAW ≠ JPEG, ehrliche Kommunikation).
- macOS-11-tauglich über `CIFilter(imageURL:options:)`; späterer Umstieg auf die
  `CIRAWFilter`-Klasse (macOS 12+) = Ein-Datei-Change.

### Phase 2 — Katalog als Wahrheit
- `AdjustmentState` **pro Bild in den Katalog** (Codable → DB), nicht ins Bild backen.
- „Speichern" wird zu „Export". Edits jederzeit wieder editierbar.
- **Copy/Paste/Sync von Einstellungen über Bilder hinweg (Batch)** → macht aus dem
  Editor ein Workflow-Tool. Das ist der eigentliche Lightroom-Move.
- Undo/Redo über Snapshot-Stack von `AdjustmentState`.

### Phase 3 — Fuji-Signature: Film-Simulationen + Rezepte *(dein Alleinstellungsmerkmal)*
- Film-Look-Presets (Classic-Chrome-artig, Acros-artig, Velvia-artig, Classic-Neg-artig …)
  als Katalog-Presets — eigenständig benannt (siehe §3).
- **Rezept-System: teilbar (Export/Import als kleine Datei).** Das ist gleichzeitig
  Produkt UND Marketing-Motor (siehe §6/§8).
- Fällt fast geschenkt raus, sobald Presets im Katalog liegen (Phase 2).

### Phase 4 — Lokale Anpassungen / Masken *(größte verbleibende Lücke, hart)*
- Pinsel, Verlauf (linear/radial), dann Luminanz-/Farbbereich-Masken.
- *Das* definierende Lightroom-Feature. Realistisch mehrere Monate. Nicht unterschätzen.

### Phase 5 — Detail & Objektiv
- Echtes Capture-Sharpening + Luminanz-/Farbrauschen-Reduktion (das *eigentliche*
  Schärfen/Entrauschen — Klarheit/Textur/Dunst hast du schon).
- Objektivkorrekturen: Vignette, Verzeichnung, CA.
- Moderne Messlatte = KI-Denoise → eigenes großes Projekt, bewusst später.

### Phase 6 — Politur & Distribution
- Sparkle-Auto-Update + Notarisierung (eigenes Päckchen, siehe §7).
- Onboarding, Preset-Sharing-UX, Polish.

**Querschnitt (durchgehend):** Plattform-Trennung sauber halten — Katalog/Business-Logik
frei von CoreImage, damit auf Ubuntu/CI testbar (§5).

---

## 5. Architektur-Prinzipien

1. **Katalog ist die Wahrheit.** Original nie anfassen, Edits sind Parameter, gerendert
   wird beim Export. (Phase 2 macht das real.)
2. **Non-destruktiv, immer.** CoreImage ist lazy — eine CIImage ist nur ein Rezept.
   Das *ist* dein Live-Preview-Modell.
3. **In Preview-Auflösung entwickeln, nicht in voller.** Von der Iris Pro erzwungen —
   aber ohnehin der richtige Weg. Decode-Größe an den Viewport koppeln.
4. **Dünne OS-spezifische Oberfläche.** RAW-Decode-Aufrufe hinter ein kleines
   Protokoll/Struct kapseln → späterer Sprung auf neuestes macOS / Apple Silicon wird
   ein lokaler Change, kein Umbau.
5. **Plattform-Trennung.** Alles CoreImage/AppKit/Metal in eine klar abgegrenzte Schicht;
   Katalog + Logik portabel halten → auf Ubuntu/Dell als CI testbar (löst dein
   „ich kann die App auf Linux nicht aufmachen"-Thema für den *Logik*-Teil).

---

## 6. Das Fuji-Alleinstellungsmerkmal — warum Rezepte der Kern sind

Film-Simulationen sind bei dir **Produkt und Marketing in einem**:
- Als Produkt: der Grund, warum ein Fuji-Shooter *deine* App statt LR nimmt.
- Als Marketing: ein teilbares Rezept ist Content. Jedes geteilte Rezept ist Werbung,
  die deine Nutzer *für dich* verbreiten (genau das Modell, das die Fuji-Rezept-Szene
  groß gemacht hat).
- Als Community-Haken: Nutzer reichen eigene Rezepte ein → Mitmach-Effekt, der bei
  Open-Source (§9) nahtlos in echte Contribution übergeht.

→ Deshalb steht Phase 3 *früh*, direkt nach „Katalog als Wahrheit". Es ist der Hebel
mit dem besten Verhältnis aus Aufwand und Differenzierung.

---

## 7. Hardware-Pfad — vom 2015er zur neuesten Version

- **Jetzt:** macOS 11, konservatives API. Alles Nötige für Phase 1–4 läuft hier.
- **Zwischenschritt:** Monterey-Update auf deinem Mac (saubereres Xcode), wenn dich ein
  SDK blockiert — nicht vorher. Kein Muss für den RAW-Umbau.
- **Ziel:** Apple Silicon (gebraucht) + neuestes macOS. Das **löst das
  Performance-Problem** (Demosaicing bei jedem Slider-Move) praktisch von selbst.
- **Brücke über Open Source:** Contributors mit M-Series-Macs können den
  Neueste-macOS-Build pflegen und testen, während du auf 11/Monterey bleibst.
  → Open Source ist hier nicht „Belohnung", sondern **Werkzeug gegen deinen
  Hardware-Engpass** (siehe §9).
- **Sparkle/Notarisierung:** eigenes, klar abgegrenztes Päckchen für Phase 6.
  Sparkle 2.9.x (unterstützt macOS 11), Apple Developer ID nötig (99 $/Jahr) für
  signierte, notarisierte Updates. Nicht jetzt anfassen.

---

## 8. Go-to-Market — wie kommen wir an Nutzer

> **Erst launchen, wenn RAW (Phase 1) UND Film-Rezepte (Phase 3) stehen.** Vorher ist
> es „noch ein Foto-Viewer". Mit beidem hast du eine Geschichte.

**Wo die Fuji-Leute sind (gezielt, nicht Gießkanne):**
- Reddit: r/fujifilm, r/fujix, r/FujifilmX — dort sind die Rezept-Diskussionen.
- Fuji-Rezept-Szene / Blogs / die einschlägigen Film-Simulation-Communities.
- Fujifilm-Facebook-Gruppen, Fuji-Discords, Fuji-YouTube-Kanäle.
- Foto-/Mac-Communities: r/photography, r/macapps.

**Die zwei Launch-Kanäle für die „kein Abo + offen"-Story:**
- **Hacker News „Show HN"** — nativ + kein Abo + (später) Open Source spielt dort
  *extrem* gut. Eine ehrliche, technische Story über die RAW-Pipeline + Fuji-Fokus.
- **Product Hunt** — für Reichweite über die Tech-Bubble hinaus.

**Content-Marketing = deine Rezepte (kostenlos eingebaut):**
- Jedes mitgelieferte Film-Rezept ist teilbar → Nutzer verbreiten es.
- Before/After-Vergleiche mit echten Fuji-RAWs als Demo-Material.
- Die Anti-Abo-/Pro-Open-Source-Haltung *ist* der Marketing-Hook 2026 — nicht
  aufdringlich, aber klar als Wert kommunizieren.

**Launch-Sequenz (Vorschlag):**
1. Stiller Beta-Kreis (du + ein paar Fuji-Bekannte) → Sparkle-Auto-Update testen.
2. Post in 1–2 Fuji-Communities mit konkretem Mehrwert (Rezepte zum Mitnehmen).
3. Wenn stabil + Feedback eingearbeitet: Show HN + Product Hunt am selben Tag.
4. Open-Source-Flip als *eigene* Launch-Story timen (doppelte Reichweite, §9).

---

## 9. Open-Source-Strategie

**Wann flippen?** *Nicht* an einer Nutzerzahl festmachen — das ist das falsche Signal.
Die echten Trigger:
1. **Architektur ist stabil** (idealerweise nach Phase 2, „Katalog als Wahrheit").
2. **Keine Secrets im Repo** (Signing-Keys etc. sauber draußen).
3. **Du würdest von Hilfe profitieren, die du selbst nicht leisten kannst** — z. B.
   Testen/Bauen auf Hardware, die du nicht hast. (Genau dein Fall → spricht eher für
   *früher* als später.)

**Reframe:** Open Source ist für dich kein „Reward bei Meilenstein", sondern die
**Lösung deines Hardware-Bottlenecks** und ein zweiter Reichweiten-Schub. Das kippt die
Logik Richtung „eher früh öffnen, sobald die Architektur trägt".

**Lizenz:**
- **GPLv3 empfohlen** — passt zum Ethos (verhindert, dass jemand deine Arbeit
  closed-source kommerzialisiert) und zur Nachbarschaft (darktable, RawTherapee sind
  GPLv3). Da du außerhalb des App Store über Sparkle verteilst, gibt's keinen
  GPL-vs-App-Store-Konflikt.
- Permissive Alternative (MIT/Apache) nur, falls du *maximale* Adoption über alles
  stellst und Closed-Source-Forks bewusst in Kauf nimmst. Für dein Ziel: eher GPLv3.

**Governance:** Simpel starten (du als Maintainer, klare CONTRIBUTING.md + Build-Doku +
CI). Foundation/Verein erst, *falls* es wirklich groß wird — nicht vorbauen.

**Voraussetzung fürs Öffnen:** Saubere Build-Anleitung, CI (idealerweise mit dem
plattformunabhängigen Logik-Teil auf Linux), README, das die Vision erklärt.

---

## 10. Nachhaltigkeit — Freeware ohne Abo

Ehrlich: Reine Freeware ohne jede Einnahme ist als Passion-Projekt völlig legitim —
aber falls du es langfristig tragfähig willst, sind das die abo-freien Wege:
- **Spenden:** GitHub Sponsors, Open Collective, Ko-fi. Niedrige Schwelle, passt zu OSS.
- **Optionaler Supporter-Tier:** kosmetische Perks / „Pro"-Extras *einmalig* bezahlbar —
  niemals Kernfunktion hinter Paywall (das wäre Verrat am Versprechen).
- **Patreon-artig für Rezepte / Early Access** — bewährtes Modell genau in der
  Fuji-Rezept-Szene (kostenlose Basis, optionaler Support).
- **Prinzip:** Das *Versprechen* ist „kein Abo, Kernfunktion frei". Monetarisierung
  immer additiv und freiwillig, nie erzwungen.

---

## 11. Meilensteine / Definition von Erfolg

**Kurzfristig (die nächsten Wochen):**
- [x] Phase 0: `AdjustmentState`-Refactor durch, verhaltensgleich. *(v0.31.1)*
- [x] RAW-Source-Node: `CIFilter(imageURL:)` — Belichtung auf Sensordaten. *(v0.31.0)*
- [ ] Phase 1 komplett: Preview-Auflösung + half-float Context + WB auf RAW-Parameter.
      ← *Ab hier ist es ein echter RAW-Editor.*
- [ ] Umbenennung entschieden (§3).

**Mittelfristig:**
- [ ] Phase 2: Edits im Katalog, Export-Modell, Batch-Sync.
- [ ] Phase 3: Film-Rezepte + teilbares Rezept-Format. ← *Ab hier hast du eine Story.*
- [ ] Beta-Kreis + Sparkle-Auto-Update.

**Längerfristig:**
- [ ] Phase 4: Lokale Masken (macht dich „ernsthaft").
- [ ] Öffentlicher Launch (Show HN + Product Hunt) + Open-Source-Flip.
- [ ] Apple-Silicon-Pfad / neuestes macOS (ggf. via Contributors).

**Was „Erfolg" heißt — gestaffelt:** Stufe 1 = du entwickelst deine eigenen Fuji-RAWs
lieber hier als in irgendwas anderem. Stufe 2 = ein paar Fuji-Leute auch. Stufe 3 =
Rezepte werden geteilt, Contributors kommen. Alles darüber ist Bonus, nicht Pflicht.

---

## 12. Was JETZT konkret zu tun ist

1. ✅ **`AdjustmentState`-Refactor** — abgeschlossen (v0.31.1).
2. ✅ **RAW-Source-Node** — `CIFilter(imageURL:)` läuft (v0.31.0). Phase 1 läuft.
3. **Preview-Auflösung + half-float Context** (Phase 1 abschließen) — nächster Schritt.
   Ohne das bleibt jeder Slider-Move auf Iris Pro zu langsam für echten Workflow.
4. **WB auf native RAW-Parameter** (neutralChromaticity) — Phase 1 letzter Punkt.
5. **Umbenennung entscheiden** — bevor irgendwas öffentlich wird.
6. **Nicht ablenken lassen:** Sparkle, Open Source, Marketing sind real und geplant —
   aber alle *nach* „Phase 1 komplett". Vorher gibt es nichts zu launchen.

> Reihenfolge ist hier alles. Phase 1 ist zu ~40% fertig (Source-Node läuft).
> Preview-Auflösung und half-float sind der kritische Rest — ohne die zwei Punkte
> ist die Performance auf älterer Hardware zu schlecht für echten Einsatz.
