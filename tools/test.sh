#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_root="$(mktemp -d /tmp/astral-tests.XXXXXX)"
export XDG_DATA_HOME="$test_root/data"
export XDG_CONFIG_HOME="$test_root/config"
export XDG_CACHE_HOME="$test_root/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --path . --import
run_check() {
  local suite="$1"
  shift
  "$@" 2>&1 | tee "$test_root/$suite.log"
  grep -Eq "^$suite: [1-9][0-9]* (checks|assertions), 0 failures$" "$test_root/$suite.log"
  if grep -Eq 'SCRIPT ERROR:|ERROR:' "$test_root/$suite.log"; then return 1; fi
}
run_check RULES godot --headless --path . --script tests/test_rules.gd
run_check PROGRESS godot --headless --path . --script tests/test_progress.gd
if [[ "${1:-}" == "--render" ]]; then
  run_check SCENE godot --path . --fixed-fps "${ASTRAL_TEST_FIXED_FPS:-30}" --rendering-method gl_compatibility --audio-driver Dummy --script tests/test_scene.gd -- --capture
  run_check TOUCH godot --path . --fixed-fps "${ASTRAL_TEST_FIXED_FPS:-30}" --rendering-method gl_compatibility --audio-driver Dummy --script tests/test_touch.gd -- --capture
else
  run_check SCENE godot --headless --path . --audio-driver Dummy --script tests/test_scene.gd
  run_check TOUCH godot --headless --path . --audio-driver Dummy --script tests/test_touch.gd
fi
