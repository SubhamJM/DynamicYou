import QtQuick
import QtQuick.Controls as Controls
import qs

Row {
    id: readouts
    readonly property var runningTimer: {
        const timer = Chrono.headline;
        return timer && timer.running && timer.kind !== "stopwatch" ? timer : null;
    }

    signal openRequested(string tab)

    visible: runningTimer !== null || Chrono.swRunning
    spacing: 6

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 12
        color: Theme.alpha(Theme.text, 0.25)
    }

    component Readout: Controls.AbstractButton {
        id: button
        required property string glyph
        required property string label

        implicitWidth: contentItem.implicitWidth + 6
        implicitHeight: 24
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 3
        rightPadding: 3
        hoverEnabled: true
        Accessible.name: label + " · " + text
        background: null

        contentItem: Row {
            spacing: 4

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: button.glyph
                iconSize: 14
                color: Theme.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: button.text
                color: button.hovered || button.visualFocus ? Theme.accent : Theme.text
                font.family: "Readex Pro"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
                renderType: Text.NativeRendering
            }
        }
    }

    Readout {
        visible: readouts.runningTimer !== null
        glyph: "hourglass_top"
        label: readouts.runningTimer?.label ?? "Timer"
        text: readouts.runningTimer ? Chrono.countdown(readouts.runningTimer.left) : ""
        onClicked: readouts.openRequested("timer")
    }

    Readout {
        visible: Chrono.swRunning
        glyph: "timer"
        label: "Stopwatch"
        text: Chrono.swRunning ? Chrono.clock(Chrono.swElapsed, false) : ""
        onClicked: readouts.openRequested("stopwatch")
    }
}
