#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == snip ]]; then
    monitor=$(hyprctl monitors -j | jq -r '[.[] | select(.focused) | .name][0] // .[0].name // empty')
    [[ -n $monitor ]] || exit 1
    runtime="${XDG_RUNTIME_DIR:-/tmp}/dynamic-you-snip"
    mkdir -p "$runtime"
    frozen="$runtime/frozen.png"
    grim -l 0 -o "$monitor" "$frozen"
    qs ipc call notch showSnip "$frozen" "$monitor"
    exit
fi

save_dir="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$save_dir"
file="$save_dir/Screenshot_$(date +%Y%m%d_%H%M%S_%N).png"

case "${1:-area}" in
    screen|full)
        grim "$file"
        ;;
    active|window)
        geometry=$(hyprctl -j activewindow | jq -er 'select(.at and .size) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        grim -g "$geometry" "$file"
        ;;
    hub|area)
        monitor=$(hyprctl monitors -j | jq -r '[.[] | select(.focused) | .name][0] // .[0].name // empty')
        runtime="${XDG_RUNTIME_DIR:-/tmp}/dynamic-you-snip"
        mkdir -p "$runtime"
        frozen="$runtime/frozen.png"
        if [[ -n $monitor ]] && grim -l 0 -o "$monitor" "$frozen" && qs ipc call notch showSnip "$frozen" "$monitor" >/dev/null 2>&1; then
            exit 0
        fi
        geometry=$(slurp </dev/null) || exit 0
        [[ -n $geometry ]] || exit 0
        sleep 0.1
        grim -g "$geometry" "$file"
        ;;
    *)
        printf 'Unknown screenshot mode: %s\n' "$1" >&2
        exit 2
        ;;
esac

wl-copy --type image/png < "$file"
if ! qs ipc call notch showScreenshot "$file" >/dev/null 2>&1; then
    notify-send -a 'Dynamic You' 'Screenshot captured' "$file"
fi
