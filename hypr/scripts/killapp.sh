#!/usr/bin/env bash

# Get the PID of the active window
PID=$(hyprctl activewindow -j | jq -r '.pid // empty')

# Check if PID is a valid number
if [[ "$PID" =~ ^[0-9]+$ ]]; then
  # kill -9 (SIGKILL) forces the process to exit immediately
  # and bypasses any "minimize to tray" logic.
  kill -9 "$PID"
else
  # Optional: Send a notification if no window is active
  notify-send "Hyprland" "No active window found to kill." -i error
fi
