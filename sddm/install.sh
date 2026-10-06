#!/usr/bin/env bash
# ==============================================================================
# SDDM Rice Installer (ii-pixel Material You + Niri Wayland Greeter)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Installing SDDM Rice (ii-pixel Material You) ===${NC}\n"

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}This installer needs root permissions to copy files to /etc and /usr/share.${NC}"
    echo -e "Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# 1. Install theme
echo -e "${BLUE}[1/4] Installing theme to /usr/share/sddm/themes/ii-pixel...${NC}"
mkdir -p /usr/share/sddm/themes
rm -rf /usr/share/sddm/themes/ii-pixel
cp -r "${SCRIPT_DIR}/themes/ii-pixel" /usr/share/sddm/themes/
chmod -R 755 /usr/share/sddm/themes/ii-pixel

# 2. Install Niri Wayland greeter compositor configuration
echo -e "${BLUE}[2/4] Installing Wayland greeter config to /usr/share/inir/sddm/...${NC}"
mkdir -p /usr/share/inir/sddm
cp -f "${SCRIPT_DIR}/greeter/niri-greeter.kdl" /usr/share/inir/sddm/niri-greeter.kdl
chmod 644 /usr/share/inir/sddm/niri-greeter.kdl

# 3. Install SDDM conf.d drop-ins
echo -e "${BLUE}[3/4] Installing SDDM configurations to /etc/sddm.conf.d/...${NC}"
mkdir -p /etc/sddm.conf.d
cp -f "${SCRIPT_DIR}/conf.d/"*.conf /etc/sddm.conf.d/
chmod 644 /etc/sddm.conf.d/*.conf

# Ensure faces directory exists (used by impasto/ii-pixel config)
mkdir -p /var/lib/impasto/faces
chmod 755 /var/lib/impasto/faces

# 4. Enable SDDM service if not enabled
echo -e "${BLUE}[4/4] Verifying SDDM service...${NC}"
if systemctl is-enabled sddm &>/dev/null; then
    echo -e "${GREEN}✓ sddm.service is already enabled.${NC}"
else
    echo -e "${YELLOW}Enabling sddm.service...${NC}"
    systemctl enable sddm
    echo -e "${GREEN}✓ sddm.service enabled.${NC}"
fi

echo -e "\n${GREEN}=== Installation Complete! ===${NC}"
echo -e "You can test the greeter UI without logging out using:"
echo -e "  ${YELLOW}sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/ii-pixel${NC}\n"
