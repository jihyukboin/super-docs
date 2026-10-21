#!/bin/bash
set -euo pipefail
artifact="${1:?Usage: staple.sh APP_OR_DMG}"
for attempt in 1 2 3 4 5; do
  if xcrun stapler staple "$artifact"; then
    xcrun stapler validate "$artifact"
    exit 0
  else
    status=$?
  fi
  # Apple ticket propagation (65) and CloudKit/network failures (68).
  if { [ "$status" != 65 ] && [ "$status" != 68 ]; } || [ "$attempt" = 5 ]; then
    exit "$status"
  fi
  echo "Apple ticket unavailable (status $status); retrying ($attempt/5)..." >&2
  sleep "$((attempt * 5))"
done
