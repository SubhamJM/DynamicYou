import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs
import qs.lucidui as Lucid

Controls.Button {
    id: control
    required property string glyph
    property bool scanning: false
    property string actionLabel: ""

    implicitHeight: 36
    leftPadding: 10
    rightPadding: 10
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    Accessible.name: actionLabel || text

    background: Rectangle {
        radius: 10
        color: Theme.alpha(control.scanning ? Theme.accent : Theme.text,
            control.down ? 0.16 : control.hovered || control.scanning || control.visualFocus ? 0.10 : 0.055)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    contentItem: RowLayout {
        spacing: 8

        Lucid.Icon {
            name: control.glyph
            size: 16
            color: control.scanning ? Theme.accent : Theme.alpha(Theme.text, 0.72)
        }
        Text {
            Layout.fillWidth: true
            text: control.text
            font.family: Theme.fontFamilyBody
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Theme.text
            elide: Text.ElideRight
        }
        Text {
            visible: control.actionLabel !== ""
            text: control.actionLabel
            font.family: Theme.fontFamilyBody
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Theme.accent
        }
    }
}
