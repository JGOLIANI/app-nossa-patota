#!/usr/bin/env bash
set -euo pipefail
PATOTA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATOTA_PG_TOOLS="${PATOTA_PG_TOOLS:-/workspace/tools/postgres}"
export npm_config_cache="${npm_config_cache:-/workspace/.cache/npm}"
mkdir -p "$PATOTA_PG_TOOLS"
npm install --prefix "$PATOTA_PG_TOOLS" --ignore-scripts --no-audit --no-fund \
  @embedded-postgres/linux-x64@16.14.0-beta.17 pg@8.16.3
(
  cd "$PATOTA_PG_TOOLS/node_modules/@embedded-postgres/linux-x64"
  node scripts/hydrate-symlinks.js
)
node "$PATOTA_ROOT/supabase/tests/database_test.mjs"
