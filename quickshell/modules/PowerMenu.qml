import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"

FocusScope {
    id: powerMenu
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    property int currentIndex: 1

    Keys.onLeftPressed: { currentIndex = (currentIndex - 1 + 5) % 5; }
    Keys.onRightPressed: { currentIndex = (currentIndex + 1) % 5; }
    Keys.onReturnPressed: { triggerSelected(); }
    Keys.onSpacePressed: { triggerSelected(); }
    Keys.onEscapePressed: { root.activeMode = "idle"; }

    function triggerSelected() {
        var cmds = [
            "pidof hyprlock || hyprlock || swaylock || loginctl lock-session",
            "systemctl suspend",
            "hyprctl dispatch exit || loginctl terminate-user $USER",
            "systemctl reboot",
            "systemctl poweroff"
        ];
        Quickshell.execDetached(["sh", "-c", cmds[currentIndex]]);
        root.activeMode = "idle";
    }

    Item {
        anchors.fill: parent

        // 1. Back to Previous Module Button (Left-aligned)
        Rectangle {
            id: backBtn
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 10
            color: backMouse.containsMouse ? (Theme.colors.hover_bg ?? "#252b3d") : (Theme.colors.card_bg ?? "#181b28")
            border.width: 1
            border.color: backMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : Qt.rgba(255, 255, 255, 0.06)
            scale: backMouse.pressed ? 0.90 : (backMouse.containsMouse ? 1.04 : 1.0)
            Behavior on scale { NumberAnimation { duration: 90 } }
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: 16
                color: backMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_primary ?? "#e2e8f0")
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    var target = (root.previousExpandedMode && root.previousExpandedMode !== "powermenu") ? root.previousExpandedMode : "utility";
                    root.switchMode(target, true);
                }
            }
        }

        // 2. Power Action Buttons Container (Right-aligned with balanced margins)
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // Hold Button Component — solid, filled Android-style circular tile with progress ring
            component HoldButton: Item {
                id: btnRoot
                property int btnIndex: -1
                property bool isFocused: powerMenu.currentIndex === btnIndex
                property string iconText: ""
                property string label: ""
                property string actionCmd: ""
                property color activeColor: Theme.colors.accent ?? "#7aa2f7"
                property real progress: 0.0

                readonly property color baseTileColor: Theme.colors.card_bg ?? "#14161f"

                Layout.preferredWidth: 66
                Layout.preferredHeight: 82
                Layout.alignment: Qt.AlignVCenter

                opacity: root.activeMode === "powermenu" ? 1.0 : 0.0
                transform: Translate {
                    y: root.activeMode === "powermenu" ? 0 : 6
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                NumberAnimation on progress {
                    id: chargeAnim
                    from: 0.0
                    to: 1.0
                    duration: 480
                    running: false
                    onFinished: {
                        if (btnRoot.progress >= 1.0) {
                            Quickshell.execDetached(["sh", "-c", btnRoot.actionCmd]);
                            root.activeMode = "idle";
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    // Solid circular tile
                    Rectangle {
                        id: circleBg
                        width: 50
                        height: 50
                        radius: 25
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: holdMouse.pressed
                            ? Qt.tint(btnRoot.baseTileColor, Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.38))
                            : (btnRoot.isFocused || holdMouse.containsMouse)
                                ? Qt.tint(btnRoot.baseTileColor, Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.22))
                                : btnRoot.baseTileColor
                        scale: holdMouse.pressed ? 0.94 : (btnRoot.isFocused ? 1.04 : (holdMouse.containsMouse ? 1.02 : 1.0))

                        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        // Faint track ring with smooth focus highlight
                        Rectangle {
                            id: trackRing
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: holdMouse.pressed
                                ? Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.85)
                                : (btnRoot.isFocused || holdMouse.containsMouse)
                                    ? Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.60)
                                    : Qt.rgba(255, 255, 255, 0.07)
                            Behavior on border.color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }

                        // Circular Fill Progress Ring (only visible & rendered when charging)
                        Canvas {
                            id: progressCanvas
                            anchors.fill: parent
                            anchors.margins: -4
                            visible: btnRoot.progress > 0.001
                            renderTarget: Canvas.FramebufferObject

                            Connections {
                                target: btnRoot
                                function onProgressChanged() {
                                    if (btnRoot.progress > 0.001) progressCanvas.requestPaint();
                                }
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                if (btnRoot.progress <= 0) return;

                                var centerX = width / 2;
                                var centerY = height / 2;
                                var radius = Math.min(centerX, centerY) - 2;

                                ctx.beginPath();
                                ctx.arc(centerX, centerY, radius, -Math.PI / 2, (-Math.PI / 2) + (Math.PI * 2 * btnRoot.progress), false);
                                ctx.lineWidth = 3.0;
                                ctx.strokeStyle = btnRoot.activeColor;
                                ctx.lineCap = "round";
                                ctx.stroke();
                            }
                        }

                        // Action Icon
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: btnRoot.iconText
                            iconSize: 22
                            color: (btnRoot.isFocused || holdMouse.containsMouse)
                                ? btnRoot.activeColor
                                : Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.70)
                            Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: holdMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onPressed: {
                                powerMenu.currentIndex = btnRoot.btnIndex;
                                btnRoot.progress = 0.0;
                                chargeAnim.restart();
                            }
                            onReleased: {
                                chargeAnim.stop();
                                btnRoot.progress = 0.0;
                            }
                            onCanceled: {
                                chargeAnim.stop();
                                btnRoot.progress = 0.0;
                            }
                        }
                    }

                    // Label (constant weight avoids horizontal layout shift; smooth color fade)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btnRoot.label
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: btnRoot.isFocused
                            ? btnRoot.activeColor
                            : (holdMouse.containsMouse ? "#ffffff" : (Theme.colors.text_secondary ?? "#94a3b8"))
                        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }
                }
            }

            // 1. Lock Screen
            HoldButton {
                btnIndex: 0
                iconText: "lock"
                label: "Lock"
                actionCmd: "pidof hyprlock || hyprlock || swaylock || loginctl lock-session"
                activeColor: Theme.colors.accent ?? "#7aa2f7"
            }

            // 2. Sleep / Suspend
            HoldButton {
                btnIndex: 1
                iconText: "bedtime"
                label: "Sleep"
                actionCmd: "systemctl suspend"
                activeColor: "#e0af68"
            }

            // 3. Logout
            HoldButton {
                btnIndex: 2
                iconText: "logout"
                label: "Logout"
                actionCmd: "hyprctl dispatch exit || loginctl terminate-user $USER"
                activeColor: "#bb9af7"
            }

            // 4. Reboot
            HoldButton {
                btnIndex: 3
                iconText: "restart_alt"
                label: "Reboot"
                actionCmd: "systemctl reboot"
                activeColor: "#7dcfff"
            }

            // 5. Power Off
            HoldButton {
                btnIndex: 4
                iconText: "power_settings_new"
                label: "Power Off"
                actionCmd: "systemctl poweroff"
                activeColor: "#f44336"
            }
        }
    }
}
