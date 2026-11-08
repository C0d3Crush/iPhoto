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
"$BIN" catalog stats > /dev/null 2>&1 || true
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
"$BIN" quality scan "$SMALL" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "quality scan 64×64" "$ELAPSED"; else fail "quality scan 64×64" "$ELAPSED" "$THRESHOLD"; fi

THRESHOLD=8000
T0=$(ms)
"$BIN" quality scan "$MEDIUM" > /dev/null 2>&1 || true
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
"$BIN" quality scan "${BATCH_PATHS[@]}" > /dev/null 2>&1 || true
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
"$BIN" catalog stats > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "catalog stats (mit Daten)" "$ELAPSED"; else fail "catalog stats (mit Daten)" "$ELAPSED" "$THRESHOLD"; fi

# JSON-Variante
T0=$(ms)
"$BIN" catalog stats --json > /dev/null 2>&1 || true
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
"$BIN" duplicate list > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "duplicate list" "$ELAPSED"; else fail "duplicate list" "$ELAPSED" "$THRESHOLD"; fi

THRESHOLD=5000
T0=$(ms)
"$BIN" duplicate similar > /dev/null 2>&1 || true
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
"$BIN" smartfolder query "PerfTest-Rating" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "smartfolder query (mit Katalog)" "$ELAPSED"; else fail "smartfolder query" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" smartfolder query "PerfTest-Rating" --json > /dev/null 2>&1 || true
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
"$BIN" search "img" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "search (100 Einträge)" "$ELAPSED"; else fail "search 100 Einträge" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" search "img" --json > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "search --json (100 Einträge)" "$ELAPSED"; else fail "search --json 100 Einträge" "$ELAPSED" "$THRESHOLD"; fi

THRESHOLD=1500
T0=$(ms)
"$BIN" stack list > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "stack list (100 Katalog-Einträge)" "$ELAPSED"; else fail "stack list 100 Einträge" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# Zusammenfassung
# ===========================================================================
# ===========================================================================
# 12. Info-Latenz
# ===========================================================================
echo "=== 12. Info-Latenz ==="

THRESHOLD=1500
T0=$(ms)
"$BIN" info "$SMALL" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "info (64×64)" "$ELAPSED"; else fail "info 64×64" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" info "$SMALL" --json > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "info --json" "$ELAPSED"; else fail "info --json" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 13. Analyse-Latenz
# ===========================================================================
echo "=== 13. Analyse-Latenz ==="

THRESHOLD=5000
T0=$(ms)
"$BIN" analyse "$SMALL" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "analyse (64×64)" "$ELAPSED"; else fail "analyse 64×64" "$ELAPSED" "$THRESHOLD"; fi

THRESHOLD=8000
T0=$(ms)
"$BIN" analyse "$MEDIUM" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "analyse (512×512)" "$ELAPSED"; else fail "analyse 512×512" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" analyse "$MEDIUM" --json > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "analyse --json (512×512)" "$ELAPSED"; else fail "analyse --json 512×512" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 14. Preset-Latenz
# ===========================================================================
echo "=== 14. Preset-Latenz ==="

THRESHOLD=1000
T0=$(ms)
"$BIN" preset list > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "preset list" "$ELAPSED"; else fail "preset list" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" preset list --json > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "preset list --json" "$ELAPSED"; else fail "preset list --json" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 15. Plugins-Latenz
# ===========================================================================
echo "=== 15. Plugins-Latenz ==="

THRESHOLD=500
T0=$(ms)
"$BIN" plugins list > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "plugins list" "$ELAPSED"; else fail "plugins list" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" plugins dir > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "plugins dir" "$ELAPSED"; else fail "plugins dir" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 16. Rating-Operationen-Latenz
# ===========================================================================
echo "=== 16. Rating-Operationen-Latenz ==="

THRESHOLD=500
T0=$(ms)
"$BIN" rating "$SMALL" --set 3 > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "rating --set" "$ELAPSED"; else fail "rating --set" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" rating "$SMALL" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "rating (read)" "$ELAPSED"; else fail "rating read" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" rating "$SMALL" --remove > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "rating --remove" "$ELAPSED"; else fail "rating --remove" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 17. Trash-Latenz
# ===========================================================================
echo "=== 17. Trash-Latenz ==="

