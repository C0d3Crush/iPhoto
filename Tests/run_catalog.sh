#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/iphoto-catalog-test"

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

echo "==> Kompiliere iphoto-catalog-test …"
"$SWIFTC" \
    -target "$TARGET" \
    -sdk "$SDK" \
    -module-name iPhotoCatalogTest \
    -framework AppKit \
    -Onone \
    "$ROOT/Sources/Utilities/CatalogStore.swift" \
    "$ROOT/Sources/Utilities/CatalogStore+Ratings.swift" \
    "$ROOT/Sources/Utilities/CatalogStore+Albums.swift" \
    "$ROOT/Sources/Utilities/CatalogStore+Adjustments.swift" \
    "$ROOT/Sources/Utilities/CatalogStore+Backup.swift" \
    "$ROOT/Sources/Utilities/CatalogStore+Motifs.swift" \
    "$ROOT/Sources/Utilities/CatalogStore+Quality.swift" \
    "$ROOT/Sources/Utilities/CatalogStore+People.swift" \
    "$ROOT/Sources/Utilities/SmartFolderSQLGenerator.swift" \
    "$ROOT/Sources/Utilities/Log.swift" \
    "$ROOT/Sources/Models/AdjustmentState.swift" \
    "$ROOT/Sources/Models/LocalAdjustment.swift" \
    "$ROOT/Sources/Models/Preset.swift" \
    "$ROOT/Sources/Models/SmartFolder.swift" \
    "$ROOT/Sources/Models/MetadataEntry.swift" \
    "$ROOT/Sources/Models/ImageDocument.swift" \
    "$ROOT/Sources/Models/RatingStore.swift" \
    "$ROOT/Sources/Models/FaceRecord.swift" \
    "$ROOT/Tests/catalog/main.swift" \
    -o "$BIN"
echo ""

"$BIN"
EXIT=$?

rm -f "$BIN"
exit $EXIT
