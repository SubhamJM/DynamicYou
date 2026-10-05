import QtQuick

Item {
    id: root

    property var values: []
    property real maximum: 100
    property color strokeColor: "#7aa2f7"
    property real strokeWidth: 1.8
    property bool fillArea: true
    property real fillOpacity: 0.22
    property bool showPeakDot: true
    property real peakDotSize: 4.0

    implicitWidth: 64
    implicitHeight: 24

    onValuesChanged: canvas.requestPaint()
    onStrokeColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const data = root.values;
            if (!data || data.length < 2 || width <= 4 || height <= 4) return;

            const topPad = 3;
            const btmPad = 3;
            const drawH = height - topPad - btmPad;
            const maxVal = Math.max(1, root.maximum);
            const count = data.length;
            const step = width / (count - 1);

            const points = [];
            for (let i = 0; i < count; i++) {
                const v = typeof data[i] === "number" ? data[i] : 0;
                const norm = Math.max(0, Math.min(1, v / maxVal));
                const px = i * step;
                const py = (height - btmPad) - (norm * drawH);
                points.push({ x: px, y: py });
            }

            // 1. Draw gradient area fill
            if (root.fillArea && points.length > 1) {
                const grad = ctx.createLinearGradient(0, topPad, 0, height);
                const r = root.strokeColor.r;
                const g = root.strokeColor.g;
                const b = root.strokeColor.b;
                grad.addColorStop(0, `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${root.fillOpacity})`);
                grad.addColorStop(1, `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, 0.0)`);

                ctx.beginPath();
                ctx.moveTo(points[0].x, points[0].y);
                for (let i = 1; i < points.length; i++) {
                    ctx.lineTo(points[i].x, points[i].y);
                }
                ctx.lineTo(points[points.length - 1].x, height);
                ctx.lineTo(points[0].x, height);
                ctx.closePath();

                ctx.fillStyle = grad;
                ctx.fill();
            }

            // 2. Draw line curve
            ctx.beginPath();
            ctx.moveTo(points[0].x, points[0].y);
            for (let i = 1; i < points.length; i++) {
                ctx.lineTo(points[i].x, points[i].y);
            }
            ctx.strokeStyle = root.strokeColor;
            ctx.lineWidth = root.strokeWidth;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.stroke();

            // 3. Draw live peak dot on latest data point
            if (root.showPeakDot && points.length > 0) {
                const lastPt = points[points.length - 1];
                const dotR = root.peakDotSize / 2;

                // Outer halo
                ctx.beginPath();
                ctx.arc(lastPt.x, lastPt.y, dotR + 2, 0, Math.PI * 2);
                ctx.fillStyle = `rgba(${Math.round(root.strokeColor.r * 255)}, ${Math.round(root.strokeColor.g * 255)}, ${Math.round(root.strokeColor.b * 255)}, 0.35)`;
                ctx.fill();

                // Center core
                ctx.beginPath();
                ctx.arc(lastPt.x, lastPt.y, dotR, 0, Math.PI * 2);
                ctx.fillStyle = "#ffffff";
                ctx.fill();
            }
        }
    }
}