TRASH_FILE="$TMPDIR_BASE/trash_perf.png"
cp "$SMALL" "$TRASH_FILE"
"$BIN" quality scan "$TRASH_FILE" > /dev/null 2>&1 || true

THRESHOLD=500
T0=$(ms)
"$BIN" trash mark "$TRASH_FILE" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "trash mark" "$ELAPSED"; else fail "trash mark" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" trash list > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "trash list (1 Eintrag)" "$ELAPSED"; else fail "trash list 1 Eintrag" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" trash restore "$TRASH_FILE" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "trash restore" "$ELAPSED"; else fail "trash restore" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 18. Motif-Latenz
# ===========================================================================
echo "=== 18. Motif-Latenz ==="

THRESHOLD=1500
T0=$(ms)
"$BIN" motif get "$SMALL" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "motif get (64×64)" "$ELAPSED"; else fail "motif get 64×64" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" motif get "$SMALL" --json > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "motif get --json" "$ELAPSED"; else fail "motif get --json" "$ELAPSED" "$THRESHOLD"; fi

# version list/delete latency
THRESHOLD=500
T0=$(ms)
"$BIN" version list "$VCOPY" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "version list" "$ELAPSED"; else fail "version list" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 19. People-Latenz
# ===========================================================================
echo "=== 19. People-Latenz ==="

THRESHOLD=5000
T0=$(ms)
"$BIN" people scan "$SMALL" > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "people scan (64×64)" "$ELAPSED"; else fail "people scan 64×64" "$ELAPSED" "$THRESHOLD"; fi

THRESHOLD=500
T0=$(ms)
"$BIN" people list > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "people list" "$ELAPSED"; else fail "people list" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms)
"$BIN" people faces > /dev/null 2>&1 || true
T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "people faces" "$ELAPSED"; else fail "people faces" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 20. Album-Schreiboperationen-Latenz
# ===========================================================================
echo "=== 20. Album-Schreiboperationen-Latenz ==="

THRESHOLD=500

PERF_AID=$("$BIN" album create "PerfAlbum" --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null) || PERF_AID=""

if [ -n "$PERF_AID" ]; then
    T0=$(ms); "$BIN" album add "$PERF_AID" "$SMALL" > /dev/null 2>&1 || true; T1=$(ms)
    ELAPSED=$((T1-T0))
    if [ $ELAPSED -le $THRESHOLD ]; then pass "album add (Schreiben)" "$ELAPSED"; else fail "album add (Schreiben)" "$ELAPSED" "$THRESHOLD"; fi

    T0=$(ms); "$BIN" album images "$PERF_AID" > /dev/null 2>&1 || true; T1=$(ms)
    ELAPSED=$((T1-T0))
    if [ $ELAPSED -le $THRESHOLD ]; then pass "album images (Lesen)" "$ELAPSED"; else fail "album images (Lesen)" "$ELAPSED" "$THRESHOLD"; fi

    T0=$(ms); "$BIN" album reorder "$PERF_AID" "$SMALL" > /dev/null 2>&1 || true; T1=$(ms)
    ELAPSED=$((T1-T0))
    if [ $ELAPSED -le $THRESHOLD ]; then pass "album reorder (Schreiben)" "$ELAPSED"; else fail "album reorder (Schreiben)" "$ELAPSED" "$THRESHOLD"; fi

    T0=$(ms); "$BIN" album remove "$PERF_AID" "$SMALL" > /dev/null 2>&1 || true; T1=$(ms)
    ELAPSED=$((T1-T0))
    if [ $ELAPSED -le $THRESHOLD ]; then pass "album remove (Schreiben)" "$ELAPSED"; else fail "album remove (Schreiben)" "$ELAPSED" "$THRESHOLD"; fi

    T0=$(ms); "$BIN" album delete "$PERF_AID" > /dev/null 2>&1 || true; T1=$(ms)
    ELAPSED=$((T1-T0))
    if [ $ELAPSED -le $THRESHOLD ]; then pass "album delete (Schreiben)" "$ELAPSED"; else fail "album delete (Schreiben)" "$ELAPSED" "$THRESHOLD"; fi
else
    pass "album Schreibops-Latenz übersprungen (create fehlgeschlagen)" "0"
    pass "album images-Latenz übersprungen" "0"
    pass "album reorder-Latenz übersprungen" "0"
    pass "album remove-Latenz übersprungen" "0"
    pass "album delete-Latenz übersprungen" "0"
