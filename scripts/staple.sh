#!/bin/bash
set -euo pipefail
artifact="${1:?Usage: staple.sh APP_OR_DMG}"
mode="${2:-staple}"
if [ "$mode" != staple ] && [ "$mode" != validate ]; then exit 64; fi
ticket_operation() {
  local action="$1" status attempt
  for attempt in 1 2 3 4 5; do
    if xcrun stapler "$action" "$artifact"; then return 0; else status=$?; fi
    # Both staple and validate query Apple's CloudKit ticket service.
    if { [ "$status" != 65 ] && [ "$status" != 68 ]; } || [ "$attempt" = 5 ]; then
      return "$status"
    fi
    echo "Apple ticket $action unavailable (status $status); retrying ($attempt/5)..." >&2
    sleep "$((attempt * 5))"
  done
}
if [ "$mode" = staple ]; then ticket_operation staple; fi
ticket_operation validate
