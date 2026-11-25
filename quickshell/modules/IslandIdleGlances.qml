pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import "../"
import "."
import "./widgets"

// Matushell-style resting Dynamic Island glance row:
// [Date • Time] [Network] [Material Battery w/ embedded percentage] (+ active timer)
// Uses Google Sans Flex + GPU QtRendering/CurveRendering for crisp legibility at fractional scale.
RowLayout {
    id: root

    property date clockDate: new Date()
    property bool isScreenRecording: false
    property int notificationCount: 0
    property bool dndEnabled: false
    property string activeNetType: "wifi"
    property string activeNetName: ""
    property int activeNetSignal: 0

    signal timerOpenRequested(string tab)

    spacing: 10
    implicitHeight: 28

    // --- Shared crisp typography tokens ---
    readonly property color fgPrimary: Theme.colors.text_primary ?? "#f5f5f7"
    readonly property color fgSecondary: Qt.alpha(fgPrimary, 0.72)
    readonly property color accentColor: Theme.accent
    readonly property color onAccentColor: Theme.onAccent

    // --- Network Data ---
    readonly property bool wifiConnected: (typeof WidgetTelemetry !== "undefined" && WidgetTelemetry.wifiConnected)
        || (root.activeNetType === "wifi" && root.activeNetName.length > 0)
    readonly property bool ethernetConnected: (typeof Net !== "undefined" && Net.wiredDevices && Net.wiredDevices.some(d => d && d.connected))
        || (root.activeNetType === "eth" && root.activeNetName.length > 0)
    readonly property bool isNetConnected: wifiConnected || ethernetConnected
    readonly property real wifiSignalPct: {
        if (typeof WidgetTelemetry !== "undefined" && WidgetTelemetry.wifiSignal >= 0) {
            return WidgetTelemetry.wifiSignal;
        }
        return root.activeNetSignal;
    }
    readonly property string networkGlyph: {
        if (!root.isNetConnected) return "android_cell_5_bar_off";
        if (root.ethernetConnected) return "lan";
        if (root.wifiSignalPct >= 0 && root.wifiSignalPct < 50) return "android_cell_4_bar";
        return "android_cell_5_bar";
    }

    // --- Battery Data ---
    readonly property var upowerDev: (typeof UPower !== "undefined") ? UPower.displayDevice : null
    readonly property bool batteryPresent: (typeof Battery !== "undefined" && Battery.available)
        || Boolean(root.upowerDev && (root.upowerDev.isLaptopBattery || root.upowerDev.isPresent))
    readonly property int batteryPct: {
        if (typeof Battery !== "undefined" && Battery.available) return Battery.percent;
        if (root.upowerDev && root.upowerDev.percentage !== undefined) {
            return Math.round(Math.max(0, Math.min(1, root.upowerDev.percentage)) * 100);
        }
        return 100;
    }
    readonly property bool batteryCharging: (typeof Battery !== "undefined" && Battery.available)
        ? Battery.isCharging
        : Boolean(root.upowerDev && root.upowerDev.state === UPowerDeviceState.Charging)
    readonly property bool isLowBattery: !root.batteryCharging && root.batteryPct < 20
    readonly property color batteryFillColor: root.isLowBattery
        ? (Theme.colors.error ?? "#ffb4ab")
        : root.accentColor
    readonly property color batteryOnFillColor: root.isLowBattery
        ? "#101014"
        : root.onAccentColor

    // 1. Clock glance (Matushell textForm: ddd, MMM d • h:mm)
    Row {
        id: clockGlance
        Layout.alignment: Qt.AlignVCenter
        spacing: 5

        Text {
            id: dateLabel
            anchors.baseline: clockFigure.baseline
            text: Qt.formatDate(root.clockDate, "ddd, MMM d")
            color: root.fgPrimary
            font.family: "Google Sans Flex"
            font.pixelSize: 13
            font.weight: Font.Medium
            font.variableAxes: ({ "wght": 500, "wdth": 100 })
            font.hintingPreference: Font.PreferNoHinting
            renderType: Text.QtRendering
            antialiasing: true
            smooth: true
        }

        Text {
            anchors.baseline: clockFigure.baseline
            text: "•"
            color: root.fgSecondary
            font.family: "Google Sans Flex"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.variableAxes: ({ "wght": 500, "wdth": 100 })
            font.hintingPreference: Font.PreferNoHinting
            renderType: Text.QtRendering
            antialiasing: true
            smooth: true
        }

        IrisClock {
            id: clockFigure
            pixelSize: 13
            family: "Google Sans Flex"
            weight: Font.Medium
            axisWeight: 500
            renderType: Text.QtRendering
            text: {
                const h = root.clockDate.getHours() % 12 || 12;
                const m = root.clockDate.getMinutes();
                return String(h) + ":" + (m < 10 ? "0" : "") + m;
            }
            color: root.fgPrimary
            separatorColor: root.accentColor
            isScreenRecording: root.isScreenRecording
        }
    }

    // 2. Network glance (Matushell IslandNetwork: cell bars / lan)
    Text {
        id: networkIcon
        Layout.alignment: Qt.AlignVCenter
        text: root.networkGlyph
        color: root.isNetConnected ? root.accentColor : Qt.alpha(root.fgPrimary, 0.5)
        font.family: Theme.fontFamilyIcon
        font.pixelSize: 16
        font.hintingPreference: Font.PreferNoHinting
        font.variableAxes: ({
            "FILL": 0,
            "GRAD": Theme.fontIconGrad,
            "opsz": 16,
            "wght": 500
        })
        renderType: Text.CurveRendering
        antialiasing: true
        smooth: true
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // 3. Material Battery glance (Matushell IslandBattery: Android-style capsule + embedded dual-tone %)
    Item {
        id: batteryGlance
        Layout.alignment: Qt.AlignVCenter
        readonly property int bodyWidth: 28
        readonly property int bodyHeight: 14
        readonly property int clampedPct: Math.max(0, Math.min(100, root.batteryPct))
        readonly property real fillWidth: Math.round(bodyWidth * (clampedPct / 100))

        implicitWidth: root.batteryPresent ? (bodyWidth + (root.batteryCharging ? 9 : 4)) : 16
        implicitHeight: root.batteryPresent ? bodyHeight : 16

        ClippingRectangle {
            id: batteryBody
            visible: root.batteryPresent
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: batteryGlance.bodyWidth
            height: batteryGlance.bodyHeight
            radius: 5
            color: Qt.alpha(root.fgPrimary, 0.22)

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: batteryGlance.fillWidth
                color: root.batteryFillColor

                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }

        // Right terminal cap when discharging / full
        Rectangle {
            visible: root.batteryPresent && !root.batteryCharging
            anchors.left: batteryBody.right
            anchors.leftMargin: 1
            anchors.verticalCenter: batteryBody.verticalCenter
            width: 2
            height: 6
            radius: 1
            color: Qt.alpha(root.fgPrimary, 0.42)
        }

        // Charging bolt beside the capsule so embedded percentage remains clear
        Shape {
            id: chargingBolt
            visible: root.batteryPresent && root.batteryCharging
            anchors.left: batteryBody.right
            anchors.leftMargin: 2
            anchors.verticalCenter: batteryBody.verticalCenter
            width: 7
            height: 10
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                strokeColor: root.accentColor
                strokeWidth: 1
                fillColor: root.accentColor

                startX: chargingBolt.width * 0.65
                startY: 0

                PathLine { x: chargingBolt.width * 0.2; y: chargingBolt.height * 0.55 }
                PathLine { x: chargingBolt.width * 0.55; y: chargingBolt.height * 0.55 }
                PathLine { x: chargingBolt.width * 0.35; y: chargingBolt.height }
                PathLine { x: chargingBolt.width * 0.8; y: chargingBolt.height * 0.45 }
                PathLine { x: chargingBolt.width * 0.45; y: chargingBolt.height * 0.45 }
                PathLine { x: chargingBolt.width * 0.65; y: 0 }
            }
        }

        // Matushell dual-color progress percentage centered inside battery capsule
        Item {
            id: percentageWrap
            visible: root.batteryPresent
            anchors.centerIn: batteryBody
            width: Math.ceil(pctUnderLabel.implicitWidth)
            height: Math.ceil(pctUnderLabel.implicitHeight)

            Text {
                id: pctUnderLabel
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: String(batteryGlance.clampedPct)
                color: root.fgPrimary
                font.family: "Google Sans Flex"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.variableAxes: ({ "wght": 620, "wdth": 100 })
                font.features: ({ "tnum": 1 })
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
            }

            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                clip: true
                width: Math.max(0, Math.min(parent.width, batteryGlance.fillWidth - (batteryBody.width - percentageWrap.width) / 2))

                Text {
                    width: percentageWrap.width
                    height: percentageWrap.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: pctUnderLabel.text
                    color: root.batteryOnFillColor
                    font: pctUnderLabel.font
                    renderType: Text.QtRendering
                    antialiasing: true
                    smooth: true
                }
            }
        }

        // Fallback AC cable icon if desktop has no battery
        Text {
            visible: !root.batteryPresent
            anchors.centerIn: parent
            text: "cable"
            color: root.accentColor
            font.family: Theme.fontFamilyIcon
            font.pixelSize: 16
            font.hintingPreference: Font.PreferNoHinting
            font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 16, "wght": 500 })
            renderType: Text.CurveRendering
            antialiasing: true
            smooth: true
        }
    }

    // 4. Active Chrono readouts (only shown when a timer/stopwatch is running)
    BarTimeReadouts {
        Layout.alignment: Qt.AlignVCenter
        onOpenRequested: tab => root.timerOpenRequested(tab)
    }
}
