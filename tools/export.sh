#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p builds/windows builds/android
godot --headless --path . --export-release Windows builds/windows/AstralForge.exe
godot --headless --path . --export-debug Android builds/android/AstralForge-debug.apk
