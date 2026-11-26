import QtQuick
import QtQuick.Effects

Item {
    id: root
    property real radius: 0
    readonly property real lineWidth: 1

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        antialiasing: true
        border.width: root.lineWidth
        border.color: Qt.rgba(1, 1, 1, 0.14)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        antialiasing: true
        border.width: root.lineWidth
        border.color: Qt.rgba(1, 1, 1, 0.34)
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: litFade
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Rectangle {
        id: litFade
        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: "white" }
            GradientStop { position: 0.55; color: "transparent" }
        }
    }
}
