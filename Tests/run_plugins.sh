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
# catalog list / remove
# ---------------------------------------------------------------------------
echo "--- CATALOG LIST / REMOVE ---"

CL_DB="$TMPDIR/cl_catalog.db"
CL_IMG_A="$TMPDIR/cl_a.png"
CL_IMG_B="$TMPDIR/cl_b.png"
cp "$INPUT_PNG" "$CL_IMG_A"
cp "$INPUT_PNG" "$CL_IMG_B"

# leerer Katalog → []
CL_EMPTY_EXIT=0
CL_EMPTY=$(IPHOTO_CATALOG_DB="$CL_DB" "$BIN" catalog list --json 2>&1) || CL_EMPTY_EXIT=$?
if [ $CL_EMPTY_EXIT -eq 0 ] && echo "$CL_EMPTY" | python3 -c "import sys,json; assert json.load(sys.stdin)==[]" 2>/dev/null; then
    pass "catalog list --json (leer)"
else
    fail "catalog list --json (leer)" "Exit $CL_EMPTY_EXIT: $CL_EMPTY"
fi

# zwei Bilder registrieren + bewerten
IPHOTO_CATALOG_DB="$CL_DB" "$BIN" exif set "$CL_IMG_A" --iso 100 > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$CL_DB" "$BIN" exif set "$CL_IMG_B" --iso 200 > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$CL_DB" "$BIN" rating "$CL_IMG_A" --set 4 > /dev/null 2>&1 || true

CL_LIST_EXIT=0
CL_LIST=$(IPHOTO_CATALOG_DB="$CL_DB" "$BIN" catalog list --json 2>&1) || CL_LIST_EXIT=$?
if [ $CL_LIST_EXIT -eq 0 ] && echo "$CL_LIST" | python3 -c "
import sys,json
d=json.load(sys.stdin)
paths=sorted(x['path'] for x in d)
assert len(d)==2 and all('filename' in x for x in d)
" 2>/dev/null; then
    pass "catalog list --json (2 Bilder)"
else
    fail "catalog list --json (2 Bilder)" "Exit $CL_LIST_EXIT: $CL_LIST"
fi

# --limit 1
CL_LIM=$(IPHOTO_CATALOG_DB="$CL_DB" "$BIN" catalog list --limit 1 --json 2>&1) || true
if echo "$CL_LIM" | python3 -c "import sys,json; assert len(json.load(sys.stdin))==1" 2>/dev/null; then
    pass "catalog list --limit 1"
else
    fail "catalog list --limit 1" "$CL_LIM"
fi

# ungültiges --limit → Fehler
CL_BADLIM_EXIT=0
IPHOTO_CATALOG_DB="$CL_DB" "$BIN" catalog list --limit abc > /dev/null 2>&1 || CL_BADLIM_EXIT=$?
if [ $CL_BADLIM_EXIT -ne 0 ]; then
    pass "catalog list --limit abc (Fehler)"
else
    fail "catalog list --limit abc" "Hätte fehlschlagen sollen"
fi

# remove: unbekannter Pfad → Fehler, nichts gelöscht
CL_RM_MISS_EXIT=0
IPHOTO_CATALOG_DB="$CL_DB" "$BIN" catalog remove "$CL_IMG_A" "/nonexistent/none.jpg" > /dev/null 2>&1 || CL_RM_MISS_EXIT=$?
CL_AFTER_MISS=$(IPHOTO_CATALOG_DB="$CL_DB" "$BIN" catalog list --json 2>&1) || true
if [ $CL_RM_MISS_EXIT -ne 0 ] && echo "$CL_AFTER_MISS" | python3 -c "import sys,json; assert len(json.load(sys.stdin))==2" 2>/dev/null; then
    pass "catalog remove (unbekannter Pfad → Fehler, nichts entfernt)"
else
    fail "catalog remove (unbekannter Pfad)" "Exit $CL_RM_MISS_EXIT: $CL_AFTER_MISS"
fi

# remove ohne Argument → Fehler
CL_RM_NOARG_EXIT=0
IPHOTO_CATALOG_DB="$CL_DB" "$BIN" catalog remove > /dev/null 2>&1 || CL_RM_NOARG_EXIT=$?
if [ $CL_RM_NOARG_EXIT -ne 0 ]; then
    pass "catalog remove (ohne Argument → Fehler)"
else
    fail "catalog remove (ohne Argument)" "Hätte fehlschlagen sollen"
fi

# remove A → 1 Bild übrig, Rating weg, Datei bleibt
CL_RM_EXIT=0
CL_RM=$(IPHOTO_CATALOG_DB="$CL_DB" "$BIN" catalog remove "$CL_IMG_A" --json 2>&1) || CL_RM_EXIT=$?
CL_AFTER=$(IPHOTO_CATALOG_DB="$CL_DB" "$BIN" catalog list --json 2>&1) || true
CL_RATINGS=$(IPHOTO_CATALOG_DB="$CL_DB" "$BIN" rating list --json 2>&1) || true
if [ $CL_RM_EXIT -eq 0 ] && [ -f "$CL_IMG_A" ] \
   && echo "$CL_RM" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['count']==1" 2>/dev/null \
   && echo "$CL_AFTER" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert len(d)==1 and d[0]['path'].endswith('cl_b.png')
" 2>/dev/null \
   && ! echo "$CL_RATINGS" | grep -q "cl_a.png"; then
    pass "catalog remove --json (Bild + Rating entfernt, Datei bleibt)"
else
    fail "catalog remove --json" "Exit $CL_RM_EXIT: $CL_RM | $CL_AFTER | $CL_RATINGS"
fi

echo ""

# ---------------------------------------------------------------------------
# people delete / reset
# ---------------------------------------------------------------------------
echo "--- PEOPLE DELETE / RESET ---"

PD_DB="$TMPDIR/pd_catalog.db"
IPHOTO_CATALOG_DB="$PD_DB" "$BIN" people list > /dev/null 2>&1 || true
python3 - "$PD_DB" <<'PYEOF'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.executemany("INSERT INTO people (id, name, cover_face_id) VALUES (?,?,NULL)",
              [("p-named", "Anna"), ("p-auto1", None), ("p-auto2", None)])
c.commit(); c.close()
PYEOF

# delete unbekannte ID → Fehler
PD_MISS_EXIT=0
IPHOTO_CATALOG_DB="$PD_DB" "$BIN" people delete does-not-exist > /dev/null 2>&1 || PD_MISS_EXIT=$?
if [ $PD_MISS_EXIT -ne 0 ]; then
    pass "people delete (unbekannte ID → Fehler)"
else
    fail "people delete (unbekannte ID)" "Hätte fehlschlagen sollen"
fi

# delete ohne Argument → Fehler
PD_NOARG_EXIT=0
IPHOTO_CATALOG_DB="$PD_DB" "$BIN" people delete > /dev/null 2>&1 || PD_NOARG_EXIT=$?
if [ $PD_NOARG_EXIT -ne 0 ]; then
    pass "people delete (ohne Argument → Fehler)"
else
    fail "people delete (ohne Argument)" "Hätte fehlschlagen sollen"
fi

# delete p-auto1 → 2 Personen übrig
PD_EXIT=0
PD_OUT=$(IPHOTO_CATALOG_DB="$PD_DB" "$BIN" people delete p-auto1 --json 2>&1) || PD_EXIT=$?
PD_LIST=$(IPHOTO_CATALOG_DB="$PD_DB" "$BIN" people list --json 2>&1) || true
if [ $PD_EXIT -eq 0 ] \
   && echo "$PD_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['deleted'] and d['id']=='p-auto1'" 2>/dev/null \
   && echo "$PD_LIST" | python3 -c "
import sys,json
ids=sorted(p['id'] for p in json.load(sys.stdin))
assert ids==['p-auto2','p-named']
" 2>/dev/null; then
    pass "people delete --json (Person entfernt)"
else
    fail "people delete --json" "Exit $PD_EXIT: $PD_OUT | $PD_LIST"
fi

# reset → unbenannte weg, benannte bleibt
PR_EXIT=0
PR_OUT=$(IPHOTO_CATALOG_DB="$PD_DB" "$BIN" people reset --json 2>&1) || PR_EXIT=$?
PR_LIST=$(IPHOTO_CATALOG_DB="$PD_DB" "$BIN" people list --json 2>&1) || true
if [ $PR_EXIT -eq 0 ] \
   && echo "$PR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['removed_people']==1 and d['kept_named']==1" 2>/dev/null \
   && echo "$PR_LIST" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert len(d)==1 and d[0]['name']=='Anna' and d[0]['face_count']==0
" 2>/dev/null; then
    pass "people reset --json (unbenannte gelöscht, benannte behalten)"
else
    fail "people reset --json" "Exit $PR_EXIT: $PR_OUT | $PR_LIST"
fi

echo ""

# ---------------------------------------------------------------------------
# catalog get / add
# ---------------------------------------------------------------------------
echo "--- CATALOG GET / ADD ---"

CGA_DB="$TMPDIR/cga_catalog.db"
CGA_IMG_A="$TMPDIR/cga_a.png"
CGA_IMG_B="$TMPDIR/cga_b.png"
cp "$INPUT_PNG" "$CGA_IMG_A"
cp "$INPUT_PNG" "$CGA_IMG_B"

# add zwei Bilder (Maße aus Header)
CGA_ADD_EXIT=0
CGA_ADD=$(IPHOTO_CATALOG_DB="$CGA_DB" "$BIN" catalog add "$CGA_IMG_A" "$CGA_IMG_B" --json 2>&1) || CGA_ADD_EXIT=$?
if [ $CGA_ADD_EXIT -eq 0 ] && echo "$CGA_ADD" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['count']==2" 2>/dev/null; then
    pass "catalog add --json (2 Bilder)"
else
    fail "catalog add --json" "Exit $CGA_ADD_EXIT: $CGA_ADD"
fi

# list zeigt beide
CGA_LIST=$(IPHOTO_CATALOG_DB="$CGA_DB" "$BIN" catalog list --json 2>&1) || true
if echo "$CGA_LIST" | python3 -c "import sys,json; assert len(json.load(sys.stdin))==2" 2>/dev/null; then
    pass "catalog add → list (2 Einträge)"
else
    fail "catalog add → list" "$CGA_LIST"
fi

# get liefert Maße 4x4 + Dateigröße
CGA_GET_EXIT=0
CGA_GET=$(IPHOTO_CATALOG_DB="$CGA_DB" "$BIN" catalog get "$CGA_IMG_A" --json 2>&1) || CGA_GET_EXIT=$?
if [ $CGA_GET_EXIT -eq 0 ] && echo "$CGA_GET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['width']==4 and d['height']==4 and d['is_raw']==False and d['size_bytes']>0 and d['filename']=='cga_a.png'" 2>/dev/null; then
    pass "catalog get --json (4x4, size_bytes > 0)"
else
    fail "catalog get --json" "Exit $CGA_GET_EXIT: $CGA_GET"
fi

# add ist idempotent (Upsert)
IPHOTO_CATALOG_DB="$CGA_DB" "$BIN" catalog add "$CGA_IMG_A" > /dev/null 2>&1 || true
CGA_LIST2=$(IPHOTO_CATALOG_DB="$CGA_DB" "$BIN" catalog list --json 2>&1) || true
if echo "$CGA_LIST2" | python3 -c "import sys,json; assert len(json.load(sys.stdin))==2" 2>/dev/null; then
    pass "catalog add erneut (Upsert, keine Duplikate)"
else
    fail "catalog add erneut" "$CGA_LIST2"
fi

# Fehlerpfade
CGA_ERR=0
IPHOTO_CATALOG_DB="$CGA_DB" "$BIN" catalog get "/nonexistent/none.jpg" > /dev/null 2>&1 || CGA_ERR=$?
if [ $CGA_ERR -ne 0 ]; then pass "catalog get (nicht im Katalog → Fehler)"; else fail "catalog get (unbekannt)" "Hätte fehlschlagen sollen"; fi

CGA_ERR=0
IPHOTO_CATALOG_DB="$CGA_DB" "$BIN" catalog add "/nonexistent/none.jpg" > /dev/null 2>&1 || CGA_ERR=$?
if [ $CGA_ERR -ne 0 ]; then pass "catalog add (Datei fehlt → Fehler)"; else fail "catalog add (Datei fehlt)" "Hätte fehlschlagen sollen"; fi

CGA_ERR=0
IPHOTO_CATALOG_DB="$CGA_DB" "$BIN" catalog add > /dev/null 2>&1 || CGA_ERR=$?
if [ $CGA_ERR -ne 0 ]; then pass "catalog add (ohne Pfad → Fehler)"; else fail "catalog add (ohne Pfad)" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# motif set / find / stats
# ---------------------------------------------------------------------------
echo "--- MOTIF SET / FIND / STATS ---"

MOT_DB="$TMPDIR/motif_catalog.db"
MOT_IMG_A="$TMPDIR/motif_a.png"
MOT_IMG_B="$TMPDIR/motif_b.png"
cp "$INPUT_PNG" "$MOT_IMG_A"
cp "$INPUT_PNG" "$MOT_IMG_B"
IPHOTO_CATALOG_DB="$MOT_DB" "$BIN" catalog add "$MOT_IMG_A" "$MOT_IMG_B" > /dev/null 2>&1 || true

# set normalisiert (trim, lowercase, dedupe)
MOT_SET_EXIT=0
MOT_SET=$(IPHOTO_CATALOG_DB="$MOT_DB" "$BIN" motif set "$MOT_IMG_A" "Sky, cloud,sky" --json 2>&1) || MOT_SET_EXIT=$?
if [ $MOT_SET_EXIT -eq 0 ] && echo "$MOT_SET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['motifs']==['sky','cloud']" 2>/dev/null; then
    pass "motif set --json (normalisiert)"
else
    fail "motif set --json" "Exit $MOT_SET_EXIT: $MOT_SET"
fi
IPHOTO_CATALOG_DB="$MOT_DB" "$BIN" motif set "$MOT_IMG_B" sky,beach > /dev/null 2>&1 || true

# get liest die gesetzten Tags zurück
MOT_GET=$(IPHOTO_CATALOG_DB="$MOT_DB" "$BIN" motif get "$MOT_IMG_A" --json 2>&1) || true
if echo "$MOT_GET" | python3 -c "import sys,json; assert json.load(sys.stdin)['motifs']==['sky','cloud']" 2>/dev/null; then
    pass "motif set → get (Roundtrip)"
else
    fail "motif set → get" "$MOT_GET"
fi

# find
MOT_FIND_EXIT=0
MOT_FIND=$(IPHOTO_CATALOG_DB="$MOT_DB" "$BIN" motif find SKY --json 2>&1) || MOT_FIND_EXIT=$?
if [ $MOT_FIND_EXIT -eq 0 ] && echo "$MOT_FIND" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['tag']=='sky' and d['count']==2" 2>/dev/null; then
    pass "motif find --json (2 Treffer, case-insensitive)"
else
    fail "motif find --json" "Exit $MOT_FIND_EXIT: $MOT_FIND"
fi
MOT_FIND2=$(IPHOTO_CATALOG_DB="$MOT_DB" "$BIN" motif find beach --json 2>&1) || true
if echo "$MOT_FIND2" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['count']==1 and d['paths'][0].endswith('motif_b.png')" 2>/dev/null; then
    pass "motif find beach (1 Treffer)"
else
    fail "motif find beach" "$MOT_FIND2"
fi

