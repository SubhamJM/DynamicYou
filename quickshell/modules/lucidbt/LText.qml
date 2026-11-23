import QtQuick
import "." as BtUi

// text on the m3 type scale. `role` picks size, weight and roundness together
Text {
    id: t

    property string role: "bodyMedium"
    property real weight: BtUi.Theme.typeWeight(t.role)
    property real rounded: BtUi.Theme.typeRound(t.role)
    property int size: BtUi.Theme.typeSize(t.role)
    // fixed-width figures, for anything that counts
    property bool tabular: false

    color: BtUi.Theme.text
    font.family: BtUi.Theme.fontFamily
    font.pixelSize: t.size
    font.weight: t.weight >= 650 ? Font.Bold : t.weight >= 540 ? Font.DemiBold : t.weight >= 470 ? Font.Medium : Font.Normal
    font.variableAxes: BtUi.Theme.axes(t.size, t.weight, t.rounded)
    font.features: t.tabular ? ({ "tnum": 1 }) : ({})
    font.letterSpacing: t.role.indexOf("label") === 0 ? 0.2 : (t.role.indexOf("display") === 0 ? -0.4 : 0)
    verticalAlignment: Text.AlignVCenter
}
