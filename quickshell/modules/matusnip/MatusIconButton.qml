import QtQuick
import Quickshell
import "."

Rectangle {
    id: root

    // --- Public API ---
    property string iconName: ""
    // Variable-font fill axis for the icon (0 outlined → 1 filled)
    property real iconFill: 0
    property bool active: false
    property int restShape: MaterialShape.Shape.Circle
    property int morphShape: MaterialShape.Shape.Cookie9Sided

    // Type of engage for the morph
    enum Engage {
        Leap,
        Morph
    }

    property int engage: MatusIconButton.Engage.Leap
    property int buttonSize: Theming.iconCircleSize
    property int iconSize: Theming.iconSizeSm
    property var bgColor: null
    property var hoverColor: null
    property bool flat: false
    property var tone: null
    property color iconColor: root.active && !root.flat ? (root.effTone ? root.effTone.accOn : Theming.primaryOn) : (root.effTone ? root.effTone.acc : Theming.primary)
    property var hoverIconColor: null
    property var rippleColor: null
    property alias iconRotation: iconText.rotation
    property bool spinning: false
    property bool clickable: true
    property bool leapOnActiveHover: false
    property bool nudgeOnHover: true
    property real hoverScale: 1.05
    property real pressScale: 0.94
    property real nudgeY: Math.round(-1.5 * Theming.paddingMultiplier)
    property alias hovered: ma.containsMouse

    // --- Local State ---
    readonly property var effTone: root.tone ?? QsWindow.window?.currentTone ?? null
    readonly property bool showCookie: (root.clickable && ma.containsMouse) || root.active

    signal clicked

    // Plays the leap animation if in Leap mode
    function triggerLeap() {
        if (root.engage === MatusIconButton.Engage.Morph)
            return
        if (!materialBg.springSettled)
            return
        materialBg.leapRotation = materialBg.leapStartAngle
        materialBg.springSettled = false
        materialSpringClock.restart()
    }

    // Morph + leap on every showCookie engage (hover/active) — steady-shape
    // buttons included, so inactive ones still spin on hover.
    onShowCookieChanged: {
        if (root.showCookie)
            root.triggerLeap()
    }

    // Active buttons never see a showCookie edge on hover — replay the leap
    // only if the consumer opted in.
    onHoveredChanged: {
        if (root.hovered && root.active && root.leapOnActiveHover)
            root.triggerLeap()
    }

    width: buttonSize
    height: buttonSize
    implicitWidth: buttonSize
    implicitHeight: buttonSize
    radius: width / 2
    color: "transparent"
    scale: (root.nudgeOnHover && root.clickable) ? (ma.containsPress ? root.pressScale : (ma.containsMouse ? root.hoverScale : 1.0)) : 1.0
    transformOrigin: Item.Center

    transform: Translate {
        y: (root.nudgeOnHover && root.clickable) ? (ma.containsPress ? Math.round(1 * Theming.paddingMultiplier) : (ma.containsMouse ? root.nudgeY : 0)) : 0

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

    MaterialShape {
        id: materialBg

        readonly property real stiffness: 180
        readonly property real dampingRatio: 0.99
        readonly property real visibilityThreshold: 0.005
        readonly property real leapStartAngle: -35
        readonly property real springWn: Math.sqrt(stiffness)
        readonly property real springWd: springWn * Math.sqrt(1 - dampingRatio * dampingRatio)
        readonly property real springZa: dampingRatio * springWn
        readonly property real springR: springZa / springWd
        readonly property real springDuration: Math.log(visibilityThreshold * Math.sqrt(1 - dampingRatio * dampingRatio)) / (-springZa)

        property real leapRotation: 0
        property bool springSettled: true

        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        visible: !root.flat
        shape: root.showCookie ? root.morphShape : root.restShape
        color: {
            if (root.active)
                return root.bgColor !== null ? root.bgColor : (root.effTone ? root.effTone.acc : Theming.primary)
            if (root.showCookie)
                return root.hoverColor !== null ? root.hoverColor : (root.bgColor !== null ? root.bgColor : (root.effTone ? root.effTone.bg : Theming.primaryContainer))
            return root.bgColor !== null ? root.bgColor : (root.effTone ? root.effTone.well : Theming.withAlpha(Theming.surfaceContainerHigh, MatusConfig.appearance.layerTransparency))
        }
        transformOrigin: Item.Center
        rotation: leapRotation

        Behavior on color {
            MatusColorAnim {
                type: MatusAnim.FastEffects
            }
        }

        ElapsedTimer {
            id: materialSpringClock
        }

        FrameAnimation {
            running: !materialBg.springSettled && materialBg.visible
            onTriggered: {
                const t = materialSpringClock.elapsed()
                if (t >= materialBg.springDuration) {
                    materialBg.leapRotation = 0
                    materialBg.springSettled = true
                    return
                }
                const decay = Math.exp(-materialBg.springZa * t)
                const pos = 1 - decay * (Math.cos(materialBg.springWd * t) + materialBg.springR * Math.sin(materialBg.springWd * t))
                materialBg.leapRotation = materialBg.leapStartAngle * (1 - pos)
            }
        }
    }

    MatusRipple {
        id: ripple

        anchors.fill: parent
        cornerRadius: root.radius
        // Per-corner overrides (Rectangle built-ins, 0 = unset) for hosts that
        // need seam-aware clipping; fall back to the uniform circle radius.
        topLeftRadius: root.topLeftRadius > 0 ? root.topLeftRadius : root.radius
        topRightRadius: root.topRightRadius > 0 ? root.topRightRadius : root.radius
        bottomLeftRadius: root.bottomLeftRadius > 0 ? root.bottomLeftRadius : root.radius
        bottomRightRadius: root.bottomRightRadius > 0 ? root.bottomRightRadius : root.radius
        rippleColor: root.rippleColor !== null ? root.rippleColor : (root.active ? (root.effTone ? root.effTone.accOn : Theming.primaryOn) : (root.effTone ? root.effTone.acc : Theming.primary))
        z: 1
    }

    MatusIcon {
        id: iconText

        width: parent.width
        height: parent.height
        text: root.iconName
        fill: root.iconFill
        color: {
            if (root.flat)
                return root.active ? (root.effTone ? root.effTone.acc : Theming.primary) : Theming.withAlpha(Theming.surfaceOn, Theming.opacitySecondary)
            if (root.active)
                return root.bgColor !== null ? root.iconColor : (root.effTone ? root.effTone.accOn : Theming.primaryOn)
            if (root.showCookie) {
                if (root.hoverIconColor !== null)
                    return root.hoverIconColor
                if (root.bgColor === null && root.hoverColor === null)
                    return root.effTone ? root.effTone.on : Theming.primaryContainerOn
                return root.iconColor
            }
            return root.iconColor
        }
        font.pixelSize: root.iconSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        transformOrigin: Item.Center
        z: 1

        Behavior on color {
            MatusColorAnim {
                type: MatusAnim.FastEffects
            }
        }

        RotationAnimator on rotation {
            running: root.spinning
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: MatusMotion.durationExtraLong4
            onRunningChanged: {
                if (!running)
                    iconText.rotation = 0
            }
        }
    }

    MouseArea {
        id: ma

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function (mouse) {
            if (root.clickable)
                ripple.triggerRipple(mouse.x, mouse.y)
            else
                mouse.accepted = false
        }
        onClicked: {
            if (root.clickable)
                root.clicked()
        }
    }
}
