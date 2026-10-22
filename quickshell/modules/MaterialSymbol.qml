import QtQuick
import "../"

// Material Symbols variable-font icon primitive inspired by Matushell
// Supports variable axes (FILL, GRAD grade compensation, opsz optical sizing, wght weight),
// native rendering, PreferNoHinting, and automatic Nerd Font fallback.
Text {
    id: root

    property real iconSize: (typeof Theme !== "undefined" && Theme.iconSize) ? Theme.iconSize : 18
    property real fill: 0
    property int grad: (typeof Theme !== "undefined" && Theme.fontIconGrad !== undefined) ? Theme.fontIconGrad : -25
    color: (typeof Theme !== "undefined" && Theme.colors && Theme.colors.text_primary) ? Theme.colors.text_primary : "#f5f5f7"

    readonly property bool isNerd: text.length > 0 && text.charCodeAt(0) >= 0xE000

    font.family: isNerd
        ? ((typeof Theme !== "undefined" && Theme.fontFamilyNerd) ? Theme.fontFamilyNerd : "JetBrainsMono Nerd Font")
        : ((typeof Theme !== "undefined" && Theme.fontFamilyIcon) ? Theme.fontFamilyIcon : "Material Symbols Rounded")
    font.pixelSize: iconSize
    font.hintingPreference: Font.PreferNoHinting
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    font.variableAxes: isNerd ? ({}) : ({
        "FILL": Number(fill).toFixed(1),
        "GRAD": grad,
        "opsz": fontInfo.pixelSize > 0 ? fontInfo.pixelSize : iconSize,
        "wght": fontInfo.weight > 0 ? fontInfo.weight : 400
    })

    Behavior on color {
        ColorAnimation { duration: (typeof Theme !== "undefined" && Theme.animFast) ? Theme.animFast : 100 }
    }
}
