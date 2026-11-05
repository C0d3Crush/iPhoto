#!/bin/bash
# Tests für alle iPhoto-Inspector-CLI-Plugins
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/iphoto-cli"
TMPDIR="$(mktemp -d)"
trap "rm -rf $TMPDIR" EXIT

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1 — $2"; FAIL=$((FAIL + 1)); }

if [ ! -x "$BIN" ]; then
    echo "Fehler: iphoto-cli nicht gefunden. Zuerst ./build.sh ausführen."
    exit 1
fi

echo ""
echo "=== iPhoto CLI — Plugin-Tests ==="
echo "Binary : $BIN"
echo "Tmpdir : $TMPDIR"
echo ""

# Alle katalogzugreifenden Befehle verwenden eine temporäre Test-DB
export IPHOTO_CATALOG_DB="$TMPDIR/test_catalog.db"

# ---------------------------------------------------------------------------
# Test-PNG erstellen: minimales gültiges 4×4 Bild (analog test_formats.sh)
# ---------------------------------------------------------------------------
INPUT_PNG="$TMPDIR/test_input.png"
python3 - <<'EOF' > "$INPUT_PNG"
import struct, zlib, sys

def chunk(name, data):
    crc = zlib.crc32(name + data) & 0xffffffff
    return struct.pack('>I', len(data)) + name + data + struct.pack('>I', crc)

sig  = b'\x89PNG\r\n\x1a\n'
# 4×4 RGB image
ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', 4, 4, 8, 2, 0, 0, 0))
# 4 rows, each: filter byte (0) + 4×RGB (12 bytes) = 13 bytes per row
row  = b'\x00' + b'\xff\x80\x00' * 4  # filter=None, orange pixels
raw  = row * 4
idat = chunk(b'IDAT', zlib.compress(raw))
iend = chunk(b'IEND', b'')
sys.stdout.buffer.write(sig + ihdr + idat + iend)
EOF

if [ ! -f "$INPUT_PNG" ] || [ ! -s "$INPUT_PNG" ]; then
    echo "Fehler: Test-PNG konnte nicht erstellt werden."
    exit 1
fi
echo "Test-PNG erstellt: $INPUT_PNG"
echo ""

# ---------------------------------------------------------------------------
# 1. rating — set 4, read back, check "4"
# ---------------------------------------------------------------------------
echo "--- Rating ---"
RATING_OUT=$("$BIN" rating "$INPUT_PNG" --set 4 2>&1)
if echo "$RATING_OUT" | grep -q "4"; then
    pass "rating --set 4 (Output enthält '4')"
else
    fail "rating --set 4" "Output enthält keine '4': $RATING_OUT"
fi

# 2. rating --json — valid JSON mit "rating"
RATING_JSON=$("$BIN" rating "$INPUT_PNG" --json 2>&1)
if echo "$RATING_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'rating' in d" 2>/dev/null; then
    pass "rating --json (valides JSON mit 'rating')"
else
    fail "rating --json" "Kein valides JSON oder fehlendes 'rating'-Feld: $RATING_JSON"
fi

# Reset auf 0
"$BIN" rating "$INPUT_PNG" --set 0 > /dev/null 2>&1 || true

echo ""

# ---------------------------------------------------------------------------
# 3. adjust --exposure — output file exists and is non-empty
# ---------------------------------------------------------------------------
echo "--- Adjust ---"
ADJ_OUT="$TMPDIR/adjusted_exposure.png"
if "$BIN" adjust "$INPUT_PNG" --output "$ADJ_OUT" --format png --exposure 0.3 2>/dev/null; then
    if [ -f "$ADJ_OUT" ] && [ -s "$ADJ_OUT" ]; then
        pass "adjust --exposure 0.3 (Ausgabedatei vorhanden und nicht leer)"
    else
        fail "adjust --exposure 0.3" "Ausgabedatei fehlt oder leer"
    fi
else
    fail "adjust --exposure 0.3" "CLI-Fehler beim Ausführen"
fi

