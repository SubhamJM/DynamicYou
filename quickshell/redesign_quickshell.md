# Quickshell Notch Redesign Blueprint: Bento Control Center & Productivity Deck (Concept A)

## 1. Executive Summary & Design Vision

This document details the complete redesign and architectural refactoring plan for the **Quickshell + Hyprland Dynamic Island Notch** setup. 

The current implementation has accumulated over 20 top-level modules. Most noticeably, `UtilityModule.qml` has transformed into a bloated "junk drawer" that mixes hardware controls (Wi-Fi, Bluetooth, volume, brightness) with full productivity applications (Pomodoro timers, notes, QR scanners, shelf drag-and-drop, and OCR snip tools).

### The Concept A Vision: The "Dual-Center" Architecture
Instead of overloading a single view, we partition the system into two distinct, purpose-driven surfaces:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            QUICKSHELL NOTCH ECOSYSTEM                       │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
         ┌─────────────────────────────┴─────────────────────────────┐
         ▼                                                           ▼
┌────────────────────────────────┐                         ┌────────────────────────────────┐
│     BENTO CONTROL CENTER       │                         │       PRODUCTIVITY DECK        │
│          (SUPER + U)           │                         │          (SUPER + P)           │
│  Hardware, Radios, Audio/      │                         │  Focus/Pomodoro, Notes,        │
│  Display, System Quick Toggles │                         │  Clipboard, Shelf, OCR, QR     │
└────────────────────────────────┘                         └────────────────────────────────┘
```

1. **Bento Control Center (`UtilityModule.qml`)**:
   - Strictly reserved for hardware controls, system state, volume/display sliders, and a uniform grid of quick toggles.
   - Every element adheres to a strict geometric rhythm (no mismatched pill sizes, no random circular dots interrupting pill rows).
   - Config-driven: users choose exactly which quick toggles appear via simple array lists in `NotchConfig.qml`.

2. **Productivity Deck (`ToolDeck.qml`)**:
   - A dedicated, cohesive module for workflow tools: Pomodoro Timer, Quick Notes, Clipboard History, Stash Shelf, OCR Snip, and QR Scanner.
   - Clean card-based dashboard layout that gives productivity tools room to breathe without cluttering system volume and network dials.

3. **Contextual Dynamic Island (`MainDash.qml` & `shell.qml`)**:
   - Leverages the notch's ambient status capabilities: ongoing screen recording, active Pomodoro timers, and playing music dynamically project micro-status indicators into the idle pill rather than demanding permanent space in the control menus.

---

## 2. Current State Audit & Bloat Mapping

### 2.1 The Redundancy Matrix
A major source of clutter in the existing codebase is identical features being implemented in 2 or 3 separate places:

| Feature / Domain | Current Location 1 | Current Location 2 | Current Location 3 | Redundancy Problem |
| :--- | :--- | :--- | :--- | :--- |
| **Power & Session** | `PowerMenu.qml` (standalone module) | Row 1 Lock Circle (`UtilityModule.qml`) | Row 2 Power Circle (`UtilityModule.qml`) | 3 separate ways to lock/power off. |
| **Screen Recorder** | `RecorderModule.qml` (full top-level popup) | Row 1 Record Pill (`UtilityModule.qml`) | Row 5 Capture Squircle (`UtilityModule.qml`) | Split controls; state was desynchronized. |
| **Pomodoro Focus** | Embedded section in `UtilityModule.qml` (lines 1612–1890) | Ambient clock indicator (`MainDash.qml`) | Header Quick Button (`UtilityModule.qml`) | Over 270 lines of timer code bloating the hardware panel. |
| **Workflow Tools** | `NotesModule.qml`, `ShelfModule.qml`, `QrModule.qml` | 5 Header icon buttons (`UtilityModule.qml`) | Top-level shortcuts | Header icons feel like desktop clutter. |
| **Audio Output** | Volume Slider (`UtilityModule.qml`) | Internal Audio Subview (`UtilityModule.qml`) | `MusicModule.qml` | Output sink switcher is buried behind a tiny slider chevron. |

### 2.2 Visual Hierarchy Discordance
Inspecting `quickshell/modules/UtilityModule.qml` (2,000+ lines) reveals 5 conflicting visual shapes stacked vertically:
1. **Header Row**: Date text + 5 tiny icon-only circular buttons with no labels.
2. **Row 1**: Large split-pill (Wi-Fi) + tiny circular button (Hotspot) + large split-pill (Record) + tiny circular button (Lock).
3. **Row 2**: Large split-pill (Bluetooth) + large split-pill (VPN) + tiny circular button (Power).
4. **Rows 3 & 4**: Full-width pill sliders with embedded chevrons.
5. **Row 5**: 5 compact squircles (Mic, Caffeine, Night Light, Screenshot, DND).

**Visual Result**: The eye is forced to jump across 4 different horizontal alignments, 3 different button geometries, and inconsistent hit targets.

---

## 3. Target Architecture: Bento Control Center

### 3.1 Geometric Grid System
The new Control Center adopts a **480px Bento Grid** built on an 8px grid with uniform corner radii:

- **Surface Width**: 460px (aligned with standard notch expansion)
- **Base Corner Radius**: 24px (outer container), 16px (bento cards), 12px (chips/toggles)
- **Grid Spacing**: 10px consistent gutters

### 3.2 Control Center ASCII Wireframe

```
┌──────────────────────────────────────────────────────────────┐
│  Control Center                            󰐥 Power   ⚙ Settings│  [Header: 32px]
├──────────────────────────────┬───────────────────────────────┤
│ 󰤨  Wi-Fi                     │ 󰂯  Bluetooth                  │
│    SubhamLaptop          (>) │    realme Buds T300       (>) │  [Connectivity Bento: 56px]
├──────────────────────────────┼───────────────────────────────┤
│ 󰕾  Volume               74% │ 󰃠  Display                60% │
│    [ ━━━━━━━━━━━━━╺━━━━ ]    │    [ ━━━━━━━━━━╺━━━━━━━ ]     │  [Twin Sliders Bento: 64px]
├──────────────────────────────┴───────────────────────────────┤
│  QUICK TOGGLES (Configurable 2x3 Uniform Tile Grid)           │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │
│  │ 󰖔 Night Light   │ │ 󰅶 Caffeine      │ │ 󰍬 Mic Mute      │  │  [Row 1: 42px]
│  │   Active        │ │   Off           │ │   Unmuted       │  │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘  │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │
│  │ 󱄄 Hotspot       │ │ 󰑋 Screen Record │ │ 󰍡 Do Not Disturb│  │  [Row 2: 42px]
│  │   Live (1 dev)  │ │   Ready         │ │   Standard      │  │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘  │
├──────────────────────────────────────────────────────────────┤
│  󰁹 84% Battery • 4h 12m remaining             󰛳 VPN Connected │  [Footer Pill: 28px]
└──────────────────────────────────────────────────────────────┘
```

### 3.3 Deep-Dive Subviews (Zero Page Bloat)
Clicking the chevron `(>)` on Wi-Fi or Bluetooth flips the card into an inline detail view with a smooth slide transition:
- **Audio Output Switcher**: Click volume icon or chevron to swap the slider card with quick radio cards for Headphones, Speakers, or Bluetooth audio.
- **VPN Switcher**: Quick-toggle WireGuard / Tailscale / WARP with status feedback.

---

## 4. Target Architecture: Productivity Deck (`ToolDeck.qml`)

All workflow, capture, and productivity tools are unified into a standalone **Productivity Deck** accessible via shortcut (`SUPER + P`) or via an icon in the hover notch.

### 4.1 Productivity Deck ASCII Wireframe

```
┌──────────────────────────────────────────────────────────────┐
│  Productivity Deck                                  [Esc] ✕  │
├──────────────────────────────────────────────────────────────┤
│ 󱎫 POMODORO FOCUS                                             │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │  24:18  Focus Sprint                                     │ │
│ │  [━━━━━━━━━━━━━━━━━━━━━━╺━━━━━━━━━━━━━━━━] (78%)         │ │
│ │  [ ⏸ Pause ]  [ +5 min ]  [ ⏹ Reset ]   [25m] [50m] [15m]│ │
│ └──────────────────────────────────────────────────────────┘ │
├──────────────────────────────┬───────────────────────────────┤
│ 󰎚 Quick Notes                │ 󰅍 Clipboard History           │
│ • Review pull request #42    │ 1. https://github.com/...     │
│ • Fix quickshell layout      │ 2. pacman -Syu wl-clipboard   │
│   [ + New Note ]   [ Open ↗ ]│ 3. rgb(136, 192, 208) [ ↗ ]   │
├──────────────────────────────┴───────────────────────────────┤
│ QUICK ACTIONS                                                │
│ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐        │
│ │ 󰄀 OCR Snip    │ │ 󰐳 QR Hub      │ │ 󱉥 Drop Shelf  │        │
│ │ Snip to Text  │ │ Generate/Scan │ │ 3 Staged Files│        │
│ └───────────────┘ └───────────────┘ └───────────────┘        │
└──────────────────────────────────────────────────────────────┘
```

**Key Advantages:**
1. **Focus Sprints feel premium**: The Pomodoro timer gets clean controls, custom durations, and visual progress without fighting for space against volume sliders.
2. **Clipboard & Notes at a Glance**: Instant preview of your clipboard history and active notes before opening fullscreen tools.
3. **Dedicated Screen Space**: Gives document tools 460x420px of breathing room with zero clutter.

---

## 5. User Agency & Dynamic Configuration System

To ensure the UI adapts to individual workflow preferences without requiring manual QML editing, we introduce **Config-Driven Toggles**.

### 5.1 `NotchConfig.qml` Schema Additions
In `quickshell/NotchConfig.qml`, add structured user settings:

```qml
// ==========================================
// 6. USER CUSTOMIZATION & TOGGLE REGISTRY
// ==========================================
// Select which quick toggles appear in the Control Center Bento grid (up to 6 recommended)
readonly property var enabledQuickToggles: [
    "nightlight",
    "caffeine",
    "mic_mute",
    "hotspot",
    "record",
    "dnd"
]

