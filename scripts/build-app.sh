#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
RHWP_DISABLE_EXTERNAL_WEBFONTS=1 npm run build:web
node scripts/make-blank.mjs
app="dist/Super Docs.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -swift-version 5 -O -target arm64-apple-macos14.0 -framework AppKit -framework WebKit -framework Network -framework UniformTypeIdentifiers -framework CryptoKit Sources/SuperDocs/*.swift -o "$app/Contents/MacOS/SuperDocs"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/Blank.hwpx "$app/Contents/Resources/"
cp Resources/THIRD_PARTY_NOTICES.txt "$app/Contents/Resources/"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
rsync -a --delete .build/web/ "$app/Contents/Resources/Web/"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "Built: $PWD/$app"
