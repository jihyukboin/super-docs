#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${APP_VERSION:?APP_VERSION is required}"
: "${RELEASE_SHA:?RELEASE_SHA is required}"
tag="v$APP_VERSION"
release="dist/release/$APP_VERSION"
files=("$release/Super-Docs-$APP_VERSION-arm64.dmg" "$release/Super-Docs-$APP_VERSION-arm64.dmg.sha256" "$release/appcast.xml")
if gh release view "$tag" --json isDraft >.build/existing-release.json 2>/dev/null; then
  python3 - <<'PY'
import json
assert json.load(open('.build/existing-release.json'))['isDraft'], 'Never overwrite published releases'
PY
  gh release upload "$tag" "${files[@]}" --clobber
else
  gh release create "$tag" "${files[@]}" --draft --target "$RELEASE_SHA" \
    --title "Super Docs $APP_VERSION" --generate-notes
fi
gh release edit "$tag" --draft=false --latest

# Verify public, unauthenticated URLs instead of only trusting an upload response.
mkdir -p .build/published
base="https://github.com/jihyukboin/super-docs/releases/download/$tag"
curl -fLsS --retry 3 "$base/Super-Docs-$APP_VERSION-arm64.dmg" -o ".build/published/Super-Docs-$APP_VERSION-arm64.dmg"
curl -fLsS --retry 3 "$base/appcast.xml" -o .build/published/appcast.xml
cmp "$release/appcast.xml" .build/published/appcast.xml
cmp "$release/Super-Docs-$APP_VERSION-arm64.dmg" ".build/published/Super-Docs-$APP_VERSION-arm64.dmg"
python3 scripts/verify-appcast.py .build/published/appcast.xml ".build/published/Super-Docs-$APP_VERSION-arm64.dmg" "$APP_VERSION"
echo "Published https://github.com/jihyukboin/super-docs/releases/tag/$tag"
