import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"

FocusScope {
    id: powerMenu
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    property int currentIndex: 1

    readonly property var actionsList: [
        {
            icon: "lock",
            label: "Lock",
            keyHint: "L",
            cmd: "qs ipc call lock lock >/dev/null 2>&1 || pidof hyprlock || hyprlock || swaylock || loginctl lock-session",
            role: "safe"
        },
        {
            icon: "bedtime",
            label: "Sleep",
            keyHint: "S",
            cmd: "systemctl suspend",
            role: "safe"
        },
        {
            icon: "logout",
            label: "Logout",
            keyHint: "E",
            cmd: "hyprctl dispatch exit || loginctl terminate-user $USER",
            role: "warn"
        },
        {
            icon: "restart_alt",
            label: "Reboot",
            keyHint: "R",
            cmd: "systemctl reboot",
            role: "warn"
        },
        {
            icon: "power_settings_new",
            label: "Power Off",
            keyHint: "P",
            cmd: "systemctl poweroff",
            role: "danger"
        }
    ]

    function colorForRole(role) {
        if (role === "danger") {
            return (Theme.colors && Theme.colors.error) ? Theme.colors.error : "#f38ba8";
        }
        if (role === "warn") {
            return (Theme.colors && Theme.colors.warning) ? Theme.colors.warning : "#f2b866";
        }
        return Theme.accent || "#7aa2f7";
    }

    function triggerAction(idx) {
        if (idx >= 0 && idx < actionsList.length) {
            Quickshell.execDetached(["sh", "-c", actionsList[idx].cmd]);
            root.collapseToIdle();
        }
    }

    Keys.onLeftPressed: (event) => {
        currentIndex = (currentIndex - 1 + actionsList.length) % actionsList.length;
        event.accepted = true;
    }
    Keys.onRightPressed: (event) => {
        currentIndex = (currentIndex + 1) % actionsList.length;
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

    // Direct keyboard accelerators: L=Lock, S=Sleep, E=Logout, R=Reboot, P=Power Off
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

    component MatusIcon: Text {
        property bool filled: false
        property int weightAxis: 500
        font.family: Theme.fontFamilyIcon
        font.pixelSize: 20
        font.variableAxes: ({
            "FILL": filled ? 1 : 0,
            "GRAD": Theme.fontIconGrad,
            "opsz": 24,
            "wght": weightAxis
        })
        renderType: Text.CurveRendering
        font.hintingPreference: Font.PreferNoHinting
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    component MatusLabel: Text {
        property int weightAxis: 560
        font.family: "Google Sans Flex"
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.variableAxes: ({ "wght": weightAxis })
        renderType: Text.QtRendering
        font.hintingPreference: Font.PreferNoHinting
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 0

        // Back button to previous panel or idle
        Rectangle {
            id: backBtn
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            radius: 16
            color: backMouse.pressed
                ? Qt.alpha(Theme.text, 0.16)
                : (backMouse.containsMouse ? Qt.alpha(Theme.text, 0.11) : Qt.alpha(Theme.text, 0.06))
            scale: backMouse.pressed ? 0.92 : 1.0

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            MatusIcon {
                anchors.centerIn: parent
                text: "arrow_back"
                font.pixelSize: 17
                filled: backMouse.containsMouse
                color: backMouse.containsMouse ? Theme.text : Qt.alpha(Theme.text, 0.78)
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var target = (root.previousExpandedMode && root.previousExpandedMode !== "powermenu")
                        ? root.previousExpandedMode : "idle";
                    if (target === "idle") root.collapseToIdle();
                    else root.switchMode(target, true);
                }
            }
        }

        Item { Layout.preferredWidth: 10 }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
            color: Qt.alpha(Theme.text, 0.10)
        }

        Item { Layout.preferredWidth: 12 }

        // 5 balanced Matushell squircle tiles (hold 400ms or Enter/shortcut to trigger)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Repeater {
                model: powerMenu.actionsList

                delegate: Rectangle {
                    id: tile
                    required property int index
                    required property var modelData

                    readonly property bool isFocused: powerMenu.currentIndex === index
                    readonly property bool isHot: isFocused || tileMouse.containsMouse
                    readonly property bool isDanger: modelData.role === "danger"
                    readonly property color roleColor: powerMenu.colorForRole(modelData.role)
                    property real progress: 0.0
                    readonly property bool isCharging: progress > 0.001

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    clip: true

                    color: tileMouse.pressed
                        ? Qt.alpha(roleColor, 0.24)
                        : (isHot
                            ? Qt.alpha(roleColor, 0.14)
                            : (isDanger ? Qt.alpha(roleColor, 0.07) : Qt.alpha(Theme.text, 0.06)))
                    border.width: 1
                    border.color: isCharging
                        ? Qt.alpha(roleColor, 0.72)
                        : (isHot
                            ? Qt.alpha(roleColor, 0.42)
                            : (isDanger ? Qt.alpha(roleColor, 0.16) : Qt.alpha(Theme.text, 0.06)))
                    scale: tileMouse.pressed ? 0.96 : 1.0

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 130 } }
                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

                    NumberAnimation on progress {
                        id: chargeAnim
                        from: 0.0
                        to: 1.0
                        duration: 400
                        running: false
                        onFinished: {
                            if (tile.progress >= 1.0) {
                                powerMenu.triggerAction(tile.index);
                            }
                        }
                    }

                    // Bottom-up tonal hold progress wash
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * tile.progress
                        visible: tile.isCharging
                        color: Qt.alpha(tile.roleColor, 0.22)
                    }

                    // Bottom charging bar
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        height: 3
                        width: parent.width * tile.progress
                        visible: tile.isCharging
                        color: tile.roleColor
                    }

                    // Subtle keycap accelerator in top-right corner
                    MatusLabel {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 6
                        anchors.rightMargin: 8
                        text: tile.modelData.keyHint
                        font.pixelSize: 9
                        weightAxis: 620
                        color: tile.isHot ? Qt.alpha(tile.roleColor, 0.90) : Qt.alpha(Theme.text, 0.32)

                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 2
                        spacing: 5

                        MatusIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.icon
                            font.pixelSize: 22
                            filled: tile.isHot || tile.isCharging
                            weightAxis: tile.isHot ? 550 : 480
                            color: (tile.isHot || tile.isDanger)
                                ? tile.roleColor
                                : Qt.alpha(Theme.text, 0.86)
                            scale: tileMouse.pressed ? 0.94 : (tile.isHot ? 1.06 : 1.0)

                            Behavior on color { ColorAnimation { duration: 130 } }
                            Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        }

                        MatusLabel {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.label
                            font.pixelSize: 11
                            weightAxis: tile.isHot ? 620 : 540
                            color: tile.isHot
                                ? Theme.text
                                : (tile.isDanger ? Qt.alpha(tile.roleColor, 0.90) : Qt.alpha(Theme.text, 0.72))

                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: powerMenu.currentIndex = tile.index
                        onPressed: {
                            powerMenu.currentIndex = tile.index;
                            tile.progress = 0.0;
                            chargeAnim.restart();
                        }
                        onReleased: {
                            chargeAnim.stop();
                            tile.progress = 0.0;
                        }
                        onCanceled: {
                            chargeAnim.stop();
                            tile.progress = 0.0;
                        }
                    }
                }
            }
        }
    }
}
