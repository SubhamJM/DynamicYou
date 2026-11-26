pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import Quickshell.Services.UPower
import "../"

// Matushell Material battery capsule with embedded dual-contrast percentage
// Shared cleanly between resting Dynamic Island glances and expanded hover bar.
Item {
    id: root

    property bool batteryPresent: (typeof Battery !== "undefined" && Battery.available)
        || Boolean(upowerDev && (upowerDev.isLaptopBattery || upowerDev.isPresent))
    property int batteryPct: {
        if (typeof Battery !== "undefined" && Battery.available) return Battery.percent;
        if (upowerDev && upowerDev.percentage !== undefined) {
            return Math.round(Math.max(0, Math.min(1, upowerDev.percentage)) * 100);
        }
        return 100;
    }
    property bool batteryCharging: (typeof Battery !== "undefined" && Battery.available)
        ? Battery.isCharging
        : Boolean(upowerDev && upowerDev.state === UPowerDeviceState.Charging)

    readonly property var upowerDev: (typeof UPower !== "undefined") ? UPower.displayDevice : null
    readonly property color fgPrimary: Theme.colors.text_primary ?? "#f5f5f7"
    readonly property bool isLowBattery: !root.batteryCharging && root.batteryPct < 20
    readonly property color fillColor: root.isLowBattery ? (Theme.colors.error ?? "#ffb4ab") : Theme.accent
    readonly property color onFillColor: root.isLowBattery ? "#101014" : Theme.onAccent

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
        width: root.bodyWidth
        height: root.bodyHeight
        radius: 5
        color: Qt.alpha(root.fgPrimary, 0.22)

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.fillWidth
            color: root.fillColor

            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
    }

    // Right terminal cap when not charging
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
            strokeColor: Theme.accent
            strokeWidth: 1
            fillColor: Theme.accent

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

    // Dual-contrast percentage centered inside battery capsule
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
            text: String(root.clampedPct)
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
            width: Math.max(0, Math.min(parent.width, root.fillWidth - (batteryBody.width - percentageWrap.width) / 2))

            Text {
                width: percentageWrap.width
                height: percentageWrap.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: pctUnderLabel.text
                color: root.onFillColor
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
        color: Theme.accent
        font.family: Theme.fontFamilyIcon
        font.pixelSize: 16
        font.hintingPreference: Font.PreferNoHinting
        font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 16, "wght": 500 })
        renderType: Text.CurveRendering
        antialiasing: true
        smooth: true
    }
}
