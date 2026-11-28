import QtQuick
import "."

// Material Symbols icon text element with variable-font axes.
// Override color, text, font.pixelSize, font.weight, Layout.* as needed.
// Use fill: 1 for filled icons (default 0 = outlined).
// matus-text-keep: icon primitive with FILL/GRAD/opsz axes — not body text, never migrate to MatusText.
Text {
    id: root

    property real fill: 0
    property int grad: Theming.fontIconGrad

    // True while this icon or any ancestor is scaled or rotated (switches to GPU analytic CurveRendering)
    readonly property bool transformed: {
        for (var p = root; p; p = p.parent) {
            if (Math.abs(p.scale - 1.0) > 0.001 || p.rotation % 360 !== 0)
                return true
        }
        return false
    }

    renderType: root.transformed ? Text.CurveRendering : Text.NativeRendering
    antialiasing: true
    smooth: true
    font.family: Theming.fontFamilyIcon
    font.hintingPreference: Font.PreferNoHinting
    font.variableAxes: ({
            "FILL": fill.toFixed(1),
            "GRAD": grad,
            "opsz": fontInfo.pixelSize,
            "wght": fontInfo.weight
        })
}
