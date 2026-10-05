import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property real value: 0.0
    property bool seekable: true
    property color fillColor: "#a8c7fa"
    property color trackColor: Qt.rgba(255, 255, 255, 0.12)
    signal seekRequested(real value)
    signal moved(real value)
    property bool knob: false
    property real stepSize: 0.05
    activeFocusOnTab: root.seekable

    // Material 3 Expressive Wavy Progress Bar properties
    property bool wavy: false
    property bool isPlaying: false
    property real waveAmplitude: 2.8
    property real waveFrequency: 0.048

    property real dragValue: -1
    readonly property bool engaged: root.seekable && (pointer.containsMouse || pointer.pressed || root.activeFocus)
    readonly property real shownValue: Math.max(0, Math.min(1, root.dragValue >= 0 ? root.dragValue : root.value))
    readonly property bool isDragging: pointer.pressed && root.dragValue >= 0

    implicitWidth: 200
    implicitHeight: 22
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    height: implicitHeight

    Accessible.role: Accessible.Slider
    Keys.onPressed: event => {
        if (!root.seekable) return
        let next = root.shownValue
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) next += root.stepSize
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) next -= root.stepSize
        else if (event.key === Qt.Key_Home) next = 0
        else if (event.key === Qt.Key_End) next = 1
        else return
        next = Math.max(0, Math.min(1, next))
        root.moved(next)
        root.seekRequested(next)
        event.accepted = true
    }

    // Standard Flat Track (visible when wavy is false)
    Item {
        id: track
        visible: !root.wavy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.engaged ? 8 : 4
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.trackColor
        }
        Item {
            width: Math.max(0, Math.min(track.width, track.width * root.shownValue))
            height: track.height
            clip: true
            Rectangle {
                width: track.width
                height: track.height
                radius: height / 2
                color: root.fillColor
            }
        }
    }

    // Material Wave Canvas (visible when wavy is true)
    Canvas {
        id: waveCanvas
        anchors.fill: parent
        visible: root.wavy
        antialiasing: true

        property real wavePhase: 0
        property real currentAmplitude: (root.wavy && root.isPlaying) ? root.waveAmplitude : 0.0
        Behavior on currentAmplitude {
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }

        onCurrentAmplitudeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root
            function onShownValueChanged() { waveCanvas.requestPaint(); }
            function onFillColorChanged() { waveCanvas.requestPaint(); }
            function onTrackColorChanged() { waveCanvas.requestPaint(); }
            function onEngagedChanged() { waveCanvas.requestPaint(); }
        }

        Timer {
            id: wavePhaseTimer
            interval: 16 // 60fps smooth animation
            running: root.wavy && root.visible && waveCanvas.currentAmplitude > 0.05
            repeat: true
            onTriggered: {
                waveCanvas.wavePhase += 0.085;
                if (waveCanvas.wavePhase > 6.28318) waveCanvas.wavePhase -= 6.28318;
                waveCanvas.requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const centerY = height / 2;
            const fillW = Math.max(0, Math.min(width, width * root.shownValue));
            const lw = root.engaged ? 5.5 : 4.0;

            // 1. Draw remaining track
            if (fillW < width) {
                ctx.strokeStyle = root.trackColor;
                ctx.lineWidth = root.engaged ? 4.5 : 3.5;
                ctx.lineCap = "round";
                ctx.beginPath();
                const startX = Math.min(width - 2, fillW + (root.knob ? 7 : 3));
                ctx.moveTo(startX, centerY);
                ctx.lineTo(width - 2, centerY);
                ctx.stroke();
            }

            // 2. Draw elapsed progress (animated sine wave when playing, smooth flat bar when paused)
            if (fillW > 1) {
                ctx.strokeStyle = root.fillColor;
                ctx.lineWidth = lw;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(2, centerY);

                if (currentAmplitude > 0.05) {
                    const step = 2;
                    for (let x = 2; x <= fillW; x += step) {
                        const y = centerY + Math.sin(x * root.waveFrequency + wavePhase) * currentAmplitude;
                        ctx.lineTo(x, y);
                    }
                } else {
                    ctx.lineTo(fillW, centerY);
                }
                ctx.stroke();
            }
        }
    }

    // Playhead Scrubber Knob Dot
    Rectangle {
        id: knobDot
        visible: root.knob
        width: root.engaged ? 15 : 11
        height: width
        radius: width / 2
        x: Math.max(0, Math.min(root.width - width, root.width * root.shownValue - width / 2))
        y: (root.wavy && waveCanvas.currentAmplitude > 0.05)
            ? (root.height / 2 - height / 2 + Math.sin(root.shownValue * root.width * root.waveFrequency + waveCanvas.wavePhase) * waveCanvas.currentAmplitude)
            : (root.height / 2 - height / 2)
        color: "#ffffff"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.20)

        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        enabled: root.seekable
        hoverEnabled: true
        cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
        function valueAt(px) { return Math.max(0, Math.min(1, px / Math.max(1, width))) }
        onPressed: mouse => {
            root.forceActiveFocus();
            root.dragValue = valueAt(mouse.x);
            root.moved(root.dragValue);
        }
        onPositionChanged: mouse => {
            if (pressed) {
                root.dragValue = valueAt(mouse.x);
                root.moved(root.dragValue);
            }
        }
        onReleased: {
            if (root.dragValue >= 0) {
                root.seekRequested(root.dragValue);
                root.moved(root.dragValue);
            }
            root.dragValue = -1;
        }
        onCanceled: root.dragValue = -1
        preventStealing: true
        property real wheelAccumulator: 0
        onWheel: wheel => {
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
