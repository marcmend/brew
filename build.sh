#!/bin/zsh
# Usage : ./build.sh            → build/Brew.app
#         ./build.sh install    → copie aussi dans /Applications et lance l'app
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Brew.app
mkdir -p build

# Les Command Line Tools livrent un module.modulemap périmé qui redéfinit SwiftBridging
# et casse l'import de Foundation/SwiftUI : on le masque via un overlay VFS.
: > build/empty.modulemap
cat > build/vfs.yaml <<EOF
{ "version": 0, "case-sensitive": "false", "roots": [ { "type": "directory",
  "name": "/Library/Developer/CommandLineTools/usr/include/swift",
  "contents": [ { "type": "file", "name": "module.modulemap", "external-contents": "$PWD/build/empty.modulemap" } ] } ] }
EOF
SWIFTC=(swiftc -O -vfsoverlay build/vfs.yaml -Xcc -ivfsoverlay -Xcc build/vfs.yaml -target arm64-apple-macos14.0)

"${SWIFTC[@]}" -parse-as-library -o build/Brew Sources/Brew/*.swift
"${SWIFTC[@]}" -o build/make-icon scripts/make-icon.swift

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/Brew "$APP/Contents/MacOS/Brew"
cp Resources/Info.plist "$APP/Contents/Info.plist"

build/make-icon build/AppIcon.icns
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf build/AppIcon.iconset

codesign --force --sign - "$APP"
echo "✓ $APP"

if [[ "${1:-}" == "install" ]]; then
  pkill -x Brew 2>/dev/null || true
  rm -rf /Applications/Brew.app
  cp -R "$APP" /Applications/
  open /Applications/Brew.app
  echo "✓ installé dans /Applications"
fi
