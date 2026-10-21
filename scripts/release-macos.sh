#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool Keychain profile}"

# Check credentials before rebuilding. Passwords remain in the Keychain.
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json >/dev/null
npm run build
npm test
bash scripts/test-native.sh

app="$PWD/dist/Super Docs.app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
release="$PWD/dist/release/$version"
mkdir -p "$release"
stage=$(mktemp -d "$PWD/.build/dmg-stage.XXXXXX")
mountpoint=""
cleanup() {
  if [ -n "$mountpoint" ]; then hdiutil detach "$mountpoint" >/dev/null || true; fi
  rm -rf "$stage"
}
trap cleanup EXIT

codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$app"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -dvv "$app" 2>"$release/app-signature.txt"
grep -q '^Authority=Developer ID Application:' "$release/app-signature.txt"
grep -q 'flags=.*runtime' "$release/app-signature.txt"

notarize() {
  local artifact="$1" result="$2"
  xcrun notarytool submit "$artifact" --keychain-profile "$NOTARY_PROFILE" \
    --wait --timeout 30m --output-format json >"$result"
  python3 - "$result" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
print('Notarization:', result.get('id'), result.get('status'))
if result.get('status') != 'Accepted':
    raise SystemExit('Apple did not accept this artifact; inspect the submission with notarytool log.')
PY
}

archive="$release/Super-Docs-$version-arm64.zip"
ditto -c -k --keepParent "$app" "$archive"
notarize "$archive" "$release/app-notarization.json"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

ditto "$app" "$stage/Super Docs.app"
ln -s /Applications "$stage/Applications"
cp LICENSE "$stage/LICENSE.txt"
cp Resources/THIRD_PARTY_NOTICES.txt "$stage/THIRD_PARTY_NOTICES.txt"
printf 'Super Docs를 Applications 폴더로 드래그하여 설치하세요.\nApple Silicon Mac · macOS 14 이상\n' >"$stage/설치 안내.txt"
dmg="$release/Super-Docs-$version-arm64.dmg"
hdiutil create -volname 'Super Docs' -srcfolder "$stage" -format UDZO -ov "$dmg"
codesign --sign "$SIGNING_IDENTITY" --timestamp "$dmg"
notarize "$dmg" "$release/dmg-notarization.json"
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
codesign --verify --strict --verbose=2 "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
hdiutil verify "$dmg"

mountpoint="$stage/mounted"
mkdir "$mountpoint"
hdiutil attach -readonly -nobrowse -mountpoint "$mountpoint" "$dmg"
codesign --verify --deep --strict --verbose=2 "$mountpoint/Super Docs.app"
xcrun stapler validate "$mountpoint/Super Docs.app"
spctl --assess --type execute --verbose=2 "$mountpoint/Super Docs.app"
hdiutil detach "$mountpoint"
mountpoint=""
(
  cd "$release"
  shasum -a 256 "$(basename "$dmg")" >"$(basename "$dmg").sha256"
)
echo "Ready for distribution: $dmg"