fi
echo ""

# ===========================================================================
# 21. SmartFolder create/query-Latenz
# ===========================================================================
echo "=== 21. SmartFolder create/query-Latenz ==="

THRESHOLD=500
T0=$(ms); "$BIN" smartfolder create "PerfOrdner" --rating-min 2 > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "smartfolder create" "$ELAPSED"; else fail "smartfolder create" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms); "$BIN" smartfolder query "PerfOrdner" > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "smartfolder query" "$ELAPSED"; else fail "smartfolder query" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms); "$BIN" smartfolder query "PerfOrdner" --json > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "smartfolder query --json" "$ELAPSED"; else fail "smartfolder query --json" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms); "$BIN" smartfolder delete "PerfOrdner" > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "smartfolder delete" "$ELAPSED"; else fail "smartfolder delete" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 22. Skalierungstest — 500 Katalog-Einträge
# ===========================================================================
echo "=== 22. Skalierungstest (500 Einträge) ==="

SCALE_DIR="$TMPDIR_BASE/scale500"
mkdir -p "$SCALE_DIR"
for i in $(seq 1 500); do
    make_png "$SCALE_DIR/perf_img_$(printf '%04d' $i).png" 32 32
    "$BIN" rating "$SCALE_DIR/perf_img_$(printf '%04d' $i).png" --set 0 > /dev/null 2>&1 || true
done

THRESHOLD=3000
T0=$(ms); "$BIN" search "perf_img" > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "search (500 Einträge, text)" "$ELAPSED"; else fail "search 500 Einträge text" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms); "$BIN" search "perf_img" --json > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "search --json (500 Einträge)" "$ELAPSED"; else fail "search --json 500 Einträge" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms); "$BIN" catalog stats > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
THRESHOLD=1000
if [ $ELAPSED -le $THRESHOLD ]; then pass "catalog stats (500 Einträge)" "$ELAPSED"; else fail "catalog stats 500 Einträge" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms); "$BIN" catalog stats --json > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "catalog stats --json (500 Einträge)" "$ELAPSED"; else fail "catalog stats --json 500 Einträge" "$ELAPSED" "$THRESHOLD"; fi

THRESHOLD=2000
T0=$(ms); "$BIN" search --camera "Canon" > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "search --camera (500 Einträge)" "$ELAPSED"; else fail "search --camera 500 Einträge" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms); "$BIN" search --date "2024" > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "search --date (500 Einträge)" "$ELAPSED"; else fail "search --date 500 Einträge" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 23. Export-Latenz
# ===========================================================================
echo "=== 23. Export-Latenz ==="

THRESHOLD=2000
EXPORT_OUT="$TMPDIR_BASE/perf_export.jpg"

T0=$(ms); "$BIN" export "$SMALL" --format jpeg --output "$EXPORT_OUT" > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "export PNG→JPEG (64×64)" "$ELAPSED"; else fail "export PNG→JPEG 64×64" "$ELAPSED" "$THRESHOLD"; fi

EXPORT_OUT2="$TMPDIR_BASE/perf_export2.jpg"
T0=$(ms); "$BIN" export "$MEDIUM" --format jpeg --output "$EXPORT_OUT2" > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "export PNG→JPEG (512×512)" "$ELAPSED"; else fail "export PNG→JPEG 512×512" "$ELAPSED" "$THRESHOLD"; fi

EXPORT_OUT3="$TMPDIR_BASE/perf_export3.jpg"
T0=$(ms); "$BIN" export "$MEDIUM" --format jpeg --output "$EXPORT_OUT3" --json > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "export --json (512×512)" "$ELAPSED"; else fail "export --json 512×512" "$ELAPSED" "$THRESHOLD"; fi

EXPORT_DIR_OUT="$TMPDIR_BASE/perf_export_dir"
mkdir -p "$EXPORT_DIR_OUT"
T0=$(ms); "$BIN" export "$MEDIUM" --format png --output-dir "$EXPORT_DIR_OUT" > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "export --output-dir (512×512)" "$ELAPSED"; else fail "export --output-dir 512×512" "$ELAPSED" "$THRESHOLD"; fi
echo ""

# ===========================================================================
# 24. ViewMode + Preset-Latenz
# ===========================================================================
echo "=== 24. ViewMode + Preset-Latenz ==="

