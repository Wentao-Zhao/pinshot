#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_FILE="$ROOT_DIR/.build/pinshot-startup-smoke.log"

export HOME="${HOME:-$ROOT_DIR/.swift-home}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/clang-module-cache}"
mkdir -p "$ROOT_DIR/.build" "$CLANG_MODULE_CACHE_PATH"

BUILD_ARGS=(--disable-sandbox -c release)
if [[ -n "${PINSHOT_SDK:-}" ]]; then
    BUILD_ARGS+=(--sdk "$PINSHOT_SDK")
fi

cd "$ROOT_DIR"
swift build "${BUILD_ARGS[@]}" >/dev/null
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

rm -f "$OUTPUT_FILE"
PINSHOT_LIFECYCLE_SMOKE_TEST=1 "$BIN_DIR/PinShot" >"$OUTPUT_FILE" 2>&1 &
PID=$!

for _ in {1..30}; do
    if ! kill -0 "$PID" 2>/dev/null; then
        break
    fi
    sleep 0.1
done

if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
fi

if grep -q "PASS: PinShot startup smoke" "$OUTPUT_FILE"; then
    cat "$OUTPUT_FILE"
    exit 0
fi

cat "$OUTPUT_FILE" >&2
echo "FAIL: PinShot startup smoke did not observe applicationDidFinishLaunching" >&2
exit 1

