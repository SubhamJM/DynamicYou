import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../"

Item {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool isReady: battery != null && battery.isPresent && battery.percentage !== undefined
    readonly property real percentage: isReady ? battery.percentage : 1.0
    readonly property int batteryLevel: Math.round(percentage * 100)
    readonly property bool isCharging: battery && (battery.state === UPowerDevice.Charging || battery.state === UPowerDevice.PendingCharge)
    readonly property bool isFullyCharged: battery && battery.state === UPowerDevice.FullyCharged
    readonly property bool isLow: isReady && batteryLevel <= 20 && !isCharging

    readonly property color chargeColor: "#34d399"
    readonly property color lowColor: "#ff5449"
    readonly property color normalColor: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
    readonly property color fillColor: root.isCharging ? root.chargeColor : (root.isLow ? root.lowColor : (Theme.colors.text_primary ?? "#ffffff"))

    implicitWidth: mainRow.implicitWidth
    implicitHeight: 22

    Row {
        id: mainRow
        anchors.centerIn: parent
        spacing: 6

        // Drawn battery outline and fill, independent of icon fonts.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 25
            height: 14

            Rectangle {
                x: 0
                y: 1
                width: 22
                height: 13
                radius: 4
                color: Theme.alpha(root.fillColor, 0.13)
                border.width: 1
                border.color: Theme.alpha(root.fillColor, 0.55)

                Rectangle {
                    x: 2
                    y: 2
                    height: 9
                    width: root.isCharging ? 18 : root.isReady ? Math.max(0, Math.min(18, 18 * root.percentage)) : 0
                    radius: 2
                    color: root.fillColor
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }
            Rectangle {
                x: 22.5
                y: 5
                width: 2
                height: 5
                radius: 1
                color: Theme.alpha(root.fillColor, 0.55)
            }
            Canvas {
                id: chargeBolt
                x: 7
                y: 2.5
                width: 8
                height: 10
                visible: root.isCharging
                onVisibleChanged: requestPaint()
                Connections { target: root; function onFillColorChanged() { chargeBolt.requestPaint(); } }
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "#12392c";
                    ctx.beginPath();
                    ctx.moveTo(4.5, 0.5);
                    ctx.lineTo(1.5, 5.5);
                    ctx.lineTo(3.8, 5.5);
                    ctx.lineTo(3.3, 9.5);
                    ctx.lineTo(6.5, 4.3);
                    ctx.lineTo(4.2, 4.3);
                    ctx.closePath();
                    ctx.fill();
                }
            }
        }

        // Tabular Percentage Text
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (root.isReady ? root.batteryLevel : "--") + "%"
            font.family: (typeof Theme !== "undefined" && Theme.fontFamily) ? Theme.fontFamily : "Noto Sans"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            color: root.fillColor
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferVerticalHinting
        }
    }
}
