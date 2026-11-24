import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import ".." as Connectivity
import "." as BtUi

Item {
    id: root

    Component.onDestruction: stopScan()

    property bool active: false
    property string expandedKey: ""
    property int resizingRows: 0

    signal closeRequested()

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: adapter ? adapter.enabled : false
    readonly property var deviceGroups: root.computeGroups()
    readonly property var connectedDevices: root.deviceGroups.connected
    readonly property var pairedDevices: root.deviceGroups.paired
    readonly property var nearbyDevices: root.deviceGroups.nearby
    readonly property bool anyConnecting: (adapter && adapter.devices) ? adapter.devices.values.some((d) => {
        return d.state === BluetoothDeviceState.Connecting;
    }) : false
    readonly property bool discovering: !!(root.adapter && root.adapter.discovering)
    property var scanAdapter: null
    property bool scanFailed: false
    property bool scanAttempted: false
    property string serviceStatus: ""
    readonly property bool hardwareBlocked: BtUi.Bt.hardBlocked

    readonly property string unavailableTitle: {
        if (hardwareBlocked) return BtUi.I18n.tr("Bluetooth is blocked");
        if (!adapter && ["inactive", "failed", "unknown"].includes(serviceStatus))
            return BtUi.I18n.tr("Bluetooth service is stopped");
        if (!adapter) return BtUi.I18n.tr("No Bluetooth adapter found");
        if (BtUi.Bt.powerPending) return BtUi.I18n.tr("Turning on Bluetooth…");
        return BtUi.I18n.tr("Bluetooth is off");
    }

    readonly property string unavailableDetail: {
        if (BtUi.Bt.blockReason !== "") return BtUi.Bt.blockReason;
        if (!adapter && ["inactive", "failed", "unknown"].includes(serviceStatus))
            return BtUi.I18n.tr("Start bluetooth.service, then reopen this panel.");
        if (!adapter) return BtUi.I18n.tr("Check that a Bluetooth adapter is enabled and recognized by the system.");
        return BtUi.I18n.tr("Turn it on to find nearby devices.");
    }

    readonly property string label: {
        if (!btEnabled)
            return unavailableTitle;

        if (root.connectedDevices.length === 1) {
            let d = root.connectedDevices[0];
            let batt = root.getBatteryText(d);
            return root.deviceName(d) + (batt !== "" ? " (" + batt + ")" : "");
        }
        if (root.connectedDevices.length > 1)
            return BtUi.I18n.tr("%1 devices connected", root.connectedDevices.length);

        if (root.anyConnecting)
            return BtUi.I18n.tr("Connecting...");

        if (root.discovering)
            return BtUi.I18n.tr("Scanning...");

        return BtUi.I18n.tr("Not connected");
    }

    function getBatteryText(dev) {
        if (!dev || !dev.batteryAvailable)
            return "";

        let b = dev.battery;
        if (b === undefined || b === null || b < 0)
            return "";

        let pct = (b <= 1 && b > 0) ? Math.round(b * 100) : Math.round(b);
        return pct + '%';
    }

    function isMacLike(name) {
        return /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(name || "");
    }

    function deviceIconKind(iconName) {
        const n = (iconName || "").toLowerCase();
        if (n.includes("headphone") || n.includes("headset"))
            return "headphones";

        if (n.includes("phone") || n.includes("tablet"))
            return "phone";

        if (n.includes("computer") || n.includes("laptop") || n.includes("pc"))
            return "laptop";

        if (n.includes("keyboard"))
            return "keyboard";

        if (n.includes("mouse"))
            return "mouse";

        if (n.includes("speaker") || n.includes("audio") || n.includes("multimedia"))
            return "speaker";

        return "";
    }

    function computeGroups() {
        if (!root.adapter || !root.adapter.devices)
            return {
            "connected": [],
            "paired": [],
            "nearby": []
        };

        const devices = root.adapter.devices.values;
        const byName = (items) => items.sort((a, b) => {
            return Number(root.namedDevice(b)) - Number(root.namedDevice(a))
                || root.deviceName(a).localeCompare(root.deviceName(b))
                || a.address.localeCompare(b.address);
        });
        return {
            connected: byName(devices.filter(d => d.connected)),
            paired: byName(devices.filter(d => !d.connected && d.paired)),
            nearby: byName(devices.filter(d => !d.connected && !d.paired && !d.blocked))
        };
    }

    function namedDevice(device) {
        return !!(device.name && !root.isMacLike(device.name));
    }

    function deviceName(device) {
        return root.namedDevice(device) ? device.name : BtUi.I18n.tr("Unknown device");
    }

    function startScan() {
        if (!active || !btEnabled || hardwareBlocked || discovering || scanAdapter)
            return;
        scanFailed = false;
        scanAttempted = true;
        scanAdapter = adapter;
        scanStartTimeout.restart();
        scanAdapter.discovering = true;
    }

    function stopScan() {
        scanStartTimeout.stop();
        scanDuration.stop();
        if (!scanAdapter) return;
        const ownedAdapter = scanAdapter;
        scanAdapter = null;
        ownedAdapter.discovering = false;
    }

    onDiscoveringChanged: {
        if (discovering && scanAdapter === adapter) {
            scanStartTimeout.stop();
            scanDuration.restart();
        } else if (!discovering && scanDuration.running) {
            stopScan();
        }
    }

    onAdapterChanged: {
        if (scanAdapter && scanAdapter !== adapter) stopScan();
        Qt.callLater(startScan);
    }

    onBtEnabledChanged: {
        if (btEnabled) Qt.callLater(startScan);
        else stopScan();
    }

    implicitHeight: col.implicitHeight

    onActiveChanged: {
        if (active) {
            serviceStatus = "";
            BtUi.Bt.refresh();
            Qt.callLater(startScan);
        } else {
            expandedKey = "";
            scanFailed = false;
            scanAttempted = false;
            stopScan();
        }
    }

    Timer {
        id: scanStartTimeout
        interval: 4000
        onTriggered: {
            root.stopScan();
            root.scanFailed = true;
        }
    }

    Timer {
        id: scanDuration
        interval: 20000
        onTriggered: root.stopScan()
    }

    Process {
        running: root.active && !root.adapter
        command: ["systemctl", "is-active", "bluetooth.service"]
        stdout: StdioCollector {
            onStreamFinished: root.serviceStatus = text.trim()
        }
    }

    Column {
        id: col

        width: root.width
        spacing: BtUi.Theme.dp(10)

        Connectivity.ConnectivityScanButton {
            width: parent.width
            visible: root.btEnabled
            scanning: root.discovering || root.scanAdapter !== null
            enabled: !root.hardwareBlocked && (!root.discovering || root.scanAdapter !== null)
            glyph: "bluetooth_searching"
            text: scanning ? BtUi.I18n.tr("Scanning for devices…") : BtUi.I18n.tr("Scan for devices")
            actionLabel: scanning && root.scanAdapter !== null ? BtUi.I18n.tr("Stop") : ""
            onClicked: {
                if (root.scanAdapter) root.stopScan();
                else root.startScan();
            }
        }

        Item {
            visible: root.btEnabled
            width: parent.width
            height: BtUi.Theme.dp(34)

            LText {
                anchors.left: parent.left
                anchors.leftMargin: BtUi.Theme.dp(6)
                anchors.verticalCenter: parent.verticalCenter
                role: "bodyMedium"
                color: BtUi.Theme.subtext
                text: BtUi.I18n.tr("Visible to other devices")
            }

            Connectivity.ConnectivityToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                powered: !!(root.adapter && root.adapter.discoverable)
                enabled: root.btEnabled
                Accessible.name: BtUi.I18n.tr("Visible to other devices")
                onClicked: {
                    if (root.adapter)
                        root.adapter.discoverable = !powered;
                }
            }

        }

        Rectangle {
            visible: !root.btEnabled
            width: parent.width
            height: helpText.implicitHeight + 24
            radius: BtUi.Theme.dp(12)
            color: BtUi.Theme.alpha(BtUi.Theme.text, 0.055)

            Text {
                id: helpText
                anchors.fill: parent
                anchors.margins: 12
                text: root.unavailableDetail
                color: BtUi.Theme.subtext
                font.family: BtUi.Theme.fontFamily
                font.pixelSize: BtUi.Theme.fs(13)
                wrapMode: Text.WordWrap
            }
        }

        Text {
            visible: root.btEnabled && root.scanFailed
            width: parent.width
            text: BtUi.I18n.tr("Bluetooth couldn’t start scanning. Try again.")
            color: BtUi.Theme.error
            font.family: BtUi.Theme.fontFamily
            font.pixelSize: BtUi.Theme.fs(13)
            wrapMode: Text.WordWrap
        }

        Column {
            id: listCol

            visible: root.btEnabled
            width: parent.width
            spacing: BtUi.Theme.dp(14)

            Column {
                width: parent.width
                spacing: BtUi.Theme.dp(3)
                visible: root.connectedDevices.length > 0

                Text {
                    text: BtUi.I18n.tr("Connected")
                    color: BtUi.Theme.subtext
                    font.family: BtUi.Theme.fontFamily
                    font.bold: true
                    font.pixelSize: BtUi.Theme.fs(12)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 600, 0)
                    leftPadding: BtUi.Theme.dp(4)
                    bottomPadding: BtUi.Theme.dp(3)
                }

                Repeater {
                    model: ScriptModel { values: root.connectedDevices }

                    BtDeviceRow {
                        group: "connected"
                    }

                }

            }

            Column {
                width: parent.width
                spacing: BtUi.Theme.dp(3)
                visible: root.pairedDevices.length > 0

                Text {
                    text: BtUi.I18n.tr("Paired")
                    color: BtUi.Theme.subtext
                    font.family: BtUi.Theme.fontFamily
                    font.bold: true
                    font.pixelSize: BtUi.Theme.fs(12)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 600, 0)
                    leftPadding: BtUi.Theme.dp(4)
                    bottomPadding: BtUi.Theme.dp(3)
                }

                Repeater {
                    model: ScriptModel { values: root.pairedDevices }

                    BtDeviceRow {
                        group: "paired"
                    }

                }

            }

            Column {
                width: parent.width
                spacing: BtUi.Theme.dp(3)
                visible: root.nearbyDevices.length > 0

                Text {
                    text: BtUi.I18n.tr("Nearby")
                    color: BtUi.Theme.subtext
                    font.family: BtUi.Theme.fontFamily
                    font.bold: true
                    font.pixelSize: BtUi.Theme.fs(12)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 600, 0)
                    leftPadding: BtUi.Theme.dp(4)
                    bottomPadding: BtUi.Theme.dp(3)
                }

                Repeater {
                    model: ScriptModel { values: root.nearbyDevices }

                    BtDeviceRow {
                        group: "nearby"
                    }

                }

            }

            Column {
                width: parent.width
                visible: root.connectedDevices.length === 0 && root.pairedDevices.length === 0 && root.nearbyDevices.length === 0
                topPadding: BtUi.Theme.dp(18)
                bottomPadding: BtUi.Theme.dp(6)
                spacing: BtUi.Theme.dp(4)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.discovering || root.scanAdapter ? BtUi.I18n.tr("Looking for devices…") : BtUi.I18n.tr("No devices found")
                    color: BtUi.Theme.subtext
                    font.family: BtUi.Theme.fontFamily
                    font.pixelSize: BtUi.Theme.fs(12)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 420, 0)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.scanFailed
                    text: root.discovering || root.scanAdapter || !root.scanAttempted
                        ? BtUi.I18n.tr("Put your device in pairing mode to find it here.")
                        : BtUi.I18n.tr("Put your device in pairing mode, then scan again.")
                    color: BtUi.Theme.outlineStrong
                    font.family: BtUi.Theme.fontFamily
                    font.pixelSize: BtUi.Theme.fs(10)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(10), 420, 0)
                }

            }

        }

    }

    component BtDeviceRow: Column {
        id: devItem

        required property var modelData
        required property string group
        readonly property bool isExpanded: root.expandedKey === modelData.address
        readonly property bool isConnected: modelData.connected
        readonly property string iconKind: root.deviceIconKind(modelData.icon)
        readonly property bool isConnecting: modelData.state === BluetoothDeviceState.Connecting
        readonly property bool isPairing: modelData.pairing
        readonly property bool isPaired: modelData.paired
        property bool actionFailed: false
        property bool wasBusy: false
        property bool renaming: false
        property string renameText: ""

        width: parent.width

        Connections {
            function onStateChanged() {
                if (devItem.modelData.state === BluetoothDeviceState.Connecting) {
                    devItem.wasBusy = true;
                    devItem.actionFailed = false;
                } else if (devItem.wasBusy && devItem.group !== "nearby") {
                    devItem.actionFailed = !devItem.modelData.connected;
                    devItem.wasBusy = false;
                }
            }

            function onPairingChanged() {
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
            }

            target: devItem.modelData
        }

        Rectangle {
            width: parent.width
            height: BtUi.Theme.dp(50)
            radius: BtUi.Theme.rad(12)
            color: devItem.isConnected
                ? BtUi.Theme.alpha(BtUi.Theme.accent, devItem.isExpanded || rowArea.containsMouse ? 0.18 : 0.13)
                : (devItem.isExpanded || rowArea.containsMouse ? BtUi.Theme.alpha(BtUi.Theme.text, 0.08) : BtUi.Theme.alpha(BtUi.Theme.text, 0.045))

            Behavior on radius {
                NumberAnimation {
                    duration: BtUi.Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: BtUi.Theme.curveDefaultSpatial
                }

            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: BtUi.Theme.dp(10)
                anchors.rightMargin: BtUi.Theme.dp(14)
                spacing: BtUi.Theme.dp(12)

                Item {
                    width: BtUi.Theme.dp(36)
                    height: BtUi.Theme.dp(36)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: BtUi.Theme.dp(18)
                        color: BtUi.Theme.alpha(devItem.isConnected ? BtUi.Theme.accent : BtUi.Theme.text, 0.10)

                        Behavior on color {
                            ColorAnimation {
                                duration: BtUi.Theme.barMs(150)
                            }

                        }

                    }

                    Icon {
                        anchors.centerIn: parent
                        name: ({"headphones": "headphones", "phone": "smartphone", "laptop": "computer", "speaker": "speaker", "keyboard": "keyboard", "mouse": "mouse"})[devItem.iconKind] || "bluetooth"
                        size: BtUi.Theme.dp(20)
                        fill: devItem.isConnected ? 1 : 0
                        color: devItem.isConnected ? BtUi.Theme.accent : BtUi.Theme.text
                    }

                    Rectangle {
                        id: btDot

                        visible: devItem.isConnected
                        width: BtUi.Theme.dp(8)
                        height: BtUi.Theme.dp(8)
                        radius: BtUi.Theme.dp(4)
                        color: BtUi.Theme.success
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -BtUi.Theme.dp(2)

                    }

                }

                Column {
                    width: parent.width - BtUi.Theme.dp(36) - BtUi.Theme.dp(20) - BtUi.Theme.dp(24)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: root.deviceName(devItem.modelData)
                        color: BtUi.Theme.text
                        font.family: BtUi.Theme.fontFamily
                        font.bold: true
                        font.pixelSize: BtUi.Theme.fs(13)
                        font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(13), 560, 0)
                        elide: Text.ElideRight
                    }

                    Row {
                        width: parent.width
                        spacing: BtUi.Theme.dp(6)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (devItem.isPairing)
                                    return BtUi.I18n.tr("Pairing…");

                                if (devItem.isConnecting)
                                    return BtUi.I18n.tr("Connecting…");

                                if (devItem.isConnected) {
                                    let batt = root.getBatteryText(devItem.modelData);
                                    return BtUi.I18n.tr("Connected") + (batt !== "" ? " · " + batt : "");
                                }
                                if (devItem.isPaired)
                                    return devItem.modelData.trusted ? BtUi.I18n.tr("Paired · Trusted") : BtUi.I18n.tr("Paired");

                                return root.namedDevice(devItem.modelData) ? BtUi.I18n.tr("Available") : devItem.modelData.address;
                            }
                            color: devItem.isConnected ? BtUi.Theme.accent : BtUi.Theme.subtext
                            font.family: BtUi.Theme.fontFamily
                            font.pixelSize: BtUi.Theme.fs(10)
                            font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(10), 420, 0)
                        }

                        Rectangle {
                            visible: devItem.isConnected && devItem.modelData.batteryAvailable
                            width: BtUi.Theme.dp(22)
                            height: BtUi.Theme.dp(5)
                            radius: BtUi.Theme.dp(2)
                            color: BtUi.Theme.bgTrack
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                readonly property real pct: devItem.modelData.battery <= 1 ? devItem.modelData.battery : devItem.modelData.battery / 100

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(BtUi.Theme.dp(2), parent.width * Math.max(0, Math.min(1, pct)))
                                height: parent.height
                                radius: BtUi.Theme.dp(2)
                                color: pct < 0.2 ? BtUi.Theme.error : BtUi.Theme.success
                            }

                        }

                    }

                }

                Icon {
                    name: "expand_more"
                    size: BtUi.Theme.dp(20)
                    color: BtUi.Theme.subtext
                    anchors.verticalCenter: parent.verticalCenter
                    rotation: devItem.isExpanded ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: BtUi.Theme.barMs(200)
                            easing.type: Easing.OutCubic
                        }

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

            Behavior on color {
                ColorAnimation {
                    duration: BtUi.Theme.barMs(150)
                }

            }

        }

        Connectivity.ConnectivityDisclosure {
            id: expandArea

            width: parent.width
            panel: root
            expanded: devItem.isExpanded
            contentHeight: expandContent.implicitHeight

            Column {
                id: expandContent

                width: parent.width
                leftPadding: BtUi.Theme.dp(14)
                rightPadding: BtUi.Theme.dp(14)
                topPadding: BtUi.Theme.dp(6)
                bottomPadding: BtUi.Theme.dp(14)
                spacing: BtUi.Theme.dp(9)
                opacity: expandArea.reveal
                enabled: devItem.isExpanded

                Row {
                    width: parent.width - expandContent.leftPadding - expandContent.rightPadding
                    height: BtUi.Theme.dp(32)
                    spacing: BtUi.Theme.dp(8)

                    Rectangle {
                        id: primaryBtn

                        readonly property bool busy: devItem.isPairing || devItem.isConnecting

                        width: devItem.group === "nearby" ? parent.width : (parent.width - BtUi.Theme.dp(8)) / 2
                        height: parent.height
                        radius: BtUi.Theme.dp(999)
                        color: busy 
                            ? BtUi.Theme.withBlur(BtUi.Theme.outlineStrong) 
                            : (devItem.isConnected 
                                ? (primaryArea.containsMouse ? Qt.darker(BtUi.Theme.accent, 1.15) : BtUi.Theme.accent) 
                                : (primaryArea.containsMouse ? BtUi.Theme.accentHover : BtUi.Theme.accent))
                        opacity: busy ? 0.7 : 1
                        scale: primaryArea.pressed ? 0.96 : 1

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (devItem.isPairing)
                                    return BtUi.I18n.tr("Pairing…");

                                if (devItem.isConnecting)
                                    return BtUi.I18n.tr("Connecting…");

                                if (devItem.group === "nearby")
                                    return BtUi.I18n.tr("Pair");

                                return devItem.isConnected ? BtUi.I18n.tr("Disconnect") : BtUi.I18n.tr("Connect");
                            }
                            color: primaryBtn.busy ? BtUi.Theme.subtext : (BtUi.Theme.fgPrimary ?? "#000000")
                            font.family: BtUi.Theme.fontFamily
                            font.bold: true
                            font.pixelSize: BtUi.Theme.fs(12)
                            font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 640, 0)
                        }

                        MouseArea {
                            id: primaryArea

                            anchors.fill: parent
                            enabled: !primaryBtn.busy
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                devItem.actionFailed = false;
                                if (devItem.group === "nearby")
                                    BtUi.Bt.pair(devItem.modelData);
                                else if (devItem.isConnected)
                                    devItem.modelData.disconnect();
                                else
                                    devItem.modelData.connect();
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: BtUi.Theme.barMs(120)
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: BtUi.Theme.barMs(90)
                                easing.type: Easing.OutQuad
                            }

                        }

                    }

                    Rectangle {
                        id: forgetBtn

                        visible: devItem.group !== "nearby"
                        width: (parent.width - BtUi.Theme.dp(8)) / 2
                        height: parent.height
                        radius: BtUi.Theme.dp(999)
                        color: forgetArea.containsMouse ? BtUi.Theme.alpha(BtUi.Theme.error, 0.20) : BtUi.Theme.alpha(BtUi.Theme.text, 0.08)
                        scale: forgetArea.pressed ? 0.96 : 1

                        Text {
                            anchors.centerIn: parent
                            text: BtUi.I18n.tr("Forget")
                            color: BtUi.Theme.text
                            font.family: BtUi.Theme.fontFamily
                            font.bold: true
                            font.pixelSize: BtUi.Theme.fs(12)
                            font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 640, 0)
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

                        Behavior on color {
                            ColorAnimation {
                                duration: BtUi.Theme.barMs(120)
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: BtUi.Theme.barMs(90)
                                easing.type: Easing.OutQuad
                            }

                        }

                    }

                }

                Text {
                    visible: devItem.isPairing
                    text: BtUi.I18n.tr("Cancel pairing")
                    color: BtUi.Theme.subtext
                    font.family: BtUi.Theme.fontFamily
                    font.pixelSize: BtUi.Theme.fs(11)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(11), 420, 0)
                    font.underline: cancelPairArea.containsMouse

                    MouseArea {
                        id: cancelPairArea

                        anchors.fill: parent
                        anchors.margins: -BtUi.Theme.dp(4)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: devItem.modelData.cancelPair()
                    }

                }

                Text {
                    visible: devItem.actionFailed && !devItem.isConnected && !devItem.isPairing && !devItem.isConnecting
                    width: parent.width - expandContent.leftPadding - expandContent.rightPadding
                    text: devItem.group === "nearby" ? BtUi.I18n.tr("Pairing failed. Please try again.") : BtUi.I18n.tr("Failed to connect. The device may be out of range.")
                    color: BtUi.Theme.error
                    font.family: BtUi.Theme.fontFamily
                    font.pixelSize: BtUi.Theme.fs(10)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(10), 420, 0)
                    wrapMode: Text.WordWrap
                }

                Flow {
                    width: parent.width - expandContent.leftPadding - expandContent.rightPadding
                    visible: devItem.group !== "nearby"
                    spacing: BtUi.Theme.dp(12)

                    Row {
                        spacing: BtUi.Theme.dp(8)

                        Rectangle {
                            width: BtUi.Theme.dp(16)
                            height: BtUi.Theme.dp(16)
                            radius: BtUi.Theme.dp(4)
                            anchors.verticalCenter: parent.verticalCenter
                            color: devItem.modelData.trusted ? BtUi.Theme.accent : BtUi.Theme.alpha(BtUi.Theme.text, 0.14)

                            Icon {
                                anchors.centerIn: parent
                                visible: devItem.modelData.trusted
                                name: "check"
                                size: BtUi.Theme.dp(12)
                                color: BtUi.Theme.on_primary ?? "#000000"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.trusted = !devItem.modelData.trusted
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: BtUi.Theme.barMs(120)
                                }

                            }

                        }

                        Text {
                            text: BtUi.I18n.tr("Auto-reconnect")
                            color: BtUi.Theme.subtext
                            font.family: BtUi.Theme.fontFamily
                            font.bold: true
                            font.pixelSize: BtUi.Theme.fs(11)
                            font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(11), 640, 0)
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.trusted = !devItem.modelData.trusted
                            }

                        }

                    }

                    Row {
                        visible: devItem.isConnected
                        spacing: BtUi.Theme.dp(8)

                        Rectangle {
                            width: BtUi.Theme.dp(16)
                            height: BtUi.Theme.dp(16)
                            radius: BtUi.Theme.dp(4)
                            anchors.verticalCenter: parent.verticalCenter
                            color: devItem.modelData.wakeAllowed ? BtUi.Theme.accent : BtUi.Theme.alpha(BtUi.Theme.text, 0.14)

                            Icon {
                                anchors.centerIn: parent
                                visible: devItem.modelData.wakeAllowed
                                name: "check"
                                size: BtUi.Theme.dp(12)
                                color: BtUi.Theme.on_primary ?? "#000000"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.wakeAllowed = !devItem.modelData.wakeAllowed
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: BtUi.Theme.barMs(120)
                                }

                            }

                        }

                        Text {
                            text: BtUi.I18n.tr("Allow wake")
                            color: BtUi.Theme.subtext
                            font.family: BtUi.Theme.fontFamily
                            font.bold: true
                            font.pixelSize: BtUi.Theme.fs(11)
                            font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(11), 640, 0)
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.wakeAllowed = !devItem.modelData.wakeAllowed
                            }

                        }

                    }

                    Row {
                        spacing: BtUi.Theme.dp(8)

                        Rectangle {
                            width: BtUi.Theme.dp(16)
                            height: BtUi.Theme.dp(16)
                            radius: BtUi.Theme.dp(4)
                            anchors.verticalCenter: parent.verticalCenter
                            color: devItem.modelData.blocked ? BtUi.Theme.error : BtUi.Theme.alpha(BtUi.Theme.text, 0.14)

                            Icon {
                                anchors.centerIn: parent
                                visible: devItem.modelData.blocked
                                name: "check"
                                size: BtUi.Theme.dp(12)
                                color: BtUi.Theme.fgError ?? "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.blocked = !devItem.modelData.blocked
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: BtUi.Theme.barMs(120)
                                }

                            }

                        }

                        Text {
                            text: BtUi.I18n.tr("Block")
                            color: BtUi.Theme.subtext
                            font.family: BtUi.Theme.fontFamily
                            font.bold: true
                            font.pixelSize: BtUi.Theme.fs(11)
                            font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(11), 640, 0)
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devItem.modelData.blocked = !devItem.modelData.blocked
                            }

                        }

                    }

                }

                Row {
                    visible: devItem.group !== "nearby" && !devItem.renaming
                    spacing: BtUi.Theme.dp(16)

                    // object push needs no open link: a paired phone that is not
                    // connected takes files just the same
                    Text {
                        visible: BtUi.Bt.canReceiveFiles(devItem.modelData.address)
                        text: BtUi.I18n.tr("Send files")
                        color: BtUi.Theme.subtext
                        font.family: BtUi.Theme.fontFamily
                        font.pixelSize: BtUi.Theme.fs(11)
                        font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(11), 420, 0)
                        font.underline: sendArea.containsMouse

                        MouseArea {
                            id: sendArea

                            anchors.fill: parent
                            anchors.margins: -BtUi.Theme.dp(4)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // the file chooser opens next, and the panel would sit over it
                                root.closeRequested();
                                BtUi.Bt.sendFiles(devItem.modelData.address, devItem.modelData.name, []);
                            }
                        }

                    }

                    Text {
                        text: BtUi.I18n.tr("Rename")
                        color: BtUi.Theme.subtext
                        font.family: BtUi.Theme.fontFamily
                        font.pixelSize: BtUi.Theme.fs(11)
                        font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(11), 420, 0)
                        font.underline: renameArea.containsMouse

                        MouseArea {
                            id: renameArea

                            anchors.fill: parent
                            anchors.margins: -BtUi.Theme.dp(4)
                            cursorShape: Qt.PointingHandCursor
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
                    width: parent.width - expandContent.leftPadding - expandContent.rightPadding
                    height: BtUi.Theme.dp(30)
                    radius: BtUi.Theme.rad(8)
                    color: renameInput.activeFocus ? BtUi.Theme.alpha(BtUi.Theme.text, 0.10) : BtUi.Theme.alpha(BtUi.Theme.text, 0.055)
                    Behavior on color {
                        ColorAnimation {
                            duration: BtUi.Theme.barMs(120)
                        }
                    }

                    Connections {
                        function onRenamingChanged() {
                            if (devItem.renaming)
                                renameInput.forceActiveFocus();

                        }

                        target: devItem
                    }

                    TextInput {
                        id: renameInput

                        anchors.fill: parent
                        anchors.leftMargin: BtUi.Theme.dp(10)
                        anchors.rightMargin: BtUi.Theme.dp(10)
                        verticalAlignment: Text.AlignVCenter
                        color: BtUi.Theme.text
                        font.family: BtUi.Theme.fontFamily
                        font.pixelSize: BtUi.Theme.fs(12)
                        font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 420, 0)
                        selectByMouse: true
                        text: devItem.renameText
                        Keys.onReturnPressed: {
                            if (text.trim().length > 0)
                                devItem.modelData.name = text.trim();

                            devItem.renaming = false;
                        }
                        Keys.onEscapePressed: devItem.renaming = false
                    }
                }

            }
        }

    }


}
