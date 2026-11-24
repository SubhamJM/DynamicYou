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

    readonly property int calculatedHeight: 460

    // Theming & Color Tokens
    readonly property color textSecondary: Theme.alpha(Theme.text, 0.72)
    readonly property color textMuted: Theme.alpha(Theme.text, 0.45)
    readonly property color panelColor: Theme.alpha(Theme.text, 0.055)
    readonly property color dividerColor: Theme.alpha(Theme.text, 0.05)
    readonly property color chargingColor: (typeof Theme !== "undefined" && Theme.success) ? Theme.success : "#4ade80"
    readonly property color warningColor: "#ecc46e"
    readonly property color errorColor: (typeof Theme !== "undefined" && Theme.error) ? Theme.error : "#ff5449"

    // UPower Service Integration
    readonly property var upowerDev: typeof UPower !== "undefined" ? UPower.displayDevice : null
    readonly property bool hasUPowerBattery: !!(upowerDev && upowerDev.ready && upowerDev.isPresent)
    readonly property bool hasUPowerState: hasUPowerBattery && upowerDev.state !== UPowerDevice.Unknown
    readonly property bool hasBatteryLevel: hasUPowerBattery || telemetryReady

    property bool telemetryReady: false
    property int rawBatteryLevel: 98
    property bool rawIsCharging: false
    property bool rawIsFull: false

    property int batteryLevel: hasUPowerBattery
        ? Math.round(upowerDev.percentage * 100)
        : rawBatteryLevel

    property bool isCharging: hasUPowerState
        ? (upowerDev.state === UPowerDevice.Charging)
        : rawIsCharging

    property bool isFull: hasUPowerState
        ? upowerDev.state === UPowerDevice.FullyCharged
        : rawIsFull

    readonly property bool isWarningLevel: batteryLevel <= 25 && batteryLevel > 15 && !isCharging
    readonly property bool isLowLevel: batteryLevel <= 15 && !isCharging

    readonly property color statusColor: {
        if (isCharging) return chargingColor;
        if (hasBatteryLevel && isLowLevel) return errorColor;
        if (hasBatteryLevel && isWarningLevel) return warningColor;
        return (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7";
    }

    // Hardware Telemetry
    property real currentPowerW: 0.0
    property real voltageV: 12.0
    property real currentEnergyWh: 37.7
    property real fullEnergyWh: 38.9
    property int healthPercentage: 87
    property string timeRemainingStr: "Calculating..."
    property int chargeThreshold: 100
    property bool chargeThresholdSupported: false
    property bool chargeLimitPending: false
    property string chargeLimitMessage: ""
    property string pendingAction: ""
    property int refreshRate: 144
    property int kbdBacklight: 0
    property bool refreshRateSupported: false
    property bool kbdBacklightSupported: false
    property string activeProfile: ""

    // ========================================================
    // BACKEND PROCESSES & ON-DEMAND POLLING
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
                    const data = JSON.parse(this.text.trim());
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
            if (batteryModule.pendingAction === "set_threshold")
                batteryModule.chargeLimitPending = false;
            batteryModule.pendingAction = "";
            telemetryPoller.running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (batteryModule.pendingAction !== "set_threshold" || !this.text.trim()) return;
                try {
                    const result = JSON.parse(this.text.trim());
                    if (result.status === "ok") {
                        batteryModule.chargeThreshold = result.chargeThreshold;
                        batteryModule.chargeThresholdSupported = true;
                        batteryModule.chargeLimitMessage = "";
                    } else {
                        batteryModule.chargeLimitMessage = result.message || "Could not change charge limit";
                    }
                } catch (error) {
                    batteryModule.chargeLimitMessage = "Could not read charge limit result";
                }
            }
        }
    }

    function runTelemetryAction(cmdArgs) {
        pendingAction = cmdArgs.length ? cmdArgs[0] : "";
        actionRunner.command = ["python3", batteryModule.scriptPath].concat(cmdArgs);
        actionRunner.running = true;
    }

    function toggleRefreshRate() {
        runTelemetryAction(["toggle_hz"]);
    }

    function toggleKbdBacklight() {
        runTelemetryAction(["toggle_kbd"]);
    }

    function toggleChargeThreshold() {
        if (!chargeThresholdSupported || chargeLimitPending || actionRunner.running) return;
        var next = (batteryModule.chargeThreshold === 80) ? 100 : 80;
        chargeLimitPending = true;
        chargeLimitMessage = "";
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
        if (data.chargeThresholdSupported !== undefined) batteryModule.chargeThresholdSupported = !!data.chargeThresholdSupported;
        if (data.refreshRate !== undefined) batteryModule.refreshRate = data.refreshRate;
        if (data.refreshRateSupported !== undefined) batteryModule.refreshRateSupported = !!data.refreshRateSupported;
        if (data.kbdBacklight !== undefined) batteryModule.kbdBacklight = data.kbdBacklight;
        if (data.kbdBacklightSupported !== undefined) batteryModule.kbdBacklightSupported = !!data.kbdBacklightSupported;
        telemetryReady = true;
    }

    function pollAll() {
        if (!telemetryPoller.running) telemetryPoller.running = true;
        if (!profileChecker.running) profileChecker.running = true;
    }

    Timer {
        interval: 3000
        running: root.activeMode === "battery"
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryModule.pollAll()
    }

    Timer {
        interval: 5000
        running: batteryModule.chargeLimitMessage !== ""
        repeat: false
        onTriggered: batteryModule.chargeLimitMessage = ""
    }

    Component.onCompleted: {
        if (typeof root !== "undefined" && root.cachedBatteryTelemetry) {
            batteryModule.applyTelemetry(root.cachedBatteryTelemetry);
        }
        batteryModule.pollAll();
    }

    readonly property bool isOnAC: hasUPowerBattery && !UPower.onBattery
    readonly property string powerState: {
        if (isCharging) return "Charging";
        if (isFull || isOnAC) return "AC power";
        return hasBatteryLevel ? "Discharging" : "Battery";
    }
    readonly property string batteryStatus: {
        if (isFull) return "Fully charged";
        if (isOnAC && !isCharging) return "Not charging";
        if (timeRemainingStr && !/^(Calculating\.\.\.|Fully Charged|Charging|\d+% Discharging)$/.test(timeRemainingStr))
            return timeRemainingStr;
        return isCharging ? "Calculating charge time…" : "Calculating time left…";
    }

    // ========================================================
    // UI LAYOUT
    // ========================================================
    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        anchors.topMargin: 0
        anchors.bottomMargin: 0
        spacing: 8

        // 1. Header Bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 8

            IrisIconButton {
                buttonSize: 30
                buttonRadius: 15
                flat: true
                icon: "arrow_back"
                iconSize: 16
                iconColor: batteryModule.textSecondary
                Accessible.role: Accessible.Button
                Accessible.name: "Back to Control Center"
                onClicked: root.switchMode("utility", true)
            }

            Label {
                text: "Power & Battery"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Item { Layout.fillWidth: true }
        }

        // 2. Hero Battery Card
        Panel {
            Layout.fillWidth: true
            Layout.preferredHeight: 152
            radius: 14
            color: Theme.alpha(Theme.colors.card_bg || Theme.text, 0.45)
            border.width: 0

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: 8

                // Top: Big Percentage & Status Badge
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        text: batteryModule.hasBatteryLevel ? batteryModule.batteryLevel + "%" : "—"
                        font.family: "Readex Pro"
                        font.pixelSize: 36
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                        color: Theme.text
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: 3

                        Rectangle {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: statusBadgeRow.implicitWidth + 18
                            radius: 12
                            color: Theme.alpha(batteryModule.statusColor, 0.16)
                            border.width: 0

                            Row {
                                id: statusBadgeRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: batteryModule.isCharging ? "bolt"
                                        : batteryModule.isFull || batteryModule.isOnAC ? "power" : "battery_std"
                                    iconSize: 13
                                    color: batteryModule.statusColor
                                }

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: batteryModule.powerState
                                    color: batteryModule.statusColor
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: batteryModule.batteryStatus
                            color: batteryModule.textSecondary
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                        }
                    }
                }

                // Middle: Visual Battery Charge Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.alpha(Theme.text, 0.08)

                    Rectangle {
                        id: batteryFill
                        height: parent.height
                        radius: 3
                        color: batteryModule.statusColor
                        width: Math.max(0, Math.min(parent.width, parent.width * (batteryModule.batteryLevel / 100.0)))

                        Behavior on width {
                            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 250 }
                        }

                        // Subtle charging pulse animation
                        SequentialAnimation on opacity {
                            running: batteryModule.isCharging
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.65; duration: 900; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                Divider {
                    Layout.fillWidth: true
                    color: Theme.alpha(Theme.text, 0.07)
                }

                // Bottom: 3 Balanced Metric Tiles
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Metric {
                        title: "BATTERY HEALTH"
                        value: batteryModule.telemetryReady ? batteryModule.healthPercentage + "%" : "—"
                        detail: !batteryModule.telemetryReady ? "" : batteryModule.healthPercentage >= 80 ? "Good" : "Service"
                        detailColor: batteryModule.healthPercentage >= 80 ? batteryModule.chargingColor : batteryModule.warningColor
                    }

                    Divider { Layout.fillHeight: true; Layout.topMargin: 2; Layout.bottomMargin: 2 }

                    Metric {
                        title: "FULL CAPACITY"
                        value: batteryModule.telemetryReady && batteryModule.fullEnergyWh > 0
                            ? batteryModule.fullEnergyWh.toFixed(1) + " Wh" : "—"
                        detail: batteryModule.telemetryReady ? batteryModule.currentEnergyWh.toFixed(1) + " Wh now" : ""
                    }

                    Divider { Layout.fillHeight: true; Layout.topMargin: 2; Layout.bottomMargin: 2 }

                    Button {
                        id: powerMetric
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        padding: 0
                        hoverEnabled: true
                        Accessible.name: "Refresh power draw"
                        onClicked: batteryModule.pollAll()

                        contentItem: Metric {
                            title: "POWER DRAW"
                            value: batteryModule.telemetryReady ? Math.max(0, batteryModule.currentPowerW).toFixed(1) + " W" : "—"
                            detail: batteryModule.telemetryReady ? batteryModule.voltageV.toFixed(1) + " V" : ""
                        }
                        background: Rectangle {
                            radius: 8
                            color: powerMetric.hovered || powerMetric.activeFocus ? Theme.alpha(Theme.text, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }
            }
        }

        // 3. Power Profile Selector
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7

            Label {
                Layout.leftMargin: 2
                text: "POWER PROFILE"
                color: batteryModule.textSecondary
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Panel {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                radius: 12
                color: Theme.alpha(Theme.text, 0.04)
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Repeater {
                        model: [
                            { key: "power-saver", label: "Power Saver", glyph: "energy_savings_leaf" },
                            { key: "balanced", label: "Balanced", glyph: "airwave" },
                            { key: "performance", label: "Performance", glyph: "rocket_launch" }
                        ]

                        Button {
                            id: profileButton
                            required property var modelData
                            readonly property bool selected: batteryModule.activeProfile === modelData.key
                            readonly property color ink: selected
                                ? (Theme.fgPrimary || "#101014")
                                : (hovered ? Theme.text : batteryModule.textSecondary)

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 0
                            padding: 0
                            hoverEnabled: true
                            text: modelData.label
                            Accessible.role: Accessible.RadioButton
                            Accessible.checkable: true
                            Accessible.checked: selected
                            onClicked: batteryModule.setPowerProfile(modelData.key)

                            contentItem: Item {
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MaterialSymbol {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: profileButton.modelData.glyph
                                        iconSize: 15
                                        color: profileButton.ink
                                    }
                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: profileButton.text
                                        color: profileButton.ink
                                        font.pixelSize: 11
                                        font.weight: profileButton.selected ? Font.Bold : Font.Medium
                                    }
                                }
                            }
                            background: Rectangle {
                                radius: 9
                                color: profileButton.selected
                                    ? Theme.accent
                                    : (profileButton.hovered || profileButton.down ? Theme.alpha(Theme.text, 0.08) : "transparent")
                                border.width: 0
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }
                    }
                }
            }
        }

        // 4. Settings Card (Battery Care, Display Eco, Keyboard Backlight)
        Panel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 154
            radius: 14
            color: batteryModule.panelColor
            border.width: 0

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                spacing: 2

                SettingRow {
                    glyph: "battery_saver"
                    title: "Battery care"
                    subtitle: batteryModule.chargeLimitMessage !== ""
                        ? batteryModule.chargeLimitMessage
                        : !batteryModule.chargeThresholdSupported
                            ? "Charge threshold limit not supported"
                            : batteryModule.chargeThreshold === 80
                                ? "Charge capped at 80% to protect health"
                                : "Charging to 100% full capacity"
                    buttonLabel: batteryModule.chargeLimitPending ? "Applying…"
                        : !batteryModule.chargeThresholdSupported ? "Unavailable"
                        : batteryModule.chargeThreshold === 80 ? "80% Limit" : "100% Full"
                    settingActive: batteryModule.chargeThreshold === 80
                    supported: batteryModule.chargeThresholdSupported && !batteryModule.chargeLimitPending
                    showWhenDisabled: true
                    onClicked: batteryModule.toggleChargeThreshold()
                }

                Divider {
                    Layout.fillWidth: true
                    Layout.leftMargin: 46
                    Layout.rightMargin: 8
                    color: Theme.alpha(Theme.text, 0.05)
                }

                SettingRow {
                    glyph: "speed"
                    title: "Display eco"
                    subtitle: batteryModule.refreshRateSupported ? "Switch between available refresh rates" : "No alternate refresh rate available"
                    buttonLabel: batteryModule.refreshRateSupported ? batteryModule.refreshRate + " Hz" : "Unavailable"
                    supported: batteryModule.refreshRateSupported
                    showWhenDisabled: true
                    settingActive: batteryModule.refreshRate <= 60
                    onClicked: batteryModule.toggleRefreshRate()
                }

                Divider {
                    Layout.fillWidth: true
                    Layout.leftMargin: 46
                    Layout.rightMargin: 8
                    color: Theme.alpha(Theme.text, 0.05)
                }

                SettingRow {
                    glyph: "keyboard"
                    title: "Keyboard backlight"
                    subtitle: !batteryModule.kbdBacklightSupported ? "No keyboard backlight detected" : batteryModule.kbdBacklight > 0
                        ? "Hardware key illumination enabled"
                        : "Backlight off to conserve battery"
                    buttonLabel: !batteryModule.kbdBacklightSupported ? "Unavailable" : batteryModule.kbdBacklight > 0 ? "On" : "Off"
                    supported: batteryModule.kbdBacklightSupported
                    showWhenDisabled: true
                    settingActive: batteryModule.kbdBacklight > 0
                    onClicked: batteryModule.toggleKbdBacklight()
                }
            }
        }
    }

    // ========================================================
    // REUSABLE SUBCOMPONENTS
    // ========================================================
    component Label: Text {
        color: Theme.text
        font.family: Theme.fontFamilyBody
        font.pixelSize: 12
        renderType: Text.NativeRendering
    }

    component Panel: Rectangle {
        radius: 14
        color: batteryModule.panelColor
        border.width: 0
    }

    component Divider: Rectangle {
        implicitWidth: 1
        implicitHeight: 1
        color: batteryModule.dividerColor
        border.width: 0
    }

    component Metric: ColumnLayout {
        id: metric
        required property string title
        required property string value
        property string detail: ""
        property color detailColor: batteryModule.textSecondary

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 1
        Layout.maximumWidth: Infinity
        Layout.alignment: Qt.AlignVCenter
        spacing: 1

        Label {
            text: metric.title
            color: batteryModule.textMuted
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
        }

        Label {
            text: metric.value
            font.pixelSize: 13
            font.weight: Font.Bold
            font.features: ({ "tnum": 1 })
            color: Theme.text
        }

        Label {
            text: metric.detail
            visible: text !== ""
            color: metric.detailColor
            font.pixelSize: 10
            font.weight: Font.Medium
        }
    }

    component SettingRow: Button {
        id: setting
        required property string glyph
        required property string title
        required property string subtitle
        required property string buttonLabel
        required property bool settingActive
        property bool supported: true
        property bool showWhenDisabled: false

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 46
        leftPadding: 8
        rightPadding: 8
        topPadding: 0
        bottomPadding: 0
        hoverEnabled: true
        enabled: batteryModule.telemetryReady && supported
        Accessible.role: Accessible.Button
        Accessible.name: title + ", " + buttonLabel
        Accessible.description: subtitle

        contentItem: RowLayout {
            spacing: 10

            // Icon Plate Badge
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 10
                color: setting.settingActive
                    ? Theme.alpha(Theme.accent, 0.20)
                    : Theme.alpha(Theme.text, 0.08)
                border.width: 0

                Behavior on color { ColorAnimation { duration: 140 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: setting.glyph
                    iconSize: 16
                    color: setting.settingActive ? Theme.accent : batteryModule.textSecondary
                }
            }

            // Title & Subtitle Column
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Label {
                    Layout.fillWidth: true
                    text: setting.title
                    font.weight: Font.Medium
                    font.pixelSize: 13
                    color: Theme.text
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    text: setting.subtitle
                    font.pixelSize: 10
                    color: batteryModule.textMuted
                    elide: Text.ElideRight
                }
            }

            // Interactive Tonal State Pill Button / Toggle
            Rectangle {
                id: pillBtn
                Layout.preferredHeight: 28
                implicitWidth: pillRow.implicitWidth + 20
                radius: 14
                color: {
                    if (!setting.enabled && !setting.showWhenDisabled)
                        return Theme.alpha(Theme.text, 0.05);
                    if (setting.settingActive)
                        return setting.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent;
                    return setting.hovered ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.text, 0.07);
                }
                border.width: 0

                Behavior on color { ColorAnimation { duration: 140 } }

                RowLayout {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        visible: setting.settingActive && setting.enabled
                        text: "check"
                        iconSize: 13
                        color: setting.settingActive ? (Theme.fgPrimary || "#101014") : batteryModule.textSecondary
                    }

                    Label {
                        text: setting.buttonLabel
                        font.pixelSize: 11
                        font.weight: setting.settingActive ? Font.Bold : Font.Medium
                        color: {
                            if (!setting.enabled && !setting.showWhenDisabled)
                                return batteryModule.textMuted;
                            if (setting.settingActive)
                                return Theme.fgPrimary || "#101014";
                            return batteryModule.textSecondary;
                        }
                    }
                }
            }
        }

        background: Rectangle {
            radius: 10
            color: setting.down || setting.hovered ? Theme.alpha(Theme.text, 0.06) : "transparent"
            border.width: 0
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }
}
