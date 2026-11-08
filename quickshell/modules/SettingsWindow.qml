import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../"

// ────────────────────────────────────────────────────────────
// The Goat Expressive Settings Window Architecture
// Complete control center covering every feature of Dynamic-You Shell
// and Hyprland Compositor, featuring an interactive Keybindings catalog.
// ────────────────────────────────────────────────────────────
Rectangle {
    id: root

    signal closeRequested()

    width: 1040
    height: 680
    radius: 20
    color: "#111114"
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.10)
    clip: true

    // State properties
    property string activePageId: "keybinds"
    function setPage(pageId) {
        if (pageId && pageId.length > 0) {
            root.activePageId = pageId;
            contentFlick.contentY = 0;
        }
    }
    property string searchQuery: ""
    property string keybindSearch: ""
    property string selectedKeybindCat: "All"
    readonly property var btAdapter: (typeof Bluetooth !== "undefined") ? Bluetooth.defaultAdapter : null
    property var wifiStatus: ({ "radio": true, "connected_ssid": "", "active_ip": "", "active_dev": "wlan0" })
    property var hyprConfig: ({
        "gaps_in": 6,
        "gaps_out": 12,
        "border_size": 2,
        "active_opacity": 1.0,
        "inactive_opacity": 0.9,
        "blur_enabled": 0,
        "blur_size": 8,
        "blur_passes": 2,
        "animations_enabled": true,
        "touchpad_tap": true,
        "natural_scroll": true,
        "disable_while_typing": true,
        "sensitivity": 0.0
    })
    property var keybindsList: []

    // Helper command runners
    Process { id: hyprExecProc }

    function setHyprKeyword(keyword, val) {
        hyprExecProc.command = ["hyprctl", "keyword", keyword, String(val)];
        hyprExecProc.running = false;
        hyprExecProc.running = true;
    }

    function runShellCmd(cmdArr) {
        hyprExecProc.command = cmdArr;
        hyprExecProc.running = false;
        hyprExecProc.running = true;
    }

    // Query Wi-Fi Status
    Process {
        id: wifiStatusProc
        running: false
        command: ["python3", Quickshell.shellDir + "/scripts/wifi_manager.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.wifiStatus = JSON.parse(this.text.trim());
                } catch(e) {}
            }
        }
    }

    Timer {
        id: wifiReloadTimer
        interval: 1500
        repeat: false
        onTriggered: wifiStatusProc.running = true
    }

    // Query Hyprland Options on Open
    Process {
        id: hyprQueryProc
        running: false
        command: ["python3", "-c", "import json, subprocess
def get(k):
    try: return json.loads(subprocess.check_output(['hyprctl', '-j', 'getoption', k], text=True))
    except: return {}
res = {
    'gaps_in': 6,
    'gaps_out': 12,
    'border_size': get('general:border_size').get('int', 2),
    'active_opacity': get('decoration:active_opacity').get('float', 1.0),
    'inactive_opacity': get('decoration:inactive_opacity').get('float', 0.9),
    'blur_enabled': get('decoration:blur:enabled').get('int', 0),
    'blur_size': get('decoration:blur:size').get('int', 8),
    'blur_passes': get('decoration:blur:passes').get('int', 2),
    'animations_enabled': get('animations:enabled').get('bool', True),
    'touchpad_tap': get('input:touchpad:tap-to-click').get('bool', True),
    'natural_scroll': get('input:touchpad:natural_scroll').get('bool', True),
    'disable_while_typing': get('input:touchpad:disable_while_typing').get('bool', True),
    'sensitivity': get('input:sensitivity').get('float', 0.0)
}
print(json.dumps(res))
"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.hyprConfig = JSON.parse(this.text.trim());
                } catch(e) {}
            }
        }
    }

    // Query Keybinds via keybinds_parser.py
    Process {
        id: keybindsProc
        running: false
        command: ["python3", Quickshell.shellDir + "/scripts/keybinds_parser.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keybindsList = JSON.parse(this.text.trim());
                    contentFlick.contentY = 0;
                } catch(e) {}
            }
        }
    }

    Component.onCompleted: {
        hyprQueryProc.running = true;
        keybindsProc.running = true;
        wifiStatusProc.running = true;
        contentFlick.contentY = 0;
    }

    onVisibleChanged: {
        if (visible) {
            hyprQueryProc.running = true;
            keybindsProc.running = true;
            wifiStatusProc.running = true;
            contentFlick.contentY = 0;
        }
    }

    onActivePageIdChanged: {
        contentFlick.contentY = 0;
    }

    // Filtered Keybinds computation
    readonly property var filteredKeybinds: {
        var q = (root.keybindSearch || "").toLowerCase().trim();
        var cat = root.selectedKeybindCat;
        return root.keybindsList.filter(function(kb) {
            if (cat !== "All" && kb.cat !== cat) return false;
            if (!q) return true;
            var desc = (kb.desc || "").toLowerCase();
            var key = (kb.key || "").toLowerCase();
            var cmd = (kb.cmd || "").toLowerCase();
            return desc.indexOf(q) !== -1 || key.indexOf(q) !== -1 || cmd.indexOf(q) !== -1;
        });
    }

    // Navigation Structure (Matching The Goat Registry)
    readonly property var navGroups: [
        {
            name: "Look & Feel",
            id: "appearance",
            pages: [
                { id: "themes", name: "Colors & Themes", icon: "palette" }
            ]
        },
        {
            name: "Shell & Modules",
            id: "modules",
            pages: [
                { id: "notch", name: "Dynamic Notch", icon: "water_drop" },
                { id: "bar", name: "Top Bar & Dash", icon: "space_bar" },
                { id: "launcher", name: "Launcher & Clipboard", icon: "search" }
            ]
        },
        {
            name: "Hyprland Compositor",
            id: "hyprland",
            pages: [
                { id: "keybinds", name: "Keybinds & Shortcuts", icon: "keyboard" },
                { id: "tiling", name: "Windows & Tiling", icon: "rule" },
                { id: "animations", name: "Animations & Blur", icon: "auto_awesome" },
                { id: "input", name: "Input & Touchpad", icon: "touch_app" }
            ]
        },
        {
            name: "Hardware & System",
            id: "hardware",
            pages: [
                { id: "battery", name: "Battery & Power", icon: "battery_charging_full" },
                { id: "network", name: "Bluetooth & Network", icon: "bluetooth" },
                { id: "displays", name: "Displays & Audio", icon: "monitor" }
            ]
        },
        {
            name: "About & Actions",
            id: "about_group",
            pages: [
                { id: "about", name: "System Info & Actions", icon: "info" }
            ]
        }
    ]

    // Keyboard support
    focus: true
    Keys.onEscapePressed: (event) => {
        root.closeRequested();
        event.accepted = true;
    }

    // ────────────────────────────────────────────────────────────
    // 1. TOP HEADER (User Profile, Search Bar, Close Button)
    // ────────────────────────────────────────────────────────────
    Item {
        id: headerRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56

        // User Profile Tile
        Rectangle {
            id: userChip
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 210
            height: 40
            radius: 12
            color: userArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.08)

            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 10
                spacing: 10

                Item {
                    width: 26
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 13
                        color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"

                        Text {
                            anchors.centerIn: parent
                            text: "K"
                            font.bold: true
                            font.pixelSize: 13
                            color: "#121214"
                        }
                    }

                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: "#30d158"
                        border.width: 1.5
                        border.color: "#111114"
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "kuro"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.bold: true
                        font.pixelSize: 12
                        color: "#ffffff"
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: "NixOS · Hyprland"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 10
                        color: Qt.rgba(255, 255, 255, 0.50)
                        renderType: Text.NativeRendering
                    }
                }
            }

            MouseArea {
                id: userArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.activePageId = "about"
            }
        }

        // Global Settings Search Bar
        Rectangle {
            id: searchBarBox
            anchors.left: userChip.right
            anchors.leftMargin: 12
            anchors.right: closeBtn.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            height: 38
            radius: 19
            color: searchInput.activeFocus ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.045)
            border.width: 1
            border.color: searchInput.activeFocus ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.10)

            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    iconSize: 18
                    color: searchInput.activeFocus ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.45)
                }

                TextInput {
                    id: searchInput
                    width: parent.width - 60
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                    font.pixelSize: 12
                    selectByMouse: true
                    onTextChanged: {
                        root.searchQuery = text;
                        if (text.trim() !== "") {
                            root.keybindSearch = text;
                            root.activePageId = "keybinds";
                        }
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: !searchInput.text && !searchInput.activeFocus
                        text: "Search settings, keybindings, compositor options..."
                        color: Qt.rgba(255, 255, 255, 0.35)
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }
                }

                MaterialSymbol {
                    visible: searchInput.text !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "close"
                    iconSize: 16
                    color: Qt.rgba(255, 255, 255, 0.50)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = "";
                            root.searchQuery = "";
                            root.keybindSearch = "";
                        }
                    }
                }
            }
        }

        // Close Button
        Rectangle {
            id: closeBtn
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 17
            color: closeMouse.containsMouse ? Qt.rgba(255, 69, 58, 0.20) : Qt.rgba(255, 255, 255, 0.06)
            border.width: 1
            border.color: closeMouse.containsMouse ? "#ff453a" : "transparent"
            scale: closeMouse.pressed ? 0.92 : (closeMouse.containsMouse ? 1.05 : 1.0)

            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 120 } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: 16
                color: closeMouse.containsMouse ? "#ff453a" : "#ffffff"
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.closeRequested()
            }
        }
    }

    // Hairline divider
    Rectangle {
        id: topDivider
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(255, 255, 255, 0.08)
    }

    // ────────────────────────────────────────────────────────────
    // 2. MAIN LAYOUT (Left Sidebar + Right Content Area)
    // ────────────────────────────────────────────────────────────
    Item {
        anchors.top: topDivider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14

        // ════════════════════════════════════════════════════════
        // SIDEBAR (Left 226px)
        // ════════════════════════════════════════════════════════
        Rectangle {
            id: sidebarBox
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 226
            radius: 16
            color: Qt.rgba(255, 255, 255, 0.03)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.06)

            Flickable {
                id: sidebarFlick
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: width
                contentHeight: sidebarCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: sidebarCol
                    width: parent.width
                    spacing: 12

                    Repeater {
                        model: root.navGroups

                        Column {
                            id: groupCol
                            width: parent.width
                            spacing: 4

                            property bool collapsed: false

                            Item {
                                width: parent.width
                                height: 24

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8

                                    Text {
                                        width: parent.width - 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name.toUpperCase()
                                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: Qt.rgba(255, 255, 255, 0.40)
                                        renderType: Text.NativeRendering
                                    }

                                    MaterialSymbol {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "keyboard_arrow_down"
                                        iconSize: 14
                                        color: Qt.rgba(255, 255, 255, 0.35)
                                        rotation: groupCol.collapsed ? -90 : 0
                                        Behavior on rotation { NumberAnimation { duration: 150 } }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: groupCol.collapsed = !groupCol.collapsed
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 2
                                visible: !groupCol.collapsed

                                Repeater {
                                    model: modelData.pages

                                    Rectangle {
                                        id: navBtn
                                        width: parent.width
                                        height: 36
                                        radius: 10

                                        readonly property bool isSelected: root.activePageId === modelData.id
                                        color: isSelected
                                            ? ((typeof Theme !== "undefined" && Theme.accent) ? Qt.alpha(Theme.accent, 0.16) : Qt.rgba(122, 162, 247, 0.16))
                                            : (navMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            MaterialSymbol {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.icon
                                                iconSize: 18
                                                color: navBtn.isSelected
                                                    ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7")
                                                    : (navMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.70))
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.name
                                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                                font.pixelSize: 12
                                                font.bold: navBtn.isSelected
                                                color: navBtn.isSelected
                                                    ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7")
                                                    : (navMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.85))
                                                renderType: Text.NativeRendering
                                            }
                                        }

                                        MouseArea {
                                            id: navMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.activePageId = modelData.id
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════
        // CONTENT CANVAS (Right Pane, Scrollable)
        // ════════════════════════════════════════════════════════
        Rectangle {
            id: contentBox
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: sidebarBox.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            radius: 16
            color: Qt.rgba(255, 255, 255, 0.02)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.06)

            Flickable {
                id: contentFlick
                anchors.fill: parent
                anchors.margins: 20
                contentWidth: width
                contentHeight: mainPagesCol.implicitHeight + 40
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Timer {
                    id: scrollResetTimer
                    interval: 60
                    repeat: false
                    onTriggered: contentFlick.contentY = 0
                }

                Connections {
                    target: root
                    function onVisibleChanged() { if (root.visible) scrollResetTimer.restart(); }
                    function onActivePageIdChanged() { scrollResetTimer.restart(); }
                    function onKeybindsListChanged() { scrollResetTimer.restart(); }
                }

                Column {
                    id: mainPagesCol
                    width: parent.width
                    spacing: 20

                    // ────────────────────────────────────────────────
                    // PAGE 1: KEYBINDS & SHORTCUTS (Interactive Catalog)
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 14
                        visible: root.activePageId === "keybinds"

                        // Page Banner
                        Row {
                            width: parent.width
                            spacing: 12

                            Column {
                                width: parent.width - 150
                                spacing: 3

                                Text {
                                    text: "Hyprland Keybindings"
                                    font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                    font.bold: true
                                    font.pixelSize: 18
                                    color: "#ffffff"
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "Interactive keybindings catalog directly parsed from your Hyprland configuration."
                                    font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                    font.pixelSize: 12
                                    color: Qt.rgba(255, 255, 255, 0.50)
                                    renderType: Text.NativeRendering
                                }
                            }

                            Rectangle {
                                width: 130
                                height: 32
                                radius: 16
                                color: reloadKbMouse.containsMouse ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.10)
                                scale: reloadKbMouse.pressed ? 0.96 : 1.0

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MaterialSymbol {
                                        text: "refresh"
                                        iconSize: 16
                                        color: reloadKbMouse.containsMouse ? "#121214" : "#ffffff"
                                    }

                                    Text {
                                        text: "Reload Binds"
                                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: reloadKbMouse.containsMouse ? "#121214" : "#ffffff"
                                        renderType: Text.NativeRendering
                                    }
                                }

                                MouseArea {
                                    id: reloadKbMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        root.runShellCmd(["hyprctl", "reload"]);
                                        keybindsProc.running = true;
                                    }
                                }
                            }
                        }

                        // Category Filter Chips Row
                        Row {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: ["All", "Launchers", "Workspaces", "Windows", "Media", "System"]

                                Rectangle {
                                    id: catChip
                                    height: 28
                                    width: catText.implicitWidth + 20
                                    radius: 14

                                    readonly property bool active: root.selectedKeybindCat === modelData
                                    color: active
                                        ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7")
                                        : (catMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05))

                                    Text {
                                        id: catText
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                        font.bold: catChip.active
                                        font.pixelSize: 11
                                        color: catChip.active ? "#121214" : "#ffffff"
                                        renderType: Text.NativeRendering
                                    }

                                    MouseArea {
                                        id: catMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedKeybindCat = modelData;
                                            contentFlick.contentY = 0;
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                height: 28
                                width: countText.implicitWidth + 16
                                radius: 14
                                color: Qt.rgba(255, 255, 255, 0.05)

                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: root.filteredKeybinds.length + " keybinds"
                                    font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                    font.pixelSize: 11
                                    color: Qt.rgba(255, 255, 255, 0.50)
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        // Keybinds Rows
                        Column {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: root.filteredKeybinds

                                Rectangle {
                                    width: parent.width
                                    height: 48
                                    radius: 12
                                    color: kbMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.035)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.06)

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 12

                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            Repeater {
                                                model: modelData.keys

                                                Rectangle {
                                                    height: 24
                                                    width: Math.max(26, kText.implicitWidth + 14)
                                                    radius: 6
                                                    color: Qt.rgba(255, 255, 255, 0.09)
                                                    border.width: 1
                                                    border.color: Qt.rgba(255, 255, 255, 0.16)

                                                    Text {
                                                        id: kText
                                                        anchors.centerIn: parent
                                                        text: modelData.replace("vars.", "")
                                                        font.family: "JetBrains Mono, monospace"
                                                        font.bold: true
                                                        font.pixelSize: 10
                                                        color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                                        renderType: Text.NativeRendering
                                                    }
                                                }
                                            }
                                        }

                                        Column {
                                            width: parent.width - 240
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                width: parent.width
                                                text: modelData.desc || modelData.cmd
                                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                                font.bold: true
                                                font.pixelSize: 12
                                                color: "#ffffff"
                                                elide: Text.ElideRight
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.cmd
                                                font.family: "JetBrains Mono, monospace"
                                                font.pixelSize: 10
                                                color: Qt.rgba(255, 255, 255, 0.40)
                                                elide: Text.ElideRight
                                                renderType: Text.NativeRendering
                                            }
                                        }

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 20
                                            width: catBadgeText.implicitWidth + 12
                                            radius: 10
                                            color: Qt.rgba(255, 255, 255, 0.07)

                                            Text {
                                                id: catBadgeText
                                                anchors.centerIn: parent
                                                text: modelData.cat || "General"
                                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                                font.pixelSize: 10
                                                color: Qt.rgba(255, 255, 255, 0.60)
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: kbMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────────────
                    // PAGE 2: COLORS & THEMES
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "themes"

                        Text {
                            text: "Colors & Appearance"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: "Select a curated color palette or customize individual UI accents."
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.pixelSize: 12
                            color: Qt.rgba(255, 255, 255, 0.50)
                            renderType: Text.NativeRendering
                        }

                        Grid {
                            width: parent.width
                            columns: 3
                            spacing: 10

                            Repeater {
                                model: [
                                    { name: "Tokyo Night", key: "tokyo-night", color: "#7aa2f7" },
                                    { name: "Catppuccin Mocha", key: "catppuccin", color: "#cba6f7" },
                                    { name: "Nord", key: "nord", color: "#88c0d0" },
                                    { name: "Gruvbox Dark", key: "gruvbox", color: "#d79921" },
                                    { name: "Cyberpunk", key: "cyberpunk", color: "#00f0ff" },
                                    { name: "Rose Pine", key: "rose-pine", color: "#ebbcba" }
                                ]

                                Rectangle {
                                    width: (parent.width - 20) / 3
                                    height: 70
                                    radius: 12
                                    color: themeCardMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
                                    border.width: 1.5
                                    border.color: (Theme.currentTheme === modelData.key) ? modelData.color : Qt.rgba(255, 255, 255, 0.08)

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 12

                                        Rectangle {
                                            width: 28; height: 28; radius: 14
                                            color: modelData.color
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name
                                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: "#ffffff"
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    MouseArea {
                                        id: themeCardMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            if (typeof Theme.setTheme === "function") {
                                                Theme.setTheme(modelData.key);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Accent Color"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 14
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        Row {
                            spacing: 10
                            Repeater {
                                model: ["#38bdf8", "#a855f7", "#34d399", "#fbbf24", "#f43f5e", "#60a5fa", "#f97316"]
                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: modelData
                                    border.width: 2
                                    border.color: (Theme.accent === modelData) ? "#ffffff" : "transparent"

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Theme.accent = modelData
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────────────
                    // PAGE 3: HYPRLAND WINDOWS & TILING
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "tiling"

                        Text {
                            text: "Windows & Tiling"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        // Border Size
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 200
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: "Window Border Width"
                                        font.bold: true
                                        font.pixelSize: 13
                                        color: "#ffffff"
                                    }
                                    Text {
                                        text: "Current: " + root.hyprConfig.border_size + "px"
                                        font.pixelSize: 11
                                        color: Qt.rgba(255, 255, 255, 0.45)
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Repeater {
                                        model: [1, 2, 3, 4]
                                        Rectangle {
                                            width: 32; height: 32; radius: 8
                                            color: (root.hyprConfig.border_size === modelData) ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.08)

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData + "px"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: (root.hyprConfig.border_size === modelData) ? "#121214" : "#ffffff"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.setHyprKeyword("general:border_size", modelData);
                                                    root.hyprConfig.border_size = modelData;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Gaps Out
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 200
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: "Outer Screen Gaps"
                                        font.bold: true
                                        font.pixelSize: 13
                                        color: "#ffffff"
                                    }
                                    Text {
                                        text: "Margin between windows and display borders"
                                        font.pixelSize: 11
                                        color: Qt.rgba(255, 255, 255, 0.45)
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Repeater {
                                        model: [6, 10, 14, 20]
                                        Rectangle {
                                            width: 36; height: 32; radius: 8
                                            color: (root.hyprConfig.gaps_out === modelData) ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.08)

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData + "px"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: (root.hyprConfig.gaps_out === modelData) ? "#121214" : "#ffffff"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.setHyprKeyword("general:gaps_out", modelData);
                                                    root.hyprConfig.gaps_out = modelData;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────────────
                    // PAGE 4: HYPRLAND ANIMATIONS & BLUR
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "animations"

                        Text {
                            text: "Animations & Blur"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        // Toggle: Master Animations
                        Rectangle {
                            width: parent.width
                            height: 56
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 60
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: "Window Animations"
                                        font.bold: true
                                        font.pixelSize: 13
                                        color: "#ffffff"
                                    }
                                    Text {
                                        text: "Master toggle for Hyprland window movement and fade animations"
                                        font.pixelSize: 11
                                        color: Qt.rgba(255, 255, 255, 0.45)
                                    }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40; height: 22; radius: 11
                                    color: (root.hyprConfig.animations_enabled ?? true) ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.15)

                                    Rectangle {
                                        width: 16; height: 16; radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: (root.hyprConfig.animations_enabled ?? true) ? parent.width - width - 3 : 3
                                        color: "#121214"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var next = !(root.hyprConfig.animations_enabled ?? true);
                                            root.setHyprKeyword("animations:enabled", next ? 1 : 0);
                                            root.hyprConfig.animations_enabled = next;
                                        }
                                    }
                                }
                            }
                        }

                        // Toggle: Window Blur
                        Rectangle {
                            width: parent.width
                            height: 56
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 60
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: "Background Blur"
                                        font.bold: true
                                        font.pixelSize: 13
                                        color: "#ffffff"
                                    }
                                    Text {
                                        text: "Dual Kawase blur behind translucent windows and notifications"
                                        font.pixelSize: 11
                                        color: Qt.rgba(255, 255, 255, 0.45)
                                    }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40; height: 22; radius: 11
                                    color: (root.hyprConfig.blur_enabled === 1) ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.15)

                                    Rectangle {
                                        width: 16; height: 16; radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: (root.hyprConfig.blur_enabled === 1) ? parent.width - width - 3 : 3
                                        color: "#121214"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var next = root.hyprConfig.blur_enabled === 1 ? 0 : 1;
                                            root.setHyprKeyword("decoration:blur:enabled", next);
                                            root.hyprConfig.blur_enabled = next;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────────────
                    // PAGE: INPUT & TOUCHPAD
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "input"

                        Text {
                            text: "Input Devices & Touchpad"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        // Touchpad Tap to Click
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 80
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Touchpad Tap-to-Click"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Tap touchpad surface with one or more fingers to click"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44; height: 24; radius: 12
                                    readonly property bool on: !!root.hyprConfig.touchpad_tap
                                    color: on ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.15)
                                    Rectangle {
                                        x: parent.on ? 22 : 2; y: 2; width: 20; height: 20; radius: 10
                                        color: parent.on ? "#111114" : "#ffffff"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var next = !root.hyprConfig.touchpad_tap;
                                            root.hyprConfig.touchpad_tap = next;
                                            root.setHyprKeyword("input:touchpad:tap-to-click", next ? "1" : "0");
                                        }
                                    }
                                }
                            }
                        }

                        // Natural Scrolling
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 80
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Natural Scrolling (Inverted)"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Scroll direction mimics touch screens and macOS tracks"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44; height: 24; radius: 12
                                    readonly property bool on: !!root.hyprConfig.natural_scroll
                                    color: on ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.15)
                                    Rectangle {
                                        x: parent.on ? 22 : 2; y: 2; width: 20; height: 20; radius: 10
                                        color: parent.on ? "#111114" : "#ffffff"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var next = !root.hyprConfig.natural_scroll;
                                            root.hyprConfig.natural_scroll = next;
                                            root.setHyprKeyword("input:touchpad:natural_scroll", next ? "1" : "0");
                                        }
                                    }
                                }
                            }
                        }

                        // Disable While Typing
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 80
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Disable Touchpad While Typing"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Prevents accidental palm contact and erratic clicks"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44; height: 24; radius: 12
                                    readonly property bool on: !!root.hyprConfig.disable_while_typing
                                    color: on ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.15)
                                    Rectangle {
                                        x: parent.on ? 22 : 2; y: 2; width: 20; height: 20; radius: 10
                                        color: parent.on ? "#111114" : "#ffffff"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var next = !root.hyprConfig.disable_while_typing;
                                            root.hyprConfig.disable_while_typing = next;
                                            root.setHyprKeyword("input:touchpad:disable_while_typing", next ? "1" : "0");
                                        }
                                    }
                                }
                            }
                        }

                        // Pointer Sensitivity
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 240
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Pointer Acceleration / Sensitivity"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Adjust pointer velocity and sensitivity offset in Hyprland"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    Repeater {
                                        model: [-0.5, 0.0, 0.5, 1.0]
                                        Rectangle {
                                            width: 52; height: 30; radius: 8
                                            readonly property bool isSelected: Math.abs((root.hyprConfig.sensitivity || 0) - modelData) < 0.05
                                            color: isSelected ? Qt.alpha((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7", 0.20) : Qt.rgba(255, 255, 255, 0.06)
                                            border.width: isSelected ? 1 : 0
                                            border.color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                            Text {
                                                anchors.centerIn: parent
                                                text: (modelData > 0 ? "+" : "") + modelData
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: "#ffffff"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.hyprConfig.sensitivity = modelData;
                                                    root.setHyprKeyword("input:sensitivity", modelData);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────────────
                    // PAGE 5: DYNAMIC NOTCH CONFIG
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "notch"

                        Text {
                            text: "Dynamic Notch Configuration"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        Row {
                            spacing: 12
                            Repeater {
                                model: [
                                    { label: "Compact Pill", w: 180, h: 32, r: 16 },
                                    { label: "Standard Island", w: 220, h: 36, r: 18 },
                                    { label: "Wide Notch", w: 280, h: 38, r: 19 }
                                ]

                                Rectangle {
                                    width: 180
                                    height: 60
                                    radius: 12
                                    color: npMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
                                    border.width: 1
                                    border.color: (NotchConfig.modeDimensions.idle.width === modelData.w) ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.08)

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            text: modelData.label
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: "#ffffff"
                                        }
                                        Text {
                                            text: modelData.w + " × " + modelData.h + " px"
                                            font.family: "JetBrains Mono, monospace"
                                            font.pixelSize: 10
                                            color: Qt.rgba(255, 255, 255, 0.40)
                                        }
                                    }

                                    MouseArea {
                                        id: npMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            NotchConfig.modeDimensions.idle.width = modelData.w;
                                            NotchConfig.modeDimensions.idle.height = modelData.h;
                                            NotchConfig.modeDimensions.idle.radius = modelData.r;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────────────
                    // PAGE: TOP BAR & DASH
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "bar"

                        Text {
                            text: "Top Bar & Expanded Dash"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        // Battery Indicator Style
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 180
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Expanded Bar Battery Indicator"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Lucid 1:1 dual-clipped percentage text, cathode nipple, and charging bolt"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 120; height: 32; radius: 8
                                    color: Qt.alpha((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7", 0.18)
                                    border.width: 1
                                    border.color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Lucid 1:1 Pill"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                    }
                                }
                            }
                        }

                        // Clock Format
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 180
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Clock & Date Formatting"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Toggle 24-hour military clock or 12-hour AM/PM format"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    Repeater {
                                        model: ["24-Hour", "12-Hour"]
                                        Rectangle {
                                            width: 76; height: 30; radius: 8
                                            readonly property bool active: modelData === "24-Hour"
                                            color: active ? Qt.alpha((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7", 0.20) : Qt.rgba(255, 255, 255, 0.06)
                                            border.width: active ? 1 : 0
                                            border.color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                            Text { anchors.centerIn: parent; text: modelData; font.bold: true; font.pixelSize: 11; color: "#ffffff" }
                                        }
                                    }
                                }
                            }
                        }

                        // Cava Visualizer in Notch
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 80
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Audio Spectrum Cava Visualizer"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Live audio waveform bars responding to media in notch pill"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44; height: 24; radius: 12
                                    color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                    Rectangle {
                                        x: 22; y: 2; width: 20; height: 20; radius: 10
                                        color: "#111114"
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────────────
                    // PAGE: LAUNCHER & CLIPBOARD
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "launcher"

                        Text {
                            text: "Launcher & Clipboard History"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        // App Launcher Shortcut
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Application Launcher Shortcut"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Fuzzy search apps, binaries, and system actions"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 120; height: 32; radius: 6
                                    color: Qt.rgba(255, 255, 255, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.15)
                                    Text { anchors.centerIn: parent; text: "SUPER + SPACE"; font.bold: true; font.pixelSize: 11; color: "#ffffff" }
                                }
                            }
                        }

                        // Clipboard History
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Clipboard Manager (cliphist)"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Store and recall copied text and images"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 120; height: 32; radius: 6
                                    color: Qt.rgba(255, 255, 255, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.15)
                                    Text { anchors.centerIn: parent; text: "SUPER + V"; font.bold: true; font.pixelSize: 11; color: "#ffffff" }
                                }
                            }
                        }

                        // Clear Clipboard Action
                        Rectangle {
                            width: parent.width
                            height: 60
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Clear Clipboard History"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Permanently delete all stored cliphist entries"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 110; height: 32; radius: 8
                                    color: clearClipMouse.containsMouse ? Qt.rgba(248, 113, 113, 0.25) : Qt.rgba(248, 113, 113, 0.15)
                                    border.width: 1
                                    border.color: "#f87171"
                                    Text { anchors.centerIn: parent; text: "Clear All"; font.bold: true; font.pixelSize: 11; color: "#f87171" }
                                    MouseArea {
                                        id: clearClipMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: root.runShellCmd(["cliphist", "wipe"])
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────────────
                    // PAGE 6: BATTERY & POWER
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "battery"

                        Text {
                            text: "Battery & Power Management"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        // Power Profiles
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 240
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: "Power Performance Profile"
                                        font.bold: true
                                        font.pixelSize: 13
                                        color: "#ffffff"
                                    }
                                    Text {
                                        text: "Governs CPU boost clocks and TDP scaling"
                                        font.pixelSize: 11
                                        color: Qt.rgba(255, 255, 255, 0.45)
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Repeater {
                                        model: ["power-saver", "balanced", "performance"]

                                        Rectangle {
                                            width: 76; height: 30; radius: 8
                                            color: ppMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.bold: true
                                                font.pixelSize: 10
                                                color: "#ffffff"
                                            }

                                            MouseArea {
                                                id: ppMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: root.runShellCmd(["powerprofilesctl", "set", modelData])
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Refresh Rate
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: "Display Refresh Rate"
                                        font.bold: true
                                        font.pixelSize: 13
                                        color: "#ffffff"
                                    }
                                    Text {
                                        text: "60 Hz for extended battery life · 144 Hz for fluid motion"
                                        font.pixelSize: 11
                                        color: Qt.rgba(255, 255, 255, 0.45)
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Repeater {
                                        model: [60, 144]
                                        Rectangle {
                                            width: 60; height: 30; radius: 8
                                            color: rrMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.08)

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData + " Hz"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: "#ffffff"
                                            }

                                            MouseArea {
                                                id: rrMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: root.runShellCmd(["hyprctl", "keyword", "monitor", "eDP-1,1920x1200@" + modelData + ",0x0,1.2"])
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────────────
                    // PAGE: BLUETOOTH & NETWORK
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "network"

                        Text {
                            text: "Network & Bluetooth Radios"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        // Wi-Fi Card
                        Rectangle {
                            width: parent.width
                            height: 74
                            radius: 14
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Item {
                                    width: 38; height: 38
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        anchors.fill: parent; radius: 19
                                        color: root.wifiStatus.radio ? Qt.alpha((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7", 0.20) : Qt.rgba(255, 255, 255, 0.08)
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: root.wifiStatus.radio ? "wifi" : "wifi_off"
                                            iconSize: 20
                                            color: root.wifiStatus.radio ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.40)
                                        }
                                    }
                                }

                                Item { width: 12; height: 1 }

                                Column {
                                    width: parent.width - 240
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Wi-Fi Interface (" + (root.wifiStatus.active_dev || "wlan0") + ")"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text {
                                        text: root.wifiStatus.connected_ssid
                                            ? "Connected to " + root.wifiStatus.connected_ssid + " · " + (root.wifiStatus.active_ip || "")
                                            : (root.wifiStatus.radio ? "Disconnected · Wi-Fi active" : "Wi-Fi radio disabled")
                                        font.pixelSize: 11
                                        color: root.wifiStatus.connected_ssid ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.45)
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Rectangle {
                                        width: 76; height: 32; radius: 8
                                        color: wifiToggleMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.wifiStatus.radio ? "Turn Off" : "Turn On"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#ffffff"
                                        }
                                        MouseArea {
                                            id: wifiToggleMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: {
                                                root.runShellCmd(["python3", Quickshell.shellDir + "/scripts/wifi_manager.py", "toggle-radio"]);
                                                wifiReloadTimer.restart();
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 76; height: 32; radius: 8
                                        color: Qt.alpha((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7", 0.18)
                                        border.width: 1
                                        border.color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Scan"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.runShellCmd(["python3", Quickshell.shellDir + "/scripts/wifi_manager.py", "scan"]);
                                                wifiReloadTimer.restart();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Bluetooth Card
                        Rectangle {
                            width: parent.width
                            height: 74
                            radius: 14
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Item {
                                    width: 38; height: 38
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        anchors.fill: parent; radius: 19
                                        readonly property bool on: !!(root.btAdapter && root.btAdapter.enabled)
                                        color: on ? Qt.alpha((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7", 0.20) : Qt.rgba(255, 255, 255, 0.08)
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "bluetooth"
                                            iconSize: 20
                                            color: parent.on ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.40)
                                        }
                                    }
                                }

                                Item { width: 12; height: 1 }

                                Column {
                                    width: parent.width - 180
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Bluetooth Adapter"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text {
                                        text: (root.btAdapter && root.btAdapter.enabled)
                                            ? "Bluetooth enabled · Ready for connections"
                                            : "Bluetooth adapter powered off"
                                        font.pixelSize: 11
                                        color: (root.btAdapter && root.btAdapter.enabled) ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.45)
                                    }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 84; height: 32; radius: 8
                                    color: btBtnMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                                    Text {
                                        anchors.centerIn: parent
                                        text: (root.btAdapter && root.btAdapter.enabled) ? "Disable" : "Enable"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#ffffff"
                                    }
                                    MouseArea {
                                        id: btBtnMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled;
                                            else root.runShellCmd(["rfkill", "toggle", "bluetooth"]);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────────────
                    // PAGE: DISPLAYS & AUDIO
                    // ────────────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "displays"

                        Text {
                            text: "Displays & Audio Hardware"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        // Active Monitor Card
                        Rectangle {
                            width: parent.width
                            height: 74
                            radius: 14
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Item {
                                    width: 38; height: 38
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        anchors.fill: parent; radius: 19
                                        color: Qt.alpha((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7", 0.20)
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "monitor"
                                            iconSize: 20
                                            color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                        }
                                    }
                                }

                                Item { width: 12; height: 1 }

                                Column {
                                    width: parent.width - 180
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Active Display (eDP-1)"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text {
                                        text: "1920×1200 @ 144Hz · Scale 1.20× · CSOT MNG007QX2-2"
                                        font.pixelSize: 11
                                        color: Qt.rgba(255, 255, 255, 0.45)
                                    }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 80; height: 28; radius: 6
                                    color: Qt.rgba(255, 255, 255, 0.08)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Primary"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#ffffff"
                                    }
                                }
                            }
                        }

                        // Night Light (hyprsunset)
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Column {
                                    width: parent.width - 80
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: "Night Light (Blue Light Filter)"; font.bold: true; font.pixelSize: 13; color: "#ffffff" }
                                    Text { text: "Warm display color temperature via hyprsunset (4500K)"; font.pixelSize: 11; color: Qt.rgba(255, 255, 255, 0.45) }
                                }

                                Rectangle {
                                    id: nlSwitch
                                    property bool on: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44; height: 24; radius: 12
                                    color: on ? "#f59e0b" : Qt.rgba(255, 255, 255, 0.15)
                                    Rectangle {
                                        x: parent.on ? 22 : 2; y: 2; width: 20; height: 20; radius: 10
                                        color: parent.on ? "#111114" : "#ffffff"
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            nlSwitch.on = !nlSwitch.on;
                                            if (nlSwitch.on) {
                                                root.runShellCmd(["sh", "-c", "pkill -9 -x hyprsunset 2>/dev/null; pkill -9 -x wlsunset 2>/dev/null; if command -v hyprsunset >/dev/null 2>&1; then hyprsunset -t 4500 & else wlsunset -t 4500 & fi"]);
                                            } else {
                                                root.runShellCmd(["sh", "-c", "pkill -9 -x hyprsunset 2>/dev/null; pkill -9 -x wlsunset 2>/dev/null"]);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: 16
                        visible: root.activePageId === "about"

                        Text {
                            text: "System Information & Actions"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 18
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        Grid {
                            width: parent.width
                            columns: 2
                            spacing: 10

                            Repeater {
                                model: [
                                    { k: "Host OS", v: "NixOS (Linux 6.12)" },
                                    { k: "Compositor", v: "Hyprland Wayland" },
                                    { k: "Shell Architecture", v: "Dynamic-You + Quickshell" },
                                    { k: "Active User", v: "kuro@nixos" }
                                ]

                                Rectangle {
                                    width: (parent.width - 10) / 2
                                    height: 52
                                    radius: 12
                                    color: Qt.rgba(255, 255, 255, 0.04)

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1

                                        Text {
                                            text: modelData.k
                                            font.pixelSize: 10
                                            color: Qt.rgba(255, 255, 255, 0.40)
                                        }
                                        Text {
                                            text: modelData.v
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: "#ffffff"
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Quick System Actions"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 14
                            color: "#ffffff"
                            renderType: Text.NativeRendering
                        }

                        Row {
                            spacing: 10

                            Rectangle {
                                width: 140; height: 36; radius: 18
                                color: rShellMouse.containsMouse ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: "Restart Shell"
                                    font.bold: true
                                    font.pixelSize: 11
                                    color: rShellMouse.containsMouse ? "#121214" : "#ffffff"
                                }

                                MouseArea {
                                    id: rShellMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.runShellCmd(["bash", "-c", "quickshell kill && sleep 0.4 && quickshell -d &"])
                                }
                            }

                            Rectangle {
                                width: 140; height: 36; radius: 18
                                color: rHyprMouse.containsMouse ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: "Reload Hyprland"
                                    font.bold: true
                                    font.pixelSize: 11
                                    color: rHyprMouse.containsMouse ? "#121214" : "#ffffff"
                                }

                                MouseArea {
                                    id: rHyprMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.runShellCmd(["hyprctl", "reload"])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
