pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../"

// Matushell OsdProgress-style progress HUD (Volume & Brightness)
Item {
    id: osdModule
    Layout.fillWidth: true
    Layout.fillHeight: true

    property real animatedValue: root.osdValue
    Behavior on animatedValue {
        NumberAnimation { duration: 140; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial ?? [0.38, 1.21, 0.22, 1, 1, 1] }
    }

    readonly property bool isMuted: root.osdType !== "brightness" && root.osdValue <= 0
    readonly property real progressFrac: isMuted ? 0 : Math.max(0, Math.min(1, animatedValue / 100.0))
    readonly property color activeColor: isMuted ? (Theme.colors.error ?? "#ffb4ab") : Theme.accent
    readonly property color fgPrimary: Theme.colors.text_primary ?? "#f5f5f7"

    readonly property string feedbackIcon: {
        if (root.osdType === "brightness") {
            return animatedValue > 60 ? "brightness_high" : animatedValue > 25 ? "brightness_medium" : "brightness_low";
        }
        if (isMuted) return "volume_off";
        if (animatedValue <= 0) return "volume_mute";
        if (animatedValue < 50) return "volume_down";
        return "volume_up";
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 10

        // Left Material Symbols Rounded glyph (CurveRendering for vector sharpness)
        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 22
            text: osdModule.feedbackIcon
            color: osdModule.isMuted ? (Theme.colors.error ?? "#ffb4ab") : osdModule.fgPrimary
            font.family: Theme.fontFamilyIcon
            font.pixelSize: 20
            font.hintingPreference: Font.PreferNoHinting
            font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
            renderType: Text.CurveRendering
            antialiasing: true
            smooth: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Center MatusSlider XXS track: active pill + vertical pill handle + inactive track + endDot
        Item {
            id: sliderTrack
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter

            readonly property int trackHeight: 10
            readonly property int handleWidth: 5
            readonly property int handleGap: 3
            readonly property real usableWidth: Math.max(1, width - handleGap * 2)
            readonly property real handleCenter: handleGap + (osdModule.progressFrac * usableWidth)
            readonly property real filledWidth: Math.max(0, handleCenter - (handleWidth / 2 + handleGap))
            readonly property real emptyWidth: Math.max(0, (width - handleCenter) - (handleWidth / 2 + handleGap))
            readonly property real remainingOpacity: Math.max(0, Math.min(1, (1 - osdModule.progressFrac) / 0.08))

            // Active left segment
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: sliderTrack.filledWidth
                height: sliderTrack.trackHeight
                topLeftRadius: height / 2
                bottomLeftRadius: height / 2
                topRightRadius: 2
                bottomRightRadius: 2
                color: osdModule.activeColor
                visible: width > 1

                Behavior on color { ColorAnimation { duration: 140 } }
            }

            // Inactive right segment
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: sliderTrack.emptyWidth
                height: sliderTrack.trackHeight
                topLeftRadius: 2
                bottomLeftRadius: 2
                topRightRadius: height / 2
                bottomRightRadius: height / 2
                color: Qt.alpha(osdModule.fgPrimary, 0.16)
                visible: width > 1

                // Matushell M3 end stop dot
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(4 * sliderTrack.remainingOpacity)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(4 * sliderTrack.remainingOpacity)
                    height: width
                    radius: width / 2
                    color: osdModule.activeColor
                    opacity: sliderTrack.remainingOpacity
                    visible: opacity > 0.05
                }
            }

            // Vertical M3 capsule handle
            Rectangle {
                x: Math.max(0, Math.min(parent.width - width, sliderTrack.handleCenter - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: sliderTrack.handleWidth
                height: 18
                radius: width / 2
                color: osdModule.activeColor

                Behavior on color { ColorAnimation { duration: 140 } }
            }
        }

        // Right Metric / Mute label in crisp Google Sans Flex
        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: 36
            horizontalAlignment: Text.AlignRight
            text: osdModule.isMuted ? "Mute" : (Math.round(osdModule.animatedValue) + "%")
            color: osdModule.isMuted ? (Theme.colors.error ?? "#ffb4ab") : osdModule.fgPrimary
            font.family: "Google Sans Flex"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.variableAxes: ({ "wght": 560, "wdth": 100 })
            font.features: ({ "tnum": 1 })
            font.hintingPreference: Font.PreferNoHinting
            renderType: Text.QtRendering
            antialiasing: true
            smooth: true

            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }
}
