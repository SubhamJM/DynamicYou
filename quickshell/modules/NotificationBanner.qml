import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs

// Matushell IslandNotificationPopup-style notification toast banner
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
    readonly property string app: (notification?.app && notification.app !== "") ? notification.app : "System"
    readonly property string message: notification?.body ?? ""
    readonly property bool isCritical: Boolean(notification?.critical)
    readonly property color tint: isCritical ? Theme.error : Theme.accent
    readonly property color fgPrimary: Theme.colors.text_primary ?? "#f5f5f7"
    readonly property bool hasBody: message !== ""
    readonly property bool isHovered: bannerHover.hovered

    readonly property real preferredWidth: 380
    property real blend: active ? 1 : 0
    property real countdownProgress: 1.0

    implicitHeight: Math.max(70, layout.implicitHeight + 22)
    height: implicitHeight
    opacity: blend * NotchConfig.revealBetween(surfaceWidth / Math.max(1, width), 0.55, 0.95)
        * NotchConfig.revealBetween(surfaceHeight / Math.max(1, implicitHeight), 0.48, 0.92)
    visible: opacity > 0.01
    enabled: active

    function restartCountdown() {
        countdownAnim.stop();
        countdownProgress = 1.0;
        if (active && !isHovered) {
            countdownAnim.start();
        }
    }

    onActiveChanged: {
        if (active) restartCountdown();
        else countdownAnim.stop();
    }

    onNotificationChanged: {
        if (active) restartCountdown();
    }

    onIsHoveredChanged: {
        if (!active) return;
        if (isHovered) countdownAnim.pause();
        else countdownAnim.resume();
    }

    NumberAnimation {
        id: countdownAnim
        target: banner
        property: "countdownProgress"
        from: 1.0
        to: 0.0
        duration: NotchConfig.timerNotifPopup
        easing.type: Easing.Linear
    }

    Behavior on blend {
        NumberAnimation {
            duration: banner.active ? NotchConfig.animContentEnter : NotchConfig.animContentExit
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        id: bannerHover
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

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Squircle avatar (Matushell 32px radiusMd)
            ClippingRectangle {
                id: notifAvatar
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignTop
                radius: 11
                color: banner.isCritical ? Qt.alpha(Theme.error, 0.18) : Qt.alpha(Theme.accent, 0.14)

                readonly property string iconSource: {
                    const icon = banner.notification?.icon ?? "";
                    if (icon.startsWith("/")) return "file://" + icon;
                    if (icon.startsWith("file://") || icon.startsWith("image://")) return icon;
                    if (icon === "" || icon.includes("://")) return "";
                    const path = Quickshell.iconPath(icon, true);
                    return path.includes("image-missing") ? "" : path;
                }

                Image {
                    id: appImg
                    anchors.fill: parent
                    anchors.margins: 4
                    fillMode: Image.PreserveAspectFit
                    source: notifAvatar.iconSource
                    sourceSize: Qt.size(48, 48)
                    visible: notifAvatar.iconSource !== "" && status === Image.Ready
                    smooth: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !appImg.visible
                    text: banner.isCritical ? "error_outline" : "notifications"
                    color: banner.tint
                    font.family: Theme.fontFamilyIcon
                    font.pixelSize: 18
                    font.hintingPreference: Font.PreferNoHinting
                    font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 18, "wght": 500 })
                    renderType: Text.CurveRendering
                    antialiasing: true
                    smooth: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                // Header line: App Name · now + Close button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: banner.app
                        textFormat: Text.PlainText
                        color: banner.tint
                        font.family: "Google Sans Flex"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.variableAxes: ({ "wght": 560, "wdth": 100 })
                        font.hintingPreference: Font.PreferNoHinting
                        renderType: Text.QtRendering
                        antialiasing: true
                        smooth: true
                        elide: Text.ElideRight
                        Layout.maximumWidth: 165
                    }

                    Text {
                        text: "·"
                        color: Qt.alpha(banner.fgPrimary, 0.55)
                        font.family: "Google Sans Flex"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.hintingPreference: Font.PreferNoHinting
                        renderType: Text.QtRendering
                    }

                    Text {
                        text: "now"
                        color: Qt.alpha(banner.fgPrimary, 0.55)
                        font.family: "Google Sans Flex"
                        font.pixelSize: 12
                        font.variableAxes: ({ "wght": 450, "wdth": 100 })
                        font.hintingPreference: Font.PreferNoHinting
                        renderType: Text.QtRendering
                    }

                    Item { Layout.fillWidth: true }

                    MouseArea {
                        id: closeBtn
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        Layout.alignment: Qt.AlignVCenter
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: banner.dismissed()

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: closeBtn.containsMouse ? Qt.alpha(banner.fgPrimary, 0.14) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "close"
                                color: closeBtn.containsMouse ? banner.fgPrimary : Qt.alpha(banner.fgPrimary, 0.6)
                                font.family: Theme.fontFamilyIcon
                                font.pixelSize: 14
                                font.hintingPreference: Font.PreferNoHinting
                                font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 14, "wght": 500 })
                                renderType: Text.CurveRendering
                                antialiasing: true
                                smooth: true
                            }
                        }
                    }
                }

                // Title / Summary
                Text {
                    Layout.fillWidth: true
                    text: banner.title
                    textFormat: Text.PlainText
                    color: banner.fgPrimary
                    font.family: "Google Sans Flex"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.variableAxes: ({ "wght": 580, "wdth": 100 })
                    font.hintingPreference: Font.PreferNoHinting
                    renderType: Text.QtRendering
                    antialiasing: true
                    smooth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // Body preview (expands smoothly on hover like Matushell)
                Text {
                    Layout.fillWidth: true
                    visible: banner.hasBody
                    text: banner.message
                    textFormat: Text.PlainText
                    color: Qt.alpha(banner.fgPrimary, 0.72)
                    font.family: "Google Sans Flex"
                    font.pixelSize: 12
                    font.variableAxes: ({ "wght": 420, "wdth": 100 })
                    font.hintingPreference: Font.PreferNoHinting
                    renderType: Text.QtRendering
                    antialiasing: true
                    smooth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: banner.isHovered ? 4 : 1
                    elide: Text.ElideRight
                }
            }
        }

        // Matushell M3 timeout countdown progress indicator (3px segmented pill)
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            implicitHeight: 3

            readonly property real activeW: Math.max(0, Math.min(width, width * banner.countdownProgress))
            readonly property real trackX: activeW > 0 ? Math.min(width, activeW + 4) : 0
            readonly property real trackW: Math.max(0, width - trackX)

            Rectangle {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                width: parent.activeW
                height: 3
                radius: 1.5
                color: banner.tint
                visible: width > 0
            }

            Rectangle {
                x: parent.trackX
                anchors.verticalCenter: parent.verticalCenter
                width: parent.trackW
                height: 3
                radius: 1.5
                color: Qt.alpha(banner.tint, 0.22)
                visible: width > 0
            }
        }
    }
}
