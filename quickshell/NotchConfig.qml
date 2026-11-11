pragma Singleton
import QtQuick
import Quickshell

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
    readonly property string scriptsDir: {
        var localPath = Qt.resolvedUrl("scripts").toString().replace(/^file:\/\//, "");
        return (localPath && localPath.length > 0) ? localPath : ((Quickshell.env("HOME") || "") + "/.config/quickshell/scripts");
    }

    // ==========================================
    // 4. STATIC NOTCH BASE DIMENSIONS
    // ==========================================
    readonly property int cornerCurveRadius: 12     // Outer inverse wing curves radius
    readonly property int baseExclusiveZone: 32     // Wayland layer shell exclusive reservation

    readonly property var modeDimensions: ({
        "idle":          { width: 184, height: 32,  radius: 16 },
		"hover":         { width: 440, height: 44,  radius: 22 },
		"switcher":      { width: 800, height: 420, radius: 22 },
        "launcher":      { width: 640, height: 215, radius: 22 },
        "theme":         { width: 880, height: 360, radius: 24 },
        "wallpaper":     { width: 880, height: 360, radius: 24 },
        "engine":        { width: 840, height: 480, radius: 22 },
        "transition":    { width: 440, height: 320, radius: 22 },
        "osd":           { width: 280, height: 40,  radius: 16 },
        "wifi":          { width: 440, height: 460, radius: 22 }, 
        "bluetooth":     { width: 440, height: 360, radius: 22 },
        "recorder":      { width: 440, height: 270, radius: 22 },
        "battery":       { width: 440, height: 348, radius: 22 },
        "powermenu":     { width: 440, height: 104, radius: 22 },
        "calendar":      { width: 686, height: 440, radius: 22 },
        "clipboard":     { width: 440, height: 440, radius: 22 },
        "utility":       { width: 440, height: 350, radius: 24 },
        "music":         { width: 560, height: 285, radius: 22 },
        "notes":         { width: 680, height: 480, radius: 22 },
        "cheatsheet":    { width: 800, height: 440, radius: 22 },
        "notifications": { width: 440, height: 380, radius: 22 },
        "taskmanager":   { width: 880, height: 620, radius: 22 }
    })

    function calculateUtilityHeight(activeSection) {
        if (activeSection === "audio") return 400;
        if (activeSection === "vpn") return 300;
        if (activeSection === "pomo") return 370;
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
        return Math.min(520, Math.max(240, 120 + (count * 72)));
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

