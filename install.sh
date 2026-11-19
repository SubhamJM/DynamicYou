#!/usr/bin/env bash
# ==============================================================================
#  ____                               _      __  __            
# / __ \__  ______  ____ _____ ___  (_)____ \ \/ /___  __  __  
#/ / / / / / / __ \/ __ `/ __ `__ \/ / ___/  \  / __ \/ / / /  
#/ /_/ / /_/ / / / / /_/ / / / / / / / /__     / / /_/ / /_/ /   
#\_____/\__, /_/ /_/\__,_/_/ /_/ /_/_/\___/    /_/\____/\__,_/    
#      /____/                                                    
#
# DynamicYou — Material 3 Expressive × Fluid Wayland Rice
# Automated Installer & Dotfiles Symlinker
# ==============================================================================

set -eo pipefail

# --- Color Definitions & Material Tones ---
BOLD="\033[1m"
DIM="\033[2m"
ITALIC="\033[3m"
RESET="\033[0m"

# Material You Gradient (Tonal Violet to Cyan)
C1="\033[38;2;186;197;238m" # #BAC5EE
C2="\033[38;2;170;185;235m"
C3="\033[38;2;155;175;230m"
C4="\033[38;2;140;165;225m"
C5="\033[38;2;130;190;230m"
C6="\033[38;2;120;210;230m"

# Status Colors
GREEN="\033[38;2;166;227;161m"
YELLOW="\033[38;2;249;226;175m"
RED="\033[38;2;243;139;168m"
BLUE="\033[38;2;137;180;250m"
SURFACE="\033[38;2;148;163;184m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${TARGET_DIR:-}" ]]; then
    if [[ "$SCRIPT_DIR" == "$HOME"* ]]; then
        TARGET_DIR="$SCRIPT_DIR"
    else
        TARGET_DIR="${HOME}/git/DynamicYou"
    fi
