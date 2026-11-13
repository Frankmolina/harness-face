#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Harness Face.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -o "$APP/Contents/MacOS/HarnessFace" Sources/main.swift \
  -framework Cocoa -framework Carbon
cp Info.plist "$APP/Contents/Info.plist"
xattr -cr "$APP"
if security find-identity -p codesigning 2>/dev/null | grep -q '"VENIRON Dev"'; then
  codesign --force --deep --sign "VENIRON Dev" "$APP"
  echo "Firmada con VENIRON Dev"
else
  codesign --force --deep --sign - "$APP"
  echo "Firmada ad hoc"
fi
echo "Lista: $APP"
