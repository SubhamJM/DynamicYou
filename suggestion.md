# Desktop Shell System — Enhancement Suggestions & Architecture Roadmap

This document compiles comprehensive recommendations and architectural improvements for transforming this dotfiles repository into a **complete, turnkey operating system shell** that any user can install, configure, and daily-drive with zero friction.

---

## 1. Executive Summary & Current Architecture

The current setup represents an exceptionally crafted Wayland desktop experience:
- **Desktop Shell**: Custom **Quickshell (QtQuick/QML)** desktop environment featuring an interactive Apple-style **Dynamic Island / Notch** (`quickshell/shell.qml`) with 18+ rich modules (Launcher with inline math & bangs, Apple-style music player with live cava harmonic visualizer, drag-and-drop Shelf file stash, micro-notes & todo scratchpad, Keybinds cheat sheet HUD, and Control Center).
- **Window Manager**: **Hyprland** configured via modern Lua (`hypr/hyprland.lua`), featuring squircle corners (rounding 18, rounding_power 2.5), smooth animations, gesture navigation, and comprehensive window rules.
- **Theming Engine**: Dynamic multi-target theme orchestrator (`scripts/apply-theme.sh`) hot-reloading Hyprland borders, Kitty terminal, Starship prompt, GTK 3/4 CSS, Neovim colorschemes, and desktop wallpapers (`awww`) on the fly.
- **CLI Stack**: Fish shell with Starship, `eza`, `zoxide`, `direnv`, fastfetch, and Krabby pokemon greeting.

To elevate this setup into a **universal desktop shell for any user**, enhancements should focus on **automated installation, hardware agnosticism, essential system utilities, and workflow polish**.

---

## 2. Foundational Layer: Installation & Hardware Portability

For any user to successfully adopt this shell, it must install reliably across different machines and hardware configurations without manual code patching.

### 2.1 Automated One-Click Installer (`install.sh`)
- **Current State**: No installer script exists. Users must manually inspect configs to discover required packages and symlink targets.
- **Proposed Solution**:
  - Implement an interactive, beautiful CLI/TUI installer script (using standard Bash or `gum`).
  - **Automated Dependency Resolution**: Detect the host package manager (`pacman`, `paru`, `yay`, `dnf`) and install all required packages:
    - **Core**: `hyprland`, `hyprlock`, `hypridle`, `hyprsunset`, `hyprpicker`, `quickshell` (or AUR/git build), `kitty`, `fish`, `starship`.
    - **Tools**: `grim`, `slurp`, `grimblast`, `wl-clipboard`, `cliphist`, `swappy`, `tesseract`, `playerctl`, `brightnessctl`, `wireplumber`, `cava`, `eza`, `zoxide`, `direnv`, `jq`, `fd`, `ripgrep`, `yazi`.
    - **Fonts**: `ttf-jetbrains-mono-nerd`, `noto-fonts`, `ttf-material-symbols-variable-git` (or local TTF bundler).
  - **Safety Backups**: Backup existing `~/.config` directories to `~/.config/dotfiles_backup_<timestamp>` before making changes.
  - **Symlinking / Stow**: Cleanly deploy configuration directories via GNU `stow` or managed atomic symlinks.

### 2.2 Machine & Hardware Agnosticism
- **GPU DRM Devices (`hypr/modules/env.lua`)**:
  - *Issue*: Line 5 hardcodes `hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card2")`. On single-GPU systems or desktops where `/dev/dri/card0` is the primary card, Hyprland may fail to initialize.
  - *Fix*: Move device-specific DRM declarations into an untracked local override file (`hypr/modules/hardware.lua`) or detect them dynamically during the install step.
- **Display Scaling Defaults (`hypr/modules/monitors.lua`)**:
  - *Issue*: Line 6 sets global scaling to `1.20` for all monitors (`output = ""`). On standard 1080p displays, fractional scaling causes blur in non-Wayland native apps; on 4K displays, it may be too small.
  - *Fix*: Default to `scale = "1"` or `preferred, auto, auto`, allowing users to customize scaling per display output name.
- **Touchpad Device Name (`hypr/modules/input.lua`)**:
  - *Issue*: Line 55 overrides settings for `ascf1201:00-2808:0231-touchpad` specifically.
  - *Fix*: Ensure all essential gestures (natural scroll, clickfinger, tap-to-click) are defined inside the generic `input.touchpad` block so any laptop works immediately.
- **Desktop vs. Laptop Adaptability**:
  - **Battery**: On desktop PCs with no ACPI battery, `BatteryPill.qml` and `BatteryModule.qml` should gracefully hide their UI elements instead of displaying 0% or errors.
  - **Brightness**: On desktops without an internal backlight controller, `brightnessctl` commands in `UtilityModule.qml` and `osd-control.sh` fail silently. Integrate fallback support for `ddcutil` (I2C control for external monitors) or gracefully disable the brightness slider.

