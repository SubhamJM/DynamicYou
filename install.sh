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
TARGET_DIR="${HOME}/git/DynamicYou"
BACKUP_DIR="${HOME}/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

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

# --- Confirmation Prompt ---
prompt_user_confirmation() {
    echo -e "   ${SURFACE}╭────────────────────────────────────────────────────────╮${RESET}"
    echo -e "   ${SURFACE}│${RESET}  ${BOLD}Installation Summary${RESET}                                  ${SURFACE}│${RESET}"
    echo -e "   ${SURFACE}├────────────────────────────────────────────────────────┤${RESET}"
    echo -e "   ${SURFACE}│${RESET}  • Rice Directory   : ${BLUE}${TARGET_DIR}${RESET}"
    echo -e "   ${SURFACE}│${RESET}  • Dotfile Targets  : ${BLUE}~/.config/{hypr,quickshell,kitty...}${RESET}"
    echo -e "   ${SURFACE}│${RESET}  • Wallpapers       : ${BLUE}~/Pictures/Wallpapers${RESET}"
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
        
        # Copy everything cleanly
        cp -a "${SCRIPT_DIR}/." "${TARGET_DIR}/"
        echo -e "   ${GREEN}✓ Setup synchronized at ${TARGET_DIR}${RESET}\n"
    else
        echo -e "   ${GREEN}✓ Installer running directly inside ${TARGET_DIR}${RESET}\n"
    fi

    # Ensure executable permissions on all scripts
    chmod +x "${TARGET_DIR}/scripts/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/hypr/scripts/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/quickshell/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/quickshell/scripts/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/sddm/install.sh" 2>/dev/null || true
    chmod +x "${TARGET_DIR}/install.sh" 2>/dev/null || true
}

# --- Install Dependencies ---
install_dependencies() {
    echo -e "${BOLD}${BLUE}📦 Installing Core & Wayland Dependencies...${RESET}"

    # Official Pacman packages
    PACMAN_DEPS=(
        hyprland
        hyprlock
        hypridle
        hyprpicker
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        wl-clipboard
        cliphist
        grim
        slurp
        kitty
        fish
        starship
        fastfetch
        neovim
        brightnessctl
        playerctl
        pamixer
        wireplumber
        pipewire
        pipewire-audio
        pipewire-alsa
        pipewire-pulse
        networkmanager
        bluez
        bluez-utils
        blueman
        jq
        socat
        libnotify
        inotify-tools
        qt6-declarative
        qt6-5compat
        qt6-svg
        qt6-multimedia
        qt6-multimedia-ffmpeg
        sddm
        niri
        noto-fonts
        noto-fonts-emoji
        papirus-icon-theme
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

    # Wallpapers
    mkdir -p "${HOME}/Pictures"
    symlink_module "${TARGET_DIR}/Wallpapers" "${HOME}/Pictures/Wallpapers"

    # Binaries in ~/.local/bin
    mkdir -p "${HOME}/.local/bin"
    symlink_module "${TARGET_DIR}/scripts/apply-theme.sh" "${HOME}/.local/bin/apply-theme.sh"
    symlink_module "${TARGET_DIR}/scripts/osd-control.sh" "${HOME}/.local/bin/osd-control.sh"

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

# --- Theme Initialization ---
init_theme() {
    echo -e "${BOLD}${BLUE}🎨 Initializing Dynamic Theme Engine...${RESET}"
    if [ -f "${TARGET_DIR}/scripts/apply-theme.sh" ]; then
        bash "${TARGET_DIR}/scripts/apply-theme.sh" Serenity || true
        echo -e "   ${GREEN}✓ Default theme applied: Serenity${RESET}\n"
    fi
}

# --- Default Shell (Fish) ---
configure_shell() {
    if command -v fish >/dev/null 2>&1; then
        FISH_PATH=$(which fish)
        if [ "$SHELL" != "$FISH_PATH" ]; then
            echo -e "${BOLD}${BLUE}🐚 Shell Configuration...${RESET}"
            read -r -p "   Set 'fish' as your default login shell? [Y/n] " shell_choice || shell_choice="N"
            shell_choice="${shell_choice:-Y}"
            if [[ "$shell_choice" =~ ^[Yy]$ ]]; then
                chsh -s "$FISH_PATH" "$USER" 2>/dev/null || sudo chsh -s "$FISH_PATH" "$USER" || true
                echo -e "   ${GREEN}✓ Default shell set to fish.${RESET}\n"
            fi
        fi
    fi
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
    echo -e "   • Switch Theme      : ${GREEN}apply-theme.sh <Theme>${RESET}  ${DIM}(e.g. Astral, Solstice, Abyss, Serenity)${RESET}"
    echo -e "   • Reload Hyprland   : ${GREEN}hyprctl reload${RESET}"
    echo -e "   • Reload QuickShell : ${GREEN}~/.config/quickshell/reload.sh${RESET}"
    echo -e "   • Open Terminal     : ${GREEN}Super + Return${RESET}          ${DIM}(Kitty)${RESET}"
    echo -e "   • Notch Launcher    : ${GREEN}Super + Space${RESET}           ${DIM}(QuickShell Apps)${RESET}"
    echo
    echo -e "   ${C5}${BOLD}To start the session, log out or reboot and select Hyprland in SDDM.${RESET}\n"
}

# --- Main Flow ---
main() {
    print_banner
    check_compatibility
    detect_aur_helper
    prompt_user_confirmation
    setup_target_dir
    install_dependencies
    apply_symlinks
    setup_sddm
    init_theme
    configure_shell
    print_completion
}

main "$@"
