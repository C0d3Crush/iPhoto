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
# cache — stats / clear
# ---------------------------------------------------------------------------
echo "--- Cache ---"

CACHE_STATS=$("$BIN" cache stats 2>&1)
CACHE_EXIT=$?
if [ $CACHE_EXIT -eq 0 ]; then
    pass "cache stats (Exitcode 0)"
else
    fail "cache stats" "Exitcode $CACHE_EXIT: $CACHE_STATS"
fi

CACHE_CLEAR=$("$BIN" cache clear 2>&1)
if echo "$CACHE_CLEAR" | grep -qi "geleert"; then
    pass "cache clear (Bestätigung in Ausgabe)"
else
    fail "cache clear" "Unerwartete Ausgabe: $CACHE_CLEAR"
fi

CACHE_JSON=$("$BIN" cache stats --json 2>&1)
if echo "$CACHE_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    pass "cache stats --json (valides JSON)"
else
    fail "cache stats --json" "Kein valides JSON: $CACHE_JSON"
fi

echo ""

# ---------------------------------------------------------------------------
# preset save / export / import
# ---------------------------------------------------------------------------
echo "--- Preset save/export/import ---"

RECIPE_FILE="$TMPDIR/test.iphotorecipe"

# preset save: speichert Anpassungen eines Bildes als neues Preset
PRESET_SAVE=$("$BIN" preset save "$INPUT_PNG" --name "TestPreset" --json 2>&1)
PRESET_SAVE_EXIT=$?
if [ $PRESET_SAVE_EXIT -eq 0 ] && echo "$PRESET_SAVE" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok') == True" 2>/dev/null; then
    pass "preset save (Exitcode 0, JSON ok:true)"
else
    fail "preset save" "Exit $PRESET_SAVE_EXIT: $PRESET_SAVE"
fi

# preset list: TestPreset muss jetzt erscheinen
PRESET_LIST=$("$BIN" preset list 2>&1)
if echo "$PRESET_LIST" | grep -q "TestPreset"; then
    pass "preset list zeigt gespeichertes Preset"
else
    fail "preset list" "TestPreset nicht gefunden: $PRESET_LIST"
fi

# preset export: exportiert Chrome (builtin) in eine Datei
PRESET_EXPORT=$("$BIN" preset export Chrome --output "$RECIPE_FILE" --json 2>&1)
PRESET_EXPORT_EXIT=$?
if [ $PRESET_EXPORT_EXIT -eq 0 ] && [ -f "$RECIPE_FILE" ]; then
    pass "preset export (Exitcode 0, Datei erstellt)"
else
    fail "preset export" "Exit $PRESET_EXPORT_EXIT: $PRESET_EXPORT"
fi

# preset import: importiert die exportierte Datei
PRESET_IMPORT=$("$BIN" preset import "$RECIPE_FILE" --json 2>&1)
PRESET_IMPORT_EXIT=$?
if [ $PRESET_IMPORT_EXIT -eq 0 ] && echo "$PRESET_IMPORT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok') == True" 2>/dev/null; then
    pass "preset import (Exitcode 0, JSON ok:true)"
else
    fail "preset import" "Exit $PRESET_IMPORT_EXIT: $PRESET_IMPORT"
fi

# preset import mit ungültiger Datei: muss Fehler liefern
PRESET_IMPORT_BAD_EXIT=0
"$BIN" preset import /nonexistent/file.iphotorecipe > /dev/null 2>&1 || PRESET_IMPORT_BAD_EXIT=$?
if [ $PRESET_IMPORT_BAD_EXIT -ne 0 ]; then
    pass "preset import ungültige Datei (Exitcode != 0)"
else
    fail "preset import ungültige Datei" "Hätte fehlschlagen sollen (Exitcode 0)"
fi

echo ""

# ---------------------------------------------------------------------------
# adjust --crop / --rotate
# ---------------------------------------------------------------------------
echo "--- Adjust crop/rotate ---"

