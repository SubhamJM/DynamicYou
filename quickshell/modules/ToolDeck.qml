import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../"

Item {
    id: toolDeckRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    Keys.onEscapePressed: (event) => {
        if (toolDeckRoot.isEditing) {
            toolDeckRoot.isEditing = false;
        } else {
            root.collapseToIdle();
        }
        event.accepted = true;
    }

    // OLED Neutral Theme Tokens
    readonly property color colBg: "#000000"
    readonly property color colCard: Qt.rgba(255, 255, 255, 0.055)
    readonly property color colCardHover: Qt.rgba(255, 255, 255, 0.11)
    readonly property color colCardActive: Qt.rgba(255, 255, 255, 0.18)
    readonly property color colAccent: Theme.accent
    readonly property color colText: "#f5f5f7"
    readonly property color colSubtext: Qt.rgba(255, 255, 255, 0.65)
    readonly property color colMuted: Qt.rgba(255, 255, 255, 0.40)
    readonly property color colBorder: Qt.rgba(255, 255, 255, 0.08)

    // Edit Mode State
    property bool isEditing: false

    // Hardware State Properties
    property bool nightLightActive: false
    property bool caffeineActive: false
    property bool micMuted: false
    property bool hotspotActive: root.wifiMod ? root.wifiMod.hotspotActive : false

    // Enabled Utilities List
    property var enabledKeys: [
        "screenshot",
        "ocr",
        "colorpicker",
        "record",
        "caffeine",
        "nightlight",
        "mic_mute",
        "dnd",
        "shelf",
        "qr",
        "pomo",
        "notes"
    ]

    readonly property int activeCount: enabledKeys.length
    readonly property int availableCount: availableKeys.length

    // All available utilities catalog
    readonly property var catalogMap: ({
        "screenshot": {
            id: "screenshot",
            name: "Screenshot",
            icon: "crop",
            desc: "Area snip",
            color: "#64d2ff",
            isActive: false,
            action: function() {
                root.collapseToIdle();
                var hubScript = Quickshell.env("HOME") + "/.config/quickshell/scripts/screenshot_hub.sh";
                Quickshell.execDetached(["bash", hubScript]);
            }
        },
        "ocr": {
            id: "ocr",
            name: "OCR Snip",
            icon: "document_scanner",
            desc: "Text snip",
            color: "#38bdf8",
            isActive: false,
            action: function() {
                root.collapseToIdle();
                Quickshell.execDetached(["/bin/sh", "-c", Qt.resolvedUrl("../scripts/snip_ocr.sh").toString().replace("file://", "")]);
            }
        },
        "colorpicker": {
            id: "colorpicker",
            name: "Color Picker",
            icon: "colorize",
            desc: "Pick hex",
            color: "#a78bfa",
            isActive: false,
            action: function() {
                root.collapseToIdle();
                Quickshell.execDetached(["sh", "-c", "sleep 0.15; hyprpicker -a && notify-send 'Color Picker' \"Copied $(wl-paste) to clipboard\""]);
            }
        },
        "record": {
            id: "record",
            name: "Record",
            icon: root.isScreenRecording ? "stop_circle" : "radio_button_checked",
            desc: root.isScreenRecording ? "Recording" : "Screen capture",
            color: "#ff453a",
            isActive: root.isScreenRecording,
            action: function() {
                if (root.isScreenRecording) {
                    root.stopRecording();
                } else {
                    root.startRecording(false);
                }
            }
        },
        "caffeine": {
            id: "caffeine",
            name: "Caffeine",
            icon: "coffee",
            desc: toolDeckRoot.caffeineActive ? "Awake" : "Idle sleep",
            color: "#ff9f0a",
            isActive: toolDeckRoot.caffeineActive,
            action: function() { toolDeckRoot.toggleCaffeine(); }
        },
        "nightlight": {
            id: "nightlight",
            name: "Night Light",
            icon: "nightlight",
            desc: toolDeckRoot.nightLightActive ? "4500K Warm" : "Standard",
            color: "#ffd60a",
            isActive: toolDeckRoot.nightLightActive,
            action: function() { toolDeckRoot.toggleNightLight(); }
        },
        "mic_mute": {
            id: "mic_mute",
            name: "Microphone",
            icon: toolDeckRoot.micMuted ? "mic_off" : "mic",
            desc: toolDeckRoot.micMuted ? "Muted" : "Active",
            color: toolDeckRoot.micMuted ? "#ff453a" : "#30d158",
            isActive: toolDeckRoot.micMuted,
            action: function() { toolDeckRoot.toggleMicMute(); }
        },
        "dnd": {
            id: "dnd",
            name: "Do Not Disturb",
            icon: root.dndEnabled ? "do_not_disturb_on" : "do_not_disturb_off",
            desc: root.dndEnabled ? "Silent" : "Alerts on",
            color: "#bf5af2",
            isActive: root.dndEnabled,
            action: function() { root.dndEnabled = !root.dndEnabled; }
        },
        "hotspot": {
            id: "hotspot",
            name: "Hotspot",
            icon: "wifi_tethering",
            desc: toolDeckRoot.hotspotActive ? "Sharing AP" : "Disabled",
            color: "#30d158",
            isActive: toolDeckRoot.hotspotActive,
            action: function() { toolDeckRoot.toggleHotspot(); }
        },
        "dictation": {
            id: "dictation",
            name: "Dictation",
            icon: "record_voice_over",
            desc: root.isDictationActive ? "Listening" : "AI Voice",
            color: "#ff375f",
            isActive: root.isDictationActive,
            action: function() {
                root.collapseToIdle();
                root.startDictation();
            }
        },
        "shelf": {
            id: "shelf",
            name: "Drop Shelf",
            icon: "inventory_2",
            desc: "File staging",
            color: "#facc15",
            isActive: false,
            action: function() { root.switchMode("shelf", false); }
        },
        "qr": {
            id: "qr",
            name: "QR Code Hub",
            icon: "qr_code_2",
            desc: "Scan / Create",
            color: "#f472b6",
            isActive: false,
            action: function() { root.switchMode("qr", false); }
        },
        "pomo": {
            id: "pomo",
            name: "Focus Timer",
            icon: root.pomoRunning ? (root.pomoPaused ? "pause" : "timer") : "timer",
            desc: root.pomoRunning ? (root.pomoPaused ? "Paused" : root.formatPomoTime(root.pomoSecondsRemaining)) : "25m Sprint",
            color: toolDeckRoot.colAccent,
            isActive: root.pomoRunning,
            action: function() {
                if (root.pomoRunning) {
                    root.togglePomodoroPause();
                } else {
                    root.startPomodoro(25, "focus", "Focus Sprint");
                }
            }
        },
        "notes": {
            id: "notes",
            name: "Scratchpad",
            icon: "edit_note",
            desc: "Quick notes",
            color: "#38bdf8",
            isActive: false,
            action: function() { root.switchMode("notes", false); }
        },
        "clipboard": {
            id: "clipboard",
            name: "Clipboard",
            icon: "assignment",
            desc: "History manager",
            color: "#a6e3a1",
            isActive: false,
            action: function() { root.switchMode("clipboard", false); }
        },
        "theme": {
            id: "theme",
            name: "Themes",
            icon: "palette",
            desc: "Palette switch",
            color: "#c678dd",
            isActive: false,
            action: function() { root.switchMode("theme", false); }
        },
        "taskmgr": {
            id: "taskmgr",
            name: "Task Manager",
            icon: "monitoring",
            desc: "System load",
            color: "#4ade80",
            isActive: false,
            action: function() { root.switchMode("taskmanager", false); }
        }
    })

    readonly property var allCatalogKeys: [
        "screenshot",
        "ocr",
        "colorpicker",
        "record",
        "caffeine",
        "nightlight",
        "mic_mute",
        "dnd",
        "hotspot",
        "dictation",
        "shelf",
        "qr",
        "pomo",
        "notes",
        "clipboard",
        "theme",
        "taskmgr"
    ]

    readonly property var availableKeys: {
        var avail = [];
        for (var i = 0; i < allCatalogKeys.length; i++) {
            var k = allCatalogKeys[i];
            if (enabledKeys.indexOf(k) === -1) {
                avail.push(k);
            }
        }
        return avail;
    }

    // ========================================================
    // HARDWARE PROCESS MONITORS & ACTIONS
    // ========================================================
    Process {
        id: checkNightLight
        running: root.activeMode === "tooldeck"
        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo 'active' || echo 'inactive'"]
        stdout: StdioCollector {
            onStreamFinished: {
                toolDeckRoot.nightLightActive = (this.text.trim() === "active");
            }
        }
    }

    function toggleNightLight() {
        if (nightLightActive) {
            Quickshell.execDetached(["sh", "-c", "killall -9 hyprsunset 2>/dev/null"]);
            nightLightActive = false;
        } else {
            Quickshell.execDetached(["sh", "-c", "killall -9 hyprsunset 2>/dev/null; hyprsunset -t 4500"]);
            nightLightActive = true;
        }
        checkNightLight.running = true;
    }

    Process {
        id: caffeineInhibitor
        running: false
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=quickshell", "--why=Keep Me Awake", "sleep", "infinity"]
    }

    Process {
        id: checkCaffeineState
        running: root.activeMode === "tooldeck"
        command: ["sh", "-c", "if [ -f /tmp/quickshell_keep_awake ]; then if pidof hypridle >/dev/null 2>&1; then rm -f /tmp/quickshell_keep_awake; echo 'inactive'; else echo 'active'; fi; else echo 'inactive'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                toolDeckRoot.caffeineActive = (this.text.trim() === "active");
            }
        }
    }

    function toggleCaffeine() {
        if (caffeineActive) {
            caffeineInhibitor.running = false;
            caffeineActive = false;
            Quickshell.execDetached(["sh", "-c", "rm -f /tmp/quickshell_keep_awake; pidof hypridle >/dev/null 2>&1 || hyprctl dispatch exec hypridle || hypridle &"]);
        } else {
            caffeineActive = true;
            Quickshell.execDetached(["sh", "-c", "touch /tmp/quickshell_keep_awake; killall -9 hypridle 2>/dev/null; brightnessctl -r 2>/dev/null; hyprctl dispatch dpms on 2>/dev/null"]);
            caffeineInhibitor.running = true;
        }
        checkCaffeineState.running = true;
    }

    Process {
        id: fetchMicProcess
        running: root.activeMode === "tooldeck"
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = this.text.toLowerCase();
                toolDeckRoot.micMuted = (txt.indexOf("[muted]") !== -1 || txt.indexOf("mute: yes") !== -1);
            }
        }
    }

    function toggleMicMute() {
        toolDeckRoot.micMuted = !toolDeckRoot.micMuted;
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
        fetchMicProcess.running = true;
    }

    Process {
        id: checkHotspotStatus
        running: root.activeMode === "tooldeck"
        command: ["sh", "-c", "nmcli -t -f TYPE,NAME con show --active | grep -E '^802-11-wireless.*:Hotspot|^wifi.*:Hotspot' || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var isActive = (this.text.trim().length > 0);
                toolDeckRoot.hotspotActive = isActive;
                if (root.wifiMod) root.wifiMod.hotspotActive = isActive;
            }
        }
    }

    function toggleHotspot() {
        var targetState = !toolDeckRoot.hotspotActive;
        toolDeckRoot.hotspotActive = targetState;
        if (root.wifiMod) root.wifiMod.hotspotActive = targetState;
        if (targetState) {
            Quickshell.execDetached(["sh", "-c", "nmcli con up Hotspot 2>/dev/null || nmcli dev wifi hotspot 2>/dev/null"]);
        } else {
            Quickshell.execDetached(["nmcli", "con", "down", "Hotspot"]);
        }
        checkHotspotStatus.running = true;
    }

    // ========================================================
    // PERSISTENCE (UTILITIES STORE)
    // ========================================================
    Process {
        id: loadConfigProcess
        running: root.activeMode === "tooldeck"
        command: ["python3", Qt.resolvedUrl("../scripts/utilities_store.py").toString().replace("file://", ""), "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    if (data && data.enabled && Array.isArray(data.enabled)) {
                        toolDeckRoot.enabledKeys = data.enabled;
                    }
                } catch(e) {
                    console.warn("[ToolDeck] Failed to parse utilities config:", e);
                }
            }
        }
    }

    function removeUtility(key) {
        var current = toolDeckRoot.enabledKeys.slice();
        var idx = current.indexOf(key);
        if (idx !== -1) {
            current.splice(idx, 1);
            toolDeckRoot.enabledKeys = current;
            saveConfig(current);
        }
    }

    function addUtility(key) {
        var current = toolDeckRoot.enabledKeys.slice();
        if (current.indexOf(key) === -1) {
            current.push(key);
            toolDeckRoot.enabledKeys = current;
            saveConfig(current);
        }
    }

    function resetDefaults() {
        var def = [
            "screenshot", "ocr", "colorpicker", "record",
            "caffeine", "nightlight", "mic_mute", "dnd",
            "shelf", "qr", "pomo", "notes"
        ];
        toolDeckRoot.enabledKeys = def;
        saveConfig(def);
    }

    function saveConfig(keys) {
        var jsonStr = JSON.stringify(keys);
        Quickshell.execDetached([
            "python3",
            Qt.resolvedUrl("../scripts/utilities_store.py").toString().replace("file://", ""),
            "save",
            jsonStr
        ]);
    }

    // ========================================================
    // UI LAYOUT
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 8

        // 1. HEADER ROW: Title, Subtitle, Edit Mode Toggle, Close
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Hub Icon
            Rectangle {
                width: 28; height: 28; radius: 8
                color: Qt.alpha(toolDeckRoot.colAccent, 0.16)
                Layout.alignment: Qt.AlignVCenter
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "widgets"
                    iconSize: 16
                    color: toolDeckRoot.colAccent
                }
            }

            // Title & Status
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: "Mini Utilities"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: toolDeckRoot.colText
                }

                Text {
                    text: toolDeckRoot.isEditing ? "Tap (−) to remove, (+) below to add" : (toolDeckRoot.activeCount + " active tools • instant shortcuts")
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    color: toolDeckRoot.isEditing ? toolDeckRoot.colAccent : toolDeckRoot.colMuted
                }
            }

            // Edit / Done Action Button
            Rectangle {
                Layout.preferredWidth: editRow.implicitWidth + 16
                Layout.preferredHeight: 26
                radius: 13
                color: toolDeckRoot.isEditing
                    ? Qt.alpha(toolDeckRoot.colAccent, 0.22)
                    : (editMouse.containsMouse ? toolDeckRoot.colCardHover : toolDeckRoot.colCard)
                border.width: toolDeckRoot.isEditing ? 1 : 0
                border.color: toolDeckRoot.colAccent
                scale: editMouse.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 80 } }

                Row {
                    id: editRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        text: toolDeckRoot.isEditing ? "check" : "tune"
                        iconSize: 14
                        color: toolDeckRoot.isEditing ? toolDeckRoot.colAccent : toolDeckRoot.colText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: toolDeckRoot.isEditing ? "Done" : "Edit"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: toolDeckRoot.isEditing ? toolDeckRoot.colAccent : toolDeckRoot.colText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: editMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toolDeckRoot.isEditing = !toolDeckRoot.isEditing
                }
            }

            // Close Button
            Rectangle {
                width: 26; height: 26; radius: 13
                color: closeMouse.containsMouse ? toolDeckRoot.colCardHover : "transparent"
                scale: closeMouse.pressed ? 0.90 : 1.0

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 16
                    color: toolDeckRoot.colMuted
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (toolDeckRoot.isEditing) toolDeckRoot.isEditing = false;
                        root.collapseToIdle();
                    }
                }
            }
        }

        // 2. ACTIVE UTILITIES GRID (Dynamic columns & rows)
        Flow {
            id: activeFlow
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: toolDeckRoot.enabledKeys

                delegate: Rectangle {
                    id: tileRect
                    readonly property var def: toolDeckRoot.catalogMap[modelData] || ({
                        name: modelData, icon: "widgets", desc: "", color: toolDeckRoot.colAccent, isActive: false, action: function(){}
                    })

                    width: Math.floor((activeFlow.width - (8 * 2)) / 3)
                    height: 52
                    radius: 14
                    color: def.isActive
                        ? Qt.rgba(toolDeckRoot.colAccent.r, toolDeckRoot.colAccent.g, toolDeckRoot.colAccent.b, tileMouse.containsMouse ? 0.24 : 0.16)
                        : (tileMouse.containsMouse ? toolDeckRoot.colCardHover : toolDeckRoot.colCard)
                    border.width: toolDeckRoot.isEditing ? 1 : 0
                    border.color: Qt.rgba(255, 255, 255, 0.10)

                    scale: tileMouse.pressed ? 0.96 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 8

                        // Icon Disc
                        Rectangle {
                            width: 32; height: 32; radius: 10
                            color: def.isActive
                                ? toolDeckRoot.colAccent
                                : Qt.rgba(255, 255, 255, 0.08)
                            Layout.alignment: Qt.AlignVCenter

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: def.icon
                                iconSize: 18
                                color: def.isActive ? "#101318" : (def.color || toolDeckRoot.colText)
                            }
                        }

                        // Labels
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: def.name
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: def.isActive ? toolDeckRoot.colAccent : toolDeckRoot.colText
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: def.desc
                                font.family: "Noto Sans"
                                font.pixelSize: 9
                                color: def.isActive ? Qt.lighter(toolDeckRoot.colAccent, 1.1) : toolDeckRoot.colMuted
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Remove Chip Badge (Visible in Edit Mode)
                    Rectangle {
                        visible: toolDeckRoot.isEditing
                        width: 18; height: 18; radius: 9
                        anchors.top: parent.top; anchors.topMargin: -4
                        anchors.right: parent.right; anchors.rightMargin: -4
                        color: removeMouse.containsMouse ? "#ff453a" : Qt.rgba(255, 69, 58, 0.85)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "remove"
                            iconSize: 12
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: removeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toolDeckRoot.removeUtility(modelData)
                        }
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (toolDeckRoot.isEditing) {
                                toolDeckRoot.removeUtility(modelData);
                            } else {
                                def.action();
                            }
                        }
                    }
                }
            }
        }

        // 3. AVAILABLE UTILITIES POOL (Visible only in Edit Mode)
        ColumnLayout {
            Layout.fillWidth: true
            visible: toolDeckRoot.isEditing
            spacing: 6

            // Section divider & header
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                Text {
                    text: "AVAILABLE TO ADD"
                    font.family: "Noto Sans"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: toolDeckRoot.colMuted
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.08)
                }

                // Reset Defaults Button
                Rectangle {
                    width: resetText.implicitWidth + 12
                    height: 20
                    radius: 10
                    color: resetMouse.containsMouse ? toolDeckRoot.colCardHover : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.12)

                    Text {
                        id: resetText
                        anchors.centerIn: parent
                        text: "Reset"
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: toolDeckRoot.colSubtext
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toolDeckRoot.resetDefaults()
                    }
                }
            }

            // Pool Grid
            Flow {
                id: poolFlow
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: toolDeckRoot.availableKeys

                    delegate: Rectangle {
                        readonly property var def: toolDeckRoot.catalogMap[modelData] || ({
                            name: modelData, icon: "widgets", desc: "", color: toolDeckRoot.colText
                        })

                        width: Math.floor((poolFlow.width - (8 * 2)) / 3)
                        height: 44
                        radius: 12
                        color: poolMouse.containsMouse ? toolDeckRoot.colCardHover : Qt.rgba(255, 255, 255, 0.035)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.06)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 6

                            MaterialSymbol {
                                text: def.icon
                                iconSize: 16
                                color: def.color || toolDeckRoot.colMuted
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: def.name
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: toolDeckRoot.colSubtext
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: poolMouse.containsMouse ? "#30d158" : Qt.rgba(48, 209, 88, 0.20)

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "add"
                                    iconSize: 12
                                    color: poolMouse.containsMouse ? "#101318" : "#30d158"
                                }
                            }
                        }

                        MouseArea {
                            id: poolMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toolDeckRoot.addUtility(modelData)
                        }
                    }
                }
            }

            // Empty Pool Message
            Text {
                visible: toolDeckRoot.availableCount === 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "All available utilities are currently enabled"
                font.family: "Noto Sans"
                font.pixelSize: 10
                color: toolDeckRoot.colMuted
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }
        }
    }
}