fi
BACKUP_DIR="${HOME}/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# --- Argument Parsing ---
SELECTED_BROWSER_ID=""
ARGS_COPY=("$@")
while [[ $# -gt 0 ]]; do
    case "$1" in
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
            echo "  -b, --browser <zen|helium>  Preselect default web browser (zen or helium)"
            echo "  -h, --help                  Show this help message"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done
set -- "${ARGS_COPY[@]}"

# --- Banner Display ---
print_banner() {
    clear 2>/dev/null || true
    echo -e "${C1}${BOLD}    ____                               _      __  __            ${RESET}"
    echo -e "${C2}${BOLD}   / __ \__  ______  ____ _____ ___  (_)____ \ \/ /___  __  __  ${RESET}"
    echo -e "${C3}${BOLD}  / / / / / / / __ \/ __ \`/ __ \`__ \/ / ___/  \  / __ \/ / / /  ${RESET}"
    echo -e "${C4}${BOLD} / /_/ / /_/ / / / / /_/ / / / / / / / /__     / / /_/ / /_/ /   ${RESET}"
    echo -e "${C5}${BOLD}/_____/\__, /_/ /_/\__,_/_/ /_/ /_/_/\___/    /_/\____/\__,_/    ${RESET}"
    echo -e "${C6}${BOLD}      /____/                                                    ${RESET}"
    echo
    echo -e "   ${BOLD}DynamicYou${RESET} ${DIM}· Material 3 Expressive × Fluid Wayland Rice${RESET}"
    echo -e "   ${DIM}https://github.com/DynamicYou/rice${RESET}"
    echo -e "   ${SURFACE}─────────────────────────────────────────────────────────────${RESET}"
    echo
}

# --- System Detection & Compatibility Verification ---
check_compatibility() {
    echo -e "${BOLD}${BLUE}🔍 Checking System Compatibility...${RESET}\n"

    # 1. Reject if executed as root directly
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}${BOLD}❌ ERROR: Do NOT run this installer directly as root!${RESET}"
        echo -e "   Please execute as your regular user: ${YELLOW}./install.sh${RESET}"
        echo -e "   Sudo permissions will be requested automatically when required."
        exit 1
    fi

    # 2. Distro Detection
    if [ ! -f /etc/os-release ]; then
        echo -e "${RED}${BOLD}❌ ERROR: Cannot identify Linux distribution (/etc/os-release missing).${RESET}"
        exit 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-$NAME}"
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"

    IS_ARCH=false
    if [[ "$DISTRO_ID" == "arch" || "$DISTRO_ID" == "cachyos" || "$DISTRO_ID" == "endeavouros" || "$DISTRO_ID" == "manjaro" || "$DISTRO_ID" == "garuda" || "$DISTRO_ID" == "artix" || "$DISTRO_LIKE" =~ "arch" ]]; then
        IS_ARCH=true
    fi

    # 3. Compositor & Target Detection
    CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}"
    HYPR_INSTALLED=false
    if command -v Hyprland >/dev/null 2>&1 || command -v hyprland >/dev/null 2>&1; then
        HYPR_INSTALLED=true
    fi

    # Display System Card
    echo -e "   ${SURFACE}╭────────────────────────────────────────────────────────╮${RESET}"
    echo -e "   ${SURFACE}│${RESET}  ${BOLD}Platform Information${RESET}                                   ${SURFACE}│${RESET}"
    echo -e "   ${SURFACE}├────────────────────────────────────────────────────────┤${RESET}"
    
    if [ "$IS_ARCH" = true ]; then
        echo -e "   ${SURFACE}│${RESET}  ${BOLD}Distribution :${RESET} ${GREEN}${DISTRO_NAME} (Arch-based) ✓${RESET}"
    else
        echo -e "   ${SURFACE}│${RESET}  ${BOLD}Distribution :${RESET} ${RED}${DISTRO_NAME} (Unsupported) ✗${RESET}"
    fi

    if [ "$CURRENT_DESKTOP" == "Hyprland" ]; then
        echo -e "   ${SURFACE}│${RESET}  ${BOLD}Environment  :${RESET} ${GREEN}Hyprland (Active Session) ✓${RESET}"
    elif [ "$HYPR_INSTALLED" = true ]; then
        echo -e "   ${SURFACE}│${RESET}  ${BOLD}Environment  :${RESET} ${GREEN}Hyprland (Installed) ✓${RESET}"
    else
        echo -e "   ${SURFACE}│${RESET}  ${BOLD}Environment  :${RESET} ${YELLOW}Hyprland (Will be installed) ℹ${RESET}"
    fi

    echo -e "   ${SURFACE}│${RESET}  ${BOLD}Display Type :${RESET} ${BLUE}Wayland (Target Protocol)${RESET}"
    echo -e "   ${SURFACE}│${RESET}  ${BOLD}Architecture :${RESET} ${BLUE}$(uname -m)${RESET}"
    echo -e "   ${SURFACE}│${RESET}  ${BOLD}Active User  :${RESET} ${BLUE}${USER}${RESET}"
    echo -e "   ${SURFACE}╰────────────────────────────────────────────────────────╯${RESET}"
    echo

    # 4. Strict Rejection if non-Arch
    if [ "$IS_ARCH" = false ]; then
        echo -e "${RED}${BOLD}❌ INSTALLATION REJECTED:${RESET}"
        echo -e "   DynamicYou is exclusively tailored for ${BOLD}Arch Linux${RESET} and Arch-based"
        echo -e "   distributions (EndeavourOS, CachyOS, etc.) with pacman and the AUR."
        echo -e "   Your system (${DISTRO_NAME}) does not support the required packaging."
        exit 1
    fi

    # 5. Strict Rejection if Hyprland is completely unavailable
    HYPR_AVAILABLE=false
    if [ "$HYPR_INSTALLED" = true ]; then
        HYPR_AVAILABLE=true
    elif pacman -Si hyprland >/dev/null 2>&1; then
        HYPR_AVAILABLE=true
    fi

    if [ "$HYPR_AVAILABLE" = false ]; then
        echo -e "${RED}${BOLD}❌ INSTALLATION REJECTED:${RESET}"
        echo -e "   Hyprland was not found and is not available in your package repositories."
        echo -e "   DynamicYou requires Hyprland as its primary Wayland compositor."
        exit 1
    fi
}

