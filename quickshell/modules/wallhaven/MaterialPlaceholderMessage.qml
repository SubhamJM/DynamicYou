import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool shown: true
    property string icon: ""
    property string text: ""
    property string explanation: ""
    property int shape: 0
    property Action helpfulAction
    property real maximumWidth: 340
    property string actionIcon: ""
    property string actionText: helpfulAction?.text ?? ""
    property int textHorizontalAlignment: Text.AlignHCenter
    property bool compact: false

    visible: shown
    implicitWidth: Math.min(maximumWidth, content.implicitWidth + 24)
    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        width: Math.min(root.maximumWidth, root.parent ? root.parent.width - 24 : root.maximumWidth)
        spacing: root.compact ? 6 : 10

        Rectangle {
            visible: root.icon !== ""
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: root.compact ? 48 : 64
            implicitHeight: implicitWidth
            radius: implicitWidth / 2
            color: Appearance.colors.colPrimaryContainer

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.icon
                iconSize: root.compact ? 24 : 30
                color: Appearance.colors.colOnPrimaryContainer
            }
        }

        StyledText {
            visible: root.text !== ""
            Layout.fillWidth: true
            text: root.text
            horizontalAlignment: root.textHorizontalAlignment
            wrapMode: Text.Wrap
            font.pixelSize: root.compact ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.large
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnSurface
        }

        StyledText {
            visible: root.explanation !== ""
            Layout.fillWidth: true
            text: root.explanation
            horizontalAlignment: root.textHorizontalAlignment
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }

        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignHCenter
            visible: root.helpfulAction !== null
            mainText: root.actionText
            materialIcon: root.actionIcon
            onClicked: root.helpfulAction.trigger()
        }
    }
}
