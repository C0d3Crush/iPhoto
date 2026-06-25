#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/iphoto-bench"

# ── Build ────────────────────────────────────────────────────────────────────
CLT="/Library/Developer/CommandLineTools"
if [ -x "$CLT/usr/bin/swiftc" ]; then
    SWIFTC="$CLT/usr/bin/swiftc"
    SDK="$CLT/SDKs/MacOSX.sdk"
    [ -d "$SDK" ] || SDK=$(xcrun --show-sdk-path --sdk macosx 2>/dev/null)
else
    SWIFTC=$(xcrun --find swiftc 2>/dev/null)
    SDK=$(xcrun --show-sdk-path --sdk macosx 2>/dev/null)
fi

ARCH=$(uname -m)
[ "$ARCH" = "arm64" ] && TARGET="arm64-apple-macosx11.0" || TARGET="x86_64-apple-macosx11.0"

BENCH_SOURCES="\
    $ROOT/Sources/Models/RAWImageDecoder.swift \
    $ROOT/Sources/Utilities/ImageExporter.swift \
    $ROOT/Sources/Utilities/Log.swift \
    $ROOT/Sources/Utilities/BookmarkStore.swift \
    $ROOT/Tests/bench/main.swift"

echo "==> Kompiliere iphoto-bench …"
"$SWIFTC" \
    -target "$TARGET" \
    -sdk "$SDK" \
    -framework CoreImage \
    -framework ImageIO \
    -module-name iPhotoBench \
    -Onone \
    $BENCH_SOURCES \
    -o "$BIN"
echo ""

# ── Ausführen ────────────────────────────────────────────────────────────────
export CPU_ARCH="$ARCH"
"$BIN"
EXIT=$?

# Aufräumen
rm -f "$BIN"
exit $EXIT
