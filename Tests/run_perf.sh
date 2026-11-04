#!/bin/bash
# Tests/run_perf.sh — Leistungstests: Laden, Scan, Export, Clustering
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/iphoto-cli"
TMPDIR_BASE="$(mktemp -d)"
trap "rm -rf '$TMPDIR_BASE'" EXIT

export IPHOTO_CATALOG_DB="$TMPDIR_BASE/perf.db"

PASS=0; FAIL=0
pass() { echo "  PASS: $1 (${2}ms)"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1 — ${2}ms > Schwellwert ${3}ms"; FAIL=$((FAIL+1)); }

[ -x "$BIN" ] || { echo "Fehler: $BIN nicht gefunden. ./build.sh ausführen."; exit 1; }

# Hilfsfunktion: Zeit in Millisekunden
ms() { python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null; }

# ===========================================================================
# Test-Bilder erzeugen
# ===========================================================================
echo "==> Erzeuge Test-Bilder…"

make_png() {
    local path="$1" w="${2:-64}" h="${3:-64}"
    python3 - "$path" "$w" "$h" <<'PYEOF'
import struct, zlib, sys
path, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
def chunk(n,d): c=zlib.crc32(n+d)&0xffffffff; return struct.pack('>I',len(d))+n+d+struct.pack('>I',c)
sig=b'\x89PNG\r\n\x1a\n'
ihdr=chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))
import random; random.seed(42)
raw=b''.join(b'\x00'+bytes([random.randint(0,255) for _ in range(w*3)]) for _ in range(h))
idat=chunk(b'IDAT',zlib.compress(raw)); iend=chunk(b'IEND',b'')
open(path,'wb').write(sig+ihdr+idat+iend)
PYEOF
}

# Kleines Bild (64×64)
SMALL="$TMPDIR_BASE/small.png";   make_png "$SMALL" 64 64
# Mittelgroßes Bild (512×512)
MEDIUM="$TMPDIR_BASE/medium.png"; make_png "$MEDIUM" 512 512
# 10 Bilder für Batch-Tests
for i in $(seq 1 10); do make_png "$TMPDIR_BASE/batch_$i.png" 256 256; done
echo "Test-Bilder bereit."
echo ""

# ===========================================================================
# 1. Catalog-Stats — Leselatenz leerer Katalog
# ===========================================================================
echo "=== 1. Catalog-Stats Latenz ==="
THRESHOLD=2000
T0=$(ms)
"$BIN" catalog stats > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "catalog stats (leer)" "$ELAPSED"; else fail "catalog stats (leer)" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 2. Quality-Scan — einzelnes Bild
# ===========================================================================
echo "=== 2. Quality-Scan Latenz ==="

THRESHOLD=5000
T0=$(ms)
"$BIN" quality scan "$SMALL" > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "quality scan 64×64" "$ELAPSED"; else fail "quality scan 64×64" "$ELAPSED" "$THRESHOLD"; fi

THRESHOLD=8000
T0=$(ms)
"$BIN" quality scan "$MEDIUM" > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "quality scan 512×512" "$ELAPSED"; else fail "quality scan 512×512" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 3. Quality-Scan — 10 Bilder (Batch)
# ===========================================================================
echo "=== 3. Quality-Scan Batch (10 Bilder) ==="
THRESHOLD=20000
BATCH_PATHS=()
for i in $(seq 1 10); do BATCH_PATHS+=("$TMPDIR_BASE/batch_$i.png"); done

T0=$(ms)
"$BIN" quality scan "${BATCH_PATHS[@]}" > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "quality scan 10×256×256" "$ELAPSED"; else fail "quality scan 10×256×256" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 4. Album CRUD — Schreiblatenz
# ===========================================================================
echo "=== 4. Album CRUD Latenz ==="
THRESHOLD=1000
T0=$(ms)
AID=$("$BIN" album create "PerfAlbum" --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null) || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "album create" "$ELAPSED"; else fail "album create" "$ELAPSED" "$THRESHOLD"; fi

