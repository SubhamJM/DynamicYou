import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs

Item {
    id: banner

    required property var notification
    required property bool active
    required property real surfaceWidth
    required property real surfaceHeight
    signal opened()
    signal dismissed()
    signal hoverChanged(bool hovered)

    readonly property string title: notification?.summary ?? ""
    readonly property string app: notification?.app ?? ""
    readonly property string message: notification?.body ?? ""
    readonly property color tint: notification?.critical ? Theme.error : Theme.accent
    readonly property bool hasAppLine: app !== "" && app !== title
    readonly property real preferredWidth: Math.min(480, Math.max(290,
        Math.ceil(Math.max(titleMeasure.width, messageMeasure.width, appMeasure.width)) + 106))
    property real blend: active ? 1 : 0

    implicitHeight: Math.max(54, content.implicitHeight + 20)
    height: implicitHeight
    opacity: blend * NotchConfig.revealBetween(surfaceWidth / Math.max(1, width), 0.55, 0.95)
        * NotchConfig.revealBetween(surfaceHeight / implicitHeight, 0.48, 0.92)
    visible: opacity > 0.01
    enabled: active

    Behavior on blend {
        NumberAnimation {
            duration: banner.active ? NotchConfig.animContentEnter : NotchConfig.animContentExit
            easing.type: Easing.OutCubic
        }
    }

    TextMetrics { id: titleMeasure; text: banner.title; font: heading.font }
    TextMetrics { id: messageMeasure; text: banner.message; font: preview.font }
    TextMetrics { id: appMeasure; text: banner.hasAppLine ? banner.app : ""; font: application.font }

    HoverHandler {
        enabled: banner.active
        onHoveredChanged: banner.hoverChanged(hovered && banner.active)
    }

    Controls.AbstractButton {
        anchors.fill: parent
        background: null
        Accessible.name: [banner.app, banner.title].filter(Boolean).join(" · ")
        Accessible.description: banner.message
        onClicked: banner.opened()
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            radius: 10
            color: Theme.alpha(banner.tint, 0.16)

            IconImage {
                id: appIcon
                anchors.centerIn: parent
                width: 19
                height: 19
                source: {
                    const icon = banner.notification?.icon ?? "";
                    if (icon.startsWith("/")) return "file://" + icon;
                    if (icon.startsWith("file://")) return icon;
                    if (icon === "" || icon.includes("://")) return "";
                    const path = Quickshell.iconPath(icon, true);
                    return path.includes("image-missing") ? "" : path;
                }
                visible: status === Image.Ready
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: !appIcon.visible
                text: banner.notification?.critical ? "priority_high" : "notifications"
                iconSize: 18
                color: banner.tint
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                id: application
                Layout.fillWidth: true
                visible: banner.hasAppLine
                text: banner.app
                textFormat: Text.PlainText
                color: Theme.alpha(Theme.text, 0.68)
                font.family: Theme.fontFamilyBody
                font.pixelSize: 10
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                id: heading
                Layout.fillWidth: true
                text: banner.title
                textFormat: Text.PlainText
                color: Theme.text
                font.family: Theme.fontFamilyBody
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                id: preview
                Layout.fillWidth: true
                visible: banner.message !== ""
                text: banner.message
                textFormat: Text.PlainText
                color: Theme.alpha(Theme.text, 0.76)
                font.family: Theme.fontFamilyBody
                font.pixelSize: 11
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        Controls.Button {
            id: close
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignTop
            Accessible.name: "Dismiss banner"
            hoverEnabled: true
            padding: 0
            onClicked: banner.dismissed()

            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 15
                    color: Theme.alpha(Theme.text, close.hovered ? 1 : 0.60)
                }
            }
            background: Rectangle {
                radius: 8
                color: Theme.alpha(Theme.text, close.down ? 0.15 : close.hovered ? 0.09 : 0)
            }
        }
    }
}
