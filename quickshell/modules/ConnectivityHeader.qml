import QtQuick
import QtQuick.Layouts
import qs

RowLayout {
    id: header
    required property string title
    required property string status
    required property bool powered
    property bool powerAvailable: true

    signal backRequested()
    signal powerRequested(bool enabled)

    spacing: 8
    implicitHeight: 38

    IrisIconButton {
        buttonSize: 28
        buttonRadius: 8
        flat: true
        icon: "arrow_back"
        iconColor: Theme.alpha(Theme.text, 0.72)
        iconSize: 16
        Accessible.role: Accessible.Button
        Accessible.name: "Back to Control Center"
        onClicked: header.backRequested()
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        Text {
            Layout.fillWidth: true
            text: header.title
            font.family: Theme.fontFamilyBody
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Theme.text
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: header.status
            font.family: Theme.fontFamilyBody
            font.pixelSize: 11
            color: Theme.alpha(Theme.text, 0.72)
            elide: Text.ElideRight
        }
    }

    ConnectivityToggle {
        powered: header.powered
        enabled: header.powerAvailable
        Accessible.name: header.title
        onClicked: header.powerRequested(!header.powered)
    }
}
