pragma Singleton
import QtQuick

QtObject {
    id: config

    // ==========================================
    // 1. GLOBAL MOTION CURVES & EASINGS
    // ==========================================
    // Caelestia / Material 3 emphasized-decelerate: cubic-bezier(0.05, 0.7, 0.1, 1)
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    // ==========================================
    // 2. GLOBAL ANIMATION DURATIONS (ms)
    // ==========================================
    readonly property int animNotchResize: 260      // Width / height transition of the notch surface (Iris snappy morph)
    readonly property int animDashFade: 90          // Quick cross-fade for the persistent dash bar
    readonly property int animModulesFade: 100      // Cross-fade for the expanded module body
    readonly property int animColor: 150            // Standard button & hover color transitions
    readonly property int animScale: 140            // Quick press/hover scale transitions

    // ==========================================
    // 3. AUTO-COLLAPSE & POPUP TIMERS (ms)
    // ==========================================
    readonly property int timerAutoCollapse: 0      // Instantaneous collapse on mouse leave
    readonly property int timerNotifPopup: 1600     // How long the notification popup island remains visible
    readonly property int timerStartupGrace: 600    // Grace window on startup to suppress notification replays
    readonly property int timerOsdSettle: 150       // OSD transition settle debounce
    readonly property int timerOsdHide: 1200        // Inactivity timeout to auto-hide OSD bar
    readonly property int timerWorkspacePeek: 800  // Duration to show workspaces on workspace switch
    readonly property int timerBtPopup: 1500        // Duration for Bluetooth connect island popup
    readonly property int timerPowerPopup: 1500     // Duration for Power/Charging connected island popup
    readonly property int timerNetPopup: 1500       // Duration for Network handoff island popup
    readonly property int timerIslandText: 3500     // Duration for Island textual info labels
    readonly property int timerFullscreenHideGrace: 250 // Duration before auto-hiding when leaving top hover in fullscreen

    // ==========================================
    // 4. STATIC NOTCH BASE DIMENSIONS
    // ==========================================
    readonly property int cornerCurveRadius: 12     // Outer inverse wing curves radius
    readonly property int baseExclusiveZone: 32     // Wayland layer shell exclusive reservation

    readonly property var modeDimensions: ({
        "idle":          { width: 184, height: 32,  radius: 16 },
		"hover":         { width: 460, height: 42,  radius: 21 },
		"switcher":      { width: 800, height: 420, radius: 14 },
        "launcher":      { width: 560, height: 246, radius: 22 },
        "theme":         { width: 660, height: 200, radius: 14 },
        "wallpaper":     { width: 760, height: 320, radius: 12 },
        "transition":    { width: 440, height: 320, radius: 12 },
        "osd":           { width: 280, height: 40,  radius: 16 },
        "wifi":          { width: 420, height: 380, radius: 26 }, 
        "bluetooth":     { width: 420, height: 380, radius: 26 },
        "recorder":      { width: 420, height: 275, radius: 26 },
        "battery":       { width: 460, height: 285, radius: 26 },
        "powermenu":     { width: 460, height: 108, radius: 24 },
        "calendar":      { width: 320, height: 280, radius: 12 },
        "clipboard":     { width: 460, height: 380, radius: 12 },
        "utility":       { width: 484, height: 342, radius: 26 },
        "music":         { width: 480, height: 265, radius: 26 },
        "notes":         { width: 680, height: 480, radius: 14 },
        "cheatsheet":    { width: 800, height: 440, radius: 14 },
        "notifications": { width: 460, height: 380, radius: 26 },
        "taskmanager":   { width: 800, height: 540, radius: 18 }
    })

    function calculateUtilityHeight(activeSection) {
        if (activeSection === "audio") return 384;
        if (activeSection === "vpn") return 254;
        if (activeSection === "pomo") return 360;
        return 342;
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
        if (count === 0) return 220;
        return Math.min(440, Math.max(180, 66 + (count * 48)));
    }

    function calculateLauncherHeight(count, allAppsLength, browsing = false) {
        if (browsing) return 246;
        if (count <= 0) return 128;
        if (count === 1) return 156;
        if (count === 2) return 224;
        if (count === 3) return 266;
        if (count === 4) return 308;
        if (count === 5) return 350;
        if (count === 6) return 392;
        return 436;
    }

    function calculateRecorderHeight(recordAudio, isDropdownOpen, isRecording) {
        if (isRecording) return 210;
        if (recordAudio && isDropdownOpen) return 360;
        if (recordAudio) return 310;
        return 270;
    }

    function calculateBluetoothHeight(devices, stateMap) {
        var btCount = devices ? devices.length : 0;
        if (btCount === 0) return 260;

        var listItemsHeight = 0;
        for (var i = 0; i < btCount; i++) {
            var dev = devices[i];
            var expanded = stateMap && stateMap[dev.mac] && stateMap[dev.mac].isExpanded;
            listItemsHeight += (expanded ? 92 : 50) + 6;
        }
        return Math.min(460, Math.max(260, 160 + listItemsHeight));
    }

    function calculateWifiHeight(activeTab, wifiEnabled, modelCount, listContentHeight) {
        if (activeTab === "hotspot") return 415;
        if (!wifiEnabled) return 260;
        if (modelCount === 0) return 280;
        var base = 195;
        var estimated = modelCount * 68;
        var effectiveList = Math.max(listContentHeight || 0, estimated);
        var dynamicListHeight = Math.min(320, Math.max(70, effectiveList));
        return Math.min(500, Math.max(260, base + dynamicListHeight));
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

