import QtQuick
import "."

Item {
    id: root

    property color rippleColor: Theming.primary
    // Uniform radius fallback for hosts with a single corner radius.
    property real cornerRadius: 0
    // Optional per-corner radii (uniform-radius hosts only set cornerRadius).
    // Unset corners fall back to cornerRadius, keeping existing usages valid.
    property real topLeftRadius: root.cornerRadius
    property real topRightRadius: root.cornerRadius
    property real bottomLeftRadius: root.cornerRadius
    property real bottomRightRadius: root.cornerRadius
    property bool rippleEnabled: true
    readonly property alias running: rippleAnim.running
    property real _rippleMaxRadius: 0
    // Guard against duplicate press events synthesized during Wayland focus
    // transitions when a new window is mapped (QSG_RENDER_LOOP=threaded).
    property var _lastTriggerTime: 0

    function triggerRipple(px, py) {
        if (!root.rippleEnabled)
            return

        // Ignore duplicate triggers within 150ms of the previous one.
        var now = Date.now()
        if (now - root._lastTriggerTime < 150)
            return
        root._lastTriggerTime = now

        const d = (ox, oy) => {
            return ox * ox + oy * oy
        }
        rippleFx.rippleCenterX = px
        rippleFx.rippleCenterY = py
        _rippleMaxRadius = Math.sqrt(Math.max(d(px, py), d(px, root.height - py), d(root.width - px, py), d(root.width - px, root.height - py)))
        rippleAnim.restart()
    }

    ShaderEffect {
        id: rippleFx

        property real rippleCenterX: 0
        property real rippleCenterY: 0
        property real rippleRadius: 0
        property real rippleOpacity: 0
        property real widthPx: root.width
        property real heightPx: root.height
        property real radiusTL: root.topLeftRadius
        property real radiusTR: root.topRightRadius
        property real radiusBL: root.bottomLeftRadius
        property real radiusBR: root.bottomRightRadius
        property real offsetX: 0
        property real offsetY: 0
        property real parentWidth: root.width
        property real parentHeight: root.height
        property vector4d rippleCol: Qt.vector4d(root.rippleColor.r, root.rippleColor.g, root.rippleColor.b, 1)

        anchors.fill: parent
        visible: root.rippleEnabled && rippleAnim.running
        blending: true
        fragmentShader: Qt.resolvedUrl("../../shaders/ripple.frag.qsb")
    }

    SequentialAnimation {
        id: rippleAnim

        PropertyAction {
            target: rippleFx
            property: "rippleRadius"
            value: 0
        }

        PropertyAction {
            target: rippleFx
            property: "rippleOpacity"
            value: Theming.opacityPress
        }

        ParallelAnimation {
            NumberAnimation {
                target: rippleFx
                property: "rippleRadius"
                from: 0
                to: root._rippleMaxRadius
                duration: MatusMotion.durationLong2
                easing.type: Easing.OutQuad
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: MatusMotion.durationMedium2
                }

                NumberAnimation {
                    target: rippleFx
                    property: "rippleOpacity"
                    to: 0
                    duration: MatusMotion.durationLong2
                }
            }
        }
    }
}
