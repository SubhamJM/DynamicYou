import QtQuick
import QtQuick.Layouts
import qs
import "calendar"

FocusScope {
    id: calRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    readonly property real targetWidth: 720
    readonly property real targetHeight: 492

    property string tab: "calendar"
    property bool tabSwitching: false
    readonly property bool expanded: visible && (typeof root === "undefined" || root.activeMode === "calendar")

    readonly property var tabs: [
        { "key": "today", "label": I18n.tr("Today"), "icon": "wb_sunny" },
        { "key": "calendar", "label": I18n.tr("Calendar"), "icon": "calendar_month" },
        { "key": "timer", "label": I18n.tr("Timer"), "icon": "hourglass_top" },
        { "key": "stopwatch", "label": I18n.tr("Stopwatch"), "icon": "timer" },
        { "key": "world", "label": I18n.tr("World"), "icon": "public" }
    ]

    readonly property int tabIndex: {
        for (var i = 0; i < calRoot.tabs.length; i++) {
            if (calRoot.tabs[i].key === calRoot.tab) return i;
        }
        return 1;
    }

    function showTab(t) {
        if (t === calRoot.tab) return;
        calRoot.tabSwitching = true;
        tabSwitchTimer.restart();
        calRoot.tab = t;
    }

    function openTab(t) {
        showTab(t);
    }

    Timer {
        id: tabSwitchTimer
        interval: 260
        onTriggered: calRoot.tabSwitching = false
    }

    Keys.onEscapePressed: {
        if (typeof root !== "undefined") root.collapseToIdle();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 10
        spacing: 12

        // Clean Inline Material 3 Tab Strip with sliding indicator
        Item {
            id: tabBar
            Layout.fillWidth: true
            Layout.preferredHeight: 42

            readonly property real segW: width / Math.max(1, calRoot.tabs.length)
            property real currentLabelW: 64

            Row {
                id: tabRow
                anchors.fill: parent

                Repeater {
                    model: calRoot.tabs

                    delegate: Item {
                        required property var modelData
                        required property int index
                        readonly property bool active: calRoot.tab === modelData.key

                        width: tabBar.segW
                        height: tabBar.height

                        onActiveChanged: if (active) tabBar.currentLabelW = tabContent.implicitWidth
                        Component.onCompleted: if (active) tabBar.currentLabelW = tabContent.implicitWidth

                        Rectangle {
                            anchors.fill: parent
                            anchors.bottomMargin: 2
                            radius: 10
                            color: tabM.pressed
                                ? Qt.alpha(active ? Theme.accent : Theme.text, 0.12)
                                : (tabM.containsMouse ? Qt.alpha(active ? Theme.accent : Theme.text, 0.06) : "transparent")
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Row {
                            id: tabContent
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -1
                            spacing: 7

                            CalIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                font.pixelSize: 18
                                filled: active
                                color: active ? Theme.accent : (tabM.containsMouse ? Theme.text : Theme.subtext)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            CalText {
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 13
                                weightAxis: active ? 480 : 420
                                color: active ? Theme.accent : (tabM.containsMouse ? Theme.text : Theme.subtext)
                                text: modelData.label
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        MouseArea {
                            id: tabM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calRoot.showTab(modelData.key)
                        }
                    }
                }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: Qt.alpha(Theme.text, 0.10)
            }

            Rectangle {
                id: tabIndicator
                readonly property real indW: Math.max(28, tabBar.currentLabelW)
                anchors.bottom: parent.bottom
                height: 3
                width: indW
                x: calRoot.tabIndex * tabBar.segW + (tabBar.segW - indW) / 2
                topLeftRadius: 3
                topRightRadius: 3
                color: Theme.accent

                Behavior on x {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }
        }

        // Slideable Viewport
        Item {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Item {
                id: pages
                x: -calRoot.tabIndex * viewport.width
                width: viewport.width * calRoot.tabs.length
                height: viewport.height

                Behavior on x {
                    enabled: calRoot.tabSwitching
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                CalToday {
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

                CalCalendar {
                    id: calendarPage
                    x: 1 * viewport.width
                    width: viewport.width
                    height: viewport.height
                    host: calRoot
                    visible: calRoot.tabIndex === 1 || calRoot.tabSwitching
                }

                CalTimers {
                    x: 2 * viewport.width
                    width: viewport.width
                    height: viewport.height
                    host: calRoot
                    visible: calRoot.tabIndex === 2 || calRoot.tabSwitching
                }

                CalStopwatch {
                    x: 3 * viewport.width
                    width: viewport.width
                    height: viewport.height
                    host: calRoot
                    visible: calRoot.tabIndex === 3 || calRoot.tabSwitching
                }

                CalWorld {
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
        if (calendarPage) calendarPage.startVisit();
    }
}
