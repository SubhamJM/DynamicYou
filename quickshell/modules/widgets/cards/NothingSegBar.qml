import QtQuick

// Segmented Nothing Glyph pill bar (horizontal or vertical)
Grid {
    id: root

    property int n: 24
    property real f: 0
    property bool vertical: false
    property color onColor: "#F2F2F2"
    property color offColor: "#2A2A2A"
    property color accentHeadColor: "transparent"
    readonly property int lit: Math.round(n * Math.max(0, Math.min(1, f)))

    columns: vertical ? 1 : n
    spacing: 3

    Repeater {
        model: root.n

        Rectangle {
            required property int index
            readonly property int k: root.vertical ? (root.n - 1 - index) : index
            readonly property bool isLit: k < root.lit
            readonly property bool isHead: root.lit > 0 && k === (root.lit - 1) && root.accentHeadColor !== Qt.rgba(0, 0, 0, 0)

            width: root.vertical ? root.width : Math.max(2, (root.width - (root.n - 1) * root.spacing) / Math.max(1, root.n))
            height: root.vertical ? Math.max(2, (root.height - (root.n - 1) * root.spacing) / Math.max(1, root.n)) : root.height
            radius: Math.min(width, height) / 2
            color: isHead && String(root.accentHeadColor) !== "#00000000"
                ? root.accentHeadColor
                : (isLit ? root.onColor : root.offColor)

            Behavior on color {
                ColorAnimation { duration: 100 }
            }
        }
    }
}
