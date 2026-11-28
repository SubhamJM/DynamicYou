import QtQuick
import "."

ColorAnimation {
    id: root

    // Reuses MatusAnim.Type. Only effects-family values are meaningful —
    // color transitions must never overshoot, so anything else falls back
    // to the slow effects token.
    property int type: MatusAnim.SlowEffects

    duration: {
        switch (type) {
        case MatusAnim.FastEffects:
            return MatusMotion.durationFastEffects
        case MatusAnim.DefaultEffects:
            return MatusMotion.durationDefaultEffects
        default:
            return MatusMotion.durationSlowEffects
        }
    }
    easing.bezierCurve: {
        switch (type) {
        case MatusAnim.FastEffects:
            return MatusMotion.curveFastEffects
        case MatusAnim.DefaultEffects:
            return MatusMotion.curveDefaultEffects
        default:
            return MatusMotion.curveSlowEffects
        }
    }
    easing.type: Easing.BezierSpline
}
