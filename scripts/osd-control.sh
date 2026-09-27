#!/usr/bin/env bash

case "$1" in
    volume_up)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
        VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
        qs ipc call notch triggerOsd "volume" "$VOL" >/dev/null 2>&1 &
        ;;
    volume_down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
        qs ipc call notch triggerOsd "volume" "$VOL" >/dev/null 2>&1 &
        ;;
    volume_mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -o "MUTED")
        if [ "$MUTED" = "MUTED" ]; then
            qs ipc call notch triggerOsd "volume" "0" >/dev/null 2>&1 &
        else
            VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
            qs ipc call notch triggerOsd "volume" "$VOL" >/dev/null 2>&1 &
        fi
        ;;
    brightness_up)
        brightnessctl set +5%
        BRIGHT=$(brightnessctl i | grep -oP '\(\K[0-9]+(?=%\))')
        qs ipc call notch triggerOsd "brightness" "$BRIGHT" >/dev/null 2>&1 &
        ;;
    brightness_down)
        brightnessctl set 5%-
        BRIGHT=$(brightnessctl i | grep -oP '\(\K[0-9]+(?=%\))')
        qs ipc call notch triggerOsd "brightness" "$BRIGHT" >/dev/null 2>&1 &
        ;;
    kbd_up)
        brightnessctl --device='*kbd_backlight*' set +10%
        BRIGHT=$(brightnessctl --device='*kbd_backlight*' i | grep -oP '\(\K[0-9]+(?=%\))')
        qs ipc call notch triggerOsd "brightness" "$BRIGHT" >/dev/null 2>&1 &
        ;;
    kbd_down)
        brightnessctl --device='*kbd_backlight*' set 10%-
        BRIGHT=$(brightnessctl --device='*kbd_backlight*' i | grep -oP '\(\K[0-9]+(?=%\))')
        qs ipc call notch triggerOsd "brightness" "$BRIGHT" >/dev/null 2>&1 &
        ;;
esac
