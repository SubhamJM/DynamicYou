
import QtQuick

// A figure that counts: when the text changes, only the characters that
// changed roll, the old one leaving and the new one arriving in the counting
// direction. Sizes and baseline like a Text so it drops into rows that align on baselines.
Item {
    id: root

    property string text: ""
    property string family: "Google Sans Flex"
    property int pixelSize: 14
    property int weight: Font.DemiBold
    property int axisWeight: 560
    property real letterSpacing: 0
    property color color: "#f5f5f7"
    property int renderType: Text.QtRendering
    property bool countDown: false

    implicitWidth: Math.ceil(row.implicitWidth)
    implicitHeight: Math.ceil(probe.implicitHeight)
    baselineOffset: Math.round(probe.baselineOffset)

    Text {
        id: probe
        visible: false
        text: "0"
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.variableAxes: root.family === "Google Sans Flex" ? ({ "wght": root.axisWeight, "wdth": 100 }) : ({})
        font.features: ({ "tnum": 1 })
        font.hintingPreference: Font.PreferNoHinting
        renderType: root.renderType
    }

    component Glyph: Text {
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.variableAxes: root.family === "Google Sans Flex" ? ({ "wght": root.axisWeight, "wdth": 100 }) : ({})
        font.letterSpacing: root.letterSpacing
        font.features: ({ "tnum": 1 })
        font.hintingPreference: Font.PreferNoHinting
        antialiasing: true
        smooth: true
        color: root.color
        renderType: root.renderType
    }

    Row {
        id: row
        spacing: 0
        Repeater {
            model: root.text.length
            Item {
                id: slot
                required property int index
                readonly property string character: root.text.charAt(slot.index)
                property real roll: 1
                property string previous: ""
                width: Math.ceil(Math.max(current.implicitWidth, slot.roll < 1 ? leaving.implicitWidth : 0))
                height: probe.implicitHeight
                clip: true

                onCharacterChanged: {
                    const old = current.shown
                    current.shown = slot.character
                    if (rollAnimation.running) rollAnimation.stop()
                    slot.previous = old
                    slot.roll = 0
                    rollAnimation.start()
                }

                readonly property real travel: slot.height * 0.7 * (root.countDown ? -1 : 1)

                Glyph {
                    id: leaving
                    text: slot.previous
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -slot.travel * slot.roll
                    opacity: 1 - slot.roll
                }
                Glyph {
                    id: current
                    property string shown: ""
                    Component.onCompleted: current.shown = slot.character
                    text: slot.character
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: slot.travel * (1 - slot.roll)
                    opacity: slot.roll
                }

                NumberAnimation {
                    id: rollAnimation
                    target: slot
                    property: "roll"
                    to: 1
                    duration: 220
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
                }
            }
        }
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text
}
