#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Harness Face.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -o "$APP/Contents/MacOS/HarnessFace" Sources/main.swift Sources/Dictation.swift \
  -framework Cocoa -framework Carbon -framework Speech -framework AVFoundation
cp Info.plist "$APP/Contents/Info.plist"
# The Desktop is often managed by iCloud/FileProvider: its xattrs make codesign
# refuse a bundle even after xattr -cr. Sign a clean /tmp copy and bring it back.
SIGNED="$(mktemp -d)/Harness Face.app"
ditto "$APP" "$SIGNED"
xattr -cr "$SIGNED"
if security find-identity -p codesigning 2>/dev/null | grep -q '"VENIRON Dev"'; then
  codesign --force --deep --sign "VENIRON Dev" "$SIGNED"
  echo "Firmada con VENIRON Dev"
else
  codesign --force --deep --sign - "$SIGNED"
  echo "Firmada ad hoc"
fi
rm -rf "$APP"
ditto "$SIGNED" "$APP"
echo "Lista: $APP"
