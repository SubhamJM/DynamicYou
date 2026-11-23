import QtQuick
import QtQuick.Shapes
import Quickshell.Bluetooth
import "." as BtUi

Item {
    id: root

    Component.onDestruction: {
        if (root.adapter && root.ownScan)
            root.adapter.discovering = false;
    }


    property bool active: false
    property string expandedKey: ""

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
    // only a scan this panel started is ours to stop; bluez refuses the rest
    property bool ownScan: false

    onDiscoveringChanged: {
        if (!root.discovering)
            root.ownScan = false;

    }

    readonly property string label: {
        if (!root.btEnabled)
            return BtUi.I18n.tr("Off");

        if (root.connectedDevices.length === 1) {
            let d = root.connectedDevices[0];
            let batt = root.getBatteryText(d);
            return d.name + (batt !== "" ? " (" + batt + ")" : "");
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

        const named = root.adapter.devices.values.filter((d) => {
            return d.name && d.name.length > 0 && !root.isMacLike(d.name);
        });
        const byName = (arr) => {
            return arr.slice().sort((a, b) => {
                return a.name.localeCompare(b.name);
            });
        };
        return {
            "connected": byName(named.filter((d) => {
                return d.connected;
            })),
            "paired": byName(named.filter((d) => {
                return !d.connected && d.paired;
            })),
            "nearby": byName(named.filter((d) => {
                return !d.connected && !d.paired;
            }))
        };
    }


    implicitHeight: col.implicitHeight

    onActiveChanged: {
        if (!root.active) {
            root.expandedKey = "";
            if (root.adapter && root.ownScan)
                root.adapter.discovering = false;
        } else {
            BtUi.Bt.probePush();
        }
    }

    Column {
        id: col

        width: root.width
        spacing: BtUi.Theme.dp(10)

        Item {
            id: scanButton

            property int dotCount: 0

            visible: root.btEnabled
            width: parent.width
            height: BtUi.Theme.dp(44)

            Timer {
                interval: 400
                running: root.discovering
                repeat: true
                onTriggered: scanButton.dotCount = (scanButton.dotCount + 1) % 4
            }

            Timer {
                interval: 20000
                running: root.discovering && root.ownScan
                onTriggered: {
                    if (root.adapter)
                        root.adapter.discovering = false;

                }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.discovering ? BtUi.Theme.withBlur(BtUi.Theme.secondaryContainer) : BtUi.Theme.withBlur(BtUi.Theme.surfaceHigh)

                Behavior on color {
                    ColorAnimation {
                        duration: BtUi.Theme.durDefaultEffects
                    }

                }

                StateLayer {
                    radius: parent.radius
                    tint: root.discovering ? BtUi.Theme.fgSecondaryContainer : BtUi.Theme.text
                    onClicked: {
                        if (!root.adapter)
                            return ;

                        root.ownScan = !root.discovering;
                        root.adapter.discovering = !root.discovering;
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: BtUi.Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: BtUi.Theme.dp(10)

                    Item {
                        width: BtUi.Theme.dp(24)
                        height: BtUi.Theme.dp(24)
                        anchors.verticalCenter: parent.verticalCenter

                        LoadingIndicator {
                            anchors.fill: parent
                            visible: root.discovering
                            color: BtUi.Theme.fgSecondaryContainer
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !root.discovering
                            name: "bluetooth_searching"
                            size: BtUi.Theme.dp(20)
                            color: BtUi.Theme.subtext
                        }

                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        text: root.discovering ? BtUi.I18n.tr("Looking for devices") : BtUi.I18n.tr("Search for devices")
                        color: root.discovering ? BtUi.Theme.fgSecondaryContainer : BtUi.Theme.text
                    }

                }

                LText {
                    anchors.right: parent.right
                    anchors.rightMargin: BtUi.Theme.dp(16)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.discovering
                    role: "labelMedium"
                    text: BtUi.I18n.tr("Stop")
                    color: BtUi.Theme.fgSecondaryContainer
                }

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

            Switch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: !!(root.adapter && root.adapter.discoverable)
                onToggled: {
                    if (root.adapter)
                        root.adapter.discoverable = !root.adapter.discoverable;

                }
            }

        }

        Column {
            visible: !root.btEnabled
            width: parent.width
            topPadding: BtUi.Theme.dp(20)
            spacing: BtUi.Theme.dp(4)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: BtUi.I18n.tr("Bluetooth is off")
                color: BtUi.Theme.subtext
                font.family: BtUi.Theme.fontFamily
                font.pixelSize: BtUi.Theme.fs(12)
                font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 420, 0)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: BtUi.I18n.tr("Turn it on to see nearby devices")
                color: BtUi.Theme.outlineStrong
                font.family: BtUi.Theme.fontFamily
                font.pixelSize: BtUi.Theme.fs(10)
                font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(10), 420, 0)
            }

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
                    color: BtUi.Theme.primary
                    font.family: BtUi.Theme.fontFamily
                    font.bold: true
                    font.pixelSize: BtUi.Theme.fs(12)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 600, 0)
                    leftPadding: BtUi.Theme.dp(4)
                    bottomPadding: BtUi.Theme.dp(3)
                }

                Repeater {
                    model: root.connectedDevices

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
                    color: BtUi.Theme.primary
                    font.family: BtUi.Theme.fontFamily
                    font.bold: true
                    font.pixelSize: BtUi.Theme.fs(12)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 600, 0)
                    leftPadding: BtUi.Theme.dp(4)
                    bottomPadding: BtUi.Theme.dp(3)
                }

                Repeater {
                    model: root.pairedDevices

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
                    color: BtUi.Theme.primary
                    font.family: BtUi.Theme.fontFamily
                    font.bold: true
                    font.pixelSize: BtUi.Theme.fs(12)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 600, 0)
                    leftPadding: BtUi.Theme.dp(4)
                    bottomPadding: BtUi.Theme.dp(3)
                }

                Repeater {
                    model: root.nearbyDevices

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
                    text: root.discovering ? BtUi.I18n.tr("Looking for devices…") : BtUi.I18n.tr("No devices found")
                    color: BtUi.Theme.subtext
                    font.family: BtUi.Theme.fontFamily
                    font.pixelSize: BtUi.Theme.fs(12)
                    font.variableAxes: BtUi.Theme.axes(BtUi.Theme.fs(12), 420, 0)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.discovering
                    text: BtUi.I18n.tr("Tap “Search for devices” to scan")
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
            height: BtUi.Theme.dp(56)
            radius: devItem.isExpanded ? BtUi.Theme.rad(20) : BtUi.Theme.rad(14)
            color: devItem.isExpanded ? BtUi.Theme.withBlur(BtUi.Theme.surfaceHighest) : (rowArea.containsMouse ? BtUi.Theme.withBlur(BtUi.Theme.layer(BtUi.Theme.surfaceHigh, BtUi.Theme.text, BtUi.Theme.stateHover)) : BtUi.Theme.withBlur(BtUi.Theme.surfaceHigh))

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
                        color: devItem.isConnected ? BtUi.Theme.primary : BtUi.Theme.alpha(BtUi.Theme.text, 0.08)

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
                        color: devItem.isConnected ? BtUi.Theme.fgPrimary : BtUi.Theme.text
                    }

                    Rectangle {
                        id: btDot

                        visible: devItem.isConnected
                        width: BtUi.Theme.dp(8)
                        height: BtUi.Theme.dp(8)
                        radius: BtUi.Theme.dp(4)
                        color: BtUi.Theme.success
                        border.width: 2
                        border.color: BtUi.Theme.surfaceHigh
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -BtUi.Theme.dp(2)

                        // visible is the effective one, so a closed panel stops the pulse
                        // instead of driving a repaint every frame for nobody
                        SequentialAnimation on opacity {
                            running: btDot.visible
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.35
                                duration: BtUi.Theme.barMs(700)
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                to: 1
                                duration: BtUi.Theme.barMs(700)
                                easing.type: Easing.InOutQuad
                            }

                        }

                    }

                }

                Column {
                    width: parent.width - BtUi.Theme.dp(36) - BtUi.Theme.dp(20) - BtUi.Theme.dp(24)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: devItem.modelData.name
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

                                return BtUi.I18n.tr("Available");
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

        Item {
            id: expandArea

            width: parent.width
            height: devItem.isExpanded ? expandContent.implicitHeight : 0
            clip: true

            Column {
                id: expandContent

                width: parent.width
                leftPadding: BtUi.Theme.dp(14)
                rightPadding: BtUi.Theme.dp(14)
                topPadding: BtUi.Theme.dp(6)
                bottomPadding: BtUi.Theme.dp(14)
                spacing: BtUi.Theme.dp(9)
                y: devItem.isExpanded ? 0 : -BtUi.Theme.dp(8)
                opacity: devItem.isExpanded ? 1 : 0

                Behavior on y {
                    NumberAnimation {
                        duration: BtUi.Theme.barMs(220)
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: BtUi.Theme.barMs(180)
                    }
                }

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
                        color: forgetArea.containsMouse ? BtUi.Theme.withBlur(BtUi.Theme.outlineStrong) : "transparent"
                        border.width: 1
                        border.color: BtUi.Theme.outlineStrong
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
                            width: BtUi.Theme.dp(15)
                            height: BtUi.Theme.dp(15)
                            radius: BtUi.Theme.dp(4)
                            anchors.verticalCenter: parent.verticalCenter
                            color: devItem.modelData.trusted ? BtUi.Theme.accent : "transparent"
                            border.width: 1.5
                            border.color: devItem.modelData.trusted ? BtUi.Theme.accent : BtUi.Theme.outlineStrong

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
                            width: BtUi.Theme.dp(15)
                            height: BtUi.Theme.dp(15)
                            radius: BtUi.Theme.dp(4)
                            anchors.verticalCenter: parent.verticalCenter
                            color: devItem.modelData.wakeAllowed ? BtUi.Theme.accent : "transparent"
                            border.width: 1.5
                            border.color: devItem.modelData.wakeAllowed ? BtUi.Theme.accent : BtUi.Theme.outlineStrong

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
                            width: BtUi.Theme.dp(15)
                            height: BtUi.Theme.dp(15)
                            radius: BtUi.Theme.dp(4)
                            anchors.verticalCenter: parent.verticalCenter
                            color: devItem.modelData.blocked ? BtUi.Theme.withBlur(BtUi.Theme.error) : "transparent"
                            border.width: 1.5
                            border.color: devItem.modelData.blocked ? BtUi.Theme.error : BtUi.Theme.outlineStrong

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
                    color: BtUi.Theme.withBlur(BtUi.Theme.bgSunken)
                    border.width: 1
                    border.color: renameInput.activeFocus ? BtUi.Theme.accent : BtUi.Theme.bgHigh

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

                    Behavior on border.color {
                        ColorAnimation {
                            duration: BtUi.Theme.barMs(150)
                        }

                    }

                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: BtUi.Theme.barMs(240)
                    easing.type: Easing.OutCubic
                }

            }

        }

    }


}