// Available toggle definitions catalog
readonly property var quickToggleDefinitions: ({
    "nightlight": {
        id: "nightlight",
        label: "Night Light",
        icon: "nightlight",
        activeText: "Sunset 4500K",
        inactiveText: "Off"
    },
    "caffeine": {
        id: "caffeine",
        label: "Caffeine",
        icon: "coffee",
        activeText: "Awake",
        inactiveText: "Standard"
    },
    "mic_mute": {
        id: "mic_mute",
        label: "Microphone",
        icon: "mic",
        activeText: "Muted",
        inactiveText: "Live"
    },
    "hotspot": {
        id: "hotspot",
        label: "Hotspot",
        icon: "wifi_tethering",
        activeText: "Broadcasting",
        inactiveText: "Inactive"
    },
    "record": {
        id: "record",
        label: "Record Screen",
        icon: "radio_button_checked",
        activeText: "Recording",
        inactiveText: "Standby"
    },
    "dnd": {
        id: "dnd",
        label: "Do Not Disturb",
        icon: "notifications_off",
        activeText: "Silent",
        inactiveText: "Active"
    },
    "vpn": {
        id: "vpn",
        label: "VPN Shield",
        icon: "vpn_key",
        activeText: "Protected",
        inactiveText: "Disabled"
    }
})
```

### 5.2 Dynamic Grid Instantiation in `UtilityModule.qml`
Instead of hardcoding 5 rows of buttons, `UtilityModule.qml` generates the quick toggles dynamically:

```qml
Grid {
    Layout.fillWidth: true
    columns: 3
    spacing: 8

    Repeater {
        model: NotchConfig.enabledQuickToggles
        delegate: BentoToggleTile {
            width: (parent.width - (parent.spacing * 2)) / 3
            height: 48
            toggleId: modelData
            def: NotchConfig.quickToggleDefinitions[modelData]
        }
    }
}
```

**Result**: You can change, reorder, or disable toggles simply by editing `NotchConfig.qml`.

---

## 6. Component Specifications & QML Architecture

### 6.1 Reusable UI Primitives

#### A. `BentoPill.qml` (Wi-Fi & Bluetooth Split Tiles)
- **Geometry**: Height 56px, Radius 16px.
- **Left Target (Circle Disc)**: Toggles device radio on/off. Visual state updates instantly with tactile scale animation.
- **Right Target (Label & Chevron)**: Opens sub-view or switches to standalone configuration module.

#### B. `BentoSlider.qml` (Audio & Display Twin Sliders)
- **Geometry**: Height 64px, Radius 16px.
- **Design**: Horizontal capsule slider with an integrated icon on the left, live percentage on the right, and smooth hover fill.
- **Zero Jitter**: Dragging state suppresses external status polling so the slider handle feels fluid and responsive.

#### C. `BentoToggleTile.qml` (Uniform Action Squares)
- **Geometry**: Height 48px, Radius 14px.
- **Design**: Icon on the left, two-line text (Title + State Subtitle) on the right.
- **States**: 
  - *Active*: Highlighted in theme accent color, icon filled, bold typography.
  - *Inactive*: Muted card background (`colCard`), subtle contrast.

---

## 7. Extended Hover Bar (`MainDash.qml`) Streamlining

The persistent hover bar in `MainDash.qml` should reflect this clean separation.

### Current Hover Bar vs. Redesigned Layout
```
[ Current ]
[ 󰣇 Launcher ] [ 1 2 3 Workspaces ] ─── [ Date • Time ] ─── [ 󰘮 Control Center ] [ 󰁹 Battery ]

