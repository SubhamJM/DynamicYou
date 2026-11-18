#!/usr/bin/env bash
# ==============================================================================
# DynamicYou / MyLinuxSetup — Fast Setup & Dotfiles Linker
# Deploys configurations, sets permissions, and initializes the environment.
#
# Usage:
#   ./setup.sh           # Deploy configurations and symlinks
#   ./setup.sh --install # Run full package installer first (via install.sh)
# ==============================================================================

set -eo pipefail

BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"
GREEN="\033[38;2;166;227;161m"
YELLOW="\033[38;2;249;226;175m"
RED="\033[38;2;243;139;168m"
BLUE="\033[38;2;137;180;250m"
SURFACE="\033[38;2;148;163;184m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${TARGET_DIR:-$SCRIPT_DIR}"
BACKUP_DIR="${HOME}/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

print_banner() {
    echo -e "${BLUE}${BOLD}================================================================${RESET}"
    echo -e "   ${BOLD}DynamicYou / MyLinuxSetup${RESET} ${DIM}— Setup & Configuration Deployer${RESET}"
    echo -e "   ${DIM}Source Directory: ${TARGET_DIR}${RESET}"
    echo -e "${BLUE}${BOLD}================================================================${RESET}\n"
}

# --- Check arguments ---
for arg in "$@"; do
    case "$arg" in
        --install|-i)
            if [ -f "${SCRIPT_DIR}/install.sh" ]; then
                echo -e "${BLUE}${BOLD}🚀 Launching full system installer...${RESET}\n"
                exec bash "${SCRIPT_DIR}/install.sh"
            fi
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -i, --install    Run full package installation via install.sh"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
    esac
done

symlink_module() {
    local src="$1"
    local dest="$2"

    if [ ! -e "$src" ]; then
        echo -e "   ${YELLOW}! Source not found, skipping: ${src}${RESET}"
        return 0
    fi

    mkdir -p "$(dirname "$dest")"

    # If already correctly linked
    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]; then
        echo -e "   ${DIM}• Already linked: ${dest} -> ${src}${RESET}"
        return 0
    fi

    # Backup if destination exists
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_target="${BACKUP_DIR}/$(basename "$dest")"
        mv "$dest" "$backup_target"
        echo -e "   ${YELLOW}• Backed up existing ${dest} -> ${backup_target}${RESET}"
    fi

    ln -sfn "$src" "$dest"
    echo -e "   ${GREEN}✓ Linked: ${dest} -> ${src}${RESET}"
}

deploy_symlinks() {
    echo -e "${BOLD}${BLUE}🔗 Deploying Dotfiles & Configurations...${RESET}"

    # Configuration modules
    symlink_module "${TARGET_DIR}/hypr" "${HOME}/.config/hypr"
    symlink_module "${TARGET_DIR}/quickshell" "${HOME}/.config/quickshell"
    symlink_module "${TARGET_DIR}/kitty" "${HOME}/.config/kitty"
    symlink_module "${TARGET_DIR}/fish" "${HOME}/.config/fish"
    symlink_module "${TARGET_DIR}/fastfetch" "${HOME}/.config/fastfetch"
    symlink_module "${TARGET_DIR}/nvim" "${HOME}/.config/nvim"
    symlink_module "${TARGET_DIR}/krabby" "${HOME}/.config/krabby"
    symlink_module "${TARGET_DIR}/starship.toml" "${HOME}/.config/starship.toml"
    symlink_module "${TARGET_DIR}/scripts" "${HOME}/.config/scripts"
    symlink_module "${TARGET_DIR}/themes" "${HOME}/.config/themes"
    symlink_module "${TARGET_DIR}/active-theme" "${HOME}/.config/active-theme"
    symlink_module "${TARGET_DIR}/yazi" "${HOME}/.config/yazi"
    symlink_module "${TARGET_DIR}/eza" "${HOME}/.config/eza"

    # GTK settings
    if [ -d "${TARGET_DIR}/gtk/gtk-3.0" ]; then
        symlink_module "${TARGET_DIR}/gtk/gtk-3.0/settings.ini" "${HOME}/.config/gtk-3.0/settings.ini"
    fi
    if [ -d "${TARGET_DIR}/gtk/gtk-4.0" ]; then
        symlink_module "${TARGET_DIR}/gtk/gtk-4.0/settings.ini" "${HOME}/.config/gtk-4.0/settings.ini"
    fi

    # Wallpapers
    mkdir -p "${HOME}/Pictures"
    symlink_module "${TARGET_DIR}/Wallpapers" "${HOME}/Pictures/Wallpapers"

    # User binaries in ~/.local/bin
    mkdir -p "${HOME}/.local/bin"
    symlink_module "${TARGET_DIR}/scripts/apply-theme.sh" "${HOME}/.local/bin/apply-theme.sh"
    symlink_module "${TARGET_DIR}/scripts/init-wallpaper.sh" "${HOME}/.local/bin/init-wallpaper.sh"
    symlink_module "${TARGET_DIR}/scripts/osd-control.sh" "${HOME}/.local/bin/osd-control.sh"

    # Lockscreen setup
    mkdir -p "${HOME}/.local/share" "${HOME}/.config/qylock"
    if [ ! -f "${HOME}/.config/qylock/theme" ]; then
        echo "dog-samurai" > "${HOME}/.config/qylock/theme"
    fi
    symlink_module "${TARGET_DIR}/lockscreen" "${HOME}/.local/share/quickshell-lockscreen"
    symlink_module "${TARGET_DIR}/lockscreen/lock.sh" "${HOME}/.local/bin/lock-screen.sh"

    echo
}

set_permissions() {
    echo -e "${BOLD}${BLUE}🔧 Setting Executable Permissions...${RESET}"
    chmod +x "${TARGET_DIR}/install.sh" "${TARGET_DIR}/setup.sh" 2>/dev/null || true
    chmod +x "${TARGET_DIR}/scripts/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/hypr/scripts/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/quickshell/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/quickshell/scripts/"*.sh "${TARGET_DIR}/quickshell/scripts/"*.py 2>/dev/null || true
    chmod +x "${TARGET_DIR}/lockscreen/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/sddm/install.sh" 2>/dev/null || true
    echo -e "   ${GREEN}✓ All script permissions verified.${RESET}\n"
}

init_theme_environment() {
    echo -e "${BOLD}${BLUE}🎨 Initializing Theme Engine...${RESET}"
    if [ -f "${TARGET_DIR}/scripts/apply-theme.sh" ]; then
        bash "${TARGET_DIR}/scripts/apply-theme.sh" Abyss || true
        echo -e "   ${GREEN}✓ Default theme applied: Abyss${RESET}\n"
    fi

    # Set base GTK GSettings
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' 2>/dev/null || true
    fi
}

main() {
    print_banner
    deploy_symlinks
    set_permissions
    init_theme_environment

    echo -e "${GREEN}${BOLD}🎉 Setup Complete!${RESET}"
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "   ${DIM}Previous dotfiles backed up to: ${BACKUP_DIR}${RESET}"
    fi
    echo -e "   To test or reload your setup, run: ${YELLOW}apply-theme.sh Abyss${RESET}\n"
}

main "$@"
