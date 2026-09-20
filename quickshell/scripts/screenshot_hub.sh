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

# Send notification / notify Quickshell
# Non-blocking write to /tmp/notch_mode FIFO
python3 -c "
import os
try:
    p = '/tmp/notch_mode'
    if os.path.exists(p):
        fd = os.open(p, os.O_WRONLY | os.O_NONBLOCK)
        os.write(fd, f'screenshot {FILE}\n'.encode())
        os.close(fd)
except Exception:
    pass
"

# Desktop notification fallback with icon preview
notify-send -a "Screenshot Hub" -i "$FILE" "Screenshot Captured" "Saved to Screenshots. Click notch action to Annotate, Pin to Shelf, or OCR."
