#!/usr/bin/env bash
# Hyprland Game Mode toggle: disable animations, blur, and decorations for max performance

HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
if [ "$HYPRGAMEMODE" = "1" ] ; then
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"
    notify-send -u low "Game Mode" "Enabled - animations and blur disabled"
    exit 0
fi
hyprctl reload
notify-send -u low "Game Mode" "Disabled - config reloaded"
