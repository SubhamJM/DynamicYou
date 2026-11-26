import QtQuick

Item {
    id: root

    property real level: 0
    property color tint: "#ffffff"
    property color frame: Qt.rgba(1, 1, 1, 0.56)
    property int markHeight: 11

    readonly property int line: Math.max(1, Math.round(root.markHeight / 10))
    readonly property int inset: root.line * 2
    readonly property int terminal: Math.max(2, Math.round(root.markHeight / 5))

    implicitHeight: root.markHeight
    implicitWidth: Math.round(root.markHeight * 2.1)

    Rectangle {
        id: body
        width: root.width - root.terminal - root.line
        height: root.height
        radius: Math.round(root.height * 0.3)
        color: "transparent"
        border.width: root.line
        border.color: root.frame

        Rectangle {
            readonly property int room: body.width - 2 * root.inset
            x: root.inset
            y: root.inset
            height: body.height - 2 * root.inset
            width: root.level <= 0 ? 0 : Math.max(2 * root.line, Math.round(room * Math.min(1, root.level)))
            radius: Math.max(1, body.radius - root.inset)
            color: root.tint
        }
    }

    Rectangle {
        x: body.width + root.line
        anchors.verticalCenter: body.verticalCenter
        width: root.terminal
        height: Math.round(root.height * 0.4)
        radius: Math.round(width / 2)
        color: root.frame
    }
}