if [ -n "$AID" ]; then
    # Registrierung im Katalog
    "$BIN" quality scan "$SMALL" > /dev/null 2>&1 || true

    THRESHOLD=1000
    T0=$(ms)
    "$BIN" album add "$AID" "$SMALL" > /dev/null 2>&1 || true
    T1=$(ms)
    ELAPSED=$((T1-T0))
    if [ $ELAPSED -le $THRESHOLD ]; then pass "album add" "$ELAPSED"; else fail "album add" "$ELAPSED" "$THRESHOLD"; fi

    THRESHOLD=1000
    T0=$(ms)
    "$BIN" album images "$AID" > /dev/null 2>&1 || true
    T1=$(ms)
    ELAPSED=$((T1-T0))
    if [ $ELAPSED -le $THRESHOLD ]; then pass "album images list" "$ELAPSED"; else fail "album images list" "$ELAPSED" "$THRESHOLD"; fi

    "$BIN" album delete "$AID" > /dev/null 2>&1 || true
fi
echo ""

# ===========================================================================
# 5. Suche — Volltextsuche & Filter
# ===========================================================================
echo "=== 5. Suche Latenz ==="
# Erst Bilder mit Rating eintragen
for i in $(seq 1 10); do
    "$BIN" rating "$TMPDIR_BASE/batch_$i.png" --set $((i % 5 + 1)) > /dev/null 2>&1 || true
done

THRESHOLD=2000
T0=$(ms)
"$BIN" search --rating 3 > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "search --rating" "$ELAPSED"; else fail "search --rating" "$ELAPSED" "$THRESHOLD"; fi

THRESHOLD=2000
T0=$(ms)
"$BIN" search "batch" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "search text" "$ELAPSED"; else fail "search text" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 6. Version Backup & Restore
# ===========================================================================
echo "=== 6. Version Backup/Restore Latenz ==="
VCOPY="$TMPDIR_BASE/perf_ver.png"
cp "$MEDIUM" "$VCOPY"

THRESHOLD=2000
T0=$(ms)
"$BIN" version backup "$VCOPY" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "version backup (512×512)" "$ELAPSED"; else fail "version backup (512×512)" "$ELAPSED" "$THRESHOLD"; fi

VID=$("$BIN" version list "$VCOPY" --json 2>/dev/null | python3 -c "import sys,json; l=json.load(sys.stdin); print(l[0]['id'] if l else '')" 2>/dev/null) || true
if [ -n "$VID" ]; then
    THRESHOLD=1000
    T0=$(ms)
    "$BIN" version restore "$VCOPY" "$VID" > /dev/null 2>&1 || true
    T1=$(ms)
    ELAPSED=$((T1-T0))
    if [ $ELAPSED -le $THRESHOLD ]; then pass "version restore (512×512)" "$ELAPSED"; else fail "version restore (512×512)" "$ELAPSED" "$THRESHOLD"; fi
fi
echo ""

# ===========================================================================
# 7. Catalog-Stats mit Daten
# ===========================================================================
echo "=== 7. Catalog-Stats mit Daten ==="
THRESHOLD=1000
T0=$(ms)
"$BIN" catalog stats > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "catalog stats (mit Daten)" "$ELAPSED"; else fail "catalog stats (mit Daten)" "$ELAPSED" "$THRESHOLD"; fi

# JSON-Variante
T0=$(ms)
"$BIN" catalog stats --json > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "catalog stats --json" "$ELAPSED"; else fail "catalog stats --json" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 8. Duplikat-Erkennung
# ===========================================================================
echo "=== 8. Duplikat-Erkennung Latenz ==="
THRESHOLD=3000
T0=$(ms)
"$BIN" duplicate list > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "duplicate list" "$ELAPSED"; else fail "duplicate list" "$ELAPSED" "$THRESHOLD"; fi

THRESHOLD=5000
T0=$(ms)
"$BIN" duplicate similar > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "duplicate similar" "$ELAPSED"; else fail "duplicate similar" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# Zusammenfassung
# ===========================================================================
echo "=============================="
echo "Leistungstest: $PASS bestanden, $FAIL fehlgeschlagen"
echo "=============================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
