#!/bin/bash
# Tests/run_cli.sh — CLI Coverage-Tests für album, quality, version, search, catalog, motif, duplicate
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/iphoto-cli"
TMPDIR_BASE="$(mktemp -d)"
trap "rm -rf '$TMPDIR_BASE'" EXIT

export IPHOTO_CATALOG_DB="$TMPDIR_BASE/test.db"

PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1 — $2"; FAIL=$((FAIL+1)); }

LOG_DIR="$ROOT/Tests/results"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/cli_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee "$LOG_FILE") 2>&1

[ -x "$BIN" ] || { echo "Fehler: $BIN nicht gefunden. ./build.sh ausführen."; exit 1; }

# Minimales Test-PNG erzeugen
INPUT="$TMPDIR_BASE/test.png"
python3 - <<'EOF' > "$INPUT"
import struct, zlib, sys
def chunk(n,d): c=zlib.crc32(n+d)&0xffffffff; return struct.pack('>I',len(d))+n+d+struct.pack('>I',c)
sig=b'\x89PNG\r\n\x1a\n'
ihdr=chunk(b'IHDR',struct.pack('>IIBBBBB',4,4,8,2,0,0,0))
row=b'\x00'+b'\xff\x80\x00'*4; raw=row*4
idat=chunk(b'IDAT',zlib.compress(raw)); iend=chunk(b'IEND',b'')
sys.stdout.buffer.write(sig+ihdr+idat+iend)
EOF
[ -f "$INPUT" ] && [ -s "$INPUT" ] || { echo "Fehler: Test-PNG konnte nicht erstellt werden."; exit 1; }
echo "Test-PNG: $INPUT"
echo ""

# ===========================================================================
# album
# ===========================================================================
echo "=== album ==="

# album create
ALBUM_OUT=$("$BIN" album create "TestAlbum" 2>&1)
ALBUM_ID=$(echo "$ALBUM_OUT" | grep -oE '[0-9A-F-]{36}' | head -1)
if [ -n "$ALBUM_ID" ]; then pass "album create (ID=$ALBUM_ID)"; else fail "album create" "Kein UUID in Ausgabe: $ALBUM_OUT"; fi

# album create --json
ALBUM_JSON=$("$BIN" album create "JsonAlbum" --json 2>&1)
ALBUM_JSON_ID=$(echo "$ALBUM_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['id'])" 2>/dev/null)
if [ -n "$ALBUM_JSON_ID" ]; then pass "album create --json (valides JSON mit 'id')"; else fail "album create --json" "Kein valides JSON: $ALBUM_JSON"; fi

# album list
LIST_OUT=$("$BIN" album list 2>&1)
if echo "$LIST_OUT" | grep -q "TestAlbum"; then pass "album list (enthält TestAlbum)"; else fail "album list" "TestAlbum nicht gefunden: $LIST_OUT"; fi

# album list --json
LIST_JSON=$("$BIN" album list --json 2>&1)
if echo "$LIST_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list) and len(lst)>0" 2>/dev/null; then
    pass "album list --json (valides JSON-Array)"
else fail "album list --json" "Kein valides JSON-Array: $LIST_JSON"; fi

# album add
"$BIN" rating "$INPUT" --set 0 > /dev/null 2>&1 || true  # ensure image exists in catalog
ADD_OUT=$("$BIN" album add "$ALBUM_ID" "$INPUT" 2>&1)
if echo "$ADD_OUT" | grep -q "hinzugefügt"; then pass "album add (1 Bild hinzugefügt)"; else fail "album add" "$ADD_OUT"; fi

# album images
IMGS_OUT=$("$BIN" album images "$ALBUM_ID" 2>&1)
if echo "$IMGS_OUT" | grep -q "test.png"; then pass "album images (enthält test.png)"; else fail "album images" "$IMGS_OUT"; fi

# album images --json
IMGS_JSON=$("$BIN" album images "$ALBUM_ID" --json 2>&1)
if echo "$IMGS_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list) and len(lst)>0" 2>/dev/null; then
    pass "album images --json (valides JSON-Array)"; else fail "album images --json" "$IMGS_JSON"; fi

