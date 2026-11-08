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

    function triggerAction(idx) {
        var cmds = [
            "pidof hyprlock || hyprlock || swaylock || loginctl lock-session",
            "systemctl suspend",
            "hyprctl dispatch exit || loginctl terminate-user $USER",
            "systemctl reboot",
            "systemctl poweroff"
        ];
        if (idx >= 0 && idx < cmds.length) {
            Quickshell.execDetached(["sh", "-c", cmds[idx]]);
            root.collapseToIdle();
        }
    }

    Keys.onLeftPressed: (event) => {
        currentIndex = (currentIndex - 1 + 5) % 5;
        event.accepted = true;
    }
    Keys.onRightPressed: (event) => {
        currentIndex = (currentIndex + 1) % 5;
        event.accepted = true;
    }
    Keys.onReturnPressed: (event) => {
        triggerAction(currentIndex);
        event.accepted = true;
    }
    Keys.onSpacePressed: (event) => {
        triggerAction(currentIndex);
        event.accepted = true;
    }
    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    // Direct key accelerators like Lucid Session (L=Lock, S=Sleep, E=Logout, R=Reboot, P=Power)
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_L) {
            triggerAction(0);
            event.accepted = true;
        } else if (event.key === Qt.Key_S) {
            triggerAction(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_E) {
            triggerAction(2);
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            triggerAction(3);
            event.accepted = true;
        } else if (event.key === Qt.Key_P) {
            triggerAction(4);
            event.accepted = true;
        }
    }

    Item {
        anchors.fill: parent

        // 1. Back to Previous Module Button (Lucid-styled tactile circle)
        Rectangle {
            id: backBtn
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 18
            color: backMouse.pressed
                ? Qt.rgba(255, 255, 255, 0.16)
                : (backMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : Qt.rgba(255, 255, 255, 0.05))
            border.width: 1
            border.color: backMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.08)
            scale: backMouse.pressed ? 0.92 : (backMouse.containsMouse ? 1.05 : 1.0)

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: 18
                fill: backMouse.containsMouse ? 1 : 0
                color: backMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.70)
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var target = (root.previousExpandedMode && root.previousExpandedMode !== "powermenu")
                        ? root.previousExpandedMode : "utility";
                    root.switchMode(target, true);
                }
            }
        }

        // 2. Power Action Buttons Container (Right-aligned with balanced spacing)
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Hold Button Component — Lucid tonal aesthetic with filled symbols and tactile charging ring
            component HoldButton: Item {
                id: btnRoot
                property int btnIndex: -1
                property bool isFocused: powerMenu.currentIndex === btnIndex
                property string iconText: ""
                property string label: ""
                property string keyHint: ""
                property string actionCmd: ""
                property color activeColor: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
                property real progress: 0.0

                readonly property bool isHot: btnRoot.isFocused || holdMouse.containsMouse
                readonly property bool isCharging: btnRoot.progress > 0.001

                Layout.preferredWidth: 64
                Layout.preferredHeight: 88
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
                    duration: 400
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
                    spacing: 5

                    // Tonal Circular Tile (Lucid-style surface)
                    Item {
                        width: 50
                        height: 50
                        anchors.horizontalCenter: parent.horizontalCenter

                        // Ambient Glow on Hover / Charge
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: width / 2
                            color: Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.22)
                            opacity: btnRoot.isCharging ? 0.95 : (btnRoot.isHot ? 0.65 : 0.0)
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                        }

                        // Background Tile with M3 / Lucid Tonal Palette
                        Rectangle {
                            id: circleBg
                            anchors.fill: parent
                            radius: 25
                            color: holdMouse.pressed
                                ? Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.36)
                                : (btnRoot.isHot
                                    ? Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.22)
                                    : Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.10))
                            border.width: holdMouse.pressed ? 2 : (btnRoot.isHot ? 1.5 : 1)
                            border.color: holdMouse.pressed
                                ? btnRoot.activeColor
                                : (btnRoot.isHot
                                    ? Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.65)
                                    : Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.22))
                            scale: holdMouse.pressed ? 0.93 : (btnRoot.isHot ? 1.05 : 1.0)

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            // Static Track Ring for charging arc
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                radius: width / 2
                                color: "transparent"
                                visible: btnRoot.isHot || btnRoot.isCharging
                                border.width: 1
                                border.color: Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.20)
                            }

                            // Circular Progress Ring (Smooth Antialiased Canvas Arc)
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
                                    ctx.lineWidth = 3.2;
                                    ctx.strokeStyle = "" + btnRoot.activeColor;
                                    ctx.lineCap = "round";
                                    ctx.stroke();
                                }
                            }

                            // Action Icon (Material Symbol with filled morph on hover/charge like Lucid)
                            MaterialSymbol {
                                id: actionIcon
                                anchors.centerIn: parent
                                text: btnRoot.iconText
                                iconSize: 24
                                fill: (btnRoot.isHot || btnRoot.isCharging) ? 1 : 0
                                color: btnRoot.isHot
                                    ? btnRoot.activeColor
                                    : Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.90)
                                scale: holdMouse.pressed ? 0.95 : (btnRoot.isHot ? 1.10 : 1.0)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
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

                    // Label with Keycap Hint (Lucid aesthetics)
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btnRoot.label
                            font.family: (typeof Theme !== "undefined" && Theme.fontFamilyBody) ? Theme.fontFamilyBody : "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: btnRoot.isHot
                                ? btnRoot.activeColor
                                : Qt.rgba(255, 255, 255, 0.72)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            renderType: Text.NativeRendering
                        }

                        // Sleek Keycap Hint Badge
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 15
                            height: 12
                            radius: 3
                            color: btnRoot.isHot
                                ? Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.25)
                                : Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1
                            border.color: btnRoot.isHot
                                ? Qt.rgba(btnRoot.activeColor.r, btnRoot.activeColor.g, btnRoot.activeColor.b, 0.50)
                                : Qt.rgba(255, 255, 255, 0.14)

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: btnRoot.keyHint
                                font.family: (typeof Theme !== "undefined" && Theme.fontFamilyMono) ? Theme.fontFamilyMono : "JetBrains Mono"
                                font.pixelSize: 8
                                font.bold: true
                                color: btnRoot.isHot
                                    ? btnRoot.activeColor
                                    : Qt.rgba(255, 255, 255, 0.55)
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }

            // 1. Lock Screen (L) - Lucid Blue
            HoldButton {
                btnIndex: 0
                iconText: "lock"
                label: "Lock"
                keyHint: "L"
                actionCmd: "pidof hyprlock || hyprlock || swaylock || loginctl lock-session"
                activeColor: (typeof Theme !== "undefined" && Theme.accent) ? Theme.accent : "#7aa2f7"
            }

            // 2. Sleep / Suspend (S) - Lucid Warm Moonlight Amber
            HoldButton {
                btnIndex: 1
                iconText: "bedtime"
                label: "Sleep"
                keyHint: "S"
                actionCmd: "systemctl suspend"
                activeColor: "#e0af68"
            }

            // 3. Logout (E) - Lucid Lavender Mauve
            HoldButton {
                btnIndex: 2
                iconText: "logout"
                label: "Logout"
                keyHint: "E"
                actionCmd: "hyprctl dispatch exit || loginctl terminate-user $USER"
                activeColor: "#bb9af7"
            }

            // 4. Reboot (R) - Lucid Ice Cyan
            HoldButton {
                btnIndex: 3
                iconText: "restart_alt"
                label: "Reboot"
                keyHint: "R"
                actionCmd: "systemctl reboot"
                activeColor: "#7dcfff"
            }

            // 5. Power Off (P) - Lucid Coral Red
            HoldButton {
                btnIndex: 4
                iconText: "power_settings_new"
                label: "Power Off"
                keyHint: "P"
                actionCmd: "systemctl poweroff"
                activeColor: "#f7768e"
            }
        }
    }
}
