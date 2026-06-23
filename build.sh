#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="iPhoto"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"

# Compiler & SDK suchen
CLT="/Library/Developer/CommandLineTools"
SWIFTC="$CLT/usr/bin/swiftc"

if [ ! -x "$SWIFTC" ]; then
    echo "Fehler: swiftc nicht gefunden unter $SWIFTC"
    echo "Bitte Command Line Tools installieren: xcode-select --install"
    exit 1
fi

# Bestes verfügbares macOS SDK >= 11 bevorzugen
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
    echo "Fehler: Kein macOS-SDK >= 11 gefunden unter $CLT/SDKs/"
    exit 1
fi

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macosx11.7"
else
    TARGET="x86_64-apple-macosx11.7"
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
SOURCES=$(find "$ROOT/Sources" -name "*.swift" | sort)
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
CODESIGN_ALLOCATE="$CLT/usr/bin/codesign_allocate" \
DEVELOPER_DIR="$CLT" \
codesign \
    --force \
    --sign - \
    --entitlements "$ROOT/Resources/iPhoto.entitlements" \
    "$APP_BUNDLE"

echo ""
echo "Fertig: $APP_BUNDLE"
echo "Starten: open \"$APP_BUNDLE\""