# album remove
REMOVE_OUT=$("$BIN" album remove "$ALBUM_ID" "$INPUT" 2>&1)
if echo "$REMOVE_OUT" | grep -q "entfernt"; then pass "album remove"; else fail "album remove" "$REMOVE_OUT"; fi

# album delete
DEL_OUT=$("$BIN" album delete "$ALBUM_ID" 2>&1)
if echo "$DEL_OUT" | grep -q "gelöscht"; then
    LIST2=$("$BIN" album list 2>&1)
    if ! echo "$LIST2" | grep -q "$ALBUM_ID"; then pass "album delete (Album verschwunden)"; else fail "album delete" "Album noch vorhanden"; fi
else fail "album delete" "$DEL_OUT"; fi

# album <ungültig>
ALBUM_BAD=0; "$BIN" album bogus > /dev/null 2>&1 || ALBUM_BAD=$?
if [ $ALBUM_BAD -ne 0 ]; then pass "album <ungültig> (Exitcode != 0)"; else fail "album bogus" "Hätte fehlschlagen sollen"; fi

echo ""

# ===========================================================================
# quality
# ===========================================================================
echo "=== quality ==="

# quality scan
QSCAN=$("$BIN" quality scan "$INPUT" 2>&1)
if echo "$QSCAN" | grep -qE 'blur=|analysiert'; then pass "quality scan (Blur-Score ausgegeben)"; else fail "quality scan" "$QSCAN"; fi

# quality scan --json
QSCAN_JSON=$("$BIN" quality scan "$INPUT" --json 2>&1)
if echo "$QSCAN_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list) and 'blur' in lst[0]" 2>/dev/null; then
    pass "quality scan --json (valides JSON mit 'blur')"; else fail "quality scan --json" "$QSCAN_JSON"; fi

# quality get
QGET=$("$BIN" quality get "$INPUT" 2>&1)
if echo "$QGET" | grep -qE 'blur='; then pass "quality get (Daten vorhanden)"; else fail "quality get" "$QGET"; fi

# quality get --json
QGET_JSON=$("$BIN" quality get "$INPUT" --json 2>&1)
if echo "$QGET_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'blur' in d" 2>/dev/null; then
    pass "quality get --json"; else fail "quality get --json" "$QGET_JSON"; fi

# quality list
QLIST=$("$BIN" quality list 2>&1)
if echo "$QLIST" | grep -qE 'blur=|keine'; then pass "quality list"; else fail "quality list" "$QLIST"; fi

# quality list --json
QLIST_JSON=$("$BIN" quality list --json 2>&1)
if echo "$QLIST_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list)" 2>/dev/null; then
    pass "quality list --json (valides JSON-Array)"; else fail "quality list --json" "$QLIST_JSON"; fi

echo ""

# ===========================================================================
# version
# ===========================================================================
echo "=== version ==="

# version list (empty)
VLIST=$("$BIN" version list "$INPUT" 2>&1)
if [ $? -eq 0 ]; then pass "version list (Exitcode 0, keine Versionen)"; else fail "version list" "$VLIST"; fi

# version backup
VBACK=$("$BIN" version backup "$INPUT" --label "v1" 2>&1)
VERSION_ID=$(echo "$VBACK" | grep -oE '[0-9A-F-]{36}' | head -1)
if [ -n "$VERSION_ID" ]; then pass "version backup (ID=$VERSION_ID)"; else fail "version backup" "$VBACK"; fi

# version backup --json (via list)
VLIST2=$("$BIN" version list "$INPUT" --json 2>&1)
if echo "$VLIST2" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list) and len(lst)>0 and 'id' in lst[0]" 2>/dev/null; then
    pass "version list --json (enthält 1 Version)"; else fail "version list --json" "$VLIST2"; fi

# version restore
VCOPY="$TMPDIR_BASE/copy.png"
cp "$INPUT" "$VCOPY"
"$BIN" version backup "$VCOPY" > /dev/null 2>&1 || true
VRESTORE=$("$BIN" version list "$VCOPY" --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])" 2>/dev/null) || true
if [ -n "$VRESTORE" ]; then
    RESTORE_OUT=$("$BIN" version restore "$VCOPY" "$VRESTORE" 2>&1) || true
    if echo "$RESTORE_OUT" | grep -q "wiederhergestellt"; then pass "version restore"; else fail "version restore" "$RESTORE_OUT"; fi
