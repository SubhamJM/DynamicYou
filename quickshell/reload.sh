#!/bin/bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    HYPR_SIG=$(ls -t /run/user/$(id -u)/hypr 2>/dev/null | head -n1)
    [ -n "$HYPR_SIG" ] && export HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG"
fi

killall -9 qs quickshell 2>/dev/null
while pgrep -x qs >/dev/null || pgrep -x quickshell >/dev/null; do sleep 0.05; done
sleep 0.15
qs -d >/dev/null 2>&1
