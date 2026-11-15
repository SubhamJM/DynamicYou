#!/usr/bin/env bash

# Resolve real script directory (resolving symlinks such as ~/.local/bin/lock-screen.sh)
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Set library and import paths
export QML_IMPORT_PATH="$DIR/imports:$QML_IMPORT_PATH"
export QML2_IMPORT_PATH="$DIR/imports:$QML2_IMPORT_PATH"
export QML_XHR_ALLOW_FILE_READ=1

# Wayland environment
export XDG_SESSION_TYPE="wayland"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

# Prevent multiple lockscreen instances & allow Hyprland restore
if command -v hyprctl &>/dev/null; then
    hyprctl keyword misc:allow_session_lock_restore 1 2>/dev/null || true
fi

# Kill any lingering previous lockscreen quickshell process (safely without touching qs notch bar)
pkill -9 -f "quickshell.*lock_shell\.qml" 2>/dev/null || true
killall -9 hyprlock swaylock wlogout 2>/dev/null || true

# User theme preference
CONFIG_FILE="$HOME/.config/qylock/theme"
if [ -n "$1" ]; then
    export QS_THEME="$1"
elif [ -f "$CONFIG_FILE" ]; then
    export QS_THEME="$(cat "$CONFIG_FILE" | tr -d '[:space:]')"
else
    export QS_THEME="dog-samurai"
fi

if [ -z "$QS_THEME" ]; then
    export QS_THEME="dog-samurai"
fi

export QS_THEMES_DIR="$DIR/themes"
export QS_THEME_PATH="$DIR/themes/$QS_THEME"

# Small settle to ensure wayland socket is clear
sleep 0.05

# Execute lock
exec quickshell --no-duplicate -p "$DIR/lock_shell.qml"