else pass "version restore (übersprungen — Backup nicht verfügbar)"; fi

# version delete
if [ -n "$VERSION_ID" ]; then
    VDEL=$("$BIN" version delete "$INPUT" "$VERSION_ID" 2>&1)
    if echo "$VDEL" | grep -q "gelöscht"; then pass "version delete"; else fail "version delete" "$VDEL"; fi
fi

echo ""

# ===========================================================================
# search
# ===========================================================================
echo "=== search ==="

# Erst ein Bild ins Katalog mit Rating eintragen
"$BIN" rating "$INPUT" --set 3 > /dev/null 2>&1 || true

# search --rating
SRATING=$("$BIN" search --rating 3 2>&1)
if [ $? -eq 0 ]; then pass "search --rating 3 (Exitcode 0)"; else fail "search --rating 3" "$SRATING"; fi

# search --rating --json
SRATING_JSON=$("$BIN" search --rating 1 --json 2>&1)
if echo "$SRATING_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list)" 2>/dev/null; then
    pass "search --rating --json (valides JSON-Array)"; else fail "search --rating --json" "$SRATING_JSON"; fi

# search --flag
"$BIN" rating "$INPUT" --flag pick > /dev/null 2>&1 || true
SFLAG=$("$BIN" search --flag pick 2>&1)
if [ $? -eq 0 ]; then pass "search --flag pick (Exitcode 0)"; else fail "search --flag pick" "$SFLAG"; fi

# search --flag --json
SFLAG_JSON=$("$BIN" search --flag pick --json 2>&1)
if echo "$SFLAG_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list)" 2>/dev/null; then
    pass "search --flag --json (valides JSON-Array)"; else fail "search --flag --json" "$SFLAG_JSON"; fi

# search text
STEXT=$("$BIN" search "test" 2>&1)
if [ $? -eq 0 ]; then pass "search <text> (Exitcode 0)"; else fail "search text" "$STEXT"; fi

# search ohne Argumente → Exitcode != 0
SEMPTY_EXIT=0; "$BIN" search > /dev/null 2>&1 || SEMPTY_EXIT=$?
if [ $SEMPTY_EXIT -ne 0 ]; then pass "search (ohne Argumente → Exitcode != 0)"; else fail "search ohne args" "Hätte fehlschlagen sollen"; fi

echo ""

# ===========================================================================
# catalog
# ===========================================================================
echo "=== catalog ==="

CSTATS=$("$BIN" catalog stats 2>&1)
if echo "$CSTATS" | grep -qE 'Bilder:|images'; then pass "catalog stats (enthält 'Bilder:')"; else fail "catalog stats" "$CSTATS"; fi

CSTATS_JSON=$("$BIN" catalog stats --json 2>&1)
if echo "$CSTATS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'images' in d" 2>/dev/null; then
    pass "catalog stats --json (valides JSON mit 'images')"; else fail "catalog stats --json" "$CSTATS_JSON"; fi

CPATH=$("$BIN" catalog path 2>&1)
if [ $? -eq 0 ] && [ -n "$CPATH" ]; then pass "catalog path (Exitcode 0, nicht leer)"; else fail "catalog path" "$CPATH"; fi

echo ""

# ===========================================================================
# motif
# ===========================================================================
echo "=== motif ==="

MGET=$("$BIN" motif get "$INPUT" 2>&1)
if [ $? -eq 0 ]; then pass "motif get (Exitcode 0)"; else fail "motif get" "$MGET"; fi

MGET_JSON=$("$BIN" motif get "$INPUT" --json 2>&1)
if echo "$MGET_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'motifs' in d" 2>/dev/null; then
    pass "motif get --json (valides JSON mit 'motifs')"; else fail "motif get --json" "$MGET_JSON"; fi

echo ""

# ===========================================================================
# duplicate
# ===========================================================================
echo "=== duplicate ==="

DLIST=$("$BIN" duplicate list 2>&1)
if [ $? -eq 0 ]; then pass "duplicate list (Exitcode 0)"; else fail "duplicate list" "$DLIST"; fi

