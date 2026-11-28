#!/usr/bin/env bash
set -euo pipefail

config="${XDG_CONFIG_HOME:-$HOME/.config}"
active="$config/active-theme"
library="$HOME/Pictures/Wallpapers"
[[ -d "$library" ]] || exit 0
library_root=$(realpath -e -- "$library")

wallpaper=
saved=
if [[ -f "$active/current-wallpaper.txt" ]]; then
    saved=$(<"$active/current-wallpaper.txt")
fi
for candidate in "$saved" "$active/current-wallpaper"; do
    [[ -f "$candidate" ]] || continue
    resolved=$(realpath -e -- "$candidate") || continue
    if [[ "$resolved" == "$library_root/"* ]]; then
        wallpaper=$resolved
        break
    fi
done
if [[ -z "$wallpaper" ]]; then
    wallpaper=$(find -H "$library" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit)
fi
[[ -n "$wallpaper" ]] || exit 0

if ! awww query >/dev/null 2>&1 && ! pgrep -x awww-daemon >/dev/null; then
    awww-daemon >/dev/null 2>&1 &
fi
for ((attempt = 0; attempt < 30; attempt++)); do
    if awww query >/dev/null 2>&1; then
        exec bash "$config/quickshell/scripts/apply_wallpaper.sh" "$wallpaper" none
    fi
    sleep 0.1
done
printf 'Wallpaper daemon did not become ready.\n' >&2
exit 1
