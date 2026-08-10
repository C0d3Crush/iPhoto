#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="iPhoto"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
OBJ_DIR="$BUILD_DIR/obj"

CLEAN=0
if [ "${1:-}" = "--clean" ]; then CLEAN=1; fi

# swiftc suchen: CLT (lokal) → xcrun (Xcode / CI)
CLT="/Library/Developer/CommandLineTools"
if [ -x "$CLT/usr/bin/swiftc" ]; then
    SWIFTC="$CLT/usr/bin/swiftc"
    CODESIGN_ALLOCATE="$CLT/usr/bin/codesign_allocate"
    DEVELOPER_DIR="$CLT"
elif SWIFTC=$(xcrun --find swiftc 2>/dev/null); then
    CODESIGN_ALLOCATE=$(xcrun --find codesign_allocate 2>/dev/null || true)
    DEVELOPER_DIR=$(xcode-select -p 2>/dev/null || true)
else
    echo "Fehler: swiftc nicht gefunden. Bitte Command Line Tools oder Xcode installieren."
    exit 1
fi

# SDK suchen: CLT-Kandidaten → xcrun
SDK=""
for candidate in \
    "$CLT/SDKs/MacOSX.sdk" \
    "$CLT/SDKs/MacOSX12.1.sdk" \
    "$CLT/SDKs/MacOSX12.sdk" \
    "$CLT/SDKs/MacOSX11.3.sdk" \
    "$CLT/SDKs/MacOSX11.1.sdk" \
    "$CLT/SDKs/MacOSX11.sdk"; do
    if [ -d "$candidate" ]; then SDK="$candidate"; break; fi
done

if [ -z "$SDK" ]; then
    SDK=$(xcrun --show-sdk-path --sdk macosx 2>/dev/null || true)
fi

if [ -z "$SDK" ]; then
    echo "Fehler: Kein macOS-SDK gefunden."
    exit 1
fi

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macosx11.0"
else
    TARGET="x86_64-apple-macosx11.0"
fi

echo "==> Baue $APP_NAME"
echo "    Compiler    : $SWIFTC"
echo "    SDK         : $SDK"
echo "    Architektur : $ARCH ($TARGET)"
echo ""

# Clean (nur mit --clean; sonst inkrementell)
if [ $CLEAN -eq 1 ]; then
    echo "==> Clean-Build (--clean)"
    rm -rf "$BUILD_DIR"
fi
rm -rf "$APP_BUNDLE"
mkdir -p "$OBJ_DIR" "$MACOS_DIR" "$CONTENTS/Resources"

# Swift-Dateien einsammeln (sortiert für konsistente Kompilierung)
SOURCES=$(find "$ROOT/Sources" -name "*.swift" -not -path "*/CLI/*" | sort)
COUNT=$(echo "$SOURCES" | wc -l | tr -d ' ')
echo "==> $COUNT Swift-Dateien gefunden"
echo ""

# Output-File-Map für inkrementelle Kompilierung erzeugen
OFM="$OBJ_DIR/output-file-map.json"
{
    printf '{\n'
    printf '  "": {"swift-dependencies": "%s/master.swiftdeps"}' "$OBJ_DIR"
    while IFS= read -r f; do
        rel="${f#$ROOT/}"
        key="${rel//\//_}"
        key="${key%.swift}"
        printf ',\n  "%s": {"object": "%s/%s.o", "swift-dependencies": "%s/%s.swiftdeps"}' \
            "$f" "$OBJ_DIR" "$key" "$OBJ_DIR" "$key"
    done <<< "$SOURCES"
    printf '\n}\n'
} > "$OFM"

# Verwaiste Objektdateien entfernen (Quelle gelöscht/umbenannt)
for o in "$OBJ_DIR"/*.o; do
    [ -e "$o" ] || continue
    base=$(basename "$o" .o)
    if ! grep -qF "$OBJ_DIR/$base.o" "$OFM"; then
        rm -f "$o" "$OBJ_DIR/$base.swiftdeps"
    fi
done

# Kompilieren (inkrementell: nur geänderte Dateien)
echo "==> Kompiliere…"
"$SWIFTC" \
    -target "$TARGET" \
    -sdk "$SDK" \
    -module-name iPhoto \
    -parse-as-library \
    -O \
    -incremental \
    -c \
    -output-file-map "$OFM" \
    -j "$(sysctl -n hw.ncpu)" \
    $SOURCES

echo "==> Linke…"
"$SWIFTC" \
    -target "$TARGET" \
    -sdk "$SDK" \
    -framework SwiftUI \
    -framework AppKit \
    -framework CoreImage \
    -framework ImageIO \
    -framework PDFKit \
    -framework Vision \
    -emit-executable \
    "$OBJ_DIR"/*.o \
    -o "$MACOS_DIR/$APP_NAME"

echo "==> Kopiere Ressourcen…"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "==> Signiere App (ad-hoc)…"
CODESIGN_ALLOCATE="${CODESIGN_ALLOCATE}" \
DEVELOPER_DIR="${DEVELOPER_DIR}" \
codesign \
    --force \
    --sign - \
    --entitlements "$ROOT/Resources/iPhoto.entitlements" \
    "$APP_BUNDLE"

echo ""
echo "Fertig: $APP_BUNDLE"
echo "Starten: open \"$APP_BUNDLE\""

# CLI-Tool bauen
echo ""
echo "==> Baue iphoto-cli…"
CLI_SOURCES="\
    $ROOT/Sources/Models/RAWImageDecoder.swift \
    $ROOT/Sources/Models/HDRMerger.swift \
    $ROOT/Sources/Models/HotPixelResult.swift \
    $ROOT/Sources/Models/MetadataEntry.swift \
    $ROOT/Sources/Utilities/Data+Extensions.swift \
    $ROOT/Sources/Utilities/ImageExporter.swift \
    $ROOT/Sources/Utilities/Log.swift \
    $ROOT/Sources/Utilities/BookmarkStore.swift \
    $ROOT/Sources/Utilities/HotPixelAnalyzer.swift \
    $ROOT/Sources/Utilities/MetadataService.swift \
    $ROOT/Sources/CLI/main.swift"

# Überspringen, wenn Binary aktueller als alle CLI-Quellen ist
CLI_BIN="$BUILD_DIR/iphoto-cli"
if [ -x "$CLI_BIN" ]; then
    CLI_DIRTY=0
    for f in $CLI_SOURCES; do
        if [ "$f" -nt "$CLI_BIN" ]; then CLI_DIRTY=1; break; fi
    done
    if [ $CLI_DIRTY -eq 0 ]; then
        echo "Unverändert: $CLI_BIN"
        exit 0
    fi
fi

"$SWIFTC" \
    -target "$TARGET" \
    -sdk "$SDK" \
    -framework CoreImage \
    -framework ImageIO \
    -framework AppKit \
    -framework VideoToolbox \
    -framework CoreMedia \
    -module-name iPhotoCLI \
    -O \
    $CLI_SOURCES \
    -o "$BUILD_DIR/iphoto-cli"

echo "Fertig: $BUILD_DIR/iphoto-cli"
