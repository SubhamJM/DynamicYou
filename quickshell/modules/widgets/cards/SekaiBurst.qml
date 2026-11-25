import QtQuick
import "../../../"

Item {
    id: root

    property int count: 6
    property real radius: 34
    property real size: 8
    property var colors: [
        Theme.m3.primary ?? "#00e5ff",
        Theme.m3.secondary ?? "#67e8f9",
        "#FFFFFF"
    ]
    property real t: 0

    function fire() {
        anim.restart();
    }

    NumberAnimation {
        id: anim
        target: root
        property: "t"
        from: 0
        to: 1
        duration: 560
        easing.type: Easing.OutCubic
    }

    Repeater {
        model: root.count

        delegate: SekaiDiamond {
            id: bit
            required property int index

            readonly property real angle: bit.index * 2 * Math.PI / root.count - Math.PI / 2 + 0.35
            readonly property real reach: root.radius * (0.65 + 0.35 * ((bit.index * 7) % 5) / 4)

            lit: true
            size: root.size
            litColor: root.colors[bit.index % root.colors.length]
            x: Math.cos(bit.angle) * bit.reach * root.t - bit.width / 2
            y: Math.sin(bit.angle) * bit.reach * root.t - bit.height / 2
            opacity: (root.t <= 0 || root.t >= 1) ? 0 : 1 - root.t * root.t
        }
    }
}
