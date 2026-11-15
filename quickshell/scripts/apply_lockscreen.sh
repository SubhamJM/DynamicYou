#!/usr/bin/env bash

THEME="${1:-dog-samurai}"
ACTION="$2"

ALLOWED=("dog-samurai" "minecraft" "pixel-hollowknight" "pixel-emerald" "enfield" "last-of-us")

IS_ALLOWED=0
for a in "${ALLOWED[@]}"; do
    if [ "$a" == "$THEME" ]; then
        IS_ALLOWED=1
        break
    fi
done

if [ "$IS_ALLOWED" -eq 0 ]; then
    echo "Error: Theme '$THEME' is not in allowed list."
    exit 1
fi

mkdir -p "$HOME/.config/qylock"
echo "$THEME" > "$HOME/.config/qylock/theme"
echo "Active lockscreen theme set to: $THEME"

if [ "$ACTION" == "--lock" ] || [ "$ACTION" == "-l" ]; then
    exec "$HOME/.local/bin/lock-screen.sh" "$THEME"
fi
