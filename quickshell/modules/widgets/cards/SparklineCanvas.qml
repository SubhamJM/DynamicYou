import QtQuick

Item {
    id: root

    property var values: []
    property var secondaryValues: []
    property color lineColor: "#00e5ff"
    property color secondaryLineColor: "#67e8f9"
    property color baselineColor: Qt.rgba(1, 1, 1, 0.16)
    property real maximum: 0
    property real scaleHeadroom: 1.2
    property bool showGuideLines: false
    property bool fillArea: true
    property bool active: visible
    property int historyLength: 60
    property int updateInterval: 1500
    property real lineWidth: 2.5
    property real fillOpacity: 0.16
    property real transitionProgress: 1

    readonly property real dataMaximum: {
        let res = 0;
        const series = [values || [], secondaryValues || []];
        for (let s = 0; s < series.length; s += 1) {
            const pts = series[s];
            for (let i = 0; i < pts.length; i += 1) {
                const v = pts[i];
                if (typeof v === "number" && isFinite(v)) res = Math.max(res, v);
            }
        }
        return res;
    }
    property real scaleMaximum: maximum > 0 ? maximum : Math.max(1, dataMaximum * scaleHeadroom)

    implicitHeight: 64

    function requestVisiblePaint() {
        if (root.active) chart.requestPaint();
    }

    function animateUpdate() {
        if (!root.active) {
            root.transitionProgress = 1;
            return;
        }
        slideAnimation.restart();
    }

    onValuesChanged: animateUpdate()
    onSecondaryValuesChanged: animateUpdate()
    onLineColorChanged: requestVisiblePaint()
    onSecondaryLineColorChanged: requestVisiblePaint()
    onScaleMaximumChanged: requestVisiblePaint()
    onActiveChanged: requestVisiblePaint()
    onTransitionProgressChanged: requestVisiblePaint()

    NumberAnimation {
        id: slideAnimation
        target: root
        property: "transitionProgress"
        from: 0
        to: 1
        duration: Math.max(250, root.updateInterval)
        easing.type: Easing.Linear
    }

    Canvas {
        id: chart
        anchors.fill: parent
        antialiasing: true
        visible: root.active
        onWidthChanged: root.requestVisiblePaint()
        onHeightChanged: root.requestVisiblePaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            if (!root.active || width <= 1 || height <= 1) return;

            const top = Math.max(6, root.lineWidth * 2);
            const bottom = height - 3;

            if (root.showGuideLines) {
                ctx.lineWidth = 1;
                ctx.strokeStyle = root.baselineColor;
                ctx.globalAlpha = 0.55;
                for (let g = 1; g <= 2; g += 1) {
                    const gy = top + (bottom - top) * g / 3;
                    ctx.beginPath();
                    ctx.moveTo(0, gy);
                    ctx.lineTo(width, gy);
                    ctx.stroke();
                }
                ctx.globalAlpha = 1;
            }

            function drawSeries(pts, color, fill) {
                if (!pts || pts.length === 0) return;
                const count = pts.length;
                const slots = Math.max(2, root.historyLength);
                const step = width / (slots - 1);
                const slideOff = count > 1 ? (1 - root.transitionProgress) * step : 0;
                const startX = width - Math.max(0, count - 1) * step + slideOff;
                const coords = [];
                for (let i = 0; i < count; i += 1) {
                    const val = pts[i];
                    if (typeof val !== "number" || !isFinite(val)) continue;
                    const x = count > 1 ? startX + i * step : width;
                    const norm = Math.max(0, Math.min(1, val / Math.max(1e-6, root.scaleMaximum)));
                    const y = bottom - norm * (bottom - top);
                    coords.push({ x: x, y: y });
                }
                if (coords.length === 0) return;
                if (coords.length === 1) {
                    const y0 = coords[0].y;
                    ctx.beginPath();
                    ctx.moveTo(0, y0);
                    ctx.lineTo(width, y0);
                    if (root.lineWidth > 0) {
                        ctx.lineWidth = root.lineWidth;
                        ctx.strokeStyle = Qt.alpha(color, 0.55);
                        ctx.stroke();
                    }
                    return;
                }

                function trace() {
                    ctx.beginPath();
                    ctx.moveTo(coords[0].x, coords[0].y);
                    for (let i = 1; i < coords.length; i += 1) ctx.lineTo(coords[i].x, coords[i].y);
                }

                if (fill && coords.length > 1) {
                    trace();
                    ctx.lineTo(coords[coords.length - 1].x, bottom);
                    ctx.lineTo(coords[0].x, bottom);
                    ctx.closePath();
                    ctx.globalAlpha = root.fillOpacity;
                    ctx.fillStyle = color;
                    ctx.fill();
                    ctx.globalAlpha = 1;
                }

                if (root.lineWidth > 0) {
                    trace();
                    ctx.lineWidth = root.lineWidth;
                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";
                    ctx.strokeStyle = color;
                    ctx.stroke();
                }
            }

            drawSeries(root.values, root.lineColor, root.fillArea);
            drawSeries(root.secondaryValues, root.secondaryLineColor, false);
        }
    }
}