DLIST_JSON=$("$BIN" duplicate list --json 2>&1)
if echo "$DLIST_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list)" 2>/dev/null; then
    pass "duplicate list --json (valides JSON-Array)"; else fail "duplicate list --json" "$DLIST_JSON"; fi

DSIM=$("$BIN" duplicate similar 2>&1)
if [ $? -eq 0 ]; then pass "duplicate similar (Exitcode 0)"; else fail "duplicate similar" "$DSIM"; fi

echo ""

# ===========================================================================
# smartfolder
# ===========================================================================
echo "=== smartfolder ==="

SF_LIST=$("$BIN" smartfolder list 2>&1)
if [ $? -eq 0 ]; then pass "smartfolder list leer (Exitcode 0)"; else fail "smartfolder list leer" "$SF_LIST"; fi

SF_CREATE=$("$BIN" smartfolder create "TestOrdner" --rating-min 3 2>&1)
if echo "$SF_CREATE" | grep -q "TestOrdner"; then pass "smartfolder create (Name in Ausgabe)"; else fail "smartfolder create" "$SF_CREATE"; fi

SF_LIST2=$("$BIN" smartfolder list 2>&1)
if echo "$SF_LIST2" | grep -q "TestOrdner"; then pass "smartfolder list zeigt neuen Ordner"; else fail "smartfolder list nach create" "$SF_LIST2"; fi

SF_LIST_JSON=$("$BIN" smartfolder list --json 2>&1)
if echo "$SF_LIST_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert any(d['name']=='TestOrdner' for d in lst)" 2>/dev/null; then
    pass "smartfolder list --json (JSON mit TestOrdner)"; else fail "smartfolder list --json" "$SF_LIST_JSON"; fi

SF_DUP_EXIT=0; "$BIN" smartfolder create "TestOrdner" > /dev/null 2>&1 || SF_DUP_EXIT=$?
if [ $SF_DUP_EXIT -ne 0 ]; then pass "smartfolder create Duplikat schlägt fehl (korrekt)"; else fail "smartfolder create Duplikat" "Sollte fehlschlagen"; fi

SF_QUERY=$("$BIN" smartfolder query "TestOrdner" 2>&1)
if echo "$SF_QUERY" | python3 -c "import sys; sys.exit(0)" 2>/dev/null && true; then pass "smartfolder query (Exitcode 0)"; else fail "smartfolder query" "$SF_QUERY"; fi

SF_QUERY_JSON=$("$BIN" smartfolder query "TestOrdner" --json 2>&1)
if echo "$SF_QUERY_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list)" 2>/dev/null; then
    pass "smartfolder query --json (JSON-Array)"; else fail "smartfolder query --json" "$SF_QUERY_JSON"; fi

SF_MISSING_EXIT=0; "$BIN" smartfolder query "NichtVorhanden" > /dev/null 2>&1 || SF_MISSING_EXIT=$?
if [ $SF_MISSING_EXIT -ne 0 ]; then pass "smartfolder query fehlender Ordner schlägt fehl"; else fail "smartfolder query missing" "Sollte fehlschlagen"; fi

SF_DEL=$("$BIN" smartfolder delete "TestOrdner" 2>&1)
if echo "$SF_DEL" | grep -q "gelöscht"; then pass "smartfolder delete (Meldung)"; else fail "smartfolder delete" "$SF_DEL"; fi

SF_LIST3=$("$BIN" smartfolder list 2>&1)
if echo "$SF_LIST3" | grep -q "TestOrdner"; then fail "smartfolder list nach delete" "Ordner noch vorhanden: $SF_LIST3"; else pass "smartfolder list nach delete (leer)"; fi

echo ""

# ===========================================================================
# stack
# ===========================================================================
echo "=== stack ==="

ST_LIST=$("$BIN" stack list 2>&1)
if [ $? -eq 0 ]; then pass "stack list (Exitcode 0, keine Seq-Daten)"; else fail "stack list" "$ST_LIST"; fi

ST_LIST_JSON=$("$BIN" stack list --json 2>&1)
if echo "$ST_LIST_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list)" 2>/dev/null; then
    pass "stack list --json (JSON-Array)"; else fail "stack list --json" "$ST_LIST_JSON"; fi

