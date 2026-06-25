#!/bin/bash
# Tests alle Export-Formate mit iphoto-cli
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
echo "=== iPhoto CLI — Dateiformat-Tests ==="
echo "Binary : $BIN"
echo "Tmpdir : $TMPDIR"
echo ""

# Minimales 1×1 weißes PNG (Base64-kodiert)
INPUT_PNG="$TMPDIR/test_input.png"
python3 - <<'EOF' > "$INPUT_PNG"
import struct, zlib, sys
def chunk(name, data):
    c = zlib.crc32(name + data) & 0xffffffff
    return struct.pack('>I', len(data)) + name + data + struct.pack('>I', c)
sig = b'\x89PNG\r\n\x1a\n'
ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', 2, 2, 8, 2, 0, 0, 0))
idat_raw = b'\x00\xff\xff\xff\x00\xff\xff\xff' * 1  # 2 Zeilen à filter+RGB+RGB
idat = chunk(b'IDAT', zlib.compress(b'\x00\xff\xff\xff\x00\xff\xff\xff'))
iend = chunk(b'IEND', b'')
sys.stdout.buffer.write(sig + ihdr + idat + iend)
EOF

echo "--- Export-Formate ---"
for fmt in jpeg png tiff; do
    OUT="$TMPDIR/out.$fmt"
    if "$BIN" export "$INPUT_PNG" --format "$fmt" --output "$OUT" 2>/dev/null; then
        if [ -f "$OUT" ] && [ -s "$OUT" ]; then
            SIZE=$(wc -c < "$OUT" | tr -d ' ')
            pass "$fmt (${SIZE} bytes)"
        else
            fail "$fmt" "Ausgabedatei leer oder fehlt"
        fi
    else
        fail "$fmt" "CLI-Fehler beim Export"
    fi
done

# HEIF benötigt VideoToolbox mit aktivem Display-Server — im CLI-Kontext nicht verfügbar
OUT_HEIF="$TMPDIR/out.heif"
if "$BIN" export "$INPUT_PNG" --format heif --output "$OUT_HEIF" 2>/dev/null && [ -s "$OUT_HEIF" ]; then
    SIZE=$(wc -c < "$OUT_HEIF" | tr -d ' ')
    pass "heif (${SIZE} bytes)"
else
    echo "  SKIP: heif (HEIF-Encoding benötigt Display-Server — nur in der GUI-App verfügbar)"
fi

echo ""
echo "--- Batch-Export ---"
BATCH_IN1="$TMPDIR/a.png"
BATCH_IN2="$TMPDIR/b.png"
BATCH_OUT="$TMPDIR/batch"
cp "$INPUT_PNG" "$BATCH_IN1"
cp "$INPUT_PNG" "$BATCH_IN2"
mkdir -p "$BATCH_OUT"
if "$BIN" export "$BATCH_IN1" "$BATCH_IN2" --format jpeg --output-dir "$BATCH_OUT" 2>/dev/null; then
    for name in a b; do
        f="$BATCH_OUT/${name}.jpg"
        if [ -f "$f" ] && [ -s "$f" ]; then
            pass "batch $name.jpg"
        else
            fail "batch $name.jpg" "Datei fehlt"
        fi
    done
else
    fail "batch" "CLI-Fehler"
fi

echo ""
echo "--- Info-Befehl ---"
INFO_OUT=$("$BIN" info "$INPUT_PNG" 2>&1)
if echo "$INFO_OUT" | grep -q "Größe"; then
    pass "info (Größe erkannt)"
else
    fail "info" "Keine Größenangabe in Ausgabe"
fi

echo ""
echo "--- Fehlerbehandlung ---"
if "$BIN" export /nichtexistent.png --format jpeg --output "$TMPDIR/x.jpg" 2>/dev/null; then
    fail "fehler-eingabe" "Sollte fehlschlagen, hat aber Exitcode 0 zurückgegeben"
else
    pass "fehler-eingabe (Exitcode != 0)"
fi

echo ""
echo "=============================="
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
echo "=============================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
