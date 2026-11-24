#!/usr/bin/env bash
set -euo pipefail

config="$HOME/.config/quickshell/shell.qml"
launcher="${config%/*}/scripts/launch-quickshell.py"
qs kill -p "$config" >/dev/null 2>&1 || true
for ((attempt = 0; attempt < 40; attempt++)); do
    running=$(qs list --all --json)
    if [[ $running == 'No running instances.' ]] ||
       ! jq -e --arg path "$config" 'any(.[]; .config_path == $path)' <<< "$running" >/dev/null; then
        exec env __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json \
                 MALLOC_ARENA_MAX=2 \
                 MALLOC_TRIM_THRESHOLD_=131072 \
                 MALLOC_MMAP_THRESHOLD_=131072 \
                 python3 "$launcher" -p "$config" -n -d
    fi
    sleep 0.1
done
printf 'Dynamic You is still shutting down.\n' >&2
exit 1
