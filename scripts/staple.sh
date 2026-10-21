#!/bin/bash
set -euo pipefail
artifact="${1:?Usage: staple.sh APP_OR_DMG}"
for attempt in 1 2 3 4 5; do
  if xcrun stapler staple "$artifact"; then exit 0; else status=$?; fi
  # Retry CloudKit/network failures, never malformed or revoked tickets.
  if [ "$status" != 68 ] || [ "$attempt" = 5 ]; then exit "$status"; fi
  echo "Apple ticket service unavailable (status $status); retrying ($attempt/5)..." >&2
  sleep "$((attempt * 5))"
done
