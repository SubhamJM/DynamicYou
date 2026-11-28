pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "."

// Post-snip preview toast; sits bottom-left by default and flips to the bottom-right
// when notification popups occupy the bottom-left corner (MatusConfig.appearance.notifPosition)
PanelWindow {
    id: root

    // --- Public API ---
    property bool previewOpen: false
    property int snipEpoch: 0
    property int snipWidth: 0
    property int snipHeight: 0
    property string cropPath: ""

    // --- Local State ---
    property bool isHiding: false
    property bool entered: false

    readonly property bool active: root.previewOpen || root.isHiding
    readonly property bool isHovered: cardHoverSink.containsMouse || saveMa.containsMouse || editBtn.hovered || dismissMa.containsMouse

    // --- Layout & Geometry ---
    readonly property bool flipRight: MatusConfig.appearance.notifPosition === "bottom-left"
    readonly property bool isBarBottom: MatusConfig.bar.position === "bottom"
    readonly property bool isVerticalBar: MatusConfig.bar.position === "left" || MatusConfig.bar.position === "right"
    readonly property bool isLeftBar: MatusConfig.bar.position === "left"
    // BarGeometry is always instantiated by BarContent; barContent is null only in the startup race, so these fall back to the pre-geometry gate there (same null-bar fallback as OsdPanelWindow).
    readonly property var barGeometry: (MatusOverlays.barContent && MatusOverlays.barContent.geometry) ? MatusOverlays.barContent.geometry : null
    readonly property bool dynamicIslandPillActive: root.barGeometry ? root.barGeometry.isDynamicIslandPill : (MatusConfig.bar.island.enabled && MatusConfig.bar.islandStyle !== "notch" && (MatusConfig.bar.mode === "transparent" || (MatusConfig.bar.mode === "float" && MatusConfig.bar.floatStyle === "isolated")))
    readonly property real dynamicIslandFarEdge: root.barGeometry ? root.barGeometry.dynamicIslandFarEdge : (MatusConfig.bar.island.edgeMargin + Math.floor(Theming.barPadding / 2) + (Theming.barHeight + Theming.islandHeight) / 2)
    readonly property int barClearance: isBarBottom ? Math.round(Math.max(Theming.barHeight + Theming.barPadding + ((MatusConfig.bar.mode === "float" || MatusConfig.bar.mode === "transparent") ? MatusConfig.bar.floatEdgeMargin : 0), root.dynamicIslandPillActive ? root.dynamicIslandFarEdge : 0)) : 0
    // No frame term here: edgeMargin already adds it, so the gap beyond the
    // side bar matches the bottom-bar gap (barClearance omits frame too).
    readonly property int sideBarClearance: isVerticalBar ? Math.round(Theming.barHeight + Theming.barPadding + ((MatusConfig.bar.mode === "float" || MatusConfig.bar.mode === "transparent") ? MatusConfig.bar.floatEdgeMargin : 0)) : 0
    // Window width must include the side-bar gap when the preview is anchored
    // on the same side as the bar, otherwise the card overflows the window.
    readonly property int sideBarClearancePadding: (isVerticalBar && ((!root.flipRight && root.isLeftBar) || (root.flipRight && !root.isLeftBar))) ? root.sideBarClearance : 0
    readonly property int edgeMargin: Theming.spacingLg + (MatusConfig.bar.mode === "connected" ? MatusConfig.bar.connectedFrameThickness : 0)
    readonly property int bottomMargin: root.edgeMargin + root.barClearance
    readonly property int overshootBuffer: 40 * Theming.paddingMultiplier
    readonly property int maxPreviewWidth: Math.round(320 * Theming.paddingMultiplier)
    readonly property int maxPreviewHeight: Math.round(220 * Theming.paddingMultiplier)
    readonly property int cardSpacing: Math.round(8 * Theming.spacingMultiplier)
    readonly property int borderWidth: Math.round(2 * Theming.paddingMultiplier)
    readonly property real previewAspect: (root.snipWidth > 0 && root.snipHeight > 0) ? (root.snipWidth / root.snipHeight) : (16 / 9)
    readonly property int previewW: Math.round(Math.min(maxPreviewWidth, maxPreviewHeight * previewAspect))
    readonly property int previewH: Math.round(previewW / previewAspect)
    readonly property int editBtnSize: Math.round(54 * Theming.paddingMultiplier)
    readonly property int toolbarBtnHeight: Math.round(44 * Theming.paddingMultiplier)
    readonly property int toolbarPadding: Math.round(6 * Theming.paddingMultiplier)
    readonly property int toolbarSpacing: Math.round(8 * Theming.spacingMultiplier)
    readonly property int toolbarH: toolbarBtnHeight + toolbarPadding * 2

    // --- Signals ---
    signal saveRequested
    signal editRequested
    signal dismissRequested

    // Emitted when the exit animation completes (destroy-on-close).
    signal closeFinished

    // --- Window Settings ---
    visible: root.active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.namespace: "matushell:snippreview"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.bottom: true
    anchors.left: !root.flipRight
    anchors.right: root.flipRight
    margins.left: 0
    margins.right: 0
    margins.bottom: root.bottomMargin

    implicitWidth: card.implicitWidth + root.edgeMargin + root.overshootBuffer + root.sideBarClearancePadding
    implicitHeight: card.implicitHeight

    mask: Region {
        item: card
    }

    onPreviewOpenChanged: {
        if (root.previewOpen) {
            hideTimer.stop()
            root.isHiding = false
        } else {
            root.isHiding = true
            hideTimer.restart()
        }
    }

    Component.onCompleted: Qt.callLater(function () {
        if (root.previewOpen)
            root.entered = true
    })

    // Graceful Teardown Timer
    Timer {
        id: hideTimer

        interval: MatusMotion.durationDefaultSpatial + 50
        onTriggered: {
            root.isHiding = false
            root.closeFinished()
        }
    }

    // Auto-dismiss timer (pauses on hover)
    Timer {
        interval: 6000
        running: root.previewOpen && !root.isHovered
        onTriggered: root.dismissRequested()
    }

    // Preview container sliding horizontally from screen edge
    Item {
        id: card

        width: implicitWidth
        height: implicitHeight
        implicitWidth: Math.max(root.previewW + root.borderWidth * 2, toolbarContainer.Layout.preferredWidth + root.editBtnSize + Math.round(8 * Theming.paddingMultiplier))
        implicitHeight: root.previewH + root.borderWidth * 2 + root.cardSpacing + root.toolbarH

        x: (root.previewOpen && root.entered) ? (root.flipRight ? parent.width - width - root.edgeMargin - (root.isVerticalBar && !root.isLeftBar ? root.sideBarClearance : 0) : root.edgeMargin + (root.isVerticalBar && root.isLeftBar ? root.sideBarClearance : 0)) : (root.flipRight ? parent.width + Theming.spacingLg : -width - Theming.spacingLg)

        Behavior on x {
            MatusAnim {
                type: MatusAnim.DefaultSpatial
            }
        }

        MouseArea {
            id: cardHoverSink

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: root.cardSpacing

            // Top screenshot preview card with outer accent border
            Item {
                Layout.preferredWidth: root.previewW + root.borderWidth * 2
                Layout.preferredHeight: root.previewH + root.borderWidth * 2
                Layout.alignment: Qt.AlignLeft

                // Outer border/frame background
                Rectangle {
                    id: outerFrame

                    anchors.fill: parent
                    radius: Theming.radiusLg
                    color: Theming.mix(Theming.primaryContainer, Theming.primary, 0.4)
                }

                // Dedicated background rectangle for base transparency
                Rectangle {
                    id: imageCardBg

                    anchors.fill: parent
                    anchors.margins: root.borderWidth
                    radius: Math.max(0, Theming.radiusLg - root.borderWidth)
                    color: Theming.surfaceContainer
                    opacity: MatusConfig.appearance.baseTransparency
                }

                // Masked screenshot crop
                ClippingRectangle {
                    id: imageCropWrapper

                    anchors.fill: parent
                    anchors.margins: root.borderWidth
                    radius: Math.max(0, Theming.radiusLg - root.borderWidth)
                    color: "transparent"

                    Image {
                        id: thumbImage

                        anchors.fill: parent
                        source: (root.cropPath !== "" && root.snipEpoch > 0 && (root.previewOpen || root.isHiding)) ? "file://" + root.cropPath + "?t=" + root.snipEpoch : ""
                        sourceSize: Qt.size(root.previewW * 2, root.previewH * 2)
                        cache: false
                        asynchronous: true // dont block UI thread
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: status === Image.Ready
                        onStatusChanged: {
                            if (status === Image.Error)
                                MatusLogger.error("Snip", "Preview image failed to load: " + source)
                        }
                    }
                }
            }

            // Bottom toolbar pill container
            Item {
                id: toolbarContainer

                Layout.preferredHeight: root.toolbarH
                Layout.preferredWidth: toolbarRow.implicitWidth + root.toolbarPadding * 2
                Layout.alignment: Qt.AlignLeft

                // Dedicated background rectangle for base transparency & shadow
                Rectangle {
                    id: toolbarBg

                    anchors.fill: parent
                    radius: height / 2
                    color: Theming.surfaceContainer
                    opacity: MatusConfig.appearance.baseTransparency
                }

                RowLayout {
                    id: toolbarRow

                    anchors.fill: parent
                    anchors.margins: root.toolbarPadding
                    spacing: root.toolbarSpacing

                    // Save extended pill button
                    Rectangle {
                        id: saveBtn

                        Layout.preferredHeight: root.toolbarBtnHeight
                        implicitWidth: saveRow.implicitWidth + Math.round(24 * Theming.paddingMultiplier)
                        radius: root.toolbarBtnHeight / 2
                        color: saveMa.pressed ? Theming.mix(Theming.primaryContainer, Theming.primaryContainerOn, 0.75) : (saveMa.containsMouse ? Theming.mix(Theming.primaryContainer, Theming.primaryContainerOn, 0.88) : Theming.primaryContainer)

                        Behavior on color {
                            MatusColorAnim {
                                type: MatusAnim.FastEffects
                            }
                        }

                        RowLayout {
                            id: saveRow

                            anchors.centerIn: parent
                            spacing: Theming.spacingSm

                            MatusIcon {
                                text: "save"
                                font.pixelSize: Theming.iconSize
                                color: Theming.primaryContainerOn
                            }

                            MatusText {
                                text: "Save"
                                size: Theming.fontSizeNormal
                                weight: MatusText.Weight.DemiBold
                                color: Theming.primaryContainerOn
                            }
                        }

                        MouseArea {
                            id: saveMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.saveRequested()
                        }
                    }

                    // Dismiss button
                    Rectangle {
                        id: dismissBtn

                        Layout.preferredWidth: root.toolbarBtnHeight
                        Layout.preferredHeight: root.toolbarBtnHeight
                        radius: root.toolbarBtnHeight / 2
                        color: dismissMa.containsMouse ? Theming.withAlpha(Theming.error, Theming.opacityHover) : Theming.withAlpha(Theming.surfaceContainerHighest, MatusConfig.appearance.layerTransparency)

                        MatusIcon {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: Theming.iconSize
                            color: dismissMa.containsMouse ? Theming.error : Theming.surfaceOn
                        }

                        MouseArea {
                            id: dismissMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dismissRequested()
                        }
                    }
                }

                // Edit button (opens swappy)
                MatusIconButton {
                    id: editBtn

                    anchors.left: toolbarContainer.right
                    anchors.leftMargin: Math.round(8 * Theming.paddingMultiplier)
                    anchors.verticalCenter: toolbarContainer.verticalCenter
                    onClicked: root.editRequested()

                    // Matches fab menu
                    buttonSize: root.editBtnSize
                    iconName: "edit"
                    restShape: MaterialShape.Shape.Circle
                    morphShape: MaterialShape.Shape.Square
                    engage: MatusIconButton.Engage.Morph
                    bgColor: hovered ? Theming.primary : Theming.primaryContainer
                    hoverColor: hovered ? Theming.mix(Theming.primaryOn, Theming.primary, Theming.opacityHover) : Theming.mix(Theming.primaryContainerOn, Theming.primaryContainer, Theming.opacityHover)
                    iconColor: hovered ? Theming.primaryOn : Theming.primaryContainerOn
                    rippleColor: hovered ? Theming.primaryOn : Theming.primary
                }
            }
        }
    }
}
