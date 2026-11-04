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

LOG_DIR="$ROOT/Tests/results"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/perf_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee "$LOG_FILE") 2>&1

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
# 9. SmartFolder-Abfrage
# ===========================================================================
echo "=== 9. SmartFolder-Abfrage ==="

"$BIN" smartfolder create "PerfTest-Rating" --rating-min 1 > /dev/null 2>&1 || true

THRESHOLD=1500
T0=$(ms)
"$BIN" smartfolder query "PerfTest-Rating" > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "smartfolder query (mit Katalog)" "$ELAPSED"; else fail "smartfolder query" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" smartfolder query "PerfTest-Rating" --json > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "smartfolder query --json" "$ELAPSED"; else fail "smartfolder query --json" "$ELAPSED" "$THRESHOLD"; fi

"$BIN" smartfolder delete "PerfTest-Rating" > /dev/null 2>&1 || true
echo ""

# ===========================================================================
# 10. Adjust-Pipeline-Latenz
# ===========================================================================
echo "=== 10. Adjust-Pipeline-Latenz ==="

ADJ_OUTPUT="$TMPDIR_BASE/adj_out.jpeg"
THRESHOLD=3000
T0=$(ms)
"$BIN" adjust "$MEDIUM" --output "$ADJ_OUTPUT" --format jpeg \
    --exposure 0.3 --contrast 0.1 --saturation 0.5 > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "adjust (512×512, 3 Regler)" "$ELAPSED"; else fail "adjust 512×512" "$ELAPSED" "$THRESHOLD"; fi
if [ -f "$ADJ_OUTPUT" ]; then pass "adjust Ausgabedatei vorhanden" "0"; else fail "adjust Ausgabedatei fehlt" "0" "1"; fi

ADJ_OUTPUT2="$TMPDIR_BASE/adj_out2.jpeg"
THRESHOLD=5000
T0=$(ms)
"$BIN" adjust "$MEDIUM" --output "$ADJ_OUTPUT2" --format jpeg \
    --exposure 0.2 --brightness 0.1 --contrast 0.1 --saturation 0.5 \
    --warmth 0.1 --vibrance 0.2 --clarity 0.3 --sharpen 0.2 > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "adjust (8 Regler gleichzeitig)" "$ELAPSED"; else fail "adjust 8 Regler" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 11. Such-Latenz bei 100 Katalog-Einträgen
# ===========================================================================
echo "=== 11. Catalog-Such-Latenz (100 Einträge) ==="

SCALE_DIR="$TMPDIR_BASE/scale_imgs"
mkdir -p "$SCALE_DIR"
for i in $(seq 1 100); do
    cp "$MEDIUM" "$SCALE_DIR/img_$(printf '%03d' $i).png"
done
"$BIN" quality scan "$SCALE_DIR" > /dev/null 2>&1 || true

THRESHOLD=2000
T0=$(ms)
"$BIN" search "img" > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "search (100 Einträge)" "$ELAPSED"; else fail "search 100 Einträge" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" search "img" --json > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "search --json (100 Einträge)" "$ELAPSED"; else fail "search --json 100 Einträge" "$ELAPSED" "$THRESHOLD"; fi

THRESHOLD=1500
T0=$(ms)
"$BIN" stack list > /dev/null 2>&1
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "stack list (100 Katalog-Einträge)" "$ELAPSED"; else fail "stack list 100 Einträge" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# Zusammenfassung
# ===========================================================================
echo "=============================="
echo "Leistungstest: $PASS bestanden, $FAIL fehlgeschlagen"
echo "=============================="
printf "%s\t%d\t%d\t%s\n" "$(date +%Y-%m-%dT%H:%M:%S)" "$PASS" "$FAIL" "$([ $FAIL -eq 0 ] && echo OK || echo FAIL)" >> "$LOG_DIR/perf_history.tsv"
echo "Protokoll: $LOG_FILE"
[ $FAIL -eq 0 ] && exit 0 || exit 1
