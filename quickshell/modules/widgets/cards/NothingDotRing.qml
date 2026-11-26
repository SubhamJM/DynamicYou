import QtQuick
import "../"

// Circular Nothing OS LED dot ring (lit clockwise from 12 o'clock with staggered wave)
Item {
    id: root

    property int n: 32
    property real f: 0
    property real dot: WidgetStore.s(4.6)
    property color onColor: "#F2F2F2"
    property color offColor: "#2A2A2A"
    readonly property int lit: Math.round(n * Math.max(0, Math.min(1, f)))

    Repeater {
        model: root.n

        Rectangle {
            required property int index
            readonly property real angle: index / root.n * 2 * Math.PI - Math.PI / 2
            readonly property real ringRadius: Math.max(2, Math.min(root.width, root.height) / 2 - root.dot / 2)

            x: root.width / 2 + ringRadius * Math.cos(angle) - width / 2
            y: root.height / 2 + ringRadius * Math.sin(angle) - height / 2
            width: root.dot
            height: root.dot
            radius: root.dot / 2
            color: index < root.lit ? root.onColor : root.offColor

            Behavior on color {
                SequentialAnimation {
                    PauseAnimation { duration: Math.min(160, index * 5) }
                    ColorAnimation { duration: 130 }
                }
            }
        }
    }
}
