import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../"

Item {
    id: batteryModule
    anchors.fill: parent
    focus: true

    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    // ========================================================
    // 1. DESIGN TOKENS & COLORS
    // ========================================================
    readonly property color accentColor: Theme.accent
    readonly property color cardBg: Qt.rgba(255, 255, 255, 0.045)
    readonly property color cardHoverBg: Qt.rgba(255, 255, 255, 0.08)
    readonly property color textPrimary: Theme.colors.text_primary ?? "#f8fafc"
    readonly property color textSecondary: Theme.colors.text_secondary ?? "#94a3b8"
    readonly property color textMuted: Theme.colors.text_muted ?? "#64748b"
    readonly property color chargingColor: "#30d158"
    readonly property color warningColor: "#ffd60a"
    readonly property color errorColor: "#ff453a"

    // ========================================================
    // 2. REACTIVE HARDWARE STATE (UPower DBus)
    // ========================================================
    readonly property var upowerDev: typeof UPower !== "undefined" ? UPower.displayDevice : null

    property int rawBatteryLevel: 98
    property bool rawIsCharging: false
    property bool rawIsFull: false

    property int batteryLevel: (upowerDev && upowerDev.percentage !== undefined && upowerDev.percentage > 0)
        ? Math.round(upowerDev.percentage * 100)
        : rawBatteryLevel

    property bool isCharging: (upowerDev && upowerDev.state !== undefined)
        ? (upowerDev.state === UPowerDevice.Charging)
        : rawIsCharging

    property bool isFull: (upowerDev && upowerDev.state !== undefined)
        ? (upowerDev.state === UPowerDevice.FullyCharged || (batteryLevel >= 96 && upowerDev.state !== UPowerDevice.Discharging))
        : rawIsFull

    readonly property bool isWarningLevel: batteryLevel <= 25 && batteryLevel > 15 && !isCharging
    readonly property bool isLowLevel: batteryLevel <= 15 && !isCharging

    readonly property color statusColor: {
        if (isCharging) return chargingColor;
        if (isLowLevel) return errorColor;
        if (isWarningLevel) return warningColor;
        return accentColor;
    }

    // Hardware Telemetry
    property real currentPowerW: 0.0
    property real voltageV: 12.0
    property real currentEnergyWh: 37.7
    property real fullEnergyWh: 38.9
    property int healthPercentage: 87
    property string timeRemainingStr: "Calculating..."
    property int chargeThreshold: 100
    property int refreshRate: 144
    property int kbdBacklight: 0
    property string activeProfile: "balanced"

    // ========================================================
    // 3. BACKEND PROCESSES & ON-DEMAND POLLING
    // ========================================================
    readonly property string scriptPath: (Quickshell.shellDir || Quickshell.configDir) + "/scripts/battery_telemetry.py"

    Process {
        id: telemetryPoller
        running: false
        command: ["python3", batteryModule.scriptPath, "telemetry"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var data = JSON.parse(this.text.trim());
                    if (typeof root !== "undefined") root.cachedBatteryTelemetry = data;
                    batteryModule.applyTelemetry(data);
                } catch (e) {
                    console.warn("[BatteryModule] Telemetry parse error:", e);
                }
            }
        }
    }

    Process {
        id: profileChecker
        running: false
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null || echo 'balanced'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim();
                if (p !== "") batteryModule.activeProfile = p;
            }
        }
    }

    Process {
        id: actionRunner
        running: false
        onExited: {
            telemetryPoller.running = true;
        }
    }

    function runTelemetryAction(cmdArgs) {
        actionRunner.command = ["python3", batteryModule.scriptPath].concat(cmdArgs);
        actionRunner.running = true;
    }

    function toggleRefreshRate() {
        batteryModule.refreshRate = (batteryModule.refreshRate <= 60) ? 144 : 60;
        runTelemetryAction(["toggle_hz"]);
    }

    function toggleKbdBacklight() {
        batteryModule.kbdBacklight = (batteryModule.kbdBacklight === 0) ? 2 : 0;
        runTelemetryAction(["toggle_kbd"]);
    }

    function toggleChargeThreshold() {
        var next = (batteryModule.chargeThreshold === 80) ? 100 : 80;
        batteryModule.chargeThreshold = next;
        runTelemetryAction(["set_threshold", next.toString()]);
    }

    function setPowerProfile(profileName) {
        batteryModule.activeProfile = profileName;
        Quickshell.execDetached(["powerprofilesctl", "set", profileName]);
    }

    function applyTelemetry(data) {
        if (!data) return;
        if (data.percentage !== undefined) batteryModule.rawBatteryLevel = data.percentage;
        if (data.isCharging !== undefined) batteryModule.rawIsCharging = !!data.isCharging;
        if (data.isFull !== undefined) batteryModule.rawIsFull = !!data.isFull;
        if (data.powerW !== undefined) batteryModule.currentPowerW = data.powerW;
        if (data.voltageV !== undefined) batteryModule.voltageV = data.voltageV;
        if (data.health !== undefined) batteryModule.healthPercentage = Math.min(100, Math.max(0, data.health));
        if (data.currentEnergyWh !== undefined) batteryModule.currentEnergyWh = data.currentEnergyWh;
        if (data.fullEnergyWh !== undefined) batteryModule.fullEnergyWh = data.fullEnergyWh;
        if (data.timeStr !== undefined) batteryModule.timeRemainingStr = data.timeStr;
        if (data.chargeThreshold !== undefined) batteryModule.chargeThreshold = data.chargeThreshold;
        if (data.refreshRate !== undefined) batteryModule.refreshRate = data.refreshRate;
        if (data.kbdBacklight !== undefined) batteryModule.kbdBacklight = data.kbdBacklight;
    }

    function pollAll() {
        if (!telemetryPoller.running) telemetryPoller.running = true;
        if (!profileChecker.running) profileChecker.running = true;
    }

    // Polling timer: throttled to 3s when open, zero CPU overhead when closed
    Timer {
        interval: 3000
        running: root.activeMode === "battery"
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryModule.pollAll()
    }

    Component.onCompleted: {
        if (typeof root !== "undefined" && root.cachedBatteryTelemetry) {
            batteryModule.applyTelemetry(root.cachedBatteryTelemetry);
        }
        batteryModule.pollAll();
    }

    // ========================================================
    // 4. MAIN LAYOUT (Matushell Expressive Visual Language)
    // ========================================================
    ColumnLayout {
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        // ── TOP HEADER ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8

            // Back button (navigates back to Control Center)
            IrisIconButton {
                buttonSize: 28
                buttonRadius: 8
                flat: true
                icon: "arrow_back"
                iconSize: 16
                iconColor: batteryModule.textPrimary
                onClicked: root.switchMode("utility", true)
            }

            Text {
                text: "Power & Battery"
                font.family: "Readex Pro"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: batteryModule.textPrimary
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            // Status chip badge
            Rectangle {
                height: 22
                width: statusBadgeText.implicitWidth + 14
                radius: 11
                color: Qt.alpha(batteryModule.statusColor, 0.15)
                Layout.alignment: Qt.AlignVCenter

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        text: batteryModule.isCharging ? "bolt" : (batteryModule.isFull ? "power" : "battery_std")
                        iconSize: 12
                        fill: 1
                        color: batteryModule.statusColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: statusBadgeText
                        text: batteryModule.isCharging ? "Charging" : (batteryModule.isFull ? "AC Power" : "Discharging")
                        font.family: "Readex Pro"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: batteryModule.statusColor
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Refresh action
            IrisIconButton {
                id: refreshBtn
                buttonSize: 28
                buttonRadius: 8
                flat: true
                icon: "refresh"
                iconSize: 15
                iconColor: batteryModule.textSecondary
                onClicked: batteryModule.pollAll()
            }
        }

        // ── 1. HERO BATTERY CARD (Matushell Duotone Device Card) ──
        Rectangle {
            id: heroCard
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            radius: 14
            color: batteryModule.cardBg

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Big percentage & state caption
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8

                            Text {
                                text: batteryModule.batteryLevel + "%"
                                font.family: "Readex Pro"
                                font.pixelSize: 28
                                font.weight: Font.Bold
                                font.features: ({ "tnum": 1 })
                                color: batteryModule.textPrimary
                                renderType: Text.NativeRendering
                            }

                            // Subtitle pill
                            Rectangle {
                                height: 18
                                width: heroSubText.implicitWidth + 10
                                radius: 9
                                color: Qt.alpha(batteryModule.statusColor, 0.14)
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    id: heroSubText
                                    anchors.centerIn: parent
                                    text: batteryModule.isCharging ? "Fast Charge" : (batteryModule.isFull ? "Fully Charged" : "On Battery")
                                    font.family: "Readex Pro"
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: batteryModule.statusColor
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        // Time remaining / state string
                        Text {
                            text: {
                                if (batteryModule.isFull) return "Battery is charged · Running on AC adapter";
                                if (batteryModule.timeRemainingStr && batteryModule.timeRemainingStr !== "Calculating...") {
                                    return batteryModule.timeRemainingStr;
                                }
                                return batteryModule.isCharging ? "Charging..." : "Calculating discharge time...";
                            }
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            color: batteryModule.textSecondary
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Circular glyph disc on the right with glowing state
                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        color: Qt.alpha(batteryModule.statusColor, 0.16)
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: batteryModule.isCharging ? "bolt" : (batteryModule.isFull ? "battery_full" : (batteryModule.isLowLevel ? "battery_alert" : "battery_android_full"))
                            iconSize: 24
                            fill: 1
                            color: batteryModule.statusColor
                        }

                        // Subtle breathing pulse animation when charging
                        SequentialAnimation on opacity {
                            running: batteryModule.isCharging
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.65; duration: 1100; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                // Smooth inset liquid progress track
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.rgba(255, 255, 255, 0.08)
                    clip: true

                    Rectangle {
                        height: parent.height
                        radius: 3
                        color: batteryModule.statusColor
                        width: parent.width * (Math.min(100, Math.max(0, batteryModule.batteryLevel)) / 100.0)

                        Behavior on width {
                            NumberAnimation {
                                duration: 320
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveFastSpatial
                            }
                        }
                    }
                }
            }
        }

        // ── 2. BATTERY HEALTH PILL (Matushell HealthFillCard) ─────
        Rectangle {
            id: healthPill
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 16
            color: batteryModule.cardBg
            clip: true

            // Growing primary fill matching health percentage
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * (Math.min(100, Math.max(0, batteryModule.healthPercentage)) / 100.0)
                radius: 16
                color: Qt.alpha(batteryModule.statusColor, 0.16)

                Behavior on width {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                MaterialSymbol {
                    text: "favorite"
                    iconSize: 14
                    fill: 1
                    color: batteryModule.statusColor
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: `Battery Health: ${batteryModule.healthPercentage}% · ${batteryModule.healthPercentage >= 80 ? "Good Condition" : "Service Recommended"}`
                    font.family: "Readex Pro"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: batteryModule.textPrimary
                    renderType: Text.NativeRendering
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: batteryModule.fullEnergyWh > 0 ? `${batteryModule.fullEnergyWh.toFixed(1)} Wh` : ""
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: batteryModule.textSecondary
                    renderType: Text.NativeRendering
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // ── 3. POWER PROFILES SELECTOR (MatusConnectedButton Strip) 
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            radius: 12
            color: batteryModule.cardBg

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 4

                readonly property var profileList: [
                    { id: "power-saver", label: "Power Saver", icon: "energy_savings_leaf" },
                    { id: "balanced",    label: "Balanced",    icon: "airwave" },
                    { id: "performance", label: "Performance", icon: "rocket_launch" }
                ]

                Repeater {
                    model: parent.profileList

                    Rectangle {
                        id: segBtn
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 11

                        readonly property bool isSelected: batteryModule.activeProfile === modelData.id
                        color: isSelected ? batteryModule.accentColor : (segMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent")
                        scale: segMouse.pressed ? 0.96 : 1.0

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }

                        MouseArea {
                            id: segMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: batteryModule.setPowerProfile(modelData.id)
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 14
                                fill: segBtn.isSelected ? 1 : 0
                                color: segBtn.isSelected ? "#000000" : batteryModule.textSecondary
                                Layout.alignment: Qt.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                text: modelData.label
                                font.family: "Readex Pro"
                                font.pixelSize: 11
                                font.weight: segBtn.isSelected ? Font.Bold : Font.Medium
                                color: segBtn.isSelected ? "#000000" : batteryModule.textPrimary
                                Layout.alignment: Qt.AlignVCenter
                                renderType: Text.NativeRendering
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }
                }
            }
        }

        // ── 4. QUICK STADIUM TILES (2x2 Grid) ────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 6

            // Tile 1: Battery Care (Asus 80% charge threshold limit)
            Rectangle {
                id: careTile
                Layout.fillWidth: true
                Layout.preferredHeight: 41
                radius: 12
                color: careMouse.containsMouse ? batteryModule.cardHoverBg : batteryModule.cardBg
                scale: careMouse.pressed ? 0.96 : (careMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
                Behavior on color { ColorAnimation { duration: 150 } }

                readonly property bool isActive: batteryModule.chargeThreshold === 80

                MouseArea {
                    id: careMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batteryModule.toggleChargeThreshold()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: careTile.isActive ? batteryModule.accentColor : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "battery_saver"
                            iconSize: 14
                            fill: careTile.isActive ? 1 : 0
                            color: careTile.isActive ? "#000000" : batteryModule.textSecondary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Battery Care"
                            font.family: "Readex Pro"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: batteryModule.textPrimary
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: careTile.isActive ? "80% Limit (Healthy)" : "100% Full Capacity"
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            color: careTile.isActive ? batteryModule.accentColor : batteryModule.textSecondary
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            // Tile 2: Display Eco Mode (60 Hz / 144 Hz)
            Rectangle {
                id: ecoTile
                Layout.fillWidth: true
                Layout.preferredHeight: 41
                radius: 12
                color: ecoMouse.containsMouse ? batteryModule.cardHoverBg : batteryModule.cardBg
                scale: ecoMouse.pressed ? 0.96 : (ecoMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
                Behavior on color { ColorAnimation { duration: 150 } }

                readonly property bool isActive: batteryModule.refreshRate <= 60

                MouseArea {
                    id: ecoMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batteryModule.toggleRefreshRate()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: ecoTile.isActive ? batteryModule.accentColor : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "speed"
                            iconSize: 14
                            fill: ecoTile.isActive ? 1 : 0
                            color: ecoTile.isActive ? "#000000" : batteryModule.textSecondary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Display Eco"
                            font.family: "Readex Pro"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: batteryModule.textPrimary
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: ecoTile.isActive ? "60 Hz Active (~2W saved)" : "144 Hz Smooth"
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            color: ecoTile.isActive ? batteryModule.accentColor : batteryModule.textSecondary
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            // Tile 3: Keyboard Backlight
            Rectangle {
                id: kbdTile
                Layout.fillWidth: true
                Layout.preferredHeight: 41
                radius: 12
                color: kbdMouse.containsMouse ? batteryModule.cardHoverBg : batteryModule.cardBg
                scale: kbdMouse.pressed ? 0.96 : (kbdMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
                Behavior on color { ColorAnimation { duration: 150 } }

                readonly property bool isActive: batteryModule.kbdBacklight > 0

                MouseArea {
                    id: kbdMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batteryModule.toggleKbdBacklight()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: kbdTile.isActive ? batteryModule.accentColor : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "keyboard"
                            iconSize: 14
                            fill: kbdTile.isActive ? 1 : 0
                            color: kbdTile.isActive ? "#000000" : batteryModule.textSecondary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Kbd Backlight"
                            font.family: "Readex Pro"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: batteryModule.textPrimary
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: kbdTile.isActive ? "Illumination Active" : "Off (Power Saver)"
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            color: kbdTile.isActive ? batteryModule.accentColor : batteryModule.textSecondary
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            // Tile 4: Live Power Telemetry
            Rectangle {
                id: pwrTile
                Layout.fillWidth: true
                Layout.preferredHeight: 41
                radius: 12
                color: pwrMouse.containsMouse ? batteryModule.cardHoverBg : batteryModule.cardBg
                scale: pwrMouse.pressed ? 0.96 : (pwrMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
                Behavior on color { ColorAnimation { duration: 150 } }

                MouseArea {
                    id: pwrMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batteryModule.pollAll()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: batteryModule.isCharging ? Qt.alpha(batteryModule.chargingColor, 0.20) : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "bolt"
                            iconSize: 15
                            fill: 1
                            color: batteryModule.isCharging ? batteryModule.chargingColor : batteryModule.statusColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Power Draw"
                            font.family: "Readex Pro"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: batteryModule.textPrimary
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: (batteryModule.currentPowerW > 0 ? `${batteryModule.currentPowerW.toFixed(1)} W` : "0.0 W") + ` • ${batteryModule.voltageV.toFixed(1)}V`
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            color: batteryModule.statusColor
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }
}
