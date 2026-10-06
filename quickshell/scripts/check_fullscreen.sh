#!/usr/bin/env bash
# Checks if there is a window in true fullscreen mode (fullscreen == 2).
# Maximized windows (fullscreen == 1, e.g. via SUPER + F) return 0 so the notch stays visible.

# 1. Direct check: is the active window in true fullscreen mode (2)?
if hyprctl activewindow -j 2>/dev/null | jq -e '(.fullscreen == 2 or .fullscreenClient == 2)' >/dev/null 2>&1; then
    echo "1"
    exit 0
fi

# 2. Workspace check: does any client on the currently active workspace have fullscreen == 2?
active_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq '.id // empty' 2>/dev/null)
if [ -n "$active_ws" ]; then
    if hyprctl clients -j 2>/dev/null | jq -e --argjson w "$active_ws" 'any(.[]; .workspace.id == $w and (.fullscreen == 2 or .fullscreenClient == 2))' >/dev/null 2>&1; then
        echo "1"
        exit 0
    fi
fi

echo "0"
