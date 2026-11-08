#!/usr/bin/env bash
# Select a Hyprland blur preset with Fuzzel, persist it, then reload.

set -euo pipefail

hypr_dir="${HOME}/.config/hypr"
state_file="${hypr_dir}/state/current-blur"

choice="$(printf '%s\n' \
  'Off — disable blur' \
  'Subtle — light blur, crisp panels' \
  'Balanced — smooth everyday glass' \
  'Frosted — rich, soft glass' \
  'Deep — strong, atmospheric blur' \
  'Vivid — colorful, lively glass' \
  'Crisp — sharper contrast and detail' \
  'Performance — lighter GPU workload' \
  | fuzzel --dmenu --prompt='Blur preset: ')" || exit 0

case "${choice}" in
  'Off — disable blur') preset='off' ;;
  'Subtle — light blur, crisp panels') preset='subtle' ;;
  'Balanced — smooth everyday glass') preset='balanced' ;;
  'Frosted — rich, soft glass') preset='frosted' ;;
  'Deep — strong, atmospheric blur') preset='deep' ;;
  'Vivid — colorful, lively glass') preset='vivid' ;;
  'Crisp — sharper contrast and detail') preset='crisp' ;;
  'Performance — lighter GPU workload') preset='performance' ;;
  *) exit 0 ;;
esac

printf '%s\n' "${preset}" > "${state_file}"
hyprctl reload

# Kitty can use its own surface alpha independently of Hyprland's window
# opacity. Force opaque surfaces while blur is Off, and clear the override
# when switching back to a blur preset. Apply this to already-open Kitty
# windows as well as future windows covered by the config rule.
while IFS= read -r address; do
  [[ -n "${address}" ]] || continue
  if [[ "${preset}" == 'off' ]]; then
    hyprctl setprop "address:${address}" force_rgbx 1 lock
  else
    hyprctl setprop "address:${address}" force_rgbx unset
  fi
done < <(hyprctl clients -j | jq -r '.[] | select((.class // "") | test("^(kitty|kitty-dropterm)$")) | .address')

notify-send -u low 'Blur' "${choice}"
