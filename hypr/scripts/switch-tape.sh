#!/usr/bin/env bash
set -euo pipefail

config="${CONFIG_DIR:-$HOME/.config}/quickshell"
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state="$runtime/dynamic-you-lucid-wallpaper.tsv"
lumen_state="$runtime/dynamic-you-restart-lumen"
lucid="$config/lucid/shell.qml"
lumen="$config/lucid/lumen.qml"
dynamic="$config/shell.qml"
dynamic_source="${TAPE_DIR:-$HOME/.tapes/dynamic-you}/quickshell/shell.qml"

instances() {
    local running
    running=$(qs list --all --json)
    [[ $running != 'No running instances.' ]] || return 0
    jq -r --arg path "$1" '.[] | select(.config_path == $path) | .id' <<< "$running"
}

stop_config() {
    local ids instance
    ids=$(instances "$1")
    while IFS= read -r instance; do
        [[ -n $instance ]] || continue
        qs kill --id "$instance" >/dev/null
    done <<< "$ids"
}

wait_for_ipc() {
    local config_path=$1
    for ((attempt = 0; attempt < 40; attempt++)); do
        if qs ipc -p "$config_path" show >/dev/null 2>&1; then return; fi
        sleep 0.25
    done
    printf 'Quickshell did not become ready for %s\n' "$config_path" >&2
    return 1
}

reload_hypr() {
    local errors
    hyprctl reload
    errors=$(hyprctl configerrors)
    if [[ $errors =~ [^[:space:]] ]]; then
        printf '%s\n' "$errors" >&2
        return 1
    fi
}

if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl -j instances | jq -er 'if length == 1 then .[0].instance else empty end')
    export HYPRLAND_INSTANCE_SIGNATURE
fi

case "${1:-}" in
    insert)
        if [[ ! -e $state ]]; then
            awww query | awk -F 'currently displaying: image: ' 'NF==2 { split($1, parts, ": "); print parts[2] "\t" $2 }' > "$state"
        fi
        reload_hypr
        stop_config "$lucid"
        lumen_id=$(instances "$lumen")
        if [[ -n $lumen_id && $(qs ipc --id "$lumen_id" call lumen count) == 0 && $(qs ipc --id "$lumen_id" call lumen busy) == 0 ]]; then
            qs kill --id "$lumen_id" >/dev/null
            touch "$lumen_state"
        fi
        env MALLOC_ARENA_MAX=2 MALLOC_TRIM_THRESHOLD_=131072 qs -p "$dynamic" -n -d
        wait_for_ipc "$dynamic"
        bash "${CONFIG_DIR:-$HOME/.config}/hypr/scripts/init-wallpaper.sh"
        ;;
    eject)
        stop_config "$dynamic"
        stop_config "$dynamic_source"
        reload_hypr
        "$HOME/.config/lucid/launch-shell.sh" -p "$lucid" -n -d
        wait_for_ipc "$lucid"
        if [[ -e $lumen_state ]]; then
            "$config/lucid/lucidlumen/lumen" --background
            wait_for_ipc "$lumen"
            rm -- "$lumen_state"
        fi
        if [[ -f $state ]]; then
            while IFS=$'\t' read -r output image; do
                if [[ -n $output && -f $image ]]; then
                    awww img "$image" --outputs "$output" --transition-type none
                fi
            done < "$state"
            rm -- "$state"
        fi
        ;;
    *)
        printf 'Usage: %s insert|eject\n' "$0" >&2
        exit 2
        ;;
esac