CROP_OUT="$TMPDIR/crop_out.png"
CROP_RESULT=$("$BIN" adjust "$INPUT_PNG" --output "$CROP_OUT" --format png --crop 0.1,0.1,0.8,0.8 2>&1)
CROP_EXIT=$?
if [ $CROP_EXIT -eq 0 ] && [ -f "$CROP_OUT" ]; then
    pass "adjust --crop (Exitcode 0, Datei erstellt)"
else
    fail "adjust --crop" "Exit $CROP_EXIT: $CROP_RESULT"
fi

ROTATE_OUT="$TMPDIR/rotate_out.png"
ROTATE_RESULT=$("$BIN" adjust "$INPUT_PNG" --output "$ROTATE_OUT" --format png --rotate 90 2>&1)
ROTATE_EXIT=$?
if [ $ROTATE_EXIT -eq 0 ] && [ -f "$ROTATE_OUT" ]; then
    pass "adjust --rotate 90 (Exitcode 0, Datei erstellt)"
else
    fail "adjust --rotate" "Exit $ROTATE_EXIT: $ROTATE_RESULT"
fi

ROTATE_BAD_EXIT=0
"$BIN" adjust "$INPUT_PNG" --output "$TMPDIR/rot_bad.png" --format png --rotate 45 > /dev/null 2>&1 || ROTATE_BAD_EXIT=$?
if [ $ROTATE_BAD_EXIT -ne 0 ]; then
    pass "adjust --rotate ungültig (Exitcode != 0)"
else
    fail "adjust --rotate ungültig" "Hätte fehlschlagen sollen (Exitcode 0)"
fi

echo ""

# ---------------------------------------------------------------------------
# people export-names / import-names
# ---------------------------------------------------------------------------
echo "--- People export-names/import-names ---"

NAMES_CSV="$TMPDIR/names.csv"

EXPORT_NAMES=$("$BIN" people export-names --output "$NAMES_CSV" --json 2>&1)
EXPORT_NAMES_EXIT=$?
if [ $EXPORT_NAMES_EXIT -eq 0 ] && [ -f "$NAMES_CSV" ]; then
    pass "people export-names (Exitcode 0, CSV erstellt)"
else
    fail "people export-names" "Exit $EXPORT_NAMES_EXIT: $EXPORT_NAMES"
fi

# import-names mit erzeugter CSV muss Exitcode 0 liefern
IMPORT_NAMES=$("$BIN" people import-names "$NAMES_CSV" --json 2>&1)
IMPORT_NAMES_EXIT=$?
if [ $IMPORT_NAMES_EXIT -eq 0 ] && echo "$IMPORT_NAMES" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok') == True" 2>/dev/null; then
    pass "people import-names (Exitcode 0, JSON ok:true)"
else
    fail "people import-names" "Exit $IMPORT_NAMES_EXIT: $IMPORT_NAMES"
fi

# import-names mit nicht-existenter Datei muss Fehler liefern
IMPORT_NAMES_BAD_EXIT=0
"$BIN" people import-names /nonexistent/names.csv > /dev/null 2>&1 || IMPORT_NAMES_BAD_EXIT=$?
if [ $IMPORT_NAMES_BAD_EXIT -ne 0 ]; then
    pass "people import-names ungültige Datei (Exitcode != 0)"
else
    fail "people import-names ungültige Datei" "Hätte fehlschlagen sollen (Exitcode 0)"
fi

echo ""

# ---------------------------------------------------------------------------
# watched list / add / remove / check
# ---------------------------------------------------------------------------
echo "--- Watched Folders ---"

WATCHED_LIST=$("$BIN" watched list 2>&1)
if [ $? -eq 0 ]; then
    pass "watched list (Exitcode 0)"
else
    fail "watched list" "Exitcode != 0: $WATCHED_LIST"
fi

WATCHED_LIST_JSON=$("$BIN" watched list --json 2>&1)
if echo "$WATCHED_LIST_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    pass "watched list --json (valides JSON-Array)"
else
    fail "watched list --json" "Kein valides JSON: $WATCHED_LIST_JSON"
fi

