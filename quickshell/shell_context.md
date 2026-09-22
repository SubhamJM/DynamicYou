# Quickshell Notch Shell Context & Architecture Guide

## 1. System Overview & Architecture
The Quickshell Dynamic Island Notch provides an adaptive top-bar interface on Hyprland, combining an idle status pill, an extended hover dashboard, dynamic popups, and OSD pill notifications.

- **Primary Source Path**: `/home/saksham/.config/quickshell/my_own/`
- **Mirror / Distribution Paths**:
  - `/home/saksham/current/quickshell/`
  - `/home/saksham/working/quickshell/`
- **Strict Isolation Boundary**: `~/inir/` is strictly isolated and NEVER modified.
- **Service Management**: Controlled by systemd user unit `quickshell-notch.service` (`systemctl --user restart quickshell-notch.service`).

---

## 2. Recent Bug Fixes & Refinements

### A. Terminal & Neovim Abrupt Closure Glitch (Resolved)
- **Root Cause 1**: `apply-theme.sh` scripts contained `killall -s SIGUSR1 fish 2>/dev/null`. In POSIX systems, `fish` does not trap `SIGUSR1` unless explicitly declared; receiving an unhandled `SIGUSR1` instantly terminates the shell process, terminating the terminal emulator window (`kitty`, `alacritty`, `cosmic-term`).
- **Root Cause 2**: Spawning commands inside Quickshell via `sh -c "... &"` made child processes descend from `quickshell-notch.service`'s cgroup, causing them to receive `SIGTERM`/`SIGKILL` whenever the service was stopped or reloaded.
- **Fix**:
  1. Purged all instances of `killall -s SIGUSR1 fish` across all theme scripts (`~/.config/scripts/apply-theme.sh`, `~/.config/hypr/scripts/apply-theme.sh`, `~/current/scripts/apply-theme.sh`, `~/working/scripts/apply-theme.sh`, `~/rice/scripts/apply-theme.sh`).
  3. Decoupled application launching from both the service cgroup and Hyprland's Lua dispatcher by using `Quickshell.execDetached(["systemd-run", "--user", "--scope", "sh", "-c", cleanCmd])`, ensuring apps launch instantly in their own independent scopes without being affected by service reloads or Hyprland syntax constraints.

---

### B. Bar & Inverse Wing Curves Color Unification (Resolved)
- **Problem**: The curved wings connecting the notch to the top of the screen (`leftWing`, `rightWing`) did not match the bar's color, appearing miscolored or separated.
- **Fix**:
  - Unified notch surface color to `Theme.colors.bg ?? "#000000"`.
  - Updated both `leftWing` and `rightWing` Canvas elements to cast the color explicitly: `ctx.fillStyle = "" + root.notchSurfaceColor`.
  - Added reactive signal listeners to both wings:
    - `onThemeReloaded` (Theme singleton)
    - `onColorsChanged` (Theme singleton)
    - `onNotchSurfaceColorChanged` (root shell)
    - `onActiveModeChanged` (root shell)
    - `onAvailableChanged`, `onWidthChanged`, and `onHeightChanged` (Canvas triggers)
  - This guarantees the curve connecting the top edge of the screen to the notch seamlessly matches the bar color at all times without visual seams or color mismatch.

---

