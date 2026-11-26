import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: ring

    property real value: 0
    property real thickness: 8
    property color progressColor: Theme.accent
    property color trackColor: Qt.alpha(Theme.text, 0.08)

    readonly property real clamped: Math.max(0, Math.min(1, value))
    readonly property real radiusPx: Math.max(4, Math.min(width, height) / 2 - thickness / 2)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: ring.trackColor
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radiusPx
                radiusY: ring.radiusPx
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: ring.clamped > 0.001 ? ring.progressColor : "transparent"
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radiusPx
                radiusY: ring.radiusPx
                startAngle: -90
                sweepAngle: 360 * ring.clamped
            }
        }
    }
}
