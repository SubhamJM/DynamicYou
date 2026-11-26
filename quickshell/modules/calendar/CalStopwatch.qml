import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: page

    property var host: null
    property real frameNow: Date.now()
    readonly property real elapsed: Chrono.swRunning ? Chrono.swBank + (page.frameNow - Chrono.swStart) : Chrono.swBank

    Timer {
        interval: 33
        repeat: true
        running: page.visible && Chrono.swRunning
        onTriggered: page.frameNow = Date.now()
    }

    readonly property var splits: {
        const out = [];
        let prev = 0;
        for (let i = 0; i < Chrono.laps.length; i++) {
            out.push({ "n": i + 1, "split": Chrono.laps[i] - prev, "total": Chrono.laps[i] });
            prev = Chrono.laps[i];
        }
        return out.reverse();
    }
    readonly property real best: page.splits.length > 1 ? Math.min.apply(null, page.splits.map((s) => s.split)) : -1
    readonly property real worst: page.splits.length > 1 ? Math.max.apply(null, page.splits.map((s) => s.split)) : -1

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // Left: Stopwatch Ring Card
        Rectangle {
            Layout.preferredWidth: 336
            Layout.fillHeight: true
            radius: 18
            color: Qt.alpha(Theme.text, 0.055)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.07)

            Item {
                id: dial
                anchors.horizontalCenter: parent.horizontalCenter
                y: 34
                width: 236
                height: 236

                CalRing {
                    anchors.fill: parent
                    thickness: 8
                    value: Chrono.swActive ? (page.elapsed % 60000) / 60000 : 0
                    progressColor: Theme.accent
                    trackColor: Qt.alpha(Theme.text, 0.09)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    CalText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: page.elapsed >= 3600000 ? 38 : 48
                        weightAxis: 680
                        tabular: true
                        text: Chrono.clock(page.elapsed, false)
                    }

                    CalText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 18
                        weightAxis: 620
                        tabular: true
                        color: Theme.accent
                        text: "." + String(Math.floor((page.elapsed % 1000) / 10)).padStart(2, "0")
                    }
                }
            }

            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 22
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                // Lap Pill
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: lapBtnRow.implicitWidth + 24
                    height: 38
                    radius: 19
                    color: Chrono.swRunning
                        ? (lapBtnM.containsMouse ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.07))
                        : Qt.alpha(Theme.text, 0.04)

                    Row {
                        id: lapBtnRow
                        anchors.centerIn: parent
                        spacing: 6

                        CalIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "flag"
                            font.pixelSize: 16
                            color: Chrono.swRunning ? Theme.text : Qt.alpha(Theme.text, 0.32)
                        }
                        CalText {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 12
                            weightAxis: 600
                            color: Chrono.swRunning ? Theme.text : Qt.alpha(Theme.text, 0.32)
                            text: I18n.tr("Lap")
                        }
                    }

                    MouseArea {
                        id: lapBtnM
                        anchors.fill: parent
                        enabled: Chrono.swRunning
                        hoverEnabled: true
                        cursorShape: Chrono.swRunning ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Chrono.swLap()
                    }
                }

                // Play/Pause Accent Pill
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 72
                    height: 46
                    radius: 23
                    color: swPlayM.pressed ? Qt.alpha(Theme.accent, 0.82) : Theme.accent
                    scale: swPlayM.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    CalIcon {
                        anchors.centerIn: parent
                        text: Chrono.swRunning ? "pause" : "play_arrow"
                        font.pixelSize: 26
                        filled: true
                        color: Theme.onAccent
                    }

                    MouseArea {
                        id: swPlayM
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Chrono.swToggle()
                    }
                }

                // Reset Pill
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: rstBtnRow.implicitWidth + 24
                    height: 38
                    radius: 19
                    color: Chrono.swActive
                        ? (rstBtnM.containsMouse ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.07))
                        : Qt.alpha(Theme.text, 0.04)

                    Row {
                        id: rstBtnRow
                        anchors.centerIn: parent
                        spacing: 6

                        CalIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "replay"
                            font.pixelSize: 16
                            color: Chrono.swActive ? Theme.text : Qt.alpha(Theme.text, 0.32)
                        }
                        CalText {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 12
                            weightAxis: 600
                            color: Chrono.swActive ? Theme.text : Qt.alpha(Theme.text, 0.32)
                            text: I18n.tr("Reset")
                        }
                    }

                    MouseArea {
                        id: rstBtnM
                        anchors.fill: parent
                        enabled: Chrono.swActive
                        hoverEnabled: true
                        cursorShape: Chrono.swActive ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Chrono.swReset()
                    }
                }
            }
        }

        // Right: Laps Card
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 18
            color: Qt.alpha(Theme.text, 0.055)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.07)

            CalText {
                id: lapHead
                x: 18
                y: 16
                font.pixelSize: 15
                weightAxis: 640
                tabular: true
                text: page.splits.length
                    ? page.splits.length + (page.splits.length === 1 ? I18n.tr(" lap") : I18n.tr(" laps"))
                    : I18n.tr("Laps")
            }

            Column {
                visible: page.splits.length === 0
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 44
                    height: 44
                    radius: 14
                    color: Qt.alpha(Theme.accent, 0.10)

                    CalIcon {
                        anchors.centerIn: parent
                        text: "flag"
                        font.pixelSize: 22
                        color: Qt.alpha(Theme.accent, 0.85)
                    }
                }

                CalText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 13
                    weightAxis: 520
                    color: Theme.subtext
                    text: I18n.tr("Laps you take land here")
                }
            }

            ListView {
                anchors.top: lapHead.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.bottomMargin: 12
                clip: true
                spacing: 6
                model: page.splits
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isBest: modelData.split === page.best
                    readonly property bool isWorst: modelData.split === page.worst
                    readonly property color bestColor: Theme.success || "#a6e3a1"
                    readonly property color worstColor: Theme.colors.error || "#f38ba8"

                    width: ListView.view.width
                    height: 44
                    radius: 12
                    color: Qt.alpha(Theme.text, 0.055)
                    border.width: 1
                    border.color: Qt.alpha(Theme.text, 0.06)

                    CalText {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 12
                        weightAxis: 560
                        color: Theme.subtext
                        tabular: true
                        text: I18n.tr("Lap %1", modelData.n)
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        CalIcon {
                            visible: isBest || isWorst
                            anchors.verticalCenter: parent.verticalCenter
                            text: isBest ? "arrow_downward" : "arrow_upward"
                            font.pixelSize: 14
                            color: isBest ? bestColor : worstColor
                        }

                        CalText {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 13
                            weightAxis: 640
                            tabular: true
                            color: isBest ? bestColor : (isWorst ? worstColor : Theme.text)
                            text: Chrono.clock(modelData.split, true)
                        }
                    }

                    CalText {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 12
                        weightAxis: 500
                        tabular: true
                        color: Theme.subtext
                        text: Chrono.clock(modelData.total, true)
                    }
                }
            }
        }
    }
}
