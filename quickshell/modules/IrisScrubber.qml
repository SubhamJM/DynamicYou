pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property real value: 0.0
    property bool seekable: true
    property color fillColor: "#a8c7fa"
    property color trackColor: Qt.rgba(255, 255, 255, 0.14)
    signal seekRequested(real value)
    signal moved(real value)
    property bool knob: false
    property real stepSize: 0.05
    activeFocusOnTab: root.seekable

    // Material 3 / Lucid Expressive Waveform Progress properties
    property bool wavy: false
    property bool isPlaying: false
    property real wavelength: 26
    readonly property real trackThickness: 4
    readonly property real handleWidth: 4
    readonly property real trackGap: 6
    readonly property real stopIndicator: 4
    readonly property real trackInset: 8

    property real dragValue: -1
    readonly property bool engaged: root.seekable && (pointer.containsMouse || pointer.pressed || root.activeFocus)
    readonly property real shownValue: Math.max(0, Math.min(1, root.dragValue >= 0 ? root.dragValue : root.value))
    readonly property bool isDragging: pointer.pressed && root.dragValue >= 0

    implicitWidth: 200
    implicitHeight: 24
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    height: implicitHeight

    Accessible.role: Accessible.Slider
    Keys.onPressed: (event) => {
        if (!root.seekable) return;
        let next = root.shownValue;
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) next += root.stepSize;
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) next -= root.stepSize;
        else if (event.key === Qt.Key_Home) next = 0;
        else if (event.key === Qt.Key_End) next = 1;
        else return;
        next = Math.max(0, Math.min(1, next));
        root.moved(next);
        root.seekRequested(next);
        event.accepted = true;
    }

    // ----------------------------------------------------
    // FLAT TRACK (Used when wavy === false, e.g. stream volume sliders)
    // ----------------------------------------------------
    Item {
        id: flatTrack
        visible: !root.wavy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.engaged ? 6 : 4
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.trackColor
        }

        Item {
            width: Math.max(0, Math.min(flatTrack.width, flatTrack.width * root.shownValue))
            height: flatTrack.height
            clip: true
            Rectangle {
                width: flatTrack.width
                height: flatTrack.height
                radius: height / 2
                color: root.fillColor
            }
        }

        Rectangle {
            id: flatKnob
            visible: root.knob
            width: root.engaged ? 14 : 10
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(flatTrack.width - width, flatTrack.width * root.shownValue - width / 2))
            color: "#ffffff"
            Behavior on width { NumberAnimation { duration: 100 } }
        }
    }

    // ----------------------------------------------------
    // LUCID WAVE CANVAS (Used when wavy === true)
    // ----------------------------------------------------
    Canvas {
        id: waveCanvas
        anchors.fill: parent
        visible: root.wavy
        antialiasing: true

        property real animatedProgress: root.shownValue
        property real handleHeight: root.engaged ? 18 : 14
        property real amplitude: (!root.wavy || !root.isPlaying) ? 0.0 : (root.engaged ? 6.0 : 5.0)

        Behavior on handleHeight {
            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
        }

        Behavior on amplitude {
            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
        }

        onAnimatedProgressChanged: requestPaint()
        onHandleHeightChanged: requestPaint()
        onAmplitudeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root
            function onShownValueChanged() { waveCanvas.requestPaint(); }
            function onFillColorChanged() { waveCanvas.requestPaint(); }
            function onTrackColorChanged() { waveCanvas.requestPaint(); }
            function onEngagedChanged() { waveCanvas.requestPaint(); }
            function onIsPlayingChanged() { waveCanvas.requestPaint(); }
        }

        // Smooth 60 FPS animation ticker while music is playing or amplitude is returning to rest
        FrameAnimation {
            running: root.wavy && root.visible && (root.isPlaying || waveCanvas.amplitude > 0.02)
            onTriggered: waveCanvas.requestPaint()
        }

        function smoothstep(t) {
            t = Math.max(0, Math.min(1, t));
            return t * t * (3 - 2 * t);
        }

        function envelope(x, inset, rampLen, endX) {
            const fromStart = smoothstep((x - inset) / rampLen);
            const fromEnd = smoothstep((endX - x) / (rampLen * 0.35));
            const progress = Math.max(0, Math.min(1, (x - inset) / Math.max(1, endX - inset)));
            const height = 0.38 + 0.62 * smoothstep(progress);
            // Mix slow, incommensurate cycles to vary consecutive peaks smoothly.
            const variation = 0.72 + 0.17 * Math.sin(x * 0.047 + 1.2)
                + 0.11 * Math.sin(x * 0.091 + 2.8);
            return Math.min(fromStart, fromEnd) * height * variation;
        }

        function roundedBar(ctx, x, y, w, h, color) {
            ctx.fillStyle = color;
            ctx.beginPath();
            ctx.roundedRect(x, y, w, h, w / 2, w / 2);
            ctx.fill();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const midY = height / 2;
            const inset = root.trackInset;
            const usableWidth = width - inset * 2;
            const handleX = inset + Math.max(0, Math.min(usableWidth, usableWidth * animatedProgress));
            const activeEnd = handleX - root.trackGap - root.handleWidth / 2;
            const inactiveStart = handleX + root.trackGap + root.handleWidth / 2;
            const rampLen = root.wavelength * 1.4;

            // Half a wavelength per second; seamless loop
            const shift = (Date.now() % 600000) / 1000 * root.wavelength * 0.5;

            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            // 1. Draw Active Wave Track
            if (activeEnd - inset > root.trackThickness) {
                ctx.strokeStyle = root.fillColor;
                ctx.lineWidth = root.trackThickness;
                ctx.beginPath();
                if (amplitude > 0.05) {
                    for (let x = inset; x <= activeEnd; x++) {
                        const y = midY + Math.sin(((x - shift) / root.wavelength) * Math.PI * 2) * amplitude * envelope(x, inset, rampLen, activeEnd);
                        if (x === inset) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }
                } else {
                    ctx.moveTo(inset, midY);
                    ctx.lineTo(activeEnd, midY);
                }
                ctx.stroke();
            }

            // 2. Draw Inactive Remaining Track
            const trackEnd = width - inset - root.stopIndicator * 2;
            if (trackEnd - inactiveStart > root.trackThickness) {
                ctx.strokeStyle = root.trackColor;
                ctx.lineWidth = root.trackThickness;
                ctx.beginPath();
                ctx.moveTo(inactiveStart, midY);
                ctx.lineTo(trackEnd, midY);
                ctx.stroke();
            }

            // 3. Stop indicator at end of inactive track
            ctx.fillStyle = root.fillColor;
            ctx.globalAlpha = animatedProgress > 0.97 ? 0 : 0.45;
            ctx.beginPath();
            ctx.arc(width - inset - root.stopIndicator / 2, midY, root.stopIndicator / 2, 0, Math.PI * 2);
            ctx.fill();
            ctx.globalAlpha = 1.0;

            // 4. Rounded Vertical Pill Handle
            roundedBar(ctx, handleX - root.handleWidth / 2, midY - handleHeight / 2, root.handleWidth, handleHeight, root.fillColor);
        }
    }

    // ----------------------------------------------------
    // POINTER INTERACTION
    // ----------------------------------------------------
    MouseArea {
        id: pointer
        anchors.fill: parent
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        enabled: root.seekable
        hoverEnabled: true
        cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor

        function valueAt(px) {
            const inset = root.wavy ? root.trackInset : 0;
            const usable = Math.max(1, width - inset * 2);
            return Math.max(0, Math.min(1, (px - inset) / usable));
        }

        onPressed: (mouse) => {
            root.forceActiveFocus();
            root.dragValue = valueAt(mouse.x);
            root.moved(root.dragValue);
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                root.dragValue = valueAt(mouse.x);
                root.moved(root.dragValue);
            }
        }
        onReleased: (mouse) => {
            if (root.dragValue >= 0) {
                root.seekRequested(root.dragValue);
                root.moved(root.dragValue);
            }
            root.dragValue = -1;
        }
        onCanceled: root.dragValue = -1
        preventStealing: true

        property real wheelAccumulator: 0
        onWheel: (wheel) => {
            const delta = (wheel.angleDelta.y || wheel.angleDelta.x) || (wheel.pixelDelta.y || wheel.pixelDelta.x) * 4;
            pointer.wheelAccumulator += delta;
            const steps = Math.trunc(pointer.wheelAccumulator / 120);
            if (steps === 0) return;
            pointer.wheelAccumulator -= steps * 120;
            const next = Math.max(0, Math.min(1, root.shownValue + steps * root.stepSize));
            root.moved(next);
            root.seekRequested(next);
        }
    }
}
