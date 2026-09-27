#!/usr/bin/env bash

ACTION="${1:-scan}"

case "$ACTION" in
    scan)
        # Select screen region with slurp
        GEOM=$(slurp < /dev/null 2>/dev/null)
        if [ -z "$GEOM" ]; then
            exit 0
        fi

        # Tiny delay to ensure slurp selection overlay is completely cleared
        sleep 0.1

        TEMP_SCAN="/tmp/quickshell_qr_scan.png"
        grim -g "$GEOM" "$TEMP_SCAN" 2>/dev/null

        if [ ! -f "$TEMP_SCAN" ]; then
            exit 1
        fi

        RAW_TEXT=$(zbarimg -q --raw "$TEMP_SCAN" 2>/dev/null)
        rm -f "$TEMP_SCAN"

        # Trim leading and trailing whitespace
        TEXT=$(printf "%s" "$RAW_TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        if [ -n "$TEXT" ]; then
            printf "%s" "$TEXT" | wl-copy
            printf "%s" "$TEXT" | wl-copy --primary 2>/dev/null
            if command -v cliphist >/dev/null 2>&1; then
                printf "%s" "$TEXT" | cliphist store 2>/dev/null
            fi

            # Sound chime
            canberra-gtk-play -i complete 2>/dev/null &

            # Visual desktop notification
            PREVIEW=$(printf "%s" "$TEXT" | tr '\n' ' ' | cut -c 1-80)
            notify-send -a "QR Scanner" -i edit-paste "QR Code Scanned & Copied" "$PREVIEW"

            # Dynamic Island Notification IPC
            qs ipc call notch onQrScanned "$TEXT" 2>/dev/null &
        else
            notify-send -a "QR Scanner" -i dialog-warning "No QR Code Detected" "Could not detect a valid QR code in the selected area."
        fi
        ;;

    encode)
        shift
        TEXT="$*"
        if [ -z "$TEXT" ]; then
            TEXT=$(wl-paste --no-newline 2>/dev/null)
        fi

        TEXT=$(printf "%s" "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        if [ -z "$TEXT" ]; then
            notify-send -a "QR Code Generator" -i dialog-warning "Clipboard Empty" "No text available in clipboard to generate a QR code."
            exit 1
        fi

        QR_OUT="/tmp/quickshell_qr.png"
        # Generate clean crisp QR image
        qrencode -s 8 -m 2 -o "$QR_OUT" "$TEXT" 2>/dev/null

        # Notify Quickshell to display QR Modal card
        qs ipc call notch showQr "$TEXT" 2>/dev/null &
        ;;

    open)
        shift
        URL="$*"
        if [[ "$URL" =~ ^https?:// ]]; then
            xdg-open "$URL" >/dev/null 2>&1 &
        fi
        ;;

    *)
        echo "Usage: $0 {scan|encode [text]|open <url>}"
        exit 1
        ;;
esac
