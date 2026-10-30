#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
renderer="${ASTRAL_RENDERER:-gl_compatibility}"
exec godot --path . --rendering-method "$renderer" "$@"
