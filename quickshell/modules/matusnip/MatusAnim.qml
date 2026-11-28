import QtQuick
import "."

NumberAnimation {
    id: root

    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: MatusAnim.DefaultSpatial

    duration: {
        switch (type) {
        case MatusAnim.FastSpatial:
            return MatusMotion.durationFastSpatial
        case MatusAnim.DefaultSpatial:
            return MatusMotion.durationDefaultSpatial
        case MatusAnim.SlowSpatial:
            return MatusMotion.durationSlowSpatial
        case MatusAnim.FastEffects:
            return MatusMotion.durationFastEffects
        case MatusAnim.DefaultEffects:
            return MatusMotion.durationDefaultEffects
        case MatusAnim.SlowEffects:
            return MatusMotion.durationSlowEffects
        case MatusAnim.StandardSmall:
        case MatusAnim.EmphasizedSmall:
            return MatusMotion.durationSmall
        case MatusAnim.Standard:
        case MatusAnim.Emphasized:
            return MatusMotion.durationNormal
        case MatusAnim.StandardLarge:
        case MatusAnim.EmphasizedLarge:
            return MatusMotion.durationLarge
        case MatusAnim.StandardExtraLarge:
        case MatusAnim.EmphasizedExtraLarge:
            return MatusMotion.durationExtraLarge
        default:
            return MatusMotion.durationDefaultSpatial
        }
    }
    easing.bezierCurve: {
        switch (type) {
        case MatusAnim.FastSpatial:
            return MatusMotion.curveFastSpatial
        case MatusAnim.DefaultSpatial:
            return MatusMotion.curveDefaultSpatial
        case MatusAnim.SlowSpatial:
            return MatusMotion.curveSlowSpatial
        case MatusAnim.FastEffects:
            return MatusMotion.curveFastEffects
        case MatusAnim.DefaultEffects:
            return MatusMotion.curveDefaultEffects
        case MatusAnim.SlowEffects:
            return MatusMotion.curveSlowEffects
        case MatusAnim.EmphasizedSmall:
        case MatusAnim.Emphasized:
        case MatusAnim.EmphasizedLarge:
        case MatusAnim.EmphasizedExtraLarge:
            return MatusMotion.curveEmphasized
        default:
            return MatusMotion.curveStandard
        }
    }
    easing.type: Easing.BezierSpline
}
