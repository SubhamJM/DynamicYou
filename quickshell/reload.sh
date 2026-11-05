#!/usr/bin/env bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    HYPR_SIG=$(ls -t /run/user/$(id -u)/hypr 2>/dev/null | head -n1)
    [ -n "$HYPR_SIG" ] && export HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG"
fi

export MALLOC_ARENA_MAX=2
export MALLOC_TRIM_THRESHOLD_=131072

pkill -9 -f quickshell 2>/dev/null
pkill -9 -x qs 2>/dev/null
while pgrep -f quickshell >/dev/null || pgrep -x qs >/dev/null; do sleep 0.05; done
sleep 0.15
qs -d >/dev/null 2>&1
