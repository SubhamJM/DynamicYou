#!/bin/bash
# Initialize awww daemon and ensure desktop wallpaper is displayed on startup

# 1. Start awww-daemon if not already running
if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon &
fi

# 2. Wait for awww daemon socket to be ready (up to 3 seconds)
for i in {1..30}; do
    if awww query >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

ACTIVE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/active-theme"

# 3. Read active transition
TRANSITION="simple"
if [ -f "$ACTIVE_DIR/wallpaper-transition.txt" ]; then
    TRANSITION=$(cat "$ACTIVE_DIR/wallpaper-transition.txt" | tr -d '\n\r ')
fi
[ -z "$TRANSITION" ] && TRANSITION="simple"
if [ "$TRANSITION" = "random" ]; then
    TRANSITIONS=("simple" "fade" "left" "right" "top" "bottom" "wipe" "wave" "outer")
    TRANSITION=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}
fi

# 4. Check for Wallpaper Engine state
WE_STATE="$HOME/.config/active-wallpaper-engine"
if [ -f "$WE_STATE" ] && [ -s "$WE_STATE" ]; then
    WE_DIR=$(cat "$WE_STATE" | tr -d '\n\r ')
    if [ -d "$WE_DIR" ] && [ -f "$WE_DIR/project.json" ]; then
        for we_script in "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/scripts/apply_wallpaper.sh"; do
            if [ -x "$we_script" ] || [ -f "$we_script" ]; then
                bash "$we_script" "$WE_DIR" "$TRANSITION" &
                exit 0
            fi
        done
    fi
fi

# 5. Determine active wallpaper file
WALLPAPER=""
if [ -f "$ACTIVE_DIR/current-wallpaper" ]; then
    TARGET=$(readlink -f "$ACTIVE_DIR/current-wallpaper" 2>/dev/null)
    if [ -n "$TARGET" ] && [ -f "$TARGET" ]; then
        WALLPAPER="$TARGET"
    fi
fi

if [ -z "$WALLPAPER" ] && [ -f "$ACTIVE_DIR/current-wallpaper.txt" ]; then
    TARGET=$(cat "$ACTIVE_DIR/current-wallpaper.txt" | tr -d '\n\r ')
    if [ -n "$TARGET" ] && [ -f "$TARGET" ]; then
        WALLPAPER="$TARGET"
    fi
fi

# Use the same wallpaper and palette path for startup and the picker.
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
WALLPAPER_SCRIPT="$CONFIG_DIR/quickshell/scripts/apply_wallpaper.sh"
if [[ -z "$WALLPAPER" ]]; then
    WALLPAPER=$(find -L "$HOME/Pictures/Wallpapers" -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print -quit 2>/dev/null)
fi
if [[ -n "$WALLPAPER" ]]; then
    bash "$WALLPAPER_SCRIPT" "$WALLPAPER" "$TRANSITION"
fi
