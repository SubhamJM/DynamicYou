# DynamicYou — Material 3 Expressive × Fluid Wayland Rice

```text
    ____                               _      __  __            
   / __ \__  ______  ____ _____ ___  (_)____ \ \/ /___  __  __  
  / / / / / / / __ \/ __ `/ __ `__ \/ / ___/  \  / __ \/ / / /  
 / /_/ / /_/ / / / / /_/ / / / / / / / /__     / / /_/ / /_/ /   
/_____/\__, /_/ /_/\__,_/_/ /_/ /_/_/\___/    /_/\____/\__,_/    
      /____/                                                    
```

An expressive, modern Linux rice built on **Arch Linux**, **Hyprland**, and **QuickShell**, inspired by **Google Pixel's Material You (Material 3)** design language and fluid Wayland animations.

---

## ✨ Features

- 🎨 **Six preset color themes** for the shell and desktop, independent of the wallpaper.
- 🏝️ **Dynamic Notch QuickShell**: Fluid, animated notch expanding into:
  - 📝 **Zen Editorial Notepad & Todo list** (distraction-free, Material 3 rounded pill styling).
  - 📋 **Material You Clipboard History** (dynamic sizing, smooth arrow transitions, soft dim borders).
  - 📶 **Lucid Wi-Fi & Bluetooth** with the Material 3 scan animation, saved and nearby networks, QR sharing, and device pairing.
  - 🚀 **App Launcher & System Deck** (instant fuzzy search and quick hardware toggles).
- 🖥️ **SDDM Rice Greeter (`ii-pixel`)**: Native Wayland greeter compositor powered by **Niri** with dynamic shape-morphing password characters, battery readout, and floating avatar cards.
- ⚡ **High Performance & Minimal Latency**: Pure Wayland architecture running without Xorg dependencies, utilizing GPU-accelerated rendering.

---

## 🚀 Installation & Setup

From a Dynamic You checkout, run the installer as your normal desktop user.

```bash
./install.sh --dry-run
./install.sh
```

The installer previews the paths it will change, asks which apps should follow the selected theme, and asks before deploying Hyprland and Quickshell. It preserves named Quickshell configs, nonconflicting custom files, existing app settings, and your wallpaper library. The install uses your existing login manager and network setup.

On a fresh Arch install, run `./install.sh --deps` as your normal user with access to `sudo`. With your approval it installs Python if needed, then installs the supported Arch packages, including Quickshell with its NetworkManager integration, and `qrencode`. Basic installation uses Arch's official repositories. Quickshell 0.3.2 and Hyprland 0.57.2 are the tested versions.

The wallpaper picker also supports local MP4, WebM, MKV, MOV, and M4V videos in `~/Pictures/Wallpapers`. It creates a still preview with FFmpeg and plays the video silently behind the desktop. Selecting a regular image stops the video. `./install.sh --deps` installs the Qt Multimedia FFmpeg backend and FFmpeg needed for this feature. Wallpaper changes do not alter the selected theme's colors.

The installer offers to start NetworkManager and BlueZ if they are inactive. Wi-Fi and Bluetooth need their respective services and supported hardware. Use `--enable-services` to opt in from a noninteractive install. The installer keeps an already active network manager. After installing, start a Hyprland session to launch the bar.

The browser key uses Zen if present and can fall back to Firefox on a fresh installation. Use `--browser zen` or `--browser helium` to explicitly choose another browser. Installing either through `--deps` requires an existing AUR helper if the browser is absent. System browser defaults are your choice. `setup.sh` uses the same installer, and `setup.sh --install` is an alias for `install.sh --deps`.

For an unattended setup, explicitly choose your app integrations. Omit `--apps` to keep saved choices, or to use the shell palette alone on a fresh install.

```bash
./install.sh --yes --apps kitty,zen
./install.sh --dry-run --rollback
./install.sh --rollback
```

Use `--apps all` or `--apps none` to select all or no integrations. Restore a specific install with `--rollback <install-id>`. Backups live under `${XDG_STATE_HOME:-$HOME/.local/state}/dynamic-you/install-backups/`. Rollback saves a recovery copy of your current files before restoring. Eject an active Tapes profile before installing or restoring the standalone desktop.

### Workspace controls

Scrolling is the default layout. `Super+Ctrl+↑/↓` switches workspaces and adding Shift moves the focused window. `Super+D` cycles half-width and full-width columns. Three-finger vertical swipes switch workspaces, horizontal swipes pan columns, and four-finger down/up opens or closes the workspace pager. `Super+X` opens the communications workspace.

### Wallpaper-derived colors

The theme switcher applies preset colors to Quickshell, Hyprland, Kitty, GTK, and Starship. Changing wallpapers keeps the selected theme colors.

## ⌨️ Keybindings Cheat Sheet

| Keybinding | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Launch Terminal (**Kitty**) |
| <kbd>Super</kbd> + <kbd>E</kbd> | Launch File Manager (**Yazi**) |
| <kbd>Super</kbd> + <kbd>B</kbd> | Launch Web Browser (**Zen Browser**) |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Toggle Dynamic Island App Launcher |
| <kbd>Super</kbd> + <kbd>R</kbd> | Launch App Launcher (**Hyprlauncher**) |
| <kbd>Super</kbd> + <kbd>T</kbd> | Dynamic Theme Switcher |
| <kbd>Super</kbd> + <kbd>W</kbd> | Wallpaper Selector |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Wallpaper Transition Selector |
| <kbd>Super</kbd> + <kbd>N</kbd> | Toggle Notifications Notch |
| <kbd>Super</kbd> + <kbd>V</kbd> | Clipboard History Notch |
| <kbd>Super</kbd> + <kbd>P</kbd> | Power Menu Notch |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock Screen (**QuickShell Lockscreen**) |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close Active Window |
| <kbd>Super</kbd> + <kbd>Print</kbd> | Screenshot Annotation Hub |

---

## 📂 Repository Structure

```text
MyLinuxSetup/
├── install.sh              # Preview, install, and restore backed-up configs
├── setup.sh                # Alias for the same installer
├── hypr/                   # Hyprland compositor configs, rules, animations & keybinds
├── quickshell/             # QuickShell QML notch, dock, and interactive modules
│   ├── modules/            # Notes, Clipboard, Wi-Fi, Bluetooth, Launcher, Deck
│   └── shell.qml           # Main QuickShell window controller
├── lockscreen/             # QuickShell lockscreen (multiple animated themes)
├── sddm/                   # SDDM rice (ii-pixel Material You theme + Niri compositor)
├── themes/                 # Curated Material You color presets
├── Wallpapers/             # Curated wallpapers organized by theme
├── scripts/                # Dynamic theme switcher (apply-theme.sh) & OSD controls
├── kitty/                  # Terminal configuration
├── yazi/                   # Terminal file manager (Kitty image preview & zoxide jumps)
├── eza/                    # Modern file listing theme configuration
├── gtk/                    # GTK 3.0 & 4.0 dark theme and icon configurations
├── fish/                   # Fish shell configs, aliases (eza, zoxide) & functions
├── fastfetch/              # Fastfetch configuration & ASCII art
├── starship/               # Starship cross-shell prompt
└── nvim/                   # Neovim text editor setup
```

---

## 🎨 Switching Themes

Switch themes on the fly from the terminal or using <kbd>Super</kbd> + <kbd>T</kbd>:

```bash
apply-theme.sh Abyss
apply-theme.sh Crimson
apply-theme.sh Solstice
apply-theme.sh Solstice
apply-theme.sh Abyss
```
