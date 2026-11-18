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
SELECTED_BROWSER_ID=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install|-i)
            if [ -f "${SCRIPT_DIR}/install.sh" ]; then
                echo -e "${BLUE}${BOLD}🚀 Launching full system installer...${RESET}\n"
                shift
                exec bash "${SCRIPT_DIR}/install.sh" "$@"
            fi
            ;;
        --browser=*)
            SELECTED_BROWSER_ID="${1#*=}"
            shift
            ;;
        --browser|-b)
            SELECTED_BROWSER_ID="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -i, --install               Run full package installation via install.sh"
            echo "  -b, --browser <zen|helium>  Preselect default web browser (zen or helium)"
            echo "  -h, --help                  Show this help message"
            exit 0
            ;;
        *)
            shift
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

    # Runtime directories
    mkdir -p "${HOME}/.cache/quickshell" "${HOME}/.local/share/quickshell"

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

configure_browser() {
    echo -e "${BOLD}${BLUE}🌐 Configuring Default Web Browser & XDG Associations...${RESET}"

    # Prompt user for browser choice if not pre-specified
    if [[ -z "${SELECTED_BROWSER_ID:-}" ]]; then
        echo -e "   Please select your preferred default browser:"
        echo -e "   ${BOLD}[1]${RESET} ${GREEN}Zen Browser${RESET}    ${DIM}(zen.desktop / zen-browser) - Firefox-based, vertical tabs [Default]${RESET}"
        echo -e "   ${BOLD}[2]${RESET} ${BLUE}Helium Browser${RESET} ${DIM}(helium.desktop / helium-browser) - Chromium-based, fast & private${RESET}"

        local choice=""
        if [ -t 0 ]; then
            read -r -p "   Select browser [1/2] (default: 1): " choice || choice="1"
        else
            choice="1"
        fi
        choice="${choice:-1}"

        case "$choice" in
            2|[Hh]|[Hh][Ee][Ll][Ii][Uu][Mm])
                SELECTED_BROWSER_ID="helium"
                ;;
            1|[Zz]|[Zz][Ee][Nn]|*)
                SELECTED_BROWSER_ID="zen"
                ;;
        esac
    fi

    local browser_name="Zen Browser"
    local browser_bin="zen-browser"
    local browser_desktop="zen.desktop"
    local browser_pkg="zen-browser-bin"

    if [[ "$SELECTED_BROWSER_ID" =~ ^[2hH] ]]; then
        browser_name="Helium Browser"
        browser_bin="helium-browser"
        browser_desktop="helium.desktop"
        browser_pkg="helium-browser-bin"
    fi

    # 1. Update Hyprland configuration (keybinds.lua & env.lua)
    local keybinds_files=("${TARGET_DIR}/hypr/modules/keybinds.lua" "${HOME}/.config/hypr/modules/keybinds.lua")
    for kf in "${keybinds_files[@]}"; do
        if [ -f "$kf" ]; then
            sed -i -E "s/local browser = \".*\"/local browser = \"${browser_bin}\"/" "$kf" 2>/dev/null || true
        fi
    done

    local env_files=("${TARGET_DIR}/hypr/modules/env.lua" "${HOME}/.config/hypr/modules/env.lua")
    for ef in "${env_files[@]}"; do
        if [ -f "$ef" ]; then
            if grep -q "BROWSER" "$ef" 2>/dev/null; then
                sed -i -E "s/hl\.env\(\"BROWSER\", \".*\"\)/hl.env(\"BROWSER\", \"${browser_bin}\")/" "$ef" 2>/dev/null || true
            else
                echo "hl.env(\"BROWSER\", \"${browser_bin}\")" >> "$ef"
            fi
        fi
    done
    export BROWSER="${browser_bin}"

    # 2. Configure XDG Default Settings
    if [ ! -f "/usr/share/applications/${browser_desktop}" ] && [ ! -f "${HOME}/.local/share/applications/${browser_desktop}" ]; then
        mkdir -p "${HOME}/.local/share/applications"
        cat <<EOF > "${HOME}/.local/share/applications/${browser_desktop}"
[Desktop Entry]
Version=1.0
Name=${browser_name}
Comment=Default Web Browser
Exec=${browser_bin} %u
Icon=${browser_bin}
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF
    fi

    if command -v xdg-settings >/dev/null 2>&1; then
        xdg-settings set default-web-browser "${browser_desktop}" 2>/dev/null || true
    fi

    # 3. Configure XDG MIME Associations
    if command -v xdg-mime >/dev/null 2>&1; then
        local mime_types=(
            "x-scheme-handler/http"
            "x-scheme-handler/https"
            "x-scheme-handler/about"
            "x-scheme-handler/unknown"
            "text/html"
            "text/xml"
            "application/xhtml+xml"
            "application/xml"
            "application/x-extension-htm"
            "application/x-extension-html"
            "application/x-extension-shtml"
            "application/x-extension-xhtml"
            "application/x-extension-xht"
        )
        for mime in "${mime_types[@]}"; do
            xdg-mime default "${browser_desktop}" "$mime" 2>/dev/null || true
        done
    fi

    # 4. Explicitly ensure ~/.config/mimeapps.list is synchronized
    local mimeapps="${HOME}/.config/mimeapps.list"
    if [ ! -f "$mimeapps" ]; then
        mkdir -p "${HOME}/.config"
        cat <<EOF > "$mimeapps"
[Default Applications]
text/html=${browser_desktop}
x-scheme-handler/http=${browser_desktop}
x-scheme-handler/https=${browser_desktop}
x-scheme-handler/about=${browser_desktop}
x-scheme-handler/unknown=${browser_desktop}
application/xhtml+xml=${browser_desktop}
EOF
    else
        sed -i -E "s/^(x-scheme-handler\/http)=.*/\1=${browser_desktop}/" "$mimeapps" 2>/dev/null || true
        sed -i -E "s/^(x-scheme-handler\/https)=.*/\1=${browser_desktop}/" "$mimeapps" 2>/dev/null || true
        sed -i -E "s/^(text\/html)=.*/\1=${browser_desktop}/" "$mimeapps" 2>/dev/null || true
        sed -i -E "s/^(application\/xhtml\+xml)=.*/\1=${browser_desktop}/" "$mimeapps" 2>/dev/null || true
    fi

    echo -e "   ${GREEN}✓ XDG default web browser configured:${RESET} ${BOLD}${browser_name}${RESET} (${browser_desktop})"

    # Check installation status
    if command -v "$browser_bin" >/dev/null 2>&1; then
        echo -e "   ${GREEN}✓ Binary detected:${RESET} $(command -v "$browser_bin")"
    else
        echo -e "   ${YELLOW}! Note: '${browser_bin}' is not currently installed.${RESET}"
        echo -e "     You can install it with: ${BOLD}yay -S ${browser_pkg}${RESET}"
    fi

    # Reload Hyprland keybinds if active
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
        echo -e "   ${GREEN}✓ Hyprland keybinds reloaded (Super + B -> ${browser_bin})${RESET}"
    fi

    echo
}

main() {
    print_banner
    deploy_symlinks
    set_permissions
    init_theme_environment
    configure_browser

    echo -e "${GREEN}${BOLD}🎉 Setup Complete!${RESET}"
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "   ${DIM}Previous dotfiles backed up to: ${BACKUP_DIR}${RESET}"
    fi
    echo -e "   To test or reload your setup, run: ${YELLOW}apply-theme.sh Abyss${RESET}\n"
}

main "$@"
