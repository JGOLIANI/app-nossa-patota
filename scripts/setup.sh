#!/usr/bin/env bash
set -euo pipefail
PATOTA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATOTA_FLUTTER_SDK="${PATOTA_FLUTTER_SDK:-/workspace/tools/flutter}"
PATOTA_FLUTTER_VERSION="$(cat "$PATOTA_ROOT/.flutter-version")"
if [[ ! -x "$PATOTA_FLUTTER_SDK/bin/flutter" ]] && ! command -v flutter >/dev/null; then
  mkdir -p "$(dirname "$PATOTA_FLUTTER_SDK")"
  git clone --depth 1 --branch "$PATOTA_FLUTTER_VERSION" https://github.com/flutter/flutter.git "$PATOTA_FLUTTER_SDK"
fi
cd "$PATOTA_ROOT"
python3 scripts/configure-gradle-proxy.py
bash scripts/flutter.sh --version
bash scripts/flutter.sh pub get --enforce-lockfile
