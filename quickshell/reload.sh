#!/bin/bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    HYPR_SIG=$(ls -t /run/user/$(id -u)/hypr 2>/dev/null | head -n1)
    [ -n "$HYPR_SIG" ] && export HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG"
fi

quickshell kill 2>/dev/null
pkill -9 quickshell 2>/dev/null
pkill -9 qs 2>/dev/null
while pgrep -x quickshell >/dev/null || pgrep -x qs >/dev/null; do sleep 0.05; done
sleep 0.1
hyprctl dispatch "hl.dsp.exec_cmd('quickshell')" >/dev/null 2>&1 || setsid quickshell >/dev/null 2>&1 &