# 4. adjust --preset Chrome
ADJ_PRESET_OUT="$TMPDIR/adjusted_preset.jpg"
if "$BIN" adjust "$INPUT_PNG" --output "$ADJ_PRESET_OUT" --format jpeg --preset Chrome 2>/dev/null; then
    if [ -f "$ADJ_PRESET_OUT" ] && [ -s "$ADJ_PRESET_OUT" ]; then
        pass "adjust --preset Chrome (Ausgabedatei vorhanden)"
    else
        fail "adjust --preset Chrome" "Ausgabedatei fehlt oder leer"
    fi
else
    fail "adjust --preset Chrome" "CLI-Fehler beim Ausführen"
fi

echo ""

# ---------------------------------------------------------------------------
# 5. preset list — contains "Chrome"
# ---------------------------------------------------------------------------
echo "--- Preset ---"
PRESET_LIST=$("$BIN" preset list 2>&1)
if echo "$PRESET_LIST" | grep -qi "chrome"; then
    pass "preset list (enthält 'Chrome')"
else
    fail "preset list" "Output enthält kein 'Chrome': $PRESET_LIST"
fi

# 6. preset list --json — valid JSON array
PRESET_JSON=$("$BIN" preset list --json 2>&1)
if echo "$PRESET_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst, list) and len(lst) > 0" 2>/dev/null; then
    pass "preset list --json (valides JSON-Array)"
else
    fail "preset list --json" "Kein valides JSON-Array: $PRESET_JSON"
fi

# 7. preset apply "Chrome"
PRESET_APPLY_OUT="$TMPDIR/preset_applied.jpg"
if "$BIN" preset apply "$INPUT_PNG" --name Chrome --output "$PRESET_APPLY_OUT" --format jpeg 2>/dev/null; then
    if [ -f "$PRESET_APPLY_OUT" ] && [ -s "$PRESET_APPLY_OUT" ]; then
        pass "preset apply Chrome (Ausgabedatei vorhanden)"
    else
        fail "preset apply Chrome" "Ausgabedatei fehlt oder leer"
    fi
else
    fail "preset apply Chrome" "CLI-Fehler beim Ausführen"
fi

echo ""

# ---------------------------------------------------------------------------
# 8. analyse single file — output contains blur score (numeric value)
# ---------------------------------------------------------------------------
echo "--- Analyse ---"
ANALYSE_OUT=$("$BIN" analyse "$INPUT_PNG" 2>&1)
# Output should contain a float number (the blur score)
if echo "$ANALYSE_OUT" | grep -qE '[0-9]+\.[0-9]+'; then
    pass "analyse single (Output enthält Blur-Score)"
else
    fail "analyse single" "Output enthält keinen numerischen Blur-Score: $ANALYSE_OUT"
fi

# 9. analyse --json — valid JSON array
ANALYSE_JSON=$("$BIN" analyse "$INPUT_PNG" --json 2>&1)
if echo "$ANALYSE_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst, list) and len(lst) > 0 and 'blur_score' in lst[0]" 2>/dev/null; then
    pass "analyse --json (valides JSON-Array mit 'blur_score')"
else
    fail "analyse --json" "Kein valides JSON-Array oder fehlendes 'blur_score': $ANALYSE_JSON"
fi

echo ""

# ---------------------------------------------------------------------------
# 10. inpaint graceful failure — nonexistent python path → exit code 1 + error msg
# ---------------------------------------------------------------------------
echo "--- Inpaint ---"
INPAINT_OUT="$TMPDIR/inpainted_result"
INPAINT_STDERR=$("$BIN" inpaint "$INPUT_PNG" --output "$INPAINT_OUT" \
    --python /nichtexistent/python99 \
    --cmt /nichtexistent/cmt \
    --checkpoint /nichtexistent/checkpoints 2>&1) || INPAINT_EXIT=$?

if [ "${INPAINT_EXIT:-0}" -ne 0 ]; then
    if echo "$INPAINT_STDERR" | grep -qi "fehler\|error\|nicht gefunden\|not found"; then
        pass "inpaint graceful failure (Exitcode != 0 + Fehlermeldung)"
    else
        fail "inpaint graceful failure" "Exitcode != 0, aber keine verständliche Fehlermeldung: $INPAINT_STDERR"
    fi
