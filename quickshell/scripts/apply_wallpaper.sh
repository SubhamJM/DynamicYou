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
transition="${2:-simple}"
if [[ $transition == random ]]; then
    transitions=(simple fade left right top bottom wipe wave outer)
    transition="${transitions[RANDOM % ${#transitions[@]}]}"
fi
awww img "$target" --transition-type "$transition" --transition-fps 144
active_dir="${XDG_CONFIG_HOME:-$HOME/.config}/active-theme"
mkdir -p "$active_dir"
ln -sfn -- "$target" "$active_dir/current-wallpaper"
printf '%s\n' "$target" > "$active_dir/current-wallpaper.txt"
