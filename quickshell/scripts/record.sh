#!/usr/bin/env bash

# Clear library overrides
unset LD_LIBRARY_PATH
unset LD_PRELOAD

STATE_DIR="$HOME/.local/state/quickshell"
STATE_FILE="$STATE_DIR/recorder-state.json"
CACHE_DIR="$HOME/.cache/quickshell/recorder_thumbs"
VIDEOS_DIR="$HOME/Videos"

mkdir -p "$STATE_DIR" "$CACHE_DIR" "$VIDEOS_DIR"

# Initialize state file if missing
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"active":false,"paused":false,"seconds":0,"file":"","last":null}' > "$STATE_FILE"
fi

get_state() {
    local key="$1"
    jq -r "$key" "$STATE_FILE" 2>/dev/null
}

set_state() {
    local filter="$1"
    local tmp="${STATE_FILE}.tmp"
    if jq "$filter" "$STATE_FILE" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$STATE_FILE"
    fi
}

start_timer() {
    (
        while pgrep -x wf-recorder > /dev/null; do
            sleep 1
            if [[ "$(get_state '.paused')" != "true" ]]; then
                set_state '.seconds = (.seconds + 1)'
            fi
        done
    ) </dev/null &>/dev/null &
    disown
}

get_active_monitor() {
    local active
    active=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
    if [[ -z "$active" || "$active" == "null" ]]; then
        active=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name' 2>/dev/null)
    fi
    echo "${active:-eDP-1}"
}

# Auto-detect best video encoder
get_encoder_opts() {
    # Test VAAPI hardware acceleration first
    if [[ -e /dev/dri/renderD128 ]] && ffmpeg -encoders 2>/dev/null | grep -q "h264_vaapi"; then
        # Check if VAAPI actually encodes without error
        if ffmpeg -y -v error -init_hw_device vaapi=va:/dev/dri/renderD128 -filter_hw_device va \
            -f lavfi -i testsrc=size=128x128:rate=1 -frames:v 1 -vf format=nv12,hwupload \
            -c:v h264_vaapi -f null - &>/dev/null; then
            echo "-c h264_vaapi -d /dev/dri/renderD128"
            return
        fi
    fi
    # Fallback to high-performance CPU x264
    echo "-c libx264 -p preset=ultrafast -p crf=22"
}