else
    fail "inpaint graceful failure" "Hätte fehlschlagen sollen (Exitcode 0 zurückgegeben)"
fi

# ---------------------------------------------------------------------------
# plugins list — at least 9 panels (builtins) are listed
# ---------------------------------------------------------------------------
echo "--- Plugins ---"
PLUGIN_LIST=$("$BIN" plugins list 2>&1)
PLUGIN_COUNT=$(echo "$PLUGIN_LIST" | grep -c "\[builtin:" || true)
if [ "$PLUGIN_COUNT" -ge 9 ]; then
    pass "plugins list (mindestens 9 Builtin-Panels gefunden)"
else
    fail "plugins list" "Weniger als 9 Builtin-Panels: $PLUGIN_COUNT gefunden. Output: $PLUGIN_LIST"
fi

# plugins list --json — valid JSON array with at least 9 items
PLUGIN_JSON=$("$BIN" plugins list --json 2>&1)
if echo "$PLUGIN_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list) and len(lst)>=10, f'nur {len(lst)} Einträge'" 2>/dev/null; then
    pass "plugins list --json (valides JSON-Array mit ≥10 Einträgen)"
else
    fail "plugins list --json" "Kein valides JSON-Array oder <10 Einträge: $PLUGIN_JSON"
fi

# plugins dir — prints an existing path
PLUGIN_DIR=$("$BIN" plugins dir 2>&1)
if [ -d "$PLUGIN_DIR" ]; then
    pass "plugins dir (Verzeichnis existiert: $PLUGIN_DIR)"
else
    fail "plugins dir" "Verzeichnis existiert nicht: $PLUGIN_DIR"
fi

echo ""

# ---------------------------------------------------------------------------
# viewmode — get/set
# ---------------------------------------------------------------------------
echo "--- ViewMode ---"

# viewmode set grid — exit 0
VIEWMODE_SET=$("$BIN" viewmode set grid 2>&1)
VIEWMODE_EXIT=$?
if [ $VIEWMODE_EXIT -eq 0 ]; then
    pass "viewmode set grid (Exitcode 0)"
else
    fail "viewmode set grid" "Exitcode $VIEWMODE_EXIT: $VIEWMODE_SET"
fi

# viewmode get — returns one of the valid modes
VIEWMODE_GET=$("$BIN" viewmode get 2>&1)
if echo "$VIEWMODE_GET" | grep -qE '^(grid|list|columns|gallery)$'; then
    pass "viewmode get (gibt gültigen Modus zurück: $VIEWMODE_GET)"
else
    fail "viewmode get" "Unerwartete Ausgabe: $VIEWMODE_GET"
fi

# viewmode set invalid — exit != 0
VIEWMODE_BAD_EXIT=0
"$BIN" viewmode set bogusmode > /dev/null 2>&1 || VIEWMODE_BAD_EXIT=$?
if [ $VIEWMODE_BAD_EXIT -ne 0 ]; then
    pass "viewmode set <ungültig> (Exitcode != 0)"
else
    fail "viewmode set bogusmode" "Hätte fehlschlagen sollen (Exitcode 0 zurückgegeben)"
fi

echo ""

# ---------------------------------------------------------------------------
# people — list / faces
# ---------------------------------------------------------------------------
echo "--- People ---"

# people list — exit 0
PEOPLE_LIST=$("$BIN" people list 2>&1)
PEOPLE_EXIT=$?
if [ $PEOPLE_EXIT -eq 0 ]; then
    pass "people list (Exitcode 0)"
else
    fail "people list" "Exitcode $PEOPLE_EXIT: $PEOPLE_LIST"
fi

# people list --json — valid JSON array
PEOPLE_JSON=$("$BIN" people list --json 2>&1)
if echo "$PEOPLE_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list)" 2>/dev/null; then
    pass "people list --json (valides JSON-Array)"
