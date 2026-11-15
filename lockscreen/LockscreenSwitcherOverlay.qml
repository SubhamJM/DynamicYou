import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: overlayRoot
    anchors.fill: parent
    z: 9999

    property string currentTheme: "dog-samurai"
    property string themesDir: ""
    signal themeSelected(string themeId)
    signal requestFocusBack()

    property bool isOpen: false

    readonly property var availableThemes: [
        {
            id: "dog-samurai",
            name: "Dog Samurai",
            desc: "Animated samurai dog in sakura rain",
            accent: "#ffb7c5",
            folder: "dog-samurai"
        },
        {
            id: "minecraft",
            name: "Minecraft",
            desc: "Classic panorama & interactive buttons",
            accent: "#5b8731",
            folder: "minecraft"
        },
        {
            id: "pixel-hollowknight",
            name: "Hollow Knight",
            desc: "Atmospheric Hallownest pixel art",
            accent: "#f5aa5b",
            folder: "pixel-hollowknight"
        },
        {
            id: "pixel-emerald",
            name: "Pixel - Emerald",
            desc: "Retro Pokémon Emerald adventure",
            accent: "#3ec878",
            folder: "pixel-emerald"
        },
        {
            id: "enfield",
            name: "Enfield",
            desc: "Cinematic Royal Enfield cruiser",
            accent: "#d4849e",
            folder: "enfield"
        },
        {
            id: "last-of-us",
            name: "The Last of Us",
            desc: "Overgrown sanctuary with spores",
            accent: "#f7c594",
            folder: "last-of-us"
        }
    ]

    function getCurrentThemeName() {
        for (var i = 0; i < availableThemes.length; i++) {
            if (availableThemes[i].id === currentTheme) {
                return availableThemes[i].name;
            }
        }
        return currentTheme;
    }

    // Key Listener for Escape/F2 when switcher is open
    Item {
        focus: overlayRoot.isOpen
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_F2 || event.key === Qt.Key_Escape) {
                overlayRoot.isOpen = false;
                overlayRoot.requestFocusBack();
                event.accepted = true;
            }
        }
    }

    // ==========================================
    // FLOATING TRIGGER PILL (Top-Right Corner)
    // ==========================================
    Rectangle {
        id: triggerPill
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 24
        height: 38
        width: pillRow.implicitWidth + 28
        radius: 19
        color: pillMouse.containsMouse ? Qt.rgba(0.08, 0.10, 0.15, 0.88) : Qt.rgba(0.04, 0.05, 0.08, 0.70)
        border.width: 1
        border.color: pillMouse.containsMouse ? Qt.rgba(0.9, 0.9, 1.0, 0.35) : Qt.rgba(0.9, 0.9, 1.0, 0.15)
        scale: pillMouse.pressed ? 0.96 : (pillMouse.containsMouse ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "󰌾"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: "#e2e8f0"
            }

            Text {
                text: overlayRoot.getCurrentThemeName()
                font.family: "Inter"
                font.pixelSize: 12
                font.bold: true
                color: "#f8fafc"
            }

            Text {
                text: overlayRoot.isOpen ? "󰅃" : "󰅀"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: "#94a3b8"
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                overlayRoot.isOpen = !overlayRoot.isOpen;
                if (!overlayRoot.isOpen) overlayRoot.requestFocusBack();
            }
        }
    }

    // Tooltip indicator (below pill in top-right)
    Rectangle {
        anchors.top: triggerPill.bottom
        anchors.topMargin: 8
        anchors.right: triggerPill.right
        height: 24
        width: tipText.implicitWidth + 16
        radius: 6
        color: Qt.rgba(0, 0, 0, 0.75)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        visible: pillMouse.containsMouse && !overlayRoot.isOpen
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: "Change Lockscreen Style (F2)"
            font.family: "Inter"
            font.pixelSize: 10
            color: "#cbd5e1"
        }
    }

    // ==========================================
    // MODAL SWITCHER PANEL
    // ==========================================
    // Dim background scrim
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: overlayRoot.isOpen
        opacity: overlayRoot.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                overlayRoot.isOpen = false;
                overlayRoot.requestFocusBack();
            }
        }
    }

    // Center Card Container
    Rectangle {
        id: panelCard
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 1140)
        height: Math.min(parent.height - 80, 480)
        radius: 20
        color: Qt.rgba(0.06, 0.07, 0.10, 0.94)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        clip: true

        visible: overlayRoot.isOpen
        scale: overlayRoot.isOpen ? 1.0 : 0.92
        opacity: overlayRoot.isOpen ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 12

                Text {
                    text: "󰏘"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                    color: "#818cf8"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Switch Lock Screen Style"
                        font.family: "Inter"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#f8fafc"
                    }
                    Text {
                        text: "Select a theme to preview and apply immediately • Press F2 or Esc to close"
                        font.family: "Inter"
                        font.pixelSize: 11
                        color: "#94a3b8"
                    }
                }

                // Close Button
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                    scale: closeMouse.pressed ? 0.92 : 1.0

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.family: "Inter"
                        font.pixelSize: 14
                        color: "#cbd5e1"
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            overlayRoot.isOpen = false;
                            overlayRoot.requestFocusBack();
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Themes Grid (2 rows of 3, or 1 row of 6)
            GridView {
                id: themesGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: width / 3
                cellHeight: height / 2
                model: overlayRoot.availableThemes

                delegate: Item {
                    width: themesGrid.cellWidth
                    height: themesGrid.cellHeight

                    readonly property bool isActive: modelData.id === overlayRoot.currentTheme
                    readonly property string thumbPath: "file://" + overlayRoot.themesDir + "/" + modelData.folder + "/preview.png"

                    Rectangle {
                        id: cardInner
                        anchors.fill: parent
                        anchors.margins: 8
                        radius: 14
                        color: Qt.rgba(0.10, 0.12, 0.18, 0.8)
                        border.width: 1
                        border.color: cardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.10)
                        scale: cardMouse.pressed ? 0.97 : (cardMouse.containsMouse ? 1.02 : 1.0)
                        clip: true

                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        // Background Preview Image
                        Image {
                            anchors.fill: parent
                            source: thumbPath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }

                        // Gradient Shade
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.50; color: Qt.rgba(0, 0, 0, 0.20) }
                                GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.05, 0.08, 0.95) }
                            }
                        }

                        // Active Indicator Pill (Top-Right)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            height: 22
                            width: activeRow.implicitWidth + 14
                            radius: 11
                            color: isActive ? (modelData.accent || "#818cf8") : Qt.rgba(0, 0, 0, 0.6)
                            visible: isActive

                            RowLayout {
                                id: activeRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "󰄬"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#0f172a"
                                }
                                Text {
                                    text: "ACTIVE"
                                    font.family: "Inter"
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: "#0f172a"
                                }
                            }
                        }

                        // Bottom Theme Info (Name Only)
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 14
                            text: modelData.name
                            font.family: "Inter"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#ffffff"
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                overlayRoot.themeSelected(modelData.id);
                                overlayRoot.isOpen = false;
                                overlayRoot.requestFocusBack();
                            }
                        }
                    }
                }
            }
        }
    }
}
