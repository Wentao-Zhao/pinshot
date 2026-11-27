#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
module_cache="$PWD/.build/clang-module-cache"
mkdir -p "$module_cache"
compiler_args=(-target "$(uname -m)-apple-macos13" -module-cache-path "$module_cache")
swiftc "${compiler_args[@]}" -module-name PinShotCore -emit-module -emit-library -static \
  -o "$build_dir/libPinShotCore.a" Sources/PinShotCore/*.swift
sources=(Sources/PinShot/*.swift)
sources=(${sources:#*/PinShotApp.swift})
sources=(${sources:#*/AppUpdater.swift})
sources=(${sources:#*/StatusItemController.swift})
sources=(${sources:#*/PasteboardWriter.swift})
swiftc "${compiler_args[@]}" -I "$build_dir" -L "$build_dir" -lPinShotCore \
  -o "$build_dir/PinShotAppTests" "${sources[@]}" Tests/PinShotAppTests/*.swift
"$build_dir/PinShotAppTests" | tee "$build_dir/results"
rg -q '^PASS: [0-9]+ AppKit interaction checks$' "$build_dir/results"
