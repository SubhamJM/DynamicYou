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

ACTIVE_DIR="$HOME/.config/active-theme"

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
        for we_script in "$HOME/.config/quickshell/scripts/apply_wallpaper.sh" "$HOME/git/MyLinuxSetup/quickshell/scripts/apply_wallpaper.sh"; do
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

# 6. Apply wallpaper if found
if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    awww img "$WALLPAPER" \
        --transition-type "$TRANSITION" \
        --transition-fps 144 \
        --transition-step 240 \
        --transition-bezier "0.25,0.1,0.25,1.0"
else
    # First boot or missing wallpaper: determine active theme and apply it
    THEME="Serenity"
    if [ -f "$ACTIVE_DIR/theme-name.txt" ]; then
        THEME=$(cat "$ACTIVE_DIR/theme-name.txt" | tr -d '\n\r ')
    fi
    [ -z "$THEME" ] && THEME="Serenity"

    for s in "$HOME/.local/bin/apply-theme.sh" "$HOME/.config/scripts/apply-theme.sh" "$HOME/git/MyLinuxSetup/scripts/apply-theme.sh"; do
        if [ -x "$s" ] || [ -f "$s" ]; then
            bash "$s" "$THEME"
            break
        fi
    done
fi
