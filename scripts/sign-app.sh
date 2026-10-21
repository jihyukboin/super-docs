#!/bin/bash
set -euo pipefail
app="${1:?Usage: sign-app.sh APP IDENTITY}"
identity="${2:?Usage: sign-app.sh APP IDENTITY}"
flags=(--force --sign "$identity")
if [ "$identity" != - ]; then flags+=(--options runtime --timestamp); fi
framework="$app/Contents/Frameworks/Sparkle.framework"
# Sign inside-out; Downloader's sandbox entitlements must be preserved.
codesign "${flags[@]}" "$framework/Versions/B/XPCServices/Installer.xpc"
codesign "${flags[@]}" --preserve-metadata=entitlements "$framework/Versions/B/XPCServices/Downloader.xpc"
codesign "${flags[@]}" "$framework/Versions/B/Autoupdate"
codesign "${flags[@]}" "$framework/Versions/B/Updater.app"
codesign "${flags[@]}" "$framework"
codesign "${flags[@]}" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
