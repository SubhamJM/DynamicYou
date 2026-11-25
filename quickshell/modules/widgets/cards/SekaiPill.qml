import QtQuick
import "../../../"
import "../"

// Sekai Pop three-layer raised container primitive: hard offset shadow, crisp border outline,
// inner light/surface ring, and keycap press spring. Scaled by WidgetStore.s() so widgets stay 1.0x.
Item {
    id: root

    property color fillColor: Theme.m3.surface_container_high ?? Theme.colors.card_bg
    property Gradient fillGradient: null
    property color outlineColor: Qt.darker(Theme.m3.surface_container_lowest ?? "#030a16", 1.35)
    property color ringColor: Qt.alpha(Theme.m3.on_surface ?? "#e0f8ff", 0.14)
    property color shadowColor: Qt.darker(Theme.m3.surface_container_lowest ?? "#030a16", 1.55)

    property real cornerRadius: WidgetStore.s(16)
    property real borderWidth: WidgetStore.s(2.5)
    property real ringWidth: WidgetStore.s(3)
    property real shadowDx: 0
    property real shadowDy: WidgetStore.s(4)
    property bool pressed: false
    property bool flat: false

    readonly property real capWidth: Math.max(1, width - shadowDx)
    readonly property real capHeight: Math.max(1, height - shadowDy)
    default property alias content: fill.data

    // Hard offset drop shadow (zero blur halo)
    Rectangle {
        visible: !root.flat && (root.shadowDx > 0 || root.shadowDy > 0)
        x: root.shadowDx
        y: root.shadowDy
        width: root.capWidth
        height: root.capHeight
        radius: root.cornerRadius
        color: root.shadowColor
        antialiasing: true
    }

    // Raised body that presses down onto the shadow
    Item {
        id: surface
        x: root.pressed && !root.flat ? root.shadowDx : 0
        y: root.pressed ? (root.flat ? WidgetStore.s(1) : root.shadowDy) : 0
        width: root.capWidth
        height: root.capHeight

        Behavior on x {
            NumberAnimation {
                duration: root.pressed ? 80 : 240
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.0
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.pressed ? 80 : 240
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.0
            }
        }

        // Outer border + inner ring frame
        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: root.ringColor
            border.width: root.borderWidth
            border.color: root.outlineColor
            antialiasing: true

            Rectangle {
                id: fill
                anchors.fill: parent
                anchors.margins: root.ringWidth
                radius: Math.max(WidgetStore.s(2), root.cornerRadius - root.ringWidth)
                color: root.fillColor
                gradient: root.fillGradient
                clip: true
                antialiasing: true

                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }
}
