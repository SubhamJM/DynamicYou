pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import "."

Item {
    id: root

    // --- Public API: Duration Tokens ---

    readonly property int durationShort1: scaledMs(50)
    readonly property int durationShort2: scaledMs(100)
    readonly property int durationShort3: scaledMs(150)
    readonly property int durationShort4: scaledMs(200)

    readonly property int durationMedium1: scaledMs(250)
    readonly property int durationMedium2: scaledMs(300)
    readonly property int durationMedium3: scaledMs(350)
    readonly property int durationMedium4: scaledMs(400)

    readonly property int durationLong1: scaledMs(450)
    readonly property int durationLong2: scaledMs(500)
    readonly property int durationLong3: scaledMs(550)
    readonly property int durationLong4: scaledMs(600)

    readonly property int durationExtraLong1: scaledMs(700)
    readonly property int durationExtraLong2: scaledMs(800)
    readonly property int durationExtraLong3: scaledMs(900)
    readonly property int durationExtraLong4: scaledMs(1000)

    // --- Public API: Expressive & Standard Duration Tokens ---

    readonly property int durationSmall: durationShort4
    readonly property int durationNormal: durationMedium4
    readonly property int durationLarge: durationLong4
    readonly property int durationExtraLarge: durationExtraLong4

    readonly property int durationFastSpatial: durationMedium3
    readonly property int durationDefaultSpatial: durationLong2
    readonly property int durationSlowSpatial: scaledMs(MatusConfig.animation.overshootEnabled ? 650 : 750)

    readonly property int durationFastEffects: durationShort3
    readonly property int durationDefaultEffects: durationShort4
    readonly property int durationSlowEffects: durationMedium2

    // --- Public API: Easing Curves (BezierSpline) ---

    // Spatial curves (scheme-aware: expressive bounce vs standard clean)
    readonly property var curveFastSpatial: MatusConfig.animation.overshootEnabled ? [0.42, 1.67, 0.21, 0.9, 1, 1] : [0.27, 1.06, 0.18, 1, 1, 1]
    readonly property var curveDefaultSpatial: MatusConfig.animation.overshootEnabled ? [0.38, 1.21, 0.22, 1, 1, 1] : [0.27, 1.06, 0.18, 1, 1, 1]
    readonly property var curveSlowSpatial: MatusConfig.animation.overshootEnabled ? [0.39, 1.29, 0.35, 0.98, 1, 1] : [0.27, 1.06, 0.18, 1, 1, 1]

    // Effects curves (strictly non-overshooting for alpha/color/blur)
    readonly property var curveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var curveDefaultEffects: [0.34, 0.80, 0.34, 1, 1, 1]
    readonly property var curveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]

    // Standard easing family (utilitarian / on-screen)
    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveStandardDecel: [0, 0, 0, 1, 1, 1]
    readonly property var curveStandardAccel: [0.3, 0, 1, 1, 1, 1]

    // Emphasized easing family (asymmetric enter / exit; true M3 2-segment cubic spline)
    readonly property var curveEmphasized: [0.05, 0, 0.133, 0.06, 0.166, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]
    readonly property var curveEmphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var curveEmphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]

    // Trailing-indicator glide (ease-in-out sine)
    readonly property var curveGlide: [0.37, 0, 0.63, 1, 1, 1]

    // --- Public API: Overshoot Geometry Tokens ---

    readonly property real overshootMultiplier: MatusConfig.animation.overshootStrength / 100.0
    readonly property real panelOvershootScale: 0.88 * overshootMultiplier
    readonly property real panelOvershootOffset: 44 * overshootMultiplier
    readonly property int panelOvershootBuffer: Math.round(33 * overshootMultiplier)

    // --- Public API: Scaling Functions ---

    function scaledMs(base: int): int {
        return Math.max(1, Math.round(base * (MatusConfig.animation.speedScale / 100.0)))
    }
}
