import QtQuick
import qs

Text {
    property int weightAxis: 420
    property bool tabular: false
    readonly property int softWeight: Math.min(480, Math.max(350, weightAxis))

    font.family: "Google Sans Flex"
    font.pixelSize: 13
    font.weight: Font.Normal
    font.variableAxes: ({ "wght": softWeight })
    font.features: tabular ? ({ "tnum": 1 }) : ({})
    renderType: Text.QtRendering
    font.hintingPreference: Font.PreferNoHinting
    color: Theme.text
}
