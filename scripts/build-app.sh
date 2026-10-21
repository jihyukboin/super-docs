#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/setup-sparkle.sh
RHWP_DISABLE_EXTERNAL_WEBFONTS=1 npm run build:web
node scripts/make-blank.mjs
app="dist/Super Docs.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
swiftc -swift-version 5 -O -target arm64-apple-macos14.0 -framework AppKit -framework WebKit -framework Network -framework UniformTypeIdentifiers -framework CryptoKit -F .build/sparkle -framework Sparkle -Xlinker -rpath -Xlinker '@executable_path/../Frameworks' Sources/SuperDocs/*.swift -o "$app/Contents/MacOS/SuperDocs"
cp Resources/Info.plist "$app/Contents/Info.plist"
version="${APP_VERSION:-$(node -p "require('./package.json').version")}"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo 'APP_VERSION must be major.minor.patch' >&2; exit 1; fi
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$app/Contents/Info.plist"
rsync -a --delete .build/sparkle/Sparkle.framework/ "$app/Contents/Frameworks/Sparkle.framework/"
cp .build/sparkle/LICENSE "$app/Contents/Resources/LICENSE.Sparkle.txt"
cp Resources/Blank.hwpx "$app/Contents/Resources/"
cp Resources/THIRD_PARTY_NOTICES.txt "$app/Contents/Resources/"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
rsync -a --delete .build/web/ "$app/Contents/Resources/Web/"
bash scripts/sign-app.sh "$app" -
echo "Built: $PWD/$app"