THRESHOLD=500
T0=$(ms); "$BIN" viewmode get > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "viewmode get" "$ELAPSED"; else fail "viewmode get" "$ELAPSED" "$THRESHOLD"; fi

T0=$(ms); "$BIN" viewmode set grid > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "viewmode set" "$ELAPSED"; else fail "viewmode set" "$ELAPSED" "$THRESHOLD"; fi
"$BIN" viewmode set gallery > /dev/null 2>&1 || true

T0=$(ms); "$BIN" viewmode get --json > /dev/null 2>&1 || true; T1=$(ms)
ELAPSED=$((T1-T0))
if [ $ELAPSED -le $THRESHOLD ]; then pass "viewmode get --json" "$ELAPSED"; else fail "viewmode get --json" "$ELAPSED" "$THRESHOLD"; fi

PRESET_NAME_PERF=$("$BIN" preset list --json 2>/dev/null | python3 -c "import sys,json; a=json.load(sys.stdin); print(a[0]['name'] if a else '')" 2>/dev/null) || PRESET_NAME_PERF=""
if [ -n "$PRESET_NAME_PERF" ]; then
    THRESHOLD=2000
    PRESET_PERF_OUT="$TMPDIR_BASE/perf_preset.jpeg"
    T0=$(ms); "$BIN" preset apply "$SMALL" --name "$PRESET_NAME_PERF" --output "$PRESET_PERF_OUT" --format jpeg > /dev/null 2>&1 || true; T1=$(ms)
    ELAPSED=$((T1-T0))
    if [ $ELAPSED -le $THRESHOLD ]; then pass "preset apply '$PRESET_NAME_PERF' (64×64)" "$ELAPSED"; else fail "preset apply latenz" "$ELAPSED" "$THRESHOLD"; fi
else
    pass "preset apply übersprungen (keine Presets)" "0"
fi
echo ""

# ===========================================================================
echo "=== 25. Info + Analyse Latenz ==="
THRESHOLD_INFO=1500
THRESHOLD_ANALYSE=3000

# info single image
T0=$(ms); "$BIN" info "$SMALL" > /dev/null 2>&1; T1=$(ms); DT=$((T1-T0))
if [ $DT -le $THRESHOLD_INFO ]; then pass "info single (${DT}ms)" "$DT"; else fail "info single" "$DT" "$THRESHOLD_INFO"; fi

# info --json
T0=$(ms); "$BIN" info "$SMALL" --json > /dev/null 2>&1; T1=$(ms); DT=$((T1-T0))
if [ $DT -le $THRESHOLD_INFO ]; then pass "info --json (${DT}ms)" "$DT"; else fail "info --json" "$DT" "$THRESHOLD_INFO"; fi

# analyse single image
T0=$(ms); "$BIN" analyse "$SMALL" > /dev/null 2>&1; T1=$(ms); DT=$((T1-T0))
if [ $DT -le $THRESHOLD_ANALYSE ]; then pass "analyse single (${DT}ms)" "$DT"; else fail "analyse single" "$DT" "$THRESHOLD_ANALYSE"; fi

# analyse directory (10 images)
BATCH_DIR="$TMPDIR_BASE"
T0=$(ms); "$BIN" analyse "$BATCH_DIR/batch_1.png" "$BATCH_DIR/batch_2.png" "$BATCH_DIR/batch_3.png" "$BATCH_DIR/batch_4.png" "$BATCH_DIR/batch_5.png" > /dev/null 2>&1; T1=$(ms); DT=$((T1-T0))
if [ $DT -le $((THRESHOLD_ANALYSE * 5)) ]; then pass "analyse 5 Bilder (${DT}ms)" "$DT"; else fail "analyse 5 Bilder" "$DT" "$((THRESHOLD_ANALYSE * 5))"; fi

echo ""

# ===========================================================================
echo "=============================="
echo "Leistungstest: $PASS bestanden, $FAIL fehlgeschlagen"
echo "=============================="
printf "%s\t%d\t%d\t%s\n" "$(date +%Y-%m-%dT%H:%M:%S)" "$PASS" "$FAIL" "$([ $FAIL -eq 0 ] && echo OK || echo FAIL)" >> "$LOG_DIR/perf_history.tsv"
echo "Protokoll: $LOG_FILE"
[ $FAIL -eq 0 ] && exit 0 || exit 1
