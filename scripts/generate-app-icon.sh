#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
ICONSET_DIR="$ROOT_DIR/Resources/AppIcon.iconset"
OUTPUT="$ROOT_DIR/Resources/AppIcon.icns"

mkdir -p "$BUILD_DIR"

SDK_ARGS=()
if [[ -n "${PINSHOT_SDK:-}" ]]; then
    SDK_ARGS=(-sdk "$PINSHOT_SDK")
fi

swiftc "${SDK_ARGS[@]}" \
    -module-cache-path "$BUILD_DIR/icon-module-cache" \
    "$ROOT_DIR/scripts/generate-app-icon.swift" \
    -o "$BUILD_DIR/generate-pinshot-app-icon"

"$BUILD_DIR/generate-pinshot-app-icon"
echo "Created: $OUTPUT"
