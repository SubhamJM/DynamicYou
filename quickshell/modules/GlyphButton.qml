import QtQuick
import "../"

// Backward-compatible GlyphButton powered by IrisIconButton architecture
IrisIconButton {
    id: root

    property color glyphColor: (typeof Theme !== "undefined" && Theme.colors && Theme.colors.text_primary) ? Theme.colors.text_primary : "#f5f5f7"

    iconColor: glyphColor
    fill: 1
    implicitWidth: 38
    implicitHeight: 38
    buttonSize: 38
}
