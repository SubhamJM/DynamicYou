import QtQuick

Item {
    id: disclosure
    required property bool expanded
    required property real contentHeight
    required property var panel
    readonly property real reveal: contentHeight > 0 ? Math.min(1, height / contentHeight) : 0
    property bool counted: false

    height: expanded ? contentHeight : 0
    clip: true

    function trackMotion(running) {
        if (counted === running) return;
        counted = running;
        if (panel) panel.resizingRows += running ? 1 : -1;
    }

    Component.onDestruction: trackMotion(false)

    // Column positions and implicit heights are polished after the animation's last step.
    Timer {
        id: settle
        interval: 34
        onTriggered: disclosure.trackMotion(false)
    }

    Behavior on height {
        NumberAnimation {
            duration: 220
            easing.type: Easing.InOutCubic
            onRunningChanged: {
                if (running) {
                    settle.stop();
                    disclosure.trackMotion(true);
                } else {
                    settle.restart();
                }
            }
        }
    }
}
