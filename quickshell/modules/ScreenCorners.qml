import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

Scope {
    id: screenCornersRoot

    required property var screen
    property real cornerRadius: 16
    property color cornerColor: "#000000"

    Variants {
        model: [
            { top: true, left: true, turn: 0 },
            { top: true, left: false, turn: 90 },
            { top: false, left: false, turn: 180 },
            { top: false, left: true, turn: 270 }
        ]

        PanelWindow {
            id: cornerWindow

            required property var modelData

            screen: screenCornersRoot.screen
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "screen-corners"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: cornerWindow.modelData.top
                bottom: !cornerWindow.modelData.top
                left: cornerWindow.modelData.left
                right: !cornerWindow.modelData.left
            }
            implicitWidth: screenCornersRoot.cornerRadius
            implicitHeight: screenCornersRoot.cornerRadius
            color: "transparent"
            mask: Region {} // Empty mask ensures 100% click-through to underlying windows

            Shape {
                id: cornerShape
                anchors.fill: parent
                rotation: cornerWindow.modelData.turn
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: screenCornersRoot.cornerColor
                    strokeWidth: -1
                    startX: 0
                    startY: 0

                    PathLine { x: cornerShape.width; y: 0 }
                    PathArc {
                        x: 0
                        y: cornerShape.height
                        radiusX: cornerShape.width
                        radiusY: cornerShape.height
                        direction: PathArc.Counterclockwise
                    }
                    PathLine { x: 0; y: 0 }
                }
            }
        }
    }
}
