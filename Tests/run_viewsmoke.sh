#!/bin/bash
# View-Rendering-Smoketest: startet die gebaute .app mit IPHOTO_SMOKETEST=1,
# wartet bis zu 8 s auf sauberen exit(0). Fangt Crashes waehrend Layout,
# Force-Unwraps in Views und Threading-Verstoesse ab, die sich in Tests ohne
# Display-Server nicht zeigen wuerden.
#
# Voraussetzung: ./build.sh muss vorher gelaufen sein und einen Display-Server
# zur Verfuegung stellen (auf CI: macos-latest Runner hat WindowServer).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# App-Name aus build.sh lesen (seit 1.86.1 „iPhoto Α“), damit Umbenennungen den Test nicht brechen.
APP_NAME="$(sed -n 's/^APP_NAME="\(.*\)"$/\1/p' "$ROOT/build.sh")"
APP_NAME="${APP_NAME:-iPhoto}"
APP="$ROOT/build/$APP_NAME.app"

if [ ! -d "$APP" ]; then
    echo "FAIL: $APP existiert nicht. Erst ./build.sh laufen lassen."
    exit 1
fi

BIN="$APP/Contents/MacOS/$APP_NAME"
LOG="$ROOT/build/viewsmoke.log"
rm -f "$LOG"

echo "==> Starte $BIN mit IPHOTO_SMOKETEST=1 (max. 8 s)"
IPHOTO_SMOKETEST=1 "$BIN" > "$LOG" 2>&1 &
PID=$!

# Bis zu 8 s auf sauberen Exit warten.
for _ in $(seq 1 80); do
    if ! kill -0 "$PID" 2>/dev/null; then
        break
    fi
    sleep 0.1
done

# Falls noch am Leben: hart terminieren + FAIL.
if kill -0 "$PID" 2>/dev/null; then
    echo "FAIL: App beendete sich nicht innerhalb 8 s — hing wahrscheinlich beim Rendern"
    kill -9 "$PID" 2>/dev/null || true
    tail -30 "$LOG" || true
    exit 1
fi

wait "$PID" 2>/dev/null && CODE=$? || CODE=$?

if [ "$CODE" -eq 0 ]; then
    echo "PASS: View-Rendering-Smoketest erfolgreich (exit 0)"
    exit 0
else
    echo "FAIL: App beendete mit exit $CODE"
    tail -40 "$LOG" || true
    exit 1
fi
