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
    // 1. DESIGN TOKENS & TYPOGRAPHY
    // ========================================================
    readonly property string fontDisplay: "Inter"
    readonly property string fontBody: "Inter"

    readonly property color accentColor: Theme.accent ?? "#38bdf8"
    readonly property color cardBg: Qt.rgba(255, 255, 255, 0.04)
    readonly property color cardHoverBg: Qt.rgba(255, 255, 255, 0.075)
    readonly property color cardBorder: Qt.rgba(255, 255, 255, 0.055)
    readonly property color textPrimary: Theme.colors.text_primary ?? "#f8fafc"
    readonly property color textSecondary: Qt.rgba(255, 255, 255, 0.60)
    readonly property color textMuted: Qt.rgba(255, 255, 255, 0.38)
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
    readonly property string scriptPath: NotchConfig.scriptsDir + "/battery_telemetry.py"

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
    // 4. MAIN LAYOUT (Consistent, Refined, Unified)
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 7

        // ── TOP HEADER ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 8

            // Back button (navigates back to Control Center)
            IrisIconButton {
                buttonSize: 30
                buttonRadius: 9
                flat: true
                icon: "arrow_back"
                iconSize: 16
                iconColor: batteryModule.textPrimary
                onClicked: root.switchMode("utility", true)
            }

            Text {
                text: "Power & Battery"
                font.family: batteryModule.fontDisplay
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: batteryModule.textPrimary
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            // Status chip badge
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: statusBadgeLayout.implicitWidth + 18
                radius: 12
                color: Qt.alpha(batteryModule.statusColor, 0.12)
                border.width: 1
                border.color: Qt.alpha(batteryModule.statusColor, 0.22)
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: statusBadgeLayout
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialSymbol {
                        text: batteryModule.isCharging ? "bolt" : (batteryModule.isFull ? "power" : "battery_std")
                        iconSize: 13
                        fill: 1
                        color: batteryModule.statusColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        id: statusBadgeText
                        text: batteryModule.isCharging ? "Charging" : (batteryModule.isFull ? "AC Power" : "Discharging")
                        font.family: batteryModule.fontBody
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: batteryModule.statusColor
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            // Refresh action
            IrisIconButton {
                id: refreshBtn
                buttonSize: 30
                buttonRadius: 9
                flat: true
                icon: "refresh"
                iconSize: 15
                iconColor: batteryModule.textSecondary
                onClicked: batteryModule.pollAll()
            }
        }

        // ── 1. HERO BATTERY CARD ─────────────────────────────────
        Rectangle {
            id: heroCard
            Layout.fillWidth: true
            Layout.preferredHeight: 88
            radius: 14
            color: batteryModule.cardBg
            border.width: 1
            border.color: batteryModule.cardBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Big percentage & state caption
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            spacing: 8
                            Layout.alignment: Qt.AlignLeft

                            Text {
                                text: batteryModule.batteryLevel + "%"
                                font.family: batteryModule.fontDisplay
                                font.pixelSize: 28
                                font.weight: Font.Bold
                                font.features: ({ "tnum": 1 })
                                color: batteryModule.textPrimary
                                renderType: Text.NativeRendering
                            }

                            // Subtitle pill
                            Rectangle {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: heroSubText.implicitWidth + 14
                                radius: 10
                                color: Qt.alpha(batteryModule.statusColor, 0.14)
                                border.width: 1
                                border.color: Qt.alpha(batteryModule.statusColor, 0.22)
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    id: heroSubText
                                    anchors.centerIn: parent
                                    text: batteryModule.isCharging ? "Fast Charge" : (batteryModule.isFull ? "Fully Charged" : "On Battery")
                                    font.family: batteryModule.fontBody
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
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
                            font.family: batteryModule.fontBody
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            color: batteryModule.textSecondary
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Circular glyph disc on the right with glowing state
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        color: Qt.alpha(batteryModule.statusColor, 0.12)
                        border.width: 1
                        border.color: Qt.alpha(batteryModule.statusColor, 0.20)
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: batteryModule.isCharging ? "bolt" : (batteryModule.isFull ? "battery_full" : (batteryModule.isLowLevel ? "battery_alert" : "battery_android_full"))
                            iconSize: 22
                            fill: 1
                            color: batteryModule.statusColor
                        }

                        // Subtle breathing pulse animation when charging
                        SequentialAnimation on opacity {
                            running: batteryModule.isCharging
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.55; duration: 1100; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                // Smooth inset liquid progress track
                Rectangle {
                    Layout.fillWidth: true
                    height: 5
                    radius: 2.5
                    color: Qt.rgba(255, 255, 255, 0.08)
                    clip: true

                    Rectangle {
                        height: parent.height
                        radius: 2.5
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

        // ── 2. BATTERY HEALTH CARD ───────────────────────────────
        Rectangle {
            id: healthCard
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 12
            color: batteryModule.cardBg
            border.width: 1
            border.color: batteryModule.cardBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                MaterialSymbol {
                    text: "favorite"
                    iconSize: 14
                    fill: 1
                    color: batteryModule.healthPercentage >= 80 ? batteryModule.accentColor : (batteryModule.healthPercentage >= 60 ? batteryModule.warningColor : batteryModule.errorColor)
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Battery Health"
                    font.family: batteryModule.fontBody
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: batteryModule.textPrimary
                    renderType: Text.NativeRendering
                    Layout.alignment: Qt.AlignVCenter
                }

                // Health status badge
                Rectangle {
                    Layout.preferredHeight: 20
                    Layout.preferredWidth: healthBadgeText.implicitWidth + 14
                    radius: 10
                    color: batteryModule.healthPercentage >= 80 ? Qt.alpha(batteryModule.accentColor, 0.12) : Qt.alpha(batteryModule.warningColor, 0.15)
                    border.width: 1
                    border.color: batteryModule.healthPercentage >= 80 ? Qt.alpha(batteryModule.accentColor, 0.22) : Qt.alpha(batteryModule.warningColor, 0.25)
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: healthBadgeText
                        anchors.centerIn: parent
                        text: `${batteryModule.healthPercentage}% · ${batteryModule.healthPercentage >= 80 ? "Good" : "Service Recommended"}`
                        font.family: batteryModule.fontBody
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: batteryModule.healthPercentage >= 80 ? batteryModule.accentColor : batteryModule.warningColor
                        renderType: Text.NativeRendering
                    }
                }

                Item { Layout.fillWidth: true }

                // Energy Capacity Wh
                RowLayout {
                    spacing: 4
                    visible: batteryModule.fullEnergyWh > 0
                    Layout.alignment: Qt.AlignVCenter

                    MaterialSymbol {
                        text: "bolt"
                        iconSize: 13
                        fill: 1
                        color: batteryModule.textMuted
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: `${batteryModule.fullEnergyWh.toFixed(1)} Wh`
                        font.family: batteryModule.fontBody
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                        color: batteryModule.textSecondary
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // ── 3. POWER PROFILES SELECTOR ───────────────────────────
        Rectangle {
            id: profileStrip
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 12
            color: batteryModule.cardBg
            border.width: 1
            border.color: batteryModule.cardBorder

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
                        radius: 9

                        readonly property bool isSelected: batteryModule.activeProfile === modelData.id
                        color: isSelected ? batteryModule.accentColor : (segMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : "transparent")
                        scale: segMouse.pressed ? 0.97 : 1.0

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
                                color: segBtn.isSelected ? "#090d16" : (segMouse.containsMouse ? batteryModule.textPrimary : batteryModule.textSecondary)
                                Layout.alignment: Qt.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                text: modelData.label
                                font.family: batteryModule.fontBody
                                font.pixelSize: 11
                                font.weight: segBtn.isSelected ? Font.DemiBold : Font.Medium
                                color: segBtn.isSelected ? "#090d16" : (segMouse.containsMouse ? batteryModule.textPrimary : batteryModule.textSecondary)
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
                Layout.preferredHeight: 51
                radius: 12
                color: careMouse.containsMouse ? batteryModule.cardHoverBg : batteryModule.cardBg
                border.width: 1
                border.color: batteryModule.cardBorder
                scale: careMouse.pressed ? 0.97 : 1.0
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
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 10
                        color: careTile.isActive ? Qt.alpha(batteryModule.accentColor, 0.20) : Qt.rgba(255, 255, 255, 0.06)
                        border.width: careTile.isActive ? 1 : 0
                        border.color: Qt.alpha(batteryModule.accentColor, 0.30)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "battery_saver"
                            iconSize: 16
                            fill: careTile.isActive ? 1 : 0
                            color: careTile.isActive ? batteryModule.accentColor : batteryModule.textSecondary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Battery Care"
                            font.family: batteryModule.fontBody
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: batteryModule.textPrimary
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: careTile.isActive ? "80% Limit (Healthy)" : "100% Full Capacity"
                            font.family: batteryModule.fontBody
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            color: careTile.isActive ? batteryModule.accentColor : batteryModule.textSecondary
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Tile 2: Display Eco Mode (60 Hz / 144 Hz)
            Rectangle {
                id: ecoTile
                Layout.fillWidth: true
                Layout.preferredHeight: 51
                radius: 12
                color: ecoMouse.containsMouse ? batteryModule.cardHoverBg : batteryModule.cardBg
                border.width: 1
                border.color: batteryModule.cardBorder
                scale: ecoMouse.pressed ? 0.97 : 1.0
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
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 10
                        color: ecoTile.isActive ? Qt.alpha(batteryModule.accentColor, 0.20) : Qt.rgba(255, 255, 255, 0.06)
                        border.width: ecoTile.isActive ? 1 : 0
                        border.color: Qt.alpha(batteryModule.accentColor, 0.30)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "speed"
                            iconSize: 16
                            fill: ecoTile.isActive ? 1 : 0
                            color: ecoTile.isActive ? batteryModule.accentColor : batteryModule.textSecondary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Display Eco"
                            font.family: batteryModule.fontBody
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: batteryModule.textPrimary
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: ecoTile.isActive ? "60 Hz Active (~2W saved)" : "144 Hz Smooth"
                            font.family: batteryModule.fontBody
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            color: ecoTile.isActive ? batteryModule.accentColor : batteryModule.textSecondary
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Tile 3: Keyboard Backlight
            Rectangle {
                id: kbdTile
                Layout.fillWidth: true
                Layout.preferredHeight: 51
                radius: 12
                color: kbdMouse.containsMouse ? batteryModule.cardHoverBg : batteryModule.cardBg
                border.width: 1
                border.color: batteryModule.cardBorder
                scale: kbdMouse.pressed ? 0.97 : 1.0
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
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 10
                        color: kbdTile.isActive ? Qt.alpha(batteryModule.accentColor, 0.20) : Qt.rgba(255, 255, 255, 0.06)
                        border.width: kbdTile.isActive ? 1 : 0
                        border.color: Qt.alpha(batteryModule.accentColor, 0.30)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "keyboard"
                            iconSize: 16
                            fill: kbdTile.isActive ? 1 : 0
                            color: kbdTile.isActive ? batteryModule.accentColor : batteryModule.textSecondary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Kbd Backlight"
                            font.family: batteryModule.fontBody
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: batteryModule.textPrimary
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: kbdTile.isActive ? "Illumination Active" : "Off (Power Saver)"
                            font.family: batteryModule.fontBody
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            color: kbdTile.isActive ? batteryModule.accentColor : batteryModule.textSecondary
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Tile 4: Live Power Telemetry
            Rectangle {
                id: pwrTile
                Layout.fillWidth: true
                Layout.preferredHeight: 51
                radius: 12
                color: pwrMouse.containsMouse ? batteryModule.cardHoverBg : batteryModule.cardBg
                border.width: 1
                border.color: batteryModule.cardBorder
                scale: pwrMouse.pressed ? 0.97 : 1.0
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
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 10
                        color: batteryModule.isCharging ? Qt.alpha(batteryModule.chargingColor, 0.20) : Qt.rgba(255, 255, 255, 0.06)
                        border.width: batteryModule.isCharging ? 1 : 0
                        border.color: Qt.alpha(batteryModule.chargingColor, 0.30)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "bolt"
                            iconSize: 16
                            fill: 1
                            color: batteryModule.isCharging ? batteryModule.chargingColor : (batteryModule.currentPowerW > 15 ? batteryModule.warningColor : batteryModule.textSecondary)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Power Draw"
                            font.family: batteryModule.fontBody
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: batteryModule.textPrimary
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: (batteryModule.currentPowerW > 0 ? `${batteryModule.currentPowerW.toFixed(1)} W` : "0.0 W") + ` · ${batteryModule.voltageV.toFixed(1)}V`
                            font.family: batteryModule.fontBody
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            font.features: ({ "tnum": 1 })
                            color: batteryModule.isCharging ? batteryModule.chargingColor : batteryModule.textSecondary
                            renderType: Text.NativeRendering
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
