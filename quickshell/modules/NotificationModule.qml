import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"

ColumnLayout {
    id: notifModule
    spacing: 10
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true
    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    readonly property int calculatedCount: globalNotifModel.count

    // ========================================================
    // 1. UNIFIED MINIMAL HEADER BAR (Modern Desktop Standard)
    // ========================================================
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 8

        // Back to Utility / Quick Settings Button
        IrisIconButton {
            width: 28
            height: 28
            buttonSize: 28
            buttonRadius: 14
            flat: true
            icon: "arrow_back"
            iconSize: 16
            iconColor: Theme.colors.text_primary ?? "#ffffff"
            onClicked: {
                var target = (root.previousExpandedMode && root.previousExpandedMode !== "notifications") ? root.previousExpandedMode : "utility";
                root.switchMode(target, true);
            }
        }

        Text {
            text: "Notifications"
            font.family: "Noto Sans"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Theme.colors.text_primary ?? "#ffffff"
            renderType: Text.NativeRendering
        }

        // Count Pill
        Rectangle {
            visible: globalNotifModel.count > 0
            Layout.preferredHeight: 20
            Layout.preferredWidth: countText.implicitWidth + 12
            radius: 10
            color: Qt.rgba(255, 255, 255, 0.08)

            Text {
                id: countText
                anchors.centerIn: parent
                text: globalNotifModel.count
                font.family: "Noto Sans"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Qt.rgba(255, 255, 255, 0.70)
                renderType: Text.NativeRendering
            }
        }

        Item { Layout.fillWidth: true }

        // DND Toggle Pill (Solid M3 pill, zero borders)
        Rectangle {
            Layout.preferredHeight: 26
            Layout.preferredWidth: dndRow.implicitWidth + 18
            radius: 13
            color: root.dndEnabled
                ? Qt.alpha(Theme.colors.accent ?? "#7aa2f7", 0.22)
                : (dndMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06))
            border.width: 0

            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

            RowLayout {
                id: dndRow
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    text: root.dndEnabled ? "notifications_off" : "notifications"
                    iconSize: 13
                    color: root.dndEnabled ? (Theme.colors.accent ?? "#7aa2f7") : Qt.rgba(255, 255, 255, 0.70)
                }

                Text {
                    text: root.dndEnabled ? "DND On" : "DND"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: root.dndEnabled ? (Theme.colors.accent ?? "#7aa2f7") : Qt.rgba(255, 255, 255, 0.70)
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dndEnabled = !root.dndEnabled
            }
        }

        // Clear All Pill (Solid pill, zero borders)
        Rectangle {
            visible: globalNotifModel.count > 0
            Layout.preferredHeight: 26
            Layout.preferredWidth: 68
            radius: 13
            color: clearMouse.containsMouse
                ? Qt.alpha(Theme.colors.error ?? "#f87171", 0.20)
                : Qt.rgba(255, 255, 255, 0.06)
            border.width: 0

            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: "Clear All"
                font.family: "Noto Sans"
                font.pixelSize: 11
                font.weight: Font.Medium
                color: clearMouse.containsMouse ? (Theme.colors.error ?? "#f87171") : Qt.rgba(255, 255, 255, 0.60)
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    for (var i = 0; i < globalNotifModel.count; i++) {
                        var item = globalNotifModel.get(i);
                        if (item && item.notifObj) item.notifObj.dismiss();
                    }
                    globalNotifModel.clear();
                }
            }
        }
    }

    // ========================================================
    // 2. NOTIFICATIONS LIST VIEW (Solid Cards, Zero Borders)
    // ========================================================
    ListView {
        id: notifList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: globalNotifModel

        boundsBehavior: Flickable.DragAndOvershootBounds
        maximumFlickVelocity: 3500
        flickDeceleration: 2200

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4
            contentItem: Rectangle {
                radius: 2
                color: Qt.rgba(255, 255, 255, 0.30)
            }
        }

        // Empty State Placeholder
        Item {
            anchors.fill: parent
            visible: globalNotifModel.count === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "notifications_none"
                    iconSize: 32
                    color: Qt.rgba(255, 255, 255, 0.25)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No notifications"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Qt.rgba(255, 255, 255, 0.40)
                    renderType: Text.NativeRendering
                }
            }
        }

        delegate: Rectangle {
            id: notifCard
            width: ListView.view.width
            implicitHeight: cardContent.implicitHeight + 18
            radius: 12
            color: cardMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.055)
            border.width: 0
            clip: true

            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
            }

            ColumnLayout {
                id: cardContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IrisIcon {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        icon: (appIcon && appIcon !== "") ? appIcon : (appName ? appName.toLowerCase() : "notifications")
                        iconSize: 16
                        color: Theme.colors.accent ?? "#7aa2f7"
                        fallbackSymbol: IconResolver.resolve(appName).fallbackSymbol || "notifications"
                        cornerRadius: 4
                    }

                    Text {
                        text: appName ? appName : "System"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.colors.accent ?? "#7aa2f7"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        renderType: Text.NativeRendering
                    }

                    IrisIconButton {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        buttonSize: 20
                        buttonRadius: 10
                        flat: true
                        icon: "close"
                        iconSize: 12
                        iconColor: Qt.rgba(255, 255, 255, 0.40)
                        hoverIconColor: Theme.colors.error ?? "#f87171"
                        onClicked: {
                            if (notifObj) notifObj.dismiss();
                            globalNotifModel.remove(index);
                        }
                    }
                }

                Text {
                    text: summary
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: "#ffffff"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: summary !== ""
                    renderType: Text.NativeRendering
                }

                Text {
                    text: body
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    color: Qt.rgba(255, 255, 255, 0.60)
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: body !== ""
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
