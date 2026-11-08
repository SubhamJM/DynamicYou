#!/usr/bin/env bash

# 1. Define explicit paths
WAYVIBES_EXEC="/usr/bin/wayvibes"
SOUNDPACK="$HOME/Applications/wayvibes/soundpacks/akko_lavender_purples/"

# 2. Kill any existing instances
pkill -x wayvibes

# 3. Give PipeWire and Hyprland a moment to fully initialize on startup
sleep 4

# 4. Start wayvibes in the background
env PIPEWIRE_LATENCY="128/48000" "$WAYVIBES_EXEC" -v 0.15 "$SOUNDPACK" -bg &