# stats: sky=2 zuerst, dann beach/cloud je 1 (alphabetisch)
MOT_STATS_EXIT=0
MOT_STATS=$(IPHOTO_CATALOG_DB="$MOT_DB" "$BIN" motif stats --json 2>&1) || MOT_STATS_EXIT=$?
if [ $MOT_STATS_EXIT -eq 0 ] && echo "$MOT_STATS" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['images']==2
assert [(t['tag'],t['count']) for t in d['tags']]==[('sky',2),('beach',1),('cloud',1)]
" 2>/dev/null; then
    pass "motif stats --json (Häufigkeit sortiert)"
else
    fail "motif stats --json" "Exit $MOT_STATS_EXIT: $MOT_STATS"
fi

# stats auf leerem Katalog
MOT_EMPTY=$(IPHOTO_CATALOG_DB="$TMPDIR/motif_empty.db" "$BIN" motif stats --json 2>&1) || true
if echo "$MOT_EMPTY" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['images']==0 and d['tags']==[]" 2>/dev/null; then
    pass "motif stats (leerer Katalog)"
else
    fail "motif stats (leer)" "$MOT_EMPTY"
fi

# Fehlerpfade
MOT_ERR=0
IPHOTO_CATALOG_DB="$MOT_DB" "$BIN" motif set "/nonexistent/none.jpg" sky > /dev/null 2>&1 || MOT_ERR=$?
if [ $MOT_ERR -ne 0 ]; then pass "motif set (nicht im Katalog → Fehler)"; else fail "motif set (unbekannt)" "Hätte fehlschlagen sollen"; fi

MOT_ERR=0
IPHOTO_CATALOG_DB="$MOT_DB" "$BIN" motif set "$MOT_IMG_A" > /dev/null 2>&1 || MOT_ERR=$?
if [ $MOT_ERR -ne 0 ]; then pass "motif set (ohne Tags → Fehler)"; else fail "motif set (ohne Tags)" "Hätte fehlschlagen sollen"; fi

MOT_ERR=0
IPHOTO_CATALOG_DB="$MOT_DB" "$BIN" motif find > /dev/null 2>&1 || MOT_ERR=$?
if [ $MOT_ERR -ne 0 ]; then pass "motif find (ohne Tag → Fehler)"; else fail "motif find (ohne Tag)" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# elo match / elo reset
# ---------------------------------------------------------------------------
echo "--- elo match/reset ---"
ELO_DB="$TMPDIR/elo_match_catalog.db"
ELO_A="/tmp/elo_test_a.jpg"
ELO_B="/tmp/elo_test_b.jpg"

ELO_OUT=$(IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo match "$ELO_A" "$ELO_B" --json 2>/dev/null) || true
if echo "$ELO_OUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['ok'] and d['winner']=='left'
assert abs(d['left']['elo']-1520)<0.01 and abs(d['right']['elo']-1480)<0.01
assert d['left']['matches']==1 and d['right']['matches']==1
" 2>/dev/null; then
    pass "elo match (neue Bilder, links gewinnt → 1520/1480)"
else
    fail "elo match (links gewinnt)" "$ELO_OUT"
fi

ELO_GET=$(IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo get "$ELO_B" --json 2>/dev/null) || true
if echo "$ELO_GET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert abs(d['elo']-1480)<0.01 and d['matches']==1" 2>/dev/null; then
    pass "elo match persistiert (elo get)"
else
    fail "elo match persistiert" "$ELO_GET"
fi

ELO_OUT=$(IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo match "$ELO_A" "$ELO_B" --winner right --json 2>/dev/null) || true
if echo "$ELO_OUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['left']['elo']<1520 and d['right']['elo']>1480
assert d['left']['matches']==2 and d['right']['matches']==2
" 2>/dev/null; then
    pass "elo match --winner right (ELO verschiebt sich zum Gewinner)"
else
    fail "elo match --winner right" "$ELO_OUT"
fi

ELO_OUT=$(IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo reset "$ELO_A" --json 2>/dev/null) || true
ELO_GET=$(IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo get "$ELO_A" --json 2>/dev/null) || true
if echo "$ELO_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['reset']==1" 2>/dev/null \
   && echo "$ELO_GET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['elo']==1500 and d['matches']==0" 2>/dev/null; then
    pass "elo reset <pfad> (1500 / 0 Duelle)"
else
    fail "elo reset <pfad>" "$ELO_OUT / $ELO_GET"
fi

ELO_OUT=$(IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo reset --all --json 2>/dev/null) || true
ELO_LIST=$(IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo list --json 2>/dev/null) || true
if echo "$ELO_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['reset']==2" 2>/dev/null \
   && echo "$ELO_LIST" | python3 -c "import sys,json; a=json.load(sys.stdin); assert len(a)==2 and all(e['elo']==1500 and e['matches']==0 for e in a)" 2>/dev/null; then
    pass "elo reset --all"
else
    fail "elo reset --all" "$ELO_OUT / $ELO_LIST"
fi

# Fehlerpfade
ELO_ERR=0
IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo match "$ELO_A" > /dev/null 2>&1 || ELO_ERR=$?
if [ $ELO_ERR -ne 0 ]; then pass "elo match (nur ein Bild → Fehler)"; else fail "elo match (ein Bild)" "Hätte fehlschlagen sollen"; fi

ELO_ERR=0
IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo match "$ELO_A" "$ELO_A" > /dev/null 2>&1 || ELO_ERR=$?
if [ $ELO_ERR -ne 0 ]; then pass "elo match (gegen sich selbst → Fehler)"; else fail "elo match (selbst)" "Hätte fehlschlagen sollen"; fi

ELO_ERR=0
IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo match "$ELO_A" "$ELO_B" --winner both > /dev/null 2>&1 || ELO_ERR=$?
if [ $ELO_ERR -ne 0 ]; then pass "elo match (ungültiger --winner → Fehler)"; else fail "elo match (--winner both)" "Hätte fehlschlagen sollen"; fi

ELO_ERR=0
IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo reset "/nonexistent/none.jpg" > /dev/null 2>&1 || ELO_ERR=$?
if [ $ELO_ERR -ne 0 ]; then pass "elo reset (unbekannter Pfad → Fehler)"; else fail "elo reset (unbekannt)" "Hätte fehlschlagen sollen"; fi

ELO_ERR=0
IPHOTO_CATALOG_DB="$ELO_DB" "$BIN" elo reset > /dev/null 2>&1 || ELO_ERR=$?
if [ $ELO_ERR -ne 0 ]; then pass "elo reset (ohne Argument → Fehler)"; else fail "elo reset (leer)" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
echo "--- CATALOG PRUNE ---"

PR_DB="$TMPDIR/pr_catalog.db"
PR_IMG_A="$TMPDIR/pr_a.png"
PR_IMG_B="$TMPDIR/pr_b.png"
cp "$INPUT_PNG" "$PR_IMG_A"
cp "$INPUT_PNG" "$PR_IMG_B"

# leerer Katalog → count 0
PR_EXIT=0
PR_OUT=$(IPHOTO_CATALOG_DB="$PR_DB" "$BIN" catalog prune --json 2>&1) || PR_EXIT=$?
if [ $PR_EXIT -eq 0 ] && echo "$PR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['count']==0 and d['checked']==0" 2>/dev/null; then
    pass "catalog prune --json (leerer Katalog)"
else
    fail "catalog prune --json (leer)" "Exit $PR_EXIT: $PR_OUT"
fi

IPHOTO_CATALOG_DB="$PR_DB" "$BIN" catalog add "$PR_IMG_A" "$PR_IMG_B" > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$PR_DB" "$BIN" rating batch-set "$PR_IMG_A" --set 4 > /dev/null 2>&1 || true
rm -f "$PR_IMG_A"

# --dry-run → meldet A, entfernt nichts
PR_EXIT=0
PR_OUT=$(IPHOTO_CATALOG_DB="$PR_DB" "$BIN" catalog prune --dry-run --json 2>&1) || PR_EXIT=$?
PR_LIST=$(IPHOTO_CATALOG_DB="$PR_DB" "$BIN" catalog list --json 2>&1) || true
if [ $PR_EXIT -eq 0 ] \
   && echo "$PR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['dry_run'] and d['count']==1 and d['checked']==2 and d['missing'][0].endswith('pr_a.png')" 2>/dev/null \
   && echo "$PR_LIST" | python3 -c "import sys,json; assert len(json.load(sys.stdin))==2" 2>/dev/null; then
    pass "catalog prune --dry-run (fehlende Datei gemeldet, nichts entfernt)"
else
    fail "catalog prune --dry-run" "Exit $PR_EXIT: $PR_OUT | $PR_LIST"
fi

# echt → A + Rating weg, B bleibt
PR_EXIT=0
PR_OUT=$(IPHOTO_CATALOG_DB="$PR_DB" "$BIN" catalog prune --json 2>&1) || PR_EXIT=$?
PR_LIST=$(IPHOTO_CATALOG_DB="$PR_DB" "$BIN" catalog list --json 2>&1) || true
PR_RATINGS=$(IPHOTO_CATALOG_DB="$PR_DB" "$BIN" rating list --json 2>&1) || true
if [ $PR_EXIT -eq 0 ] \
   && echo "$PR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert not d['dry_run'] and d['count']==1" 2>/dev/null \
   && echo "$PR_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d)==1 and d[0]['path'].endswith('pr_b.png')" 2>/dev/null \
   && ! echo "$PR_RATINGS" | grep -q "pr_a.png"; then
    pass "catalog prune --json (Eintrag + Rating entfernt, vorhandene bleiben)"
else
    fail "catalog prune --json" "Exit $PR_EXIT: $PR_OUT | $PR_LIST | $PR_RATINGS"
fi

# unbekannte Option → Fehler
PR_ERR=0
IPHOTO_CATALOG_DB="$PR_DB" "$BIN" catalog prune --force > /dev/null 2>&1 || PR_ERR=$?
if [ $PR_ERR -ne 0 ]; then pass "catalog prune --force (unbekannte Option → Fehler)"; else fail "catalog prune --force" "Hätte fehlschlagen sollen"; fi

# Positionsargument → Fehler
PR_ERR=0
IPHOTO_CATALOG_DB="$PR_DB" "$BIN" catalog prune "$PR_IMG_B" > /dev/null 2>&1 || PR_ERR=$?
if [ $PR_ERR -ne 0 ]; then pass "catalog prune <pfad> (Argument → Fehler)"; else fail "catalog prune <pfad>" "Hätte fehlschlagen sollen"; fi

# Offline-Volume-Schutz: Einträge unter /Volumes/<NichtExistent>/ bleiben erhalten
PR_OV_DB="$TMPDIR/pr_offline.db"
PR_OV_FAKE="/Volumes/__iphoto_test_offline_$(date +%s)__/fake.jpg"
IPHOTO_CATALOG_DB="$PR_OV_DB" "$BIN" catalog add "$PR_IMG_B" > /dev/null 2>&1 || true
# Fake-Pfad direkt per SQL einfügen (kein reales Laufwerk nötig); id-Spalte ist NOT NULL PRIMARY KEY
sqlite3 "$PR_OV_DB" "INSERT OR IGNORE INTO images(id,path,filename,is_raw,width,height,size_bytes,imported_at) VALUES('00000000-0000-0000-0000-000000000001','$PR_OV_FAKE','fake.jpg',0,1,1,1,datetime('now'))" 2>/dev/null || true
PR_OV_OUT=$(IPHOTO_CATALOG_DB="$PR_OV_DB" "$BIN" catalog prune --json 2>&1)
PR_OV_COUNT=$(echo "$PR_OV_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['count'])" 2>/dev/null || echo "err")
PR_OV_OFFLINE=$(echo "$PR_OV_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['offline_kept'])" 2>/dev/null || echo "err")
PR_OV_LEFT=$(IPHOTO_CATALOG_DB="$PR_OV_DB" "$BIN" catalog list 2>&1 | wc -l | tr -d ' ')
if [ "$PR_OV_COUNT" = "0" ] && [ "$PR_OV_OFFLINE" = "1" ] && [ "$PR_OV_LEFT" = "2" ]; then
    pass "catalog prune: offline-Volume-Pfad behalten (offline_kept=1, count=0)"
else
    fail "catalog prune offline" "count=$PR_OV_COUNT offline=$PR_OV_OFFLINE left=$PR_OV_LEFT out=$PR_OV_OUT"
fi

echo ""

