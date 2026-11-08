import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../"

// ────────────────────────────────────────────────────────────
// Lucid Battery Architecture & Design (1:1 with Lucid BatteryPill.qml)
// Horizontal battery with dual-clipped percentage inside the fill,
// battery terminal nipple, and dynamic charging indicator.
// ────────────────────────────────────────────────────────────
Item {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool isReady: battery != null && (battery.percentage !== undefined && battery.percentage > 0)
    readonly property real percentage: isReady ? battery.percentage : 1.0
    readonly property int batteryLevel: Math.round(percentage * 100)
    readonly property bool isCharging: battery && (battery.state === UPowerDevice.Charging || battery.state === UPowerDevice.FullyCharged)
    readonly property bool isFullyCharged: battery && battery.state === UPowerDevice.FullyCharged
    readonly property bool isLow: isReady && batteryLevel <= 20 && !isCharging

    readonly property color chargeColor: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#30d158"
    readonly property color fillColor: root.isCharging ? root.chargeColor : (root.isLow ? "#ff453a" : "#ffffff")
    readonly property color emptyColor: Qt.rgba(255, 255, 255, 0.22)
    readonly property real level: Math.max(0, Math.min(1, root.percentage))

    implicitWidth: mainRow.implicitWidth
    implicitHeight: 16

    Row {
        id: mainRow
        anchors.centerIn: parent
        spacing: 4

        // Bolt glyph when plugged in / charging (Lucid style)
        MaterialSymbol {
            visible: root.isCharging
            anchors.verticalCenter: parent.verticalCenter
            text: "bolt"
            iconSize: 14
            fill: 1
            color: root.fillColor

            SequentialAnimation on opacity {
                running: root.isCharging && !root.isFullyCharged
                loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: 800; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
            }
        }

        // Horizontal Battery Capsule (Lucid 1:1)
        Item {
            id: bp
            width: 35
            height: 15
            anchors.verticalCenter: parent.verticalCenter

            // Main battery cell body
            Item {
                id: body
                width: bp.width - 3
                height: bp.height

                // Unfilled track background
                Rectangle {
                    anchors.fill: parent
                    radius: 4.5
                    color: root.emptyColor
                }

                // Filled portion with clipped dark text
                Item {
                    id: fillClip
                    width: Math.max(2, Math.round(body.width * root.level))
                    height: body.height
                    clip: true

                    Rectangle {
                        width: body.width
                        height: body.height
                        radius: 4.5
                        color: root.fillColor

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        width: body.width
                        height: body.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 10
                        font.bold: true
                        text: root.isReady ? root.batteryLevel : "--"
                        color: "#121214"
                        renderType: Text.NativeRendering
                    }
                }

                // Unfilled portion with clipped light text
                Item {
                    x: fillClip.width
                    width: Math.max(0, body.width - fillClip.width)
                    height: body.height
                    clip: true

                    Text {
                        x: -fillClip.width
                        width: body.width
                        height: body.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                        font.pixelSize: 10
                        font.bold: true
                        text: root.isReady ? root.batteryLevel : "--"
                        color: "#ffffff"
                        renderType: Text.NativeRendering
                    }
                }
            }

            // Terminal cathode nipple on the right (Lucid 1:1)
            Rectangle {
                anchors.left: body.right
                anchors.leftMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 6
                radius: 1
                color: root.level >= 0.98 ? root.fillColor : root.emptyColor
            }
        }
    }
}
