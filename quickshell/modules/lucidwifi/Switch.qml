import QtQuick
import "." as WifiUi

// m3 switch: the thumb grows when on and again under press, and carries a check
Item {
    id: sw

    property bool checked: false
    property bool disabled: false
    property bool icons: true

    signal toggled(bool value)

    implicitWidth: WifiUi.Theme.dp(48)
    implicitHeight: WifiUi.Theme.dp(28)
    opacity: sw.disabled ? WifiUi.Theme.disabledContent : 1

    Rectangle {
        id: track

        anchors.fill: parent
        radius: WifiUi.Theme.pill(height)
        color: sw.checked ? WifiUi.Theme.primary : WifiUi.Theme.bgSunken
        border.width: sw.checked ? 0 : 2
        border.color: WifiUi.Theme.outlineStrong

        Behavior on color {
            ColorAnimation {
                duration: WifiUi.Theme.durDefaultEffects
            }

        }

    }

    Rectangle {
        id: thumb

        property real d: area.pressed && !sw.disabled ? WifiUi.Theme.dp(26) : (sw.checked || sw.icons ? WifiUi.Theme.dp(22) : WifiUi.Theme.dp(14))
        // the travel eases on its own; an eased x that also followed the easing
        // size restarted every frame and sat still until the size had settled
        property real pos: sw.checked ? 1 : 0

        width: thumb.d
        height: thumb.d
        radius: thumb.d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: WifiUi.Theme.dp(3) + (WifiUi.Theme.dp(22) - thumb.d) / 2 + thumb.pos * (sw.width - WifiUi.Theme.dp(28))
        color: sw.checked ? WifiUi.Theme.fgPrimary : WifiUi.Theme.outlineStrong
        readonly property bool jellyWobbling: thumbJelly.wobbling
        // drawn out like a drop as it slides, then wobbling where it lands
        transform: Jelly {
            id: thumbJelly

            target: thumb
            frequency: 5
        }

        Behavior on pos {
            NumberAnimation {
                duration: WifiUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: WifiUi.Theme.curveFastSpatial
            }

        }

        Behavior on d {
            NumberAnimation {
                duration: WifiUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: WifiUi.Theme.curveDefaultSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: WifiUi.Theme.durDefaultEffects
            }

        }

        Rectangle {
            anchors.centerIn: parent
            width: WifiUi.Theme.dp(38)
            height: WifiUi.Theme.dp(38)
            radius: WifiUi.Theme.dp(19)
            color: sw.checked ? WifiUi.Theme.primary : WifiUi.Theme.text
            opacity: sw.disabled ? 0 : (area.pressed ? WifiUi.Theme.statePressed : (area.containsMouse ? WifiUi.Theme.stateHover : 0))
        }

        Icon {
            anchors.centerIn: parent
            visible: sw.icons
            name: sw.checked ? "check" : "close"
            size: WifiUi.Theme.dp(15)
            weight: 600
            color: sw.checked ? WifiUi.Theme.fgPrimaryContainer : WifiUi.Theme.surfaceHighest
            opacity: sw.checked ? 1 : 0.9
        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -WifiUi.Theme.dp(4)
        hoverEnabled: true
        enabled: !sw.disabled
        cursorShape: Qt.PointingHandCursor
        // the caller owns `checked`; assigning it here would cut their binding
        onClicked: {
            thumbJelly.kick(-0.17);
            sw.toggled(!sw.checked);
        }
    }

}
