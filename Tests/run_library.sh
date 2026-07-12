#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/iphoto-library-test"

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

echo "==> Kompiliere iphoto-library-test …"
"$SWIFTC" \
    -target "$TARGET" \
    -sdk "$SDK" \
    -framework CoreImage \
    -framework ImageIO \
    -module-name iPhotoLibTest \
    -Onone \
    "$ROOT/Sources/Models/RAWImageDecoder.swift" \
    "$ROOT/Sources/Utilities/Data+Extensions.swift" \
    "$ROOT/Sources/Utilities/ImageExporter.swift" \
    "$ROOT/Sources/Utilities/Log.swift" \
    "$ROOT/Sources/Utilities/BookmarkStore.swift" \
    "$ROOT/Tests/library/main.swift" \
    -o "$BIN"
echo ""

export CPU_ARCH="$ARCH"
"$BIN"
EXIT=$?

rm -f "$BIN"
exit $EXIT