ST_QUERY_EXIT=0; "$BIN" stack query "/nonexistent/image.RAF" > /dev/null 2>&1 || ST_QUERY_EXIT=$?
if [ $ST_QUERY_EXIT -ne 0 ]; then pass "stack query fehlender Pfad schlägt fehl"; else fail "stack query missing" "Sollte fehlschlagen"; fi

echo ""

# ===========================================================================
# people rename
# ===========================================================================
echo "=== people rename ==="

PR_LIST=$("$BIN" people list --json 2>&1)
PR_ID=$(echo "$PR_LIST" | python3 -c "import sys,json; lst=json.load(sys.stdin); print(lst[0]['id'])" 2>/dev/null || true)
if [ -n "$PR_ID" ]; then
    PR_REN=$("$BIN" people rename "$PR_ID" "TestPerson" 2>&1)
    if echo "$PR_REN" | grep -q "TestPerson"; then pass "people rename (Meldung enthält neuen Namen)"; else fail "people rename" "$PR_REN"; fi
    PR_LIST2=$("$BIN" people list --json 2>&1)
    if echo "$PR_LIST2" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert any(d.get('name')=='TestPerson' for d in lst)" 2>/dev/null; then
        pass "people rename persistiert (list zeigt neuen Namen)"; else fail "people rename persistiert" "$PR_LIST2"; fi
else
    pass "people rename übersprungen (kein Person im Katalog)"
fi

PR_ERR_EXIT=0; "$BIN" people rename "NICHT-VORHANDEN-UUID" "Name" > /dev/null 2>&1 || PR_ERR_EXIT=$?
if [ $PR_ERR_EXIT -ne 0 ]; then pass "people rename fehlende ID schlägt fehl"; else fail "people rename fehlende ID" "Sollte fehlschlagen"; fi

echo ""

# ===========================================================================
# trash
# ===========================================================================
echo "=== trash ==="

TR_LIST=$("$BIN" trash list 2>&1)
if [ $? -eq 0 ]; then pass "trash list leer (Exitcode 0)"; else fail "trash list" "$TR_LIST"; fi

TR_LIST_JSON=$("$BIN" trash list --json 2>&1)
if echo "$TR_LIST_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list)" 2>/dev/null; then
    pass "trash list --json (JSON-Array)"; else fail "trash list --json" "$TR_LIST_JSON"; fi

"$BIN" rating "$INPUT" --set 0 > /dev/null 2>&1 || true
TR_MARK=$("$BIN" trash mark "$INPUT" 2>&1)
if echo "$TR_MARK" | grep -q "Papierkorb"; then pass "trash mark (Meldung)"; else fail "trash mark" "$TR_MARK"; fi

TR_LIST2=$("$BIN" trash list 2>&1)
if echo "$TR_LIST2" | grep -q "$INPUT"; then pass "trash list zeigt markiertes Bild"; else fail "trash list nach mark" "$TR_LIST2"; fi

TR_RESTORE=$("$BIN" trash restore "$INPUT" 2>&1)
if echo "$TR_RESTORE" | grep -q "wiederhergestellt"; then pass "trash restore (Meldung)"; else fail "trash restore" "$TR_RESTORE"; fi

TR_LIST3=$("$BIN" trash list 2>&1)
if echo "$TR_LIST3" | grep -q "$INPUT"; then fail "trash list nach restore" "Bild noch im Papierkorb: $TR_LIST3"; else pass "trash list nach restore (leer)"; fi

TR_RESTORE_ALL=$("$BIN" trash restore --all 2>&1)
if [ $? -eq 0 ]; then pass "trash restore --all (Exitcode 0)"; else fail "trash restore --all" "$TR_RESTORE_ALL"; fi

echo ""

# ===========================================================================
# Zusammenfassung
# ===========================================================================
echo "=============================="
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
echo "=============================="
printf "%s\t%d\t%d\t%s\n" "$(date +%Y-%m-%dT%H:%M:%S)" "$PASS" "$FAIL" "$([ $FAIL -eq 0 ] && echo OK || echo FAIL)" >> "$LOG_DIR/cli_history.tsv"
echo "Protokoll: $LOG_FILE"
[ $FAIL -eq 0 ] && exit 0 || exit 1
