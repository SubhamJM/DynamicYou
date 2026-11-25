import QtQuick
import "../"

// Minimal end-4pc bottom-right corner resize arc for M3 desktop widgets.
// Sits cleanly inside the card bounds so Wayland input mask & symmetric grow/shrink deltas never break.
Item {
    id: root

    property string tileId: ""
    property bool hoverActive: false
    property bool enabledHandle: false
    property string currentMode: "1x3"
    property var snapModes: ["1x1", "1x2", "1x3", "2x2", "2x3"]
    property color strokeColor: "#ffffff"
    property color badgeBg: "#0a0e18"
    property color badgeFg: "#ffffff"
    property bool resizing: handleMouse.pressed || handleMouse.containsMouse

    function parseCols(mode) {
        const m = String(mode || "1x3");
        const c = parseInt(m.charAt(2), 10);
        return (c >= 1 && c <= 3) ? c : 1;
    }

    function parseRows(mode) {
        const m = String(mode || "1x3");
        const r = parseInt(m.charAt(0), 10);
        return (r >= 1 && r <= 2) ? r : 1;
    }

    function resolveStepMode(dx, dy, startCols, startRows) {
        // Symmetric step thresholds (~52dp per column/row step) so shrinking AND growing feel identical
        const stepX = WidgetStore.s(78);
        const stepY = WidgetStore.s(78);
        const dCols = dx > 0 ? Math.floor((dx + stepX * 0.45) / stepX) : Math.ceil((dx - stepX * 0.45) / stepX);
        const dRows = dy > 0 ? Math.floor((dy + stepY * 0.45) / stepY) : Math.ceil((dy - stepY * 0.45) / stepY);

        let cols = Math.max(1, Math.min(3, startCols + dCols));
        let rows = Math.max(1, Math.min(2, startRows + dRows));
        let candidate = rows + "x" + cols;

        if (snapModes.indexOf(candidate) !== -1) return candidate;
        if (rows === 2 && cols === 1) {
            candidate = (snapModes.indexOf("2x2") !== -1) ? "2x2" : "1x1";
            return candidate;
        }
        if (rows === 1 && snapModes.indexOf(candidate) === -1) {
            return snapModes.indexOf("1x2") !== -1 ? "1x2" : currentMode;
        }
        return currentMode;
    }

    anchors {
        right: parent.right
        bottom: parent.bottom
        rightMargin: WidgetStore.s(4)
        bottomMargin: WidgetStore.s(4)
    }
    width: WidgetStore.s(42)
    height: WidgetStore.s(42)
    visible: enabledHandle
    opacity: (hoverActive || handleMouse.containsMouse || handleMouse.pressed) ? 0.92 : 0
    z: 35

    Behavior on opacity { NumberAnimation { duration: 130 } }

    onStrokeColorChanged: arcCanvas.requestPaint()

    Canvas {
        id: arcCanvas
        anchors.fill: parent
        Component.onCompleted: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = root.strokeColor;
            ctx.lineWidth = Math.max(2, WidgetStore.s(3));
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.arc(width * 0.5, height * 0.5, width * 0.34, 0, Math.PI * 0.5);
            ctx.stroke();
        }
    }

    // Live size indicator badge during resize drag
    Rectangle {
        visible: handleMouse.pressed
        anchors {
            right: parent.left
            bottom: parent.bottom
            rightMargin: WidgetStore.s(4)
            bottomMargin: WidgetStore.s(6)
        }
        width: lbl.implicitWidth + WidgetStore.s(12)
        height: WidgetStore.s(20)
        radius: WidgetStore.s(10)
        color: root.badgeBg
        border.width: 1
        border.color: Qt.alpha(root.badgeFg, 0.25)

        Text {
            id: lbl
            anchors.centerIn: parent
            text: root.currentMode.replace("x", "×")
            color: root.badgeFg
            font.family: "Google Sans Flex"
            font.pixelSize: WidgetStore.si(10)
            font.weight: Font.Bold
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: handleMouse
        anchors.fill: parent
        enabled: root.enabledHandle
        hoverEnabled: true
        cursorShape: Qt.SizeFDiagCursor
        preventStealing: true

        property real startX: 0
        property real startY: 0
        property int startCols: 1
        property int startRows: 1
        property string previewMode: ""

        onPressed: (mouse) => {
            mouse.accepted = true;
            const g = mapToItem(null, mouse.x, mouse.y);
            startX = g.x;
            startY = g.y;
            startCols = root.parseCols(root.currentMode);
            startRows = root.parseRows(root.currentMode);
            previewMode = root.currentMode;
        }
        onPositionChanged: (mouse) => {
            if (!pressed || !root.tileId) return;
            const g = mapToItem(null, mouse.x, mouse.y);
            const next = root.resolveStepMode(g.x - startX, g.y - startY, startCols, startRows);
            if (next !== previewMode) {
                previewMode = next;
                WidgetStore.setCardOption(root.tileId, "sizeMode", next);
            }
        }
    }
}
