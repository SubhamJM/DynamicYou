import QtQuick
import "." as WifiUi

// text on the m3 type scale. `role` picks size, weight and roundness together
Text {
    id: t

    property string role: "bodyMedium"
    property real weight: WifiUi.Theme.typeWeight(t.role)
    property real rounded: WifiUi.Theme.typeRound(t.role)
    property int size: WifiUi.Theme.typeSize(t.role)
    // fixed-width figures, for anything that counts
    property bool tabular: false

    color: WifiUi.Theme.text
    font.family: WifiUi.Theme.fontFamily
    font.pixelSize: t.size
    font.weight: t.weight >= 650 ? Font.Bold : t.weight >= 540 ? Font.DemiBold : t.weight >= 470 ? Font.Medium : Font.Normal
    font.variableAxes: WifiUi.Theme.axes(t.size, t.weight, t.rounded)
    font.features: t.tabular ? ({ "tnum": 1 }) : ({})
    font.letterSpacing: t.role.indexOf("label") === 0 ? 0.2 : (t.role.indexOf("display") === 0 ? -0.4 : 0)
    verticalAlignment: Text.AlignVCenter
}
