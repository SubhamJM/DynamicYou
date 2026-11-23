#!/usr/bin/env bash
if command -v hyprlock >/dev/null; then
    exec hyprlock
fi
notify-send 'Dynamic You' 'Lock screen requires hyprlock.'
exit 1
