#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/iphoto-librarystore-test"

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

echo "==> Kompiliere iphoto-librarystore-test …"
"$SWIFTC" \
    -target "$TARGET" \
    -sdk "$SDK" \
    -module-name iPhotoLibraryStoreTest \
    -Onone \
    "$ROOT/Sources/ViewModels/LibraryStore.swift" \
    "$ROOT/Sources/Models/Album.swift" \
    "$ROOT/Sources/Models/WatchedFolder.swift" \
    "$ROOT/Sources/Models/SmartFolder.swift" \
    "$ROOT/Sources/Models/ImageDocument.swift" \
    "$ROOT/Sources/Models/MetadataEntry.swift" \
    "$ROOT/Sources/Models/DetectedVolume.swift" \
    "$ROOT/Sources/Utilities/Log.swift" \
    "$ROOT/Tests/librarystore/main.swift" \
    -o "$BIN"
echo ""

"$BIN"
EXIT=$?

rm -f "$BIN"
exit $EXIT
