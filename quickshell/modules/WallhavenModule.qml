import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.services
import "../"
import "./wallhaven"

FocusScope {
    id: wallhavenModule
    focus: true
    anchors.fill: parent

    readonly property real targetWidth: 820
    readonly property real targetHeight: 860
    readonly property var displayScreen: Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name)
        ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    Component.onCompleted: {
        if (typeof Wallhaven !== "undefined") {
            Wallhaven.viewActive = true;
        }
        if (wallhavenView && wallhavenView.inputField) {
            wallhavenView.inputField.text = "";
            Qt.callLater(() => wallhavenView.inputField.forceActiveFocus());
        }
    }

    Component.onDestruction: {
        if (typeof Wallhaven !== "undefined") {
            Wallhaven.viewActive = false;
            Wallhaven.activePreview = null;
        }
    }

    Keys.forwardTo: (wallhavenView && wallhavenView.inputField) ? [wallhavenView.inputField] : []

    Keys.onEscapePressed: (event) => {
        if (typeof Wallhaven !== "undefined" && Wallhaven.activePreview !== null) {
            Wallhaven.activePreview = null;
            event.accepted = true;
            return;
        }
        if (typeof root !== "undefined" && typeof root.collapseToIdle === "function") {
            root.collapseToIdle();
        }
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 8

        // Top Header connected to bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 8

            // Back button
            Rectangle {
                id: backBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: backMouse.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: 18
                    color: Theme.text
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof root !== "undefined" && typeof root.switchMode === "function") {
                            root.switchMode("launcher", true);
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                Text {
                    text: "Wallhaven Wallpapers"
                    color: Theme.text
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Browse, search and set wallpapers online from wallhaven.cc"
                    color: Theme.subtext
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 11
                }
            }

            // Close button
            Rectangle {
                id: closeBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: closeMouse.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 18
                    color: Theme.text
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof root !== "undefined" && typeof root.collapseToIdle === "function") {
                            root.collapseToIdle();
                        }
                    }
                }
            }
        }

        // Main Wallhaven view
        WallhavenView {
            id: wallhavenView
            Layout.fillWidth: true
            Layout.fillHeight: true
            screenWidth: Hyprland.focusedMonitor?.width ?? (wallhavenModule.displayScreen ? wallhavenModule.displayScreen.width : 1920)
            screenHeight: Hyprland.focusedMonitor?.height ?? (wallhavenModule.displayScreen ? wallhavenModule.displayScreen.height : 1080)
            panelScreen: wallhavenModule.displayScreen
        }
    }
}
