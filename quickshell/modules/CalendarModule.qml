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
        anchors.margins: 14
        spacing: 12

        // Matushell Header Bar: Back Pill + Segmented Tab Pill Switcher
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: backM.pressed ? Qt.alpha(Theme.text, 0.16) : (backM.containsMouse ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.06))
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.07)

                Behavior on color { ColorAnimation { duration: 120 } }

                CalIcon {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    font.pixelSize: 17
                    filled: backM.containsMouse
                    color: backM.containsMouse ? Theme.text : Qt.alpha(Theme.text, 0.78)
                }

                MouseArea {
                    id: backM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof root !== "undefined") root.collapseToIdle();
                    }
                }
            }

            Rectangle {
                id: tabBarBg
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 18
                color: Qt.alpha(Theme.text, 0.06)
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.07)

                readonly property real segW: (width - 6) / Math.max(1, calRoot.tabs.length)

                // Sliding Accent Pill Indicator
                Rectangle {
                    x: 3 + calRoot.tabIndex * tabBarBg.segW
                    y: 3
                    width: tabBarBg.segW
                    height: parent.height - 6
                    radius: 15
                    color: Theme.accent

                    Behavior on x {
                        NumberAnimation {
                            duration: 210
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 3

                    Repeater {
                        model: calRoot.tabs

                        delegate: Item {
                            required property var modelData
                            required property int index
                            readonly property bool active: calRoot.tab === modelData.key

                            width: tabBarBg.segW
                            height: tabBarBg.height - 6

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                CalIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font.pixelSize: 16
                                    filled: active
                                    color: active ? Theme.onAccent : (tabM.containsMouse ? Theme.text : Theme.subtext)

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                CalText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 12
                                    weightAxis: active ? 660 : 540
                                    color: active ? Theme.onAccent : (tabM.containsMouse ? Theme.text : Theme.subtext)
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
