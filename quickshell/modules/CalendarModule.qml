import QtQuick
import QtQuick.Layouts
import "../lucidbar"
import "../lucidui"
import "../"

FocusScope {
    id: calRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    Keys.onEscapePressed: {
        if (typeof root !== "undefined") root.collapseToIdle();
    }

    ClockCalendar {
        id: calendarPage
        anchors.fill: parent
        focus: true
    }

    Component.onCompleted: {
        calendarPage.startVisit();
    }
}