# --- Detect or Install AUR Helper ---
detect_aur_helper() {
    echo -e "${BOLD}${BLUE}📦 Checking Package Manager & AUR Helper...${RESET}"
    if command -v paru >/dev/null 2>&1; then
        AUR_HELPER="paru"
        echo -e "   ${GREEN}✓ Detected AUR helper: paru${RESET}\n"
    elif command -v yay >/dev/null 2>&1; then
        AUR_HELPER="yay"
        echo -e "   ${GREEN}✓ Detected AUR helper: yay${RESET}\n"
    else
        echo -e "   ${YELLOW}! No AUR helper (paru or yay) found.${RESET}"
        read -r -p "   Would you like to automatically install 'yay'? [Y/n] " install_yay_choice || install_yay_choice="N"
        install_yay_choice="${install_yay_choice:-Y}"
        if [[ "$install_yay_choice" =~ ^[Yy]$ ]]; then
            echo -e "   ${BLUE}Installing base-devel, git, and yay-bin...${RESET}"
            sudo pacman -S --needed --noconfirm base-devel git
            TMP_YAY=$(mktemp -d)
            git clone https://aur.archlinux.org/yay-bin.git "$TMP_YAY/yay-bin"
            (cd "$TMP_YAY/yay-bin" && makepkg -si --noconfirm)
            rm -rf "$TMP_YAY"
            AUR_HELPER="yay"
            echo -e "   ${GREEN}✓ Successfully installed yay!${RESET}\n"
        else
            echo -e "${RED}❌ AUR helper is required to install QuickShell and complementary modules.${RESET}"
            exit 1
        fi
    fi
}

# --- Web Browser Preference ---
select_browser() {
    echo -e "${BOLD}${BLUE}🌐 Web Browser Preference...${RESET}"
    echo -e "   DynamicYou supports both Zen (Firefox-based) and Helium (Chromium-based)."

    if [[ -z "${SELECTED_BROWSER_ID:-}" ]]; then
        echo -e "   Please select your preferred default browser:"
        echo -e "   ${BOLD}[1]${RESET} ${GREEN}Zen Browser${RESET}    ${DIM}(zen-browser-bin) - Firefox-based, vertical tabs, tiling optimized [Recommended]${RESET}"
        echo -e "   ${BOLD}[2]${RESET} ${BLUE}Helium Browser${RESET} ${DIM}(helium-browser-bin) - Chromium-based, private, fast & honest${RESET}"
        echo

        local choice=""
        if [ -t 0 ]; then
            read -r -p "   Choose default browser [1/2] (default: 1): " choice || choice="1"
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

    if [[ "$SELECTED_BROWSER_ID" =~ ^[2hH] ]]; then
        SELECTED_BROWSER_NAME="Helium Browser"
        SELECTED_BROWSER_BIN="helium-browser"
        SELECTED_BROWSER_DESKTOP="helium.desktop"
        SELECTED_BROWSER_PKG="helium-browser-bin"
    else
        SELECTED_BROWSER_NAME="Zen Browser"
        SELECTED_BROWSER_BIN="zen-browser"
        SELECTED_BROWSER_DESKTOP="zen.desktop"
        SELECTED_BROWSER_PKG="zen-browser-bin"
    fi

    echo -e "   ${GREEN}✓ Selected: ${BOLD}${SELECTED_BROWSER_NAME}${RESET} (${SELECTED_BROWSER_BIN})\n"
}

