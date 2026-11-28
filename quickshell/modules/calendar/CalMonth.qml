import QtQuick
import qs

Item {
    id: month

    property int year: Loc.now().getFullYear()
    property int monthIndex: Loc.now().getMonth()
    property var selected: null
    property int cell: 38
    property real slideX: 0
    property bool mondayFirst: Prefs.weekStartMonday

    property int thisMonth: Loc.now().getFullYear() * 12 + Loc.now().getMonth()
    readonly property bool isCurrent: month.year * 12 + month.monthIndex === month.thisMonth
    readonly property bool todaySelected: {
        Agenda.checkedDay;
        const now = Loc.now();
        return month.selected !== null
            && month.selected.year === now.getFullYear()
            && month.selected.month === now.getMonth()
            && month.selected.day === now.getDate();
    }
    readonly property var weekdays: month.mondayFirst
        ? ["M", "T", "W", "T", "F", "S", "S"]
        : ["S", "M", "T", "W", "T", "F", "S"]

    readonly property var cells: {
        Agenda.checkedDay;
        const now = Loc.now();
        const lead = (new Date(month.year, month.monthIndex, 1).getDay() + (month.mondayFirst ? 6 : 0)) % 7;
        const first = new Date(month.year, month.monthIndex, 1 - lead);
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), first.getDate() + i);
            out.push({
                "year": d.getFullYear(),
                "month": d.getMonth(),
                "day": d.getDate(),
                "other": d.getMonth() !== month.monthIndex,
                "today": d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate(),
                "marked": Agenda.hasOn(d.getFullYear(), d.getMonth(), d.getDate())
            });
        }
        return out;
    }

    signal picked(int y, int m, int d)
    signal todayRequested()

    function page(dir) {
        let m = month.monthIndex + dir;
        let y = month.year;
        if (m < 0) {
            m = 11;
            y -= 1;
        } else if (m > 11) {
            m = 0;
            y += 1;
        }
        month.year = y;
        month.monthIndex = m;
        slideIn.from = dir * 36;
        slideIn.restart();
    }

    function goToday() {
        const n = Loc.now();
        if (month.year === n.getFullYear() && month.monthIndex === n.getMonth())
            return;
        const dir = (n.getFullYear() * 12 + n.getMonth()) >= (month.year * 12 + month.monthIndex) ? 1 : -1;
        month.year = n.getFullYear();
        month.monthIndex = n.getMonth();
        slideIn.from = dir * 36;
        slideIn.restart();
    }

    implicitWidth: month.cell * 7
    implicitHeight: 36 + 8 + 22 + month.cell * 6

    Connections {
        target: Agenda
        function onCheckedDayChanged() {
            const n = Loc.now();
            const now = n.getFullYear() * 12 + n.getMonth();
            if (now === month.thisMonth) return;
            if (month.isCurrent) {
                month.year = n.getFullYear();
                month.monthIndex = n.getMonth();
            }
            month.thisMonth = now;
        }
    }

    NumberAnimation {
        id: slideIn
        target: month
        property: "slideX"
        to: 0
        duration: 180
        easing.type: Easing.OutCubic
    }

    // Header: Month Year + Nav pills
    Item {
        id: head
        width: parent.width
        height: 36

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            CalText {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 15
                weightAxis: 640
                color: Theme.accent
                text: new Date(month.year, month.monthIndex, 1).toLocaleDateString(Qt.locale(), "MMMM")
            }

            CalText {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 15
                weightAxis: 500
                color: Theme.subtext
                tabular: true
                text: String(month.year)
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Rectangle {
                visible: !month.isCurrent || (month.selected !== null && !month.todaySelected)
                width: 28
                height: 28
                radius: 14
                color: todayMouse.pressed ? Qt.alpha(Theme.accent, 0.22) : (todayMouse.containsMouse ? Qt.alpha(Theme.accent, 0.14) : Qt.alpha(Theme.text, 0.06))
                Behavior on color { ColorAnimation { duration: 120 } }

                CalIcon {
                    anchors.centerIn: parent
                    text: "today"
                    font.pixelSize: 15
                    color: todayMouse.containsMouse ? Theme.accent : Theme.subtext
                }
                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: month.todayRequested()
                }
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: prevMouse.pressed ? Qt.alpha(Theme.text, 0.16) : (prevMouse.containsMouse ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.05))
                Behavior on color { ColorAnimation { duration: 120 } }

                CalIcon {
                    anchors.centerIn: parent
                    text: "chevron_left"
                    font.pixelSize: 17
                    color: prevMouse.containsMouse ? Theme.text : Theme.subtext
                }
                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: month.page(-1)
                }
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: nextMouse.pressed ? Qt.alpha(Theme.text, 0.16) : (nextMouse.containsMouse ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.05))
                Behavior on color { ColorAnimation { duration: 120 } }

                CalIcon {
                    anchors.centerIn: parent
                    text: "chevron_right"
                    font.pixelSize: 17
                    color: nextMouse.containsMouse ? Theme.text : Theme.subtext
                }
                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: month.page(1)
                }
            }
        }
    }

    Item {
        id: body
        anchors.top: head.bottom
        anchors.topMargin: 8
        width: parent.width
        height: weekRow.height + month.cell * 6
        clip: true

        Item {
            x: month.slideX
            width: parent.width
            height: parent.height
            opacity: Math.max(0.2, 1 - Math.abs(month.slideX) / 48)

            Row {
                id: weekRow
                width: parent.width
                height: 22

                Repeater {
                    model: month.weekdays

                    CalText {
                        required property var modelData
                        required property int index
                        width: month.cell
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 11
                        weightAxis: 620
                        color: (month.mondayFirst ? index >= 5 : (index === 0 || index === 6))
                            ? Theme.accent
                            : Theme.subtext
                        text: modelData
                    }
                }
            }

            Grid {
                anchors.top: weekRow.bottom
                columns: 7

                Repeater {
                    model: month.cells

                    Item {
                        id: dayCell
                        required property var modelData
                        readonly property bool isSelected: month.selected !== null
                            && month.selected.year === modelData.year
                            && month.selected.month === modelData.month
                            && month.selected.day === modelData.day

                        width: month.cell
                        height: month.cell

                        // Clean circular pill (today = filled accent, selected = soft tonal)
                        Rectangle {
                            anchors.centerIn: parent
                            width: month.cell - 5
                            height: month.cell - 5
                            radius: width / 2
                            color: dayCell.modelData.today
                                ? Theme.accent
                                : (dayCell.isSelected
                                    ? Qt.alpha(Theme.accent, 0.22)
                                    : (dayMouse.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent"))
                            scale: dayMouse.pressed ? 0.92 : 1.0

                            Behavior on color { ColorAnimation { duration: 110 } }
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                        }

                        CalText {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: dayCell.modelData.marked ? -2 : 0
                            font.pixelSize: 13
                            weightAxis: dayCell.modelData.today ? 700 : (dayCell.isSelected ? 640 : 520)
                            tabular: true
                            color: dayCell.modelData.today
                                ? Theme.onAccent
                                : (dayCell.isSelected
                                    ? Theme.accent
                                    : (dayCell.modelData.other ? Qt.alpha(Theme.text, 0.30) : Theme.text))
                            text: String(dayCell.modelData.day)
                        }

                        // Subtle reminder dot indicator
                        Rectangle {
                            visible: dayCell.modelData.marked
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            width: 4
                            height: 4
                            radius: 2
                            color: dayCell.modelData.today
                                ? Theme.onAccent
                                : (dayCell.modelData.other ? Qt.alpha(Theme.accent, 0.45) : Theme.accent)
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: month.picked(dayCell.modelData.year, dayCell.modelData.month, dayCell.modelData.day)
                        }
                    }
                }
            }
        }
    }
}
