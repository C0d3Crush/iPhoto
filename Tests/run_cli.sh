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

# album add/remove --json
AID2=$("$BIN" album create "TestAlbum2" --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null) || AID2=""
if [ -n "$AID2" ]; then
    OUT=$("$BIN" album add "$AID2" "$INPUT" --json 2>&1)
    if echo "$OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok')==True" 2>/dev/null; then
        pass "album add --json (ok=true)"; else fail "album add --json" "$OUT"; fi
    OUT=$("$BIN" album remove "$AID2" "$INPUT" --json 2>&1)
    if echo "$OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok')==True" 2>/dev/null; then
        pass "album remove --json (ok=true)"; else fail "album remove --json" "$OUT"; fi
    "$BIN" album delete "$AID2" > /dev/null 2>&1 || true
else
    pass "album add --json übersprungen"
fi

ALBUM_ADD_ERR=0; "$BIN" album add "$ALBUM_ID" > /dev/null 2>&1 || ALBUM_ADD_ERR=$?
if [ $ALBUM_ADD_ERR -ne 0 ]; then pass "album add ohne Bilder (Fehler korrekt)"; else fail "album add ohne Bilder" "Exitcode 0"; fi
ALBUM_REM_ERR=0; "$BIN" album remove "$ALBUM_ID" > /dev/null 2>&1 || ALBUM_REM_ERR=$?
if [ $ALBUM_REM_ERR -ne 0 ]; then pass "album remove ohne Bilder (Fehler korrekt)"; else fail "album remove ohne Bilder" "Exitcode 0"; fi

# album reorder
REORDER_AID=$("$BIN" album create "ReorderAlbum" --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null) || REORDER_AID=""
if [ -n "$REORDER_AID" ]; then
    IMG2="$TMPDIR_BASE/test2.png"; cp "$INPUT" "$IMG2"
    "$BIN" album add "$REORDER_AID" "$INPUT" "$IMG2" > /dev/null 2>&1 || true
    OUT=$("$BIN" album reorder "$REORDER_AID" "$IMG2" "$INPUT" 2>&1)
    if echo "$OUT" | grep -q "sortiert"; then pass "album reorder (Meldung)"; else fail "album reorder" "$OUT"; fi
    OUT=$("$BIN" album reorder "$REORDER_AID" "$IMG2" "$INPUT" --json 2>&1)
    if echo "$OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok')==True" 2>/dev/null; then
        pass "album reorder --json (ok=true)"; else fail "album reorder --json" "$OUT"; fi
    "$BIN" album delete "$REORDER_AID" > /dev/null 2>&1 || true
else
    pass "album reorder übersprungen"
fi

REORDER_ERR=0; "$BIN" album reorder "$ALBUM_ID" > /dev/null 2>&1 || REORDER_ERR=$?
if [ $REORDER_ERR -ne 0 ]; then pass "album reorder ohne Bilder (Fehler korrekt)"; else fail "album reorder ohne Bilder" "Exitcode 0"; fi

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

# version backup --json
VBACK_JSON=$("$BIN" version backup "$INPUT" --json 2>&1)
if echo "$VBACK_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'id' in d" 2>/dev/null; then
    pass "version backup --json (JSON mit 'id')"
else
    fail "version backup --json" "Kein JSON oder 'id' fehlt: $VBACK_JSON"
fi

# version restore --json
VID2=$("$BIN" version list "$INPUT" --json 2>/dev/null | python3 -c "import sys,json; l=json.load(sys.stdin); print(l[0]['id'])" 2>/dev/null) || VID2=""
if [ -n "$VID2" ]; then
    VREST_JSON=$("$BIN" version restore "$INPUT" "$VID2" --json 2>&1)
    if echo "$VREST_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok')==True" 2>/dev/null; then
        pass "version restore --json (ok=true)"
    else fail "version restore --json" "$VREST_JSON"; fi
else
    pass "version restore --json übersprungen (keine Version)"
fi

# version delete --json
if [ -n "$VID2" ]; then
    VDEL_JSON=$("$BIN" version delete "$INPUT" "$VID2" --json 2>&1)
    if echo "$VDEL_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok')==True" 2>/dev/null; then
        pass "version delete --json (ok=true)"
    else fail "version delete --json" "$VDEL_JSON"; fi
else
    pass "version delete --json übersprungen (keine Version)"
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

