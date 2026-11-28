pragma ComponentBehavior: Bound

import QtQuick
import "."

// Standardized styled text primitive for all UI labels across Matushell.
// Encapsulates Google Sans Flex variable font axes (wght/wdth), default colors,
// and auto-scaling font size tokens.
Text {
    id: root

    // --- Public API ---
    enum Weight {
        Light,
        Regular,
        Medium,
        DemiBold,
        Bold
    }

    property int weight: MatusText.Weight.Regular
    property alias size: root.font.pixelSize
    property alias features: root.font.features
    property var axes: null

    // Tracked outside the font group: a binding that reads font.* while writing
    // font.variableAxes depends on its own write (fontChanged) -> binding loop.
    property string family: Theming.fontFamily

    // True while this text or any ancestor is scaled or rotated (switches to distance-field QtRendering)
    readonly property bool transformed: {
        for (var p = root; p; p = p.parent) {
            if (Math.abs(p.scale - 1.0) > 0.001 || p.rotation % 360 !== 0)
                return true
        }
        return false
    }

    // --- Helper Functions ---
    function resolvedAxes() {
        if (axes !== null)
            return axes

        // Non-variable families (mono/nerd/icon): empty map clears Flex axes
        // without tripping a binding error from an undefined QVariantMap.
        if (family !== Theming.fontFamily)
            return ({})

        switch (weight) {
        case MatusText.Weight.Light:
            return Theming.fontAxesLight
        case MatusText.Weight.Regular:
            return Theming.fontAxesRegular
        case MatusText.Weight.Medium:
            return Theming.fontAxesMedium
        case MatusText.Weight.DemiBold:
            return Theming.fontAxesDemiBold
        case MatusText.Weight.Bold:
            return Theming.fontAxesBold
        default:
            return Theming.fontAxesRegular
        }
    }

    function resolvedWeight() {
        switch (weight) {
        case MatusText.Weight.Light:
            return Theming.fontWeightLight
        case MatusText.Weight.Regular:
            return Theming.fontWeightNormal
        case MatusText.Weight.Medium:
            return Theming.fontWeightMedium
        case MatusText.Weight.DemiBold:
            return Theming.fontWeightDemiBold
        case MatusText.Weight.Bold:
            return Theming.fontWeightBold
        default:
            return Theming.fontWeightNormal
        }
    }

    // --- Layout & Styling ---
    renderType: root.transformed ? Text.QtRendering : Text.NativeRendering
    antialiasing: true
    smooth: true
    verticalAlignment: Text.AlignVCenter
    font.family: root.family
    font.pixelSize: Theming.fontSizeSmall
    font.variableAxes: resolvedAxes()
    font.weight: resolvedWeight()
    color: Theming.surfaceOn
    linkColor: Theming.primary
}