---

## 3. Core System Utilities (The Missing Essentials)

A complete desktop operating system shell needs daily utilities built directly into its control surfaces.

### 3.1 Lock Screen & Idle Management (`hyprlock` & `hypridle`)
- **Current State**: `hypridle` is autostarted in `autostart.lua` and a lock button exists in `UtilityModule.qml`, but neither `hyprlock.conf` nor `hypridle.conf` exist in the repository.
- **Proposed Solution**:
  - Include a custom, themed `hyprlock.conf` styled to match the active theme's colors (`active-theme/quickshell-colors.json` or CSS).
  - Feature user avatar, clock with custom font weight, subtle glassmorphic input card, battery status, and active media banner.
  - Configure `hypridle.conf` with progressive timeouts:
    1. 2.5 min: Dim screen to 20%.
    2. 3.0 min: Lock screen via `hyprlock`.
    3. 5.0 min: Turn off screen (DPMS off).
    4. 15.0 min: Suspend system (if on battery).

### 3.2 VPN & Network Privacy Integration (WireGuard / Tailscale / Cloudflare WARP)
- **Status**: Implemented (`quickshell/scripts/vpn_manager.py` + `quickshell/modules/UtilityModule.qml`)
- **Features Implemented**:
  - Dedicated **Material You VPN Pill** in Row 2 of Control Center (split toggle & detail chevron).
  - **Zero-Setup Default**: Cloudflare WARP (`warp-cli`) with automatic registration on first toggle.
  - **Multi-Provider Subview**: Interactive subview displaying Cloudflare WARP, Tailscale (`tailscale0`), WireGuard (`wg0`), and custom NetworkManager VPN profiles.
  - Quick disconnect action and real-time interface status detection.

### 3.3 Multi-Monitor Management HUD
- **Problem**: Laptop users frequently dock into monitors, presentation projectors, or dual-screen workstations.
- **Proposed Solution**:
  - Add a quick display selector in the Notch or Launcher:
    - Presets: **Mirror Displays**, **Extend Right**, **Extend Left**, **External Monitor Only**, **Laptop Screen Only**.
    - Powered by simple `hyprctl keyword monitor` commands or `kanshi` profile daemon switching.

### 3.4 Rolling Release Package Update Tracker
- **Problem**: On rolling distributions (Arch, CachyOS), keeping track of pending updates is a daily habit.
- **Proposed Solution**:
  - Background checker running `checkupdates` / `yay -Qu` every 2 hours.
  - Subtle update indicator badge in the idle Notch or Control Center: `󰏔 14 updates`.
  - Clicking the badge spawns a floating Kitty terminal running `yay -Syu` or `paru`.

### 3.5 Microphone Noise Suppression (RNNoise / EasyEffects)
- **Problem**: Background keyboard clatter and fan noise during calls on Discord, Zoom, or Meet.
- **Proposed Solution**:
  - In `UtilityModule.qml`, beside the microphone mute toggle, add an **AI Voice Isolation / Noise Gate** toggle.
  - Toggles a PipeWire RNNoise filter chain or toggles the active preset in `easyeffects`.

---

## 4. Creative & Workflow Power Utilities

### 4.1 Screenshot Annotation Hub (`swappy` / `satty`)
- **Current State**: Screenshot shortcuts immediately save to `~/Pictures/Screenshots` and copy raw images to the clipboard.
- **Proposed Solution**:
  - When taking a screenshot (`Print` or `Super+Print`), display an interactive toast banner or floating action bar offering:
    1. **Annotate**: Opens the cropped capture in `swappy` to draw arrows, highlight code, add text, or blur sensitive data.
    2. **Pin to Shelf**: Drops the screenshot straight into `ShelfModule.qml` for subsequent dragging.
    3. **Instant OCR**: Runs `snip_ocr.sh` directly on the captured buffer.

### 4.2 Universal Drop Shelf Superpowers (`ShelfModule.qml`)
- **Current State**: The shelf provides an excellent temporary file holding area.
- **Proposed Enhancements**:
  - **LocalSend / KDE Connect Integration**: A "Send to Phone" action button next to stashed files to instantly transfer them to mobile devices over LAN.
  - **Quick Cloud Upload (0x0.st / Pastebin)**: A "Share Link" action button that uploads the file or image to a temporary filehost (e.g. `0x0.st`) and copies the short URL to the clipboard with confirmation.
  - **Bulk Actions**: One-click "Zip All Files" or "Copy Paths to Clipboard".

