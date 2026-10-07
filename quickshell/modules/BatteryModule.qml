import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../"

Item {
    id: batteryModule
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true
    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    // ========================================================
    // MATERIAL YOU (M3) TONAL PALETTE & MOTION TOKENS
    // ========================================================
    readonly property color colAccent: Theme.accent ?? "#7aa2f7"
    readonly property color colOnAccent: "#0e121a"
    readonly property color colAccentContainer: Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.16)
    readonly property color colCard: Qt.rgba(255, 255, 255, 0.055)
    readonly property color colCardHover: Qt.rgba(255, 255, 255, 0.10)
    readonly property color colCardActive: Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.18)
    readonly property color colChipBg: Qt.rgba(255, 255, 255, 0.08)
    readonly property color colText: "#f5f5f7"
    readonly property color colSubtext: Qt.rgba(255, 255, 255, 0.62)
    readonly property color colMuted: Qt.rgba(255, 255, 255, 0.38)

    readonly property color colGreen: "#8FDEB4"
    readonly property color colWarning: "#fbbf24"
    readonly property color colRed: "#f87171"
    readonly property var motionCurve: (typeof NotchConfig !== "undefined" && NotchConfig.motionCurve) ? NotchConfig.motionCurve : [0.05, 0.7, 0.1, 1, 1, 1]

    // ========================================================
    // REACTIVE HARDWARE STATE
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
        if (isCharging) return colGreen;
        if (isLowLevel) return colRed;
        if (isWarningLevel) return colWarning;
        return colAccent;
    }

    // Telemetry properties
    property real currentPowerW: 0.0
    property real voltageV: 12.0
    property real currentEnergyWh: 0.0
    property real fullEnergyWh: 0.0
    property int healthPercentage: 100
    property string timeRemainingStr: "Calculating..."
    property int chargeThreshold: 100
    property int refreshRate: 144
    property int kbdBacklight: 0
    property var topDrainers: []
    property string activeProfile: "balanced"

    // ========================================================
    // BACKEND SCRIPTS INTEGRATION
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
        if (data.topDrainers) batteryModule.topDrainers = data.topDrainers;
    }

    function pollAll() {
        if (!telemetryPoller.running) telemetryPoller.running = true;
        if (!profileChecker.running) profileChecker.running = true;
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode === "battery") {
                if (typeof root !== "undefined" && root.cachedBatteryTelemetry) {
                    batteryModule.applyTelemetry(root.cachedBatteryTelemetry);
                }
                batteryModule.pollAll();
            }
        }
    }

    Timer {
        interval: 1000
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
    // REUSABLE MATERIAL YOU (M3) COMPONENTS
    // ========================================================

    // 1. Material You Circular Action Button
    component MaterialCircleBtn: Rectangle {
        id: cbtn
        property string glyph: ""
        property color iconColor: batteryModule.colText
        signal clicked()

        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: 16
        color: cmouse.containsMouse ? batteryModule.colCardHover : batteryModule.colCard
        border.width: 0

        scale: cmouse.pressed ? 0.90 : (cmouse.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: cbtn.glyph
            iconSize: 17
            color: cbtn.iconColor
        }

        MouseArea {
            id: cmouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: cbtn.clicked()
        }
    }

    // 2. Material You Quick Settings Stadium Tile (Matches Control Center)
    component MaterialPill: Rectangle {
        id: pill
        property string glyph: ""
        property string title: ""
        property string subtitle: ""
        property bool isActive: false
        property color activeColor: batteryModule.colAccent
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 46
        radius: 23

        color: pill.isActive
            ? Qt.rgba(pill.activeColor.r, pill.activeColor.g, pill.activeColor.b, 0.16)
            : (pillMouse.containsMouse ? batteryModule.colCardHover : batteryModule.colCard)
        border.width: 0

        scale: pillMouse.pressed ? 0.982 : (pillMouse.containsMouse ? 1.008 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 12
            spacing: 10

            // Left: Circular Icon Disc
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: pill.isActive ? pill.activeColor : (pillMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.085))

                scale: pillMouse.pressed ? 0.92 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: pill.glyph
                    fill: pill.isActive ? 1 : 0
                    iconSize: 19
                    color: pill.isActive ? "#101318" : batteryModule.colText
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            // Right: Text Content Area
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Layout.alignment: Qt.AlignVCenter

                Text {
                    Layout.fillWidth: true
                    text: pill.title
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: pill.isActive ? "#ffffff" : batteryModule.colText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    text: pill.subtitle
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.Normal
                    color: pill.isActive ? pill.activeColor : batteryModule.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    renderType: Text.NativeRendering
                }
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    // ========================================================
    // MAIN DASHBOARD LAYOUT
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        spacing: 8

        // ══════════════════════════════════════════════════════════
        // 1. MATERIAL YOU TOP HEADER
        // ══════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Back to Control Center
            MaterialCircleBtn {
                glyph: "arrow_back"
                iconColor: batteryModule.colAccent
                onClicked: root.switchMode("utility", true)
            }

            // Title & Live Summary
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: "Battery & Power"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: batteryModule.colText
                    renderType: Text.NativeRendering
                }

                Text {
                    text: {
                        if (batteryModule.isFull) return "AC Power Connected • Fully Charged";
                        if (batteryModule.isCharging) {
                            return "Fast Charging • " + (batteryModule.timeRemainingStr !== "Calculating..." ? batteryModule.timeRemainingStr : "Plugged In");
                        }
                        return batteryModule.timeRemainingStr !== "Calculating..." ? (batteryModule.timeRemainingStr + " • Discharging") : "Discharging on Battery";
                    }
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.Normal
                    color: batteryModule.colSubtext
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    renderType: Text.NativeRendering
                }
            }

            // Diagnostics / Refresh Button
            MaterialCircleBtn {
                glyph: "refresh"
                iconColor: batteryModule.colSubtext
                onClicked: batteryModule.pollAll()
            }

            // Close Button
            MaterialCircleBtn {
                glyph: "close"
                iconColor: batteryModule.colSubtext
                onClicked: root.collapseToIdle()
            }
        }

        // ══════════════════════════════════════════════════════════
        // 2. MATERIAL YOU HERO BATTERY WIDGET CARD
        // ══════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 102
            radius: 20
            color: batteryModule.colCard
            border.width: 0

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 8

                // Top Line: Big Expressive Percentage + Dynamic Status Pill + Power Draw Metric
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Big Expressive Percentage
                    Text {
                        text: batteryModule.batteryLevel + "%"
                        font.family: "Noto Sans"
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        color: batteryModule.statusColor
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Dynamic Material You Status Pill
                    Rectangle {
                        height: 24
                        radius: 12
                        color: Qt.rgba(batteryModule.statusColor.r, batteryModule.statusColor.g, batteryModule.statusColor.b, 0.18)
                        border.width: 0
                        implicitWidth: statusPillRow.implicitWidth + 16
                        Layout.alignment: Qt.AlignVCenter

                        Row {
                            id: statusPillRow
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: batteryModule.isCharging ? "bolt" : (batteryModule.isFull ? "power" : (batteryModule.isLowLevel ? "battery_alert" : "battery_full"))
                                fill: 1
                                iconSize: 14
                                color: batteryModule.statusColor
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: batteryModule.isCharging ? "Charging" : (batteryModule.isFull ? "Fully Charged" : (batteryModule.isLowLevel ? "Low Battery" : "On Battery"))
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: batteryModule.statusColor
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Power Draw Metric Chip
                    Rectangle {
                        height: 24
                        radius: 12
                        color: batteryModule.colChipBg
                        border.width: 0
                        implicitWidth: powerMetricRow.implicitWidth + 14
                        Layout.alignment: Qt.AlignVCenter

                        Row {
                            id: powerMetricRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "electric_bolt"
                                iconSize: 13
                                color: batteryModule.statusColor
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (batteryModule.currentPowerW > 0 ? batteryModule.currentPowerW.toFixed(1) + " W" : "0.0 W")
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: batteryModule.colText
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }

                // Middle: Material 3 Expressive Stadium Track
                Rectangle {
                    Layout.fillWidth: true
                    height: 12
                    radius: 6
                    color: Qt.rgba(255, 255, 255, 0.08)
                    clip: true

                    Rectangle {
                        id: progressFill
                        height: parent.height
                        radius: parent.radius
                        color: batteryModule.statusColor
                        width: parent.width * (Math.min(100, Math.max(0, batteryModule.batteryLevel)) / 100.0)

                        Behavior on width {
                            NumberAnimation {
                                duration: 380
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: batteryModule.motionCurve
                            }
                        }

                        // Fluid charging shimmer
                        Rectangle {
                            visible: batteryModule.isCharging && !batteryModule.isFull
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(1, 1, 1, 0.16)
                            opacity: 0

                            property real shimmerPos: 0
                            x: (parent.width + width) * shimmerPos - width

                            SequentialAnimation on shimmerPos {
                                running: batteryModule.isCharging && !batteryModule.isFull
                                loops: Animation.Infinite
                                NumberAnimation { from: -0.3; to: 1.3; duration: 1400; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: 300 }
                            }

                            SequentialAnimation on opacity {
                                running: batteryModule.isCharging && !batteryModule.isFull
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.04; to: 0.20; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.20; to: 0.04; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }

                // Bottom Line: Material 3 Tonal Info Chips
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Chip 1: Time remaining
                    Rectangle {
                        height: 22
                        radius: 11
                        color: batteryModule.colChipBg
                        border.width: 0
                        implicitWidth: chipTimeRow.implicitWidth + 14

                        Row {
                            id: chipTimeRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "schedule"
                                iconSize: 12
                                color: batteryModule.colSubtext
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: batteryModule.timeRemainingStr
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: batteryModule.colSubtext
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    // Chip 2: Health
                    Rectangle {
                        height: 22
                        radius: 11
                        color: batteryModule.colChipBg
                        border.width: 0
                        implicitWidth: chipHealthRow.implicitWidth + 14

                        Row {
                            id: chipHealthRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "health_and_safety"
                                iconSize: 12
                                color: batteryModule.colSubtext
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: batteryModule.healthPercentage + "% Health"
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: batteryModule.colSubtext
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    // Chip 3: Voltage
                    Rectangle {
                        height: 22
                        radius: 11
                        color: batteryModule.colChipBg
                        border.width: 0
                        implicitWidth: chipVoltRow.implicitWidth + 14

                        Row {
                            id: chipVoltRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "speed"
                                iconSize: 12
                                color: batteryModule.colSubtext
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: batteryModule.voltageV.toFixed(1) + " V"
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: batteryModule.colSubtext
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════
        // 3. POWER PROFILES (Material 3 Segmented Stadium Button)
        // ══════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 19
            color: batteryModule.colCard
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 4

                readonly property var profiles: [
                    { id: "power-saver", label: "Power Saver", icon: "energy_savings_leaf" },
                    { id: "balanced",    label: "Balanced",    icon: "tune" },
                    { id: "performance", label: "Performance", icon: "rocket_launch" }
                ]

                Repeater {
                    model: parent.profiles

                    Rectangle {
                        id: segPill
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 16

                        readonly property bool isSelected: batteryModule.activeProfile === modelData.id

                        color: isSelected ? batteryModule.colAccent : (segMouse.containsMouse ? batteryModule.colCardHover : "transparent")
                        border.width: 0

                        scale: segMouse.pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                iconSize: 16
                                fill: segPill.isSelected ? 1 : 0
                                color: segPill.isSelected ? batteryModule.colOnAccent : (segMouse.containsMouse ? "#ffffff" : batteryModule.colSubtext)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: segPill.isSelected ? Font.DemiBold : Font.Medium
                                color: segPill.isSelected ? batteryModule.colOnAccent : (segMouse.containsMouse ? "#ffffff" : batteryModule.colText)
                                renderType: Text.NativeRendering
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        MouseArea {
                            id: segMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: batteryModule.setPowerProfile(modelData.id)
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════
        // 4. HARDWARE & ECO TILES (Material 3 Stadium Tiles Grid)
        // ══════════════════════════════════════════════════════════
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            // Tile 1: Battery Care (80% Asus Charge Threshold)
            MaterialPill {
                glyph: "battery_saver"
                title: "Battery Care"
                subtitle: batteryModule.chargeThreshold === 80 ? "80% Limit (Healthy)" : "100% Full Capacity"
                isActive: batteryModule.chargeThreshold === 80
                activeColor: batteryModule.colAccent
                onClicked: batteryModule.toggleChargeThreshold()
            }

            // Tile 2: Display Eco 60Hz Mode
            MaterialPill {
                glyph: "desktop_windows"
                title: "Display Eco"
                subtitle: batteryModule.refreshRate <= 60 ? "60 Hz Active (Eco)" : "144 Hz Smooth"
                isActive: batteryModule.refreshRate <= 60
                activeColor: batteryModule.colAccent
                onClicked: batteryModule.toggleRefreshRate()
            }

            // Tile 3: Keyboard Backlight
            MaterialPill {
                glyph: "keyboard"
                title: "Kbd Backlight"
                subtitle: batteryModule.kbdBacklight > 0 ? "Illumination On" : "Off (Power Saver)"
                isActive: batteryModule.kbdBacklight > 0
                activeColor: batteryModule.colAccent
                onClicked: batteryModule.toggleKbdBacklight()
            }

            // Tile 4: Instant Telemetry / Power Draw Rate
            MaterialPill {
                glyph: "bolt"
                title: "Power Telemetry"
                subtitle: (batteryModule.currentPowerW > 0 ? batteryModule.currentPowerW.toFixed(1) + " W rate" : "0.0 W idle") + " • " + batteryModule.voltageV.toFixed(1) + "V"
                isActive: batteryModule.isCharging
                activeColor: batteryModule.colGreen
                onClicked: batteryModule.pollAll()
            }
        }
    }
}
