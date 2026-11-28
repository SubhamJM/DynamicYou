pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

// MatusButton — Material 3 Expressive Action Button
// General-purpose action button with dynamic sizing presets, squircle-to-pill
// corner morphing, tactile hover nudge, and smooth spatial transitions.
Rectangle {
    id: root

    enum Size {
        XXS,
        XS,
        S,
        M,
        L,
        XL
    }

    // --- Public API ---
    property string iconName: ""
    property string text: ""
    property bool active: false
    property bool showIcon: true
    property bool showText: true
    property int textAlignment: Text.AlignLeft
    property int size: MatusButton.Size.M
    property var customColor: null
    property var customTextColor: null
    property real iconFill: root.active ? 1 : 0
    property bool nudgeOnHover: true
    property real hoverScale: 1.02
    property real pressScale: 0.97
    property real nudgeY: Math.round(-1.5 * Theming.paddingMultiplier)
    property var tone: null
    readonly property alias hovered: ma.containsMouse

    // Sizing presets lookup table: height, iconSize, fontSize, pressedRadius, squareRadius
    readonly property var sizeMetrics: ({
            [MatusButton.Size.XXS]: {
                height: Math.round(28 * Theming.paddingMultiplier),
                icon: Math.round(14 * Theming.fontMultiplier),
                font: Theming.fontSizeSmallie,
                pressedRadius: Math.round(4 * Theming.radiusMultiplier),
                squareRadius: Math.round(8 * Theming.radiusMultiplier)
            },
            [MatusButton.Size.XS]: {
                height: Math.round(32 * Theming.paddingMultiplier),
                icon: Theming.iconSizeSm,
                font: Theming.fontSizeSmallie,
                pressedRadius: Math.round(4 * Theming.radiusMultiplier),
                squareRadius: Math.round(8 * Theming.radiusMultiplier)
            },
            [MatusButton.Size.S]: {
                height: Math.round(36 * Theming.paddingMultiplier),
                icon: Theming.iconSizeSm,
                font: Theming.fontSizeSmall,
                pressedRadius: Math.round(4 * Theming.radiusMultiplier),
                squareRadius: Math.round(8 * Theming.radiusMultiplier)
            },
            [MatusButton.Size.M]: {
                height: Math.round(40 * Theming.paddingMultiplier),
                icon: Theming.iconSizeSm,
                font: Theming.fontSizeSmall,
                pressedRadius: Math.round(6 * Theming.radiusMultiplier),
                squareRadius: Math.round(10 * Theming.radiusMultiplier)
            },
            [MatusButton.Size.L]: {
                height: Math.round(48 * Theming.paddingMultiplier),
                icon: Theming.iconSize,
                font: Theming.fontSizeNormal,
                pressedRadius: Math.round(8 * Theming.radiusMultiplier),
                squareRadius: Math.round(12 * Theming.radiusMultiplier)
            },
            [MatusButton.Size.XL]: {
                height: Math.round(56 * Theming.paddingMultiplier),
                icon: Theming.iconSizeMd,
                font: Theming.fontSizeLarge,
                pressedRadius: Math.round(8 * Theming.radiusMultiplier),
                squareRadius: Math.round(12 * Theming.radiusMultiplier)
            }
        })
    readonly property var currentMetrics: sizeMetrics[root.size] ?? sizeMetrics[MatusButton.Size.M]
    readonly property var effTone: root.tone ?? QsWindow.window?.currentTone ?? null

    readonly property real sizeHeight: currentMetrics.height
    readonly property real sizeIconSize: currentMetrics.icon
    readonly property real sizeFontSize: currentMetrics.font
    readonly property real pressedRadius: currentMetrics.pressedRadius
    readonly property real squareRadius: currentMetrics.squareRadius

    property real buttonHeight: root.sizeHeight
    property real iconSize: root.sizeIconSize
    property bool ready: false
    readonly property real contentWidth: contentRow.implicitWidth + Theming.spacingLg * 2
    readonly property real stateOpacity: ma.containsPress ? Theming.opacityPress : ma.containsMouse ? Theming.opacityHover : 0
    readonly property real targetRadius: {
        if (ma.containsPress)
            return root.pressedRadius

        if (root.active)
            return root.squareRadius

        return root.height / 2
    }

    signal clicked

    implicitHeight: root.buttonHeight
    implicitWidth: root.contentWidth
    topLeftRadius: root.targetRadius
    topRightRadius: root.targetRadius
    bottomLeftRadius: root.targetRadius
    bottomRightRadius: root.targetRadius
    color: root.customColor !== null ? root.customColor : (root.active ? (root.effTone ? root.effTone.acc : Theming.primary) : (root.effTone ? root.effTone.well : Theming.withAlpha(Theming.surfaceContainerHigh, MatusConfig.appearance.layerTransparency)))
    opacity: root.enabled ? 1 : Theming.opacityDisabled
    scale: (root.nudgeOnHover && root.enabled) ? (ma.containsPress ? root.pressScale : (ma.containsMouse ? root.hoverScale : 1.0)) : 1.0
    transformOrigin: Item.Center

    Component.onCompleted: Qt.callLater(() => root.ready = true)

    transform: Translate {
        y: (root.nudgeOnHover && root.enabled) ? (ma.containsPress ? Math.round(1 * Theming.paddingMultiplier) : (ma.containsMouse ? root.nudgeY : 0)) : 0

        Behavior on y {
            MatusAnim {
                type: MatusAnim.FastSpatial
            }
        }
    }

    Behavior on scale {
        MatusAnim {
            type: MatusAnim.FastSpatial
        }
    }

    Behavior on color {
        MatusColorAnim {
            type: MatusAnim.FastEffects
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.topLeftRadius
        color: {
            var baseColor = root.customTextColor !== null ? root.customTextColor : (root.active ? (root.effTone ? root.effTone.accOn : Theming.primaryOn) : (root.effTone ? root.effTone.on : Theming.surfaceOn))
            return Theming.withAlpha(baseColor, root.stateOpacity)
        }

        Behavior on color {
            MatusColorAnim {
                type: MatusAnim.FastEffects
            }
        }
    }

    MatusRipple {
        id: ripple

        anchors.fill: parent
        cornerRadius: root.topLeftRadius
        rippleColor: root.customTextColor !== null ? root.customTextColor : (root.active ? (root.effTone ? root.effTone.accOn : Theming.primaryOn) : (root.effTone ? root.effTone.on : Theming.surfaceOn))
    }

    RowLayout {
        id: contentRow

        anchors.fill: parent
        anchors.leftMargin: Theming.spacingLg
        anchors.rightMargin: Theming.spacingLg
        spacing: Theming.spacingSm
        z: 1

        Item {
            id: leftSpacer

            Layout.fillWidth: true
            visible: root.textAlignment === Text.AlignHCenter || root.textAlignment === Text.AlignRight || (!root.showText || root.text === "")
        }

        Item {
            id: iconContainer

            visible: root.showIcon && root.iconName !== ""
            implicitWidth: root.iconSize
            Layout.fillHeight: true

            MatusIcon {
                id: iconText

                anchors.centerIn: parent
                text: root.iconName
                fill: root.iconFill
                color: root.customTextColor !== null ? root.customTextColor : (root.active ? (root.effTone ? root.effTone.accOn : Theming.primaryOn) : (root.effTone ? root.effTone.on : Theming.surfaceVariantOn))
                font.pixelSize: root.iconSize

                Behavior on color {
                    MatusColorAnim {
                        type: MatusAnim.FastEffects
                    }
                }

                Behavior on fill {
                    MatusAnim {
                        type: MatusAnim.FastSpatial
                    }
                }
            }
        }

        MatusText {
            id: labelText

            visible: root.showText && root.text !== ""
            text: root.text
            color: root.customTextColor !== null ? root.customTextColor : (root.active ? (root.effTone ? root.effTone.accOn : Theming.primaryOn) : (root.effTone ? root.effTone.on : Theming.surfaceOn))
            size: root.sizeFontSize
            weight: MatusText.Weight.DemiBold
            Layout.fillHeight: true
            elide: Text.ElideRight

            Behavior on color {
                MatusColorAnim {
                    type: MatusAnim.FastEffects
                }
            }
        }

        Item {
            id: rightSpacer

            Layout.fillWidth: true
            visible: root.textAlignment === Text.AlignHCenter || root.textAlignment === Text.AlignLeft || (!root.showText || root.text === "")
        }
    }

    MouseArea {
        id: ma

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: function (mouse) {
            ripple.triggerRipple(mouse.x, mouse.y)
        }
        onClicked: root.clicked()
    }

    Behavior on topLeftRadius {
        MatusAnim {
            type: MatusAnim.FastSpatial
        }
    }

    Behavior on topRightRadius {
        MatusAnim {
            type: MatusAnim.FastSpatial
        }
    }

    Behavior on bottomLeftRadius {
        MatusAnim {
            type: MatusAnim.FastSpatial
        }
    }

    Behavior on bottomRightRadius {
        MatusAnim {
            type: MatusAnim.FastSpatial
        }
    }

    // Width morphs are utilitarian layout shifts — standard family, no bounce.
    Behavior on implicitWidth {
        enabled: root.ready

        MatusAnim {
            type: MatusAnim.StandardSmall
        }
    }
}
