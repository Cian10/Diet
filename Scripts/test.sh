#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

mkdir -p .tooling-home/module-cache .tooling-home/swiftpm-cache
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.tooling-home/module-cache"
export SWIFT_MODULECACHE_PATH="$ROOT_DIR/.tooling-home/module-cache"

SCRATCH_PATH="$ROOT_DIR/.build-native"
EXTRA_ARGS=()
if [[ "${1:-}" == "--swiftdata" ]]; then
  SCRATCH_PATH="$ROOT_DIR/.build-native-swiftdata"
  EXTRA_ARGS=(-Xswiftc -DDIETAPP_SWIFTDATA)
elif [[ $# -gt 0 ]]; then
  echo "用法：./Scripts/test.sh [--swiftdata]" >&2
  exit 2
fi

swift test \
  --build-system native \
  --disable-sandbox \
  --cache-path "$ROOT_DIR/.tooling-home/swiftpm-cache" \
  --scratch-path "$SCRATCH_PATH" \
  "${EXTRA_ARGS[@]}"