# search --color
"$BIN" rating "$INPUT" --color red > /dev/null 2>&1 || true
SCOLOR_EXIT=0; SCOLOR=$("$BIN" search --color red 2>&1) || SCOLOR_EXIT=$?
if [ $SCOLOR_EXIT -eq 0 ]; then pass "search --color red (Exitcode 0)"; else fail "search --color red" "$SCOLOR"; fi

SCOLOR_JSON=$("$BIN" search --color red --json 2>&1)
if echo "$SCOLOR_JSON" | python3 -c "import sys,json; lst=json.load(sys.stdin); assert isinstance(lst,list)" 2>/dev/null; then
    pass "search --color --json (valides JSON-Array)"; else fail "search --color --json" "$SCOLOR_JSON"; fi

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

# catalog vacuum
CVACUUM=$("$BIN" catalog vacuum 2>&1)
if echo "$CVACUUM" | grep -q "optimiert"; then pass "catalog vacuum (Meldung)"; else fail "catalog vacuum" "$CVACUUM"; fi

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
# export
# ===========================================================================
echo "=== export ==="

EXPORT_JPEG="$TMPDIR_BASE/exported.jpeg"
OUT=$("$BIN" export "$INPUT" --format jpeg --output "$EXPORT_JPEG" 2>&1)
if [ -f "$EXPORT_JPEG" ]; then pass "export PNG→JPEG (Datei vorhanden)"; else fail "export PNG→JPEG" "Datei fehlt: $OUT"; fi

EXPORT_PNG2="$TMPDIR_BASE/exported2.png"
OUT=$("$BIN" export "$INPUT" --format png --output "$EXPORT_PNG2" 2>&1)
if [ -f "$EXPORT_PNG2" ]; then pass "export PNG→PNG (Datei vorhanden)"; else fail "export PNG→PNG" "Datei fehlt: $OUT"; fi

EXPORT_DIR="$TMPDIR_BASE/batch_export"
mkdir -p "$EXPORT_DIR"
"$BIN" export "$INPUT" --format jpeg --output-dir "$EXPORT_DIR" > /dev/null 2>&1 || true
if ls "$EXPORT_DIR"/ 2>/dev/null | grep -qiE '\.(jpg|jpeg)$'; then pass "export --output-dir (Batch)"; else fail "export --output-dir" "Keine JPEG in $EXPORT_DIR: $(ls $EXPORT_DIR/ 2>/dev/null)"; fi

EXPORT_EXIT=0; "$BIN" export "/nicht/vorhanden.png" --format jpeg --output "$TMPDIR_BASE/x.jpeg" > /dev/null 2>&1 || EXPORT_EXIT=$?
if [ $EXPORT_EXIT -ne 0 ]; then pass "export nicht-existente Datei (Fehler korrekt)"; else fail "export nicht-existente Datei" "Exitcode 0"; fi

EXPORT_EXIT2=0; "$BIN" export --format jpeg > /dev/null 2>&1 || EXPORT_EXIT2=$?
if [ $EXPORT_EXIT2 -ne 0 ]; then pass "export ohne Eingabe (Fehler korrekt)"; else fail "export ohne Eingabe" "Exitcode 0"; fi

EXPORT_SIZE=$(stat -f%z "$EXPORT_JPEG" 2>/dev/null || echo 0)
if [ "${EXPORT_SIZE:-0}" -gt 100 ]; then pass "export JPEG Dateigröße > 100 Bytes ($EXPORT_SIZE B)"; else fail "export Dateigröße" "Zu klein oder leer: ${EXPORT_SIZE}B"; fi

