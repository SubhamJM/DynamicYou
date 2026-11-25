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

    visible: false
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
                iconSize: 15
                color: Theme.accent
                renderType: Text.CurveRendering
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: button.text
                color: button.hovered || button.visualFocus ? Theme.accent : (Theme.colors.text_primary ?? "#f5f5f7")
                font.family: "Google Sans Flex"
                font.pixelSize: 13
                font.weight: Font.Medium
                font.variableAxes: ({ "wght": 500, "wdth": 100 })
                font.features: ({ "tnum": 1 })
                renderType: Text.QtRendering
                font.hintingPreference: Font.PreferNoHinting
                antialiasing: true
                smooth: true
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
