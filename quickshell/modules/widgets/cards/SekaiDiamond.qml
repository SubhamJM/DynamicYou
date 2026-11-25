import QtQuick
import "../../../"

Rectangle {
    id: root

    property bool lit: false
    property color litColor: Theme.m3.secondary ?? "#67e8f9"
    property color offColor: Qt.alpha(Theme.m3.on_surface ?? "#e0f8ff", 0.25)
    property color lineColor: Qt.darker(Theme.m3.surface_container_lowest ?? "#030a16", 1.35)
    property real size: 11
    property real pop: 1

    width: root.size
    height: root.size
    radius: Math.max(2, root.size * 0.25)
    rotation: 45
    scale: root.pop
    color: root.lit ? root.litColor : root.offColor
    border.width: 2
    border.color: root.lineColor
    antialiasing: true

    Behavior on color { ColorAnimation { duration: 140 } }

    onLitChanged: {
        if (root.lit) root.bump();
    }

    function bump() {
        bumpAnim.restart();
    }

    NumberAnimation {
        id: bumpAnim
        target: root
        property: "pop"
        from: 1.7
        to: 1
        duration: 360
        easing.type: Easing.OutBack
        easing.overshoot: 2.2
    }
}
