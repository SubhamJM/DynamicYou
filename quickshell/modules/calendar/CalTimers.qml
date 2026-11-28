import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: page

    property var host: null
    property string focusId: ""
    property int setup: 300
    readonly property var presets: [60, 300, 600, 900, 1500, 3600]
    readonly property var focused: {
        Chrono.now;
        let f = Chrono.timers.find((t) => t.id === page.focusId);
        if (!f) f = Chrono.timers.find((t) => t.running);
        return f || null;
    }
    readonly property real remainMs: page.focused ? Chrono.remaining(page.focused) : page.setup * 1000
    readonly property real totalMs: page.focused ? page.focused.total : page.setup * 1000
    readonly property bool shown: page.visible && (!page.host || page.host.expanded)

    function spanText(ms) {
        const m = Math.round(ms / 60000);
        return m >= 60 ? Math.floor(m / 60) + " h" + (m % 60 ? " " + (m % 60) + " min" : "") : m + " min";
    }

    function nudgeSetup(sec) {
        page.setup = Math.max(10, Math.min(24 * 3600, page.setup + sec));
    }

    function start() {
        Chrono.addTimer(page.setup, "");
        page.focusId = Chrono.timers[Chrono.timers.length - 1].id;
    }

    onShownChanged: {
        if (page.shown) Chrono.rollDay();
        else pomo.tuning = false;
    }

    component PomoStepper: Item {
        id: st
        property string label: ""
        property int value: 0
        property int from: 0
        property int to: 10
        property int step: 1
        property string zeroText: ""
        signal moved(int v)

        function nudge(by) {
            const v = Math.max(st.from, Math.min(st.to, st.value + by * st.step));
            if (v !== st.value) st.moved(v);
        }

        implicitHeight: 30

        CalText {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 12
            weightAxis: 520
            color: Theme.subtext
            text: st.label
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: decMouse.containsMouse && st.value > st.from ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.05)

                CalIcon {
                    anchors.centerIn: parent
                    text: "remove"
                    font.pixelSize: 14
                    color: st.value > st.from ? Theme.text : Qt.alpha(Theme.text, 0.30)
                }
                MouseArea {
                    id: decMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: st.value > st.from ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: st.nudge(-1)
                }
            }

            CalText {
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 12
                weightAxis: 640
                tabular: true
                text: st.value === 0 && st.zeroText !== "" ? st.zeroText : String(st.value)
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: incMouse.containsMouse && st.value < st.to ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.05)

                CalIcon {
                    anchors.centerIn: parent
                    text: "add"
                    font.pixelSize: 14
                    color: st.value < st.to ? Theme.text : Qt.alpha(Theme.text, 0.30)
                }
                MouseArea {
                    id: incMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: st.value < st.to ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: st.nudge(1)
                }
            }
        }

        WheelHandler {
            onWheel: (e) => st.nudge(e.angleDelta.y > 0 ? 1 : -1)
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // Left: Borderless Main Countdown Dial Card
        Rectangle {
            id: dialCard
            Layout.preferredWidth: 304
            Layout.fillHeight: true
            radius: 20
            color: Theme.surfaceHigh

            CalText {
                x: 18
                y: 16
                font.pixelSize: 15
                weightAxis: 640
                text: page.focused ? (page.focused.label || I18n.tr("Timer")) : I18n.tr("New timer")
            }

            Item {
                id: dial
                anchors.horizontalCenter: parent.horizontalCenter
                y: 48
                width: 192
                height: 192

                CalRing {
                    anchors.fill: parent
                    thickness: 8
                    value: page.totalMs > 0 ? page.remainMs / page.totalMs : 0
                    progressColor: (page.focused && page.remainMs <= 0) ? (Theme.colors.error || "#f38ba8") : Theme.accent
                    trackColor: Qt.alpha(Theme.text, 0.09)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    CalText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: page.remainMs >= 3600000 ? 34 : 42
                        weightAxis: 660
                        tabular: true
                        color: (page.focused && page.remainMs <= 0) ? (Theme.colors.error || "#f38ba8") : Theme.text
                        text: Chrono.countdown(page.remainMs)
                    }

                    CalText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 11
                        weightAxis: 520
                        color: Theme.subtext
                        tabular: true
                        text: {
                            if (!page.focused) return I18n.tr("Scroll to set");
                            if (page.remainMs <= 0) return I18n.tr("Done");
                            if (!page.focused.running) return I18n.tr("Paused");
                            const end = new Date(Loc.nowMs() + page.remainMs);
                            return I18n.tr("Ends %1", end.toLocaleTimeString(I18n.locale, Prefs.clock24h ? "HH:mm" : "h:mm AP"));
                        }
                    }
                }

                WheelHandler {
                    enabled: !page.focused
                    onWheel: (e) => {
                        const s = page.setup >= 600 ? 60 : (page.setup >= 120 ? 30 : 10);
                        page.nudgeSetup(e.angleDelta.y > 0 ? s : -s);
                    }
                }
            }

            // Preset pills in a single clean row when idle
            Row {
                visible: !page.focused
                anchors.top: dial.bottom
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Repeater {
                    model: page.presets

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: page.setup === modelData
                        width: presetLabel.implicitWidth + 14
                        height: 26
                        radius: 13
                        color: active ? Theme.primaryContainer : (pMouse.containsMouse ? Qt.alpha(Theme.text, 0.10) : Theme.surfaceHighest)

                        Behavior on color { ColorAnimation { duration: 110 } }

                        CalText {
                            id: presetLabel
                            anchors.centerIn: parent
                            font.pixelSize: 11
                            weightAxis: active ? 640 : 520
                            tabular: true
                            color: active ? Theme.accent : Theme.subtext
                            text: modelData >= 3600 ? I18n.tr("1h") : I18n.tr("%1m", Math.round(modelData / 60))
                        }

                        MouseArea {
                            id: pMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.setup = modelData
                        }
                    }
                }
            }

            // Bottom transport row
            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 20
                    color: minusMouse.containsMouse ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.07)

                    CalIcon {
                        anchors.centerIn: parent
                        text: page.focused ? "replay" : "remove"
                        font.pixelSize: 18
                    }
                    MouseArea {
                        id: minusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.focused ? Chrono.reset(page.focused.id) : page.nudgeSetup(-60)
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 72
                    height: 44
                    radius: 22
                    color: playMouse.pressed ? Qt.alpha(Theme.accent, 0.82) : Theme.accent
                    scale: playMouse.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    CalIcon {
                        anchors.centerIn: parent
                        text: page.focused && page.focused.running ? "pause" : "play_arrow"
                        font.pixelSize: 24
                        filled: true
                        color: Theme.onAccent
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.focused ? Chrono.toggle(page.focused.id) : page.start()
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 20
                    color: plusMouse.containsMouse ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.07)

                    CalIcon {
                        anchors.centerIn: parent
                        text: "add"
                        font.pixelSize: 18
                    }
                    MouseArea {
                        id: plusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.focused ? Chrono.extend(page.focused.id, 60) : page.nudgeSetup(60)
                    }
                }
            }
        }

        // Right Column: Pomodoro + Timers List
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: pomo
                property bool tuning: false
                readonly property real t: Math.max(0, Math.min(1, (pomo.height - 170) / Math.max(1, parent.height - 170)))
                readonly property bool tinted: Chrono.pomoActive && !pomo.tuning

                width: parent.width
                height: pomo.tuning ? parent.height : 170
                radius: 20
                color: pomo.tinted ? Theme.primaryContainer : Theme.surfaceHigh

                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 160 } }

                Column {
                    id: pomoHead
                    x: 18
                    y: 16
                    spacing: 2

                    Row {
                        spacing: 8

                        CalIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Chrono.pomoPhase === "focus" ? "psychiatry" : (Chrono.pomoActive ? "coffee" : "timer")
                            font.pixelSize: 18
                            filled: true
                            color: Chrono.pomoActive ? Theme.accent : Theme.subtext
                        }

                        CalText {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 15
                            weightAxis: 640
                            text: Chrono.pomoActive ? Chrono.phaseLabel(Chrono.pomoPhase) : I18n.tr("Pomodoro")
                        }
                    }

                    CalText {
                        font.pixelSize: 11
                        weightAxis: 480
                        color: Theme.subtext
                        tabular: true
                        text: I18n.tr("%1 min focus · %2 min break · every %3", Prefs.pomodoroFocus, Prefs.pomodoroShort, Prefs.pomodoroRounds)
                    }

                    CalText {
                        visible: Prefs.pomodoroGoal > 0 || Chrono.pomoToday > 0
                        font.pixelSize: 11
                        weightAxis: Chrono.pomoGoalMet ? 640 : 480
                        color: Chrono.pomoGoalMet ? Theme.accent : Theme.subtext
                        tabular: true
                        text: {
                            const n = Chrono.pomoToday;
                            const bits = [Prefs.pomodoroGoal > 0 ? I18n.tr("%1 of %2 today", n, Prefs.pomodoroGoal) : n + (n === 1 ? I18n.tr(" session today") : I18n.tr(" sessions today"))];
                            if (Chrono.pomoTodayMs > 0) bits.push(I18n.tr("%1 focused", page.spanText(Chrono.pomoTodayMs)));
                            return bits.join(" · ");
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 12
                    width: 30
                    height: 30
                    radius: 15
                    color: tuneMouse.containsMouse ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.05)

                    CalIcon {
                        anchors.centerIn: parent
                        text: pomo.tuning ? "close" : "tune"
                        font.pixelSize: 16
                        color: pomo.tuning ? Theme.accent : Theme.subtext
                    }
                    MouseArea {
                        id: tuneMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pomo.tuning = !pomo.tuning
                    }
                }

                // Expanded Pomodoro Tuning Section
                Item {
                    anchors.top: pomoHead.bottom
                    anchors.topMargin: 10
                    anchors.bottom: pomoCount.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    visible: opacity > 0
                    opacity: Math.max(0, (pomo.t - 0.35) / 0.65)
                    clip: true

                    Column {
                        width: parent.width
                        spacing: 8

                        Row {
                            spacing: 6
                            Repeater {
                                model: Chrono.pomoPresets
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool sel: Chrono.pomoPreset === modelData.key
                                    width: ppTxt.implicitWidth + 18
                                    height: 26
                                    radius: 13
                                    color: sel ? Theme.accent : Qt.alpha(Theme.text, 0.06)

                                    CalText {
                                        id: ppTxt
                                        anchors.centerIn: parent
                                        font.pixelSize: 11
                                        weightAxis: sel ? 640 : 520
                                        color: sel ? Theme.onAccent : Theme.subtext
                                        text: modelData.label
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Chrono.pomoUsePreset(modelData.key)
                                    }
                                }
                            }
                        }

                        Grid {
                            id: lengths
                            readonly property real cellW: (width - columnSpacing) / 2
                            width: parent.width
                            columns: 2
                            columnSpacing: 14
                            rowSpacing: 4

                            PomoStepper { width: lengths.cellW; label: I18n.tr("Focus"); from: 5; to: 90; step: 5; value: Prefs.pomodoroFocus; onMoved: (v) => Prefs.pomodoroFocus = v }
                            PomoStepper { width: lengths.cellW; label: I18n.tr("Rounds"); from: 2; to: 8; value: Prefs.pomodoroRounds; onMoved: (v) => Prefs.pomodoroRounds = v }
                            PomoStepper { width: lengths.cellW; label: I18n.tr("Break"); from: 1; to: 30; value: Prefs.pomodoroShort; onMoved: (v) => Prefs.pomodoroShort = v }
                            PomoStepper { width: lengths.cellW; label: I18n.tr("Long break"); from: 5; to: 60; step: 5; value: Prefs.pomodoroLong; onMoved: (v) => Prefs.pomodoroLong = v }
                            PomoStepper { width: lengths.cellW; label: I18n.tr("Daily goal"); to: 16; zeroText: I18n.tr("Off"); value: Prefs.pomodoroGoal; onMoved: (v) => Prefs.pomodoroGoal = v }
                        }

                        Flow {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: [
                                    { label: I18n.tr("Auto breaks"), active: Prefs.pomodoroAutoStart, toggle: () => Prefs.pomodoroAutoStart = !Prefs.pomodoroAutoStart },
                                    { label: I18n.tr("Auto focus"), active: Prefs.pomodoroAutoFocus, toggle: () => Prefs.pomodoroAutoFocus = !Prefs.pomodoroAutoFocus },
                                    { label: I18n.tr("Repeat sets"), active: Prefs.pomodoroRepeat, toggle: () => Prefs.pomodoroRepeat = !Prefs.pomodoroRepeat },
                                    { label: I18n.tr("Do not disturb"), active: Prefs.pomodoroSilence, toggle: () => Prefs.pomodoroSilence = !Prefs.pomodoroSilence }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    width: optTxt.implicitWidth + 18
                                    height: 26
                                    radius: 13
                                    color: modelData.active ? Theme.primaryContainer : Theme.surfaceHighest

                                    CalText {
                                        id: optTxt
                                        anchors.centerIn: parent
                                        font.pixelSize: 11
                                        weightAxis: modelData.active ? 620 : 500
                                        color: modelData.active ? Theme.accent : Theme.subtext
                                        text: modelData.label
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: modelData.toggle()
                                    }
                                }
                            }
                        }
                    }
                }

                CalText {
                    id: pomoCount
                    x: 18
                    anchors.bottom: dots.top
                    anchors.bottomMargin: 6
                    font.pixelSize: text.length > 5 ? 32 : 38
                    weightAxis: 660
                    tabular: true
                    text: Chrono.countdown(Chrono.pomoActive ? Chrono.pomoRemaining : Prefs.pomodoroFocus * 60000)
                }

                Row {
                    id: dots
                    x: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    spacing: 6

                    Repeater {
                        model: Prefs.pomodoroRounds
                        delegate: Rectangle {
                            required property int index
                            readonly property bool done: index < Chrono.pomoRound % Math.max(1, Prefs.pomodoroRounds)
                            readonly property bool current: Chrono.pomoPhase === "focus" && index === Chrono.pomoRound % Math.max(1, Prefs.pomodoroRounds)
                            anchors.verticalCenter: parent.verticalCenter
                            width: current ? 20 : 8
                            height: 8
                            radius: 4
                            color: done || current ? Theme.accent : Qt.alpha(Theme.text, 0.18)
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    spacing: 6

                    Repeater {
                        model: Chrono.pomoActive ? [
                            { icon: "more_time", fn: () => Chrono.pomoExtend(60) },
                            { icon: "stop", fn: () => Chrono.pomoStop() },
                            { icon: "skip_next", fn: () => Chrono.pomoSkip() }
                        ] : []

                        delegate: Rectangle {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: 16
                            color: pmBtnM.containsMouse ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.06)

                            CalIcon {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.pixelSize: 16
                            }
                            MouseArea {
                                id: pmBtnM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.fn()
                            }
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 36
                        radius: 18
                        color: Theme.accent

                        CalIcon {
                            anchors.centerIn: parent
                            text: Chrono.pomoRunning ? "pause" : "play_arrow"
                            font.pixelSize: 20
                            filled: true
                            color: Theme.onAccent
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Chrono.pomoToggle()
                        }
                    }
                }
            }

            // Bottom Right: Active Timers Card
            Rectangle {
                anchors.top: pomo.bottom
                anchors.topMargin: 12
                anchors.bottom: parent.bottom
                width: parent.width
                visible: opacity > 0
                opacity: 1 - Math.min(1, pomo.t * 2.5)
                radius: 20
                color: Theme.surfaceHigh

                RowLayout {
                    id: listHead
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 14
                    anchors.leftMargin: 18
                    anchors.rightMargin: 14

                    CalText {
                        font.pixelSize: 14
                        weightAxis: 620
                        color: Chrono.timers.length ? Theme.text : Theme.subtext
                        text: Chrono.timers.length ? I18n.tr("Timers") : I18n.tr("No timers running")
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        visible: Chrono.timers.some((t) => !t.running && t.left <= 0)
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: clrTxt.implicitWidth + 16
                        radius: 12
                        color: Qt.alpha(Theme.accent, 0.12)

                        CalText {
                            id: clrTxt
                            anchors.centerIn: parent
                            font.pixelSize: 11
                            weightAxis: 600
                            color: Theme.accent
                            text: I18n.tr("Clear done")
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Chrono.clearFinished()
                        }
                    }
                }

                Flickable {
                    anchors.top: listHead.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.bottomMargin: 12
                    contentHeight: timerCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: timerCol
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: Chrono.timers

                            delegate: Rectangle {
                                required property var modelData
                                readonly property real rem: Chrono.remaining(modelData)
                                readonly property bool isFocus: page.focused !== null && page.focused.id === modelData.id

                                width: timerCol.width
                                height: 50
                                radius: 14
                                color: isFocus ? Theme.primaryContainer : Theme.surfaceHighest

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.focusId = modelData.id
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    CalRing {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        thickness: 4
                                        value: modelData.total > 0 ? rem / modelData.total : 0
                                        progressColor: rem <= 0 ? (Theme.colors.error || "#f38ba8") : Theme.accent
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        CalText {
                                            font.pixelSize: 14
                                            weightAxis: 640
                                            tabular: true
                                            text: Chrono.countdown(rem)
                                        }

                                        CalText {
                                            font.pixelSize: 11
                                            weightAxis: 480
                                            color: Theme.subtext
                                            text: (modelData.label || I18n.tr("Timer")) + (rem <= 0 ? I18n.tr(" · done") : (modelData.running ? "" : I18n.tr(" · paused")))
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: Qt.alpha(Theme.text, 0.08)

                                        CalIcon {
                                            anchors.centerIn: parent
                                            text: rem <= 0 ? "replay" : (modelData.running ? "pause" : "play_arrow")
                                            font.pixelSize: 15
                                            filled: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Chrono.toggle(modelData.id)
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: closeM.containsMouse ? Qt.alpha(Theme.colors.error || "#f38ba8", 0.18) : "transparent"

                                        CalIcon {
                                            anchors.centerIn: parent
                                            text: "close"
                                            font.pixelSize: 15
                                            color: closeM.containsMouse ? (Theme.colors.error || "#f38ba8") : Theme.subtext
                                        }
                                        MouseArea {
                                            id: closeM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Chrono.remove(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
