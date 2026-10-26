#!/bin/bash
# Baut die Mac-App (ZIP) und die iPhone-App (IPA, ad hoc signiert – zum Neu-Signieren mit Signulous).
# Aufruf: scripts/baue.sh [Version]   – braucht Xcode und XcodeGen (brew install xcodegen)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-$(cat VERSION)}"
NUMMER="$(echo "$VERSION" | awk -F. '{ printf "%d%02d%02d", $1, $2, $3 }')"

rm -rf build && mkdir -p build
swift scripts/symbol.swift build/AppIcon.iconset ressourcen/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
iconutil -c icns build/AppIcon.iconset -o ressourcen/AppIcon.icns
sips -g hasAlpha -g pixelWidth ressourcen/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --spec project.yml --quiet

bauen() {  # Schema, SDK/Ziel, Log, weitere Einstellungen
  xcodebuild -project Paketbote.xcodeproj -scheme "$1" -configuration Release -derivedDataPath build/dd $2 ${4:-} \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$NUMMER" -skipPackagePluginValidation build 2>&1 | tee "build/$3.log" \
    | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true
  grep -q "BUILD SUCCEEDED" "build/$3.log" || { grep -B2 -A6 "error:" "build/$3.log" | head -80; exit 1; }
}

# Mac
bauen Paketbote-Mac "-destination generic/platform=macOS" mac
cp -R build/dd/Build/Products/Release/Paketbote.app build/
codesign --verify --deep --strict build/Paketbote.app && echo "Mac: Signatur ok"
(cd build && ditto -c -k --sequesterRsrc --keepParent Paketbote.app "Paketbote-macOS-$VERSION.zip")

# iPhone/iPad (Gerät): ohne Profil bauen, dann selbst ad hoc mit den Berechtigungen (App-Gruppe) signieren –
# Signulous signiert beim Installieren mit dem eigenen Zertifikat neu und übernimmt die Berechtigungen.
bauen Paketbote-iOS "-sdk iphoneos -destination generic/platform=iOS" ios "CODE_SIGNING_ALLOWED=NO"
mkdir -p build/ipa/Payload
cp -R build/dd/Build/Products/Release-iphoneos/Paketbote.app build/ipa/Payload/
APP=build/ipa/Payload/Paketbote.app
codesign -f -s - --entitlements ressourcen/Widgets-iOS.entitlements "$APP/PlugIns/PaketboteWidgets.appex"
codesign -f -s - --entitlements ressourcen/iOS.entitlements "$APP"
echo "iPhone: Berechtigungen"; codesign -d --entitlements - build/ipa/Payload/Paketbote.app 2>/dev/null | grep -A2 application-groups || echo "  (keine)"
echo "iPhone: Symbol im Info.plist"; plutil -p "$APP/Info.plist" | grep -A6 CFBundleIcons || { echo "FEHLER: kein App-Symbol"; exit 1; }
ls "$APP" | grep -i appicon
mkdir -p bilder-ci && cp ressourcen/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png bilder-ci/
(cd build/ipa && zip -qry "../Paketbote-iOS-$VERSION.ipa" Payload)
echo "Fertig: build/Paketbote-macOS-$VERSION.zip, build/Paketbote-iOS-$VERSION.ipa"
