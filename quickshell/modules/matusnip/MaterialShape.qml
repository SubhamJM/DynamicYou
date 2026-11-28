import QtQuick
import QtQuick.Shapes
import "."

// Pure-QML Material 3 Expressive Shape with smooth vertex-by-vertex morphing
// matching M3Shapes.MaterialShape API (Circle, Square, Cookie4Sided, Cookie9Sided, VerySunny, etc.).
Item {
    id: root

    enum Shape {
        Circle = 0,
        Square,
        Slanted,
        Arch,
        Fan,
        Arrow,
        SemiCircle,
        Oval,
        Pill,
        Triangle,
        Diamond,
        ClamShell,
        Pentagon,
        Gem,
        Sunny,
        VerySunny,
        Cookie4Sided,
        Cookie6Sided,
        Cookie7Sided,
        Cookie9Sided,
        Cookie12Sided,
        Ghostish,
        PixelCircle,
        PixelTriangle,
        Bun,
        Heart,
        Puffy,
        PuffyDiamond,
        Flower,
        SoftBurst,
        Boom,
        SoftBoom,
        Clover4Leaf,
        Clover8Leaf,
        Burst
    }

    property int shape: MaterialShape.Shape.Circle
    property color color: Theming.primary
    property real implicitSize: 0
    property int morphDuration: MatusMotion.durationFastSpatial
    property var morphEasing: MatusMotion.curveFastSpatial

    implicitWidth: implicitSize > 0 ? implicitSize : 48
    implicitHeight: implicitSize > 0 ? implicitSize : 48

    property int _fromShape: shape
    property int _toShape: shape
    property real _morphT: 1.0

    onShapeChanged: {
        if (shape === _toShape)
            return
        _fromPts = sampleShape(_fromShape, _toShape, _morphT)
        _fromShape = _toShape
        _toShape = shape
        _toPts = sampleUnitShape(_toShape)
        morphAnim.stop()
        _morphT = 0.0
        morphAnim.start()
    }

    property var _fromPts: sampleUnitShape(MaterialShape.Shape.Circle)
    property var _toPts: sampleUnitShape(shape)

    NumberAnimation {
        id: morphAnim
        target: root
        property: "_morphT"
        from: 0.0
        to: 1.0
        duration: root.morphDuration
        easing.type: root.morphEasing ? Easing.BezierSpline : Easing.OutCubic
        easing.bezierCurve: root.morphEasing || []
    }

    function unitRadius(s, theta) {
        const c = Math.cos(theta)
        const sSin = Math.sin(theta)
        switch (s) {
        case MaterialShape.Shape.Square: {
            const p = 6.0
            const d = Math.pow(Math.abs(c), p) + Math.pow(Math.abs(sSin), p)
            return 0.94 / Math.pow(d, 1.0 / p)
        }
        case MaterialShape.Shape.Diamond: {
            const p = 1.35
            const d = Math.pow(Math.abs(c), p) + Math.pow(Math.abs(sSin), p)
            return 0.95 / Math.pow(d, 1.0 / p)
        }
        case MaterialShape.Shape.Cookie4Sided:
            return 0.80 - 0.18 * Math.cos(4.0 * theta) + 0.025 * Math.cos(8.0 * theta)
        case MaterialShape.Shape.Cookie6Sided:
            return 0.87 + 0.12 * Math.cos(6.0 * theta)
        case MaterialShape.Shape.Cookie7Sided:
            return 0.88 + 0.11 * Math.cos(7.0 * theta)
        case MaterialShape.Shape.Cookie9Sided:
            return 0.90 + 0.095 * Math.cos(9.0 * theta)
        case MaterialShape.Shape.Cookie12Sided:
            return 0.92 + 0.075 * Math.cos(12.0 * theta)
        case MaterialShape.Shape.Sunny:
        case MaterialShape.Shape.SoftBurst:
            return 0.83 + 0.15 * Math.cos(8.0 * theta) + 0.02 * Math.cos(16.0 * theta)
        case MaterialShape.Shape.VerySunny:
        case MaterialShape.Shape.Burst:
            return 0.84 + 0.15 * Math.cos(12.0 * theta)
        case MaterialShape.Shape.Clover4Leaf:
            return 0.72 - 0.25 * Math.cos(4.0 * theta)
        case MaterialShape.Shape.Clover8Leaf:
            return 0.80 + 0.19 * Math.cos(8.0 * theta)
        case MaterialShape.Shape.Triangle: {
            const k = (theta % (2 * Math.PI / 3))
            const seg = Math.abs(Math.cos(Math.PI / 3) / Math.cos(k - Math.PI / 3))
            return Math.min(0.95, 0.54 * seg + 0.36)
        }
        case MaterialShape.Shape.Pentagon:
            return 0.90 + 0.08 * Math.cos(5.0 * (theta - Math.PI / 2))
        case MaterialShape.Shape.Oval:
            return 1.0 / Math.sqrt((c / 0.74) * (c / 0.74) + sSin * sSin)
        case MaterialShape.Shape.Pill: {
            const p = 5.0
            const ax = Math.abs(c) / 1.0
            const ay = Math.abs(sSin) / 0.66
            return 0.96 / Math.pow(Math.pow(ax, p) + Math.pow(ay, p), 1.0 / p)
        }
        default:
            return 1.0
        }
    }

    function sampleUnitShape(s) {
        const n = 72
        const pts = []
        for (let i = 0; i <= n; i++) {
            const theta = (i / n) * Math.PI * 2.0
            const r = unitRadius(s, theta)
            pts.push(Qt.point(r * Math.cos(theta), r * Math.sin(theta)))
        }
        return pts
    }

    function sampleShape(fromS, toS, t) {
        const a = sampleUnitShape(fromS)
        const b = sampleUnitShape(toS)
        const out = []
        for (let i = 0; i < a.length; i++) {
            out.push(Qt.point(a[i].x + (b[i].x - a[i].x) * t, a[i].y + (b[i].y - a[i].y) * t))
        }
        return out
    }

    function buildPath(w, h, fromPts, toPts, t) {
        const cx = w * 0.5
        const cy = h * 0.5
        const rx = cx
        const ry = cy
        const out = []
        const len = Math.min(fromPts.length, toPts.length)
        for (let i = 0; i < len; i++) {
            const x = fromPts[i].x + (toPts[i].x - fromPts[i].x) * t
            const y = fromPts[i].y + (toPts[i].y - fromPts[i].y) * t
            out.push(Qt.point(cx + x * rx, cy + y * ry))
        }
        return out
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: root.color

            PathPolyline {
                path: root.buildPath(root.width, root.height, root._fromPts, root._toPts, root._morphT)
            }
        }
    }
}
