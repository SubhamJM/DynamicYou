import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../"

// ────────────────────────────────────────────────────────────
// Lucid Bluetooth Architecture & Design (1:1 with Lucid BluetoothPanel.qml & BtDeviceRow.qml)
// Exact copy of Lucid's padding, layouts, component metrics, and enclosed card hierarchy.
// ────────────────────────────────────────────────────────────
Item {
    id: root

    // Adapter bindings (Quickshell.Bluetooth)
    readonly property var adapter: (typeof Bluetooth !== "undefined") ? Bluetooth.defaultAdapter : null
    readonly property bool btEnabled: !!(adapter && adapter.enabled)
    readonly property bool discovering: !!(adapter && adapter.discovering)
    property bool ownScan: false

    onDiscoveringChanged: {
        if (!root.discovering)
            root.ownScan = false;
    }

    // Refresh tick to keep devices & statuses updated
    property int refreshTick: 0
    Timer {
        interval: 2000
        running: (root.visible && root.btEnabled)
        repeat: true
        onTriggered: {
            root.refreshTick++;
            if (!btBatchBatteryScanner.running) {
                btBatchBatteryScanner.running = true;
            }
        }
    }

    // Live battery map from bt-status.py fallback
    property var batteryMap: ({})

    Process {
        id: btBatchBatteryScanner
        running: false
        command: ["python3", Quickshell.shellDir + "/scripts/bt-status.py", "--all"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return;
                var lines = this.text.trim().split("\n");
                var bmap = {};
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("=") !== -1) {
                        var p = line.split("=");
                        if (p[0] && p[1]) {
                            bmap[p[0]] = p[1];
                        }
                    }
                }
                root.batteryMap = bmap;
            }
        }
    }

    Process {
        id: btPairProc
    }

    function pairDevice(device) {
        if (!device) return;
        try {
            if (root.adapter && !root.adapter.pairable) {
                root.adapter.pairable = true;
            }
            if (typeof device.pair === "function") {
                device.pair();
                return;
            }
        } catch(e) {}
        btPairProc.command = ["bluetoothctl", "pair", device.address];
        btPairProc.running = true;
    }

    // Helper functions (copied 1:1 from Lucid BluetoothPanel.qml)
    function isMacLike(name) {
        return /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(name || "");
    }

    function getBatteryText(dev) {
        if (!dev) return "";
        if (dev.batteryAvailable) {
            let b = dev.battery;
            if (b !== undefined && b !== null && b >= 0) {
                let pct = (b <= 1 && b > 0) ? Math.round(b * 100) : Math.round(b);
                return pct + "%";
            }
        }
        if (root.batteryMap && root.batteryMap[dev.address]) {
            return root.batteryMap[dev.address];
        }
        return "";
    }

    function deviceIconKind(dev) {
        if (!dev) return "bluetooth";
        const iconName = dev.icon || "";
        const devName = dev.name || "";
        const n = (iconName + " " + devName).toLowerCase();

        if (n.includes("headphone") || n.includes("headset") || n.includes("bud") || n.includes("pod") || n.includes("wh-") || n.includes("audio"))
            return "headphones";

        if (n.includes("phone") || n.includes("tablet") || n.includes("iphone") || n.includes("android"))
            return "phone";

        if (n.includes("computer") || n.includes("laptop") || n.includes("mac") || n.includes("pc"))
            return "laptop";

        if (n.includes("keyboard"))
            return "keyboard";

        if (n.includes("mouse"))
            return "mouse";

        if (n.includes("speaker") || n.includes("soundbar") || n.includes("multimedia"))
            return "speaker";

        if (n.includes("watch") || n.includes("band") || n.includes("bip") || n.includes("amazfit"))
            return "watch";

        return "bluetooth";
    }

    function computeGroups() {
        if (!root.adapter || !root.adapter.devices || !root.adapter.devices.values) {
            return {
                "connected": [],
                "paired": [],
                "nearby": []
            };
        }

        const named = root.adapter.devices.values.filter((d) => {
            return d && d.name && d.name.length > 0 && !root.isMacLike(d.name);
        });

        const byName = (arr) => {
            return arr.slice().sort((a, b) => {
                return (a.name || "").localeCompare(b.name || "");
            });
        };

        return {
            "connected": byName(named.filter((d) => {
                return !!d.connected;
            })),
            "paired": byName(named.filter((d) => {
                return !d.connected && !!d.paired;
            })),
            "nearby": byName(named.filter((d) => {
                return !d.connected && !d.paired;
            }))
        };
    }

    // 3-Tier Categorization
    readonly property var rawDevices: (root.adapter && root.adapter.devices) ? root.adapter.devices.values : []
    readonly property var deviceGroups: {
        var _ = root.refreshTick;
        var __ = root.rawDevices;
        return root.computeGroups();
    }
    readonly property var connectedDevices: root.deviceGroups.connected
    readonly property var pairedDevices: root.deviceGroups.paired
    readonly property var nearbyDevices: root.deviceGroups.nearby

    property string expandedKey: ""

    // Pixel-perfect Dynamic Height that hugs Lucid's content with exact enclosed padding
    readonly property int calculatedHeight: {
        if (!root.btEnabled) return 220;
        var contentH = subHeader.height + 6 + col.implicitHeight + 24;
        return Math.min(540, Math.max(220, contentH));
    }

    onVisibleChanged: {
        if (visible) {
            if (root.adapter && root.btEnabled) {
                root.adapter.discovering = true;
            }
            if (!btBatchBatteryScanner.running) {
                btBatchBatteryScanner.running = true;
            }
        }
    }

    // Keyboard support
    focus: true
    Keys.onEscapePressed: (event) => {
        if (root.expandedKey !== "") {
            root.expandedKey = "";
        } else {
            root.parent.collapseToIdle ? root.parent.collapseToIdle() : null;
        }
        event.accepted = true;
    }

    // ========================================================
    // 1. LUCID SUBHEADER (44dp: Back Button, "Bluetooth" Title, Power Switch)
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
            text: "Bluetooth"
            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
            font.pixelSize: 14
            font.bold: true
            color: "#ffffff"
            renderType: Text.NativeRendering
        }

        // Master Bluetooth Power Switch
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 22; radius: 11
            color: root.btEnabled ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.15)
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                width: 16; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: root.btEnabled ? parent.width - width - 3 : 3
                color: root.btEnabled ? "#121214" : Qt.rgba(255, 255, 255, 0.60)
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.adapter) {
                        root.adapter.enabled = !root.adapter.enabled;
                    }
                }
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
        contentHeight: root.btEnabled ? col.implicitHeight : disabledCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // Disabled State (Lucid 1:1)
        Column {
            id: disabledCol
            visible: !root.btEnabled
            width: parent.width
            topPadding: 24
            spacing: 8

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "bluetooth_disabled"
                iconSize: 36
                color: Qt.rgba(255, 255, 255, 0.35)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Bluetooth is turned off"
                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                font.bold: true
                font.pixelSize: 13
                color: "#ffffff"
                renderType: Text.NativeRendering
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Turn on Bluetooth to see nearby devices"
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
                    onClicked: {
                        if (root.adapter) {
                            root.adapter.enabled = true;
                        }
                    }
                }
            }
        }

        // Active Content Column (Lucid 1:1)
        Column {
            id: col
            visible: root.btEnabled
            width: subScroll.width
            spacing: 10

            // ────────────────────────────────────────────────────
            // ITEM 1: SCAN BUTTON CAPSULE (Lucid 1:1)
            // ────────────────────────────────────────────────────
            Item {
                id: scanButton
                width: parent.width
                height: 44

                Timer {
                    interval: 20000
                    running: root.discovering && root.ownScan
                    onTriggered: {
                        if (root.adapter) root.adapter.discovering = false;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.discovering ? Qt.rgba(255, 255, 255, 0.08) : (scanArea.containsMouse ? Qt.rgba(255, 255, 255, 0.065) : Qt.rgba(255, 255, 255, 0.04))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Item {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: root.discovering
                                text: "progress_activity"
                                iconSize: 18
                                color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                                RotationAnimator on rotation {
                                    from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: root.discovering
                                }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: !root.discovering
                                text: "bluetooth_searching"
                                iconSize: 20
                                color: Qt.rgba(255, 255, 255, 0.65)
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.discovering ? "Looking for devices…" : "Search for devices"
                            color: root.discovering ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : "#ffffff"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 13
                            renderType: Text.NativeRendering
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.discovering
                        text: "Stop"
                        color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.bold: true
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: scanArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.adapter) return;
                            root.ownScan = !root.discovering;
                            root.adapter.discovering = !root.discovering;
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────
            // ITEM 2: "VISIBLE TO OTHER DEVICES" ROW (Lucid 1:1)
            // ────────────────────────────────────────────────────
            Item {
                width: parent.width
                height: 34

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Visible to other devices"
                    color: Qt.rgba(255, 255, 255, 0.60)
                    font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38; height: 20; radius: 10
                    readonly property bool checked: !!(root.adapter && root.adapter.discoverable)
                    color: checked ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.15)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 14; height: 14; radius: 7
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.checked ? parent.width - width - 3 : 3
                        color: parent.checked ? "#121214" : Qt.rgba(255, 255, 255, 0.60)
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.adapter) {
                                root.adapter.discoverable = !root.adapter.discoverable;
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────
            // ITEM 3: 3-TIER DEVICE LIST (Lucid 1:1)
            // ────────────────────────────────────────────────────
            Column {
                id: listCol
                width: parent.width
                spacing: 14

                // SECTION 1: CONNECTED
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.connectedDevices.length > 0

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
                        model: root.connectedDevices
                        BtDeviceRow { group: "connected" }
                    }
                }

                // SECTION 2: PAIRED
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.pairedDevices.length > 0

                    Text {
                        text: "Paired"
                        color: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.bold: true
                        font.pixelSize: 12
                        leftPadding: 4
                        bottomPadding: 3
                        renderType: Text.NativeRendering
                    }

                    Repeater {
                        model: root.pairedDevices
                        BtDeviceRow { group: "paired" }
                    }
                }

                // SECTION 3: NEARBY
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.nearbyDevices.length > 0

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
                        model: root.nearbyDevices
                        BtDeviceRow { group: "nearby" }
                    }
                }

                // SECTION 4: EMPTY STATE
                Column {
                    width: parent.width
                    visible: root.connectedDevices.length === 0 && root.pairedDevices.length === 0 && root.nearbyDevices.length === 0
                    topPadding: 18
                    bottomPadding: 6
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.discovering ? "Looking for devices…" : "No devices found"
                        color: Qt.rgba(255, 255, 255, 0.45)
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !root.discovering
                        text: "Tap “Search for devices” to scan"
                        color: Qt.rgba(255, 255, 255, 0.30)
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }

    // ========================================================
    // 3. LUCID BTDEVICEROW (Copied 1:1 from Lucid BluetoothPanel.qml, enclosed card)
    // ========================================================
    component BtDeviceRow: Rectangle {
        id: devItem

        required property var modelData
        required property string group

        readonly property bool isExpanded: root.expandedKey === modelData.address
        readonly property bool isConnected: !!modelData.connected
        readonly property string iconKind: root.deviceIconKind(modelData)
        readonly property bool isConnecting: {
            try {
                return (typeof BluetoothDeviceState !== "undefined")
                    ? modelData.state === BluetoothDeviceState.Connecting
                    : false;
            } catch(e) { return false; }
        }
        readonly property bool isPairing: !!modelData.pairing
        readonly property bool isPaired: !!modelData.paired

        property bool actionFailed: false
        property bool wasBusy: false
        property bool renaming: false
        property string renameText: ""

        width: parent.width
        radius: devItem.isExpanded ? 18 : 14
        color: devItem.isExpanded ? Qt.rgba(255, 255, 255, 0.08) : (rowArea.containsMouse ? Qt.rgba(255, 255, 255, 0.065) : Qt.rgba(255, 255, 255, 0.04))
        border.width: devItem.isExpanded ? 1 : 0
        border.color: devItem.isExpanded ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
        clip: true

        Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        height: 56 + (devItem.isExpanded ? (expandContent.implicitHeight + 8) : 0)

        Connections {
            target: devItem.modelData
            ignoreUnknownSignals: true
            function onStateChanged() {
                try {
                    if (typeof BluetoothDeviceState !== "undefined" && devItem.modelData.state === BluetoothDeviceState.Connecting) {
                        devItem.wasBusy = true;
                        devItem.actionFailed = false;
                    } else if (devItem.wasBusy && devItem.group !== "nearby") {
                        devItem.actionFailed = !devItem.modelData.connected;
                        devItem.wasBusy = false;
                    }
                } catch(e) {}
            }
            function onPairingChanged() {
                try {
                    if (devItem.modelData.pairing) {
                        devItem.wasBusy = true;
                        devItem.actionFailed = false;
                    } else if (devItem.wasBusy && devItem.group === "nearby") {
                        devItem.wasBusy = false;
                        if (devItem.modelData.paired) {
                            devItem.actionFailed = false;
                            devItem.modelData.connect();
                        } else {
                            devItem.actionFailed = true;
                        }
                    }
                } catch(e) {}
            }
        }

        Column {
            id: devCardCol
            width: parent.width

            Item {
                width: parent.width
                height: 56

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 12

                    // Icon Tile
                    Item {
                        width: 36
                        height: 36
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            color: devItem.isConnected ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: ({
                                "headphones": "headphones",
                                "phone": "smartphone",
                                "laptop": "laptop",
                                "speaker": "speaker",
                                "keyboard": "keyboard",
                                "mouse": "mouse",
                                "watch": "watch"
                            })[devItem.iconKind] || "bluetooth"
                            iconSize: 20
                            fill: devItem.isConnected ? 1 : 0
                            color: devItem.isConnected ? "#121214" : "#ffffff"
                        }

                        // Connected Pulsing Dot
                        Rectangle {
                            id: btDot
                            visible: devItem.isConnected
                            width: 8
                            height: 8
                            radius: 4
                            color: "#30d158"
                            border.width: 1.5
                            border.color: "#18181b"
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: -1

                            SequentialAnimation on opacity {
                                running: btDot.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutQuad }
                            }
                        }
                    }

                    // Device Name + Subtitle
                    Column {
                        width: parent.width - 36 - 20 - 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: devItem.modelData.name || devItem.modelData.address
                            color: "#ffffff"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.bold: true
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Row {
                            width: parent.width
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (devItem.isPairing) return "Pairing…";
                                    if (devItem.isConnecting) return "Connecting…";
                                    if (devItem.isConnected) {
                                        let batt = root.getBatteryText(devItem.modelData);
                                        return "Connected" + (batt !== "" ? " · " + batt : "");
                                    }
                                    if (devItem.isPaired) {
                                        return devItem.modelData.trusted ? "Paired · Trusted" : "Paired";
                                    }
                                    return "Available";
                                }
                                color: devItem.isConnected ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.50)
                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                font.pixelSize: 10
                                renderType: Text.NativeRendering
                            }

                            // Battery Progress Bar
                            Rectangle {
                                readonly property string battStr: root.getBatteryText(devItem.modelData)
                                readonly property real battPct: {
                                    if (devItem.modelData.batteryAvailable && devItem.modelData.battery !== undefined && devItem.modelData.battery !== null) {
                                        return devItem.modelData.battery <= 1 ? devItem.modelData.battery : devItem.modelData.battery / 100;
                                    }
                                    if (battStr !== "") {
                                        return parseInt(battStr) / 100;
                                    }
                                    return 0;
                                }
                                visible: devItem.isConnected && battPct > 0
                                width: 22
                                height: 5
                                radius: 2.5
                                color: Qt.rgba(255, 255, 255, 0.15)
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(2, parent.width * Math.max(0, Math.min(1, parent.battPct)))
                                    height: parent.height
                                    radius: 2.5
                                    color: parent.battPct < 0.2 ? "#ff453a" : "#30d158"
                                }
                            }
                        }
                    }

                    // Rotating Chevron
                    MaterialSymbol {
                        text: "expand_more"
                        iconSize: 20
                        color: Qt.rgba(255, 255, 255, 0.60)
                        anchors.verticalCenter: parent.verticalCenter
                        rotation: devItem.isExpanded ? 180 : 0
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
                    onClicked: {
                        devItem.renaming = false;
                        root.expandedKey = devItem.isExpanded ? "" : devItem.modelData.address;
                    }
                }
            }

            // Expand Drawer
            Item {
                id: expandArea
                width: parent.width
                height: devItem.isExpanded ? (expandContent.implicitHeight + 8) : 0
                clip: true

                Column {
                    id: expandContent
                    width: parent.width
                    leftPadding: 14
                    rightPadding: 14
                    topPadding: 4
                    bottomPadding: 14
                    spacing: 10
                    opacity: devItem.isExpanded ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    // Primary Action Buttons Row (Connect / Disconnect / Pair + Forget)
                    Row {
                        width: parent.width - 28
                        height: 32
                        spacing: 8

                        Rectangle {
                            id: primaryBtn
                            readonly property bool busy: devItem.isPairing || devItem.isConnecting
                            width: devItem.group === "nearby" ? parent.width : (parent.width - 8) / 2
                            height: parent.height
                            radius: 999
                            color: busy ? Qt.rgba(255, 255, 255, 0.12)
                                        : (devItem.isConnected
                                            ? Qt.rgba(255, 69, 58, 0.18)
                                            : (primaryArea.containsMouse
                                                ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7")
                                                : Qt.rgba(255, 255, 255, 0.14)))
                            border.width: devItem.isConnected ? 1 : 0
                            border.color: devItem.isConnected ? Qt.rgba(255, 69, 58, 0.40) : "transparent"
                            opacity: busy ? 0.7 : 1.0
                            scale: primaryArea.pressed ? 0.96 : 1.0

                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (devItem.isPairing) return "Pairing…";
                                    if (devItem.isConnecting) return "Connecting…";
                                    if (devItem.group === "nearby") return "Pair";
                                    return devItem.isConnected ? "Disconnect" : "Connect";
                                }
                                color: primaryBtn.busy
                                    ? Qt.rgba(255, 255, 255, 0.50)
                                    : (devItem.isConnected ? "#ff453a" : "#ffffff")
                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                font.bold: true
                                font.pixelSize: 12
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: primaryArea
                                anchors.fill: parent
                                enabled: !primaryBtn.busy
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    devItem.actionFailed = false;
                                    if (devItem.group === "nearby") {
                                        root.pairDevice(devItem.modelData);
                                    } else if (devItem.isConnected) {
                                        devItem.modelData.disconnect();
                                    } else {
                                        devItem.modelData.connect();
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: forgetBtn
                            visible: devItem.group !== "nearby"
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 999
                            color: forgetArea.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : "transparent"
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.20)
                            scale: forgetArea.pressed ? 0.96 : 1.0

                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "Forget Device"
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
                                onClicked: {
                                    root.expandedKey = "";
                                    devItem.modelData.forget();
                                }
                            }
                        }
                    }

                    // Cancel pairing link
                    Text {
                        visible: devItem.isPairing
                        text: "Cancel pairing"
                        color: Qt.rgba(255, 255, 255, 0.50)
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 11
                        font.underline: cancelPairArea.containsMouse
                        renderType: Text.NativeRendering

                        MouseArea {
                            id: cancelPairArea
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                try { devItem.modelData.cancelPair(); } catch(e) {}
                            }
                        }
                    }

                    // Error text
                    Text {
                        visible: devItem.actionFailed && !devItem.isConnected && !devItem.isPairing && !devItem.isConnecting
                        width: parent.width - 28
                        text: devItem.group === "nearby" ? "Pairing failed. Please try again." : "Failed to connect. The device may be out of range."
                        color: "#ff453a"
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        renderType: Text.NativeRendering
                    }

                    // Option Checkboxes (Auto-reconnect, Allow wake, Block)
                    Flow {
                        width: parent.width - 28
                        visible: devItem.group !== "nearby"
                        spacing: 12

                        // Auto-reconnect
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 15; height: 15; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: devItem.modelData.trusted ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : "transparent"
                                border.width: 1.5
                                border.color: devItem.modelData.trusted ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.30)

                                MaterialSymbol {
                                    visible: devItem.modelData.trusted
                                    anchors.centerIn: parent
                                    text: "check"
                                    iconSize: 12
                                    color: "#121214"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: devItem.modelData.trusted = !devItem.modelData.trusted
                                }
                            }

                            Text {
                                text: "Auto-reconnect"
                                color: Qt.rgba(255, 255, 255, 0.70)
                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                font.bold: true
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: devItem.modelData.trusted = !devItem.modelData.trusted
                                }
                            }
                        }

                        // Allow wake
                        Row {
                            visible: devItem.isConnected
                            spacing: 8
                            Rectangle {
                                width: 15; height: 15; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: devItem.modelData.wakeAllowed ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : "transparent"
                                border.width: 1.5
                                border.color: devItem.modelData.wakeAllowed ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.30)

                                MaterialSymbol {
                                    visible: devItem.modelData.wakeAllowed
                                    anchors.centerIn: parent
                                    text: "check"
                                    iconSize: 12
                                    color: "#121214"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: devItem.modelData.wakeAllowed = !devItem.modelData.wakeAllowed
                                }
                            }

                            Text {
                                text: "Allow wake"
                                color: Qt.rgba(255, 255, 255, 0.70)
                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                font.bold: true
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: devItem.modelData.wakeAllowed = !devItem.modelData.wakeAllowed
                                }
                            }
                        }

                        // Block
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 15; height: 15; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: devItem.modelData.blocked ? "#ff453a" : "transparent"
                                border.width: 1.5
                                border.color: devItem.modelData.blocked ? "#ff453a" : Qt.rgba(255, 255, 255, 0.30)

                                MaterialSymbol {
                                    visible: devItem.modelData.blocked
                                    anchors.centerIn: parent
                                    text: "check"
                                    iconSize: 12
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: devItem.modelData.blocked = !devItem.modelData.blocked
                                }
                            }

                            Text {
                                text: "Block"
                                color: Qt.rgba(255, 255, 255, 0.70)
                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                                font.bold: true
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: devItem.modelData.blocked = !devItem.modelData.blocked
                                }
                            }
                        }
                    }

                    // Inline Rename
                    Row {
                        visible: devItem.group !== "nearby" && !devItem.renaming
                        spacing: 16

                        Text {
                            text: "Rename"
                            color: Qt.rgba(255, 255, 255, 0.60)
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.pixelSize: 11
                            font.underline: renameArea.containsMouse
                            renderType: Text.NativeRendering

                            MouseArea {
                                id: renameArea
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    devItem.renameText = devItem.modelData.name;
                                    devItem.renaming = true;
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: renameBox
                        visible: devItem.renaming
                        width: parent.width - 28
                        height: 30
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: renameInput.activeFocus ? ((typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7") : Qt.rgba(255, 255, 255, 0.15)

                        Connections {
                            target: devItem
                            function onRenamingChanged() {
                                if (devItem.renaming) renameInput.forceActiveFocus();
                            }
                        }

                        TextInput {
                            id: renameInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            color: "#ffffff"
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.pixelSize: 12
                            selectByMouse: true
                            text: devItem.renameText
                            Keys.onReturnPressed: {
                                if (text.trim().length > 0) devItem.modelData.name = text.trim();
                                devItem.renaming = false;
                            }
                            Keys.onEscapePressed: devItem.renaming = false
                        }
                    }
                }
            }
        }
    }
}
