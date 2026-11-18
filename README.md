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

- 🎨 **Material You Dynamic Theming**: 6 distinct, curated aesthetic themes (`Crimson`, `Solstice`, `Verdant`, `Abyss`, `Afterglow`, `Frost`) with dedicated color harmonies, unique backgrounds, and smooth wallpaper transitions.
- 🏝️ **Dynamic Notch QuickShell**: Fluid, animated notch expanding into:
  - 📝 **Zen Editorial Notepad & Todo list** (distraction-free, Material 3 rounded pill styling).
  - 📋 **Material You Clipboard History** (dynamic sizing, smooth arrow transitions, soft dim borders).
  - 📶 **Wi-Fi & Bluetooth Panels** (expressive toggles, detailed device cards).
  - 🚀 **App Launcher & System Deck** (instant fuzzy search and quick hardware toggles).
- 🖥️ **SDDM Rice Greeter (`ii-pixel`)**: Native Wayland greeter compositor powered by **Niri** with dynamic shape-morphing password characters, battery readout, and floating avatar cards.
- ⚡ **High Performance & Minimal Latency**: Pure Wayland architecture running without Xorg dependencies, utilizing GPU-accelerated rendering.

---

## 🚀 Installation & Setup

### Option 1: Full Fresh Arch Installation (`install.sh`)
For a fresh Arch Linux / EndeavourOS / CachyOS installation. This will detect/install an AUR helper, resolve all official and AUR dependencies, deploy SDDM with the Material You Wayland greeter, configure system services, set `fish` as your default shell, and deploy all dotfiles:

```bash
git clone https://github.com/SubhamJM/MyLinuxSetup.git ~/git/MyLinuxSetup
cd ~/git/MyLinuxSetup
chmod +x install.sh setup.sh
./install.sh
```

### Option 2: Fast Dotfiles Setup (`setup.sh`)
If packages are already installed and you just want to cleanly backup existing configs, deploy symlinks, set permissions, and initialize the theme engine:

```bash
./setup.sh
```
*(Tip: You can also run `./setup.sh --install` to trigger the full package installer).*

---

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
├── install.sh              # Full automated installer & dependency resolver
├── setup.sh                # Fast dotfiles deployer & permission initializer
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