generate_last_metadata() {
    local newest
    newest=$(find "$VIDEOS_DIR" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' \) -printf '%T@\t%p\n' 2>/dev/null | sort -nr | head -n 1 | cut -f2-)
    if [[ -z "$newest" || ! -f "$newest" ]]; then
        echo 'null'
        return
    fi

    local fname
    fname=$(basename "$newest")
    local mtime
    mtime=$(stat -c %Y "$newest" 2>/dev/null || echo 0)
    local size
    size=$(stat -c %s "$newest" 2>/dev/null || echo 0)
    local hash
    hash=$(printf '%s:%s' "$newest" "$mtime" | md5sum | cut -c1-16)
    local thumb="$CACHE_DIR/${hash}.jpg"

    if [[ ! -s "$thumb" ]]; then
        ffmpeg -y -v error -ss 00:00:01 -i "$newest" -vframes 1 -vf "scale=320:-1" -q:v 3 "$thumb" &>/dev/null || rm -f "$thumb"
    fi

    local dur
    dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$newest" 2>/dev/null | cut -d'.' -f1)
    dur=${dur:-0}

    jq -n \
        --arg path "$newest" \
        --arg name "$fname" \
        --arg thumb "$thumb" \
        --argjson duration "$dur" \
        --argjson size "$size" \
        --argjson mtime "$mtime" \
        '{path: $path, name: $name, thumb: $thumb, duration: $duration, size: $size, mtime: $mtime}'
}

# ── Action Dispatcher ────────────────────────────────────────────────────────

case "$1" in
    --status)
        if pgrep -x wf-recorder > /dev/null; then
            jq '.active = true' "$STATE_FILE"
        else
            set_state '.active = false | .paused = false | .seconds = 0'
            jq '.' "$STATE_FILE"
        fi
        exit 0
        ;;

    --last)
        generate_last_metadata
        exit 0
        ;;

    --pause)
        if pgrep -x wf-recorder > /dev/null; then
            if [[ "$(get_state '.paused')" == "true" ]]; then
                pkill -CONT -x wf-recorder
                set_state '.paused = false'
                notify-send "Recording Resumed" "Screen capture is continuing" -a 'Screen Recorder' -i media-playback-start
            else
                pkill -STOP -x wf-recorder
                set_state '.paused = true'
                notify-send "Recording Paused" "Screen capture is currently paused" -a 'Screen Recorder' -i media-playback-pause
            fi
        fi
        exit 0
        ;;

    --stop)
        if pgrep -x wf-recorder > /dev/null; then
            # Ensure process is continued before sending SIGINT so it flushes
            pkill -CONT -x wf-recorder 2>/dev/null
            pkill -INT -x wf-recorder
            sleep 0.8
            # Double check termination
            if pgrep -x wf-recorder > /dev/null; then
                sleep 0.5
                pkill -KILL -x wf-recorder 2>/dev/null
            fi
        fi

        set_state '.active = false | .paused = false | .seconds = 0'
        LAST_JSON=$(generate_last_metadata)
        set_state ".last = $LAST_JSON"

        LPATH=$(echo "$LAST_JSON" | jq -r '.path // empty' 2>/dev/null)
        if [[ -n "$LPATH" && -f "$LPATH" ]]; then
            notify-send "Recording Saved" "$(basename "$LPATH")" -a 'Screen Recorder' -i video-x-generic
        fi
        exit 0
        ;;

    --screenshot-region)
        FILE="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y%m%d_%H%M%S).png"
        mkdir -p "$(dirname "$FILE")"
        GEOM=$(slurp 2>/dev/null)
        if [[ -n "$GEOM" ]]; then
            grim -g "$GEOM" "$FILE"
            wl-copy < "$FILE"
            notify-send "Screenshot Saved" "Copied region to clipboard and saved to Screenshots" -a 'Screen Recorder' -i camera-photo
        fi
        exit 0
        ;;

    --screenshot-full)
        FILE="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y%m%d_%H%M%S).png"
        mkdir -p "$(dirname "$FILE")"
        grim "$FILE"
        wl-copy < "$FILE"
        notify-send "Screenshot Saved" "Copied full screen to clipboard and saved to Screenshots" -a 'Screen Recorder' -i camera-photo
        exit 0
        ;;
esac

# If already recording and invoked without arguments, stop recording
if pgrep -x wf-recorder > /dev/null; then
    exec "$0" --stop
fi

# ── Start Recording ──────────────────────────────────────────────────────────

REGION_MODE=false
SOUND_SYS=false
SOUND_MIC=false

for arg in "$@"; do
    case "$arg" in
        --region) REGION_MODE=true ;;
        --sound) SOUND_SYS=true ;;
        --mic) SOUND_MIC=true ;;
    esac
done

OUT_FILE="$VIDEOS_DIR/recording_$(date +%Y%m%d_%H%M%S).mp4"
AUDIO_FLAGS=()

if [[ "$SOUND_SYS" == "true" || "$SOUND_MIC" == "true" ]]; then
    AUDIO_FLAGS+=("--audio-backend=pipewire" "-a")
fi

ENCODER_FLAGS=($(get_encoder_opts))

if [[ "$REGION_MODE" == "true" ]]; then
    GEOM=$(slurp 2>/dev/null)
    if [[ -z "$GEOM" ]]; then
        # User pressed Escape or cancelled slurp
        exit 0
    fi
    set_state ".active = true | .paused = false | .seconds = 0 | .file = \"$OUT_FILE\""
    start_timer
    wf-recorder "${AUDIO_FLAGS[@]}" "${ENCODER_FLAGS[@]}" -g "$GEOM" -f "$OUT_FILE" </dev/null &>/tmp/wf-recorder.log &
    disown
else
    MONITOR=$(get_active_monitor)
    set_state ".active = true | .paused = false | .seconds = 0 | .file = \"$OUT_FILE\""
    start_timer
    wf-recorder "${AUDIO_FLAGS[@]}" "${ENCODER_FLAGS[@]}" -o "$MONITOR" -f "$OUT_FILE" </dev/null &>/tmp/wf-recorder.log &
    disown
fi

notify-send "Recording Started" "Press Notch Record or Super to stop" -a 'Screen Recorder' -i media-record
exit 0
