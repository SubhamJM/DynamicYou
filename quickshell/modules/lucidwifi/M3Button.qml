import QtQuick
import "." as WifiUi

// m3 expressive common button: full-shape at rest, corners morph in under press
Item {
    id: btn

    property string text: ""
    property string variant: "tonal" // "filled" | "tonal" | "outlined" | "text"
    property bool enabled: true
    property bool destructive: false
    // a material symbol name
    property string iconPath: ""
    readonly property color baseColor: {
        if (btn.variant === "filled")
            return btn.destructive ? WifiUi.Theme.error : WifiUi.Theme.accent;

        if (btn.variant === "tonal")
            return btn.destructive ? WifiUi.Theme.errorContainer : WifiUi.Theme.secondaryContainer;

        if (btn.variant === "outlined")
            return btn.destructive ? WifiUi.Theme.alpha(WifiUi.Theme.error, 0.15) : WifiUi.Theme.alpha(WifiUi.Theme.text, 0.08);

        return "transparent";
    }
    readonly property color labelColor: {
        if (btn.variant === "filled")
            return btn.destructive ? WifiUi.Theme.fgError : WifiUi.Theme.fgAccent;

        if (btn.variant === "tonal")
            return btn.destructive ? WifiUi.Theme.fgErrorContainer : WifiUi.Theme.fgSecondaryContainer;

        return btn.destructive ? WifiUi.Theme.error : WifiUi.Theme.text;
    }

    signal clicked()

    implicitHeight: WifiUi.Theme.dp(40)
    implicitWidth: content.implicitWidth + (btn.variant === "text" ? WifiUi.Theme.dp(26) : WifiUi.Theme.dp(46))
    opacity: btn.enabled ? 1 : 0.38
    readonly property bool jellyWobbling: squish.wobbling
    transform: Jelly {
        id: squish

        target: btn
        frequency: 6
    }

    Rectangle {
        anchors.fill: parent
        radius: area.pressed ? WifiUi.Theme.shapeMd : WifiUi.Theme.pill(height)
        color: btn.baseColor

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: btn.labelColor
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

    Row {
        id: content

        anchors.centerIn: parent
        spacing: WifiUi.Theme.dp(8)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.iconPath !== ""
            name: btn.iconPath
            size: WifiUi.Theme.dp(19)
            color: btn.labelColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            color: btn.labelColor
            font.family: WifiUi.Theme.fontFamily
            font.pixelSize: WifiUi.Theme.fontLabelLg
            font.variableAxes: WifiUi.Theme.axes(WifiUi.Theme.fontLabelLg, 520, 0)
            font.weight: Font.Medium
            font.letterSpacing: 0.1

            Behavior on color {
                ColorAnimation {
                    duration: WifiUi.Theme.durShort
                }

            }

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
        onPressedChanged: squish.kick(area.pressed ? -0.1 : 0.08)
    }

    Behavior on opacity {
        NumberAnimation {
            duration: WifiUi.Theme.durShort
        }

    }

}
