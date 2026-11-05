#!/usr/bin/env bash
set -e

SHARE_DIR="${DYNAMIC_YOU_SHARE_DIR:-@pkgDir@}"
RUNTIME_CONFIG="${DYNAMIC_YOU_CONFIG_DIR:-}"

resolve_qs_dir() {
    if [ -n "$RUNTIME_CONFIG" ] && [ -f "$RUNTIME_CONFIG/shell.qml" ]; then
        echo "$RUNTIME_CONFIG"
    elif [ -f "$HOME/.config/quickshell/shell.qml" ]; then
        echo "$HOME/.config/quickshell"
    else
        echo "$SHARE_DIR/quickshell"
    fi
}

cmd="${1:-run}"
case "$cmd" in
    run)
        shift 2>/dev/null || true
        qs_dir="$(resolve_qs_dir)"
        echo ":: Starting DynamicYou QuickShell from: $qs_dir"
        exec quickshell -p "$qs_dir" "$@"
        ;;
    daemon|-d)
        shift 2>/dev/null || true
        qs_dir="$(resolve_qs_dir)"
        echo ":: Starting DynamicYou daemon from: $qs_dir"
        exec quickshell -d -p "$qs_dir" "$@"
        ;;
    reload)
        killall -9 qs quickshell 2>/dev/null || true
        while pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1; do sleep 0.05; done
        sleep 0.15
        qs_dir="$(resolve_qs_dir)"
        exec quickshell -d -p "$qs_dir" >/dev/null 2>&1 &
        echo ":: DynamicYou QuickShell reloaded."
        ;;
    theme)
        shift 2>/dev/null || true
        exec "$SHARE_DIR/scripts/apply-theme.sh" "$@"
        ;;
    wallpaper)
        shift 2>/dev/null || true
        exec "$SHARE_DIR/scripts/init-wallpaper.sh" "$@"
        ;;
    osd)
        shift 2>/dev/null || true
        exec "$SHARE_DIR/scripts/osd-control.sh" "$@"
        ;;
    screenshot)
        qs_dir="$(resolve_qs_dir)"
        if [ -f "$qs_dir/scripts/screenshot_hub.sh" ]; then
            exec "$qs_dir/scripts/screenshot_hub.sh"
        else
            exec "$SHARE_DIR/quickshell/scripts/screenshot_hub.sh"
        fi
        ;;
    setup-dotfiles)
        shift 2>/dev/null || true
        force=false
        [ "${1:-}" = "--force" ] && force=true
        backup_dir="$HOME/.config/dynamic_you_backup_$(date +%Y%m%d_%H%M%S)"
        
        echo ":: Setting up DynamicYou dotfiles..."
        link_target() {
            local src="$1"
            local dest="$2"
            mkdir -p "$(dirname "$dest")"
            if [ -e "$dest" ] || [ -L "$dest" ]; then
                if [ "$force" = true ]; then
                    mkdir -p "$backup_dir"
                    mv "$dest" "$backup_dir/"
                    echo "  Backed up $dest -> $backup_dir/"
                else
                    echo "  Skipping existing: $dest (use --force to overwrite and back up)"
                    return 0
                fi
            fi
            ln -sfn "$src" "$dest"
            echo "  Linked: $dest -> $src"
        }

        for mod in quickshell hypr kitty fish fastfetch themes scripts active-theme krabby nvim; do
            if [ -d "$SHARE_DIR/$mod" ]; then
                link_target "$SHARE_DIR/$mod" "$HOME/.config/$mod"
            fi
        done
        [ -f "$SHARE_DIR/starship.toml" ] && link_target "$SHARE_DIR/starship.toml" "$HOME/.config/starship.toml"
        [ -d "$SHARE_DIR/starship" ] && link_target "$SHARE_DIR/starship" "$HOME/.config/starship"
        [ -d "$SHARE_DIR/Wallpapers" ] && link_target "$SHARE_DIR/Wallpapers" "$HOME/Pictures/Wallpapers"
        echo "✓ Dotfiles configured successfully!"
        ;;
    status)
        echo "=== DynamicYou Status ==="
        echo "Share directory: $SHARE_DIR"
        echo "Active quickshell directory: $(resolve_qs_dir)"
        if pgrep -x quickshell >/dev/null 2>&1 || pgrep -x qs >/dev/null 2>&1; then
            echo "QuickShell: RUNNING"
        else
            echo "QuickShell: STOPPED"
        fi
        if pgrep -x Hyprland >/dev/null 2>&1; then
            echo "Hyprland: RUNNING"
        else
            echo "Hyprland: NOT DETECTED"
        fi
        if [ -f "$HOME/.config/active-theme/theme-name.txt" ]; then
            echo "Active theme: $(cat "$HOME/.config/active-theme/theme-name.txt")"
        fi
        ;;
    help|--help|-h)
        echo "Usage: dynamic-you <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  run [args...]           Run QuickShell in foreground"
        echo "  daemon|-d [args...]     Run QuickShell in daemon mode"
        echo "  reload                  Restart running QuickShell instance"
        echo "  theme <theme-name>      Apply a Material 3 tonal theme"
        echo "  wallpaper [init]        Initialize wallpaper daemon and set active wallpaper"
        echo "  osd <action>            Trigger OSD (volume_up, volume_down, brightness_up, etc.)"
        echo "  screenshot              Trigger screenshot hub selection"
        echo "  setup-dotfiles [--force] Symlink configuration folders into ~/.config"
        echo "  status                  Show running components and active theme"
        echo "  help                    Show this help message"
        ;;
    *)
        echo "Unknown command: $cmd. Run 'dynamic-you help' for usage."
        exit 1
        ;;
esac
