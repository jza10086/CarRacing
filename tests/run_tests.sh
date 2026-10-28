#!/usr/bin/env bash
set -euo pipefail
# GODOT_BIN may point at a specific Godot 4.x executable.
GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/ridgeline-tests.XXXXXX")"
trap 'rm -rf "$TEST_HOME"' EXIT
export XDG_DATA_HOME="$TEST_HOME/data" XDG_CONFIG_HOME="$TEST_HOME/config" XDG_CACHE_HOME="$TEST_HOME/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
run_checked() {
  local log="$TEST_HOME/check.log"
  "$GODOT_BIN" --headless --path "$PROJECT" "$@" 2>&1 | tee "$log"
  if grep -Eq '^(SCRIPT ERROR|ERROR):' "$log"; then
    echo "Godot reported a runtime/import error" >&2
    return 1
  fi
}
run_checked --editor --import
run_checked --script res://tests/test_rules.gd
run_checked --script res://tests/test_car.gd

run_checked --script res://tests/test_kart.gd

run_checked --script res://tests/test_track.gd
