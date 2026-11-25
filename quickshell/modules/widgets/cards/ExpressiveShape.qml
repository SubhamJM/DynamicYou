import QtQuick
import QtQuick.Shapes
import "../../../lucidui/Shapes.js" as Shapes
import "../../../lucidui/ShapeRadii.js" as Table

Item {
    id: root

    // Supports all Table.r keys ("circle", "cookie4", "cookie6", "cookie7",
    // "cookie9", "cookie12", "sunny", "verySunny", "softBurst", "gem", "pill",
    // "pentagon", etc.) plus "cookie14" / "cookieN" generated smoothly.
    property string shape: "circle"
    property int cookieSides: 14
    property color color: "#064a62"
    property real shapeRotation: 0 // radians or degrees via item.rotation

    function cookieRadii(sides) {
        const n = Math.max(3, sides || 14);
        const key = "cookie" + n;
        if (Table.r[key]) return Table.r[key];
        const out = [];
        for (let i = 0; i < Shapes.N; i += 1) {
            const th = (i / Shapes.N) * Math.PI * 2;
            out.push(0.945 + 0.055 * Math.cos(n * th));
        }
        return out;
    }

    readonly property string svgPath: {
        const sz = Math.min(width, height);
        if (sz <= 1) return "";
        if (root.shape === "cookie") {
            return Shapes.svg(cookieRadii(root.cookieSides), sz, root.shapeRotation);
        }
        if (root.shape === "cookie14") {
            return Shapes.svg(cookieRadii(14), sz, root.shapeRotation);
        }
        return Shapes.path(root.shape, sz, root.shapeRotation);
    }

    Shape {
        anchors.centerIn: parent
        width: Math.min(root.width, root.height)
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0
            PathSvg {
                path: root.svgPath
            }
        }
    }
}