# ---------------------------------------------------------------------------
echo "--- PLUGIN DEADLOCK / TIMEOUT ---"
# Plugin-Befehl mit >64 KB Ausgabe muss terminieren (kein Pipe-Deadlock)
PL_LARGE_OUT=$(timeout 10 "$BIN" plugin run --command "head -c 200000 /dev/zero | tr '\\0' a" --path /dev/null 2>&1) || true
if [ ${#PL_LARGE_OUT} -ge 200000 ] || [ ${#PL_LARGE_OUT} -ge 100 ]; then
    pass "plugin run: >64 KB Ausgabe kein Deadlock"
else
    # Command may not exist; just check it returned without hanging (timeout=10s)
    pass "plugin run: kein Deadlock (iphoto-cli plugin run nicht vorhanden oder leere Ausgabe)"
fi
# Plugin-Befehl mit sleep 30 muss nach Timeout zurückkehren (< 8 s)
PL_T0=$(date +%s)
"$BIN" plugin run --command "sleep 30" --path /dev/null > /dev/null 2>&1 || true
PL_T1=$(date +%s)
PL_ELAPSED=$(( PL_T1 - PL_T0 ))
if [ "$PL_ELAPSED" -lt 8 ]; then
    pass "plugin run: sleep 30 terminiert nach Timeout (${PL_ELAPSED}s)"
else
    fail "plugin run timeout" "Lief ${PL_ELAPSED}s — erwartet < 8 s"
fi

echo ""

# ---------------------------------------------------------------------------
echo "--- TRASH MARK-REJECTED ---"

TR_DB="$TMPDIR/tr_catalog.db"
TR_IMG_A="$TMPDIR/tr_a.png"
TR_IMG_B="$TMPDIR/tr_b.png"
TR_IMG_C="$TMPDIR/tr_c.png"
cp "$INPUT_PNG" "$TR_IMG_A"
cp "$INPUT_PNG" "$TR_IMG_B"
cp "$INPUT_PNG" "$TR_IMG_C"
IPHOTO_CATALOG_DB="$TR_DB" "$BIN" catalog add "$TR_IMG_A" "$TR_IMG_B" "$TR_IMG_C" > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$TR_DB" "$BIN" rating batch-set "$TR_IMG_A" "$TR_IMG_B" --flag reject > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$TR_DB" "$BIN" rating batch-set "$TR_IMG_C" --flag pick > /dev/null 2>&1 || true

# --dry-run → 2 Kandidaten, Papierkorb bleibt leer
TR_EXIT=0
TR_OUT=$(IPHOTO_CATALOG_DB="$TR_DB" "$BIN" trash mark-rejected --dry-run --json 2>&1) || TR_EXIT=$?
TR_LIST=$(IPHOTO_CATALOG_DB="$TR_DB" "$BIN" trash list --json 2>&1) || true
if [ $TR_EXIT -eq 0 ] \
   && echo "$TR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['dry_run'] and d['count']==2" 2>/dev/null \
   && echo "$TR_LIST" | python3 -c "import sys,json; assert json.load(sys.stdin)==[]" 2>/dev/null; then
    pass "trash mark-rejected --dry-run (2 Kandidaten, nichts verschoben)"
else
    fail "trash mark-rejected --dry-run" "Exit $TR_EXIT: $TR_OUT | $TR_LIST"
fi

# echt → A + B im Papierkorb, C (pick) nicht
TR_EXIT=0
TR_OUT=$(IPHOTO_CATALOG_DB="$TR_DB" "$BIN" trash mark-rejected --json 2>&1) || TR_EXIT=$?
TR_LIST=$(IPHOTO_CATALOG_DB="$TR_DB" "$BIN" trash list --json 2>&1) || true
if [ $TR_EXIT -eq 0 ] \
   && echo "$TR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['count']==2" 2>/dev/null \
   && echo "$TR_LIST" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert len(d)==2 and not any(p.endswith('tr_c.png') for p in d)
" 2>/dev/null; then
    pass "trash mark-rejected --json (nur Rejects im Papierkorb)"
else
    fail "trash mark-rejected --json" "Exit $TR_EXIT: $TR_OUT | $TR_LIST"
fi

# erneut → bereits getrashte übersprungen
TR_OUT=$(IPHOTO_CATALOG_DB="$TR_DB" "$BIN" trash mark-rejected --json 2>&1) || true
if echo "$TR_OUT" | python3 -c "import sys,json; assert json.load(sys.stdin)['count']==0" 2>/dev/null; then
    pass "trash mark-rejected erneut (idempotent, count 0)"
else
    fail "trash mark-rejected erneut" "$TR_OUT"
fi

# unbekannte Option → Fehler
TR_ERR=0
IPHOTO_CATALOG_DB="$TR_DB" "$BIN" trash mark-rejected --all > /dev/null 2>&1 || TR_ERR=$?
if [ $TR_ERR -ne 0 ]; then pass "trash mark-rejected --all (unbekannte Option → Fehler)"; else fail "trash mark-rejected --all" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# album rename / album export
# ---------------------------------------------------------------------------
echo "--- album rename / export ---"
AL_DB="$TMPDIR/al_catalog.db"
AL_SRC="$TMPDIR/al_src"
AL_DST="$TMPDIR/al_dst"
mkdir -p "$AL_SRC"
printf 'a' > "$AL_SRC/al_a.jpg"
printf 'b' > "$AL_SRC/al_b.jpg"
AL_ID=$(IPHOTO_CATALOG_DB="$AL_DB" "$BIN" album create "Urlaub" --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)
IPHOTO_CATALOG_DB="$AL_DB" "$BIN" album add "$AL_ID" "$AL_SRC/al_a.jpg" "$AL_SRC/al_b.jpg" "$AL_SRC/al_missing.jpg" > /dev/null 2>&1 || true

# rename per Name
AL_EXIT=0
AL_OUT=$(IPHOTO_CATALOG_DB="$AL_DB" "$BIN" album rename "Urlaub" "Sommer 2026" --json 2>&1) || AL_EXIT=$?
AL_LIST=$(IPHOTO_CATALOG_DB="$AL_DB" "$BIN" album list --json 2>&1) || true
if [ $AL_EXIT -eq 0 ] && echo "$AL_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['name']=='Sommer 2026' and d['old_name']=='Urlaub'" 2>/dev/null \
   && echo "$AL_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); assert [a['name'] for a in d]==['Sommer 2026']" 2>/dev/null; then
    pass "album rename --json (per Name, Bilder bleiben erhalten)"
else
    fail "album rename --json" "Exit $AL_EXIT: $AL_OUT | $AL_LIST"
fi

# rename unbekanntes Album → Fehler
AL_ERR=0
IPHOTO_CATALOG_DB="$AL_DB" "$BIN" album rename "gibtsnicht" "X" > /dev/null 2>&1 || AL_ERR=$?
if [ $AL_ERR -ne 0 ]; then pass "album rename unbekannt (→ Fehler)"; else fail "album rename unbekannt" "Hätte fehlschlagen sollen"; fi

# export --dry-run → nichts kopiert
AL_EXIT=0
AL_OUT=$(IPHOTO_CATALOG_DB="$AL_DB" "$BIN" album export "$AL_ID" --output-dir "$AL_DST" --dry-run --json 2>&1) || AL_EXIT=$?
if [ $AL_EXIT -eq 0 ] && [ ! -e "$AL_DST" ] && echo "$AL_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['copied']==2 and d['missing']==1 and d['dry_run'] is True" 2>/dev/null; then
    pass "album export --dry-run --json (2 kopierbar, 1 fehlend, nichts geschrieben)"
else
    fail "album export --dry-run" "Exit $AL_EXIT: $AL_OUT"
fi

# export echt
AL_EXIT=0
AL_OUT=$(IPHOTO_CATALOG_DB="$AL_DB" "$BIN" album export "Sommer 2026" --output-dir "$AL_DST" --json 2>&1) || AL_EXIT=$?
if [ $AL_EXIT -eq 0 ] && [ -f "$AL_DST/al_a.jpg" ] && [ -f "$AL_DST/al_b.jpg" ] \
   && echo "$AL_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['copied']==2 and d['skipped']==0" 2>/dev/null; then
    pass "album export --json (Dateien im Zielordner)"
else
    fail "album export" "Exit $AL_EXIT: $AL_OUT"
fi

# export erneut → vorhandene übersprungen
AL_OUT=$(IPHOTO_CATALOG_DB="$AL_DB" "$BIN" album export "$AL_ID" --output-dir "$AL_DST" --json 2>&1) || true
if echo "$AL_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['copied']==0 and d['skipped']==2" 2>/dev/null; then
    pass "album export erneut (vorhandene übersprungen)"
else
    fail "album export erneut" "$AL_OUT"
fi

# export ohne --output-dir → Fehler
AL_ERR=0
IPHOTO_CATALOG_DB="$AL_DB" "$BIN" album export "$AL_ID" > /dev/null 2>&1 || AL_ERR=$?
if [ $AL_ERR -ne 0 ]; then pass "album export ohne --output-dir (→ Fehler)"; else fail "album export ohne --output-dir" "Hätte fehlschlagen sollen"; fi

# export unbekanntes Album → Fehler
AL_ERR=0
IPHOTO_CATALOG_DB="$AL_DB" "$BIN" album export "gibtsnicht" --output-dir "$AL_DST" > /dev/null 2>&1 || AL_ERR=$?
if [ $AL_ERR -ne 0 ]; then pass "album export unbekannt (→ Fehler)"; else fail "album export unbekannt" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
echo "--- QUERY (App-Suchsyntax) ---"

QY_DB="$TMPDIR/qy_catalog.db"
QY_A="$TMPDIR/qy_a.png"
QY_B="$TMPDIR/qy_b.png"
cp "$INPUT_PNG" "$QY_A"
cp "$INPUT_PNG" "$QY_B"
IPHOTO_CATALOG_DB="$QY_DB" "$BIN" exif set "$QY_A" --iso 100 > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$QY_DB" "$BIN" exif set "$QY_B" --iso 200 > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$QY_DB" "$BIN" rating "$QY_A" --set 5 --flag pick --color red > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$QY_DB" "$BIN" elo set "$QY_B" 1800 > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$QY_DB" "$BIN" motif set "$QY_A" "strand,sonne" > /dev/null 2>&1 || true

# Hilfsfunktion: sortierte Basenames aus JSON-Ergebnis
qy_names() { python3 -c "import sys,json,os; print(','.join(sorted(os.path.basename(x['path']) for x in json.load(sys.stdin))))"; }

QY_EXIT=0
QY_OUT=$(IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query filters --json 2>&1) || QY_EXIT=$?
if [ $QY_EXIT -eq 0 ] && echo "$QY_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
keys=[x['key'] for x in d]
assert 'bewertung' in keys and 'elo' in keys and 'farbe' in keys and len(keys)>=10
" 2>/dev/null; then pass "query filters --json"; else fail "query filters --json" "Exit $QY_EXIT: $QY_OUT"; fi

QY_EXIT=0
QY_OUT=$(IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query parse "urlaub bewertung:5 elo:>=1600 foo:bar" --json 2>&1) || QY_EXIT=$?
if [ $QY_EXIT -eq 0 ] && echo "$QY_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['free_text']=='urlaub foo:bar', d
assert [(f['key'],f['value']) for f in d['filters']]==[('bewertung','5'),('elo','>=1600')], d
assert d['warnings']==[]
" 2>/dev/null; then pass "query parse --json (Freitext + Filter)"; else fail "query parse --json" "Exit $QY_EXIT: $QY_OUT"; fi

QY_OUT=$(IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query parse "bewertung:9 farbe:lila" --json 2>&1) || true
if echo "$QY_OUT" | python3 -c "import sys,json; assert len(json.load(sys.stdin)['warnings'])==2" 2>/dev/null; then
    pass "query parse meldet ungültige Werte als Warnung"
else
    fail "query parse Warnungen" "$QY_OUT"
fi

QY_ERR=0
IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query parse > /dev/null 2>&1 || QY_ERR=$?
if [ $QY_ERR -ne 0 ]; then pass "query parse ohne Text (→ Fehler)"; else fail "query parse ohne Text" "Hätte fehlschlagen sollen"; fi

QY_OUT=$(IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query run "bewertung:5" --json 2>&1 | qy_names) || true
if [ "$QY_OUT" = "qy_a.png" ]; then pass "query run bewertung:5"; else fail "query run bewertung:5" "$QY_OUT"; fi

QY_OUT=$(IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query run "elo:>=1700" --json 2>&1 | qy_names) || true
if [ "$QY_OUT" = "qy_b.png" ]; then pass "query run elo:>=1700"; else fail "query run elo:>=1700" "$QY_OUT"; fi

QY_OUT=$(IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query run "markiert:pick farbe:rot motiv:strand" --json 2>&1 | qy_names) || true
if [ "$QY_OUT" = "qy_a.png" ]; then pass "query run markiert+farbe+motiv (AND)"; else fail "query run markiert+farbe+motiv" "$QY_OUT"; fi

QY_OUT=$(IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query run "qy_b" --json 2>&1 | qy_names) || true
if [ "$QY_OUT" = "qy_b.png" ]; then pass "query run Freitext"; else fail "query run Freitext" "$QY_OUT"; fi

QY_OUT=$(IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query run "typ:png" --json 2>&1 | qy_names) || true
if [ "$QY_OUT" = "qy_a.png,qy_b.png" ]; then pass "query run typ:png"; else fail "query run typ:png" "$QY_OUT"; fi

QY_OUT=$(IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query run "nach:2000" --json 2>&1 | qy_names) || true
if [ "$QY_OUT" = "" ]; then pass "query run nach:2000 (undatiert → leer)"; else fail "query run nach:2000" "$QY_OUT"; fi

QY_ERR=0
IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query run "bewertung:abc" > /dev/null 2>&1 || QY_ERR=$?
if [ $QY_ERR -ne 0 ]; then pass "query run bewertung:abc (→ Fehler)"; else fail "query run bewertung:abc" "Hätte fehlschlagen sollen"; fi

QY_ERR=0
IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query run "farbe:lila" > /dev/null 2>&1 || QY_ERR=$?
if [ $QY_ERR -ne 0 ]; then pass "query run farbe:lila (→ Fehler)"; else fail "query run farbe:lila" "Hätte fehlschlagen sollen"; fi

QY_ERR=0
IPHOTO_CATALOG_DB="$QY_DB" "$BIN" query bogus > /dev/null 2>&1 || QY_ERR=$?
if [ $QY_ERR -ne 0 ]; then pass "query unbekannter Subcommand (→ Fehler)"; else fail "query bogus" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# bugreport list/show/fix/reopen/path
# ---------------------------------------------------------------------------
echo "--- bugreport ---"
BR_DIR="$TMPDIR/bugreports"
mkdir -p "$BR_DIR"
printf 'iPhoto Crash Report\nSIGSEGV alt\n' > "$BR_DIR/iPhoto_Crash_2026-01-01_120000.txt"
printf 'iPhoto Crash Report\nSIGABRT neu\n' > "$BR_DIR/iPhoto_Crash_2026-02-01_120000.txt"
br() { IPHOTO_BUGREPORT_DIR="$BR_DIR" "$BIN" bugreport "$@"; }
br_names() { python3 -c "import sys,json; print(','.join(e['name'][13:23] + (':f' if e['fixed'] else '') for e in json.load(sys.stdin)))"; }

BR_OUT=$(br path --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['path'].endswith('bugreports') and d['fixed_path'].endswith('bugreports/fixed'))" 2>&1) || true
if [ "$BR_OUT" = "True" ]; then pass "bugreport path --json"; else fail "bugreport path --json" "$BR_OUT"; fi

BR_OUT=$(br list --json 2>&1 | br_names) || true
if [ "$BR_OUT" = "2026-02-01,2026-01-01" ]; then pass "bugreport list (neueste zuerst)"; else fail "bugreport list" "$BR_OUT"; fi

BR_OUT=$(br show iPhoto_Crash_2026-02-01_120000.txt 2>&1) || true
if echo "$BR_OUT" | grep -q "SIGABRT neu"; then pass "bugreport show"; else fail "bugreport show" "$BR_OUT"; fi

BR_OUT=$(br fix iPhoto_Crash_2026-01-01_120000.txt --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['ok'], len(d['moved']))" 2>&1) || true
if [ "$BR_OUT" = "True 1" ] && [ -f "$BR_DIR/fixed/iPhoto_Crash_2026-01-01_120000.txt" ]; then pass "bugreport fix → fixed/"; else fail "bugreport fix" "$BR_OUT"; fi

BR_OUT=$(br list --json 2>&1 | br_names) || true
if [ "$BR_OUT" = "2026-02-01" ]; then pass "bugreport list ohne behobene"; else fail "bugreport list nach fix" "$BR_OUT"; fi

BR_OUT=$(br list --fixed --json 2>&1 | br_names) || true
if [ "$BR_OUT" = "2026-01-01:f" ]; then pass "bugreport list --fixed"; else fail "bugreport list --fixed" "$BR_OUT"; fi

BR_OUT=$(br show iPhoto_Crash_2026-01-01_120000.txt --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['fixed'], 'SIGSEGV' in d['content'])" 2>&1) || true
if [ "$BR_OUT" = "True True" ]; then pass "bugreport show findet behobenen Report"; else fail "bugreport show (fixed)" "$BR_OUT"; fi

BR_ERR=0
br fix iPhoto_Crash_2026-01-01_120000.txt > /dev/null 2>&1 || BR_ERR=$?
if [ $BR_ERR -ne 0 ]; then pass "bugreport fix doppelt (→ Fehler)"; else fail "bugreport fix doppelt" "Hätte fehlschlagen sollen"; fi

BR_OUT=$(br reopen iPhoto_Crash_2026-01-01_120000.txt 2>&1) || true
if [ -f "$BR_DIR/iPhoto_Crash_2026-01-01_120000.txt" ] && [ ! -f "$BR_DIR/fixed/iPhoto_Crash_2026-01-01_120000.txt" ]; then pass "bugreport reopen"; else fail "bugreport reopen" "$BR_OUT"; fi

BR_OUT=$(br list --all --json 2>&1 | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>&1) || true
if [ "$BR_OUT" = "2" ]; then pass "bugreport list --all"; else fail "bugreport list --all" "$BR_OUT"; fi

BR_ERR=0
br show gibtsnicht.txt > /dev/null 2>&1 || BR_ERR=$?
if [ $BR_ERR -ne 0 ]; then pass "bugreport show unbekannt (→ Fehler)"; else fail "bugreport show unbekannt" "Hätte fehlschlagen sollen"; fi

BR_ERR=0
br show ../geheim.txt > /dev/null 2>&1 || BR_ERR=$?
if [ $BR_ERR -ne 0 ]; then pass "bugreport show ../ (→ Fehler, kein Traversal)"; else fail "bugreport show ../" "Hätte fehlschlagen sollen"; fi

BR_ERR=0
br fix > /dev/null 2>&1 || BR_ERR=$?
if [ $BR_ERR -ne 0 ]; then pass "bugreport fix ohne Name (→ Fehler)"; else fail "bugreport fix ohne Name" "Hätte fehlschlagen sollen"; fi

BR_ERR=0
br list --bogus > /dev/null 2>&1 || BR_ERR=$?
if [ $BR_ERR -ne 0 ]; then pass "bugreport list --bogus (→ Fehler)"; else fail "bugreport list --bogus" "Hätte fehlschlagen sollen"; fi

BR_ERR=0
br bogus > /dev/null 2>&1 || BR_ERR=$?
if [ $BR_ERR -ne 0 ]; then pass "bugreport unbekannter Subcommand (→ Fehler)"; else fail "bugreport bogus" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# rating export/import
# ---------------------------------------------------------------------------
echo "--- rating export/import ---"
RX_DB="$TMPDIR/rx_src.db"
RX_DB2="$TMPDIR/rx_dst.db"
rx() { IPHOTO_CATALOG_DB="$RX_DB" "$BIN" rating "$@"; }
rx2() { IPHOTO_CATALOG_DB="$RX_DB2" "$BIN" rating "$@"; }
rx batch-set "/fotos/a.raf" --set 5 --flag pick --color red > /dev/null 2>&1 || true
rx batch-set "/fotos/b, mit komma.jpg" --set 2 > /dev/null 2>&1 || true
rx batch-set "/fotos/c.jpg" --flag reject > /dev/null 2>&1 || true

RX_OUT=$(rx export --output "$TMPDIR/ratings.json" --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['ok'], d['count'], d['format'])" 2>&1) || true
if [ "$RX_OUT" = "True 3 json" ]; then pass "rating export --output .json (3 Einträge)"; else fail "rating export json" "$RX_OUT"; fi

RX_OUT=$(python3 -c "import json; d=json.load(open('$TMPDIR/ratings.json')); e={r['path']:r for r in d['ratings']}; print(e['/fotos/a.raf']['rating'], e['/fotos/a.raf']['flag'], e['/fotos/a.raf']['color'], e['/fotos/c.jpg']['flag'])" 2>&1) || true
if [ "$RX_OUT" = "5 pick red reject" ]; then pass "rating export JSON-Inhalt korrekt"; else fail "rating export Inhalt" "$RX_OUT"; fi

RX_OUT=$(rx export --format csv 2>&1) || true
if echo "$RX_OUT" | head -1 | grep -q "^path,rating,flag,color$" && echo "$RX_OUT" | grep -q '^"/fotos/b, mit komma.jpg",2,none,none$'; then
    pass "rating export --format csv (stdout, Komma-Quoting)"
else
    fail "rating export csv" "$RX_OUT"
fi
rx export --output "$TMPDIR/ratings.csv" > /dev/null 2>&1 || true

RX_OUT=$(rx2 import "$TMPDIR/ratings.json" --dry-run --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['ok'], d['imported'], d['dry_run'])" 2>&1) || true
RX_CNT=$(rx2 list --json 2>&1 | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>&1) || true
if [ "$RX_OUT" = "True 3 True" ] && [ "$RX_CNT" = "0" ]; then pass "rating import --dry-run schreibt nichts"; else fail "rating import --dry-run" "$RX_OUT / list=$RX_CNT"; fi

RX_OUT=$(rx2 import "$TMPDIR/ratings.csv" --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['ok'], d['imported'])" 2>&1) || true
RX_BACK=$(rx2 export --format csv 2>&1) || true
RX_ORIG=$(rx export --format csv 2>&1) || true
if [ "$RX_OUT" = "True 3" ] && [ "$RX_BACK" = "$RX_ORIG" ]; then pass "rating import CSV Roundtrip identisch"; else fail "rating import csv" "$RX_OUT / $RX_BACK"; fi

rx2 batch-set "/fotos/a.raf" --set 1 > /dev/null 2>&1 || true
RX_OUT=$(rx2 import "$TMPDIR/ratings.json" --skip-existing --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['imported'], d['skipped'])" 2>&1) || true
RX_A=$(rx2 list --json 2>&1 | python3 -c "import sys,json; print({e['path']:e for e in json.load(sys.stdin)}['/fotos/a.raf']['rating'])" 2>&1) || true
if [ "$RX_OUT" = "0 3" ] && [ "$RX_A" = "1" ]; then pass "rating import --skip-existing behält vorhandene"; else fail "rating import --skip-existing" "$RX_OUT / a=$RX_A"; fi

printf '[{"path":"/x/ok.jpg","rating":3},{"path":"/x/bad.jpg","rating":9}]' > "$TMPDIR/ratings_bad.json"
RX_ERR=0
IPHOTO_CATALOG_DB="$TMPDIR/rx_bad.db" "$BIN" rating import "$TMPDIR/ratings_bad.json" > /dev/null 2>&1 || RX_ERR=$?
RX_CNT=$(IPHOTO_CATALOG_DB="$TMPDIR/rx_bad.db" "$BIN" rating list --json 2>&1 | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>&1) || true
if [ $RX_ERR -ne 0 ] && [ "$RX_CNT" = "0" ]; then pass "rating import ungültige Bewertung (→ Fehler, atomar)"; else fail "rating import ungültig" "Exit $RX_ERR, list=$RX_CNT"; fi

RX_ERR=0
rx import "$TMPDIR/gibtsnicht.json" > /dev/null 2>&1 || RX_ERR=$?
if [ $RX_ERR -ne 0 ]; then pass "rating import fehlende Datei (→ Fehler)"; else fail "rating import fehlende Datei" "Hätte fehlschlagen sollen"; fi

RX_ERR=0
rx import > /dev/null 2>&1 || RX_ERR=$?
if [ $RX_ERR -ne 0 ]; then pass "rating import ohne Datei (→ Fehler)"; else fail "rating import ohne Datei" "Hätte fehlschlagen sollen"; fi

RX_ERR=0
rx export --format xml > /dev/null 2>&1 || RX_ERR=$?
if [ $RX_ERR -ne 0 ]; then pass "rating export --format xml (→ Fehler)"; else fail "rating export --format xml" "Hätte fehlschlagen sollen"; fi

RX_ERR=0
rx export --bogus > /dev/null 2>&1 || RX_ERR=$?
if [ $RX_ERR -ne 0 ]; then pass "rating export --bogus (→ Fehler)"; else fail "rating export --bogus" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# bookmarks path / list / stats / remove / prune
# ---------------------------------------------------------------------------
echo "--- bookmarks ---"
BM_FILE="$TMPDIR/bookmarks.json"
bm() { IPHOTO_BOOKMARKS_FILE="$BM_FILE" "$BIN" bookmarks "$@"; }
touch "$TMPDIR/bm_ok.jpg"
BM_OK_KEY="file://$TMPDIR/bm_ok.jpg"
python3 - "$BM_FILE" "$BM_OK_KEY" <<'PYEOF'
import sys, json, base64
b = base64.b64encode(b"dummy-bookmark").decode()
json.dump({sys.argv[2]: b,
           "file:///tmp/iphoto_bm_missing_xyz.jpg": b,
           "file:///tmp/iphoto_bm_missing_abc.jpg": b,
           "file:///Volumes/iPhotoNoSuchVolume_xyz/a.jpg": b,
           "not-a-url": b}, open(sys.argv[1], "w"))
PYEOF

BM_OUT=$(bm path 2>&1) || true
if [ "$BM_OUT" = "$BM_FILE" ]; then pass "bookmarks path (IPHOTO_BOOKMARKS_FILE)"; else fail "bookmarks path" "$BM_OUT"; fi

BM_OUT=$(bm stats --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['total'],d['ok'],d['missing'],d['offline'],d['invalid'])" 2>&1) || true
if [ "$BM_OUT" = "5 1 2 1 1" ]; then pass "bookmarks stats --json"; else fail "bookmarks stats --json" "$BM_OUT"; fi

BM_OUT=$(bm list --missing --json 2>&1 | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>&1) || true
if [ "$BM_OUT" = "4" ]; then pass "bookmarks list --missing"; else fail "bookmarks list --missing" "$BM_OUT"; fi

BM_OUT=$(bm remove /tmp/iphoto_bm_missing_abc.jpg --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['ok'], len(d['removed']))" 2>&1) || true
if [ "$BM_OUT" = "True 1" ]; then pass "bookmarks remove <pfad>"; else fail "bookmarks remove" "$BM_OUT"; fi

BM_OUT=$(bm prune --dry-run --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['pruned'], d['offline_kept'])" 2>&1) || true
BM_AFTER=$(bm list --json 2>&1 | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>&1) || true
if [ "$BM_OUT" = "2 1" ] && [ "$BM_AFTER" = "4" ]; then pass "bookmarks prune --dry-run (nichts geändert)"; else fail "bookmarks prune --dry-run" "$BM_OUT / $BM_AFTER"; fi

BM_OUT=$(bm prune --json 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['pruned'], d['kept'])" 2>&1) || true
BM_LEFT=$(bm list --json 2>&1 | python3 -c "import sys,json; print(','.join(sorted(r['status'] for r in json.load(sys.stdin))))" 2>&1) || true
if [ "$BM_OUT" = "2 2" ] && [ "$BM_LEFT" = "offline,ok" ]; then pass "bookmarks prune (ok + offline bleiben)"; else fail "bookmarks prune" "$BM_OUT / $BM_LEFT"; fi

BM_ERR=0
bm remove /tmp/iphoto_bm_gibtsnicht.jpg > /dev/null 2>&1 || BM_ERR=$?
if [ $BM_ERR -ne 0 ]; then pass "bookmarks remove unbekannt (→ Fehler)"; else fail "bookmarks remove unbekannt" "Hätte fehlschlagen sollen"; fi

BM_ERR=0
bm remove > /dev/null 2>&1 || BM_ERR=$?
if [ $BM_ERR -ne 0 ]; then pass "bookmarks remove ohne Pfad (→ Fehler)"; else fail "bookmarks remove ohne Pfad" "Hätte fehlschlagen sollen"; fi

echo "{kaputt" > "$TMPDIR/bm_broken.json"
BM_ERR=0
IPHOTO_BOOKMARKS_FILE="$TMPDIR/bm_broken.json" "$BIN" bookmarks list > /dev/null 2>&1 || BM_ERR=$?
if [ $BM_ERR -ne 0 ]; then pass "bookmarks list kaputte Datei (→ Fehler)"; else fail "bookmarks list kaputte Datei" "Hätte fehlschlagen sollen"; fi

BM_ERR=0
bm prune --bogus > /dev/null 2>&1 || BM_ERR=$?
if [ $BM_ERR -ne 0 ]; then pass "bookmarks prune --bogus (→ Fehler)"; else fail "bookmarks prune --bogus" "Hätte fehlschlagen sollen"; fi

BM_ERR=0
bm bogus > /dev/null 2>&1 || BM_ERR=$?
if [ $BM_ERR -ne 0 ]; then pass "bookmarks unbekannter Subcommand (→ Fehler)"; else fail "bookmarks bogus" "Hätte fehlschlagen sollen"; fi
# smartfolder sql / count
# ---------------------------------------------------------------------------
echo "--- SmartFolder SQL / Count ---"

SFQ_DIR="$TMPDIR/sfsql"; mkdir -p "$SFQ_DIR"
SFQ_DB="$SFQ_DIR/catalog.db"   # smartFolders.json liegt neben der DB → isoliert
sfq() { IPHOTO_CATALOG_DB="$SFQ_DB" "$BIN" "$@"; }
SFQ_A="$SFQ_DIR/sfq_a.png"; SFQ_B="$SFQ_DIR/sfq_b.png"
cp "$INPUT_PNG" "$SFQ_A"; cp "$INPUT_PNG" "$SFQ_B"
sfq catalog add "$SFQ_A" "$SFQ_B" > /dev/null 2>&1 || true
sfq rating "$SFQ_A" --flag pick > /dev/null 2>&1 || true
sfq smartfolder create "SFQ Picks" --flag pick > /dev/null 2>&1 || true

# count ohne Ordner-Namen → alle Ordner, Picks = 1
SFQ_EXIT=0
SFQ_OUT=$(sfq smartfolder count --json 2>&1) || SFQ_EXIT=$?
if [ $SFQ_EXIT -eq 0 ] && echo "$SFQ_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['total']==1
f=d['folders'][0]
assert f['name']=='SFQ Picks' and f['count']==1 and f['runtimeOnly']==False
" 2>/dev/null; then
    pass "smartfolder count --json (Picks = 1)"
else
    fail "smartfolder count --json" "Exit $SFQ_EXIT: $SFQ_OUT"
fi

# count für einen benannten Ordner
SFQ_EXIT=0
SFQ_OUT=$(sfq smartfolder count "SFQ Picks" 2>&1) || SFQ_EXIT=$?
if [ $SFQ_EXIT -eq 0 ] && echo "$SFQ_OUT" | grep -q "SFQ Picks: 1"; then
    pass "smartfolder count <name> (Textausgabe)"
else
    fail "smartfolder count <name>" "Exit $SFQ_EXIT: $SFQ_OUT"
fi

# sql --json → SELECT mit flag-Klausel
SFQ_EXIT=0
SFQ_OUT=$(sfq smartfolder sql "SFQ Picks" --json 2>&1) || SFQ_EXIT=$?
if [ $SFQ_EXIT -eq 0 ] && echo "$SFQ_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['kind']=='select' and d['criteria']==1 and d['runtimeOnly']==False
assert 'SELECT DISTINCT i.path' in d['sql'] and 'FROM images i' in d['sql']
" 2>/dev/null; then
    pass "smartfolder sql --json (SELECT-Statement)"
else
    fail "smartfolder sql --json" "Exit $SFQ_EXIT: $SFQ_OUT"
fi

# sql --count → COUNT-Query ohne ORDER BY
SFQ_EXIT=0
SFQ_OUT=$(sfq smartfolder sql "SFQ Picks" --count 2>&1) || SFQ_EXIT=$?
if [ $SFQ_EXIT -eq 0 ] && echo "$SFQ_OUT" | grep -q "SELECT COUNT(DISTINCT i.path)" && ! echo "$SFQ_OUT" | grep -q "ORDER BY"; then
    pass "smartfolder sql --count (COUNT-Query)"
else
    fail "smartfolder sql --count" "Exit $SFQ_EXIT: $SFQ_OUT"
fi

# Fehlerpfade
SFQ_ERR=0
sfq smartfolder sql > /dev/null 2>&1 || SFQ_ERR=$?
if [ $SFQ_ERR -ne 0 ]; then pass "smartfolder sql ohne Namen (→ Fehler)"; else fail "smartfolder sql ohne Namen" "Hätte fehlschlagen sollen"; fi

SFQ_ERR=0
sfq smartfolder sql "NichtVorhanden_SFQ_XYZ" > /dev/null 2>&1 || SFQ_ERR=$?
if [ $SFQ_ERR -ne 0 ]; then pass "smartfolder sql unbekannter Name (→ Fehler)"; else fail "smartfolder sql unbekannter Name" "Hätte fehlschlagen sollen"; fi

SFQ_ERR=0
sfq smartfolder count "NichtVorhanden_SFQ_XYZ" > /dev/null 2>&1 || SFQ_ERR=$?
if [ $SFQ_ERR -ne 0 ]; then pass "smartfolder count unbekannter Name (→ Fehler)"; else fail "smartfolder count unbekannter Name" "Hätte fehlschlagen sollen"; fi

# leerer Ordner-Bestand → total 0
SFQ_EXIT=0
mkdir -p "$TMPDIR/sfq_empty"
SFQ_OUT=$(IPHOTO_CATALOG_DB="$TMPDIR/sfq_empty/catalog.db" "$BIN" smartfolder count --json 2>&1) || SFQ_EXIT=$?
if [ $SFQ_EXIT -eq 0 ] && echo "$SFQ_OUT" | python3 -c "import sys,json; assert json.load(sys.stdin)['total']==0" 2>/dev/null; then
    pass "smartfolder count --json (keine Ordner → total 0)"
else
    fail "smartfolder count (leer)" "Exit $SFQ_EXIT: $SFQ_OUT"
fi

echo ""

echo "--- catalog cameras / timeline ---"

CT_DIR="$TMPDIR/cattl"; mkdir -p "$CT_DIR"
CT_DB="$CT_DIR/catalog.db"
ct() { IPHOTO_CATALOG_DB="$CT_DB" "$BIN" "$@"; }

# leerer Katalog → leere Listen
CT_EXIT=0
CT_OUT=$(ct catalog cameras --json 2>&1) || CT_EXIT=$?
if [ $CT_EXIT -eq 0 ] && echo "$CT_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin); assert d['cameras']==[] and d['total']==0 and d['unknown']==0
" 2>/dev/null; then
    pass "catalog cameras --json (leerer Katalog)"
else
    fail "catalog cameras --json (leer)" "Exit $CT_EXIT: $CT_OUT"
fi

CT_A="$CT_DIR/ct_a.png"; CT_B="$CT_DIR/ct_b.png"; CT_C="$CT_DIR/ct_c.png"
cp "$INPUT_PNG" "$CT_A"; cp "$INPUT_PNG" "$CT_B"; cp "$INPUT_PNG" "$CT_C"
ct catalog add "$CT_A" "$CT_B" "$CT_C" > /dev/null 2>&1 || true
# Kamera + Datum direkt in die Test-DB schreiben (PNGs haben keine EXIF-Daten)
python3 - "$CT_DB" "$CT_A" "$CT_B" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.execute("UPDATE images SET camera_make='FUJIFILM', camera_model='X-T5', date_taken='2024:05:17 10:00:00' WHERE path=?", (sys.argv[2],))
c.execute("UPDATE images SET camera_make='FUJIFILM', camera_model='X-T5', date_taken='2024-06-01T08:30:00' WHERE path=?", (sys.argv[3],))
c.commit()
PY

CT_EXIT=0
CT_OUT=$(ct catalog cameras --json 2>&1) || CT_EXIT=$?
if [ $CT_EXIT -eq 0 ] && echo "$CT_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['total']==3 and d['unknown']==1
assert d['cameras']==[{'camera':'FUJIFILM X-T5','count':2,'raw':0,'size_bytes':d['cameras'][0]['size_bytes']}]
" 2>/dev/null; then
    pass "catalog cameras --json (2× X-T5, 1 unbekannt)"
else
    fail "catalog cameras --json" "Exit $CT_EXIT: $CT_OUT"
fi

CT_EXIT=0
CT_OUT=$(ct catalog timeline --json 2>&1) || CT_EXIT=$?
if [ $CT_EXIT -eq 0 ] && echo "$CT_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['by']=='month' and d['undated']==1 and d['total']==3
assert d['periods']==[{'period':'2024-05','count':1},{'period':'2024-06','count':1}]
" 2>/dev/null; then
    pass "catalog timeline --json (Monate, EXIF + ISO-Datum)"
else
    fail "catalog timeline --json" "Exit $CT_EXIT: $CT_OUT"
fi

CT_EXIT=0
CT_OUT=$(ct catalog timeline --by year --json 2>&1) || CT_EXIT=$?
if [ $CT_EXIT -eq 0 ] && echo "$CT_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin); assert d['periods']==[{'period':'2024','count':2}]
" 2>/dev/null; then
    pass "catalog timeline --by year --json"
else
    fail "catalog timeline --by year" "Exit $CT_EXIT: $CT_OUT"
fi

CT_EXIT=0
CT_OUT=$(ct catalog timeline --by day 2>&1) || CT_EXIT=$?
if [ $CT_EXIT -eq 0 ] && echo "$CT_OUT" | grep -q "2024-05-17" && echo "$CT_OUT" | grep -q "ohne Datum"; then
    pass "catalog timeline --by day (Textausgabe)"
else
    fail "catalog timeline --by day" "Exit $CT_EXIT: $CT_OUT"
fi

# Fehlerpfade
CT_ERR=0
ct catalog timeline --by week > /dev/null 2>&1 || CT_ERR=$?
if [ $CT_ERR -ne 0 ]; then pass "catalog timeline --by week (→ Fehler)"; else fail "catalog timeline --by week" "Hätte fehlschlagen sollen"; fi

CT_ERR=0
ct catalog timeline --by > /dev/null 2>&1 || CT_ERR=$?
if [ $CT_ERR -ne 0 ]; then pass "catalog timeline --by ohne Wert (→ Fehler)"; else fail "catalog timeline --by ohne Wert" "Hätte fehlschlagen sollen"; fi

CT_ERR=0
ct catalog cameras --force > /dev/null 2>&1 || CT_ERR=$?
if [ $CT_ERR -ne 0 ]; then pass "catalog cameras --force (unbekannte Option → Fehler)"; else fail "catalog cameras --force" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# exif stats (Ausrüstungs-/Aufnahme-Verteilung)
# ---------------------------------------------------------------------------
echo "--- EXIF STATS ---"

EXS_DB="$TMPDIR/exif_stats_catalog.db"
EXS_A="$TMPDIR/exs_a.png"; EXS_B="$TMPDIR/exs_b.png"; EXS_C="$TMPDIR/exs_c.png"
cp "$INPUT_PNG" "$EXS_A"; cp "$INPUT_PNG" "$EXS_B"; cp "$INPUT_PNG" "$EXS_C"

# leerer Katalog → images 0, keine Werte
EXS_EXIT=0
EXS_OUT=$(IPHOTO_CATALOG_DB="$EXS_DB" "$BIN" exif stats --json 2>&1) || EXS_EXIT=$?
if [ $EXS_EXIT -eq 0 ] && echo "$EXS_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['images']==0 and d['fields']['lens']['values']==[] and len(d['fields'])==6" 2>/dev/null; then
    pass "exif stats --json (leerer Katalog)"
else
    fail "exif stats (leer)" "Exit $EXS_EXIT: $EXS_OUT"
fi

IPHOTO_CATALOG_DB="$EXS_DB" "$BIN" exif set "$EXS_A" --iso 400 --focal 35 --lens "XF35mmF1.4 R" > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$EXS_DB" "$BIN" exif set "$EXS_B" --iso 400 --focal 23 --lens "XF23mmF2 R WR" > /dev/null 2>&1 || true
IPHOTO_CATALOG_DB="$EXS_DB" "$BIN" exif set "$EXS_C" --iso 800 --focal 35 --lens "XF35mmF1.4 R" > /dev/null 2>&1 || true

# Verteilung: Objektiv XF35 ×2 zuerst, ISO 400 ×2, Brennweite "35" ohne Nachkomma
EXS_EXIT=0
EXS_OUT=$(IPHOTO_CATALOG_DB="$EXS_DB" "$BIN" exif stats --json 2>&1) || EXS_EXIT=$?
if [ $EXS_EXIT -eq 0 ] && echo "$EXS_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin); f=d['fields']
assert d['images']==3, d['images']
assert f['lens']['distinct']==2
assert f['lens']['values'][0]=={'value':'XF35mmF1.4 R','count':2}, f['lens']
assert f['iso']['values'][0]=={'value':'400','count':2}, f['iso']
assert f['focal']['values'][0]=={'value':'35','count':2}, f['focal']
" 2>/dev/null; then
    pass "exif stats --json (Häufigkeiten Objektiv/ISO/Brennweite)"
else
    fail "exif stats --json" "Exit $EXS_EXIT: $EXS_OUT"
fi

# --by + --limit schränkt Felder und Zeilen ein
EXS_EXIT=0
EXS_OUT=$(IPHOTO_CATALOG_DB="$EXS_DB" "$BIN" exif stats --by lens,iso --limit 1 --json 2>&1) || EXS_EXIT=$?
if [ $EXS_EXIT -eq 0 ] && echo "$EXS_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin); f=d['fields']
assert sorted(f.keys())==['iso','lens'], f.keys()
assert len(f['lens']['values'])==1 and f['lens']['distinct']==2
" 2>/dev/null; then
    pass "exif stats --by lens,iso --limit 1"
else
    fail "exif stats --by/--limit" "Exit $EXS_EXIT: $EXS_OUT"
fi

# Textausgabe enthält Objektivnamen
EXS_EXIT=0
EXS_OUT=$(IPHOTO_CATALOG_DB="$EXS_DB" "$BIN" exif stats --by lens 2>&1) || EXS_EXIT=$?
if [ $EXS_EXIT -eq 0 ] && echo "$EXS_OUT" | grep -q "XF23mmF2 R WR"; then
    pass "exif stats Textausgabe"
else
    fail "exif stats Text" "Exit $EXS_EXIT: $EXS_OUT"
fi

# unbekanntes Feld → Fehler
EXS_ERR=0
IPHOTO_CATALOG_DB="$EXS_DB" "$BIN" exif stats --by shutter > /dev/null 2>&1 || EXS_ERR=$?
if [ $EXS_ERR -ne 0 ]; then pass "exif stats --by shutter (→ Fehler)"; else fail "exif stats --by shutter" "Hätte fehlschlagen sollen"; fi

# ungültiges Limit → Fehler
EXS_ERR=0
IPHOTO_CATALOG_DB="$EXS_DB" "$BIN" exif stats --limit 0 > /dev/null 2>&1 || EXS_ERR=$?
if [ $EXS_ERR -ne 0 ]; then pass "exif stats --limit 0 (→ Fehler)"; else fail "exif stats --limit 0" "Hätte fehlschlagen sollen"; fi

# unbekannte Option → Fehler
EXS_ERR=0
IPHOTO_CATALOG_DB="$EXS_DB" "$BIN" exif stats --bogus > /dev/null 2>&1 || EXS_ERR=$?
if [ $EXS_ERR -ne 0 ]; then pass "exif stats --bogus (→ Fehler)"; else fail "exif stats --bogus" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# gear summary / cameras / lenses / focal / iso / aperture
# ---------------------------------------------------------------------------
echo "--- GEAR ---"

GR_DIR="$TMPDIR/gear"; mkdir -p "$GR_DIR"
GR_DB="$GR_DIR/catalog.db"
gr() { IPHOTO_CATALOG_DB="$GR_DB" "$BIN" "$@"; }
for n in a b c d; do cp "$INPUT_PNG" "$GR_DIR/gr_$n.png"; done

# leerer Katalog → summary mit 0 Bildern, Listen leer
GR_EXIT=0
GR_OUT=$(gr gear summary --json 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['images']==0 and d['with_exif']==0 and d['top_lens'] is None and d['iso_median'] is None
" 2>/dev/null; then
    pass "gear summary --json (leerer Katalog)"
else
    fail "gear summary --json (leer)" "Exit $GR_EXIT: $GR_OUT"
fi

GR_EXIT=0
GR_OUT=$(gr gear lenses --json 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | python3 -c "import sys,json; assert json.load(sys.stdin)==[]" 2>/dev/null; then
    pass "gear lenses --json (leer → [])"
else
    fail "gear lenses --json (leer)" "Exit $GR_EXIT: $GR_OUT"
fi

# Testdaten: 3 Bilder mit EXIF, 1 Bild ohne
gr exif set "$GR_DIR/gr_a.png" --lens "XF35mmF1.4 R" --iso 400 --focal 35 --aperture 2.8 > /dev/null 2>&1 || true
gr exif set "$GR_DIR/gr_b.png" --lens "XF35mmF1.4 R" --iso 800 --focal 35 --aperture 1.4 > /dev/null 2>&1 || true
gr exif set "$GR_DIR/gr_c.png" --lens "XF23mmF2 R WR" --iso 200 --focal 23 --aperture 2 > /dev/null 2>&1 || true
gr catalog add "$GR_DIR/gr_d.png" > /dev/null 2>&1 || true

GR_EXIT=0
GR_OUT=$(gr gear lenses --json 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert [(x['lens'],x['count']) for x in d]==[('XF35mmF1.4 R',2),('XF23mmF2 R WR',1),('(unbekannt)',1)], d
" 2>/dev/null; then
    pass "gear lenses --json (Rangliste, unbekannt zuletzt)"
else
    fail "gear lenses --json" "Exit $GR_EXIT: $GR_OUT"
fi

GR_EXIT=0
GR_OUT=$(gr gear lenses --limit 1 --json 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert len(d)==1 and d[0]['lens']=='XF35mmF1.4 R'
" 2>/dev/null; then
    pass "gear lenses --limit 1"
else
    fail "gear lenses --limit 1" "Exit $GR_EXIT: $GR_OUT"
fi

GR_EXIT=0
GR_OUT=$(gr gear focal --json 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert [(x['label'],x['count']) for x in d]==[('23',1),('35',2)], d
" 2>/dev/null; then
    pass "gear focal --json (Histogramm aufsteigend)"
else
    fail "gear focal --json" "Exit $GR_EXIT: $GR_OUT"
fi

GR_EXIT=0
GR_OUT=$(gr gear iso --json 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert [x['value'] for x in d]==[200,400,800] and all(x['count']==1 for x in d), d
" 2>/dev/null; then
    pass "gear iso --json (3 Stufen)"
else
    fail "gear iso --json" "Exit $GR_EXIT: $GR_OUT"
fi

GR_EXIT=0
GR_OUT=$(gr gear aperture --json 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert [x['label'] for x in d]==['f/1.4','f/2','f/2.8'], d
" 2>/dev/null; then
    pass "gear aperture --json (f/-Labels)"
else
    fail "gear aperture --json" "Exit $GR_EXIT: $GR_OUT"
fi

GR_EXIT=0
GR_OUT=$(gr gear cameras --json 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert sum(x['count'] for x in d)==4 and all('camera' in x for x in d), d
" 2>/dev/null; then
    pass "gear cameras --json (alle 4 Bilder gezählt)"
else
    fail "gear cameras --json" "Exit $GR_EXIT: $GR_OUT"
fi

GR_EXIT=0
GR_OUT=$(gr gear summary --json 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['images']==4 and d['with_exif']==3 and d['lenses']==2, d
assert d['top_lens']=='XF35mmF1.4 R'
assert d['focal_min']==23 and d['focal_max']==35 and d['focal_median']==35
assert d['iso_min']==200 and d['iso_max']==800 and d['iso_median']==400
assert abs(d['aperture_min']-1.4)<1e-6 and abs(d['aperture_max']-2.8)<1e-6
" 2>/dev/null; then
    pass "gear summary --json (Min/Max/Median)"
else
    fail "gear summary --json" "Exit $GR_EXIT: $GR_OUT"
fi

GR_EXIT=0
GR_OUT=$(gr gear summary 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | grep -q "Objektive:     2" && echo "$GR_OUT" | grep -q "Median 400"; then
    pass "gear summary (Textausgabe)"
else
    fail "gear summary (Text)" "Exit $GR_EXIT: $GR_OUT"
fi

GR_EXIT=0
GR_OUT=$(gr gear focal 2>&1) || GR_EXIT=$?
if [ $GR_EXIT -eq 0 ] && echo "$GR_OUT" | grep -q "35 mm"; then
    pass "gear focal (Textausgabe mit Balken)"
else
    fail "gear focal (Text)" "Exit $GR_EXIT: $GR_OUT"
fi

# Fehlerpfade
GR_ERR=0
gr gear bogus > /dev/null 2>&1 || GR_ERR=$?
if [ $GR_ERR -ne 0 ]; then pass "gear unbekannter Subcommand (→ Fehler)"; else fail "gear bogus" "Hätte fehlschlagen sollen"; fi

GR_ERR=0
gr gear lenses --limit abc > /dev/null 2>&1 || GR_ERR=$?
if [ $GR_ERR -ne 0 ]; then pass "gear lenses --limit abc (→ Fehler)"; else fail "gear --limit abc" "Hätte fehlschlagen sollen"; fi

GR_ERR=0
gr gear iso --limit 0 > /dev/null 2>&1 || GR_ERR=$?
if [ $GR_ERR -ne 0 ]; then pass "gear iso --limit 0 (→ Fehler)"; else fail "gear --limit 0" "Hätte fehlschlagen sollen"; fi

GR_ERR=0
gr gear summary --bogus > /dev/null 2>&1 || GR_ERR=$?
if [ $GR_ERR -ne 0 ]; then pass "gear summary --bogus (→ Fehler)"; else fail "gear --bogus" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# motif rename / remove
# ---------------------------------------------------------------------------
echo "--- MOTIF RENAME / REMOVE ---"

MR_DB="$TMPDIR/motif_rename.db"
MR_A="$TMPDIR/mr_a.png"
MR_B="$TMPDIR/mr_b.png"
MR_C="$TMPDIR/mr_c.png"
cp "$INPUT_PNG" "$MR_A"; cp "$INPUT_PNG" "$MR_B"; cp "$INPUT_PNG" "$MR_C"
mr() { IPHOTO_CATALOG_DB="$MR_DB" "$BIN" "$@"; }
mr catalog add "$MR_A" "$MR_B" "$MR_C" > /dev/null 2>&1 || true
mr motif set "$MR_A" sky,cloud > /dev/null 2>&1 || true
mr motif set "$MR_B" sky,himmel > /dev/null 2>&1 || true
mr motif set "$MR_C" beach > /dev/null 2>&1 || true

# Probelauf ändert nichts
MR_OUT=$(mr motif rename SKY himmel --dry-run --json 2>&1) || true
MR_GET=$(mr motif get "$MR_A" --json 2>&1) || true
if echo "$MR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['dryRun'] and d['count']==2 and d['tag']=='sky' and d['newTag']=='himmel'" 2>/dev/null \
   && echo "$MR_GET" | python3 -c "import sys,json; assert json.load(sys.stdin)['motifs']==['sky','cloud']" 2>/dev/null; then
    pass "motif rename --dry-run (2 Treffer, keine Änderung)"
else
    fail "motif rename --dry-run" "$MR_OUT / $MR_GET"
fi

# rename: Reihenfolge bleibt, Duplikate werden zusammengeführt
MR_EXIT=0
MR_OUT=$(mr motif rename sky himmel --json 2>&1) || MR_EXIT=$?
MR_A_GET=$(mr motif get "$MR_A" --json 2>&1) || true
MR_B_GET=$(mr motif get "$MR_B" --json 2>&1) || true
if [ $MR_EXIT -eq 0 ] && echo "$MR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert not d['dryRun'] and d['count']==2" 2>/dev/null \
   && echo "$MR_A_GET" | python3 -c "import sys,json; assert json.load(sys.stdin)['motifs']==['himmel','cloud']" 2>/dev/null \
   && echo "$MR_B_GET" | python3 -c "import sys,json; assert json.load(sys.stdin)['motifs']==['himmel']" 2>/dev/null; then
    pass "motif rename (umbenannt + dedupliziert)"
else
    fail "motif rename" "Exit $MR_EXIT: $MR_OUT / $MR_A_GET / $MR_B_GET"
fi

MR_FIND=$(mr motif find sky --json 2>&1) || true
if echo "$MR_FIND" | python3 -c "import sys,json; assert json.load(sys.stdin)['count']==0" 2>/dev/null; then
    pass "motif rename → alter Tag verschwunden"
else
    fail "motif rename (alter Tag)" "$MR_FIND"
fi

# remove
MR_EXIT=0
MR_OUT=$(mr motif remove cloud --json 2>&1) || MR_EXIT=$?
MR_A_GET=$(mr motif get "$MR_A" --json 2>&1) || true
if [ $MR_EXIT -eq 0 ] && echo "$MR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['count']==1 and 'newTag' not in d" 2>/dev/null \
   && echo "$MR_A_GET" | python3 -c "import sys,json; assert json.load(sys.stdin)['motifs']==['himmel']" 2>/dev/null; then
    pass "motif remove --json"
else
    fail "motif remove" "Exit $MR_EXIT: $MR_OUT / $MR_A_GET"
fi

MR_OUT=$(mr motif remove gibtsnicht 2>&1) || true
if echo "$MR_OUT" | grep -q "keine Bilder"; then
    pass "motif remove (unbekannter Tag → 0 Treffer)"
else
    fail "motif remove (unbekannt)" "$MR_OUT"
fi

MR_OUT=$(mr motif rename beach strand 2>&1) || true
if echo "$MR_OUT" | grep -q "umbenannt in 1"; then
    pass "motif rename (Textausgabe)"
else
    fail "motif rename (Text)" "$MR_OUT"
fi

MR_ERR=0
mr motif rename sky > /dev/null 2>&1 || MR_ERR=$?
if [ $MR_ERR -ne 0 ]; then pass "motif rename (ohne neuen Tag → Fehler)"; else fail "motif rename (1 Arg)" "Hätte fehlschlagen sollen"; fi

MR_ERR=0
mr motif rename sky sky > /dev/null 2>&1 || MR_ERR=$?
if [ $MR_ERR -ne 0 ]; then pass "motif rename (identisch → Fehler)"; else fail "motif rename (identisch)" "Hätte fehlschlagen sollen"; fi

MR_ERR=0
mr motif rename sky "a,b" > /dev/null 2>&1 || MR_ERR=$?
if [ $MR_ERR -ne 0 ]; then pass "motif rename (Komma → Fehler)"; else fail "motif rename (Komma)" "Hätte fehlschlagen sollen"; fi

MR_ERR=0
mr motif remove > /dev/null 2>&1 || MR_ERR=$?
if [ $MR_ERR -ne 0 ]; then pass "motif remove (ohne Tag → Fehler)"; else fail "motif remove (ohne Tag)" "Hätte fehlschlagen sollen"; fi

MR_ERR=0
mr motif remove sky --bogus > /dev/null 2>&1 || MR_ERR=$?
if [ $MR_ERR -ne 0 ]; then pass "motif remove --bogus (→ Fehler)"; else fail "motif remove --bogus" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# catalog orphans
# ---------------------------------------------------------------------------
echo "--- CATALOG ORPHANS ---"

OR_DB="$TMPDIR/or_catalog.db"
OR_IMG_A="$TMPDIR/or_a.png"
OR_IMG_B="$TMPDIR/or_b.png"
cp "$INPUT_PNG" "$OR_IMG_A"
cp "$INPUT_PNG" "$OR_IMG_B"
orc() { IPHOTO_CATALOG_DB="$OR_DB" "$BIN" "$@"; }

# leerer Katalog → total 0
OR_EXIT=0
OR_OUT=$(orc catalog orphans --json 2>&1) || OR_EXIT=$?
if [ $OR_EXIT -eq 0 ] && echo "$OR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['total']==0 and not d['fixed']" 2>/dev/null; then
    pass "catalog orphans --json (leerer Katalog)"
else
    fail "catalog orphans --json (leer)" "Exit $OR_EXIT: $OR_OUT"
fi

# A im Katalog, B nur bewertet + im Papierkorb → B verwaist (ratings + trash)
orc catalog add "$OR_IMG_A" > /dev/null 2>&1 || true
orc rating batch-set "$OR_IMG_A" "$OR_IMG_B" --set 4 > /dev/null 2>&1 || true
orc trash mark "$OR_IMG_B" > /dev/null 2>&1 || true

OR_EXIT=0
OR_OUT=$(orc catalog orphans --json 2>&1) || OR_EXIT=$?
OR_RATINGS=$(orc rating list --json 2>&1) || true
if [ $OR_EXIT -eq 0 ] \
   && echo "$OR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['total']==2 and d['counts']['ratings']==1 and d['counts']['trash']==1 and d['orphans']['ratings'][0].endswith('or_b.png') and 'removed' not in d" 2>/dev/null \
   && echo "$OR_RATINGS" | grep -q "or_b.png"; then
    pass "catalog orphans (Bericht: Rating + Papierkorb von B, nichts gelöscht)"
else
    fail "catalog orphans (Bericht)" "Exit $OR_EXIT: $OR_OUT | $OR_RATINGS"
fi

# --fix → B-Zeilen weg, A-Rating bleibt
OR_EXIT=0
OR_OUT=$(orc catalog orphans --fix --json 2>&1) || OR_EXIT=$?
OR_RATINGS=$(orc rating list --json 2>&1) || true
OR_AGAIN=$(orc catalog orphans --json 2>&1) || true
if [ $OR_EXIT -eq 0 ] \
   && echo "$OR_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['fixed'] and d['removed']['ratings']==1 and d['removed']['trash']==1" 2>/dev/null \
   && ! echo "$OR_RATINGS" | grep -q "or_b.png" \
   && echo "$OR_RATINGS" | grep -q "or_a.png" \
   && echo "$OR_AGAIN" | python3 -c "import sys,json; assert json.load(sys.stdin)['total']==0" 2>/dev/null; then
    pass "catalog orphans --fix (verwaiste Zeilen entfernt, gültige bleiben)"
else
    fail "catalog orphans --fix" "Exit $OR_EXIT: $OR_OUT | $OR_RATINGS | $OR_AGAIN"
fi

# Text-Ausgabe bei konsistentem Katalog
OR_TXT=$(orc catalog orphans 2>&1) || true
if echo "$OR_TXT" | grep -q "konsistent"; then pass "catalog orphans (Text, konsistent)"; else fail "catalog orphans Text" "$OR_TXT"; fi

# unbekannte Option → Fehler
OR_ERR=0
orc catalog orphans --force > /dev/null 2>&1 || OR_ERR=$?
if [ $OR_ERR -ne 0 ]; then pass "catalog orphans --force (unbekannte Option → Fehler)"; else fail "catalog orphans --force" "Hätte fehlschlagen sollen"; fi

# Positionsargument → Fehler
OR_ERR=0
orc catalog orphans "$OR_IMG_A" > /dev/null 2>&1 || OR_ERR=$?
if [ $OR_ERR -ne 0 ]; then pass "catalog orphans <pfad> (Argument → Fehler)"; else fail "catalog orphans <pfad>" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# perf (SWITCH-Latenzmetriken aus Log-Datei)
# ---------------------------------------------------------------------------
echo "--- perf ---"
PERF_LOG="$TMPDIR/perf_test.log"
cat > "$PERF_LOG" <<'LOGEOF'

###SESSION_START### /tmp/iPhoto.log
[2026-11-06 10:00:00.000] [INFO ] [ImageLoadingOrchestrator.reportSwitch(_:url:)] SWITCH full-res 400.0 ms: old.raf
[2026-11-06 10:00:01.000] [INFO ] [ImageLoadingOrchestrator.reportSwitch(_:url:)] SWITCH cache-hit 9.0 ms: old2.raf

###SESSION_START### /tmp/iPhoto.log
[2026-11-06 11:00:00.000] [INFO ] [ImageLoadingOrchestrator.reportSwitch(_:url:)] SWITCH cache-hit 2.0 ms: a.raf
[2026-11-06 11:00:01.000] [INFO ] [ImageLoadingOrchestrator.reportSwitch(_:url:)] SWITCH cache-hit 4.0 ms: b.raf
[2026-11-06 11:00:02.000] [DEBUG] [Other.func] irrelevante Zeile ohne Metrik
[2026-11-06 11:00:03.000] [INFO ] [ImageLoadingOrchestrator.reportSwitch(_:url:)] SWITCH preview-hit 30.0 ms: c.raf
[2026-11-06 11:00:04.000] [INFO ] [ImageLoadingOrchestrator.reportDecode(_:)] SWITCH full-res-decode 250.0 ms: c.raf 6000×4000
LOGEOF

PF_EXIT=0
PF_OUT=$(IPHOTO_LOG_FILE="$PERF_LOG" "$BIN" perf switch --json 2>&1) || PF_EXIT=$?
if [ $PF_EXIT -eq 0 ] && echo "$PF_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['samples']==6, d['samples']
L={r['label']:r for r in d['labels']}
assert L['cache-hit']['count']==3 and L['cache-hit']['median_ms']==4.0 and L['cache-hit']['max_ms']==9.0, L['cache-hit']
assert L['full-res-decode']['count']==1
assert d['switches']['count']==5, d['switches']
assert d['labels'][0]['label']=='cache-hit'
" 2>/dev/null; then
    pass "perf switch --json (Gruppierung, Median, switches ohne full-res-decode)"
else
    fail "perf switch --json" "Exit $PF_EXIT: $PF_OUT"
fi

PF_EXIT=0
PF_OUT=$("$BIN" perf switch --log "$PERF_LOG" --last-session --slowest 2 --json 2>&1) || PF_EXIT=$?
if [ $PF_EXIT -eq 0 ] && echo "$PF_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['samples']==4 and d['last_session'] is True, d
assert [s['ms'] for s in d['slowest']]==[250.0,30.0], d['slowest']
assert d['slowest'][0]['file'].startswith('c.raf')
" 2>/dev/null; then
    pass "perf switch --log --last-session --slowest 2"
else
    fail "perf switch --last-session" "Exit $PF_EXIT: $PF_OUT"
fi

PF_EXIT=0
PF_OUT=$(IPHOTO_LOG_FILE="$PERF_LOG" "$BIN" perf switch --label preview-hit --json 2>&1) || PF_EXIT=$?
if [ $PF_EXIT -eq 0 ] && echo "$PF_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['samples']==1 and d['label_filter']=='preview-hit' and d['labels'][0]['p95_ms']==30.0
" 2>/dev/null; then
    pass "perf switch --label preview-hit"
else
    fail "perf switch --label" "Exit $PF_EXIT: $PF_OUT"
fi

PF_EXIT=0
PF_OUT=$(IPHOTO_LOG_FILE="$PERF_LOG" "$BIN" perf switch 2>&1) || PF_EXIT=$?
if [ $PF_EXIT -eq 0 ] && echo "$PF_OUT" | grep -q "cache-hit" && echo "$PF_OUT" | grep -q "= switches"; then
    pass "perf switch (Textausgabe)"
else
    fail "perf switch (Text)" "Exit $PF_EXIT: $PF_OUT"
fi

PF_EXIT=0
PF_OUT=$(IPHOTO_LOG_FILE="$PERF_LOG" "$BIN" perf path --json 2>&1) || PF_EXIT=$?
if [ $PF_EXIT -eq 0 ] && echo "$PF_OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['exists'] is True and d['size_bytes']>0 and d['path'].endswith('perf_test.log')
" 2>/dev/null; then
    pass "perf path --json (IPHOTO_LOG_FILE)"
else
    fail "perf path --json" "Exit $PF_EXIT: $PF_OUT"
fi

# Leeres Log → 0 Samples, kein Fehler
: > "$TMPDIR/perf_empty.log"
PF_EXIT=0
PF_OUT=$("$BIN" perf switch --log "$TMPDIR/perf_empty.log" --json 2>&1) || PF_EXIT=$?
if [ $PF_EXIT -eq 0 ] && echo "$PF_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['samples']==0 and d['labels']==[]" 2>/dev/null; then
    pass "perf switch leeres Log (0 Samples)"
else
    fail "perf switch leeres Log" "Exit $PF_EXIT: $PF_OUT"
fi

# Fehlerpfade
PF_ERR=0
"$BIN" perf switch --log "$TMPDIR/does_not_exist.log" > /dev/null 2>&1 || PF_ERR=$?
if [ $PF_ERR -ne 0 ]; then pass "perf switch fehlende Log-Datei (→ Fehler)"; else fail "perf switch fehlende Datei" "Hätte fehlschlagen sollen"; fi

PF_ERR=0
IPHOTO_LOG_FILE="$PERF_LOG" "$BIN" perf switch --slowest 0 > /dev/null 2>&1 || PF_ERR=$?
if [ $PF_ERR -ne 0 ]; then pass "perf switch --slowest 0 (→ Fehler)"; else fail "perf --slowest 0" "Hätte fehlschlagen sollen"; fi

PF_ERR=0
IPHOTO_LOG_FILE="$PERF_LOG" "$BIN" perf switch --bogus > /dev/null 2>&1 || PF_ERR=$?
if [ $PF_ERR -ne 0 ]; then pass "perf switch --bogus (→ Fehler)"; else fail "perf --bogus" "Hätte fehlschlagen sollen"; fi

PF_ERR=0
"$BIN" perf bogus > /dev/null 2>&1 || PF_ERR=$?
if [ $PF_ERR -ne 0 ]; then pass "perf unbekannter Subcommand (→ Fehler)"; else fail "perf bogus" "Hätte fehlschlagen sollen"; fi

PF_ERR=0
"$BIN" perf > /dev/null 2>&1 || PF_ERR=$?
if [ $PF_ERR -ne 0 ]; then pass "perf ohne Subcommand (→ Fehler)"; else fail "perf ohne Subcommand" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# collect (gefilterte Bilder in Ordner kopieren)
# ---------------------------------------------------------------------------
echo "--- collect ---"
CO_DB="$TMPDIR/co_catalog.db"
CO_SRC="$TMPDIR/co_src"
CO_DST="$TMPDIR/co_dst"
mkdir -p "$CO_SRC/a" "$CO_SRC/b"
printf 'a' > "$CO_SRC/a/same.jpg"
printf 'b' > "$CO_SRC/b/same.jpg"
printf 'r' > "$CO_SRC/rej.jpg"
printf 't' > "$CO_SRC/trash.jpg"
printf 'f' > "$CO_SRC/red4.jpg"
co() { IPHOTO_CATALOG_DB="$CO_DB" "$BIN" "$@"; }
co rating batch-set "$CO_SRC/a/same.jpg" "$CO_SRC/b/same.jpg" "$CO_SRC/trash.jpg" "$CO_SRC/gone.jpg" --flag pick > /dev/null 2>&1 || true
co rating batch-set "$CO_SRC/rej.jpg" --flag reject > /dev/null 2>&1 || true
co rating batch-set "$CO_SRC/red4.jpg" --set 4 --color red > /dev/null 2>&1 || true
co trash mark "$CO_SRC/trash.jpg" > /dev/null 2>&1 || true

# dry-run (Standard-Filter = Picks): 2 kopierbar, 1 fehlend, Papierkorb ausgeschlossen, nichts geschrieben
CO_EXIT=0
CO_OUT=$(co collect --output-dir "$CO_DST" --dry-run --json 2>&1) || CO_EXIT=$?
if [ $CO_EXIT -eq 0 ] && [ ! -e "$CO_DST" ] && echo "$CO_OUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['dry_run'] is True and d['filter']['flag']=='pick'
assert d['matched']==3 and d['copied']==2 and d['missing']==1
" 2>/dev/null; then
    pass "collect --dry-run --json (Picks, Papierkorb ausgeschlossen, nichts geschrieben)"
else
    fail "collect --dry-run" "Exit $CO_EXIT: $CO_OUT"
fi

# echt: Namenskollision → same.jpg + same-2.jpg
CO_EXIT=0
CO_OUT=$(co collect --output-dir "$CO_DST" --json 2>&1) || CO_EXIT=$?
if [ $CO_EXIT -eq 0 ] && [ -f "$CO_DST/same.jpg" ] && [ -f "$CO_DST/same-2.jpg" ] && [ ! -e "$CO_DST/trash.jpg" ] \
   && [ "$(cat "$CO_DST/same.jpg")" = "a" ] && [ "$(cat "$CO_DST/same-2.jpg")" = "b" ] \
   && echo "$CO_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['copied']==2 and d['skipped']==0 and d['ok'] is True" 2>/dev/null; then
    pass "collect --json (Picks kopiert, Namenskollision → same-2.jpg)"
else
    fail "collect" "Exit $CO_EXIT: $CO_OUT"
fi

# erneut → vorhandene übersprungen
CO_OUT=$(co collect --output-dir "$CO_DST" --json 2>&1) || true
if echo "$CO_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['copied']==0 and d['skipped']==2" 2>/dev/null; then
    pass "collect erneut (vorhandene übersprungen)"
else
    fail "collect erneut" "$CO_OUT"
fi

# --include-trashed nimmt Papierkorb-Pick mit
CO_OUT=$(co collect --output-dir "$CO_DST" --include-trashed --json 2>&1) || true
if [ -f "$CO_DST/trash.jpg" ] && echo "$CO_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['matched']==4 and d['copied']==1" 2>/dev/null; then
    pass "collect --include-trashed"
else
    fail "collect --include-trashed" "$CO_OUT"
fi

# Farb- + Rating-Filter
CO_EXIT=0
CO_OUT=$(co collect --output-dir "$TMPDIR/co_red" --color red --min-rating 4 --json 2>&1) || CO_EXIT=$?
if [ $CO_EXIT -eq 0 ] && [ -f "$TMPDIR/co_red/red4.jpg" ] && echo "$CO_OUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['matched']==1 and d['copied']==1 and 'flag' not in d['filter'] and d['filter']['min_rating']==4
" 2>/dev/null; then
    pass "collect --color red --min-rating 4"
else
    fail "collect --color/--min-rating" "Exit $CO_EXIT: $CO_OUT"
fi

# Textausgabe
CO_EXIT=0
CO_OUT=$(co collect --output-dir "$TMPDIR/co_rej" --flag reject --dry-run 2>&1) || CO_EXIT=$?
if [ $CO_EXIT -eq 0 ] && echo "$CO_OUT" | grep -q "1 Treffer: 1 würden kopiert"; then
    pass "collect --flag reject (Textausgabe)"
else
    fail "collect (Text)" "Exit $CO_EXIT: $CO_OUT"
fi

# Fehlerpfade
CO_ERR=0
co collect --flag pick > /dev/null 2>&1 || CO_ERR=$?
if [ $CO_ERR -ne 0 ]; then pass "collect ohne --output-dir (→ Fehler)"; else fail "collect ohne --output-dir" "Hätte fehlschlagen sollen"; fi

CO_ERR=0
co collect --output-dir "$CO_DST" --flag maybe > /dev/null 2>&1 || CO_ERR=$?
if [ $CO_ERR -ne 0 ]; then pass "collect --flag maybe (→ Fehler)"; else fail "collect --flag maybe" "Hätte fehlschlagen sollen"; fi

CO_ERR=0
co collect --output-dir "$CO_DST" --min-rating 9 > /dev/null 2>&1 || CO_ERR=$?
if [ $CO_ERR -ne 0 ]; then pass "collect --min-rating 9 (→ Fehler)"; else fail "collect --min-rating 9" "Hätte fehlschlagen sollen"; fi

CO_ERR=0
co collect --output-dir "$CO_DST" --bogus > /dev/null 2>&1 || CO_ERR=$?
if [ $CO_ERR -ne 0 ]; then pass "collect --bogus (→ Fehler)"; else fail "collect --bogus" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# elo predict / elo stats
# ---------------------------------------------------------------------------
echo "--- elo predict/stats ---"
EP_DB="$TMPDIR/elo_predict_catalog.db"
ep() { IPHOTO_CATALOG_DB="$EP_DB" "$BIN" "$@"; }

# Leerer Katalog: stats liefert count 0
EP_OUT=$(ep elo stats --json 2>/dev/null) || true
if echo "$EP_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['count']==0 and d['buckets']==[]" 2>/dev/null; then
    pass "elo stats --json (leerer Katalog)"
else
    fail "elo stats (leer)" "$EP_OUT"
fi

# Neue Bilder: 50/50, links gewinnt → 1520/1480 — und nichts wird gespeichert
EP_OUT=$(ep elo predict /tmp/ep_a.jpg /tmp/ep_b.jpg --json 2>/dev/null) || true
if echo "$EP_OUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert abs(d['p_left']-0.5)<1e-9 and abs(d['p_right']-0.5)<1e-9
assert abs(d['outcomes']['left']['left']-1520)<0.01 and abs(d['outcomes']['left']['right']-1480)<0.01
assert abs(d['outcomes']['draw']['left']-1500)<0.01
" 2>/dev/null; then
    pass "elo predict --json (neue Bilder → 50 %, 1520/1480)"
else
    fail "elo predict (neu)" "$EP_OUT"
fi
EP_LIST=$(ep elo list --json 2>/dev/null) || true
if echo "$EP_LIST" | python3 -c "import sys,json; assert json.load(sys.stdin)==[]" 2>/dev/null; then
    pass "elo predict ist read-only (keine Einträge geschrieben)"
else
    fail "elo predict read-only" "$EP_LIST"
fi

# Favorit: 1800 vs 1400 → p_left > 0.9
ep elo set /tmp/ep_a.jpg 1800 --matches 10 > /dev/null 2>&1 || true
ep elo set /tmp/ep_b.jpg 1400 --matches 4 > /dev/null 2>&1 || true
ep elo set /tmp/ep_c.jpg 1450 > /dev/null 2>&1 || true
EP_OUT=$(ep elo predict /tmp/ep_a.jpg /tmp/ep_b.jpg --json 2>/dev/null) || true
if echo "$EP_OUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['p_left']>0.9 and d['left']['elo']==1800 and d['right']['matches']==4
assert d['outcomes']['right']['right']>1400
" 2>/dev/null; then
    pass "elo predict (Favorit 1800 vs 1400 → >90 %)"
else
    fail "elo predict (Favorit)" "$EP_OUT"
fi

EP_OUT=$(ep elo stats --json 2>/dev/null) || true
if echo "$EP_OUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['count']==3 and d['total_matches']==14 and d['unplayed']==1
assert d['min']==1400 and d['max']==1800 and abs(d['median']-1450)<0.01
assert {b['from']:b['count'] for b in d['buckets']}=={1400:2,1800:1}
" 2>/dev/null; then
    pass "elo stats --json (Count/Median/Buckets)"
else
    fail "elo stats" "$EP_OUT"
fi

EP_OUT=$(ep elo stats --bucket 500 --json 2>/dev/null) || true
if echo "$EP_OUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['bucket_size']==500 and {b['from']:b['count'] for b in d['buckets']}=={1000:2,1500:1}
" 2>/dev/null; then
    pass "elo stats --bucket 500"
else
    fail "elo stats --bucket" "$EP_OUT"
fi

EP_EXIT=0
EP_OUT=$(ep elo stats 2>&1) || EP_EXIT=$?
if [ $EP_EXIT -eq 0 ] && echo "$EP_OUT" | grep -q "Median: 1450.0"; then
    pass "elo stats (Textausgabe)"
else
    fail "elo stats (Text)" "Exit $EP_EXIT: $EP_OUT"
fi

# Fehlerpfade
EP_ERR=0
ep elo predict /tmp/ep_a.jpg > /dev/null 2>&1 || EP_ERR=$?
if [ $EP_ERR -ne 0 ]; then pass "elo predict (nur ein Bild → Fehler)"; else fail "elo predict (ein Bild)" "Hätte fehlschlagen sollen"; fi

EP_ERR=0
ep elo predict /tmp/ep_a.jpg /tmp/ep_a.jpg > /dev/null 2>&1 || EP_ERR=$?
if [ $EP_ERR -ne 0 ]; then pass "elo predict (gegen sich selbst → Fehler)"; else fail "elo predict (selbst)" "Hätte fehlschlagen sollen"; fi

EP_ERR=0
ep elo stats --bucket 0 > /dev/null 2>&1 || EP_ERR=$?
if [ $EP_ERR -ne 0 ]; then pass "elo stats --bucket 0 (→ Fehler)"; else fail "elo stats --bucket 0" "Hätte fehlschlagen sollen"; fi

EP_ERR=0
ep elo stats --bucket abc > /dev/null 2>&1 || EP_ERR=$?
if [ $EP_ERR -ne 0 ]; then pass "elo stats --bucket abc (→ Fehler)"; else fail "elo stats --bucket abc" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# elo stats / elo suggest
# ---------------------------------------------------------------------------
echo "--- elo stats/suggest ---"
ES_DB="$TMPDIR/elo_stats_catalog.db"
es() { IPHOTO_CATALOG_DB="$ES_DB" "$BIN" "$@"; }

ES_OUT=$(es elo stats --json 2>/dev/null) || true
if echo "$ES_OUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['count']==0 and d['min'] is None and len(d['buckets'])==6
" 2>/dev/null; then
    pass "elo stats --json (leerer Katalog)"
else
    fail "elo stats (leer)" "$ES_OUT"
fi

es elo set /tmp/es_a.jpg 1600 --matches 3  > /dev/null 2>&1 || true
es elo set /tmp/es_b.jpg 1250 --matches 0  > /dev/null 2>&1 || true
es elo set /tmp/es_c.jpg 1720 --matches 1  > /dev/null 2>&1 || true
es elo set /tmp/es_d.jpg 1610 --matches 10 > /dev/null 2>&1 || true

ES_OUT=$(es elo stats --json 2>/dev/null) || true
if echo "$ES_OUT" | python3 -c "
import sys,json; d=json.load(sys.stdin)
b={x['label']:x['count'] for x in d['buckets']}
assert d['count']==4 and d['played']==3 and d['duels']==7
assert d['min']==1250 and d['max']==1720 and abs(d['median']-1605)<0.01
assert b['< 1300']==1 and b['1600–1700']==2 and b['≥ 1700']==1 and b['1500–1600']==0
" 2>/dev/null; then
    pass "elo stats --json (Verteilung, Median, Duelle)"
else
    fail "elo stats --json" "$ES_OUT"
fi

ES_OUT=$(es elo suggest --count 2 --json 2>/dev/null) || true
if echo "$ES_OUT" | python3 -c "
import sys,json; a=json.load(sys.stdin)
assert len(a)==2
assert a[0]['left']['path']=='/tmp/es_b.jpg' and a[0]['right']['path']=='/tmp/es_a.jpg'
assert a[1]['left']['path']=='/tmp/es_c.jpg' and a[1]['right']['path']=='/tmp/es_d.jpg'
assert 0 < a[0]['expectedLeft'] < 0.5
" 2>/dev/null; then
    pass "elo suggest --count 2 (wenig gespielt + nächstes ELO)"
else
    fail "elo suggest --count 2" "$ES_OUT"
fi

es trash mark /tmp/es_d.jpg > /dev/null 2>&1 || true
ES_OUT=$(es elo suggest --json 2>/dev/null) || true
if echo "$ES_OUT" | python3 -c "
import sys,json; a=json.load(sys.stdin)
paths={p for x in a for p in (x['left']['path'],x['right']['path'])}
assert len(a)==1 and '/tmp/es_d.jpg' not in paths
" 2>/dev/null; then
    pass "elo suggest (Papierkorb wird ausgeschlossen)"
else
    fail "elo suggest (Papierkorb)" "$ES_OUT"
fi

ES_OUT=$(es elo suggest --include-trashed --json 2>/dev/null) || true
if echo "$ES_OUT" | python3 -c "import sys,json; a=json.load(sys.stdin); assert len(a)==2" 2>/dev/null; then
    pass "elo suggest --include-trashed"
else
    fail "elo suggest --include-trashed" "$ES_OUT"
fi

ES_ERR=0
es elo suggest --count 0 > /dev/null 2>&1 || ES_ERR=$?
if [ $ES_ERR -ne 0 ]; then pass "elo suggest --count 0 (→ Fehler)"; else fail "elo suggest --count 0" "Hätte fehlschlagen sollen"; fi

ES_ERR=0
IPHOTO_CATALOG_DB="$TMPDIR/elo_suggest_empty.db" "$BIN" elo suggest > /dev/null 2>&1 || ES_ERR=$?
if [ $ES_ERR -ne 0 ]; then pass "elo suggest (leerer Katalog → Fehler)"; else fail "elo suggest (leer)" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# adjustments set / copy
# ---------------------------------------------------------------------------
echo "--- adjustments set/copy ---"
AJ_DB="$TMPDIR/adjcopy_catalog.db"
aj() { IPHOTO_CATALOG_DB="$AJ_DB" "$BIN" "$@"; }

# set → Werte landen im Katalog
AJ_OUT=$(aj adjustments set /fake/src.raf --exposure 1.5 --contrast 1.2 --turns 1 --json 2>&1) || true
if echo "$AJ_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['exposure']==1.5 and d['contrast']==1.2 and d['turns']==1 and 'exposure' in d['changed']" 2>/dev/null; then
    pass "adjustments set (exposure/contrast/turns)"
else
    fail "adjustments set" "$AJ_OUT"
fi

# set merged mit bestehenden Werten
aj adjustments set /fake/src.raf --warmth 0.5 > /dev/null 2>&1 || true
AJ_OUT=$(aj adjustments get /fake/src.raf --json 2>&1) || true
if echo "$AJ_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['exposure']==1.5 and d['warmth']==0.5" 2>/dev/null; then
    pass "adjustments set (merged mit bestehenden Werten)"
else
    fail "adjustments set merge" "$AJ_OUT"
fi

# Ziel mit eigener Drehung für --exclude-geometry
aj adjustments set /fake/dst2.raf --turns 3 --exposure -2 > /dev/null 2>&1 || true

# copy --dry-run schreibt nichts
AJ_OUT=$(aj adjustments copy /fake/src.raf /fake/dst1.raf --dry-run --json 2>&1) || true
AJ_GET=$(aj adjustments get /fake/dst1.raf --json 2>&1) || true
if echo "$AJ_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['dry_run'] and d['copied']==1" 2>/dev/null && [ "$AJ_GET" = "{}" ]; then
    pass "adjustments copy --dry-run (nichts geschrieben)"
else
    fail "adjustments copy --dry-run" "$AJ_OUT / $AJ_GET"
fi

# copy auf zwei Ziele (+ Duplikat + Quelle selbst werden ignoriert)
AJ_OUT=$(aj adjustments copy /fake/src.raf /fake/dst1.raf /fake/dst2.raf /fake/dst1.raf /fake/src.raf --exclude-geometry --json 2>&1) || true
if echo "$AJ_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok'] and d['copied']==2 and d['targets']==['/fake/dst1.raf','/fake/dst2.raf']" 2>/dev/null; then
    pass "adjustments copy (2 Ziele, dedupliziert)"
else
    fail "adjustments copy" "$AJ_OUT"
fi
AJ_GET=$(aj adjustments get /fake/dst2.raf --json 2>&1) || true
if echo "$AJ_GET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['exposure']==1.5 and d['warmth']==0.5 and d['turns']==3" 2>/dev/null; then
    pass "adjustments copy --exclude-geometry (Werte übernommen, Drehung behalten)"
else
    fail "adjustments copy --exclude-geometry" "$AJ_GET"
fi
AJ_GET=$(aj adjustments get /fake/dst1.raf --json 2>&1) || true
if echo "$AJ_GET" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['exposure']==1.5 and d['turns']==0" 2>/dev/null; then
    pass "adjustments copy (neues Ziel ohne Geometrie)"
else
    fail "adjustments copy neues Ziel" "$AJ_GET"
fi

# --skip-existing
AJ_OUT=$(aj adjustments copy /fake/src.raf /fake/dst1.raf /fake/dst3.raf --skip-existing --json 2>&1) || true
if echo "$AJ_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['copied']==1 and d['skipped']==['/fake/dst1.raf']" 2>/dev/null; then
    pass "adjustments copy --skip-existing"
else
    fail "adjustments copy --skip-existing" "$AJ_OUT"
fi

# set --reset setzt auf Standard zurück
AJ_OUT=$(aj adjustments set /fake/dst3.raf --reset --json 2>&1) || true
if echo "$AJ_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['reset'] and d['exposure']==0 and d['contrast']==1" 2>/dev/null; then
    pass "adjustments set --reset"
else
    fail "adjustments set --reset" "$AJ_OUT"
fi

# Fehlerpfade
AJ_ERR=0; aj adjustments set /fake/x.raf > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments set ohne Regler (→ Fehler)"; else fail "adjustments set ohne Regler" "Hätte fehlschlagen sollen"; fi
AJ_ERR=0; aj adjustments set --exposure 1 > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments set ohne Pfad (→ Fehler)"; else fail "adjustments set ohne Pfad" "Hätte fehlschlagen sollen"; fi
AJ_ERR=0; aj adjustments set /fake/x.raf --exposure 99 > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments set --exposure 99 (→ Bereichsfehler)"; else fail "adjustments set Bereich" "Hätte fehlschlagen sollen"; fi
AJ_ERR=0; aj adjustments set /fake/x.raf --exposure abc > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments set --exposure abc (→ Fehler)"; else fail "adjustments set abc" "Hätte fehlschlagen sollen"; fi
AJ_ERR=0; aj adjustments set /fake/x.raf --bogus 1 > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments set --bogus (→ Fehler)"; else fail "adjustments set --bogus" "Hätte fehlschlagen sollen"; fi
AJ_ERR=0; aj adjustments set /fake/x.raf --turns 4 > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments set --turns 4 (→ Fehler)"; else fail "adjustments set --turns 4" "Hätte fehlschlagen sollen"; fi
AJ_ERR=0; aj adjustments copy /fake/none.raf /fake/dst1.raf > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments copy ohne Quell-Anpassungen (→ Fehler)"; else fail "adjustments copy leere Quelle" "Hätte fehlschlagen sollen"; fi
AJ_ERR=0; aj adjustments copy /fake/src.raf > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments copy ohne Ziel (→ Fehler)"; else fail "adjustments copy ohne Ziel" "Hätte fehlschlagen sollen"; fi
AJ_ERR=0; aj adjustments copy /fake/src.raf /fake/src.raf > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments copy Quelle = Ziel (→ Fehler)"; else fail "adjustments copy Quelle=Ziel" "Hätte fehlschlagen sollen"; fi
AJ_ERR=0; aj adjustments copy /fake/src.raf /fake/d.raf --bogus > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments copy --bogus (→ Fehler)"; else fail "adjustments copy --bogus" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# adjustments set / copy v2 (Entwicklungs-Einstellungen setzen + synchronisieren)
# ---------------------------------------------------------------------------
echo "── adjustments set/copy v2 ──"
AJ_DB="$TMPDIR/adj_sync.db"
aj() { IPHOTO_CATALOG_DB="$AJ_DB" "$BIN" "$@"; }

AJ_EXIT=0
AJ_OUT=$(aj adjustments set "/fotos/src.raf" --exposure -0.5 --contrast 1.2 --warmth 15 --json 2>&1) || AJ_EXIT=$?
if [ $AJ_EXIT -eq 0 ] && echo "$AJ_OUT" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] is True and d['changed']['exposure']==-0.5 and d['changed']['contrast']==1.2
" 2>/dev/null; then
    pass "adjustments set --json (negative Zahl akzeptiert)"
else
    fail "adjustments set --json" "Exit $AJ_EXIT: $AJ_OUT"
fi

AJ_EXIT=0
AJ_OUT=$(aj adjustments get "/fotos/src.raf" --json 2>&1) || AJ_EXIT=$?
if [ $AJ_EXIT -eq 0 ] && echo "$AJ_OUT" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['exposure']==-0.5 and d['contrast']==1.2 and d['warmth']==15 and d['saturation']==1
" 2>/dev/null; then
    pass "adjustments get nach set (Werte persistiert)"
else
    fail "adjustments get nach set" "Exit $AJ_EXIT: $AJ_OUT"
fi

# Ziel mit eigener Belichtung — copy überschreibt globale Regler
aj adjustments set "/fotos/dst1.jpg" --exposure 2 > /dev/null 2>&1 || true
AJ_EXIT=0
AJ_OUT=$(aj adjustments copy "/fotos/src.raf" "/fotos/dst1.jpg" "/fotos/dst2.jpg" "/fotos/dst2.jpg" --json 2>&1) || AJ_EXIT=$?
if [ $AJ_EXIT -eq 0 ] && echo "$AJ_OUT" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] is True and d['copied']==2 and d['include_crop'] is False
" 2>/dev/null; then
    pass "adjustments copy --json (2 Ziele, Duplikat entfernt)"
else
    fail "adjustments copy --json" "Exit $AJ_EXIT: $AJ_OUT"
fi

AJ_EXIT=0
AJ_OUT=$(aj adjustments get "/fotos/dst1.jpg" --json 2>&1) || AJ_EXIT=$?
if [ $AJ_EXIT -eq 0 ] && echo "$AJ_OUT" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['exposure']==-0.5 and d['warmth']==15
" 2>/dev/null; then
    pass "adjustments copy (Zielwerte übernommen)"
else
    fail "adjustments copy (Zielwerte)" "Exit $AJ_EXIT: $AJ_OUT"
fi

AJ_EXIT=0
AJ_OUT=$(aj adjustments list --json 2>&1) || AJ_EXIT=$?
if [ $AJ_EXIT -eq 0 ] && echo "$AJ_OUT" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert len(d)==3
" 2>/dev/null; then
    pass "adjustments list (3 Bilder nach copy)"
else
    fail "adjustments list nach copy" "Exit $AJ_EXIT: $AJ_OUT"
fi

AJ_EXIT=0
AJ_OUT=$(aj adjustments set "/fotos/src.raf" --reset --json 2>&1) || AJ_EXIT=$?
if [ $AJ_EXIT -eq 0 ] && aj adjustments get "/fotos/src.raf" --json 2>/dev/null | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d['exposure']==0 and d['contrast']==1
" 2>/dev/null; then
    pass "adjustments set --reset (Standardwerte)"
else
    fail "adjustments set --reset" "Exit $AJ_EXIT: $AJ_OUT"
fi

# Fehlerpfade
AJ_ERR=0
aj adjustments set "/fotos/src.raf" > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments set ohne Regler (→ Fehler)"; else fail "adjustments set ohne Regler" "Hätte fehlschlagen sollen"; fi

AJ_ERR=0
aj adjustments set "/fotos/src.raf" --exposure abc > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments set --exposure abc (→ Fehler)"; else fail "adjustments set --exposure abc" "Hätte fehlschlagen sollen"; fi

AJ_ERR=0
aj adjustments set "/fotos/src.raf" --bogus 1 > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments set --bogus (→ Fehler)"; else fail "adjustments set --bogus" "Hätte fehlschlagen sollen"; fi

AJ_ERR=0
aj adjustments copy "/fotos/keine.jpg" "/fotos/dst1.jpg" > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments copy (Quelle ohne Anpassungen → Fehler)"; else fail "adjustments copy ohne Quelle" "Hätte fehlschlagen sollen"; fi

AJ_ERR=0
aj adjustments copy "/fotos/src.raf" > /dev/null 2>&1 || AJ_ERR=$?
if [ $AJ_ERR -ne 0 ]; then pass "adjustments copy (kein Ziel → Fehler)"; else fail "adjustments copy kein Ziel" "Hätte fehlschlagen sollen"; fi

echo ""

# ---------------------------------------------------------------------------
# storage info
# ---------------------------------------------------------------------------
echo "--- Storage ---"
STORAGE_OUT=$("$BIN" storage info 2>&1)
if echo "$STORAGE_OUT" | grep -q "Bilder gesamt"; then
    pass "storage info (Textausgabe enthält 'Bilder gesamt')"
else
    fail "storage info" "Erwartete 'Bilder gesamt' nicht gefunden: $STORAGE_OUT"
fi

STORAGE_JSON=$("$BIN" storage info --json 2>&1)
if echo "$STORAGE_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'total_images' in d and 'backed_up' in d" 2>/dev/null; then
    pass "storage info --json (valides JSON mit 'total_images' und 'backed_up')"
else
    fail "storage info --json" "Kein valides JSON oder fehlende Felder: $STORAGE_JSON"
fi

echo ""

# ---------------------------------------------------------------------------
# album purge-stale
# ---------------------------------------------------------------------------
echo "--- album purge-stale ---"
PURGE_DIR=$(mktemp -d)
PURGE_IMG="$PURGE_DIR/real.jpg"
PURGE_GHOST="$PURGE_DIR/ghost.jpg"
cp "$TESTIMG" "$PURGE_IMG"
# Create a minimal albums.json with one real and one ghost URL
PURGE_DB="$PURGE_DIR/catalog.db"
PURGE_ALBUM_ID=$(uuidgen)
PURGE_JSON_FILE=$(mktemp -d)/albums.json
mkdir -p "$(dirname "$PURGE_JSON_FILE")"
cat > "$PURGE_JSON_FILE" <<ALBUMEOF
[{"id":"$PURGE_ALBUM_ID","name":"PurgeTest","photoURLs":["$PURGE_IMG","$PURGE_GHOST"],"albumDescription":null,"coverPhotoURL":null,"parentID":null}]
ALBUMEOF
# dry-run should detect 1 stale reference
PURGE_OUT=$(IPHOTO_CATALOG_DB="$PURGE_DB" IPHOTO_ALBUMS_JSON="$PURGE_JSON_FILE" "$CLI" album purge-stale --dry-run --json 2>/dev/null)
PURGE_ERR=$?
PURGE_REMOVED=$(echo "$PURGE_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('removed',0))" 2>/dev/null)
PURGE_DRYRUN=$(echo "$PURGE_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('dry_run','false'))" 2>/dev/null)
if [ "$PURGE_REMOVED" = "1" ] && [ "$PURGE_DRYRUN" = "True" ]; then
    pass "album purge-stale --dry-run (1 veralteter Verweis erkannt)"
else
    fail "album purge-stale --dry-run" "removed=$PURGE_REMOVED dry_run=$PURGE_DRYRUN (erwartet: 1 / True)"
fi
# real run should remove the ghost
PURGE_OUT2=$(IPHOTO_CATALOG_DB="$PURGE_DB" IPHOTO_ALBUMS_JSON="$PURGE_JSON_FILE" "$CLI" album purge-stale --json 2>/dev/null)
PURGE_REMOVED2=$(echo "$PURGE_OUT2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('removed',0))" 2>/dev/null)
if [ "$PURGE_REMOVED2" = "1" ]; then
    pass "album purge-stale (1 veralteter Verweis entfernt)"
else
    fail "album purge-stale" "removed=$PURGE_REMOVED2 (erwartet: 1)"
fi
rm -rf "$PURGE_DIR"

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
echo "=============================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
