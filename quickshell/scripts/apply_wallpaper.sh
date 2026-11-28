#!/usr/bin/env bash
set -euo pipefail

target=$(realpath -e -- "${1:?Select a wallpaper}")
library=$(realpath -e -- "$HOME/Pictures/Wallpapers")
case "$target" in
    "$library/"*) ;;
    *) printf 'Wallpaper must be under ~/Pictures/Wallpapers\n' >&2; exit 1 ;;
esac
target="$HOME/Pictures/Wallpapers/${target#"$library/"}"
test -f "$target"
display="$target"
case "${target,,}" in
    *.mp4|*.webm|*.mkv|*.mov|*.m4v)
        command -v ffmpeg >/dev/null || { printf 'Live wallpapers need ffmpeg\n' >&2; exit 1; }
        cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/dynamic-you/live-frames"
        mkdir -p "$cache_dir"
        cache_key=$(printf '%s:%s:%s' "$target" "$(stat -c %s "$target")" "$(stat -c %Y "$target")" | sha256sum | cut -c1-24)
        display="$cache_dir/$cache_key.jpg"
        if [[ ! -s "$display" ]]; then
            frame_tmp="$cache_dir/.$cache_key.$$.jpg"
            if ! ffmpeg -v error -y -i "$target" -frames:v 1 -q:v 2 "$frame_tmp" </dev/null; then
                rm -f "$frame_tmp"
                printf 'Could not read a frame from %s\n' "$target" >&2
                exit 1
            fi
            mv -f "$frame_tmp" "$display"
        fi
        ;;
esac
transition="${2:-simple}"
if [[ $transition == random ]]; then
    transitions=(simple fade left right top bottom wipe wave outer)
    transition="${transitions[RANDOM % ${#transitions[@]}]}"
fi
awww img "$display" --transition-type "$transition" --transition-fps 144
active_dir="${XDG_CONFIG_HOME:-$HOME/.config}/active-theme"
mkdir -p "$active_dir"
ln -sfn -- "$display" "$active_dir/current-wallpaper"
state_tmp=$(mktemp "$active_dir/.current-wallpaper.XXXXXX")
printf '%s\n' "$target" > "$state_tmp"
mv -f "$state_tmp" "$active_dir/current-wallpaper.txt"
