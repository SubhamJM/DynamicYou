pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

// MatusFabMenu — Material 3 Expressive Speed Dial FAB Menu
Item {
    id: root

    // --- Public API ---
    property var model: []
    property bool expanded: false
    property string iconName: "menu"
    property int fabSize: Math.round(52 * Theming.paddingMultiplier)
    property int miniFabSize: Math.round(40 * Theming.paddingMultiplier)
    property int restShape: MaterialShape.Shape.Circle
    property int morphShape: MaterialShape.Shape.Square
    property int itemHeight: Math.round(38 * Theming.paddingMultiplier)
    property int buttonSize: MatusButton.Size.M
    property bool enableScrim: false
    property color scrimColor: Theming.withAlpha(Theming.scrim, Theming.opacityScrim)

    // Menu overlay extents for consumer reservation
    readonly property real menuWidth: menuCol.implicitWidth
    readonly property real menuHeight: menuCol.implicitHeight

    signal selected(int index)

    implicitWidth: fab.width
    implicitHeight: fab.height

    // Optional click-outside dismiss scrim
    Rectangle {
        id: scrim

        visible: root.enableScrim && opacity > 0
        opacity: root.expanded ? 1.0 : 0.0
        color: root.scrimColor
        radius: Theming.radius

        anchors.fill: parent

        Behavior on opacity {
            MatusAnim {
                type: MatusAnim.FastEffects
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = false
        }
    }

    // Main FAB button
    MatusIconButton {
        id: fab

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        buttonSize: root.fabSize
        iconSize: Theming.iconSizeMd
        iconName: root.expanded ? "close" : root.iconName
        bgColor: root.expanded ? Theming.primary : Theming.primaryContainer
        hoverColor: root.expanded ? Theming.mix(Theming.primaryOn, Theming.primary, Theming.opacityHover) : Theming.mix(Theming.primaryContainerOn, Theming.primaryContainer, Theming.opacityHover)
        iconColor: root.expanded ? Theming.primaryOn : Theming.primaryContainerOn
        rippleColor: root.expanded ? Theming.primaryOn : Theming.primary
        restShape: root.restShape
        morphShape: root.morphShape
        engage: MatusIconButton.Engage.Morph
        active: root.expanded
        onClicked: root.expanded = !root.expanded
    }

    // Expanding Speed Dial Menu (mini-FABs + floating pill labels)
    ColumnLayout {
        id: menuCol

        anchors.right: fab.right
        anchors.bottom: fab.top
        anchors.bottomMargin: Theming.spacingMd
        spacing: Theming.spacingSm
        enabled: root.expanded

        Repeater {
            id: menuRepeater

            model: root.model

            FabMenuItem {
                Layout.alignment: Qt.AlignRight
            }
        }
    }

    component FabMenuItem: Item {
        id: menuItem

        required property var modelData
        required property int index

        readonly property string itemLabel: typeof modelData === "string" ? modelData : (modelData.label ?? "")
        readonly property string itemIcon: typeof modelData === "object" && modelData.icon ? modelData.icon : ""
        readonly property bool isHovered: itemMouse.containsMouse
        property real offsetY: root.expanded ? 0 : Math.round(12 * Theming.paddingMultiplier)

        implicitWidth: itemRow.implicitWidth
        implicitHeight: Math.max(root.itemHeight, root.miniFabSize)

        opacity: root.expanded ? 1.0 : 0.0
        scale: root.expanded ? 1.0 : 0.3
        transformOrigin: Item.BottomRight
        visible: opacity > 0

        transform: Translate {
            y: menuItem.offsetY
        }

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.expanded ? (menuRepeater.count - 1 - menuItem.index) * 40 : menuItem.index * 30
                }
                MatusAnim {
                    type: MatusAnim.FastEffects
                }
            }
        }

        Behavior on scale {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.expanded ? (menuRepeater.count - 1 - menuItem.index) * 40 : menuItem.index * 30
                }
                MatusAnim {
                    type: MatusAnim.FastSpatial
                }
            }
        }

        Behavior on offsetY {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.expanded ? (menuRepeater.count - 1 - menuItem.index) * 40 : menuItem.index * 30
                }
                MatusAnim {
                    type: MatusAnim.FastSpatial
                }
            }
        }

        MouseArea {
            id: itemMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function (mouse) {
                const pt = itemMouse.mapToItem(miniFab, mouse.x, mouse.y)
                miniRipple.triggerRipple(pt.x, pt.y)
            }
            onClicked: {
                root.expanded = false
                root.selected(menuItem.index)
            }
        }

        RowLayout {
            id: itemRow

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theming.spacingSm

            // Floating pill label
            Rectangle {
                id: labelPill

                visible: menuItem.itemLabel !== ""
                implicitHeight: Math.round(32 * Theming.paddingMultiplier)
                implicitWidth: labelText.implicitWidth + Theming.spacingLg * 2
                radius: height / 2

                color: menuItem.isHovered ? Theming.mix(Theming.surfaceOn, Theming.surfaceContainerHigh, Theming.opacityHover) : Theming.surfaceContainerHigh

                Behavior on color {
                    MatusColorAnim {
                        type: MatusAnim.FastEffects
                    }
                }

                MatusText {
                    id: labelText

                    anchors.centerIn: parent
                    text: menuItem.itemLabel
                    size: Theming.fontSizeSmall
                    weight: MatusText.Weight.DemiBold
                    color: Theming.surfaceOn
                }
            }

            // Mini-FAB circle
            Rectangle {
                id: miniFab

                implicitWidth: root.miniFabSize
                implicitHeight: root.miniFabSize
                radius: height / 2

                color: menuItem.isHovered ? Theming.mix(Theming.primaryOn, Theming.primary, Theming.opacityHover) : Theming.primary

                Behavior on color {
                    MatusColorAnim {
                        type: MatusAnim.FastEffects
                    }
                }

                MatusIcon {
                    anchors.centerIn: parent
                    text: menuItem.itemIcon
                    font.pixelSize: Theming.iconSizeSm
                    color: Theming.primaryOn
                    fill: 1
                }

                MatusRipple {
                    id: miniRipple

                    anchors.fill: parent
                    rippleColor: Theming.primaryOn
                    cornerRadius: parent.radius
                }
            }
        }
    }
}
