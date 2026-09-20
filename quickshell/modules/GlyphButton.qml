import QtQuick
import "../"

Item {
    id: root
    property string glyph: ""
    property real glyphSize: 22
    property real fill: 1
    property color glyphColor: "#f5f5f7"
    property real buttonRadius: height / 2
    property color backgroundColor: "transparent"
    property color backgroundHoverColor: Qt.rgba(255, 255, 255, 0.12)
    property color backgroundPressedColor: Qt.rgba(255, 255, 255, 0.20)
    property bool enabled: true

    signal clicked()

    implicitWidth: 38
    implicitHeight: 38

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.buttonRadius
        color: !root.enabled ? "transparent"
            : mouseArea.pressed ? root.backgroundPressedColor
            : mouseArea.containsMouse ? root.backgroundHoverColor
            : root.backgroundColor
        scale: mouseArea.pressed ? 0.93 : 1.0
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: root.glyph
            iconSize: root.glyphSize
            fill: root.fill
            color: root.enabled ? root.glyphColor : Qt.rgba(255, 255, 255, 0.3)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
