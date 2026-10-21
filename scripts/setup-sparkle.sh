#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=2.10.0
checksum=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
archive=".build/Sparkle-$version.tar.xz"
if [ -f .build/sparkle/.version ] && [ "$(cat .build/sparkle/.version)" = "$version" ]; then exit 0; fi
mkdir -p .build/sparkle
curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" -o "$archive"
printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c -
tar -xJf "$archive" -C .build/sparkle
printf '%s' "$version" > .build/sparkle/.version
