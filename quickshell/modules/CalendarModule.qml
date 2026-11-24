import QtQuick
import QtQuick.Layouts
import "../lucidbar"
import "../lucidui"
import "../"
import qs
import qs.lucidui
import qs.lucidbar

FocusScope {
    id: calRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    readonly property real targetWidth: 720
    readonly property real targetHeight: 490

    property string tab: "calendar"
    property bool tabSwitching: false
    readonly property bool expanded: visible && (typeof root === "undefined" || root.activeMode === "calendar")

    readonly property int pad: Theme.dp(16)
    readonly property var tabs: [
        { "key": "today", "label": I18n.tr("Today"), "icon": "wb_sunny" },
        { "key": "calendar", "label": I18n.tr("Calendar"), "icon": "calendar_month" },
        { "key": "timer", "label": I18n.tr("Timer"), "icon": "hourglass_top" },
        { "key": "stopwatch", "label": I18n.tr("Stopwatch"), "icon": "timer" },
        { "key": "world", "label": I18n.tr("World"), "icon": "public" }
    ]

    readonly property int tabIndex: {
        for (var i = 0; i < calRoot.tabs.length; i++) {
            if (calRoot.tabs[i].key === calRoot.tab)
                return i;
        }
        return 1;
    }

    function showTab(t) {
        if (t === calRoot.tab)
            return;
        calRoot.tabSwitching = true;
        tabSwitchTimer.restart();
        calRoot.tab = t;
    }

    function openTab(t) {
        showTab(t);
    }

    Timer {
        id: tabSwitchTimer
        interval: Theme.barMs(350)
        onTriggered: calRoot.tabSwitching = false
    }

    Keys.onEscapePressed: {
        if (typeof root !== "undefined") root.collapseToIdle();
    }

    Item {
        anchors.fill: parent

        Tabs {
            id: tabsBar
            x: calRoot.pad
            y: calRoot.pad - Theme.dp(6)
            width: parent.width - calRoot.pad * 2
            inline: true
            options: calRoot.tabs
            current: calRoot.tab
            onPicked: (k) => {
                calRoot.showTab(k);
            }
        }

        Item {
            id: viewport
            anchors.top: tabsBar.bottom
            anchors.topMargin: Theme.dp(10)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: calRoot.pad
            anchors.rightMargin: calRoot.pad
            height: Math.max(0, Math.min(Theme.dp(404), parent.height - y))
            clip: true

            Item {
                id: pages
                x: -calRoot.tabIndex * viewport.width
                width: viewport.width * calRoot.tabs.length
                height: viewport.height

                Behavior on x {
                    enabled: calRoot.tabSwitching
                    NumberAnimation {
                        duration: Theme.durDefaultSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }
                }

                ClockToday {
                    x: 0 * viewport.width
                    width: viewport.width
                    height: viewport.height
                    host: calRoot
                    visible: calRoot.tabIndex === 0 || calRoot.tabSwitching
                    onAddRequested: {
                        calRoot.showTab("calendar");
                        calendarPage.selectToday();
                        calendarPage.focusName();
                    }
                }

                ClockCalendar {
                    id: calendarPage
                    x: 1 * viewport.width
                    width: viewport.width
                    height: viewport.height
                    host: calRoot
                    visible: calRoot.tabIndex === 1 || calRoot.tabSwitching
                }

                ClockTimers {
                    id: timersPage
                    x: 2 * viewport.width
                    width: viewport.width
                    height: viewport.height
                    host: calRoot
                    visible: calRoot.tabIndex === 2 || calRoot.tabSwitching
                }

                ClockStopwatch {
                    id: stopwatchPage
                    x: 3 * viewport.width
                    width: viewport.width
                    height: viewport.height
                    host: calRoot
                    visible: calRoot.tabIndex === 3 || calRoot.tabSwitching
                }

                ClockWorld {
                    id: worldPage
                    x: 4 * viewport.width
                    width: viewport.width
                    height: viewport.height
                    host: calRoot
                    visible: calRoot.tabIndex === 4 || calRoot.tabSwitching
                }
            }
        }
    }

    Component.onCompleted: {
        if (calendarPage) {
            calendarPage.startVisit();
        }
    }
}
