#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_root="$(mktemp -d /tmp/astral-tests.XXXXXX)"
export XDG_DATA_HOME="$test_root/data"
export XDG_CONFIG_HOME="$test_root/config"
export XDG_CACHE_HOME="$test_root/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --path . --import
godot --headless --path . --script tests/test_rules.gd
godot --headless --path . --script tests/test_progress.gd
if [[ "${1:-}" == "--render" ]]; then
  godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script tests/test_scene.gd -- --capture
else
  godot --headless --path . --audio-driver Dummy --script tests/test_scene.gd
fi
