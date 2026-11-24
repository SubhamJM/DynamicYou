import QtQuick
import QtQuick.Controls as Controls
import qs

Controls.AbstractButton {
    id: toggle
    required property bool powered

    implicitWidth: 54
    implicitHeight: 36
    hoverEnabled: true
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: powered

    background: Rectangle {
        anchors.centerIn: parent
        width: 36
        height: 20
        radius: 10
        color: toggle.powered
            ? (toggle.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
            : (toggle.hovered ? Theme.alpha(Theme.text, 0.14) : Theme.alpha(Theme.text, 0.09))
        opacity: toggle.enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.powered ? parent.width - width - 3 : 3
            width: 14
            height: 14
            radius: 7
            color: toggle.powered ? (Theme.colors.bg ?? "#12141c") : Theme.alpha(Theme.text, 0.60)
            Behavior on x { NumberAnimation { duration: Theme.ms(120) } }
        }
    }
}
