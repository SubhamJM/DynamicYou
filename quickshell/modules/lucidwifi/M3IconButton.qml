import QtQuick
import "." as WifiUi

// m3 expressive icon button: round at rest, morphs square-ish under press
Item {
    id: btn

    property string variant: "standard" // "standard" | "tonal" | "filled" | "outlined"
    property int size: WifiUi.Theme.dp(40)
    property int iconSize: Math.round(btn.size * 0.55)
    // a material symbol name
    property string iconPath: ""
    property bool enabled: true
    property bool destructive: false
    readonly property color baseColor: {
        if (btn.variant === "filled")
            return btn.destructive ? WifiUi.Theme.error : WifiUi.Theme.accent;

        if (btn.variant === "tonal")
            return btn.destructive ? WifiUi.Theme.errorContainer : WifiUi.Theme.secondaryContainer;

        return "transparent";
    }
    readonly property color fgColor: {
        if (btn.variant === "filled")
            return btn.destructive ? WifiUi.Theme.fgError : WifiUi.Theme.fgAccent;

        if (btn.variant === "tonal")
            return btn.destructive ? WifiUi.Theme.fgErrorContainer : WifiUi.Theme.fgSecondaryContainer;

        return btn.destructive ? WifiUi.Theme.error : (area.containsMouse ? WifiUi.Theme.text : WifiUi.Theme.subtext);
    }

    signal clicked()

    implicitWidth: btn.size
    implicitHeight: btn.size
    opacity: btn.enabled ? 1 : 0.38
    readonly property bool jellyWobbling: squish.wobbling
    transform: Jelly {
        id: squish

        target: btn
        frequency: 6.5
    }

    Rectangle {
        id: container

        anchors.fill: parent
        // shape morph: full -> medium while held
        radius: area.pressed ? WifiUi.Theme.shapeMd : WifiUi.Theme.pill(btn.size)
        color: btn.baseColor
        border.width: btn.variant === "outlined" ? 1 : 0
        border.color: WifiUi.Theme.outlineStrong

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: btn.fgColor
            opacity: !btn.enabled ? 0 : (area.pressed ? WifiUi.Theme.statePressed : (area.containsMouse ? WifiUi.Theme.stateHover : 0))

            Behavior on opacity {
                NumberAnimation {
                    duration: WifiUi.Theme.durQuick
                }

            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: WifiUi.Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: WifiUi.Theme.curveDefaultSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: WifiUi.Theme.durShort
            }

        }

    }

    Icon {
        anchors.centerIn: parent
        name: btn.iconPath
        size: Math.round(btn.iconSize * 1.08)
        color: btn.fgColor
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
        onPressedChanged: squish.kick(area.pressed ? -0.12 : 0.09)
    }

    Behavior on opacity {
        NumberAnimation {
            duration: WifiUi.Theme.durShort
        }

    }

}
