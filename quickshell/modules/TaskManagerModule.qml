import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: taskManagerRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    // ==========================================
    // PROPERTIES & THEME
    // ==========================================
    readonly property color colAccent: Theme.accent ?? "#a8c7fa"
    readonly property color colCard: Qt.rgba(255, 255, 255, 0.055)
    readonly property color colCardHover: Qt.rgba(255, 255, 255, 0.10)
    readonly property color colCardSelected: Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.16)
    readonly property color colDanger: "#ff5449"
    readonly property color colDangerHover: "#ff6e65"
    readonly property color colDangerBg: Qt.rgba(255, 84, 73, 0.18)
    readonly property color colWarning: "#f59f00"
    readonly property color colSuccess: "#51cf66"
    readonly property color colText: "#f5f5f7"
    readonly property color colSubtext: Qt.rgba(255, 255, 255, 0.65)
    readonly property color colMuted: Qt.rgba(255, 255, 255, 0.38)

    // State & Metrics
    property real cpuTotal: 0.0
    property real memUsedGb: 0.0
    property real memTotalGb: 0.0
    property real memPercent: 0.0
    property int tasksTotalCount: 0
    property int tasksAppsCount: 0
    property int tasksBgCount: 0
    property var cpuHistory: [12, 16, 14, 20, 18, 22, 19, 25, 21, 24, 28, 20]
    property var memHistory: [42, 42, 43, 43, 44, 44, 43, 44, 45, 45, 45, 46]

    property var rawProcesses: []
    property int activeTab: 0 // 0: Apps, 1: Background, 2: All
    property string sortField: "cpu" // "cpu", "mem", "name"
    property bool sortAsc: false
    property string searchQuery: ""
    property int selectedPid: -1
    property bool isRefreshing: false
    property string statusMessage: ""

    ListModel { id: filteredProcessModel }

    function forceSearchFocus() {
        searchInput.forceActiveFocus();
    }

    function refresh() {
        if (!taskPoller.running) {
            isRefreshing = true;
            taskPoller.running = true;
        }
    }

    function killProcess(pid, force) {
        if (!pid || pid <= 0) return;
        statusMessage = "Terminating PID " + pid + "...";
        statusTimer.restart();

        // Optimistically remove or mark in UI
        for (var i = 0; i < filteredProcessModel.count; i++) {
            if (filteredProcessModel.get(i).pid === pid) {
                filteredProcessModel.remove(i);
                break;
            }
        }

        taskKiller.command = [
            "python3",
            (Quickshell.shellDir || Quickshell.configDir) + "/scripts/task_manager.py",
            "kill",
            pid.toString(),
            force ? "--force" : ""
        ];
        taskKiller.running = true;
    }

    function applyFilterAndSort() {
        filteredProcessModel.clear();
        var q = searchQuery.toLowerCase().trim();
        var list = [];

        for (var i = 0; i < rawProcesses.length; i++) {
            var p = rawProcesses[i];

            // Category Tab Filter
            if (activeTab === 0 && p.category !== "app") continue;
            if (activeTab === 1 && (p.category !== "background" || p.is_kernel)) continue;
            // Tab 2 is "All", which includes everything

            // Search Query Filter
            if (q !== "") {
                var matchesName = p.name && p.name.toLowerCase().indexOf(q) !== -1;
                var matchesDisplay = p.display_name && p.display_name.toLowerCase().indexOf(q) !== -1;
                var matchesTitle = p.title && p.title.toLowerCase().indexOf(q) !== -1;
                var matchesPid = p.pid && p.pid.toString().indexOf(q) !== -1;
                var matchesUser = p.user && p.user.toLowerCase().indexOf(q) !== -1;
                if (!matchesName && !matchesDisplay && !matchesTitle && !matchesPid && !matchesUser) {
                    continue;
                }
            }

            list.push(p);
        }

        // Sorting
        list.sort(function(a, b) {
            var diff = 0;
            if (sortField === "cpu") {
                diff = a.cpu - b.cpu;
            } else if (sortField === "mem") {
                diff = a.mem_mb - b.mem_mb;
            } else if (sortField === "name") {
                diff = (a.display_name || a.name).localeCompare(b.display_name || b.name);
            } else if (sortField === "pid") {
                diff = a.pid - b.pid;
            }
            return sortAsc ? diff : -diff;
        });

        for (var j = 0; j < list.length; j++) {
            filteredProcessModel.append(list[j]);
        }
    }

    Timer {
        id: statusTimer
        interval: 2200
        repeat: false
        onTriggered: taskManagerRoot.statusMessage = ""
    }

    // Auto-refresh timer when module is active
    Timer {
        id: autoRefreshTimer
        interval: 1000
        repeat: true
        running: taskManagerRoot.visible && root.activeMode === "taskmanager"
        onTriggered: {
            if (!taskPoller.running) {
                taskPoller.running = true;
            }
        }
    }

    onVisibleChanged: {
        if (visible && root.activeMode === "taskmanager") {
            refresh();
            Qt.callLater(forceSearchFocus);
        }
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode === "taskmanager") {
                taskManagerRoot.refresh();
                Qt.callLater(forceSearchFocus);
            }
        }
    }

    Component.onCompleted: {
        refresh();
    }

    // ==========================================
    // BACKEND PROCESSES
    // ==========================================
    Process {
        id: taskPoller
        running: false
        command: [
            "python3",
            (Quickshell.shellDir || Quickshell.configDir) + "/scripts/task_manager.py",
            "list"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                taskManagerRoot.isRefreshing = false;
                var raw = this.text.trim();
                if (!raw) return;
                try {
                    var data = JSON.parse(raw);
                    if (data.cpu_total !== undefined) {
                        taskManagerRoot.cpuTotal = data.cpu_total;
                        taskManagerRoot.memUsedGb = data.mem_used_gb;
                        taskManagerRoot.memTotalGb = data.mem_total_gb;
                        taskManagerRoot.memPercent = data.mem_percent;
                        taskManagerRoot.tasksTotalCount = data.tasks_total;
                        taskManagerRoot.tasksAppsCount = data.tasks_apps;
                        taskManagerRoot.tasksBgCount = data.tasks_bg;
                        taskManagerRoot.rawProcesses = data.processes || [];

                        var newCpu = (taskManagerRoot.cpuHistory || []).slice();
                        newCpu.push(data.cpu_total);
                        if (newCpu.length > 20) newCpu.shift();
                        taskManagerRoot.cpuHistory = newCpu;

                        var newMem = (taskManagerRoot.memHistory || []).slice();
                        newMem.push(data.mem_percent);
                        if (newMem.length > 20) newMem.shift();
                        taskManagerRoot.memHistory = newMem;

                        taskManagerRoot.applyFilterAndSort();
                    }
                } catch (e) {
                    console.log("TaskManager JSON parse error:", e);
                }
            }
        }
    }

    Process {
        id: taskKiller
        running: false
        onExited: {
            taskPoller.running = true;
        }
    }

    // ==========================================
    // MAIN LAYOUT
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ── 1. HEADER BAR & SYSTEM STATS OVERVIEW ────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 12

            // Tactile Close Button
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: closeMouse.containsMouse ? taskManagerRoot.colCardHover : taskManagerRoot.colCard
                border.width: 0
                scale: closeMouse.pressed ? 0.92 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 16
                    color: closeMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.collapseToIdle()
                }
            }

            // Header Title & Icon
            RowLayout {
                spacing: 9
                MaterialSymbol {
                    text: "monitoring"
                    iconSize: 22
                    color: taskManagerRoot.colAccent
                    fill: 1
                }

                ColumnLayout {
                    spacing: 1
                    Text {
                        text: "Task Manager"
                        font.family: "Noto Sans"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: taskManagerRoot.colText
                    }
                    Text {
                        text: taskManagerRoot.statusMessage !== "" 
                            ? taskManagerRoot.statusMessage 
                            : (taskManagerRoot.tasksTotalCount > 0 ? (taskManagerRoot.tasksTotalCount + " processes active") : "Monitoring system processes")
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        color: taskManagerRoot.statusMessage !== "" ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // CPU Gauge Capsule with Live Rolling Sparkline
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: cpuRow.implicitWidth + 56
                radius: 16
                clip: true
                color: taskManagerRoot.cpuTotal > 70 
                    ? Qt.rgba(255, 84, 73, 0.20) 
                    : (taskManagerRoot.cpuTotal > 40 ? Qt.rgba(245, 159, 0, 0.18) : taskManagerRoot.colCard)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.06)

                Sparkline {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    width: 46
                    values: taskManagerRoot.cpuHistory
                    maximum: 100
                    strokeColor: taskManagerRoot.cpuTotal > 70 ? taskManagerRoot.colDanger : (taskManagerRoot.cpuTotal > 40 ? taskManagerRoot.colWarning : taskManagerRoot.colAccent)
                    fillOpacity: 0.18
                    strokeWidth: 1.6
                }

                RowLayout {
                    id: cpuRow
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    MaterialSymbol {
                        text: "memory"
                        iconSize: 16
                        fill: 1
                        color: taskManagerRoot.cpuTotal > 70 ? taskManagerRoot.colDanger : (taskManagerRoot.cpuTotal > 40 ? taskManagerRoot.colWarning : taskManagerRoot.colAccent)
                    }

                    Text {
                        text: "CPU " + Math.round(taskManagerRoot.cpuTotal) + "%"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: taskManagerRoot.colText
                    }
                }
            }

            // RAM Gauge Capsule with Live Rolling Sparkline
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: ramRow.implicitWidth + 56
                radius: 16
                clip: true
                color: taskManagerRoot.memPercent > 85 
                    ? Qt.rgba(255, 84, 73, 0.20) 
                    : (taskManagerRoot.memPercent > 70 ? Qt.rgba(245, 159, 0, 0.18) : taskManagerRoot.colCard)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.06)

                Sparkline {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    width: 46
                    values: taskManagerRoot.memHistory
                    maximum: 100
                    strokeColor: taskManagerRoot.memPercent > 85 ? taskManagerRoot.colDanger : (taskManagerRoot.memPercent > 70 ? taskManagerRoot.colWarning : taskManagerRoot.colAccent)
                    fillOpacity: 0.18
                    strokeWidth: 1.6
                }

                RowLayout {
                    id: ramRow
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    MaterialSymbol {
                        text: "storage"
                        iconSize: 16
                        fill: 1
                        color: taskManagerRoot.memPercent > 85 ? taskManagerRoot.colDanger : (taskManagerRoot.memPercent > 70 ? taskManagerRoot.colWarning : taskManagerRoot.colAccent)
                    }

                    Text {
                        text: "RAM " + taskManagerRoot.memUsedGb.toFixed(1) + " GB (" + Math.round(taskManagerRoot.memPercent) + "%)"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: taskManagerRoot.colText
                    }
                }
            }

            // Quick Refresh Button
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: refreshMouse.containsMouse ? taskManagerRoot.colCardHover : taskManagerRoot.colCard
                border.width: 0
                scale: refreshMouse.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                MaterialSymbol {
                    id: refreshIcon
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 16
                    color: taskManagerRoot.isRefreshing ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                    rotation: taskManagerRoot.isRefreshing ? 360 : 0
                    Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: taskManagerRoot.refresh()
                }
            }
        }

        // ── 2. FILTER TABS, SEARCH BAR & SORT SELECTOR ─────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Segmented Category Tabs (Apps | Background | All) with Airy Spacing
            Rectangle {
                Layout.preferredHeight: 38
                Layout.preferredWidth: tabsRow.implicitWidth + 12
                radius: 19
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 0

                RowLayout {
                    id: tabsRow
                    anchors.centerIn: parent
                    spacing: 6

                    // Tab 0: Apps
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: appTabRow.implicitWidth + 24
                        radius: 14
                        color: taskManagerRoot.activeTab === 0 ? taskManagerRoot.colAccent : (appTabMouse.containsMouse ? taskManagerRoot.colCardHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            id: appTabRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                text: "apps"
                                iconSize: 14
                                fill: taskManagerRoot.activeTab === 0 ? 1 : 0
                                color: taskManagerRoot.activeTab === 0 ? "#101318" : (appTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                            Text {
                                text: "Apps (" + taskManagerRoot.tasksAppsCount + ")"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: taskManagerRoot.activeTab === 0 ? Font.DemiBold : Font.Normal
                                color: taskManagerRoot.activeTab === 0 ? "#101318" : (appTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                        }

                        MouseArea {
                            id: appTabMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                taskManagerRoot.activeTab = 0;
                                taskManagerRoot.applyFilterAndSort();
                            }
                        }
                    }

                    // Tab 1: Background
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: bgTabRow.implicitWidth + 24
                        radius: 14
                        color: taskManagerRoot.activeTab === 1 ? taskManagerRoot.colAccent : (bgTabMouse.containsMouse ? taskManagerRoot.colCardHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            id: bgTabRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                text: "tune"
                                iconSize: 14
                                fill: taskManagerRoot.activeTab === 1 ? 1 : 0
                                color: taskManagerRoot.activeTab === 1 ? "#101318" : (bgTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                            Text {
                                text: "Background (" + taskManagerRoot.tasksBgCount + ")"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: taskManagerRoot.activeTab === 1 ? Font.DemiBold : Font.Normal
                                color: taskManagerRoot.activeTab === 1 ? "#101318" : (bgTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                        }

                        MouseArea {
                            id: bgTabMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                taskManagerRoot.activeTab = 1;
                                taskManagerRoot.applyFilterAndSort();
                            }
                        }
                    }

                    // Tab 2: All Processes
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: allTabRow.implicitWidth + 24
                        radius: 14
                        color: taskManagerRoot.activeTab === 2 ? taskManagerRoot.colAccent : (allTabMouse.containsMouse ? taskManagerRoot.colCardHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            id: allTabRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                text: "view_list"
                                iconSize: 14
                                fill: taskManagerRoot.activeTab === 2 ? 1 : 0
                                color: taskManagerRoot.activeTab === 2 ? "#101318" : (allTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                            Text {
                                text: "All (" + taskManagerRoot.tasksTotalCount + ")"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: taskManagerRoot.activeTab === 2 ? Font.DemiBold : Font.Normal
                                color: taskManagerRoot.activeTab === 2 ? "#101318" : (allTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                        }

                        MouseArea {
                            id: allTabMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                taskManagerRoot.activeTab = 2;
                                taskManagerRoot.applyFilterAndSort();
                            }
                        }
                    }
                }
            }

            // Search Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 19
                color: searchInput.activeFocus ? Qt.rgba(255, 255, 255, 0.09) : Qt.rgba(255, 255, 255, 0.05)
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8

                    MaterialSymbol {
                        text: "search"
                        iconSize: 16
                        color: searchInput.activeFocus ? taskManagerRoot.colAccent : taskManagerRoot.colMuted
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        color: taskManagerRoot.colText
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        placeholderText: "Search by process name, title, or PID..."
                        placeholderTextColor: taskManagerRoot.colMuted
                        background: Item {}
                        selectByMouse: true

                        onTextChanged: {
                            taskManagerRoot.searchQuery = text;
                            taskManagerRoot.applyFilterAndSort();
                        }

                        Keys.onDownPressed: (event) => {
                            if (processList.currentIndex < filteredProcessModel.count - 1) {
                                processList.currentIndex++;
                                processList.positionViewAtIndex(processList.currentIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        }
                        Keys.onUpPressed: (event) => {
                            if (processList.currentIndex > 0) {
                                processList.currentIndex--;
                                processList.positionViewAtIndex(processList.currentIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        }
                        Keys.onDeletePressed: (event) => {
                            if (processList.currentIndex >= 0 && processList.currentIndex < filteredProcessModel.count) {
                                var item = filteredProcessModel.get(processList.currentIndex);
                                if (item && item.pid) {
                                    taskManagerRoot.killProcess(item.pid, false);
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Clear search button
                    Rectangle {
                        visible: searchInput.text.length > 0
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: clearMouse.containsMouse ? taskManagerRoot.colCardHover : "transparent"
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 12
                            color: taskManagerRoot.colSubtext
                        }
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // Sort Toggle Chips (CPU / Memory)
            RowLayout {
                spacing: 6

                // CPU Sort
                Rectangle {
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: cpuSortRow.implicitWidth + 22
                    radius: 19
                    color: taskManagerRoot.sortField === "cpu" 
                        ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.22) 
                        : (cpuSortMouse.containsMouse ? taskManagerRoot.colCardHover : taskManagerRoot.colCard)
                    border.width: 0

                    RowLayout {
                        id: cpuSortRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "CPU"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: taskManagerRoot.sortField === "cpu" ? Font.DemiBold : Font.Normal
                            color: taskManagerRoot.sortField === "cpu" ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                        }

                        MaterialSymbol {
                            visible: taskManagerRoot.sortField === "cpu"
                            text: taskManagerRoot.sortAsc ? "arrow_upward" : "arrow_downward"
                            iconSize: 13
                            color: taskManagerRoot.colAccent
                        }
                    }

                    MouseArea {
                        id: cpuSortMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (taskManagerRoot.sortField === "cpu") {
                                taskManagerRoot.sortAsc = !taskManagerRoot.sortAsc;
                            } else {
                                taskManagerRoot.sortField = "cpu";
                                taskManagerRoot.sortAsc = false;
                            }
                            taskManagerRoot.applyFilterAndSort();
                        }
                    }
                }

                // RAM Sort
                Rectangle {
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: memSortRow.implicitWidth + 22
                    radius: 19
                    color: taskManagerRoot.sortField === "mem" 
                        ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.22) 
                        : (memSortMouse.containsMouse ? taskManagerRoot.colCardHover : taskManagerRoot.colCard)
                    border.width: 0

                    RowLayout {
                        id: memSortRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "RAM"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: taskManagerRoot.sortField === "mem" ? Font.DemiBold : Font.Normal
                            color: taskManagerRoot.sortField === "mem" ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                        }

                        MaterialSymbol {
                            visible: taskManagerRoot.sortField === "mem"
                            text: taskManagerRoot.sortAsc ? "arrow_upward" : "arrow_downward"
                            iconSize: 13
                            color: taskManagerRoot.colAccent
                        }
                    }

                    MouseArea {
                        id: memSortMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (taskManagerRoot.sortField === "mem") {
                                taskManagerRoot.sortAsc = !taskManagerRoot.sortAsc;
                            } else {
                                taskManagerRoot.sortField = "mem";
                                taskManagerRoot.sortAsc = false;
                            }
                            taskManagerRoot.applyFilterAndSort();
                        }
                    }
                }
            }
        }

        // ── 3. PROCESS LIST VIEW ─────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: Qt.rgba(255, 255, 255, 0.02)
            border.width: 0
            clip: true

            ListView {
                id: processList
                anchors.fill: parent
                anchors.margins: 6
                model: filteredProcessModel
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ScrollBar.vertical: ScrollBar {
                    id: vbar
                    active: true
                    width: 5
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 5
                        radius: 3
                        color: vbar.pressed ? Qt.rgba(255, 255, 255, 0.35) : Qt.rgba(255, 255, 255, 0.18)
                    }
                }

                delegate: Rectangle {
                    id: procRow
                    property int itemPid: model.pid
                    width: processList.width - (processList.ScrollBar.vertical.visible ? 10 : 0)
                    height: 54
                    radius: 14
                    color: (processList.currentIndex === index)
                        ? taskManagerRoot.colCardSelected
                        : (rowMouse.containsMouse ? taskManagerRoot.colCardHover : taskManagerRoot.colCard)
                    border.width: 0

                    scale: rowMouse.pressed ? 0.99 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        // App / Process Icon Disc
                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 18
                            color: model.category === "app" ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.18) : Qt.rgba(255, 255, 255, 0.08)
                            border.width: 0

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: model.icon || "memory"
                                iconSize: 18
                                color: model.category === "app" ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                                fill: model.category === "app" ? 1 : 0
                            }
                        }

                        // Process Identity & Window Title (Fills remaining horizontal space)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3
                            clip: true

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Text {
                                    text: model.display_name || model.name
                                    font.family: "Noto Sans"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: taskManagerRoot.colText
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                // Category Indicator Tag
                                Rectangle {
                                    visible: model.category === "app"
                                    Layout.preferredHeight: 18
                                    Layout.preferredWidth: appTagText.implicitWidth + 12
                                    radius: 9
                                    color: Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.16)
                                    border.width: 0
                                    Text {
                                        id: appTagText
                                        anchors.centerIn: parent
                                        text: "App"
                                        font.family: "Noto Sans"
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                        color: taskManagerRoot.colAccent
                                    }
                                }

                                // User indicator if not root/self
                                Text {
                                    visible: model.user !== "" && model.user !== "ricing"
                                    text: model.user
                                    font.family: "Noto Sans"
                                    font.pixelSize: 9
                                    color: taskManagerRoot.colMuted
                                }

                                Item { Layout.fillWidth: true }
                            }

                            RowLayout {
                                spacing: 6
                                Layout.fillWidth: true

                                Text {
                                    text: "PID " + model.pid
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    color: taskManagerRoot.colMuted
                                }

                                Text {
                                    visible: model.title !== "" && model.title !== model.name && model.title !== model.display_name
                                    Layout.fillWidth: true
                                    text: "• " + model.title
                                    font.family: "Noto Sans"
                                    font.pixelSize: 10
                                    color: taskManagerRoot.colSubtext
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Item { 
                                    visible: !(model.title !== "" && model.title !== model.name && model.title !== model.display_name)
                                    Layout.fillWidth: true 
                                }
                            }
                        }

                        // Resource Usage Badges & Actions (Pinned rigidly to rightmost side in consistent columns)
                        RowLayout {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            spacing: 8

                            // 1. CPU Pill (Fixed Column Width: 84px)
                            Rectangle {
                                Layout.preferredWidth: 84
                                Layout.preferredHeight: 28
                                radius: 14
                                color: model.cpu > 50 
                                    ? Qt.rgba(255, 84, 73, 0.22) 
                                    : (model.cpu > 15 ? Qt.rgba(245, 159, 0, 0.18) : Qt.rgba(255, 255, 255, 0.06))
                                border.width: 0

                                Text {
                                    anchors.centerIn: parent
                                    text: model.cpu.toFixed(1) + "% CPU"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    font.weight: model.cpu > 15 ? Font.Bold : Font.Normal
                                    color: model.cpu > 50 ? taskManagerRoot.colDanger : (model.cpu > 15 ? taskManagerRoot.colWarning : taskManagerRoot.colText)
                                }
                            }

                            // 2. RAM Pill (Fixed Column Width: 84px)
                            Rectangle {
                                Layout.preferredWidth: 84
                                Layout.preferredHeight: 28
                                radius: 14
                                color: model.mem_mb > 1024 
                                    ? Qt.rgba(255, 84, 73, 0.18) 
                                    : (model.mem_mb > 500 ? Qt.rgba(168, 199, 250, 0.16) : Qt.rgba(255, 255, 255, 0.06))
                                border.width: 0

                                Text {
                                    anchors.centerIn: parent
                                    text: model.mem_mb >= 1024 ? ((model.mem_mb / 1024).toFixed(2) + " GB") : (Math.round(model.mem_mb) + " MB")
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    color: model.mem_mb > 1024 ? taskManagerRoot.colAccent : taskManagerRoot.colText
                                }
                            }

                            // 3. Tactile "End Task" Action Button (Fixed Column Width: 68px)
                            Rectangle {
                                id: killBtn
                                Layout.preferredWidth: 68
                                Layout.preferredHeight: 28
                                radius: 14
                                color: killBtnMouse.containsMouse ? taskManagerRoot.colDanger : taskManagerRoot.colDangerBg
                                border.width: 0
                                scale: killBtnMouse.pressed ? 0.92 : 1.0
                                Behavior on scale { NumberAnimation { duration: 80 } }
                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    MaterialSymbol {
                                        text: "close"
                                        iconSize: 13
                                        color: killBtnMouse.containsMouse ? "#ffffff" : taskManagerRoot.colDanger
                                    }

                                    Text {
                                        text: "End"
                                        font.family: "Noto Sans"
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: killBtnMouse.containsMouse ? "#ffffff" : taskManagerRoot.colDanger
                                    }
                                }

                                MouseArea {
                                    id: killBtnMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        taskManagerRoot.killProcess(model.pid, false);
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                        z: -1
                        onClicked: {
                            processList.currentIndex = index;
                            taskManagerRoot.selectedPid = model.pid;
                        }
                    }
                }

                // Empty State Placeholder
                Item {
                    anchors.centerIn: parent
                    visible: filteredProcessModel.count === 0
                    width: 240
                    height: 120

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "search_off"
                            iconSize: 32
                            color: taskManagerRoot.colMuted
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: taskManagerRoot.searchQuery !== "" ? "No processes matching '" + taskManagerRoot.searchQuery + "'" : "No active processes found"
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                            color: taskManagerRoot.colSubtext
                        }
                    }
                }
            }
        }

        // ── 4. FOOTER STATUS BAR ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: 10

            Text {
                text: "Showing " + filteredProcessModel.count + " process" + (filteredProcessModel.count === 1 ? "" : "es")
                font.family: "Noto Sans"
                font.pixelSize: 11
                color: taskManagerRoot.colSubtext
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Esc to close • Select & Delete to kill • SUPER+Shift+T to toggle"
                font.family: "Noto Sans"
                font.pixelSize: 11
                color: taskManagerRoot.colMuted
            }
        }
    }
}