else
    fail "people list --json" "Kein valides JSON-Array: $PEOPLE_JSON"
fi

# people faces --json — valid JSON array
FACES_JSON=$("$BIN" people faces --json 2>&1)
if echo "$FACES_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list)" 2>/dev/null; then
    pass "people faces --json (valides JSON-Array)"
else
    fail "people faces --json" "Kein valides JSON-Array: $FACES_JSON"
fi

# people cluster --json — exit 0, valides JSON
CLUSTER_JSON=$("$BIN" people cluster --json 2>&1)
CLUSTER_EXIT=$?
if [ $CLUSTER_EXIT -eq 0 ]; then
    pass "people cluster (Exitcode 0)"
else
    fail "people cluster" "Exitcode $CLUSTER_EXIT: $CLUSTER_JSON"
fi

# people <ungültig> — exit != 0
PEOPLE_BAD_EXIT=0
"$BIN" people bogussubcmd > /dev/null 2>&1 || PEOPLE_BAD_EXIT=$?
if [ $PEOPLE_BAD_EXIT -ne 0 ]; then
    pass "people <ungültig> (Exitcode != 0)"
else
    fail "people bogussubcmd" "Hätte fehlschlagen sollen (Exitcode 0 zurückgegeben)"
fi

echo ""

# ---------------------------------------------------------------------------
# 12. people scan — Gesichtserkennung in echtem Bild
# ---------------------------------------------------------------------------
SCAN_IMG="$ROOT/Tests/fixtures/faces/einstein_1.jpg"
if [ -f "$SCAN_IMG" ]; then
    SCAN_DB=$(mktemp /tmp/iphoto_scan_test_XXXXXX.db)
    SCAN_OUT=$(IPHOTO_CATALOG_DB="$SCAN_DB" "$BIN" people scan "$SCAN_IMG" 2>&1)
    SCAN_FACES=$(echo "$SCAN_OUT" | grep -oE '[0-9]+ Gesicht' | head -1 | grep -oE '[0-9]+')
    rm -f "$SCAN_DB"
    if [ "${SCAN_FACES:-0}" -ge 1 ]; then
        pass "people scan (Gesicht in einstein_1.jpg erkannt)"
    else
        fail "people scan" "Kein Gesicht erkannt: $SCAN_OUT"
    fi
else
    pass "people scan (übersprungen — Testbild nicht vorhanden)"
fi

echo ""

# ---------------------------------------------------------------------------
# config — export / show / import
# ---------------------------------------------------------------------------
echo "--- Config ---"

CONFIG_OUT="$TMPDIR/settings_export.json"

# config export --path <file>
CONFIG_EXPORT=$("$BIN" config export --path "$CONFIG_OUT" 2>&1)
CONFIG_EXIT=$?
if [ $CONFIG_EXIT -eq 0 ] && [ -f "$CONFIG_OUT" ]; then
    pass "config export --path (Exitcode 0, Datei erstellt)"
else
    fail "config export --path" "Exitcode $CONFIG_EXIT: $CONFIG_EXPORT"
fi

# config show — valid JSON (may be empty object if no settings stored)
if [ -f "$CONFIG_OUT" ]; then
    CONFIG_SHOW=$("$BIN" config show 2>&1)
    if python3 -c "import sys,json; json.loads(sys.stdin.read())" <<< "$CONFIG_SHOW" 2>/dev/null; then
        pass "config show (valides JSON)"
    else
        fail "config show" "Kein valides JSON: $CONFIG_SHOW"
    fi
fi

# config import — round-trip the exported file
if [ -f "$CONFIG_OUT" ]; then
    CONFIG_IMPORT=$("$BIN" config import "$CONFIG_OUT" 2>&1)
    CONFIG_IMPORT_EXIT=$?
    if [ $CONFIG_IMPORT_EXIT -eq 0 ]; then
        pass "config import (Exitcode 0)"
    else
        fail "config import" "Exitcode $CONFIG_IMPORT_EXIT: $CONFIG_IMPORT"
    fi
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
echo "=============================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
