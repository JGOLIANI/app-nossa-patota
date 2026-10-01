#!/usr/bin/env bash
set -euo pipefail
export PUB_CACHE="${PUB_CACHE:-/workspace/.cache/pub}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.cache/config}"
export ANALYZER_STATE_LOCATION_OVERRIDE="${ANALYZER_STATE_LOCATION_OVERRIDE:-/workspace/.cache/dart-analyzer}"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-/workspace/.cache/android-user}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/workspace/.cache/gradle}"
export FLUTTER_SUPPRESS_ANALYTICS=true
export DASH__SUPPRESS_ANALYTICS=true
if [[ -x /workspace/tools/jdk/bin/javac ]]; then
  export JAVA_HOME="${JAVA_HOME:-/workspace/tools/jdk}"
fi
if [[ -d /workspace/tools/android-sdk ]]; then
  export ANDROID_HOME="${ANDROID_HOME:-/workspace/tools/android-sdk}"
fi
PATOTA_FLUTTER_SDK="${PATOTA_FLUTTER_SDK:-/workspace/tools/flutter}"
if [[ -x "$PATOTA_FLUTTER_SDK/bin/flutter" ]]; then
  exec "$PATOTA_FLUTTER_SDK/bin/flutter" "$@"
fi
exec flutter "$@"
