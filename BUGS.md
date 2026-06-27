# iPhoto – Bug-Tracking

Bug-Reports werden vom `CrashReporter` automatisch beim nächsten App-Start erkannt und direkt gespeichert unter:

```
~/Documents/bugreports/iPhoto_Crash_<datum>.txt        ← automatisch gespeichert, zu bearbeiten
~/Documents/bugreports/fixed/iPhoto_Crash_<datum>.txt  ← behoben (manuell verschieben)
```

**Workflow beim Auftreten eines neuen Bug-Reports:**
1. Datei unter `~/Documents/bugreports/` lesen und analysieren
2. Ursache identifizieren, Fehler professionell beheben (kein Quick-Fix ohne Ursachenanalyse)
3. Build mit `./build.sh` verifizieren
4. Behobene Datei nach `~/Documents/bugreports/fixed/` verschieben
5. Tabelle unten mit Ergebnis aktualisieren
6. Commit + Push wie gewohnt

**Wichtig:** Jeden Bug ernst nehmen. Crashes sind kein akzeptabler Zustand — Ursache finden, nicht umschiffen.

## Bekannte Bugs & Status

| # | Datum | Version | Symptom | Ursache | Behoben in | Test |
|---|-------|---------|---------|---------|------------|------|
| 1 | 2026-06-27 | 0.38.2 | Crash nach ~10 Min Betrieb; Bug-Report zeigte letzten Log-Eintrag abgeschnitten | `CrashReporter.buildReport()` splittete Log-Datei an `=== iPhoto gestartet ===`, das aber auch als Teilstring in normalen Log-Einträgen vorkommt → letzter Eintrag der abgestürzten Session wurde mitten im Text getrennt | 0.39.1 | Nächsten Crash provozieren und prüfen ob der Report vollständig ist; kein abgeschnittener letzter Eintrag mehr |
| 2 | 2026-06-27 | 0.39.0 | Hot-Pixel-Analyse schlägt bei RAF-Dateien fehl (kein Ergebnis) | `frameDimensions()` verwendete nur `CGImageSourceCreateImageAtIndex` ohne CIFilter-Pfad → RAF-Dateien wurden nie dekodiert; außerdem verwendete `decodeFrame()` `[CIRAWFilterOption: Any]`-Options-Dict statt `setValue`-Ansatz wie im Rest der Codebase | 0.39.1 | Ordner mit Fuji RAF-Dateien auswählen → Analyse muss durchlaufen und Ergebnis zeigen |
| 3 | 2026-06-27 | 0.39.0 | Crash-Loop beim Start: App startet, lädt 1-2 Bilder, crasht sofort, Neustart → selber Crash | `CatalogStore.bind()` übergab `(v as NSString).utf8String` mit `SQLITE_STATIC` (nil-Destruktor) an SQLite. ARC konnte die NSString-Temporary freigeben bevor `sqlite3_step` auf den Pointer zugriff → Use-after-free in SQLite | 0.39.2 | App mit mehreren Bildern öffnen, durch Bibliothek navigieren; kein Crash beim Start oder beim Laden von Bildern |
| 4 | 2026-06-25 | 0.30.0–0.36.0 | App crasht still nach langer Leerlaufzeit (kein ERROR im Log), besonders nach schnellem Durchblättern vieler großer Bilder | `cgImage`-Objekte (je ~96 MB bei 4000×6000) wurden nie aus dem Speicher entlassen → Memory-Pressure → SIGKILL durch macOS. Außerdem: POSIX-Signale (SIGSEGV, SIGABRT etc.) wurden nicht geloggt, nur ObjC-Exceptions. | 0.39.3 | 50+ große Bilder öffnen, schnell durchblättern; Memory-Nutzung im Aktivitätsmonitor sollte stabil bleiben und nicht unbegrenzt wachsen |
| 5 | 2026-06-25 | 0.30.0–0.36.0 | Signal-basierte Crashes (SIGSEGV, SIGABRT etc.) hinterlassen keinen Log-Eintrag, nur ein leeres Crash-Report-Fenster beim nächsten Start | Kein `sigaction`-Handler für POSIX-Signale installiert — nur `NSSetUncaughtExceptionHandler` für ObjC-Exceptions | 0.39.3 | Nicht direkt testbar; bei zukünftigen Crashes sollte der Log-Eintrag `[SIGNAL] SIGSEGV` o.ä. enthalten |
| 6 | 2026-06-27 | 0.39.2 | Hot-Pixel-Analyse crasht auf macOS 11 beim Öffnen von RAF-Dateien (NSUnknownKeyException → SIGABRT) | `HotPixelAnalyzer.decodeFrame` rief `filter.setValue(true, forKey: "inputAllowDraftMode")` auf — dieser Key ist auf macOS 11 in `CIRAWFilterImpl` nicht vorhanden → `NSUnknownKeyException` | 0.39.4 | Hot-Pixel-Analyse mit RAF-Dateien auf macOS 11 durchführen; kein Crash mehr |
