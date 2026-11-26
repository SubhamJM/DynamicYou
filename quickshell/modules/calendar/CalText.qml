import QtQuick
import qs

Text {
    property int weightAxis: 540
    property bool tabular: false

    font.family: "Google Sans Flex"
    font.pixelSize: 13
    font.weight: weightAxis >= 640 ? Font.Bold : (weightAxis >= 560 ? Font.DemiBold : (weightAxis >= 480 ? Font.Medium : Font.Normal))
    font.variableAxes: ({ "wght": weightAxis })
    font.features: tabular ? ({ "tnum": 1 }) : ({})
    renderType: Text.QtRendering
    font.hintingPreference: Font.PreferNoHinting
    color: Theme.text
}
