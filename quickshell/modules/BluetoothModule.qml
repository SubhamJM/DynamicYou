import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../"

ColumnLayout {
    id: btModule
    anchors.fill: parent
    spacing: 8
    focus: true
    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    // Sleek Dark OLED Palette with Matushell Elevation
    readonly property color colSurface: "#000000"
    readonly property color colCard: Qt.rgba(255, 255, 255, 0.045)
    readonly property color colCardHover: Qt.rgba(255, 255, 255, 0.08)
    readonly property color colCardActive: Qt.rgba(255, 255, 255, 0.065)
    readonly property color colChipBg: Qt.rgba(255, 255, 255, 0.07)
    readonly property color colText: Theme.colors.text_primary ?? "#f8fafc"
    readonly property color colSubtext: Theme.colors.text_secondary ?? "#94a3b8"
    readonly property color colMuted: Theme.colors.text_muted ?? "#64748b"
    readonly property color colAccent: Theme.accent ?? "#38bdf8"
    readonly property color colGreen: "#30d158"
    readonly property color colRed: "#ff453a"

    // State maps for expanded cards and live device batteries
    property var stateMap: ({})
    property var batteryMap: ({})

    readonly property int calculatedHeight: {
        var base = 160;
        var count = filteredDevices ? filteredDevices.length : 0;
        if (!isEnabled || count === 0) return 285;
        var listH = 0;
        for (var i = 0; i < count; i++) {
            var dev = filteredDevices[i];
            var exp = stateMap && stateMap[dev.mac] && stateMap[dev.mac].isExpanded;
            listH += (exp ? 96 : 50) + 6;
        }
        return Math.min(480, Math.max(285, base + listH + 12));
    }

    readonly property var adapter: typeof Bluetooth !== "undefined" ? Bluetooth.defaultAdapter : null
    readonly property bool isEnabled: adapter ? adapter.enabled : false
    readonly property bool isDiscovering: adapter ? adapter.discovering : false

    // Batch Bluetooth Battery Scanner (throttled, only runs on open or manual refresh)
    Process {
        id: btBatchBatteryScanner
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/bt-status.py").toString().replace("file://", ""), "--all"]
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
                btModule.batteryMap = bmap;
            }
        }
    }

    Component.onCompleted: {
        if (btModule.isEnabled && !btBatchBatteryScanner.running) {
            btBatchBatteryScanner.running = true;
        }
    }

    // Refresh scanner periodically when Bluetooth popup is active (throttled 4s)
    Timer {
        interval: 4000
        running: (root.activeMode === "bluetooth" || (root.activeMode === "utility" && root.utilMod && root.utilMod.activeSection === "bluetooth")) && btModule.isEnabled
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (!btBatchBatteryScanner.running) btBatchBatteryScanner.running = true;
        }
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if ((root.activeMode === "bluetooth" || (root.activeMode === "utility" && root.utilMod && root.utilMod.activeSection === "bluetooth")) && btModule.isEnabled) {
                if (!btBatchBatteryScanner.running) btBatchBatteryScanner.running = true;
            }
        }
    }

    function toggleExpand(mac) {
        var sm = Object.assign({}, btModule.stateMap);
        if (!sm[mac]) sm[mac] = { isExpanded: false };
        sm[mac].isExpanded = !sm[mac].isExpanded;
        btModule.stateMap = sm;
    }

    // Device icon mapper based on hints (Material Symbols)
    function iconFor(dev) {
        var icon = (dev.device && dev.device.icon) ? dev.device.icon.toLowerCase() : "";
        var name = (dev.name || "").toLowerCase();
        if (icon.includes("audio") || icon.includes("headset") || icon.includes("headphone") ||
            name.includes("bud") || name.includes("pod") || name.includes("wh-") || name.includes("headphone") || name.includes("ear")) {
            return "headphones";
        }
        if (icon.includes("phone") || name.includes("phone") || name.includes("iphone") || name.includes("android")) return "smartphone";
        if (icon.includes("computer") || icon.includes("laptop") || name.includes("mac") || name.includes("pc")) return "laptop";
        if (icon.includes("mouse") || name.includes("mouse") || name.includes("trackpad")) return "mouse";
        if (icon.includes("keyboard") || name.includes("keyboard") || name.includes("key")) return "keyboard";
        if (icon.includes("gamepad") || icon.includes("joystick") || name.includes("controller")) return "sports_esports";
        return dev.connected ? "bluetooth_connected" : "bluetooth";
    }

    function batteryIconFor(pct) {
        if (pct >= 85) return "battery_full";
        if (pct >= 60) return "battery_5_bar";
        if (pct >= 35) return "battery_3_bar";
        if (pct >= 15) return "battery_2_bar";
        return "battery_1_bar";
    }

    // Connected device summary helper
    readonly property var primaryConnectedDevice: {
        for (var i = 0; i < filteredDevices.length; i++) {
            if (filteredDevices[i].connected) return filteredDevices[i];
        }
        return null;
    }

    readonly property string primaryBattery: {
        if (!primaryConnectedDevice) return "";
        if (typeof dashMod !== "undefined" && dashMod.btConnectedMac === primaryConnectedDevice.mac && dashMod.btIslandBattery !== "") {
            return dashMod.btIslandBattery;
        }
        return batteryMap[primaryConnectedDevice.mac] || "";
    }

    readonly property var filteredDevices: {
        if (typeof Bluetooth === "undefined" || !Bluetooth.devices) return [];
        var rawList = Bluetooth.devices.values;
        var seenKeys = {};
        var result = [];

        for (var i = 0; i < rawList.length; i++) {
            var dev = rawList[i];
            var devName = dev.name ? dev.name.trim() : "";
            var mac = dev.address ? dev.address.trim() : "";
            if (!mac && !devName) continue;

            // If not discovering, only show paired or connected devices
            if (!btModule.isDiscovering && !dev.paired && !dev.connected) continue;

            // Filter out anonymous raw MAC hex addresses unless paired or connected
            var isRawMac = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/.test(devName) || 
                           /^([0-9A-Fa-f]{2}-){5}([0-9A-Fa-f]{2})$/.test(devName);
            if (isRawMac && !dev.paired && !dev.connected) continue;
            if (devName === "" && !dev.paired && !dev.connected) continue;

            var key = mac || devName;
            if (!seenKeys[key]) {
                seenKeys[key] = true;
                result.push({
                    "device": dev,
                    "mac": mac,
                    "name": devName || mac,
                    "connected": dev.connected,
                    "paired": dev.paired
                });
            }
        }

        return result.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
    }

    // ========================================================
    // 1. HERO STATUS CARD (Matushell Duotone Surface)
    // ========================================================
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 94
        height: 94
        radius: 14
        color: btModule.colCard

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 8

            // Top Status Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Tactile Back Button
                IrisIconButton {
                    buttonSize: 28
                    buttonRadius: 8
                    flat: true
                    icon: "arrow_back"
                    iconSize: 15
                    iconColor: btModule.colText
                    onClicked: root.switchMode("utility", true)
                }

                // Squircle Icon Badge
                Rectangle {
                    width: 38
                    height: 38
                    radius: 11
                    color: btModule.colChipBg

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: {
                            if (!btModule.isEnabled) return "bluetooth_disabled";
                            if (btModule.primaryConnectedDevice) return btModule.iconFor(btModule.primaryConnectedDevice);
                            return "bluetooth";
                        }
                        iconSize: 19
                        fill: btModule.primaryConnectedDevice ? 1 : 0
                        color: {
                            if (!btModule.isEnabled) return btModule.colMuted;
                            if (btModule.primaryConnectedDevice) return btModule.colAccent;
                            return btModule.colText;
                        }
                    }
                }

                // Title + Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!btModule.isEnabled) return "Bluetooth Disabled";
                            if (btModule.primaryConnectedDevice) return btModule.primaryConnectedDevice.name;
                            return "Bluetooth Ready";
                        }
                        font.family: "Readex Pro"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: btModule.colText
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!btModule.isEnabled) return "Turn on to discover & pair devices";
                            if (btModule.primaryConnectedDevice) return "Connected • Active Audio Sink";
                            return "Discoverable to nearby devices";
                        }
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        color: btModule.colSubtext
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                // Solid Status Pill
                Rectangle {
                    radius: 10
                    color: Qt.alpha(btModule.primaryConnectedDevice ? btModule.colAccent : btModule.colMuted, 0.14)
                    implicitWidth: statusRow.implicitWidth + 14
                    implicitHeight: 22

                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: {
                                if (!btModule.isEnabled) return btModule.colMuted;
                                return btModule.colAccent;
                            }
                            SequentialAnimation on opacity {
                                running: btModule.isEnabled && (btModule.primaryConnectedDevice !== null)
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            text: {
                                if (!btModule.isEnabled) return "OFF";
                                if (btModule.primaryConnectedDevice) return "CONNECTED";
                                return "READY";
                            }
                            font.family: "Readex Pro"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                            color: {
                                if (!btModule.isEnabled) return btModule.colMuted;
                                return btModule.colAccent;
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Bottom Tonal Metadata Chips Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Chip 1: MAC / Adapter Address
                Rectangle {
                    height: 22
                    radius: 6
                    color: btModule.colChipBg
                    implicitWidth: chipMacRow.implicitWidth + 12

                    Row {
                        id: chipMacRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "laptop"
                            iconSize: 12
                            color: btModule.colMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: btModule.primaryConnectedDevice ? btModule.primaryConnectedDevice.mac : (btModule.adapter ? (btModule.adapter.name || "hci0") : "hci0")
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: btModule.colSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Chip 2: Battery Percentage (Only if primary device has battery)
                Rectangle {
                    visible: btModule.primaryConnectedDevice !== null && btModule.primaryBattery !== ""
                    height: 22
                    radius: 6
                    color: {
                        var pct = parseInt(btModule.primaryBattery) || 100;
                        return pct < 20 ? Qt.alpha(btModule.colRed, 0.22) : btModule.colChipBg;
                    }
                    implicitWidth: chipBatRow.implicitWidth + 12

                    Row {
                        id: chipBatRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: {
                                var pct = parseInt(btModule.primaryBattery) || 100;
                                return btModule.batteryIconFor(pct);
                            }
                            iconSize: 13
                            fill: 1
                            color: {
                                var pct = parseInt(btModule.primaryBattery) || 100;
                                return pct < 20 ? btModule.colRed : btModule.colAccent;
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: btModule.primaryBattery
                            font.family: "Readex Pro"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                            color: {
                                var pct = parseInt(btModule.primaryBattery) || 100;
                                return pct < 20 ? btModule.colRed : btModule.colText;
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Chip 3: State Chip (e.g. "Scanning" or "High Quality")
                Rectangle {
                    height: 22
                    radius: 6
                    color: btModule.colChipBg
                    implicitWidth: chipStateRow.implicitWidth + 12

                    Row {
                        id: chipStateRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: btModule.isDiscovering ? "refresh" : (btModule.primaryConnectedDevice ? "volume_up" : "bluetooth")
                            iconSize: 12
                            color: btModule.isDiscovering ? btModule.colAccent : btModule.colMuted
                            anchors.verticalCenter: parent.verticalCenter
                            RotationAnimation on rotation {
                                running: btModule.isDiscovering
                                from: 0; to: 360; duration: 900; loops: Animation.Infinite
                            }
                        }

                        Text {
                            text: btModule.isDiscovering ? "Scanning" : (btModule.primaryConnectedDevice ? "Audio Sink" : "Bluetooth 5.3")
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: btModule.colSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // ========================================================
    // 2. ACTION STRIP & POWER TOGGLE (Solid M3 Controls)
    // ========================================================
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        spacing: 8

        // Section Title + Paired Count Capsule
        Row {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "Paired Devices"
                font.family: "Readex Pro"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                color: btModule.colText
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                height: 18
                radius: 9
                color: btModule.colChipBg
                implicitWidth: countText.implicitWidth + 10
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: btModule.filteredDevices.length + " paired"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: btModule.colSubtext
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Scan/Refresh Button
        Rectangle {
            height: 26
            radius: 13
            color: btModule.isDiscovering ? Qt.alpha(btModule.colAccent, 0.22) : (scanMouse.containsMouse ? btModule.colCardHover : btModule.colChipBg)
            scale: scanMouse.pressed ? 0.94 : (scanMouse.containsMouse ? 1.02 : 1.0)
            implicitWidth: scanRow.implicitWidth + 16
            visible: btModule.isEnabled

            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                id: scanRow
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    text: "refresh"
                    iconSize: 14
                    color: btModule.isDiscovering ? btModule.colAccent : btModule.colSubtext
                    anchors.verticalCenter: parent.verticalCenter
                    RotationAnimation on rotation {
                        running: btModule.isDiscovering
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                    }
                }

                Text {
                    text: btModule.isDiscovering ? "Scanning" : "Scan"
                    font.family: "Readex Pro"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    color: btModule.isDiscovering ? btModule.colAccent : btModule.colText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: scanMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (btModule.adapter) btModule.adapter.discovering = !btModule.adapter.discovering;
                }
            }
        }

        // Material You Solid Power Switch
        Item {
            implicitWidth: 38
            implicitHeight: 22

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: btModule.isEnabled ? btModule.colAccent : btModule.colChipBg

                Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: btModule.isEnabled ? parent.width - width - 3 : 3
                    color: btModule.isEnabled ? "#000000" : btModule.colSubtext
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (btModule.adapter) btModule.adapter.enabled = !btModule.adapter.enabled;
                }
            }
        }
    }

    // ========================================================
    // 3. DEVICE CARDS LIST (Matushell Expressive Visual Language)
    // ========================================================
    ListView {
        id: deviceListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: btModule.isEnabled ? btModule.filteredDevices : []

        // Empty state when Bluetooth is OFF or no devices found
        Item {
            anchors.fill: parent
            visible: !btModule.isEnabled || btModule.filteredDevices.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 44
                    height: 44
                    radius: 14
                    color: btModule.colChipBg

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: btModule.isEnabled ? "bluetooth" : "bluetooth_disabled"
                        iconSize: 22
                        color: btModule.colMuted
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: !btModule.isEnabled ? "Bluetooth is Turned Off" : (btModule.isDiscovering ? "Searching for devices..." : "No paired devices found")
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    color: btModule.colSubtext
                }
            }
        }

        delegate: Rectangle {
            id: devCard
            width: ListView.view.width
            property bool isExpanded: btModule.stateMap[modelData.mac] ? btModule.stateMap[modelData.mac].isExpanded : false

            // Strict battery resolution: ONLY show battery when device is CONNECTED
            property string batteryLvl: {
                if (!modelData.connected) return "";
                if (typeof dashMod !== "undefined" && dashMod.btConnectedMac === modelData.mac && dashMod.btIslandBattery !== "") {
                    return dashMod.btIslandBattery;
                }
                return btModule.batteryMap[modelData.mac] || "";
            }
            property int batteryPct: batteryLvl !== "" ? parseInt(batteryLvl) : -1

            // Dynamic height (50px collapsed, 92px expanded with drawer)
            height: isExpanded ? 92 : 50
            radius: 12
            color: modelData.connected ? (cardHover.containsMouse ? btModule.colCardHover : btModule.colCardActive) : (cardHover.containsMouse ? btModule.colCardHover : btModule.colCard)
            clip: true

            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
            Behavior on color { ColorAnimation { duration: 150 } }

            MouseArea {
                id: cardHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btModule.toggleExpand(modelData.mac)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Top Primary Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Squircle Icon Badge
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        color: btModule.colChipBg

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: btModule.iconFor(modelData)
                            iconSize: 17
                            fill: modelData.connected ? 1 : 0
                            color: modelData.connected ? btModule.colAccent : btModule.colSubtext
                        }
                    }

                    // Device Name & Status Chips
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: modelData.name
                            color: btModule.colText
                            font.family: "Readex Pro"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Row {
                            spacing: 5
                            Rectangle {
                                height: 16
                                radius: 8
                                color: btModule.colChipBg
                                implicitWidth: statusChipRow.implicitWidth + 10

                                Row {
                                    id: statusChipRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Rectangle {
                                        visible: modelData.connected
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: btModule.colAccent
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                                        font.family: "Noto Sans"
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        renderType: Text.NativeRendering
                                        color: modelData.connected ? btModule.colAccent : btModule.colSubtext
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // Battery Badge Pill (Visible only if connected and battery reported)
                    Rectangle {
                        visible: modelData.connected && devCard.batteryLvl !== ""
                        height: 22
                        radius: 7
                        color: (devCard.batteryPct >= 0 && devCard.batteryPct < 20) ? Qt.alpha(btModule.colRed, 0.22) : btModule.colChipBg
                        implicitWidth: devBatRow.implicitWidth + 10

                        Row {
                            id: devBatRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: devCard.batteryLvl
                                font.family: "Readex Pro"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                color: (devCard.batteryPct >= 0 && devCard.batteryPct < 20) ? btModule.colRed : btModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            MaterialSymbol {
                                text: btModule.batteryIconFor(devCard.batteryPct)
                                iconSize: 13
                                fill: 1
                                color: (devCard.batteryPct >= 0 && devCard.batteryPct < 20) ? btModule.colRed : btModule.colAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Expand Caret Icon
                    MaterialSymbol {
                        text: "expand_more"
                        iconSize: 18
                        color: btModule.colMuted
                        rotation: devCard.isExpanded ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
                    }
                }

                // Drawer Action Row
                RowLayout {
                    Layout.fillWidth: true
                    visible: devCard.isExpanded
                    spacing: 6

                    // Connect / Disconnect Action Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 8
                        color: btActionMouse.containsMouse 
                            ? (modelData.connected ? Qt.alpha(btModule.colRed, 0.25) : Qt.alpha(btModule.colAccent, 0.25)) 
                            : (modelData.connected ? Qt.alpha(btModule.colRed, 0.16) : Qt.alpha(btModule.colAccent, 0.16))
                        scale: btActionMouse.pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                text: modelData.connected ? "link_off" : "link"
                                iconSize: 14
                                color: modelData.connected ? btModule.colRed : btModule.colAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.connected ? "Disconnect" : "Connect"
                                font.family: "Readex Pro"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                color: modelData.connected ? btModule.colRed : btModule.colAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: btActionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.connected) {
                                    modelData.device.disconnect();
                                } else {
                                    modelData.device.connect();
                                }
                            }
                        }
                    }

                    // Forget Device Button
                    Rectangle {
                        Layout.preferredWidth: 80
                        height: 28
                        radius: 8
                        color: forgetMouse.containsMouse ? btModule.colCardHover : btModule.colChipBg
                        scale: forgetMouse.pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                text: "delete"
                                iconSize: 13
                                color: btModule.colSubtext
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Forget"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                                color: btModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: forgetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bluetoothctl", "remove", modelData.mac]);
                            }
                        }
                    }

                    // MAC Pill
                    Rectangle {
                        Layout.preferredWidth: 120
                        height: 28
                        radius: 8
                        color: btModule.colChipBg

                        Text {
                            anchors.centerIn: parent
                            text: modelData.mac
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: btModule.colSubtext
                        }
                    }
                }
            }
        }
    }
}
