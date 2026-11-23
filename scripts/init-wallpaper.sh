#!/usr/bin/env bash
set -euo pipefail
root=$(dirname "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")")
exec bash "$root/hypr/scripts/init-wallpaper.sh" "$@"