### 4.3 QR Code Utilities (Share & Scan)
- **Screen Scanner**: A shortcut or Launcher command (`> qrscan`) that freezes the screen with `slurp`, crops the selection, and decodes the QR code with `zbarimg`, copying the decoded URL to the clipboard.
- **Clipboard-to-QR**: A launcher action or keybind (`> qr`) that generates a clean QR code modal on screen for the current clipboard text, enabling instant transfer of links and text to a smartphone camera.

### 4.4 Dynamic Island Pomodoro & Focus Timer
- **Current State**: Proposed in `quickshell/QOL_SUGGESTIONS.md`.
- **Implementation Vision**:
  - Quick presets: 25m Focus, 5m Short Break, 15m Long Break, or custom input.
  - When active, the idle Notch displays an unobtrusive countdown indicator (`󱎫 24:18`).
  - Automatically enables Focus / Do Not Disturb (`dndEnabled = true`) during active focus sprints.
  - Upon completion, the Dynamic Island expands with a chime, pulse glow, and desktop notification.

---

## 5. Desktop Ergonomics & Polish

### 5.1 Launcher Spotlight Enhancements (`Launcher.qml`)
- **Fast Local File & Directory Search**:
  - Add a prefix (e.g., `~ ` or `f `) that queries `fd` or `fzf` for documents, downloads, and project directories, opening them directly in their default app or `yazi`.
- **Flatpak Application Discovery**:
  - Ensure the application scanner reads desktop files from:
    - `/var/lib/flatpak/exports/share/applications`
    - `~/.local/share/flatpak/exports/share/applications`
  - Allows Flatpak installs (Discord, Spotify, Steam) to appear seamlessly alongside native binaries.
- **Browser Bookmarks Search**:
  - Optional prefix (e.g., `b `) that queries Zen Browser or Firefox SQLite bookmark databases for instant navigation.

### 5.2 Keybinding Ergonomics & Collision Resolution
- In `hypr/modules/keybinds.lua`:
  - **Conflict**: Line 23 binds `SUPER + D` to `quickshell:toggleShelfNotch`, while Line 104 binds `SUPER + D` to `hl.dsp.workspace.toggle_special("extra")`. Rebind the special workspace (e.g. `SUPER + X` or `SUPER + G`) so the Shelf shortcut operates reliably.
  - **Music Binds**: Line 21 binds `SUPER + SHIFT + M` to the Notch music card, while Line 103 binds `SUPER + M` to special workspace `music`. Consolidate these binds so the user experience is intuitive and predictable.

### 5.3 Clean Cold-Boot Theming Resilience
- Ensure `scripts/apply-theme.sh` is invoked during initial session autostart if `~/.config/active-theme/theme-name.txt` exists. This prevents a newly installed system from booting into unstyled gray borders or mismatched terminal colors prior to manual theme toggling.

---

## 6. Implementation Roadmap & Priority Matrix

| Phase | Feature / Utility | Impact | Complexity | Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1: Foundations** | Turnkey `install.sh` installer | Critical | Medium | `bash`, `stow` / symlinks |
| **Phase 1: Foundations** | Themed `hyprlock.conf` & `hypridle.conf` | Critical | Low | `hyprlock`, `hypridle` |
| **Phase 1: Foundations** | Resolve `env.lua` GPU & monitor hardcoding | High | Low | Refactoring Lua files |
| **Phase 1: Foundations** | Fix `SUPER + D` keybind collision in `keybinds.lua` | High | Trivial | Line edit in `keybinds.lua` |
| **Phase 2: Core System** | WireGuard / Tailscale VPN control pill | High | Medium | `UtilityModule.qml`, `nmcli` / `tailscale` |
| **Phase 2: Core System** | Arch package updates counter in Notch | Medium | Low | `checkupdates`, `quickshell` Process |
| **Phase 2: Core System** | Fallback for desktop screens (`ddcutil` / battery hide) | High | Medium | `quickshell` bindings |
| **Phase 3: Workflows** | Screenshot annotation integration (`swappy`) | High | Low | `swappy`, `grimblast` |
| **Phase 3: Workflows** | Shelf sharing (LocalSend & 0x0.st upload) | Medium | Medium | `ShelfModule.qml`, `curl` |
| **Phase 3: Workflows** | Dynamic Island Pomodoro timer | Medium | Medium | `shell.qml`, QML Timer |
| **Phase 4: Search & Polish** | Local file search & Flatpak indexing in Launcher | Medium | Medium | `Launcher.qml`, `fd` |
| **Phase 4: Search & Polish** | QR Code generator & screen reader | Low | Low | `qrencode`, `zbar` |