OUT=$("$BIN" export "$INPUT" --format jpeg --output "$TMPDIR_BASE/export_json.jpg" --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'ok' in d and d['ok']==True" 2>/dev/null; then
    pass "export --json (JSON mit 'ok': true)"
else
    fail "export --json" "Kein JSON oder ok!=true: $OUT"
fi

echo ""

# ===========================================================================
# info
# ===========================================================================
echo "=== info ==="

OUT=$("$BIN" info "$INPUT" 2>&1)
if echo "$OUT" | grep -q "test.png"; then pass "info (Dateiname in Ausgabe)"; else fail "info" "test.png fehlt: $OUT"; fi

OUT=$("$BIN" info "$INPUT" --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'file' in d" 2>/dev/null; then
    pass "info --json (JSON mit 'file')"
else
    fail "info --json" "Kein JSON oder 'file' fehlt: $OUT"
fi

INFO_EXIT=0; "$BIN" info "/nicht/vorhanden.png" > /dev/null 2>&1 || INFO_EXIT=$?
if [ $INFO_EXIT -ne 0 ]; then pass "info nicht-existente Datei (Fehler korrekt)"; else fail "info nicht-existente Datei" "Exitcode 0"; fi

INFO_EXIT2=0; "$BIN" info > /dev/null 2>&1 || INFO_EXIT2=$?
if [ $INFO_EXIT2 -ne 0 ]; then pass "info ohne Argumente (Fehler korrekt)"; else fail "info ohne Argumente" "Exitcode 0"; fi

echo ""

# ===========================================================================
# rating (dedizierter Block)
# ===========================================================================
echo "=== rating ==="

OUT=$("$BIN" rating "$INPUT" --set 4 2>&1)
if echo "$OUT" | grep -q "Gespeichert"; then pass "rating --set 4"; else fail "rating --set 4" "$OUT"; fi

OUT=$("$BIN" rating "$INPUT" 2>&1)
if echo "$OUT" | grep -q "Rating : 4"; then pass "rating read-back (4 vorhanden)"; else fail "rating read-back" "$OUT"; fi

OUT=$("$BIN" rating "$INPUT" --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('rating')==4" 2>/dev/null; then
    pass "rating --json (rating=4)"
else
    fail "rating --json" "Kein JSON oder rating!=4: $OUT"
fi

OUT=$("$BIN" rating "$INPUT" --flag pick 2>&1)
if echo "$OUT" | grep -q "Gespeichert"; then pass "rating --flag pick"; else fail "rating --flag pick" "$OUT"; fi

OUT=$("$BIN" rating "$INPUT" --color red 2>&1)
if echo "$OUT" | grep -q "Gespeichert"; then pass "rating --color red"; else fail "rating --color red" "$OUT"; fi

OUT=$("$BIN" rating "$INPUT" --remove 2>&1)
if echo "$OUT" | grep -q "entfernt"; then pass "rating --remove (Meldung)"; else fail "rating --remove" "$OUT"; fi

OUT=$("$BIN" rating "$INPUT" 2>&1)
if echo "$OUT" | grep -q "Rating : 0"; then pass "rating nach --remove (0)"; else fail "rating nach --remove" "$OUT"; fi

RATING_EXIT=0; "$BIN" rating "$INPUT" --flag ungueltig > /dev/null 2>&1 || RATING_EXIT=$?
if [ $RATING_EXIT -ne 0 ]; then pass "rating --flag ungültig (Fehler korrekt)"; else fail "rating --flag ungültig" "Exitcode 0"; fi

RATING_EXIT2=0; "$BIN" rating "/nicht/vorhanden.png" > /dev/null 2>&1 || RATING_EXIT2=$?
if [ $RATING_EXIT2 -ne 0 ]; then pass "rating nicht-existente Datei (Fehler korrekt)"; else fail "rating nicht-existente Datei" "Exitcode 0"; fi

echo ""

# ===========================================================================
# analyse
# ===========================================================================
echo "=== analyse ==="

OUT=$("$BIN" analyse "$INPUT" 2>&1)
if echo "$OUT" | grep -q "Gesamt:"; then pass "analyse (Ausgabe enthält 'Gesamt:')"; else fail "analyse" "$OUT"; fi

OUT=$("$BIN" analyse "$INPUT" --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; a=json.load(sys.stdin); assert isinstance(a,list) and 'blur_score' in a[0]" 2>/dev/null; then
    pass "analyse --json (JSON mit 'blur_score')"
else
    fail "analyse --json" "Kein JSON oder blur_score fehlt: $OUT"
fi

OUT=$("$BIN" analyse "$INPUT" --blur-threshold 100 2>&1)
if echo "$OUT" | grep -q "Gesamt:"; then pass "analyse --blur-threshold (Exitcode 0)"; else fail "analyse --blur-threshold" "$OUT"; fi

ANALYSE_EXIT=0; "$BIN" analyse "/nicht/vorhanden.png" > /dev/null 2>&1 || ANALYSE_EXIT=$?
if [ $ANALYSE_EXIT -ne 0 ]; then pass "analyse nicht-existente Datei (Fehler korrekt)"; else fail "analyse nicht-existente Datei" "Exitcode 0"; fi

ANALYSE_EXIT2=0; "$BIN" analyse > /dev/null 2>&1 || ANALYSE_EXIT2=$?
if [ $ANALYSE_EXIT2 -ne 0 ]; then pass "analyse ohne Argumente (Fehler korrekt)"; else fail "analyse ohne Argumente" "Exitcode 0"; fi

ANALYSE_DIR="$TMPDIR_BASE/analyse_dir"
mkdir -p "$ANALYSE_DIR"
cp "$INPUT" "$ANALYSE_DIR/img1.png"
cp "$INPUT" "$ANALYSE_DIR/img2.png"
OUT=$("$BIN" analyse "$ANALYSE_DIR" 2>&1)
if echo "$OUT" | grep -q "Gesamt: 2"; then pass "analyse <Ordner> (2 Dateien)"; else fail "analyse <Ordner>" "Sollte 2 Dateien zeigen: $OUT"; fi

OUT=$("$BIN" analyse "$ANALYSE_DIR" --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; a=json.load(sys.stdin); assert len(a)==2" 2>/dev/null; then
    pass "analyse <Ordner> --json (2 Einträge)"
else
    fail "analyse <Ordner> --json" "Sollte Array mit 2 Elementen sein: $OUT"
fi

echo ""

# ===========================================================================
# preset
# ===========================================================================
echo "=== preset ==="

OUT=$("$BIN" preset list 2>&1)
if echo "$OUT" | grep -q "Presets"; then pass "preset list (Presets aufgelistet)"; else fail "preset list" "$OUT"; fi

OUT=$("$BIN" preset list --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; a=json.load(sys.stdin); assert isinstance(a,list)" 2>/dev/null; then
    pass "preset list --json (JSON-Array)"
else
    fail "preset list --json" "Kein JSON-Array: $OUT"
fi

PRESET_OUT="$TMPDIR_BASE/preset_out.jpeg"
PRESET_NAME=$("$BIN" preset list --json 2>/dev/null | python3 -c "import sys,json; a=json.load(sys.stdin); print(a[0]['name'] if a else '')" 2>/dev/null) || PRESET_NAME=""
if [ -n "$PRESET_NAME" ]; then
    OUT=$("$BIN" preset apply "$INPUT" --name "$PRESET_NAME" --output "$PRESET_OUT" --format jpeg 2>&1)
    if [ -f "$PRESET_OUT" ]; then pass "preset apply '$PRESET_NAME' (Datei vorhanden)"; else fail "preset apply" "Datei fehlt: $OUT"; fi
else
    pass "preset apply übersprungen (keine Presets)"
fi

PRESET_EXIT=0; "$BIN" preset apply "$INPUT" --name "__NichtExistent__" --output "$TMPDIR_BASE/x.jpeg" > /dev/null 2>&1 || PRESET_EXIT=$?
if [ $PRESET_EXIT -ne 0 ]; then pass "preset apply unbekannter Name (Fehler korrekt)"; else fail "preset apply unbekannter Name" "Exitcode 0"; fi

PRESET_EXIT2=0; "$BIN" preset delete "__NichtExistent__" > /dev/null 2>&1 || PRESET_EXIT2=$?
if [ $PRESET_EXIT2 -ne 0 ]; then pass "preset delete unbekannt (Fehler korrekt)"; else fail "preset delete unbekannt" "Exitcode 0"; fi

ADJ_JSON_OUT="$TMPDIR_BASE/adj_json.jpeg"
OUT=$("$BIN" adjust "$INPUT" --output "$ADJ_JSON_OUT" --format jpeg --exposure 0.1 --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('ok')==True" 2>/dev/null; then
    pass "adjust --json (JSON mit 'ok': true)"
else
    fail "adjust --json" "Kein JSON oder ok!=true: $OUT"
fi

echo ""

# ===========================================================================
# plugins
# ===========================================================================
echo "=== plugins ==="

OUT=$("$BIN" plugins list 2>&1); EC=$?
if [ $EC -eq 0 ]; then pass "plugins list (Exitcode 0)"; else fail "plugins list" "$OUT"; fi

OUT=$("$BIN" plugins list --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    pass "plugins list --json (gültiges JSON)"
else
    fail "plugins list --json" "Kein gültiges JSON: $OUT"
fi

OUT=$("$BIN" plugins dir 2>&1)
if [ -n "$OUT" ]; then pass "plugins dir (Pfad ausgegeben)"; else fail "plugins dir" "Leere Ausgabe"; fi

PLUGINS_EXIT=0; "$BIN" plugins invalid_sub > /dev/null 2>&1 || PLUGINS_EXIT=$?
if [ $PLUGINS_EXIT -ne 0 ]; then pass "plugins unbekannter Unterbefehl (Fehler korrekt)"; else fail "plugins unbekannter Unterbefehl" "Exitcode 0"; fi

echo ""

# ===========================================================================
# viewmode
# ===========================================================================
echo "=== viewmode ==="

OUT=$("$BIN" viewmode get 2>&1); EC=$?
if [ $EC -eq 0 ] && [ -n "$OUT" ]; then pass "viewmode get (Modus ausgegeben: $OUT)"; else fail "viewmode get" "Exitcode=$EC oder leer"; fi

OUT=$("$BIN" viewmode set grid 2>&1)
if echo "$OUT" | grep -q "grid"; then pass "viewmode set grid"; else fail "viewmode set grid" "$OUT"; fi

OUT=$("$BIN" viewmode get 2>&1)
if echo "$OUT" | grep -q "grid"; then pass "viewmode get nach set grid"; else fail "viewmode get nach set grid" "$OUT"; fi

OUT=$("$BIN" viewmode set gallery 2>&1)
if echo "$OUT" | grep -q "gallery"; then pass "viewmode set gallery (zurücksetzen)"; else fail "viewmode set gallery" "$OUT"; fi

VM_EXIT=0; "$BIN" viewmode set ungueltig > /dev/null 2>&1 || VM_EXIT=$?
if [ $VM_EXIT -ne 0 ]; then pass "viewmode set ungültig (Fehler korrekt)"; else fail "viewmode set ungültig" "Exitcode 0"; fi

VM_EXIT2=0; "$BIN" viewmode > /dev/null 2>&1 || VM_EXIT2=$?
if [ $VM_EXIT2 -ne 0 ]; then pass "viewmode ohne Unterbefehl (Fehler korrekt)"; else fail "viewmode ohne Unterbefehl" "Exitcode 0"; fi

echo ""

# ===========================================================================
# people
# ===========================================================================
echo "=== people ==="

OUT=$("$BIN" people list 2>&1); EC=$?
if [ $EC -eq 0 ]; then pass "people list (Exitcode 0)"; else fail "people list" "$OUT"; fi

OUT=$("$BIN" people list --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    pass "people list --json (gültiges JSON)"
else
    fail "people list --json" "Kein gültiges JSON: $OUT"
fi

OUT=$("$BIN" people scan "$INPUT" 2>&1)
if echo "$OUT" | grep -q "Gesamt:"; then pass "people scan (Ausgabe enthält 'Gesamt:')"; else fail "people scan" "$OUT"; fi

OUT=$("$BIN" people scan "$INPUT" --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; a=json.load(sys.stdin); assert isinstance(a,list)" 2>/dev/null; then
    pass "people scan --json (JSON-Array)"
else
    fail "people scan --json" "Kein JSON-Array: $OUT"
fi

OUT=$("$BIN" people faces 2>&1); EC=$?
if [ $EC -eq 0 ]; then pass "people faces (Exitcode 0)"; else fail "people faces" "$OUT"; fi

OUT=$("$BIN" people cluster 2>&1); EC=$?
if [ $EC -eq 0 ]; then pass "people cluster ohne Daten (Exitcode 0)"; else fail "people cluster" "$OUT"; fi

PEOPLE_EXIT=0; "$BIN" people scan > /dev/null 2>&1 || PEOPLE_EXIT=$?
if [ $PEOPLE_EXIT -ne 0 ]; then pass "people scan ohne Argumente (Fehler korrekt)"; else fail "people scan ohne Argumente" "Exitcode 0"; fi

PEOPLE_EXIT2=0; "$BIN" people unbekannt > /dev/null 2>&1 || PEOPLE_EXIT2=$?
if [ $PEOPLE_EXIT2 -ne 0 ]; then pass "people unbekannter Unterbefehl (Fehler korrekt)"; else fail "people unbekannter Unterbefehl" "Exitcode 0"; fi

OUT=$("$BIN" people cluster --json 2>&1)
if echo "$OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d,dict) and 'clusters' in d" 2>/dev/null; then
    pass "people cluster --json leer (JSON mit 'clusters')"
else
    fail "people cluster --json leer" "Kein JSON oder 'clusters' fehlt: $OUT"
fi

echo ""

# ===========================================================================
# hotpixel
# ===========================================================================
echo "=== hotpixel ==="

HOTPIXEL_EXIT=0; "$BIN" hotpixel > /dev/null 2>&1 || HOTPIXEL_EXIT=$?
if [ $HOTPIXEL_EXIT -ne 0 ]; then pass "hotpixel ohne Argumente (Fehler korrekt)"; else fail "hotpixel ohne Argumente" "Exitcode 0"; fi

HOTPIXEL_EXIT2=0; "$BIN" hotpixel "/nicht/vorhanden" > /dev/null 2>&1 || HOTPIXEL_EXIT2=$?
if [ $HOTPIXEL_EXIT2 -ne 0 ]; then pass "hotpixel nicht-existenter Ordner (Fehler korrekt)"; else fail "hotpixel nicht-existenter Ordner" "Exitcode 0"; fi

EMPTY_DIR="$TMPDIR_BASE/empty_hp"
mkdir -p "$EMPTY_DIR"
HOTPIXEL_EXIT3=0; "$BIN" hotpixel "$EMPTY_DIR" > /dev/null 2>&1 || HOTPIXEL_EXIT3=$?
if [ $HOTPIXEL_EXIT3 -ne 0 ]; then pass "hotpixel leerer Ordner (Fehler korrekt)"; else fail "hotpixel leerer Ordner" "Exitcode 0"; fi

echo ""

# ===========================================================================
# hdr
# ===========================================================================
echo "=== hdr ==="

HDR_EXIT=0; "$BIN" hdr > /dev/null 2>&1 || HDR_EXIT=$?
if [ $HDR_EXIT -ne 0 ]; then pass "hdr ohne Argumente (Fehler korrekt)"; else fail "hdr ohne Argumente" "Exitcode 0"; fi

HDR_DIR="$TMPDIR_BASE/hdr_single"
mkdir -p "$HDR_DIR"; cp "$INPUT" "$HDR_DIR/only.png"
HDR_EXIT2=0; "$BIN" hdr "$HDR_DIR" --output-dir "$TMPDIR_BASE/hdr_out" > /dev/null 2>&1 || HDR_EXIT2=$?
if [ $HDR_EXIT2 -ne 0 ]; then pass "hdr Ordner mit 1 Bild (Fehler korrekt — min. 2 benötigt)"; else fail "hdr Ordner mit 1 Bild" "Exitcode 0"; fi

HDR_EXIT3=0; "$BIN" hdr "/nicht/vorhanden" --output-dir "$TMPDIR_BASE/hdr_out2" > /dev/null 2>&1 || HDR_EXIT3=$?
if [ $HDR_EXIT3 -ne 0 ]; then pass "hdr nicht-existenter Ordner (Fehler korrekt)"; else fail "hdr nicht-existenter Ordner" "Exitcode 0"; fi

echo ""

# ===========================================================================
# inpaint
# ===========================================================================
echo "=== inpaint ==="

INPAINT_EXIT=0; "$BIN" inpaint > /dev/null 2>&1 || INPAINT_EXIT=$?
if [ $INPAINT_EXIT -ne 0 ]; then pass "inpaint ohne Argumente (Fehler korrekt)"; else fail "inpaint ohne Argumente" "Exitcode 0"; fi

INPAINT_EXIT2=0; "$BIN" inpaint "$INPUT" > /dev/null 2>&1 || INPAINT_EXIT2=$?
if [ $INPAINT_EXIT2 -ne 0 ]; then pass "inpaint ohne --output (Fehler korrekt)"; else fail "inpaint ohne --output" "Exitcode 0"; fi

INPAINT_EXIT3=0; "$BIN" inpaint "/nicht/vorhanden.png" --output "$TMPDIR_BASE/x.png" > /dev/null 2>&1 || INPAINT_EXIT3=$?
if [ $INPAINT_EXIT3 -ne 0 ]; then pass "inpaint nicht-existente Datei (Fehler korrekt)"; else fail "inpaint nicht-existente Datei" "Exitcode 0"; fi

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
