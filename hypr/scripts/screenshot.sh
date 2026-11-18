#!/usr/bin/env bash
# ==============================================================================
# DynamicYou - Robust Screenshot Handler
# Cleans stale lockfiles, manages screenshot targets, notifies & copies to clipboard
# ==============================================================================

TARGET="${1:-area}"
SAVE_DIR="${XDG_SCREENSHOTS_DIR:-${HOME}/Pictures/Screenshots}"
mkdir -p "$SAVE_DIR"
export XDG_SCREENSHOTS_DIR="$SAVE_DIR"

# 1. Auto-heal: Clean stale lockfiles if grimblast is not actively running
LOCK_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/grimblast.lock"
CACHE_LOCK="${HOME}/.cache/grimblast.lock"
if ! pgrep -x grimblast >/dev/null 2>&1; then
    rm -f "$LOCK_FILE" "$CACHE_LOCK" 2>/dev/null || true
fi

# 2. Kill any frozen hyprpicker from previous interrupted snips
if ! pgrep -x grimblast >/dev/null 2>&1 && pgrep -x hyprpicker >/dev/null 2>&1; then
    pkill -9 hyprpicker 2>/dev/null || true
fi

# 3. Handle screenshot actions
case "$TARGET" in
    screen|full)
        grimblast --notify copysave screen
        ;;
    active|window)
        grimblast --notify copysave active
        ;;
    hub)
        if [ -f "${HOME}/.config/quickshell/scripts/screenshot_hub.sh" ]; then
            bash "${HOME}/.config/quickshell/scripts/screenshot_hub.sh"
        else
            grimblast --notify copysave area
        fi
        ;;
    area|*)
        grimblast --notify copysave area
        ;;
esac
