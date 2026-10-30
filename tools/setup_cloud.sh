#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/cloud_env.sh
godot --version
blender --version
godot --headless --path . --import
python3 tools/configure_imports.py
godot --headless --path . --import
bash tools/test.sh