[ Redesigned ]
[ 󰣇 Apps ] [ 1 2 3 Workspaces ] ─── [ Date • Time ] ─── [ 󱎫 Tools ] [ 󰘮 Controls ] [ 󰁹 Battery ]
```

- **Apps Button (`󰣇`)**: Launches Application Grid (`SUPER + Space`).
- **Workspaces Indicator**: Interactive workspace dots / numbers.
- **Center Clock & DateMark**: Clicking opens `CalendarModule`. When a Pomodoro timer or Screen Recording is active, ambient status appears right here.
- **Tools Button (`󱎫` or `󰘵`)**: Direct trigger for the new **Productivity Deck** (`SUPER + P`).
- **Control Center Button (`󰘮`)**: Direct trigger for the **Bento Control Center** (`SUPER + U`).
- **Battery Pill**: Shows percentage and opens `BatteryModule` on click.

---

## 8. Step-by-Step Implementation Roadmap

### Phase 1: Create `Productivity Deck` Module (`modules/ToolDeck.qml`)
1. Create `quickshell/modules/ToolDeck.qml`.
2. Extract the Pomodoro logic and UI from `UtilityModule.qml` into a dedicated hero widget inside `ToolDeck.qml`.
3. Build quick launcher cards for:
   - Notes (`NotesModule`)
   - Clipboard (`ClipboardModule`)
   - Drop Shelf (`ShelfModule`)
   - Quick OCR snip trigger (`scripts/snip_ocr.sh`)
   - QR code scanner / generator trigger (`QrModule`)
4. Register `"tooldeck"` in `shell.qml`:
   - Add to `getModuleSource(mode)`: `case "tooldeck": return Qt.resolvedUrl("modules/ToolDeck.qml");`
   - Add dimensions to `NotchConfig.qml`: `"tooldeck": { width: 480, height: 440, radius: 26 }`.
   - Add global shortcut: `SUPER + P` in `hypr/modules/keybinds.lua`.

### Phase 2: Refactor `UtilityModule.qml` into Pure Bento Control Center
1. **Remove Clutter**:
   - Delete header shortcut buttons (`Shelf`, `OCR`, `QR`, `Pomo`, `Notes`).
   - Remove duplicate Lock and Power circles from Row 1 and Row 2.
   - Remove embedded Pomodoro subview (lines 1612–1890).
2. **Build Bento Section 1 (Header & System Info)**:
   - Left: "Control Center" title and current network badge.
   - Right: Clean Lock / Power action and Settings trigger.
3. **Build Bento Section 2 (Dual Connectivity Cards)**:
   - Wi-Fi split pill (toggle radio + open full `WifiModule`).
   - Bluetooth split pill (toggle radio + open full `BluetoothModule`).
4. **Build Bento Section 3 (Twin Sliders)**:
   - Side-by-side or cleanly stacked Volume and Brightness cards.
   - Volume includes small device badge (e.g., "Headphones") and click-to-swap audio sinks.
5. **Build Bento Section 4 (Configurable Quick Toggles Grid)**:
   - Implement dynamic `Repeater` over `NotchConfig.enabledQuickToggles`.
   - Wire all existing scripts/commands cleanly (`nmcli`, `hyprsunset`, `hypridle inhibitor`, `pactl`, `wf-recorder`).
6. **Build Bento Section 5 (Footer Status Bar)**:
   - Battery state with time-to-empty / charging status.
   - VPN shield status.

### Phase 3: Shell & Notch Synchronization
1. Update `NotchConfig.qml`:
   - Adjust `modeDimensions["utility"]` to `height: 350`.
   - Update `calculateUtilityHeight(section)` to handle `audio` and `vpn` sub-sheets cleanly.
2. Update `shell.qml`:
   - Ensure all IPC handlers and keybind triggers cleanly switch between `utility` and `tooldeck`.
3. Update `MainDash.qml`:
   - Insert the Productivity Hub trigger icon in the tray container.
4. Synchronize all modified files with `~/.config/quickshell/` and reload via `quickshell/reload.sh`.

---

## 9. Keybinding & Interaction Reference

| Shortcut | Action | Target View |
| :--- | :--- | :--- |
| `SUPER + U` | Toggle Hardware Control Center | `modules/UtilityModule.qml` (Bento Grid) |
| `SUPER + P` | Toggle Productivity Deck | `modules/ToolDeck.qml` (Pomodoro, Notes, Shelf) |
| `SUPER + Space` | Toggle Application Launcher | `modules/Launcher.qml` |
| `SUPER + Shift + M` | Toggle Music Player & Equalizer | `modules/MusicModule.qml` |
| `SUPER + T` | Toggle Theme Selector | `modules/ThemeSelector.qml` |
| `SUPER + W` | Toggle Wallpaper Carousel | `modules/WallpaperSelector.qml` |
| `SUPER + C` | Toggle Clipboard Manager | `modules/ClipboardModule.qml` |
| `SUPER + Escape` / `Click Outside` | Collapse Notch to Idle | `shell.qml: collapseToIdle()` |

---

## 10. Summary of Benefits

1. **70% Less Visual Noise**: Control Center goes from 5 uneven rows with 15+ competing elements down to a calm, balanced Bento layout.
2. **Dedicated Workflow Space**: Pomodoro, Notes, and Shelf gain the screen space they need to be genuinely productive.
3. **Zero Functionality Lost**: Every single script, tool, toggle, and sub-setting is preserved and easier to access.
4. **User Agency**: You can add, remove, or reorder toggles instantly by modifying a single list in `NotchConfig.qml`.
