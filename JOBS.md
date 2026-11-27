# JOBS.md — Automatisierte Agents im Projekt

Alle Cloud-Agenten die auf dem iPhoto-Repo laufen. Verwaltung: https://claude.ai/code/scheduled

---

## Aktive Agents

### CLI-Entwickler
**Trigger-ID:** `trig_01NP6YvxPjHpoFrT3P241iUR`
**Takt:** Jede Stunde (`:19`)
**Aufgabe:** Sucht Lücken in der CLI-Abdeckung (`iphoto-cli`), implementiert 1–2 neue Subcommands pro Run, schreibt Tests in `Tests/run_plugins.sh`, fügt Logging hinzu, pusht direkt auf `main`.
**Schreibt:** `Sources/CLI/main.swift`, `Tests/run_plugins.sh`, `CHANGELOG.md`, `Resources/Info.plist`

---

### Rust-Doktor
**Trigger-ID:** `trig_016AUQ4THEAXRNxoLfxz1pqx`
**Takt:** Jeden Dienstag 9 Uhr (Berlin)
**Aufgabe:** Scannt Swift-Code auf Stellen wo Rust messbaren Gewinn bringt (CPU-bound, Apple-unabhängig, Pixel-Iteration, O(N²)+). Erstellt GitHub Issues mit konkretem Migrationsplan.
**Schreibt:** GitHub Issues (`perf: X in Rust/rayon auslagern`)

---

### Performance-Doktor
**Trigger-ID:** `trig_01NH1cWXdjFgxrwjqgqwB3sF`
**Takt:** Jeden Mittwoch 9 Uhr (Berlin)
**Aufgabe:** Analysiert Hot-Path-Code und `logs/latest.log` auf Performance-Probleme (Main-Thread-I/O, O(N²)-Loops, per-frame Observer, fehlende Debounces). Erstellt GitHub Issues mit Datei+Zeile, Beweis und Fix-Vorschlag.
**Liest:** `logs/latest.log` (wird lokal per `scripts/sync_logs.sh` aktualisiert)
**Schreibt:** GitHub Issues (`perf: X`)

---

### Logging-Verbesserer
**Trigger-ID:** `trig_01EKDTLxf1Th219NLP7uwqnr`
**Takt:** Täglich 4 Uhr (Berlin)
**Aufgabe:** Verbessert Log-Ausgaben im Code — Bug-IDs, Ladezeiten, Nutzerverhalten.
**Schreibt:** Swift-Quelldateien, pusht auf `main`

---

### Refactor-Agent
**Trigger-ID:** `trig_01Wr5AwDaUmKHPZdaGCqQaaY`
**Takt:** Jeden Montag 10 Uhr (Berlin)
**Aufgabe:** Wartbarkeits-Refactors — Komplexität reduzieren, Views/ViewModels aufräumen.
**Schreibt:** Swift-Quelldateien, pusht auf `main`

---

### Philosophie-Wächter
**Trigger-ID:** `trig_017RD4R1FQqJP26vxWarxTRa`
**Takt:** Jeden Mittwoch 10 Uhr (Berlin)
**Aufgabe:** Prüft ob neue Features und Architekturentscheidungen mit `PHILOSOPHY.md` übereinstimmen. Ergänzt offene Fragen und beantwortet sie aus dem aktuellen Code-Stand.
**Schreibt:** `PHILOSOPHY.md`

---

## Log-Sync (lokal)

Damit der Performance-Doktor auf echte Laufzeit-Daten zugreifen kann, müssen Logs regelmäßig ins Repo gepusht werden:

```bash
./scripts/sync_logs.sh
```

Oder als automatischen Cron alle 2h einrichten:
```bash
crontab -e
# einfügen:
0 */2 * * * cd /Users/c0d3_cru5h/Developer/iOS-macOS/iPhoto && ./scripts/sync_logs.sh
```
