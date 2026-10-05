#!/usr/bin/env bash
# Screenshot Annotation Hub Trigger
# Takes an area screenshot via slurp + grim, saves to ~/Pictures/Screenshots,
# copies to clipboard, and triggers the Quickshell Dynamic Island hub.

mkdir -p "$HOME/Pictures/Screenshots"
FILE="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y%m%d_%H%M%S).png"

# Slurp area selection (redirect stdin from /dev/null to avoid blocking pipe)
GEOM=$(slurp < /dev/null 2>/dev/null)
if [ -z "$GEOM" ]; then
    exit 0
fi

# Give slurp overlay a brief moment to unmap completely
sleep 0.1

# Capture selected region
grim -g "$GEOM" "$FILE"
if [ ! -f "$FILE" ]; then
    exit 1
fi

# Copy image bytes to system clipboard
wl-copy < "$FILE"

# Direct native Quickshell IPC trigger (zero Python FIFO overhead)
qs ipc call notch showScreenshot "$FILE" >/dev/null 2>&1 &

notify-send -a "Screenshot Hub" -i "$FILE" "Screenshot Captured" "Saved to Screenshots. Click notch action to Annotate."