# add: Tmpdir ist ein gültiges Verzeichnis → Exitcode 0
WATCHED_ADD=$("$BIN" watched add "$TMPDIR" --json 2>&1)
WATCHED_ADD_EXIT=$?
if [ $WATCHED_ADD_EXIT -eq 0 ] && echo "$WATCHED_ADD" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok') == True" 2>/dev/null; then
    pass "watched add (Exitcode 0, JSON ok:true)"
else
    fail "watched add" "Exit $WATCHED_ADD_EXIT: $WATCHED_ADD"
fi

# check: Tmpdir ist erreichbar → available:true
WATCHED_CHECK=$("$BIN" watched check --json 2>&1)
if echo "$WATCHED_CHECK" | python3 -c "import sys,json; a=json.load(sys.stdin); assert any(e.get('available') for e in a)" 2>/dev/null; then
    pass "watched check --json (Ordner verfügbar)"
else
    fail "watched check --json" "Kein verfügbarer Ordner: $WATCHED_CHECK"
fi

# remove: gerade hinzugefügten Ordner wieder entfernen
WATCHED_ID=$(echo "$WATCHED_ADD" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
if [ -n "$WATCHED_ID" ]; then
    WATCHED_RM=$("$BIN" watched remove "$WATCHED_ID" --json 2>&1)
    WATCHED_RM_EXIT=$?
    if [ $WATCHED_RM_EXIT -eq 0 ] && echo "$WATCHED_RM" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok') == True" 2>/dev/null; then
        pass "watched remove (Exitcode 0, JSON ok:true)"
    else
        fail "watched remove" "Exit $WATCHED_RM_EXIT: $WATCHED_RM"
    fi
else
    fail "watched remove" "ID aus watched add konnte nicht gelesen werden"
fi

# add mit nicht-existentem Pfad → Fehler
WATCHED_ADD_BAD_EXIT=0
"$BIN" watched add /nonexistent/path/xyz > /dev/null 2>&1 || WATCHED_ADD_BAD_EXIT=$?
if [ $WATCHED_ADD_BAD_EXIT -ne 0 ]; then
    pass "watched add ungültiger Pfad (Exitcode != 0)"
else
    fail "watched add ungültiger Pfad" "Hätte fehlschlagen sollen"
fi

echo ""

# ---------------------------------------------------------------------------
# backup config get / set
# ---------------------------------------------------------------------------
echo "--- Backup Config ---"

BACKUP_GET=$("$BIN" backup get --json 2>&1)
BACKUP_GET_EXIT=$?
if [ $BACKUP_GET_EXIT -eq 0 ] && echo "$BACKUP_GET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'jpeg_quality' in d and 'collision_mode' in d" 2>/dev/null; then
    pass "backup get --json (Exitcode 0, Felder vorhanden)"
else
    fail "backup get --json" "Exit $BACKUP_GET_EXIT: $BACKUP_GET"
fi

BACKUP_SET=$("$BIN" backup set --quality 0.9 --mode skip --json 2>&1)
BACKUP_SET_EXIT=$?
if [ $BACKUP_SET_EXIT -eq 0 ] && echo "$BACKUP_SET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok') == True" 2>/dev/null; then
    pass "backup set --quality --mode (Exitcode 0, JSON ok:true)"
else
    fail "backup set" "Exit $BACKUP_SET_EXIT: $BACKUP_SET"
fi

# set ungültiger Mode → Fehler
BACKUP_SET_BAD_EXIT=0
"$BIN" backup set --mode invalidmode > /dev/null 2>&1 || BACKUP_SET_BAD_EXIT=$?
if [ $BACKUP_SET_BAD_EXIT -ne 0 ]; then
    pass "backup set ungültiger Mode (Exitcode != 0)"
else
    fail "backup set ungültiger Mode" "Hätte fehlschlagen sollen"
fi

echo ""

# ---------------------------------------------------------------------------
# config get / set
# ---------------------------------------------------------------------------
echo "--- Config Get/Set ---"

# show returns JSON object
CONFIG_SHOW=$("$BIN" config show 2>&1)
CONFIG_SHOW_EXIT=$?
if [ $CONFIG_SHOW_EXIT -eq 0 ]; then
    pass "config show (Exitcode 0)"
else
    fail "config show" "Exit $CONFIG_SHOW_EXIT: $CONFIG_SHOW"
fi

# set a known badge key to true
CONFIG_SET=$("$BIN" config set badge.rating true 2>&1)
CONFIG_SET_EXIT=$?
if [ $CONFIG_SET_EXIT -eq 0 ]; then
    pass "config set badge.rating true (Exitcode 0)"
else
    fail "config set badge.rating true" "Exit $CONFIG_SET_EXIT: $CONFIG_SET"
fi

# get the key back and verify it contains "1" or "true"
CONFIG_GET=$("$BIN" config get badge.rating 2>&1)
CONFIG_GET_EXIT=$?
if [ $CONFIG_GET_EXIT -eq 0 ] && (echo "$CONFIG_GET" | grep -qE "^(1|true)$"); then
    pass "config get badge.rating (Wert '1' oder 'true' erwartet)"
else
    fail "config get badge.rating" "Exit $CONFIG_GET_EXIT, Ausgabe: $CONFIG_GET"
fi

# get unknown key → error
CONFIG_GET_BAD_EXIT=0
"$BIN" config get badge.unknownkey > /dev/null 2>&1 || CONFIG_GET_BAD_EXIT=$?
if [ $CONFIG_GET_BAD_EXIT -ne 0 ]; then
    pass "config get unbekannter Schlüssel (Exitcode != 0)"
else
    fail "config get unbekannter Schlüssel" "Hätte fehlschlagen sollen"
fi

# set unknown key → error
CONFIG_SET_BAD_EXIT=0
"$BIN" config set badge.nonexistent true > /dev/null 2>&1 || CONFIG_SET_BAD_EXIT=$?
if [ $CONFIG_SET_BAD_EXIT -ne 0 ]; then
    pass "config set unbekannter Schlüssel (Exitcode != 0)"
else
    fail "config set unbekannter Schlüssel" "Hätte fehlschlagen sollen"
fi

echo ""

# ---------------------------------------------------------------------------
# metadata get / set
# ---------------------------------------------------------------------------
echo "--- Metadata Get/Set ---"

# metadata get on test PNG → returns JSON with editable keys
META_GET=$("$BIN" metadata get "$INPUT_PNG" --json 2>&1)
META_GET_EXIT=$?
if [ $META_GET_EXIT -eq 0 ] && echo "$META_GET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d, dict)" 2>/dev/null; then
    pass "metadata get --json (Exitcode 0, JSON-Objekt)"
else
    fail "metadata get --json" "Exit $META_GET_EXIT: $META_GET"
fi

# metadata set title + caption on JPEG copy of PNG (PNG supports IPTC via ImageIO)
META_JPEG="$TMPDIR/meta_test.jpg"
"$BIN" export "$INPUT_PNG" --format jpeg --output "$META_JPEG" > /dev/null 2>&1 || true
if [ -f "$META_JPEG" ]; then
    META_SET=$("$BIN" metadata set "$META_JPEG" --title "TestTitel" --caption "TestBeschreibung" --json 2>&1)
    META_SET_EXIT=$?
    if [ $META_SET_EXIT -eq 0 ] && echo "$META_SET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok') == True" 2>/dev/null; then
        pass "metadata set --title --caption --json (Exitcode 0, ok:true)"
    else
        fail "metadata set" "Exit $META_SET_EXIT: $META_SET"
    fi

    # read back title
    META_GET2=$("$BIN" metadata get "$META_JPEG" --json 2>&1)
    if echo "$META_GET2" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('iptc.ObjectName','') == 'TestTitel'" 2>/dev/null; then
        pass "metadata get nach set (Titel korrekt gelesen)"
    else
        fail "metadata get nach set" "Titel nicht gefunden in: $META_GET2"
    fi
else
    fail "metadata set" "JPEG-Testbild konnte nicht erstellt werden"
fi

# metadata set on RAW (raf extension) → error expected
META_RAW="$TMPDIR/fake.raf"
cp "$INPUT_PNG" "$META_RAW"
META_SET_RAF_EXIT=0
"$BIN" metadata set "$META_RAW" --title "x" > /dev/null 2>&1 || META_SET_RAF_EXIT=$?
if [ $META_SET_RAF_EXIT -ne 0 ]; then
    pass "metadata set auf RAW-Datei (Exitcode != 0)"
else
    fail "metadata set auf RAW-Datei" "Hätte fehlschlagen sollen"
fi

echo ""

# ---------------------------------------------------------------------------
# local-adjustments list / clear
# ---------------------------------------------------------------------------
echo "--- Local Adjustments ---"

# list on unknown path → 0 exit, reports no adjustments
LA_LIST=$("$BIN" local-adjustments list "/nonexistent/no_adj.jpg" --json 2>&1)
LA_LIST_EXIT=$?
if [ $LA_LIST_EXIT -eq 0 ] && echo "$LA_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('count',1) == 0" 2>/dev/null; then
    pass "local-adjustments list (kein Eintrag → count 0)"
else
    fail "local-adjustments list" "Exit $LA_LIST_EXIT: $LA_LIST"
fi

# clear on path that has no adjustments stored → ok:true, cleared:0
LA_CLEAR=$("$BIN" local-adjustments clear "/nonexistent/no_adj.jpg" --json 2>&1)
LA_CLEAR_EXIT=$?
if [ $LA_CLEAR_EXIT -eq 0 ] && echo "$LA_CLEAR" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok') == True and d.get('cleared',1) == 0" 2>/dev/null; then
    pass "local-adjustments clear (kein Eintrag → cleared 0, ok true)"
else
    fail "local-adjustments clear" "Exit $LA_CLEAR_EXIT: $LA_CLEAR"
fi

# missing subcommand → error exit
LA_BAD_EXIT=0
"$BIN" local-adjustments 2>/dev/null || LA_BAD_EXIT=$?
if [ $LA_BAD_EXIT -ne 0 ]; then
    pass "local-adjustments (kein Subbefehl → Fehler)"
else
    fail "local-adjustments (kein Subbefehl)" "Hätte fehlschlagen sollen"
fi

# list without path argument → error exit
LA_NOPATH_EXIT=0
"$BIN" local-adjustments list 2>/dev/null || LA_NOPATH_EXIT=$?
if [ $LA_NOPATH_EXIT -ne 0 ]; then
    pass "local-adjustments list (kein Pfad → Fehler)"
else
    fail "local-adjustments list (kein Pfad)" "Hätte fehlschlagen sollen"
fi

echo ""

# ---------------------------------------------------------------------------
# smartfolder sync
# ---------------------------------------------------------------------------
echo "--- SmartFolder Sync ---"

# sync with no smart folders defined → succeeds, reports 0 synced entries
SF_SYNC=$("$BIN" smartfolder sync --json 2>&1)
SF_SYNC_EXIT=$?
if [ $SF_SYNC_EXIT -eq 0 ] && echo "$SF_SYNC" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok') == True" 2>/dev/null; then
    pass "smartfolder sync (keine Ordner → ok true)"
else
    fail "smartfolder sync" "Exit $SF_SYNC_EXIT: $SF_SYNC"
fi

# sync a non-existent named folder → error exit
SF_SYNC_BAD_EXIT=0
"$BIN" smartfolder sync "NichtVorhanden_TestFolder_XYZ" 2>/dev/null || SF_SYNC_BAD_EXIT=$?
if [ $SF_SYNC_BAD_EXIT -ne 0 ]; then
    pass "smartfolder sync (unbekannter Name → Fehler)"
else
    fail "smartfolder sync (unbekannter Name)" "Hätte fehlschlagen sollen"
fi

echo ""

# ---------------------------------------------------------------------------
# rating histogram
# ---------------------------------------------------------------------------
echo "--- Rating Histogram ---"

HIST_DB="$TMPDIR/hist_catalog.db"
HIST_A="$TMPDIR/hist_a.png"; HIST_B="$TMPDIR/hist_b.png"
cp "$INPUT_PNG" "$HIST_A"; cp "$INPUT_PNG" "$HIST_B"
IPHOTO_CATALOG_DB="$HIST_DB" "$BIN" rating "$HIST_A" --set 5 > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$HIST_DB" "$BIN" rating "$HIST_B" --set 3 > /dev/null 2>&1 || true

HIST_EXIT=0
HIST_OUT=$(IPHOTO_CATALOG_DB="$HIST_DB" "$BIN" rating histogram --json 2>&1) || HIST_EXIT=$?
if [ $HIST_EXIT -eq 0 ] && echo "$HIST_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
b=d['byStars']
assert sorted(b.keys())==['0','1','2','3','4','5']
assert b['5']==1 and b['3']==1 and d['rated']==2
assert abs(d['average']-4.0)<0.01
" 2>/dev/null; then
    pass "rating histogram --json (★5=1, ★3=1, Ø 4.0)"
else
    fail "rating histogram --json" "Exit $HIST_EXIT: $HIST_OUT"
fi

# leerer Katalog → rated 0
HIST_EMPTY_EXIT=0
HIST_EMPTY=$(IPHOTO_CATALOG_DB="$TMPDIR/hist_empty.db" "$BIN" rating histogram --json 2>&1) || HIST_EMPTY_EXIT=$?
if [ $HIST_EMPTY_EXIT -eq 0 ] && echo "$HIST_EMPTY" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['rated']==0 and d['average']==0" 2>/dev/null; then
    pass "rating histogram (leerer Katalog → rated 0)"
else
    fail "rating histogram (leer)" "Exit $HIST_EMPTY_EXIT: $HIST_EMPTY"
fi

# unbekanntes Argument → Fehler
HIST_BAD_EXIT=0
"$BIN" rating histogram --bogus > /dev/null 2>&1 || HIST_BAD_EXIT=$?
if [ $HIST_BAD_EXIT -ne 0 ]; then
    pass "rating histogram --bogus (Fehler)"
else
    fail "rating histogram --bogus" "Hätte fehlschlagen sollen"
fi

echo ""

# ---------------------------------------------------------------------------
# exif get / set / films
# ---------------------------------------------------------------------------
echo "--- EXIF ---"

EXIF_DB="$TMPDIR/exif_catalog.db"
EXIF_IMG="$TMPDIR/exif_test.png"
cp "$INPUT_PNG" "$EXIF_IMG"

# get auf unbekanntes Bild → Fehler
EXIF_GET_MISS_EXIT=0
IPHOTO_CATALOG_DB="$EXIF_DB" "$BIN" exif get "/nonexistent/none.jpg" --json > /dev/null 2>&1 || EXIF_GET_MISS_EXIT=$?
if [ $EXIF_GET_MISS_EXIT -ne 0 ]; then
    pass "exif get (nicht im Katalog → Fehler)"
else
    fail "exif get (nicht im Katalog)" "Hätte fehlschlagen sollen"
fi

# set registriert Bild und speichert Werte
EXIF_SET_EXIT=0
EXIF_SET=$(IPHOTO_CATALOG_DB="$EXIF_DB" "$BIN" exif set "$EXIF_IMG" --iso 400 --focal 35 --aperture 2.8 --lens "XF35mmF1.4 R" --film "Classic Chrome" --hdr true --json 2>&1) || EXIF_SET_EXIT=$?
if [ $EXIF_SET_EXIT -eq 0 ] && echo "$EXIF_SET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['iso']==400 and d['hdr']==True" 2>/dev/null; then
    pass "exif set --json (ok, iso 400, hdr true)"
else
    fail "exif set --json" "Exit $EXIF_SET_EXIT: $EXIF_SET"
fi

# get liest persistierte Werte (neuer Prozess)
EXIF_GET_EXIT=0
EXIF_GET=$(IPHOTO_CATALOG_DB="$EXIF_DB" "$BIN" exif get "$EXIF_IMG" --json 2>&1) || EXIF_GET_EXIT=$?
if [ $EXIF_GET_EXIT -eq 0 ] && echo "$EXIF_GET" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['iso']==400 and abs(d['focalLength']-35)<0.01 and abs(d['aperture']-2.8)<0.01
assert d['lens']=='XF35mmF1.4 R' and d['film']=='Classic Chrome'
" 2>/dev/null; then
    pass "exif get nach set (Werte persistiert)"
else
    fail "exif get nach set" "Exit $EXIF_GET_EXIT: $EXIF_GET"
fi

# partielles set behält andere Felder
IPHOTO_CATALOG_DB="$EXIF_DB" "$BIN" exif set "$EXIF_IMG" --iso 800 > /dev/null 2>&1 || true
EXIF_GET2=$(IPHOTO_CATALOG_DB="$EXIF_DB" "$BIN" exif get "$EXIF_IMG" --json 2>&1) || true
if echo "$EXIF_GET2" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['iso']==800 and d['film']=='Classic Chrome'" 2>/dev/null; then
    pass "exif set partiell (iso 800, Film unverändert)"
else
    fail "exif set partiell" "$EXIF_GET2"
fi

# films listet Filmsimulation
EXIF_FILMS_EXIT=0
EXIF_FILMS=$(IPHOTO_CATALOG_DB="$EXIF_DB" "$BIN" exif films --json 2>&1) || EXIF_FILMS_EXIT=$?
if [ $EXIF_FILMS_EXIT -eq 0 ] && echo "$EXIF_FILMS" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d==['Classic Chrome']" 2>/dev/null; then
    pass "exif films --json (['Classic Chrome'])"
else
    fail "exif films --json" "Exit $EXIF_FILMS_EXIT: $EXIF_FILMS"
fi

# ungültiger ISO-Wert → Fehler
EXIF_BAD_ISO_EXIT=0
IPHOTO_CATALOG_DB="$EXIF_DB" "$BIN" exif set "$EXIF_IMG" --iso abc > /dev/null 2>&1 || EXIF_BAD_ISO_EXIT=$?
if [ $EXIF_BAD_ISO_EXIT -ne 0 ]; then
    pass "exif set --iso abc (Fehler)"
else
    fail "exif set --iso abc" "Hätte fehlschlagen sollen"
fi

# set auf nicht existierende Datei → Fehler
EXIF_SET_MISS_EXIT=0
IPHOTO_CATALOG_DB="$EXIF_DB" "$BIN" exif set "/nonexistent/none.jpg" --iso 100 > /dev/null 2>&1 || EXIF_SET_MISS_EXIT=$?
if [ $EXIF_SET_MISS_EXIT -ne 0 ]; then
    pass "exif set (Datei fehlt → Fehler)"
else
    fail "exif set (Datei fehlt)" "Hätte fehlschlagen sollen"
fi

# unbekannter Subbefehl → Fehler
EXIF_BAD_EXIT=0
"$BIN" exif bogus > /dev/null 2>&1 || EXIF_BAD_EXIT=$?
if [ $EXIF_BAD_EXIT -ne 0 ]; then
    pass "exif bogus (Fehler)"
else
    fail "exif bogus" "Hätte fehlschlagen sollen"
fi

echo ""

# ---------------------------------------------------------------------------
# quality override list / set / clear
# ---------------------------------------------------------------------------
echo "--- QUALITY OVERRIDE ---"

QO_DB="$TMPDIR/qo_catalog.db"
QO_IMG="$TMPDIR/qo_test.png"
cp "$INPUT_PNG" "$QO_IMG"

# leere Liste auf frischem Katalog
QO_LIST_EXIT=0
QO_LIST=$(IPHOTO_CATALOG_DB="$QO_DB" "$BIN" quality override list --json 2>&1) || QO_LIST_EXIT=$?
if [ $QO_LIST_EXIT -eq 0 ] && echo "$QO_LIST" | python3 -c "import sys,json; assert json.load(sys.stdin)==[]" 2>/dev/null; then
    pass "quality override list --json (leer)"
else
    fail "quality override list --json (leer)" "Exit $QO_LIST_EXIT: $QO_LIST"
fi

# Bild nicht im Katalog → Fehler
QO_MISS_EXIT=0
IPHOTO_CATALOG_DB="$QO_DB" "$BIN" quality override "/nonexistent/none.jpg" --blur on > /dev/null 2>&1 || QO_MISS_EXIT=$?
if [ $QO_MISS_EXIT -ne 0 ]; then
    pass "quality override (nicht im Katalog → Fehler)"
else
    fail "quality override (nicht im Katalog)" "Hätte fehlschlagen sollen"
fi

# Bild registrieren (exif set legt Katalog-Eintrag an), dann Overrides setzen
IPHOTO_CATALOG_DB="$QO_DB" "$BIN" exif set "$QO_IMG" --iso 100 > /dev/null 2>&1 || true
QO_SET_EXIT=0
QO_SET=$(IPHOTO_CATALOG_DB="$QO_DB" "$BIN" quality override "$QO_IMG" --blur on --eyes-closed on --json 2>&1) || QO_SET_EXIT=$?
if [ $QO_SET_EXIT -eq 0 ] && echo "$QO_SET" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['blur'] and d['eyes_closed'] and not d['under'] and not d['over'] and d['changed']
" 2>/dev/null; then
    pass "quality override --blur on --eyes-closed on --json"
else
    fail "quality override set" "Exit $QO_SET_EXIT: $QO_SET"
fi

# Persistenz: list im neuen Prozess
QO_LIST2=$(IPHOTO_CATALOG_DB="$QO_DB" "$BIN" quality override list --json 2>&1) || true
if echo "$QO_LIST2" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert len(d)==1 and d[0]['blur'] and d[0]['eyes_closed'] and not d[0]['over']
" 2>/dev/null; then
    pass "quality override list nach set (1 Eintrag persistiert)"
else
    fail "quality override list nach set" "$QO_LIST2"
fi

# ungültiger Wert → Fehler
QO_BAD_EXIT=0
IPHOTO_CATALOG_DB="$QO_DB" "$BIN" quality override "$QO_IMG" --blur maybe > /dev/null 2>&1 || QO_BAD_EXIT=$?
if [ $QO_BAD_EXIT -ne 0 ]; then
    pass "quality override --blur maybe (Fehler)"
else
    fail "quality override --blur maybe" "Hätte fehlschlagen sollen"
fi

# unbekannte Option → Fehler
QO_OPT_EXIT=0
IPHOTO_CATALOG_DB="$QO_DB" "$BIN" quality override "$QO_IMG" --bogus on > /dev/null 2>&1 || QO_OPT_EXIT=$?
if [ $QO_OPT_EXIT -ne 0 ]; then
    pass "quality override --bogus (Fehler)"
else
    fail "quality override --bogus" "Hätte fehlschlagen sollen"
fi

# --clear setzt alles zurück, Liste wieder leer
IPHOTO_CATALOG_DB="$QO_DB" "$BIN" quality override "$QO_IMG" --clear > /dev/null 2>&1 || true
QO_LIST3=$(IPHOTO_CATALOG_DB="$QO_DB" "$BIN" quality override list --json 2>&1) || true
if echo "$QO_LIST3" | python3 -c "import sys,json; assert json.load(sys.stdin)==[]" 2>/dev/null; then
    pass "quality override --clear (Liste leer)"
else
    fail "quality override --clear" "$QO_LIST3"
fi

# fehlendes Argument → Fehler
QO_NOARG_EXIT=0
IPHOTO_CATALOG_DB="$QO_DB" "$BIN" quality override > /dev/null 2>&1 || QO_NOARG_EXIT=$?
if [ $QO_NOARG_EXIT -ne 0 ]; then
    pass "quality override (ohne Argument → Fehler)"
else
    fail "quality override (ohne Argument)" "Hätte fehlschlagen sollen"
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
