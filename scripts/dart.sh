#!/usr/bin/env bash
set -euo pipefail
export PUB_CACHE="${PUB_CACHE:-/workspace/.cache/pub}"
export ANALYZER_STATE_LOCATION_OVERRIDE="${ANALYZER_STATE_LOCATION_OVERRIDE:-/workspace/.cache/dart-analyzer}"
export DASH__SUPPRESS_ANALYTICS=true
PATOTA_FLUTTER_SDK="${PATOTA_FLUTTER_SDK:-/workspace/tools/flutter}"
if [[ -x "$PATOTA_FLUTTER_SDK/bin/cache/dart-sdk/bin/dart" ]]; then
  exec "$PATOTA_FLUTTER_SDK/bin/cache/dart-sdk/bin/dart" "$@"
fi
exec dart "$@"
