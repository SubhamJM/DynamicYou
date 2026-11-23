import QtQuick
import "." as BtUi

// m3 switch: the thumb grows when on and again under press, and carries a check
Item {
    id: sw

    property bool checked: false
    property bool disabled: false
    property bool icons: true

    signal toggled(bool value)

    implicitWidth: BtUi.Theme.dp(48)
    implicitHeight: BtUi.Theme.dp(28)
    opacity: sw.disabled ? BtUi.Theme.disabledContent : 1

    Rectangle {
        id: track

        anchors.fill: parent
        radius: BtUi.Theme.pill(height)
        color: sw.checked ? BtUi.Theme.primary : BtUi.Theme.bgSunken
        border.width: sw.checked ? 0 : 2
        border.color: BtUi.Theme.outlineStrong

        Behavior on color {
            ColorAnimation {
                duration: BtUi.Theme.durDefaultEffects
            }

        }

    }

    Rectangle {
        id: thumb

        property real d: area.pressed && !sw.disabled ? BtUi.Theme.dp(26) : (sw.checked || sw.icons ? BtUi.Theme.dp(22) : BtUi.Theme.dp(14))
        // the travel eases on its own; an eased x that also followed the easing
        // size restarted every frame and sat still until the size had settled
        property real pos: sw.checked ? 1 : 0

        width: thumb.d
        height: thumb.d
        radius: thumb.d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: BtUi.Theme.dp(3) + (BtUi.Theme.dp(22) - thumb.d) / 2 + thumb.pos * (sw.width - BtUi.Theme.dp(28))
        color: sw.checked ? BtUi.Theme.fgPrimary : BtUi.Theme.outlineStrong
        readonly property bool jellyWobbling: thumbJelly.wobbling
        // drawn out like a drop as it slides, then wobbling where it lands
        transform: Jelly {
            id: thumbJelly

            target: thumb
            frequency: 5
        }

        Behavior on pos {
            NumberAnimation {
                duration: BtUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: BtUi.Theme.curveFastSpatial
            }

        }

        Behavior on d {
            NumberAnimation {
                duration: BtUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: BtUi.Theme.curveDefaultSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: BtUi.Theme.durDefaultEffects
            }

        }

        Rectangle {
            anchors.centerIn: parent
            width: BtUi.Theme.dp(38)
            height: BtUi.Theme.dp(38)
            radius: BtUi.Theme.dp(19)
            color: sw.checked ? BtUi.Theme.primary : BtUi.Theme.text
            opacity: sw.disabled ? 0 : (area.pressed ? BtUi.Theme.statePressed : (area.containsMouse ? BtUi.Theme.stateHover : 0))
        }

        Icon {
            anchors.centerIn: parent
            visible: sw.icons
            name: sw.checked ? "check" : "close"
            size: BtUi.Theme.dp(15)
            weight: 600
            color: sw.checked ? BtUi.Theme.fgPrimaryContainer : BtUi.Theme.surfaceHighest
            opacity: sw.checked ? 1 : 0.9
        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -BtUi.Theme.dp(4)
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
