import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ────────────────────────────────────────────────────────────
// Lucid Wi-Fi Architecture & Design (1:1 with Lucid WifiPanel.qml & WifiShare.qml)
// Pure copy of Lucid's padding, layouts, component metrics, and visual hierarchy.
// ────────────────────────────────────────────────────────────
Item {
    id: root

    // State properties (compatible with shell.qml)
    property string activeTab: "wifi"
    property bool wifiEnabled: true
    property bool isScanning: wifiScanProc.running
    property bool hotspotActive: false
    property string connectedSsid: ""
    property string activeIp: ""
    property string activeDev: "wlan0"
    property var ethernetData: null
    property string expandedSsid: ""
    property string pendingSsid: ""
    property bool hiddenFormOpen: false
    property string hiddenSsid: ""
    property string hiddenPass: ""
    property var failedSsidMap: ({})
    property var shareDataMap: ({})

    // Lucid 3-tier split lists
    property var connectedNetworks: []
    property var savedNetworks: []
    property var nearbyNetworks: []

    readonly property int totalCount: connectedNetworks.length + savedNetworks.length + nearbyNetworks.length
    readonly property var model: ({ count: root.totalCount })

    // Pixel-perfect dynamic height that hugs Lucid's content with exact padding
    readonly property int calculatedHeight: {
        if (!root.wifiEnabled) return 210;
        var contentH = subHeader.height + 6 + col.implicitHeight + 24;
        return Math.min(540, Math.max(220, contentH));
    }
    readonly property real listViewContentHeight: col.implicitHeight

    // Lucid Shared Glyphs (copied 1:1 from WifiPanel.qml)
    component EthernetGlyph: Item {
        id: glyph
        property color glyphColor: Qt.rgba(255, 255, 255, 0.65)
        width: 16
        height: 16

        MaterialSymbol {
            anchors.centerIn: parent
            text: "lan"
            iconSize: 18
            fill: 1
            color: glyph.glyphColor
        }
    }

    component WifiStrengthGlyph: MaterialSymbol {
        id: wsg
        property real strength: 0
        property bool showOff: false
        readonly property real normalizedStrength: wsg.strength <= 1 ? wsg.strength * 100 : wsg.strength
        readonly property int level: wsg.normalizedStrength >= 80 ? 4 : (wsg.normalizedStrength >= 60 ? 3 : (wsg.normalizedStrength >= 40 ? 2 : (wsg.normalizedStrength >= 20 ? 1 : 0)))

        text: wsg.showOff ? "signal_wifi_off" : ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"][wsg.level]
        iconSize: 20
        fill: 1
    }

    // Backend Execution Processes
    readonly property string helperScript: Quickshell.shellDir + "/scripts/wifi_manager.py"

    function scan(forceRescan) {
        if (!root.wifiEnabled) return;
        var rescanArg = (forceRescan === false) ? "no" : "yes";
        wifiScanProc.command = ["python3", root.helperScript, "scan", rescanArg];
        wifiScanProc.running = false;
        wifiScanProc.running = true;
    }

    function refreshStatus() {
        wifiStatusProc.command = ["python3", root.helperScript, "status"];
        wifiStatusProc.running = false;
        wifiStatusProc.running = true;
        root.scan(false);
    }

    function toggleRadio() {
        wifiToggleProc.command = ["python3", root.helperScript, "toggle-radio"];
        wifiToggleProc.running = true;
        root.wifiEnabled = !root.wifiEnabled;
    }

    function connectNetwork(ssid, password) {
        root.pendingSsid = ssid;
        var cmd = ["python3", root.helperScript, "connect", ssid];
        if (password && password.length > 0) cmd.push(password);
        wifiConnectProc.targetSsid = ssid;
        wifiConnectProc.command = cmd;
        wifiConnectProc.running = true;
    }

    function disconnectNetwork(ssid) {
        var cmd = ["python3", root.helperScript, "disconnect"];
        if (ssid) cmd.push(ssid);
        wifiActionProc.command = cmd;
        wifiActionProc.running = true;
    }

    function disconnectEthernet() {
        wifiActionProc.command = ["python3", root.helperScript, "disconnect-wired"];
        wifiActionProc.running = true;
    }

    function forgetNetwork(ssid) {
        wifiActionProc.command = ["python3", root.helperScript, "forget", ssid];
        wifiActionProc.running = true;
    }

    function fetchSecret(ssid) {
        wifiSecretProc.targetSsid = ssid;
        wifiSecretProc.command = ["python3", root.helperScript, "secret", ssid];
        wifiSecretProc.running = true;
    }

    function toggleAutoConnect(ssid, enable) {
        wifiAutoConnectProc.command = ["python3", root.helperScript, "autoconnect", ssid, enable ? "yes" : "no"];
        wifiAutoConnectProc.running = true;
    }

    function getStrengthLabel(signal) {
        var sig = parseInt(signal) || 0;
        if (sig >= 75) return "Excellent signal (" + sig + "%)";
        if (sig >= 50) return "Good signal (" + sig + "%)";
        if (sig >= 25) return "Fair signal (" + sig + "%)";
        return "Weak signal (" + sig + "%)";
    }

    // Process Definitions
    Process {
        id: wifiStatusProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    root.wifiEnabled = !!data.radio;
                    root.connectedSsid = data.connected_ssid || "";
                    root.activeIp = data.active_ip || "";
                    root.activeDev = data.active_dev || "wlan0";
                    root.hotspotActive = !!data.hotspot_active;
                    root.ethernetData = data.ethernet || null;
                } catch (e) {}
            }
        }
    }

    Process {
        id: wifiScanProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(this.text.trim());
                    if (res.status) {
                        root.wifiEnabled = !!res.status.radio;
                        root.connectedSsid = res.status.connected_ssid || "";
                        root.activeIp = res.status.active_ip || "";
                        root.activeDev = res.status.active_dev || "wlan0";
                        root.hotspotActive = !!res.status.hotspot_active;
                        root.ethernetData = res.status.ethernet || null;
                    }
                    root.connectedNetworks = res.connected || [];
                    root.savedNetworks = res.saved || [];
                    root.nearbyNetworks = res.nearby || [];
                } catch (e) {}
            }
        }
    }

    Process {
        id: wifiConnectProc
        property string targetSsid: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root.pendingSsid = "";
                try {
                    var out = JSON.parse(this.text.trim());
                    if (!out.success) {
                        var map = Object.assign({}, root.failedSsidMap);
                        map[wifiConnectProc.targetSsid] = out.error || "Connection failed";
                        root.failedSsidMap = map;
                    } else {
                        var mapClean = Object.assign({}, root.failedSsidMap);
                        delete mapClean[wifiConnectProc.targetSsid];
                        root.failedSsidMap = mapClean;
                    }
                } catch (e) {}
                root.scan(true);
            }
        }
    }

    Process {
        id: wifiActionProc
        onExited: root.scan(true)
    }

    Process {
        id: wifiSecretProc
        property string targetSsid: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var secData = JSON.parse(this.text.trim());
                    var smap = Object.assign({}, root.shareDataMap);
                    smap[wifiSecretProc.targetSsid] = secData;
                    root.shareDataMap = smap;
                } catch (e) {}
            }
        }
    }

    Process {
        id: wifiAutoConnectProc
        onExited: root.scan(false)
    }

    Process {
        id: wifiToggleProc
        onExited: root.refreshStatus()
    }

    Timer {
        interval: 6000
        running: (root.visible && !root.isScanning && root.pendingSsid === "")
        repeat: true
        onTriggered: root.scan(false)
    }

    onVisibleChanged: {
        if (visible) root.refreshStatus();
    }

    Component.onCompleted: root.refreshStatus()

    // Keyboard support
    focus: true
    Keys.onEscapePressed: (event) => {
        if (root.expandedSsid !== "") {
            root.expandedSsid = "";
        } else if (root.hiddenFormOpen) {
            root.hiddenFormOpen = false;
        } else {
            root.parent.collapseToIdle ? root.parent.collapseToIdle() : null;
        }
        event.accepted = true;
    }

    // ========================================================
    // 1. LUCID SUBHEADER (44dp: Back Button, "Internet" Title, Power Switch)
    // ========================================================
    Item {
        id: subHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44

        Rectangle {
            id: backChip
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 16
            color: backArea.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
            scale: backArea.pressed ? 0.94 : (backArea.containsMouse ? 1.04 : 1.0)
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "←"
                font.pixelSize: 16
                color: "#ffffff"
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    if (typeof root.parent.switchMode === "function") {
                        root.parent.switchMode("utility", true);
                    } else {
                        Quickshell.execDetached(["quickshell", "ipc", "call", "notch", "switchMode", "utility"]);
                    }
                }
            }
        }

        Text {
            anchors.left: backChip.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "Internet"
            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
            font.pixelSize: 14
            font.bold: true
            color: "#ffffff"
            renderType: Text.NativeRendering
        }

        // Master Wi-Fi Power Switch
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 22; radius: 11
            color: root.wifiEnabled ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.15)
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                width: 16; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: root.wifiEnabled ? parent.width - width - 3 : 3
                color: root.wifiEnabled ? "#121214" : Qt.rgba(255, 255, 255, 0.60)
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleRadio()
            }
        }
    }

    // ========================================================
    // 2. MAIN SCROLLABLE CONTENT (Lucid 1:1 Layout)
    // ========================================================
    Flickable {
        id: subScroll
        anchors.top: subHeader.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: root.wifiEnabled ? col.implicitHeight : disabledCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // Disabled State (Lucid 1:1)
        Column {
            id: disabledCol
            visible: !root.wifiEnabled
            width: parent.width
            topPadding: 24
            spacing: 8

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "wifi_off"
                iconSize: 36
                color: Qt.rgba(255, 255, 255, 0.35)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Wi-Fi is turned off"
                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                font.bold: true
                font.pixelSize: 13
                color: "#ffffff"
                renderType: Text.NativeRendering
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Turn on Wi-Fi to see available networks"
                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                font.pixelSize: 11
                color: Qt.rgba(255, 255, 255, 0.50)
                renderType: Text.NativeRendering
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 92; height: 30; radius: 15
                color: turnOnMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.88)
                scale: turnOnMouse.pressed ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: "Turn On"
                    font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#121214"
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: turnOnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.toggleRadio()
                }
            }
        }

        // Active Content Column (copied 1:1 from Lucid WifiPanel.qml `Column { id: col }`)
        Column {
            id: col
            visible: root.wifiEnabled
            width: subScroll.width
            spacing: 10

            // ────────────────────────────────────────────────────
            // ITEM 1: ETHERNET ROW (Lucid 1:1)
            // ────────────────────────────────────────────────────
            Item {
                visible: root.ethernetData !== null
                width: parent.width
                height: 40

                EthernetGlyph {
                    id: ethIcon
                    width: 16
                    height: 16
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    glyphColor: (root.ethernetData && root.ethernetData.connected) ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.45)
                }

                Column {
                    anchors.left: ethIcon.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "Ethernet"
                        color: "#ffffff"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.bold: true
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: {
                            if (!root.ethernetData) return "No cable connected";
                            if (root.ethernetData.connected) {
                                var parts = ["Connected"];
                                if (root.ethernetData.speed) parts.push(root.ethernetData.speed + " Mbps");
                                if (root.ethernetData.ip) parts.push(root.ethernetData.ip);
                                return parts.join(" · ");
                            }
                            return "Cable connected · not configured";
                        }
                        color: (root.ethernetData && root.ethernetData.connected) ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.45)
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                    }
                }

                Rectangle {
                    visible: !!(root.ethernetData && root.ethernetData.connected)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 78
                    height: 26
                    radius: 999
                    color: ethDisconnectArea.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.20)

                    Text {
                        anchors.centerIn: parent
                        text: "Disconnect"
                        color: "#ffffff"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.bold: true
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: ethDisconnectArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.disconnectEthernet()
                    }
                }
            }

            // ────────────────────────────────────────────────────
            // ITEM 2: SCAN BUTTON CAPSULE (Lucid 1:1)
            // ────────────────────────────────────────────────────
            Item {
                id: scanButton
                width: parent.width
                height: 44

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.isScanning ? Qt.rgba(255, 255, 255, 0.10) : (scanArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Item {
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: !root.isScanning
                                text: "wifi_find"
                                iconSize: 20
                                color: Qt.rgba(255, 255, 255, 0.55)
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: root.isScanning
                                text: "refresh"
                                iconSize: 18
                                color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                RotationAnimation on rotation {
                                    from: 0; to: 360; duration: 900; loops: Animation.Infinite
                                    running: root.isScanning
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.isScanning ? "Looking for networks" : "Search for networks"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.pixelSize: 12
                            color: root.isScanning ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : "#ffffff"
                            renderType: Text.NativeRendering
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.isScanning
                        text: "Stop"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 11
                        color: Qt.rgba(255, 255, 255, 0.70)
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: scanArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (root.isScanning) {
                                wifiScanProc.running = false;
                            } else {
                                root.scan(true);
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────
            // ITEM 3: LIST COLUMN (Lucid 1:1 `Column { id: listCol }`)
            // ────────────────────────────────────────────────────
            Column {
                id: listCol
                width: parent.width
                spacing: 14

                // SECTION 1: CONNECTED
                Column {
                    width: parent.width
                    spacing: 3
                    visible: root.connectedNetworks.length > 0

                    Text {
                        text: "Connected"
                        color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.bold: true
                        font.pixelSize: 12
                        leftPadding: 4
                        bottomPadding: 3
                        renderType: Text.NativeRendering
                    }

                    Repeater {
                        model: root.connectedNetworks
                        NetRow { }
                    }
                }

                // SECTION 2: SAVED
                Column {
                    width: parent.width
                    spacing: 3
                    visible: root.savedNetworks.length > 0

                    Text {
                        text: "Saved"
                        color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.bold: true
                        font.pixelSize: 12
                        leftPadding: 4
                        bottomPadding: 3
                        renderType: Text.NativeRendering
                    }

                    Repeater {
                        model: root.savedNetworks
                        NetRow { }
                    }
                }

                // SECTION 3: NEARBY
                Column {
                    width: parent.width
                    spacing: 3
                    visible: root.nearbyNetworks.length > 0

                    Text {
                        text: "Nearby"
                        color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.bold: true
                        font.pixelSize: 12
                        leftPadding: 4
                        bottomPadding: 3
                        renderType: Text.NativeRendering
                    }

                    Repeater {
                        model: root.nearbyNetworks
                        NetRow { }
                    }
                }

                // SECTION 4: EMPTY STATE
                Column {
                    width: parent.width
                    visible: root.totalCount === 0 && !root.isScanning
                    topPadding: 18
                    bottomPadding: 6
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No networks found"
                        color: Qt.rgba(255, 255, 255, 0.45)
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }
                }

                // SECTION 5: HIDDEN NETWORK (Lucid 1:1)
                Column {
                    width: parent.width
                    spacing: 8
                    topPadding: 2

                    Text {
                        visible: !root.hiddenFormOpen
                        text: "Connect to hidden network"
                        color: Qt.rgba(255, 255, 255, 0.55)
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 11
                        font.underline: hiddenToggleArea.containsMouse
                        leftPadding: 4
                        renderType: Text.NativeRendering

                        MouseArea {
                            id: hiddenToggleArea
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.hiddenFormOpen = true
                        }
                    }

                    Column {
                        width: parent.width
                        visible: root.hiddenFormOpen
                        spacing: 6
                        leftPadding: 4
                        rightPadding: 4

                        Rectangle {
                            width: parent.width - 8
                            height: 30
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1
                            border.color: hiddenSsidInput.activeFocus ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.12)

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Network name (SSID)"
                                color: Qt.rgba(255, 255, 255, 0.35)
                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                font.pixelSize: 11
                                visible: !hiddenSsidInput.text && !hiddenSsidInput.activeFocus
                                renderType: Text.NativeRendering
                            }

                            TextInput {
                                id: hiddenSsidInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                color: "#ffffff"
                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                font.pixelSize: 12
                                selectByMouse: true
                                onTextChanged: root.hiddenSsid = text
                            }
                        }

                        Rectangle {
                            width: parent.width - 8
                            height: 30
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.35)
                            border.width: 1
                            border.color: hiddenPskInput.activeFocus ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.12)

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Password"
                                color: Qt.rgba(255, 255, 255, 0.35)
                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                font.pixelSize: 11
                                visible: !hiddenPskInput.text && !hiddenPskInput.activeFocus
                                renderType: Text.NativeRendering
                            }

                            TextInput {
                                id: hiddenPskInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                color: "#ffffff"
                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                font.pixelSize: 12
                                selectByMouse: true
                                onTextChanged: root.hiddenPass = text
                                onAccepted: hiddenConnectBtn.clickedAction()
                            }
                        }

                        Row {
                            spacing: 8
                            height: 28

                            Rectangle {
                                id: hiddenConnectBtn
                                width: 90
                                height: parent.height
                                radius: 999
                                color: hiddenConnectArea.containsMouse ? "#ffffff" : ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7")

                                function clickedAction() {
                                    if (root.hiddenSsid.trim().length > 0) {
                                        root.connectNetwork(root.hiddenSsid.trim(), root.hiddenPass.trim());
                                        root.hiddenFormOpen = false;
                                        hiddenSsidInput.text = "";
                                        hiddenPskInput.text = "";
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Connect"
                                    color: "#121214"
                                    font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                    font.bold: true
                                    font.pixelSize: 11
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    id: hiddenConnectArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: hiddenConnectBtn.clickedAction()
                                }
                            }

                            Rectangle {
                                width: 70
                                height: parent.height
                                radius: 999
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.20)

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: "#ffffff"
                                    font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                    font.bold: true
                                    font.pixelSize: 11
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.hiddenFormOpen = false;
                                        hiddenSsidInput.text = "";
                                        hiddenPskInput.text = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ========================================================
    // 3. LUCID NETROW (Copied 1:1 from Lucid WifiPanel.qml `component NetRow: Column`)
    // ========================================================
    component NetRow: Rectangle {
        id: netItem

        required property var modelData
        readonly property bool isExpanded: root.expandedSsid === modelData.ssid
        readonly property bool isConnected: !!modelData.active || (root.connectedSsid === modelData.ssid && modelData.ssid !== "")
        readonly property bool isSecured: modelData.security !== "Open" && modelData.security !== "--" && modelData.security !== ""
        readonly property bool isTrusted: !!modelData.saved
        readonly property bool connectFailed: !!root.failedSsidMap[modelData.ssid]
        readonly property string failReason: root.failedSsidMap[modelData.ssid] || ""
        readonly property bool isConnecting: (root.pendingSsid === modelData.ssid && modelData.ssid !== "")
        readonly property bool canShare: netItem.isTrusted
        property bool sharing: false

        width: parent.width
        radius: netItem.isExpanded ? 18 : 14
        color: netItem.isExpanded ? Qt.rgba(255, 255, 255, 0.08) : (rowArea.containsMouse ? Qt.rgba(255, 255, 255, 0.065) : Qt.rgba(255, 255, 255, 0.04))
        border.width: netItem.isExpanded ? 1 : 0
        border.color: netItem.isExpanded ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
        clip: true

        Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        height: 54 + (netItem.isExpanded ? (expandContent.implicitHeight + 8) : 0)

        onIsExpandedChanged: {
            if (!isExpanded) {
                netItem.sharing = false;
            } else if (netItem.isTrusted) {
                root.fetchSecret(modelData.ssid);
            }
        }

        Column {
            id: netCardCol
            width: parent.width

            Item {
                width: parent.width
                height: 54

                Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 14

                Item {
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    WifiStrengthGlyph {
                        anchors.centerIn: parent
                        strength: modelData.signal || 0
                        color: netItem.isConnected ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.65)
                    }

                    Rectangle {
                        id: netDot
                        visible: netItem.isConnected
                        width: 6; height: 6; radius: 3
                        color: "#30d158"
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -1

                        SequentialAnimation on opacity {
                            running: netDot.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                Column {
                    width: parent.width - 20 - 18 - 28
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: modelData.ssid
                        color: "#ffffff"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.bold: true
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: {
                            if (netItem.isConnected) {
                                var parts = ["Connected"];
                                if (modelData.band) parts.push(modelData.band);
                                if (modelData.signal > 0) parts.push(root.getStrengthLabel(modelData.signal));
                                if (root.activeIp) parts.push(root.activeIp);
                                return parts.join(" · ");
                            }
                            if (netItem.isTrusted) {
                                return "Saved · " + root.getStrengthLabel(modelData.signal);
                            }
                            return root.getStrengthLabel(modelData.signal) + (netItem.isSecured ? "" : " · Open");
                        }
                        color: netItem.isConnected ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.50)
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }
                }

                MaterialSymbol {
                    text: "expand_more"
                    iconSize: 20
                    color: Qt.rgba(255, 255, 255, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                    rotation: netItem.isExpanded ? 180 : 0
                    Behavior on rotation {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expandedSsid = (root.expandedSsid === modelData.ssid) ? "" : modelData.ssid
                }
            }

            Item {
                id: expandArea
                width: parent.width
                height: netItem.isExpanded ? (expandContent.implicitHeight + 8) : 0
                clip: true

                Column {
                    id: expandContent
                    width: parent.width
                    leftPadding: 14
                    rightPadding: 14
                    topPadding: 2
                    bottomPadding: 14
                    spacing: 10
                    opacity: netItem.isExpanded ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Rectangle {
                        id: passwordBox
                        visible: !netItem.isConnected && (!netItem.isTrusted || netItem.connectFailed)
                        width: parent.width - 28
                        height: 32
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.width: 1
                    border.color: netItem.connectFailed ? "#f87171" : (passwordInput.activeFocus ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.12))

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enter password..."
                        color: Qt.rgba(255, 255, 255, 0.35)
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 11
                        visible: !passwordInput.text && !passwordInput.activeFocus
                        renderType: Text.NativeRendering
                    }

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: "#ffffff"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 12
                        selectByMouse: true
                        onAccepted: connectBtn.clickedAction()
                    }
                }

                Row {
                    width: parent.width - 28
                    height: 30
                    spacing: 8

                    Rectangle {
                        id: connectBtn
                        width: netItem.canShare ? (parent.width - shareBtn.width - 16) / 2 : parent.width
                        height: parent.height
                        radius: 999
                        color: netItem.isConnecting ? Qt.rgba(255, 255, 255, 0.15)
                             : (netItem.isConnected ? Qt.rgba(248, 113, 113, 0.18)
                             : (connectArea.containsMouse ? "#ffffff" : ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7")))
                        scale: connectArea.pressed ? 0.96 : 1

                        function clickedAction() {
                            if (netItem.isConnected) {
                                root.disconnectNetwork(modelData.ssid);
                            } else {
                                var pass = passwordInput.text.trim();
                                root.connectNetwork(modelData.ssid, pass);
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: netItem.isConnecting ? "Connecting..." : (netItem.isConnected ? "Disconnect" : "Connect")
                            color: netItem.isConnecting ? Qt.rgba(255, 255, 255, 0.6) : (netItem.isConnected ? "#f87171" : "#121214")
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 12
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: connectArea
                            anchors.fill: parent
                            enabled: !netItem.isConnecting
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectBtn.clickedAction()
                        }
                    }

                    Rectangle {
                        id: forgetBtn
                        visible: netItem.canShare
                        width: (parent.width - shareBtn.width - 16) / 2
                        height: parent.height
                        radius: 999
                        color: forgetArea.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : "transparent"
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.20)
                        scale: forgetArea.pressed ? 0.96 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "Forget Network"
                            color: "#ffffff"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 11
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: forgetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.forgetNetwork(modelData.ssid)
                        }
                    }

                    Rectangle {
                        id: shareBtn
                        visible: netItem.canShare
                        width: 30
                        height: 30
                        radius: 999
                        color: netItem.sharing ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : (shareArea.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent")
                        border.width: netItem.sharing ? 0 : 1
                        border.color: Qt.rgba(255, 255, 255, 0.20)
                        scale: shareArea.pressed ? 0.94 : 1

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "qr_code"
                            iconSize: 16
                            fill: netItem.sharing ? 1 : 0
                            color: netItem.sharing ? "#121214" : "#ffffff"
                        }

                        MouseArea {
                            id: shareArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: netItem.sharing = !netItem.sharing
                        }
                    }
                }

                // WifiShare View (Copied 1:1 from Lucid WifiShare.qml)
                Loader {
                    width: parent.width - 28
                    active: netItem.sharing && netItem.isExpanded
                    visible: active

                    sourceComponent: Component {
                        Item {
                            id: shareComp
                            property bool revealed: false
                            property bool copied: false
                            readonly property var info: root.shareDataMap[modelData.ssid] || ({})
                            readonly property var rows: info.qr_rows || []
                            implicitHeight: shareGrid.implicitHeight

                            Timer {
                                id: copiedTimer
                                interval: 1600
                                onTriggered: shareComp.copied = false
                            }

                            Column {
                                id: shareGrid
                                width: parent.width
                                spacing: 10

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 148; height: 148
                                    radius: 13
                                    color: "#ffffff"

                                    Canvas {
                                        id: qrCanvas
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        visible: shareComp.rows.length > 0

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            var n = shareComp.rows.length;
                                            if (n === 0) return;
                                            var m = Math.max(1, Math.floor(Math.min(width, height) / n));
                                            var ox = Math.floor((width - m * n) / 2);
                                            var oy = Math.floor((height - m * n) / 2);
                                            ctx.fillStyle = "#121214";
                                            for (var y = 0; y < n; y++) {
                                                var row = shareComp.rows[y];
                                                for (var x = 0; x < row.length; x++) {
                                                    if (row.charAt(x) === "1") {
                                                        ctx.fillRect(ox + x * m, oy + y * m, m, m);
                                                    }
                                                }
                                            }
                                        }

                                        Connections {
                                            target: shareComp
                                            function onRowsChanged() { qrCanvas.requestPaint(); }
                                        }
                                        Component.onCompleted: qrCanvas.requestPaint()
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: shareComp.rows.length === 0
                                        text: "Loading QR…"
                                        color: Qt.rgba(0, 0, 0, 0.6)
                                        font.pixelSize: 11
                                        renderType: Text.NativeRendering
                                    }
                                }

                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: "Point a phone's camera at the code to join " + modelData.ssid + ", or type the password in."
                                    color: Qt.rgba(255, 255, 255, 0.65)
                                    font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                    font.pixelSize: 11
                                    lineHeight: 1.15
                                    renderType: Text.NativeRendering
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 38
                                    radius: 8
                                    color: Qt.rgba(255, 255, 255, 0.06)

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.right: eyeBtn.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shareComp.revealed ? (shareComp.info.psk || "No password") : "••••••••••"
                                        color: "#ffffff"
                                        font.family: shareComp.revealed ? ((typeof Theme !== "undefined" && Theme.fontFamilyNerd) ? Theme.fontFamilyNerd : "JetBrainsMono Nerd Font") : ((typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans")
                                        font.pixelSize: shareComp.revealed ? 11 : 13
                                        font.letterSpacing: shareComp.revealed ? 0.5 : 2
                                        elide: Text.ElideRight
                                        renderType: Text.NativeRendering
                                    }

                                    MaterialSymbol {
                                        id: eyeBtn
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: shareComp.revealed ? "visibility_off" : "visibility"
                                        iconSize: 18
                                        color: Qt.rgba(255, 255, 255, 0.60)
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: shareComp.revealed = !shareComp.revealed
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 30
                                    radius: 999
                                    color: copyBtnMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.20)

                                    Text {
                                        anchors.centerIn: parent
                                        text: shareComp.copied ? "Copied" : "Copy password"
                                        color: "#ffffff"
                                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                        font.bold: true
                                        font.pixelSize: 11
                                        renderType: Text.NativeRendering
                                    }

                                    MouseArea {
                                        id: copyBtnMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            var pass = shareComp.info.psk || "";
                                            if (pass) {
                                                Quickshell.execDetached(["wl-copy", pass]);
                                                shareComp.copied = true;
                                                copiedTimer.restart();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    id: errorText
                    visible: netItem.connectFailed && !netItem.isConnected && !netItem.isConnecting
                    width: parent.width - 28
                    text: netItem.failReason || "Connection failed."
                    color: "#f87171"
                    font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    renderType: Text.NativeRendering
                }

                Row {
                    visible: netItem.isTrusted
                    spacing: 8

                    Rectangle {
                        id: autoBox
                        readonly property bool checked: !!modelData.autoconnect
                        width: 15; height: 15; radius: 4
                        color: checked ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : "transparent"
                        border.width: 1.5
                        border.color: checked ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.35)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: autoBox.checked
                            text: "check"
                            iconSize: 11
                            color: "#121214"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleAutoConnect(modelData.ssid, !autoBox.checked)
                        }
                    }

                    Text {
                        text: "Connect automatically"
                        color: Qt.rgba(255, 255, 255, 0.65)
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.bold: true
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
}
