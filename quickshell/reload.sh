#!/usr/bin/env bash
set -euo pipefail

config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml"
qs kill -p "$config" >/dev/null 2>&1 || true
for ((attempt = 0; attempt < 40; attempt++)); do
    running=$(qs list --all --json)
    if [[ $running == 'No running instances.' ]] ||
       ! jq -e --arg path "$config" 'any(.[]; .config_path == $path)' <<< "$running" >/dev/null; then
        exec env MALLOC_ARENA_MAX=2 MALLOC_TRIM_THRESHOLD_=131072 qs -p "$config" -n -d
    fi
    sleep 0.1
done
printf 'Dynamic You is still shutting down.\n' >&2
exit 1
