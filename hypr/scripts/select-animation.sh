#!/usr/bin/env bash
# Select a Hyprland animation preset with Fuzzel, persist it, then reload.

set -euo pipefail

hypr_dir="${HOME}/.config/hypr"
state_file="${hypr_dir}/state/current-animation"

choice="$(printf '%s\n' \
  'M3 Expressive — bouncy, playful motion' \
  'M3 Hybrid — expressive windows, clean workspaces' \
  'M3 Standard — clean, predictable motion' \
  'Simple — minimal, familiar motion' \
  'Cinematic — flowing, deliberate transitions' \
  | fuzzel --dmenu --prompt='Animation preset: ')" || exit 0

case "${choice}" in
  'M3 Expressive — bouncy, playful motion') preset='m3-expressive' ;;
  'M3 Hybrid — expressive windows, clean workspaces') preset='m3-hybrid' ;;
  'M3 Standard — clean, predictable motion') preset='m3-standard' ;;
  'Simple — minimal, familiar motion') preset='simple' ;;
  'Cinematic — flowing, deliberate transitions') preset='cinematic' ;;
  *) exit 0 ;;
esac

printf '%s\n' "${preset}" > "${state_file}"
hyprctl reload
notify-send -u low 'Animations' "${choice}"
