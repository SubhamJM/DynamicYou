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

- 🎨 **Material You Dynamic Theming**: 10+ expressive tonal palettes (`Serenity`, `Astral`, `Solstice`, `Abyss`, `Cloudscape`, `Crimson`, `Cyber`, `Frost`, `Verdant`, `Afterglow`) with smooth wallpaper color-harmonized transitions.
- 🏝️ **Dynamic Notch QuickShell**: Fluid, animated notch expanding into:
  - 📝 **Zen Editorial Notepad & Todo list** (distraction-free, Material 3 rounded pill styling).
  - 📋 **Material You Clipboard History** (dynamic sizing, smooth arrow transitions, soft dim borders).
  - 📶 **Wi-Fi & Bluetooth Panels** (expressive toggles, detailed device cards).
  - 🚀 **App Launcher & System Deck** (instant fuzzy search and quick hardware toggles).
- 🖥️ **SDDM Rice Greeter (`ii-pixel`)**: Native Wayland greeter compositor powered by **Niri** with dynamic shape-morphing password characters, battery readout, and floating avatar cards.
- ⚡ **High Performance & Minimal Latency**: Pure Wayland architecture running without Xorg dependencies, utilizing GPU-accelerated rendering.

---

## 🚀 Quick Installation

Clone and run the automated installer:

```bash
git clone https://github.com/YourUsername/DynamicYou.git ~/git/DynamicYou
cd ~/git/DynamicYou
chmod +x install.sh
./install.sh
```

### What the installer does:
1. **Checks Compatibility**: Verifies Arch Linux / Arch-derived environment, Wayland, and Hyprland readiness.
2. **Installs All Dependencies**: Pacman & AUR dependencies (Hyprland ecosystem, QuickShell, Qt6 runtime, Kitty, Fish, Starship, media/audio utilities).
3. **Dotfiles Symlinking**: Safely backs up existing configurations to `~/.config/dotfiles_backup_<date>` and symlinks modules from `~/git/DynamicYou` to `~/.config/`.
4. **SDDM Rice Setup**: Installs the `ii-pixel` Material You SDDM theme and Niri Wayland compositor greeter.
5. **Initializes Theme Engine**: Automatically applies the default `Serenity` theme and initializes wallpaper cache.

---

## ⌨️ Keybindings Cheat Sheet

| Keybinding | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Launch Terminal (**Kitty**) |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Toggle App Launcher |
| <kbd>Super</kbd> + <kbd>T</kbd> | Dynamic Theme Switcher |
| <kbd>Super</kbd> + <kbd>W</kbd> | Wallpaper Selector |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Wallpaper Transition Selector |
| <kbd>Super</kbd> + <kbd>N</kbd> | Toggle Dynamic Notch |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close Active Window |
| <kbd>Super</kbd> + <kbd>Print</kbd> | Screenshot Hub |

---

## 📂 Repository Structure

```text
DynamicYou/
├── install.sh              # Unified installer & system validator
├── hypr/                   # Hyprland compositor configs, rules, animations & keybinds
├── quickshell/             # QuickShell QML notch, dock, and interactive modules
│   ├── modules/            # Notes, Clipboard, Wi-Fi, Bluetooth, Launcher, Deck
│   └── shell.qml           # Main QuickShell window controller
├── sddm/                   # SDDM rice (ii-pixel Material You theme + Niri compositor)
├── themes/                 # 10+ Material You color presets
├── Wallpapers/             # Curated wallpapers organized by theme
├── scripts/                # Dynamic theme switcher (apply-theme.sh) & OSD controls
├── kitty/                  # Terminal configuration
├── fish/                   # Fish shell configs & functions
├── fastfetch/              # Fastfetch configuration & ASCII art
├── starship/               # Starship cross-shell prompt
└── nvim/                   # Neovim text editor setup
```

---

## 🎨 Switching Themes

Switch themes on the fly from the terminal or using <kbd>Super</kbd> + <kbd>T</kbd>:

```bash
apply-theme.sh Serenity
apply-theme.sh Astral
apply-theme.sh Solstice
apply-theme.sh Abyss
```
