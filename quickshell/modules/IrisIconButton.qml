import QtQuick
import "../"

// Modular, high-performance icon button inspired by MatusIconButton
// Features:
// - Stateful interactive touch feedback (hover scale, press spring)
// - Active / toggled mode with accent container styling
// - Spinning animator for loading / WiFi scanning
// - Variable font Material Symbols + App Icon theme integration
// - Fast color transitions with zero frame drops
Rectangle {
    id: root

    // --- Public API ---
    property string glyph: ""
    property string icon: glyph
    property real iconSize: (typeof Theme !== "undefined" && Theme.iconSize) ? Theme.iconSize : 18
    property real glyphSize: iconSize
    property real fill: 0
    property bool active: false
    property bool flat: false
    property bool clickable: true
    property bool enabled: clickable
    property bool spinning: false
    property int spinDuration: 900
    property string fallbackSymbol: "apps"

    property real buttonSize: (typeof Theme !== "undefined" && Theme.iconBtnSize) ? Theme.iconBtnSize : 34
    property real buttonRadius: height / 2

    // Color tokens
    property color iconColor: root.active && !root.flat
        ? (Theme.colors.bg ?? "#000000")
        : (Theme.colors.text_primary ?? "#ffffff")
    property color activeIconColor: Theme.colors.bg ?? "#000000"
    property var hoverIconColor: null

    property color backgroundColor: root.flat
        ? "transparent"
        : (root.active ? (Theme.accent ?? "#7aa2f7") : Qt.rgba(255, 255, 255, 0.06))
    property color backgroundHoverColor: root.flat
        ? Qt.rgba(255, 255, 255, 0.10)
        : (root.active ? Qt.lighter(Theme.accent ?? "#7aa2f7", 1.1) : Qt.rgba(255, 255, 255, 0.12))
    property color backgroundPressedColor: root.flat
        ? Qt.rgba(255, 255, 255, 0.18)
        : (root.active ? Qt.darker(Theme.accent ?? "#7aa2f7", 1.1) : Qt.rgba(255, 255, 255, 0.20))

    signal clicked()
    signal rightClicked()

    implicitWidth: buttonSize
    implicitHeight: buttonSize
    radius: buttonRadius

    // Background color resolution with smooth transition
    color: {
        if (!root.clickable || !root.enabled) return Qt.rgba(255, 255, 255, 0.03);
        if (mouseArea.pressed) return root.backgroundPressedColor;
        if (mouseArea.containsMouse) return root.backgroundHoverColor;
        return root.backgroundColor;
    }

    Behavior on color {
        ColorAnimation { duration: (typeof Theme !== "undefined" && Theme.animFast) ? Theme.animFast : 100 }
    }

    // Interactive scale feedback (spring compression on click, subtle lift on hover)
    scale: (!root.clickable || !root.enabled) ? 1.0 : (mouseArea.pressed ? 0.92 : (mouseArea.containsMouse ? 1.04 : 1.0))
    Behavior on scale {
        NumberAnimation {
            duration: (typeof Theme !== "undefined" && Theme.animFast) ? Theme.animFast : 100
            easing.type: Easing.OutQuad
        }
    }

    // Smart Iris Icon child
    IrisIcon {
        id: iconItem
        anchors.centerIn: parent
        icon: root.icon !== "" ? root.icon : root.glyph
        iconSize: root.iconSize
        fill: root.fill
        color: {
            if (!root.clickable || !root.enabled) return Qt.rgba(255, 255, 255, 0.3);
            if (mouseArea.containsMouse && root.hoverIconColor !== null) return root.hoverIconColor;
            if (root.active && !root.flat) return root.activeIconColor;
            return root.iconColor;
        }
        spinning: root.spinning
        spinDuration: root.spinDuration
        fallbackSymbol: root.fallbackSymbol
    }

    // Press highlight
    Rectangle {
        id: pressHighlight
        anchors.fill: parent
        radius: root.radius
        color: root.active ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(255, 255, 255, 0.16)
        opacity: mouseArea.pressed ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.clickable && root.enabled
        cursorShape: (root.clickable && root.enabled) ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked();
            } else {
                root.clicked();
            }
        }
    }
}
