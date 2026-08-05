#!/bin/bash
# Notarize + staple iPhoto.app fuer Vertrieb ausserhalb des App Store.
#
# Voraussetzungen (einmalig einrichten):
#   1. Developer-ID-Application-Zertifikat im Login-Keychain
#      (Apple Developer Account > Certificates > "Developer ID Application")
#   2. App-Specific-Password fuer notarytool im Keychain hinterlegen:
#        xcrun notarytool store-credentials "iPhoto-Notary" \
#            --apple-id "lukas.dzielski@gmail.com" \
#            --team-id "XXXXXXXXXX" \
#            --password "abcd-efgh-ijkl-mnop"
#
# Nutzung:
#   ./notarize.sh                           # signiert build/iPhoto.app mit
#                                           # Developer-ID + notarisiert + stapled
#   IDENTITY="Developer ID Application: Vorname Nachname (TEAMID)" ./notarize.sh
#
# Sparkle-Integrationsplan (SPAETER, wenn Auto-Update benoetigt wird):
# ---------------------------------------------------------------------
# 1. Sparkle-Framework beschaffen ohne SPM: Release-.tar.xz von
#    github.com/sparkle-project/Sparkle laden, Sparkle.framework nach
#    ./Frameworks/ ablegen. build.sh anpassen:
#      - swiftc-Aufrufe: -F "$ROOT/Frameworks" -framework Sparkle
#      - Post-Link: cp -R Frameworks/Sparkle.framework $CONTENTS/Frameworks/
#      - LC_RPATH auf @executable_path/../Frameworks setzen:
#          install_name_tool -add_rpath @executable_path/../Frameworks \
#              "$MACOS_DIR/iPhoto"
# 2. Info.plist ergaenzen:
#      SUFeedURL     = https://c0d3crush.github.io/iphoto/appcast.xml
#      SUPublicEDKey = <ed25519 public key aus generate_keys>
#      SUEnableAutomaticChecks = true
# 3. AppDelegate: SPUStandardUpdaterController als @IBOutlet oder als
#    lazy property; UI-Trigger "Nach Updates suchen..." ans Hauptmenue haengen.
# 4. Release-Workflow: notarize.sh -> zip -> generate_appcast auf den ZIP
#    (aus Sparkle-Bin-Ordner) -> appcast.xml + ZIP nach GitHub Pages pushen.
# 5. Notarization + Sparkle beissen sich nicht: die notarisierte, gestaplete
#    .app wird 1:1 in die ZIP gepackt; Sparkle verifiziert die Ed25519-Signatur
#    der ZIP, nicht die Codesign-Signatur der .app.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$ROOT/build/iPhoto.app"
KEYCHAIN_PROFILE="iPhoto-Notary"
IDENTITY="${IDENTITY:-Developer ID Application}"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Fehler: $APP_BUNDLE existiert nicht. Erst ./build.sh laufen lassen."
    exit 1
fi

echo "==> Signiere mit Developer-ID: $IDENTITY"
codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --entitlements "$ROOT/Resources/iPhoto.entitlements" \
    --sign "$IDENTITY" \
    "$APP_BUNDLE"

echo "==> Verifiziere Signatur"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "==> Verpacke fuer Notarisierung"
ZIP="$ROOT/build/iPhoto-notarize.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP"

echo "==> Sende an Apple Notary Service (kann 2-15 min dauern)"
xcrun notarytool submit "$ZIP" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "==> Stapler-Ticket in .app einbetten"
xcrun stapler staple "$APP_BUNDLE"

echo "==> Fertig. Verifiziere final:"
spctl --assess --type execute --verbose=2 "$APP_BUNDLE"
echo ""
echo "Signierte + notarisierte App: $APP_BUNDLE"
