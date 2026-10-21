#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool Keychain profile}"
: "${SPARKLE_KEY_FILE:?Set SPARKLE_KEY_FILE to the Sparkle EdDSA private key file}"

# Check credentials before rebuilding. Passwords remain in the Keychain.
notary_options=(--keychain-profile "$NOTARY_PROFILE")
if [ -n "${NOTARY_KEYCHAIN:-}" ]; then notary_options+=(--keychain "$NOTARY_KEYCHAIN"); fi
xcrun notarytool history "${notary_options[@]}" --output-format json >/dev/null
npm run build
python3 tests/test-release.py
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

bash scripts/sign-app.sh "$app" "$SIGNING_IDENTITY"
codesign -dvv "$app" 2>"$release/app-signature.txt"
grep -q '^Authority=Developer ID Application:' "$release/app-signature.txt"
grep -q 'flags=.*runtime' "$release/app-signature.txt"

notarize() {
  local artifact="$1" result="$2"
  xcrun notarytool submit "$artifact" "${notary_options[@]}" \
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
bash scripts/staple.sh "$app"
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
bash scripts/staple.sh "$dmg"
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

# Keep update archives separate from the pre-stapling notarization ZIP.
updates="$release/updates"
mkdir -p "$updates"
cp "$dmg" "$updates/"
.build/sparkle/bin/generate_appcast --ed-key-file "$SPARKLE_KEY_FILE" \
  --download-url-prefix "https://github.com/jihyukboin/super-docs/releases/download/v$version/" \
  --link https://github.com/jihyukboin/super-docs --maximum-deltas 0 "$updates"
cp "$updates/appcast.xml" "$release/appcast.xml"
python3 scripts/verify-appcast.py "$release/appcast.xml" "$dmg" "$version"
signature=$(python3 - "$release/appcast.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
print(ET.parse(sys.argv[1]).find('./channel/item/enclosure').get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature'))
PY
)
.build/sparkle/bin/sign_update --verify --ed-key-file "$SPARKLE_KEY_FILE" "$dmg" "$signature"