### C. Music Background Isolation (Popup Only) (Resolved)
- **Problem**: Album artwork backdrop was drawn across the whole bar/notch during media playback.
- **Fix**:
  - Removed `IrisMediaBackdrop` from the global `notch` rectangle in [shell.qml](file:///home/saksham/.config/quickshell/my_own/shell.qml).
  - Preserved `IrisMediaBackdrop` strictly inside [MusicModule.qml](file:///home/saksham/.config/quickshell/my_own/modules/MusicModule.qml), so album art styling is visible solely within the music expanded popup card.
  - The idle and hover bars remain pure OLED dark neutrals (`#000000`).

---

### D. Hover-Out Collapse Logic (Resolved)
- **Problem**: Moving the mouse out of the extended hover bar failed to collapse back to idle mode.
- **Root Cause**: An `extendedHoverArea` (`MouseArea`) was positioned with `-20px` negative margins outside the `notch` bounds. Because Quickshell's Wayland layer-shell input `mask` (`Region`) was clipped to `notchContainer` (`notch.height`), when the cursor moved past `notch.height`, it immediately exited the Wayland window surface. Consequently, `extendedHoverArea` never received the `mouseExited` event, locking `containsMouse` to `true` permanently. Because `autoCollapseTimer` checked `!extendedHoverArea.containsMouse`, collapse was permanently blocked.
- **Fix**:
  - Completely removed the problematic `extendedHoverArea`.
  - Streamlined `autoCollapseTimer`:
    ```qml
    Timer {
        id: autoCollapseTimer
        interval: NotchConfig.timerAutoCollapse // 250ms
        repeat: false
        onTriggered: {
            if (root.activeMode === "hover" && !notchHoverHandler.hovered) {
                root.collapseToIdle();
            }
        }
    }
    ```
  - `notchHoverHandler` triggers `autoCollapseTimer.restart()` on `hovered = false`. Moving out of the notch cleanly collapses the bar after 250ms, while interactive popup menus (`theme`, `wallpaper`, `music`, `utility`, `launcher`) remain open until explicitly closed by clicking outside or pressing Escape.

---

### E. Wallpaper Fallback Exception Logic (Resolved)
- **Problem**: If theme-specific wallpaper directories (`~/Pictures/Wallpapers/<theme>`) were empty or non-existent, the wallpaper picker showed no images.
- **Fix**:
  - Updated both [WallpaperSelector.qml](file:///home/saksham/.config/quickshell/my_own/modules/WallpaperSelector.qml) and [apply-theme.sh](file:///home/saksham/.config/scripts/apply-theme.sh).
  - In [WallpaperSelector.qml](file:///home/saksham/.config/quickshell/my_own/modules/WallpaperSelector.qml), replaced shallow globbing with recursive `os.walk(..., followlinks=True)`.
  - If a theme directory is absent or contains 0 valid images (`.jpg`, `.jpeg`, `.png`, `.webp`), the scanner automatically traverses:
    1. `~/Pictures/Wallpapers`
    2. `~/rice/Wallpapers`
    3. `~/Pictures`
  - Added a reactive `Connections` block on `root.activeModeChanged` in `WallpaperSelector.qml` to restart `wallpaperScanner` and autofocus the carousel every time the wallpaper module opens.

---

### F. Extended Hover Bar Layout Order
The extended hover bar ([MainDash.qml](file:///home/saksham/.config/quickshell/my_own/modules/MainDash.qml)) maintains the layout order:
1. **Arch Linux Logo Button** (`󰣇`): Triggers the application launcher.
2. **Workspaces Module**: Hyprland workspace indicators with active indicator dot.
3. **Clock & DateMark**: Formatted time with theme accent separator and DateMark.
4. **Control Center Button** (`󰘮`): Sleek quick-settings tune sliders icon opening the utility card.
5. **Battery**: Live battery percentage and state pill.

---

## 3. Directory Synchronization Map
Whenever changes are made to the notch, files must be synchronized:
- Source: `/home/saksham/.config/quickshell/my_own/`
- Target 1: `/home/saksham/current/quickshell/`
- Target 2: `/home/saksham/working/quickshell/`
- Script: `rsync -av --delete /home/saksham/.config/quickshell/my_own/ /home/saksham/current/quickshell/ && rsync -av --delete /home/saksham/.config/quickshell/my_own/ /home/saksham/working/quickshell/`

---

## 4. Key Shortcuts & IPC Commands
- **IPC Target**: `quickshell -c ~/.config/quickshell/my_own ipc call notch <method>`
  - `switchMode(string mode)`: Switch mode (`idle`, `hover`, `theme`, `wallpaper`, `music`, `utility`, `launcher`, etc.)
  - `collapse()` / `collapseToIdle()`: Collapse to idle pill
  - `toggleMusic()`: Toggle music popup
  - `toggleRecorder()`: Toggle screen recorder popup
- **Keyboard Shortcuts (Hyprland)**:
  - `SUPER + Space`: Toggle Launcher
  - `SUPER + T`: Toggle Theme Selector
  - `SUPER + W`: Toggle Wallpaper Selector
  - `SUPER + SHIFT + M`: Toggle Music Popup
  - `SUPER + U`: Toggle Utility / Control Center
  - `SUPER + grave (~)`: Reset Notch to Idle