# --- Confirmation Prompt ---
prompt_user_confirmation() {
    echo -e "   ${SURFACE}╭────────────────────────────────────────────────────────╮${RESET}"
    echo -e "   ${SURFACE}│${RESET}  ${BOLD}Installation Summary${RESET}                                  ${SURFACE}│${RESET}"
    echo -e "   ${SURFACE}├────────────────────────────────────────────────────────┤${RESET}"
    echo -e "   ${SURFACE}│${RESET}  • Rice Directory   : ${BLUE}${TARGET_DIR}${RESET}"
    echo -e "   ${SURFACE}│${RESET}  • Dotfile Targets  : ${BLUE}~/.config/{hypr,quickshell,kitty...}${RESET}"
    echo -e "   ${SURFACE}│${RESET}  • Wallpapers       : ${BLUE}~/Pictures/Wallpapers${RESET}"
    echo -e "   ${SURFACE}│${RESET}  • Default Browser  : ${BLUE}${SELECTED_BROWSER_NAME} (${SELECTED_BROWSER_DESKTOP})${RESET}"
    echo -e "   ${SURFACE}│${RESET}  • Backups          : ${BLUE}${BACKUP_DIR}${RESET}"
    echo -e "   ${SURFACE}│${RESET}  • Greeter / SDDM   : ${BLUE}ii-pixel Material You + Niri Wayland${RESET}"
    echo -e "   ${SURFACE}╰────────────────────────────────────────────────────────╯${RESET}"
    echo

    read -r -p "Proceed with DynamicYou installation? [Y/n] " user_choice || user_choice="N"
    user_choice="${user_choice:-Y}"
    if [[ ! "$user_choice" =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}Installation cancelled by user. No modifications were made.${RESET}"
        exit 0
    fi
    echo
}

# --- Setup Target Rice Directory (~/git/DynamicYou) ---
setup_target_dir() {
    echo -e "${BOLD}${BLUE}📁 Setting up Rice Directory...${RESET}"
    mkdir -p "$(dirname "$TARGET_DIR")"

    if [ "$SCRIPT_DIR" != "$TARGET_DIR" ]; then
        echo -e "   Copying rice repository to ${BLUE}${TARGET_DIR}${RESET}..."
        mkdir -p "$TARGET_DIR"
        
        # Synchronize cleanly (avoid Permission denied on read-only git objects)
        if command -v rsync >/dev/null 2>&1; then
            rsync -a "${SCRIPT_DIR}/" "${TARGET_DIR}/"
        else
            cp --remove-destination -a "${SCRIPT_DIR}/." "${TARGET_DIR}/"
        fi
        echo -e "   ${GREEN}✓ Setup synchronized at ${TARGET_DIR}${RESET}\n"
    else
        echo -e "   ${GREEN}✓ Installer running directly inside ${TARGET_DIR}${RESET}\n"
    fi

    # Ensure executable permissions on all scripts
    chmod +x "${TARGET_DIR}/scripts/"*.sh "${TARGET_DIR}/scripts/"*.py 2>/dev/null || true
    chmod +x "${TARGET_DIR}/hypr/scripts/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/quickshell/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/quickshell/scripts/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/lockscreen/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/sddm/install.sh" 2>/dev/null || true
    chmod +x "${TARGET_DIR}/install.sh" 2>/dev/null || true
}

# --- Install Dependencies ---
install_dependencies() {
    echo -e "${BOLD}${BLUE}📦 Installing Core & Wayland Dependencies...${RESET}"

    # Official Pacman packages
    PACMAN_DEPS=(
        # Compositor & Display
        hyprland
        hyprlock
        hypridle
        hyprpicker
        hyprlauncher
        hyprpolkitagent
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        xorg-xwayland
        sddm
        niri

        # Wallpaper & Clipboard
        awww
        wl-clipboard
        cliphist
        grim
        slurp

        # Terminal, Shell & Navigation
        kitty
        yazi
        zoxide
        eza
        fzf
        fd
        ripgrep
        ffmpegthumbnailer
        poppler
        7zip
        imagemagick
        fish
        starship
        fastfetch
        neovim
        tree-sitter-cli

        # Audio & Media
        brightnessctl
        playerctl
        pamixer
        cava
        wireplumber
        pipewire
        pipewire-audio
        pipewire-alsa
        pipewire-pulse

        # Networking, Hotspot & Bluetooth
        networkmanager
        dnsmasq
        iptables
        iproute2
        iw
        bluez
        bluez-utils
        blueman

        # System Utilities & Runtimes
        jq
        socat
        libnotify
        inotify-tools
        rsync
        qt6-base
        qt6-declarative
        qt6-5compat
        qt6-svg
        qt6-multimedia
        qt6-multimedia-ffmpeg
        qt6-wayland
        python
        python-dbus
        python-pillow
        zenity

        # Fonts & Icons
        noto-fonts
        noto-fonts-emoji
        noto-fonts-cjk
        inter-font
        papirus-icon-theme
        breeze-icons
        ttf-jetbrains-mono-nerd
    )

    # Missing pacman packages check
    MISSING_PACMAN=()
    for pkg in "${PACMAN_DEPS[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            MISSING_PACMAN+=("$pkg")
        fi
    done

    if [ ${#MISSING_PACMAN[@]} -gt 0 ]; then
        echo -e "   Installing ${#MISSING_PACMAN[@]} missing Arch packages: ${YELLOW}${MISSING_PACMAN[*]}${RESET}"
        sudo pacman -S --needed --noconfirm "${MISSING_PACMAN[@]}"
    else
        echo -e "   ${GREEN}✓ All official Arch dependencies are already installed.${RESET}"
    fi

    # AUR packages
    echo -e "\n${BOLD}${BLUE}📦 Checking AUR Dependencies...${RESET}"
    AUR_DEPS=(
        quickshell
        grimblast-git
        krabby-bin
        ttf-material-symbols-variable-git
        "${SELECTED_BROWSER_PKG:-zen-browser-bin}"
    )

    MISSING_AUR=()
    for pkg in "${AUR_DEPS[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null && ! pacman -Qi "${pkg%-bin}" &>/dev/null && ! pacman -Qi "${pkg%-git}" &>/dev/null; then
            MISSING_AUR+=("$pkg")
        fi
    done

    if [ ${#MISSING_AUR[@]} -gt 0 ]; then
        echo -e "   Installing AUR packages via ${AUR_HELPER}: ${YELLOW}${MISSING_AUR[*]}${RESET}"
        $AUR_HELPER -S --needed --noconfirm "${MISSING_AUR[@]}" || {
            echo -e "${YELLOW}! Warning: Some AUR packages could not install automatically.${RESET}"
            echo -e "  If 'quickshell' failed, try: ${BOLD}$AUR_HELPER -S quickshell-git${RESET}"
        }
    else
        echo -e "   ${GREEN}✓ All AUR dependencies are already satisfied.${RESET}"
    fi
    echo
}

# --- Symlinking Modules with Safe Backups ---
symlink_module() {
    local src="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")"

    # If already correctly linked
    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]; then
        echo -e "   ${DIM}• Already linked: ${dest} -> ${src}${RESET}"
        return 0
    fi

    # If target already exists (file or directory), back it up
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_target="${BACKUP_DIR}/$(basename "$dest")"
        mv "$dest" "$backup_target"
        echo -e "   ${YELLOW}• Backed up existing ${dest} -> ${backup_target}${RESET}"
    fi

    # Create symlink
    ln -sfn "$src" "$dest"
    echo -e "   ${GREEN}✓ Linked: ${dest} -> ${src}${RESET}"
}

apply_symlinks() {
    echo -e "${BOLD}${BLUE}🔗 Symlinking Configuration Modules...${RESET}"

    # ~/.config modules
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
    mkdir -p "${HOME}/.config/gtk-3.0" "${HOME}/.config/gtk-4.0"
    if [ -f "${TARGET_DIR}/gtk/gtk-3.0/settings.ini" ]; then
        symlink_module "${TARGET_DIR}/gtk/gtk-3.0/settings.ini" "${HOME}/.config/gtk-3.0/settings.ini"
    fi
    if [ -f "${TARGET_DIR}/gtk/gtk-4.0/settings.ini" ]; then
        symlink_module "${TARGET_DIR}/gtk/gtk-4.0/settings.ini" "${HOME}/.config/gtk-4.0/settings.ini"
    fi

    # Wallpapers
    mkdir -p "${HOME}/Pictures"
    symlink_module "${TARGET_DIR}/Wallpapers" "${HOME}/Pictures/Wallpapers"

    # Binaries & permissions
    mkdir -p "${HOME}/.local/bin" "${HOME}/.cache/quickshell" "${HOME}/.local/share/quickshell"
    chmod +x "${TARGET_DIR}/install.sh" "${TARGET_DIR}/setup.sh" 2>/dev/null || true
    chmod +x "${TARGET_DIR}/scripts/"*.sh "${TARGET_DIR}/scripts/"*.py 2>/dev/null || true
    chmod +x "${TARGET_DIR}/hypr/scripts/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/quickshell/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/quickshell/scripts/"*.sh "${TARGET_DIR}/quickshell/scripts/"*.py 2>/dev/null || true
    chmod +x "${TARGET_DIR}/lockscreen/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/sddm/install.sh" 2>/dev/null || true
    symlink_module "${TARGET_DIR}/scripts/apply-theme.sh" "${HOME}/.local/bin/apply-theme.sh"
    symlink_module "${TARGET_DIR}/scripts/init-wallpaper.sh" "${HOME}/.local/bin/init-wallpaper.sh"
    symlink_module "${TARGET_DIR}/scripts/osd-control.sh" "${HOME}/.local/bin/osd-control.sh"
    symlink_module "${TARGET_DIR}/scripts/screenshot.sh" "${HOME}/.local/bin/screenshot.sh"
    symlink_module "${TARGET_DIR}/scripts/hotspot.sh" "${HOME}/.local/bin/hotspot"

    # Lockscreen setup
    mkdir -p "${HOME}/.local/share"
    mkdir -p "${HOME}/.config/qylock"
    if [ ! -f "${HOME}/.config/qylock/theme" ]; then
        echo "dog-samurai" > "${HOME}/.config/qylock/theme"
    fi
    symlink_module "${TARGET_DIR}/lockscreen" "${HOME}/.local/share/quickshell-lockscreen"
    symlink_module "${TARGET_DIR}/lockscreen/lock.sh" "${HOME}/.local/bin/lock-screen.sh"

    echo
}

# --- SDDM Setup ---
setup_sddm() {
    echo -e "${BOLD}${BLUE}🖥️ Configuring SDDM (ii-pixel Material You Greeter)...${RESET}"
    read -r -p "   Install DynamicYou SDDM theme & Wayland compositor? [Y/n] " sddm_choice || sddm_choice="N"
    sddm_choice="${sddm_choice:-Y}"
    if [[ "$sddm_choice" =~ ^[Yy]$ ]]; then
        sudo bash "${TARGET_DIR}/sddm/install.sh"
    else
        echo -e "   ${DIM}Skipping SDDM installation.${RESET}\n"
    fi
}

# --- Core System Services ---
enable_services() {
    echo -e "${BOLD}${BLUE}⚙️ Enabling Core System Services & Hotspot Stack...${RESET}"
    sudo systemctl enable NetworkManager.service 2>/dev/null || true
    sudo systemctl enable bluetooth.service 2>/dev/null || true
    systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true

    # Disable standalone dnsmasq service so NetworkManager can spawn its own instance for Hotspot DHCP
    sudo systemctl disable --now dnsmasq.service 2>/dev/null || true

    # Enable IPv4 packet forwarding for Wi-Fi hotspot sharing
    if [ ! -f /etc/sysctl.d/30-ipforward.conf ] || ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.d/30-ipforward.conf 2>/dev/null; then
        echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/30-ipforward.conf >/dev/null 2>&1 || true
        sudo sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
    fi

    # Configure firewall rules if UFW is installed
    if command -v ufw >/dev/null 2>&1; then
        echo -e "   ${DIM}• Configuring UFW firewall rules for Hotspot DHCP & DNS...${RESET}"
        sudo ufw allow 67/udp comment "Hotspot DHCP" 2>/dev/null || true
        sudo ufw allow 53/udp comment "Hotspot DNS" 2>/dev/null || true
        sudo ufw allow 53/tcp comment "Hotspot DNS" 2>/dev/null || true
        if [ -f /etc/default/ufw ]; then
            sudo sed -i -E 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw 2>/dev/null || true
        fi
        if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
            sudo ufw reload 2>/dev/null || true
        fi
    fi

    echo -e "   ${GREEN}✓ Essential services (NetworkManager, Bluetooth, PipeWire, Hotspot) configured.${RESET}\n"
}

# --- Theme Initialization ---
init_theme() {
    echo -e "${BOLD}${BLUE}🎨 Initializing Dynamic Theme Engine...${RESET}"
    if [ -f "${TARGET_DIR}/scripts/apply-theme.sh" ]; then
        bash "${TARGET_DIR}/scripts/apply-theme.sh" Abyss || true
        echo -e "   ${GREEN}✓ Default theme applied: Abyss${RESET}\n"
    fi

    # Set GTK defaults via GSettings
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' 2>/dev/null || true
    fi
}

# --- Default Shell (Fish) ---
configure_shell() {
    if command -v fish >/dev/null 2>&1; then
        FISH_PATH=$(which fish)
        CURRENT_SHELL=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)
        CURRENT_SHELL="${CURRENT_SHELL:-$SHELL}"

        if [ "$CURRENT_SHELL" != "$FISH_PATH" ]; then
            echo -e "${BOLD}${BLUE}🐚 Shell Configuration...${RESET}"
            read -r -p "   Set 'fish' as your default login shell? [Y/n] " shell_choice || shell_choice="N"
            shell_choice="${shell_choice:-Y}"
            if [[ "$shell_choice" =~ ^[Yy]$ ]]; then
                # Ensure fish is listed in /etc/shells
                if ! grep -qxF "$FISH_PATH" /etc/shells 2>/dev/null; then
                    echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
                fi

                # Set default shell with sudo (usermod or chsh) to prevent PAM authentication hangs
                if sudo usermod -s "$FISH_PATH" "$USER" 2>/dev/null || sudo chsh -s "$FISH_PATH" "$USER"; then
                    echo -e "   ${GREEN}✓ Default shell set to fish.${RESET}\n"
                else
                    echo -e "   ${YELLOW}! Could not automatically set default shell. You can run: chsh -s $FISH_PATH${RESET}\n"
                fi
            fi
        else
            echo -e "${BOLD}${BLUE}🐚 Shell Configuration...${RESET}"
            echo -e "   ${GREEN}✓ Default shell is already set to fish.${RESET}\n"
        fi
    fi
}

# --- Default Web Browser & XDG Configuration ---
configure_browser() {
    echo -e "${BOLD}${BLUE}🌐 Configuring Default Web Browser & XDG Associations...${RESET}"

    local browser_name="${SELECTED_BROWSER_NAME:-Zen Browser}"
    local browser_bin="${SELECTED_BROWSER_BIN:-zen-browser}"
    local browser_desktop="${SELECTED_BROWSER_DESKTOP:-zen.desktop}"
    local browser_pkg="${SELECTED_BROWSER_PKG:-zen-browser-bin}"

    # 1. Update Hyprland keybinds & env
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
        echo -e "   ${GREEN}✓ Configured XDG MIME associations for ${browser_desktop}${RESET}"
    fi

    # 4. Explicit fallback ensure in ~/.config/mimeapps.list
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

    echo -e "   ${GREEN}✓ Default web browser successfully set to ${BOLD}${browser_name}${RESET} (${browser_desktop})\n"
}

# --- Final Completion Screen ---
print_completion() {
    echo -e "   ${C1}${BOLD}╭────────────────────────────────────────────────────────╮${RESET}"
    echo -e "   ${C2}${BOLD}│  🎉 DynamicYou Installation Complete!                  │${RESET}"
    echo -e "   ${C3}${BOLD}╰────────────────────────────────────────────────────────╯${RESET}"
    echo
    echo -e "   ${BOLD}Rice Location:${RESET}   ${BLUE}${TARGET_DIR}${RESET}"
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "   ${BOLD}Backups Saved:${RESET}   ${YELLOW}${BACKUP_DIR}${RESET}"
    fi
    echo
    echo -e "   ${BOLD}Key Commands & Shortcuts:${RESET}"
    echo -e "   • Switch Theme      : ${GREEN}apply-theme.sh <Theme>${RESET}  ${DIM}(e.g. Crimson, Solstice, Verdant, Abyss, Afterglow, Frost)${RESET}"
    echo -e "   • Reload Hyprland   : ${GREEN}hyprctl reload${RESET}"
    echo -e "   • Reload QuickShell : ${GREEN}~/.config/quickshell/reload.sh${RESET}"
    echo -e "   • Open Terminal     : ${GREEN}Super + Return${RESET}          ${DIM}(Kitty)${RESET}"
    echo -e "   • Open Browser      : ${GREEN}Super + B${RESET}               ${DIM}(${SELECTED_BROWSER_NAME:-Browser})${RESET}"
    echo -e "   • Notch Launcher    : ${GREEN}Super + Space${RESET}           ${DIM}(QuickShell Apps)${RESET}"
    echo
    echo -e "   ${C5}${BOLD}To start the session, log out or reboot and select Hyprland in SDDM.${RESET}\n"
}

# --- Main Flow ---
main() {
    print_banner
    check_compatibility
    detect_aur_helper
    select_browser
    prompt_user_confirmation
    setup_target_dir
    install_dependencies
    apply_symlinks
    setup_sddm
    enable_services
    init_theme
    configure_browser
    configure_shell
    print_completion
}

main "$@"
