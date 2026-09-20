pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: osdModule
    Layout.fillWidth: true
    Layout.fillHeight: true

    // Smooth normalized value interpolation (0 to 100)
    property real animatedValue: root.osdValue
    Behavior on animatedValue {
        NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
    }

    readonly property bool isMuted: root.osdType !== "brightness" && root.osdValue <= 0

    readonly property string feedbackIcon: {
        if (root.osdType === "brightness") return "light_mode";
        if (isMuted) return "volume_off";
        if (animatedValue < 34) return "volume_mute";
        if (animatedValue < 67) return "volume_down";
        return "volume_up";
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 12

        // Left Icon (Iris 1:1 MaterialSymbol with fill: 1)
        MaterialSymbol {
            text: osdModule.feedbackIcon
            iconSize: 18
            fill: 1
            color: osdModule.isMuted ? "#ff6961" : "#f5f5f7"
            Layout.preferredWidth: 20
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Center Scrubber Track (Iris 1:1 6px pill track)
        Item {
            id: trackContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: trackBg
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(255, 255, 255, 0.14)
            }

            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(trackContainer.width, trackContainer.width * (osdModule.isMuted ? 0 : (osdModule.animatedValue / 100.0))))
                clip: true

                Rectangle {
                    width: trackContainer.width
                    height: trackContainer.height
                    radius: height / 2
                    color: osdModule.isMuted ? "#ff6961" : (Theme.colors.accent ?? "#a8c7fa")
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
            }
        }

        // Right Metric / Percentage (Iris 1:1 Tabular text)
        Item {
            Layout.preferredWidth: 38
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: osdModule.isMuted ? "0%" : Math.round(osdModule.animatedValue) + "%"
                font.pixelSize: 13
                font.weight: Font.Bold
                font.features: ({ "tnum": 1 })
                color: osdModule.isMuted ? "#ff6961" : "#f5f5f7"
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }
}
