pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: config

    // ==========================================
    // 1. INIR-INSPIRED MOTION CURVES & EASINGS
    // ==========================================
    // Rounded starts and stops for the expanding and collapsing bar.
    readonly property var curveMorph: [0.30, 0, 0.20, 1, 1, 1]
    readonly property var curveAccel: [0.38, 0, 0.42, 1, 1, 1]

    // Emphasized deceleration for short effects.
    readonly property var curveDecel: [0.05, 0.7, 0.1, 1, 1, 1]

    // Expressive spatial overshoot: cubic-bezier(0.38, 1.21, 0.22, 1)
    readonly property var curveSpatial: [0.38, 1.21, 0.22, 1, 1, 1]

    // Non-overshooting smooth effects curve for fades, colors, and opacity transitions
    readonly property var curveEffects: [0.34, 0.80, 0.34, 1, 1, 1]

    // Backward-compatibility alias
    readonly property var motionCurve: curveMorph

    // ==========================================
    // 2. CONTEXTUAL & INTUITION-BASED ANIMATION DURATIONS (ms)
    // ==========================================
    // Opening / expansion.
    readonly property int animNotchEnter: 260

    // Closing / collapse to idle.
    readonly property int animNotchExit: 210

    // Switching between two expanded cards: Smooth glide (300ms)
    readonly property int animNotchSwitch: 300

    // OSD Toast mode: Snappy compact toast morph (180ms)
    readonly property int animOsdMorph: 180

    // Content fade-in when expanding: starts with graceful deceleration
    readonly property int animContentEnter: 145

    // Content fade-out when closing: dissolves fast before notch collapses so cards don't clip
    readonly property int animContentExit: 95

    // Dash idle layer fade transitions
    readonly property int animDashEnter: 180
    readonly property int animDashExit: 100

    // Backward compatibility aliases
    readonly property int animNotchResize: 360
    readonly property int animDashFade: 120
    readonly property int animModulesFade: 220
    readonly property int animColor: 150
    readonly property int animScale: 140

    // ==========================================
    // 3. AUTO-COLLAPSE & POPUP TIMERS (ms)
    // ==========================================
    readonly property int timerAutoCollapse: 0      // Instantaneous collapse on mouse leave
    readonly property int timerNotifPopup: 4000     // How long the notification popup island remains visible
    readonly property int timerStartupGrace: 600    // Grace window on startup to suppress notification replays
    readonly property int timerOsdSettle: 150       // OSD transition settle debounce
    readonly property int timerOsdHide: 1200        // Inactivity timeout to auto-hide OSD bar
    readonly property int timerWorkspacePeek: 800  // Duration to show workspaces on workspace switch
    readonly property int timerBtPopup: 1500        // Duration for Bluetooth connect island popup
    readonly property int timerPowerPopup: 1500     // Duration for Power/Charging connected island popup
    readonly property int timerNetPopup: 1500       // Duration for Network handoff island popup
    readonly property int timerIslandText: 3500     // Duration for Island textual info labels
    readonly property int timerFullscreenHideGrace: 250 // Duration before auto-hiding when leaving top hover in fullscreen
    readonly property string scriptsDir: {
        var localPath = Qt.resolvedUrl("scripts").toString().replace(/^file:\/\//, "");
        return (localPath && localPath.length > 0) ? localPath : ((Quickshell.env("HOME") || "") + "/.config/quickshell/scripts");
    }

    // ==========================================
    // 4. STATIC NOTCH BASE DIMENSIONS
    // ==========================================
    readonly property int cornerCurveRadius: 12     // Outer inverse wing curves radius
    readonly property int baseExclusiveZone: 38     // Wayland layer shell exclusive reservation

    readonly property var modeDimensions: ({
        "idle":          { width: 184, height: 38,  radius: 19 },
		"hover":         { width: 440, height: 44,  radius: 22 },
		"switcher":      { width: 800, height: 420, radius: 22 },
        "launcher":      { width: 640, height: 215, radius: 22 },
        "theme":         { width: 620, height: 204, radius: 24 },
        "wallpaper":     { width: 880, height: 400, radius: 24 },
        "wallsort":      { width: 540, height: 362, radius: 22 },
        "lockscreen":    { width: 880, height: 360, radius: 24 },
        "engine":        { width: 840, height: 480, radius: 22 },
        "transition":    { width: 440, height: 320, radius: 22 },
        "osd":           { width: 340, height: 40,  radius: 20 },
        "wifi":          { width: 440, height: 460, radius: 22 },
        "bluetooth":     { width: 440, height: 360, radius: 22 },
        "recorder":      { width: 408, height: 350, radius: 24 },
        "battery":       { width: 440, height: 460, radius: 22 },
        "powermenu":     { width: 452, height: 106, radius: 24 },
        "calendar":      { width: 720, height: 492, radius: 24 },
        "clipboard":     { width: 480, height: 500, radius: 24 },
        "utility":       { width: 408, height: 350, radius: 24 },
        "music":         { width: 560, height: 285, radius: 22 },
        "notes":         { width: 680, height: 480, radius: 22 },
        "cheatsheet":    { width: 800, height: 440, radius: 22 },
        "notifications": { width: 440, height: 380, radius: 22 },
        "wallhaven":     { width: 820, height: 860, radius: 24 },
        "taskmanager":   { width: 900, height: 660, radius: 22 }
    })

    function revealBetween(value, start, end) {
        const progress = Math.max(0, Math.min(1, (value - start) / (end - start)));
        return progress * progress * (3 - 2 * progress);
    }

    function popupOpenDuration(width, height) {
        const span = Math.max(height, width * 0.55);
        return animNotchEnter + Math.round(Math.max(-32, Math.min(34, (span - 350) * 0.15)));
    }

    function popupReveal(mode, width, height, inset, surfaceWidth, surfaceHeight) {
        const widthRatio = surfaceWidth / Math.max(1, width);
        const heightRatio = surfaceHeight / Math.max(1, height);
        switch (mode) {
        case "theme":
        case "wallpaper":
        case "lockscreen":
        case "transition":
        case "switcher":
            // The preview is centered, with controls on both sides or below it.
            return Math.min(revealBetween(widthRatio, 0.71, 0.97), revealBetween(heightRatio, 0.56, 0.94));
        case "powermenu":
            // The short action row appears together.
            return Math.min(revealBetween(widthRatio, 0.70, 0.94), revealBetween(heightRatio, 0.55, 0.91));
        default:
            // Keep the top controls in place and let the surface expose the rest of the panel.
            const start = Math.min(height * 0.5, inset + 44);
            const end = Math.max(start + 1, Math.min(height * 0.9, inset + 145));
            return Math.min(revealBetween(widthRatio, 0.60, 0.95), revealBetween(surfaceHeight, start, end));
        }
    }

    function calculateUtilityHeight(activeSection) {
        if (activeSection === "audio") return 400;
        if (activeSection === "vpn") return 300;
        return 350;
    }

    // ==========================================
    // 5. DYNAMIC HEIGHT CALCULATORS
    // ==========================================
    // Notification banner active in Dash mode
    readonly property int heightNotifBanner: 54

    // Dynamic Module Heights (Min / Max bounds and per-item multipliers)
    function calculateNotificationsHeight(count) {
        if (count === 0) return 200;
        return Math.min(480, Math.max(200, 50 + (count * 76)));
    }

    function calculateClipboardHeight(count) {
        if (count === 0) return 260;
        return Math.min(540, Math.max(280, 110 + (count * 64)));
    }

    function calculateLauncherHeight(count, allAppsLength, browsing = false) {
        if (browsing) return 215;
        if (count <= 0) return 140;
        if (count === 1) return 170;
        if (count === 2) return 236;
        if (count === 3) return 286;
        if (count === 4) return 336;
        if (count === 5) return 386;
        if (count === 6) return 416;
        return 436;
    }

    function calculateRecorderHeight(hasLastRecording, isRecording) {
        var base = isRecording ? 162 : 174;
        var cardH = hasLastRecording ? 68 : 38;
        return base + cardH + 28;
    }

    function calculateBluetoothHeight(devices, stateMap) {
        var btCount = devices ? (devices.count !== undefined ? devices.count : devices.length) : 0;
        if (btCount === 0) return 285;

        var listItemsHeight = 0;
        for (var i = 0; i < btCount; i++) {
            var dev = (devices.get) ? devices.get(i) : devices[i];
            var devMac = dev ? (dev.mac || "") : "";
            var expanded = devMac && stateMap && stateMap[devMac] && stateMap[devMac].isExpanded;
            listItemsHeight += (expanded ? 92 : 50) + 6;
        }
        return Math.min(480, Math.max(285, 160 + listItemsHeight + 12));
    }

    function calculateWifiHeight(activeTab, wifiEnabled, modelCount, listContentHeight, hasEthernet) {
        if (activeTab === "hotspot") return 380;
        if (!wifiEnabled) return 240;
        if (modelCount === 0) return hasEthernet ? 310 : 260;
        var base = hasEthernet ? 160 : 110;
        var effectiveList = (listContentHeight > 0) ? listContentHeight : (modelCount * 56);
        var dynamicListHeight = Math.min(430, Math.max(120, effectiveList));
        return Math.min(540, Math.max(hasEthernet ? 340 : 300, base + dynamicListHeight));
    }

    function calculateTaskManagerHeight(activeTab, modelCount, listContentHeight) {
        return 620;
    }

    // ==========================================
    // 6. NOTCH SHADOW CONFIGURATION
    // ==========================================
    readonly property bool shadowEnabled: true
    readonly property color shadowColor: "#000000"
    readonly property real shadowOpacity: 0.65
    readonly property real shadowBlur: 0.48
    readonly property real shadowVerticalOffset: 2.5
    readonly property real shadowHorizontalOffset: 0
}

