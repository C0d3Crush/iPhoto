#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="iPhoto"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"

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

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$CONTENTS/Resources"

# Swift-Dateien einsammeln (sortiert für konsistente Kompilierung)
SOURCES=$(find "$ROOT/Sources" -name "*.swift" -not -path "*/CLI/*" | sort)
COUNT=$(echo "$SOURCES" | wc -l | tr -d ' ')
echo "==> $COUNT Swift-Dateien gefunden"
echo "$SOURCES" | while read f; do echo "    $f"; done
echo ""

# Kompilieren
echo "==> Kompiliere…"
"$SWIFTC" \
    -target "$TARGET" \
    -sdk "$SDK" \
    -framework SwiftUI \
    -framework AppKit \
    -framework CoreImage \
    -framework ImageIO \
    -framework PDFKit \
    -module-name iPhoto \
    -parse-as-library \
    -O \
    $SOURCES \
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
    $ROOT/Sources/Models/HotPixelResult.swift \
    $ROOT/Sources/Utilities/ImageExporter.swift \
    $ROOT/Sources/Utilities/Log.swift \
    $ROOT/Sources/Utilities/BookmarkStore.swift \
    $ROOT/Sources/Utilities/HotPixelAnalyzer.swift \
    $ROOT/Sources/CLI/main.swift"

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
