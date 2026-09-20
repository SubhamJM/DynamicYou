import QtQuick
import QtQuick.Effects

Item {
    id: root
    property string source: ""
    property real radius: 26
    property real strength: 0.55

    readonly property real overscan: 32

    Image {
        id: cover
        anchors.fill: parent
        anchors.margins: -root.overscan
        source: root.source
        sourceSize: Qt.size(160, 160)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    Item {
        id: composed
        anchors.fill: parent
        layer.enabled: root.radius > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: roundMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        MultiEffect {
            anchors.fill: parent
            anchors.margins: -root.overscan
            source: cover
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            opacity: root.strength
            visible: cover.status === Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.08, 0.08, 0.09, 0.72) }
                GradientStop { position: 1.0; color: Qt.rgba(0.08, 0.08, 0.09, 0.88) }
            }
        }
    }

    Item {
        id: roundMask
        anchors.fill: parent
        visible: false
        layer.enabled: root.radius > 0
        Rectangle {
            anchors.fill: parent
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: root.radius
            bottomRightRadius: root.radius
        }
    }
}
