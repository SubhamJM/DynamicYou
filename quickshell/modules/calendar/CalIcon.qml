import QtQuick
import qs

Text {
    property bool filled: false
    property int weightAxis: 500

    font.family: Theme.fontFamilyIcon
    font.pixelSize: 18
    font.variableAxes: ({
        "FILL": filled ? 1 : 0,
        "GRAD": Theme.fontIconGrad,
        "opsz": 24,
        "wght": weightAxis
    })
    renderType: Text.CurveRendering
    font.hintingPreference: Font.PreferNoHinting
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    color: Theme.text
}
