import QtQuick
import Quickshell.Widgets
import "../"

Item {
    id: root
    property string source: ""
    property bool circular: true
    property real radius: circular ? width / 2 : 6
    property real decodeSize: 0
    implicitWidth: 24
    implicitHeight: 24

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(1, 1, 1, 0.08)

        Image {
            id: cover
            anchors.fill: parent
            source: root.source
            sourceSize: root.decodeSize > 0 ? Qt.size(Math.ceil(root.decodeSize), Math.ceil(root.decodeSize))
                : Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            smooth: true
            cache: true
        }

        Text {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "󰎆"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: root.width * 0.5
            color: (typeof Theme !== "undefined" && Theme.colors && Theme.colors.accent) ? Theme.colors.accent : "#88c0d0"
        }
    }
}
