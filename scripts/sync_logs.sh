#!/bin/bash
# Synct die letzten 1000 Zeilen des iPhoto-Logs ins Repo für Remote-Agents.
# Aufruf: ./scripts/sync_logs.sh
# Oder als launchd/cron: z.B. alle 2h automatisch

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_SRC="$HOME/Library/Logs/iPhoto/iPhoto.log"
LOG_DEST="$REPO_ROOT/logs/latest.log"

if [ ! -f "$LOG_SRC" ]; then
    echo "Keine Log-Datei gefunden: $LOG_SRC"
    exit 1
fi

tail -n 1000 "$LOG_SRC" > "$LOG_DEST"
echo "$(date '+%Y-%m-%d %H:%M:%S') — Log synchronisiert ($(wc -l < "$LOG_DEST") Zeilen)" >> "$REPO_ROOT/logs/sync.log"

cd "$REPO_ROOT"
git add logs/latest.log logs/sync.log
if git diff --cached --quiet; then
    echo "Keine neuen Log-Einträge — nichts zu committen."
    exit 0
fi

git commit -m "chore: logs/latest.log aktualisiert ($(date '+%Y-%m-%d %H:%M'))"
git push origin main
echo "Log gepusht."
