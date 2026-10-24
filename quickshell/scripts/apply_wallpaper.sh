#!/usr/bin/env bash
set -e

TARGET="$1"
TRANSITION="${2:-simple}"
POSTER_ARG="$3"

ASSETS_DIR="$HOME/.local/share/Steam/steamapps/common/wallpaper_engine/assets"
STATE_FILE="$HOME/.config/active-wallpaper-engine"
POSTER_DIR="$HOME/.cache/wallpaper-engine-posters"
WE_THUMBS="$HOME/.cache/skwd-wall-v2/we-thumbs"
PRIMARY_OUTPUT="eDP-1"

if [ -z "$TARGET" ]; then
    exit 1
fi

is_we=false
ITEM_DIR=""
WE_ID=""

if [ -d "$TARGET" ] && [ -f "$TARGET/project.json" ]; then
    is_we=true
    ITEM_DIR="$TARGET"
    WE_ID="$(basename "$TARGET")"
elif [[ "$TARGET" =~ ^[0-9]+$ ]]; then
    CANDIDATE="$HOME/.local/share/Steam/steamapps/workshop/content/431960/$TARGET"
    if [ -d "$CANDIDATE" ] && [ -f "$CANDIDATE/project.json" ]; then
        is_we=true
        ITEM_DIR="$CANDIDATE"
        WE_ID="$TARGET"
    fi
elif [ -f "$TARGET" ]; then
    PARENT_DIR="$(dirname "$TARGET")"
    if [ -f "$PARENT_DIR/project.json" ]; then
        is_we=true
        ITEM_DIR="$PARENT_DIR"
        WE_ID="$(basename "$PARENT_DIR")"
    fi
fi

ensure_awww() {
    if ! pgrep -x awww-daemon >/dev/null 2>&1; then
        awww-daemon &
        for i in {1..30}; do
            awww query >/dev/null 2>&1 && break
            sleep 0.1
        done
    fi
}

if [ "$is_we" = true ]; then
    killall -9 linux-wallpaperengine 2>/dev/null || true
    echo "$ITEM_DIR" > "$STATE_FILE"

    # 1. Resolve Best High-Resolution Poster
    HQ_POSTER=""
    if [ -n "$POSTER_ARG" ] && [ -f "$POSTER_ARG" ]; then
        HQ_POSTER="$POSTER_ARG"
    elif [ -n "$WE_ID" ] && [ -f "$POSTER_DIR/$WE_ID.png" ]; then
        HQ_POSTER="$POSTER_DIR/$WE_ID.png"
    elif [ -f "$ITEM_DIR/preview.jpg" ]; then
        HQ_POSTER="$ITEM_DIR/preview.jpg"
    elif [ -f "$ITEM_DIR/preview.png" ]; then
        HQ_POSTER="$ITEM_DIR/preview.png"
    elif [ -n "$WE_ID" ] && [ -f "$WE_THUMBS/$WE_ID.webp" ]; then
        HQ_POSTER="$WE_THUMBS/$WE_ID.webp"
    fi

    # 2. Present Crisp High-Res Poster to AWWW (zero black screen, instant smooth transition)
    if [ -n "$HQ_POSTER" ] && [ -f "$HQ_POSTER" ]; then
        mkdir -p "$HOME/.config/active-theme"
        ln -sf "$HQ_POSTER" "$HOME/.config/active-theme/current-wallpaper" 2>/dev/null || true
        echo "$HQ_POSTER" > "$HOME/.config/active-theme/current-wallpaper.txt" 2>/dev/null || true

        ensure_awww
        awww img "$HQ_POSTER" \
            --transition-type "$TRANSITION" \
            --transition-fps 144 \
            --transition-step 240 \
            --transition-bezier 0.25,0.1,0.25,1.0 || true
    fi

    # 3. Launch Wallpaper Engine (OpenGL / EGL layer-shell with nohup and disown)
    nohup linux-wallpaperengine \
        --assets-dir "$ASSETS_DIR" \
        --screen-root "$PRIMARY_OUTPUT" \
        --silent \
        --fps 60 \
        "$ITEM_DIR" </dev/null >/tmp/wallpaper-engine.log 2>&1 &
    WE_PID=$!
    disown "$WE_PID" 2>/dev/null || true

    # Check if process launched successfully or exited due to unsupported shaders
    sleep 0.5
    if kill -0 "$WE_PID" 2>/dev/null; then
        echo "linux-wallpaperengine (PID $WE_PID) running successfully for $ITEM_DIR" >> /tmp/wallpaper-engine.log
    else
        echo "linux-wallpaperengine exited; high-resolution poster preserved on screen." >> /tmp/wallpaper-engine.log
    fi
else
    killall -9 linux-wallpaperengine 2>/dev/null || true
    rm -f "$STATE_FILE" 2>/dev/null || true

    mkdir -p "$HOME/.config/active-theme"
    ln -sf "$TARGET" "$HOME/.config/active-theme/current-wallpaper" 2>/dev/null || true
    echo "$TARGET" > "$HOME/.config/active-theme/current-wallpaper.txt" 2>/dev/null || true

    ensure_awww
    awww img "$TARGET" \
        --transition-type "$TRANSITION" \
        --transition-fps 144 \
        --transition-step 240 \
        --transition-bezier 0.25,0.1,0.25,1.0
fi
