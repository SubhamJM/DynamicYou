#!/usr/bin/env bash
# Generate missing 680x422 thumbnails recursively under a wallpaper library.
set -uo pipefail

DIR="${1:-}"
SIZE="680x422"
THUMBS="$HOME/.cache/lucid/wallpaper-thumbs/$SIZE"
[[ -d "$DIR" ]] || exit 0

mkdir -p "$THUMBS"
exec 9>"$THUMBS/.lock"
flock -n 9 || exit 0

LOW=(nice -n 19)
command -v ionice &>/dev/null && LOW+=(ionice -c 3)

while IFS=$'\t' read -r src key; do
    [[ -n "$src" && -f "$src" ]] || continue
    thumb="$THUMBS/$key.jpg"
    [[ -f "$thumb" ]] && continue
    tmp="$thumb.$$.tmp.jpg"
    if [[ "${src,,}" =~ \.(mp4|webm|mkv|mov|m4v)$ ]]; then
        if command -v ffmpeg &>/dev/null && "${LOW[@]}" ffmpeg -v error -y -threads 1 -i "$src" -frames:v 1 \
                -vf "scale=${SIZE%x*}:${SIZE#*x}:force_original_aspect_ratio=increase,crop=${SIZE%x*}:${SIZE#*x}" \
                -q:v 3 "$tmp" </dev/null; then
            mv -f "$tmp" "$thumb"
        else
            rm -f "$tmp"
        fi
    elif command -v magick &>/dev/null; then
        if "${LOW[@]}" env MAGICK_THREAD_LIMIT=1 \
                magick -define jpeg:size=1360x844 "$src[0]" -auto-orient -thumbnail "$SIZE^" \
                -strip -quality 90 "$tmp" 2>/dev/null; then
            mv -f "$tmp" "$thumb"
        else
            rm -f "$tmp"
        fi
    fi
done < <(find -H "$DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.m4v' \) -printf '%p\t%i-%s-%T@\n')

find "$THUMBS" -type f -name '*.jpg' -mtime +120 -delete 2>/dev/null || true
