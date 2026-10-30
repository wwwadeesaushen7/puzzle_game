# Source this file in the prepared Codex cloud machine; ordinary players do not need it.
export XDG_CONFIG_HOME=/workspace/.config
export XDG_DATA_HOME=/workspace/.godot-user
export XDG_CACHE_HOME=/workspace/.cache
export ANDROID_USER_HOME=/workspace/toolchain/android-user
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$ANDROID_USER_HOME"
