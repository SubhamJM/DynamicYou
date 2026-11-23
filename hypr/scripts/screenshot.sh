#!/usr/bin/env bash
set -euo pipefail

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
if [[ ${1:-area} == hub ]]; then
    qs ipc call notch showScreenshot "$file"
fi
notify-send -a 'Dynamic You' 'Screenshot captured' "$file"
