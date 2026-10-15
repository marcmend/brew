#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${1:-dev}"
APP="build/Brew.app"
OUTPUT="dist/Brew-${VERSION}-arm64.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

if [[ ! -d "$APP" ]]; then
  echo "Missing $APP. Run ./build.sh first." >&2
  exit 1
fi

mkdir -p dist
cp -R "$APP" "$STAGING/Brew.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Brew" -srcfolder "$STAGING" -ov -format UDZO "$OUTPUT"
shasum -a 256 "$OUTPUT"
echo "Created $OUTPUT"
