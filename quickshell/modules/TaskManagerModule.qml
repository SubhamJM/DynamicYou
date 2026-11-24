import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

FocusScope {
    id: taskManagerRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    // ==========================================
    // PROPERTIES & THEME (Iris Frosted M3 Aesthetic)
    // ==========================================
    readonly property color colAccent: Theme.accent
    readonly property color colCpuMetric: "#82b8ff"
    readonly property color colMemory: "#f0ba78"
    readonly property color colGraphics: "#c6a5f5"
    readonly property color colNetwork: "#78d4ba"
    readonly property color colUpload: "#a9c7ff"
    readonly property color colCard: Theme.surfaceHigh
    readonly property color colCardHover: Theme.surfaceHighest
    readonly property color colCardSelected: Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.12)
    readonly property color colDanger: Theme.error
    readonly property color colDangerBg: Theme.alpha(colDanger, 0.14)
    readonly property color colWarning: "#fbbf24"
    readonly property color colSuccess: "#51cf66"
    readonly property color colText: Theme.text
    readonly property color colSubtext: Theme.subtext
    readonly property color colMuted: Theme.subtextDim

    // System Metrics & State
    property real cpuTotal: 0.0
    property int cpuCount: 1
    property real cpuMhz: 0
    property real cpuTemp: -1
    property string cpuModel: "Processor"
    property string load1: "0.00"
    property string load5: "0.00"
    property string load15: "0.00"
    property real memUsedGb: 0.0
    property real memTotalGb: 0.0
    property real memPercent: 0.0
    property real swapUsedGb: 0.0
    property real swapTotalGb: 0.0
    property real swapPercent: 0.0
    property real diskUsedGb: 0.0
    property real diskTotalGb: 0.0
    property real diskFreeGb: 0.0
    property real diskPercent: 0.0
    property string gpuName: "Graphics"
    property real gpuUsage: 0.0
    property real gpuTemp: -1
    property string netRxStr: "0 B/s"
    property string netTxStr: "0 B/s"
    property real netRxRate: 0.0
    property real netTxRate: 0.0
    property string distroName: "Linux"
    property string kernelVer: ""
    property string uptimeStr: ""
    property int tasksTotalCount: 0
    property int tasksAppsCount: 0
    property int tasksBgCount: 0

    // Sparkline Live History Arrays
    property var cpuHistory: []
    property var memHistory: []
    property var gpuHistory: []
    property var netHistory: []
    property var uploadHistory: []
    readonly property real networkScale: Math.pow(2, Math.ceil(Math.log2(
        Math.max(128 * 1024, ...netHistory, ...uploadHistory))))

    function pushHistory(arr, val, maxLen) {
        const sample = typeof val === "number" ? val : 0;
        var a = (arr && arr.length > 0) ? arr.slice() : [sample];
        a.push(sample);
        while (a.length > (maxLen || 24)) a.shift();
        return a;
    }

    function formatCpu(rounded, raw) {
        const value = rounded || 0;
        return value === 0 && raw > 0 ? "<0.1%" : value.toFixed(1) + "%";
    }

    property var rawApps: []
    property var rawBackground: []
    property var rawAll: []

    property int activeTab: 0 // 0: Apps, 1: Background, 2: All
    property string sortField: "cpu" // "cpu", "mem", "name"
    property bool sortAsc: false
    property string searchQuery: ""
    property string statusMessage: ""

    // Expose dynamic list metrics for reactive Notch container height
    readonly property real listViewContentHeight: processList.contentHeight
    readonly property int displayCount: displayProcessModel.count
    property alias searchInput: searchInput

    // Accordion expand/collapse state tracking
    property var expandedPids: ({})
    property var appsChildrenByPid: ({})

    function toggleExpand(pid) {
        var copy = Object.assign({}, expandedPids);
        if (copy[pid]) {
            delete copy[pid];
        } else {
            copy[pid] = true;
        }
        expandedPids = copy;
    }

    ListModel { id: displayProcessModel }

    function forceSearchFocus() {
        if (searchInput) searchInput.forceActiveFocus();
    }

    function refresh() {
        if (!taskPoller.running) {
            taskPoller.running = true;
        }
    }

    function killProcess(pid, force) {
        if (!pid || pid <= 0) return;
        var modeName = force ? "Force terminating (SIGKILL)" : "Terminating";
        statusMessage = modeName + " PID " + pid + "...";
        statusTimer.restart();

        // Optimistically remove from UI list if top-level app
        for (var i = 0; i < displayProcessModel.count; i++) {
            if (displayProcessModel.get(i).pid === pid) {
                displayProcessModel.remove(i);
                break;
            }
        }

        // Optimistically remove child from children map if child process
        var updatedMap = Object.assign({}, appsChildrenByPid);
        var foundChild = false;
        for (var rootPid in updatedMap) {
            var chList = updatedMap[rootPid] || [];
            var filtered = chList.filter(function(c) { return c.pid !== pid; });
            if (filtered.length !== chList.length) {
                updatedMap[rootPid] = filtered;
                foundChild = true;
                break;
            }
        }
        if (foundChild) appsChildrenByPid = updatedMap;

        taskKiller.command = [
            "python3",
            NotchConfig.scriptsDir + "/task_manager.py",
            "kill",
            pid.toString(),
            force ? "--force" : ""
        ];
        taskKiller.running = true;
    }

    function focusWindow(address, pid) {
        if (!address && !pid) return;
        var rawAddr = address ? address.trim() : pid.toString();
        var formattedAddr = rawAddr.startsWith("0x") ? rawAddr : ("0x" + rawAddr);

        root.collapseToIdle();

        if (typeof Hyprland !== "undefined") {
            try {
                Hyprland.dispatch(`focuswindow address:${formattedAddr}`);
            } catch(e) {}
        }

        focusDelayTimer.targetAddress = formattedAddr;
        focusDelayTimer.restart();
    }

    Timer {
        id: focusDelayTimer
        interval: 35
        repeat: false
        property string targetAddress: ""
        onTriggered: {
            windowFocuser.command = [
                "python3",
                NotchConfig.scriptsDir + "/task_manager.py",
                "focus",
                targetAddress
            ];
            windowFocuser.running = true;
        }
    }

    property int lastRenderedTab: -1
    property string lastSearchQuery: ""
    property string lastSortField: ""
    property bool lastSortAsc: false

    function restoreSelection(pid, fallback) {
        for (let index = 0; index < displayProcessModel.count; index++) {
            if (displayProcessModel.get(index).pid === pid) {
                processList.currentIndex = index;
                return;
            }
        }
        processList.currentIndex = Math.min(fallback, displayProcessModel.count - 1);
    }

    function applyFilterAndSort(userTriggered) {
        const selectedIndex = processList.currentIndex;
        const selected = selectedIndex >= 0 && selectedIndex < displayProcessModel.count
            ? displayProcessModel.get(selectedIndex).pid : -1;
        var q = searchQuery.toLowerCase().trim();
        var src = (activeTab === 0) ? rawApps : ((activeTab === 1) ? rawBackground : rawAll);
        var filteredList = [];

        for (var i = 0; i < src.length; i++) {
            var p = src[i];
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
            filteredList.push(p);
        }

        // Sort the filtered list
        filteredList.sort(function(a, b) {
            var diff = 0;
            if (sortField === "cpu") {
                diff = (a.cpu_raw ?? a.cpu) - (b.cpu_raw ?? b.cpu);
                if (Math.abs(diff) < 0.001) diff = a.mem_mb - b.mem_mb;
            } else if (sortField === "mem") {
                diff = a.mem_mb - b.mem_mb;
            } else if (sortField === "name") {
                diff = (a.display_name || a.name).localeCompare(b.display_name || b.name);
            }
            return (sortAsc ? diff : -diff) || a.pid - b.pid;
        });

        var tabChanged = (lastRenderedTab !== activeTab);
        var searchChanged = (lastSearchQuery !== q);
        var sortChanged = (lastSortField !== sortField || lastSortAsc !== sortAsc);
        var isInitial = (displayProcessModel.count === 0);

        lastRenderedTab = activeTab;
        lastSearchQuery = q;
        lastSortField = sortField;
        lastSortAsc = sortAsc;

        // If switching tabs or initially empty, populate directly
        if (isInitial || tabChanged) {
            displayProcessModel.clear();
            for (var j = 0; j < filteredList.length; j++) {
                displayProcessModel.append(filteredList[j]);
            }
            restoreSelection(tabChanged ? -1 : selected, 0);
            return;
        }

        // --- IN-PLACE BTOP-STYLE RECONCILIATION ---
        // 1. Build lookup dictionary of new data by PID
        var newMap = {};
        for (var k = 0; k < filteredList.length; k++) {
            newMap[filteredList[k].pid] = filteredList[k];
        }

        // 2. Remove dead processes that no longer exist
        for (var d = displayProcessModel.count - 1; d >= 0; d--) {
            var dPid = displayProcessModel.get(d).pid;
            if (!newMap[dPid]) {
                displayProcessModel.remove(d);
            }
        }

        // 3. Update existing processes in-place without destroying delegates
        var existingPids = {};
        for (var u = 0; u < displayProcessModel.count; u++) {
            var curItem = displayProcessModel.get(u);
            var updatedData = newMap[curItem.pid];
            if (updatedData) {
                existingPids[curItem.pid] = true;
                if (curItem.cpu !== updatedData.cpu) displayProcessModel.setProperty(u, "cpu", updatedData.cpu);
                if (curItem.cpu_raw !== updatedData.cpu_raw) displayProcessModel.setProperty(u, "cpu_raw", updatedData.cpu_raw);
                if (curItem.mem_mb !== updatedData.mem_mb) displayProcessModel.setProperty(u, "mem_mb", updatedData.mem_mb);
                if (curItem.mem_percent !== updatedData.mem_percent) displayProcessModel.setProperty(u, "mem_percent", updatedData.mem_percent);
                if (curItem.mem_bytes !== updatedData.mem_bytes) displayProcessModel.setProperty(u, "mem_bytes", updatedData.mem_bytes);
                if (curItem.title !== updatedData.title) displayProcessModel.setProperty(u, "title", updatedData.title);
                if (curItem.proc_count !== updatedData.proc_count) displayProcessModel.setProperty(u, "proc_count", updatedData.proc_count);
                if (curItem.workspace !== updatedData.workspace) displayProcessModel.setProperty(u, "workspace", updatedData.workspace);
            }
        }

        // 4. Append any newly appeared processes
        for (var a = 0; a < filteredList.length; a++) {
            var newProc = filteredList[a];
            if (!existingPids[newProc.pid]) {
                displayProcessModel.append(newProc);
            }
        }

        // Update the readings in place while the pointer or scrolling is in the list.
        const interacting = processHover.hovered || processList.moving || vbar.pressed;
        if (userTriggered || sortChanged || searchChanged || !interacting) {
            // Re-order displayProcessModel to match filteredList order using model.move()
            for (var target = 0; target < filteredList.length; target++) {
                var targetPid = filteredList[target].pid;
                var currentPos = -1;
                for (var scan = target; scan < displayProcessModel.count; scan++) {
                    if (displayProcessModel.get(scan).pid === targetPid) {
                        currentPos = scan;
                        break;
                    }
                }
                if (currentPos !== -1 && currentPos !== target) {
                    displayProcessModel.move(currentPos, target, 1);
                }
            }
        }
        restoreSelection(selected, searchChanged ? 0 : Math.max(0, selectedIndex));
    }

    Timer {
        id: statusTimer
        interval: 2500
        repeat: false
        onTriggered: taskManagerRoot.statusMessage = ""
    }

    // Auto-refresh timer when module is active
    Timer {
        id: autoRefreshTimer
        interval: 2000
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
            NotchConfig.scriptsDir + "/task_manager.py",
            "list"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text.trim();
                if (!raw) return;
                try {
                    var data = JSON.parse(raw);
                    if (data.cpu_total !== undefined) {
                        taskManagerRoot.cpuTotal = data.cpu_total;
                        taskManagerRoot.cpuCount = data.cpu_count || 1;
                        taskManagerRoot.cpuMhz = data.cpu_mhz || 0;
                        taskManagerRoot.cpuTemp = (data.cpu_temp !== undefined) ? data.cpu_temp : -1;
                        taskManagerRoot.cpuModel = data.cpu_model || "Processor";
                        taskManagerRoot.load1 = data.load_1 || "0.00";
                        taskManagerRoot.load5 = data.load_5 || "0.00";
                        taskManagerRoot.load15 = data.load_15 || "0.00";
                        taskManagerRoot.memUsedGb = data.mem_used_gb || 0;
                        taskManagerRoot.memTotalGb = data.mem_total_gb || 1;
                        taskManagerRoot.memPercent = data.mem_percent || 0;
                        taskManagerRoot.swapUsedGb = data.swap_used_gb || 0;
                        taskManagerRoot.swapTotalGb = data.swap_total_gb || 0;
                        taskManagerRoot.swapPercent = data.swap_percent || 0;
                        taskManagerRoot.diskUsedGb = data.disk_used_gb || 0;
                        taskManagerRoot.diskTotalGb = data.disk_total_gb || 1;
                        taskManagerRoot.diskFreeGb = data.disk_free_gb || 0;
                        taskManagerRoot.diskPercent = data.disk_percent || 0;
                        taskManagerRoot.gpuName = data.gpu_name || "Graphics";
                        taskManagerRoot.gpuUsage = data.gpu_usage || 0;
                        taskManagerRoot.gpuTemp = (data.gpu_temp !== undefined) ? data.gpu_temp : -1;
                        taskManagerRoot.netRxStr = data.net_rx_str || "0 B/s";
                        taskManagerRoot.netTxStr = data.net_tx_str || "0 B/s";
                        taskManagerRoot.netRxRate = data.net_rx_rate || 0;
                        taskManagerRoot.netTxRate = data.net_tx_rate || 0;
                        taskManagerRoot.distroName = data.distro || "Linux";
                        taskManagerRoot.kernelVer = data.kernel || "";
                        taskManagerRoot.uptimeStr = data.uptime_str || "";
                        taskManagerRoot.tasksTotalCount = data.tasks_total || 0;
                        taskManagerRoot.tasksAppsCount = data.tasks_apps || 0;
                        taskManagerRoot.tasksBgCount = data.tasks_bg || 0;

                        // Push live history points for sparkline graphs
                        taskManagerRoot.cpuHistory = taskManagerRoot.pushHistory(taskManagerRoot.cpuHistory, taskManagerRoot.cpuTotal, 24);
                        taskManagerRoot.memHistory = taskManagerRoot.pushHistory(taskManagerRoot.memHistory, taskManagerRoot.memPercent, 24);
                        taskManagerRoot.gpuHistory = taskManagerRoot.pushHistory(taskManagerRoot.gpuHistory, taskManagerRoot.gpuUsage, 24);
                        taskManagerRoot.netHistory = taskManagerRoot.pushHistory(taskManagerRoot.netHistory, taskManagerRoot.netRxRate, 24);
                        taskManagerRoot.uploadHistory = taskManagerRoot.pushHistory(taskManagerRoot.uploadHistory, taskManagerRoot.netTxRate, 24);

                        taskManagerRoot.rawApps = data.apps || [];
                        taskManagerRoot.rawBackground = data.background || [];
                        taskManagerRoot.rawAll = data.all || [];

                        // Populate children map for instant reactive accordion access
                        var chMap = {};
                        for (var k = 0; k < (data.apps || []).length; k++) {
                            var appObj = data.apps[k];
                            chMap[appObj.pid] = appObj.children || [];
                        }
                        taskManagerRoot.appsChildrenByPid = chMap;

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

    Process {
        id: windowFocuser
        running: false
    }

    // ==========================================
    // MAIN LAYOUT
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 9

        // ── 1. HEADER BAR ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 10

            // Tactile Back / Exit Button
            IrisIconButton {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                buttonSize: 34
                icon: "arrow_back"
                iconSize: 15
                backgroundColor: taskManagerRoot.colCard
                backgroundHoverColor: taskManagerRoot.colCardHover
                iconColor: taskManagerRoot.colSubtext
                hoverIconColor: taskManagerRoot.colText
                onClicked: root.collapseToIdle()
            }

            // Header Title & Dynamic Subtitle
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialSymbol {
                    text: "monitoring"
                    iconSize: 22
                    color: taskManagerRoot.colAccent
                    fill: 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Task Manager"
                        font.family: "Noto Sans"
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: taskManagerRoot.colText
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: taskManagerRoot.statusMessage !== "" 
                            ? taskManagerRoot.statusMessage 
                            : (taskManagerRoot.distroName + (taskManagerRoot.kernelVer !== "" ? " • " + taskManagerRoot.kernelVer : "") + " • " + taskManagerRoot.cpuModel + (taskManagerRoot.uptimeStr !== "" ? " • Up " + taskManagerRoot.uptimeStr : ""))
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        color: taskManagerRoot.statusMessage !== "" ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                    }
                }
            }

            // Close Button
            IrisIconButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                buttonSize: 32
                icon: "close"
                iconSize: 15
                backgroundColor: taskManagerRoot.colCard
                backgroundHoverColor: taskManagerRoot.colDangerBg
                iconColor: taskManagerRoot.colSubtext
                hoverIconColor: taskManagerRoot.colDanger
                onClicked: root.collapseToIdle()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            MetricCard {
                title: "CPU"
                glyph: "memory"
                tone: taskManagerRoot.colCpuMetric
                alert: taskManagerRoot.cpuTotal > 80
                value: Math.round(taskManagerRoot.cpuTotal) + "%"
                detail: taskManagerRoot.cpuTemp >= 0 ? taskManagerRoot.cpuTemp.toFixed(0) + " °C" : ""
                history: taskManagerRoot.cpuHistory
                caption: taskManagerRoot.cpuCount + " threads · Load " + taskManagerRoot.load1 + " / " + taskManagerRoot.load5
                secondary: taskManagerRoot.cpuMhz > 0 ? (taskManagerRoot.cpuMhz / 1000).toFixed(1) + " GHz" : ""
            }
            MetricCard {
                title: "Memory"
                glyph: "storage"
                tone: taskManagerRoot.colMemory
                chart: "allocation"
                current: taskManagerRoot.memPercent
                alert: taskManagerRoot.memPercent >= 85
                value: Math.round(taskManagerRoot.memPercent) + "%"
                detail: taskManagerRoot.memUsedGb.toFixed(1) + " / " + taskManagerRoot.memTotalGb.toFixed(1) + " GB"
                history: taskManagerRoot.memHistory
                caption: taskManagerRoot.swapTotalGb > 0
                    ? "Swap " + taskManagerRoot.swapUsedGb.toFixed(1) + " / " + taskManagerRoot.swapTotalGb.toFixed(1) + " GB"
                    : "No swap configured"
            }
            MetricCard {
                title: "Graphics"
                glyph: "developer_board"
                tone: taskManagerRoot.colGraphics
                chart: "bars"
                alert: taskManagerRoot.gpuUsage > 80
                value: Math.round(taskManagerRoot.gpuUsage) + "%"
                detail: taskManagerRoot.gpuTemp >= 0 ? taskManagerRoot.gpuTemp.toFixed(0) + " °C" : ""
                history: taskManagerRoot.gpuHistory
                caption: taskManagerRoot.gpuName
            }
            MetricCard {
                title: "Network & disk"
                glyph: "swap_vert"
                tone: taskManagerRoot.colNetwork
                chart: "traffic"
                detailTone: taskManagerRoot.colUpload
                value: "↓ " + taskManagerRoot.netRxStr
                detail: "↑ " + taskManagerRoot.netTxStr
                history: taskManagerRoot.netHistory
                caption: "File system  " + taskManagerRoot.diskUsedGb.toFixed(0) + " / " + taskManagerRoot.diskTotalGb.toFixed(0) + " GB"
                secondary: Math.round(taskManagerRoot.diskPercent) + "%"
                compactValue: true
            }
        }

        // ── 2. FILTER TABS, EXPANDING SEARCH & SORT SELECTOR ─────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 8

            // Segmented Category Tabs (Apps | Background | All)
            Rectangle {
                Layout.preferredHeight: 34
                Layout.preferredWidth: tabsRow.implicitWidth + 8
                radius: 17
                color: Qt.rgba(255, 255, 255, 0.05)

                RowLayout {
                    id: tabsRow
                    anchors.centerIn: parent
                    spacing: 3

                    // Tab 0: Apps
                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: appTabRow.implicitWidth + 18
                        radius: 13
                        color: taskManagerRoot.activeTab === 0 ? taskManagerRoot.colAccent : (appTabMouse.containsMouse ? taskManagerRoot.colCardHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            id: appTabRow
                            anchors.centerIn: parent
                            spacing: 5
                            MaterialSymbol {
                                text: "apps"
                                iconSize: 14
                                fill: taskManagerRoot.activeTab === 0 ? 1 : 0
                                color: taskManagerRoot.activeTab === 0 ? Theme.fgPrimary : (appTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                            Text {
                                text: "Apps (" + taskManagerRoot.tasksAppsCount + ")"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: taskManagerRoot.activeTab === 0 ? Font.Bold : Font.Normal
                                color: taskManagerRoot.activeTab === 0 ? Theme.fgPrimary : (appTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                        }

                        MouseArea {
                            id: appTabMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                taskManagerRoot.activeTab = 0;
                                taskManagerRoot.applyFilterAndSort(true);
                            }
                        }
                    }

                    // Tab 1: Background
                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: bgTabRow.implicitWidth + 18
                        radius: 13
                        color: taskManagerRoot.activeTab === 1 ? taskManagerRoot.colAccent : (bgTabMouse.containsMouse ? taskManagerRoot.colCardHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            id: bgTabRow
                            anchors.centerIn: parent
                            spacing: 5
                            MaterialSymbol {
                                text: "tune"
                                iconSize: 14
                                fill: taskManagerRoot.activeTab === 1 ? 1 : 0
                                color: taskManagerRoot.activeTab === 1 ? Theme.fgPrimary : (bgTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                            Text {
                                text: "Background (" + taskManagerRoot.tasksBgCount + ")"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: taskManagerRoot.activeTab === 1 ? Font.Bold : Font.Normal
                                color: taskManagerRoot.activeTab === 1 ? Theme.fgPrimary : (bgTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                        }

                        MouseArea {
                            id: bgTabMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                taskManagerRoot.activeTab = 1;
                                taskManagerRoot.applyFilterAndSort(true);
                            }
                        }
                    }

                    // Tab 2: All Processes
                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: allTabRow.implicitWidth + 18
                        radius: 13
                        color: taskManagerRoot.activeTab === 2 ? taskManagerRoot.colAccent : (allTabMouse.containsMouse ? taskManagerRoot.colCardHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            id: allTabRow
                            anchors.centerIn: parent
                            spacing: 5
                            MaterialSymbol {
                                text: "view_list"
                                iconSize: 14
                                fill: taskManagerRoot.activeTab === 2 ? 1 : 0
                                color: taskManagerRoot.activeTab === 2 ? Theme.fgPrimary : (allTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                            Text {
                                text: "All (" + taskManagerRoot.tasksTotalCount + ")"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: taskManagerRoot.activeTab === 2 ? Font.Bold : Font.Normal
                                color: taskManagerRoot.activeTab === 2 ? Theme.fgPrimary : (allTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                        }

                        MouseArea {
                            id: allTabMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                taskManagerRoot.activeTab = 2;
                                taskManagerRoot.applyFilterAndSort(true);
                            }
                        }
                    }
                }
            }

            // Expanding Search Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 17
                color: searchInput.activeFocus ? Theme.alpha(Theme.text, 0.09) : Theme.alpha(Theme.text, 0.05)
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8

                    MaterialSymbol {
                        text: "search"
                        iconSize: 15
                        color: searchInput.activeFocus ? taskManagerRoot.colAccent : taskManagerRoot.colMuted
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        color: taskManagerRoot.colText
                        font.family: Theme.fontFamilyBody
                        font.pixelSize: 12
                        placeholderText: "Search application, window title, or PID..."
                        placeholderTextColor: taskManagerRoot.colMuted
                        background: Item {}
                        selectByMouse: true

                        onTextChanged: {
                            taskManagerRoot.searchQuery = text;
                            taskManagerRoot.applyFilterAndSort(true);
                        }

                        Keys.onDownPressed: (event) => {
                            if (processList.currentIndex < displayProcessModel.count - 1) {
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
                            if (processList.currentIndex >= 0 && processList.currentIndex < displayProcessModel.count) {
                                var item = displayProcessModel.get(processList.currentIndex);
                                if (item && item.pid) {
                                    var force = (event.modifiers & Qt.ShiftModifier);
                                    taskManagerRoot.killProcess(item.pid, force);
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Clear search button
                    IrisIconButton {
                        visible: searchInput.text.length > 0
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        buttonSize: 20
                        buttonRadius: 10
                        flat: true
                        icon: "close"
                        iconSize: 12
                        iconColor: taskManagerRoot.colSubtext
                        hoverIconColor: taskManagerRoot.colText
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }

            // Sort Selector Chips (CPU | RAM | Name)
            RowLayout {
                spacing: 6

                // CPU Sort
                Rectangle {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: cpuSortRow.implicitWidth + 18
                    radius: 17
                    color: taskManagerRoot.sortField === "cpu" 
                        ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.22) 
                        : (cpuSortMouse.containsMouse ? taskManagerRoot.colCardHover : taskManagerRoot.colCard)

                    RowLayout {
                        id: cpuSortRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "CPU"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: taskManagerRoot.sortField === "cpu" ? Font.Bold : Font.Normal
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
                            taskManagerRoot.applyFilterAndSort(true);
                        }
                    }
                }

                // RAM Sort
                Rectangle {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: memSortRow.implicitWidth + 18
                    radius: 17
                    color: taskManagerRoot.sortField === "mem" 
                        ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.22) 
                        : (memSortMouse.containsMouse ? taskManagerRoot.colCardHover : taskManagerRoot.colCard)

                    RowLayout {
                        id: memSortRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "RAM"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: taskManagerRoot.sortField === "mem" ? Font.Bold : Font.Normal
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
                            taskManagerRoot.applyFilterAndSort(true);
                        }
                    }
                }

                // Name Sort
                Rectangle {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: nameSortRow.implicitWidth + 18
                    radius: 17
                    color: taskManagerRoot.sortField === "name" 
                        ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.22) 
                        : (nameSortMouse.containsMouse ? taskManagerRoot.colCardHover : taskManagerRoot.colCard)

                    RowLayout {
                        id: nameSortRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "Name"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: taskManagerRoot.sortField === "name" ? Font.Bold : Font.Normal
                            color: taskManagerRoot.sortField === "name" ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                        }

                        MaterialSymbol {
                            visible: taskManagerRoot.sortField === "name"
                            text: taskManagerRoot.sortAsc ? "arrow_upward" : "arrow_downward"
                            iconSize: 13
                            color: taskManagerRoot.colAccent
                        }
                    }

                    MouseArea {
                        id: nameSortMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (taskManagerRoot.sortField === "name") {
                                taskManagerRoot.sortAsc = !taskManagerRoot.sortAsc;
                            } else {
                                taskManagerRoot.sortField = "name";
                                taskManagerRoot.sortAsc = true;
                            }
                            taskManagerRoot.applyFilterAndSort(true);
                        }
                    }
                }
            }
        }





        // ── 3. COLUMN GUIDE SUBHEADER ─────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 22
            Layout.rightMargin: 24
            Layout.preferredHeight: 18
            spacing: 8

            Text {
                text: "Applications and processes"
                font.family: "Noto Sans"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: taskManagerRoot.colMuted
                Layout.fillWidth: true
            }

            Text {
                text: "CPU"
                font.family: "Noto Sans"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: taskManagerRoot.colMuted
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 86
            }

            Text {
                text: "Memory"
                font.family: "Noto Sans"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: taskManagerRoot.colMuted
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 86
            }

            Text {
                text: "Actions"
                font.family: "Noto Sans"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: taskManagerRoot.colMuted
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 124
            }
        }

        // ── 4. PROCESS LIST VIEW ─────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: Theme.alpha(Theme.surfaceHigh, 0.62)
            clip: true

            ListView {
                id: processList
                anchors.fill: parent
                anchors.margins: 4
                model: displayProcessModel
                spacing: 5
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                cacheBuffer: 140
                pixelAligned: true
                highlightFollowsCurrentItem: false

                HoverHandler { id: processHover }

                ScrollBar.vertical: ScrollBar {
                    id: vbar
                    active: true
                    width: 5
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 5
                        radius: 2.5
                        color: vbar.pressed 
                            ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.6) 
                            : (vbar.hovered ? Qt.rgba(255, 255, 255, 0.35) : Qt.rgba(255, 255, 255, 0.18))
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }

                delegate: Rectangle {
                    id: procRow
                    property int itemPid: model.pid
                    property bool hasWin: model.has_window || false
                    readonly property var childList: taskManagerRoot.appsChildrenByPid[model.pid] || []
                    readonly property bool hasChildren: childList.length > 0
                    readonly property bool isExpanded: !!taskManagerRoot.expandedPids[model.pid]

                    width: processList.width - 6
                    height: isExpanded ? (54 + (childList.length * 35) + 12) : 54
                    radius: 12
                    color: (processList.currentIndex === index)
                        ? taskManagerRoot.colCardSelected
                        : (rowMouse.containsMouse ? taskManagerRoot.colCardHover : taskManagerRoot.colCard)
                    clip: true

                    scale: rowMouse.pressed ? 0.995 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // ── Main Top-Level Process Card Row (54px) ──
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 8

                                // Dropdown Expand Chevron Button
                                IrisIconButton {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    buttonSize: 20
                                    buttonRadius: 10
                                    flat: true
                                    visible: procRow.hasChildren
                                    icon: "keyboard_arrow_right"
                                    iconSize: 15
                                    iconColor: procRow.isExpanded ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                                    rotation: procRow.isExpanded ? 90 : 0
                                    Behavior on rotation { NumberAnimation { duration: 140 } }
                                    onClicked: taskManagerRoot.toggleExpand(procRow.itemPid)
                                }

                                Item {
                                    visible: !procRow.hasChildren
                                    Layout.preferredWidth: 6
                                }

                                // Desktop Application Icon with Material fallback
                                Rectangle {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                    radius: 10
                                    color: Qt.rgba(255, 255, 255, 0.06)
                                    clip: true

                                    IrisIcon {
                                        anchors.centerIn: parent
                                        icon: (model.icon_name && model.icon_name !== "") ? model.icon_name : (model.icon || "memory")
                                        isApp: Boolean(model.icon_name)
                                        iconSize: 20
                                        fill: model.category === "app" ? 1 : 0
                                        color: model.category === "app" ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                                        fallbackSymbol: model.icon || "memory"
                                        cornerRadius: 6
                                    }
                                }

                                // Process Identity & Title
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3
                                    clip: true

                                    RowLayout {
                                        spacing: 6
                                        Layout.fillWidth: true

                                        Text {
                                            text: model.display_name || model.name
                                            font.family: "Noto Sans"
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: taskManagerRoot.colText
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        // Active Workspace Tag
                                        Rectangle {
                                            visible: model.workspace !== "" && model.workspace !== undefined
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: wsTagText.implicitWidth + 10
                                            radius: 9
                                            color: Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.18)
                                            Text {
                                                id: wsTagText
                                                anchors.centerIn: parent
                                                text: "WS " + model.workspace
                                                font.family: "Noto Sans"
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                                color: taskManagerRoot.colAccent
                                            }
                                        }

                                        // Multi-process Dropdown Pill Badge
                                        Rectangle {
                                            visible: procRow.hasChildren
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: countTagRow.implicitWidth + 12
                                            radius: 9
                                            color: countTagMouse.containsMouse 
                                                ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.25)
                                                : (procRow.isExpanded 
                                                    ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.18) 
                                                    : Qt.rgba(255, 255, 255, 0.08))

                                            RowLayout {
                                                id: countTagRow
                                                anchors.centerIn: parent
                                                spacing: 3
                                                Text {
                                                    text: (procRow.childList.length + 1) + " procs"
                                                    font.family: "Noto Sans"
                                                    font.pixelSize: 9
                                                    font.weight: Font.DemiBold
                                                    color: procRow.isExpanded ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                                                }
                                                MaterialSymbol {
                                                    text: "expand_more"
                                                    iconSize: 12
                                                    color: procRow.isExpanded ? taskManagerRoot.colAccent : taskManagerRoot.colMuted
                                                    rotation: procRow.isExpanded ? 180 : 0
                                                    Behavior on rotation { NumberAnimation { duration: 140 } }
                                                }
                                            }

                                            MouseArea {
                                                id: countTagMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: taskManagerRoot.toggleExpand(procRow.itemPid)
                                            }
                                        }

                                        // User indicator if not current user
                                        Text {
                                            visible: model.user !== "" && model.user !== (Quickshell.env("USER") || "") && model.user !== "root"
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

                                // ── Right Data Columns: CPU, RAM, Actions ──
                                RowLayout {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    spacing: 8

                                    // 1. CPU Column (86px)
                                    ColumnLayout {
                                        Layout.preferredWidth: 86
                                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                        spacing: 3

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: taskManagerRoot.formatCpu(model.cpu, model.cpu_raw)
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: model.cpu > 50 ? taskManagerRoot.colDanger : (model.cpu > 20 ? taskManagerRoot.colWarning : taskManagerRoot.colText)
                                        }

                                        // Dynamic CPU Mini Progress Bar
                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 58
                                            Layout.preferredHeight: 3
                                            radius: 1.5
                                            color: Qt.rgba(255, 255, 255, 0.08)

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: model.cpu_raw > 0 ? Math.max(2, parent.width * Math.min(1, model.cpu / 100)) : 0
                                                radius: 1.5
                                                color: model.cpu > 50 ? taskManagerRoot.colDanger : (model.cpu > 20 ? taskManagerRoot.colWarning : taskManagerRoot.colAccent)
                                            }
                                        }
                                    }

                                    // 2. RAM Column (86px)
                                    ColumnLayout {
                                        Layout.preferredWidth: 86
                                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                        spacing: 2

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: model.mem_mb >= 1024 ? ((model.mem_mb / 1024).toFixed(1) + " GB") : (Math.round(model.mem_mb) + " MB")
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: model.mem_mb > 1500 ? taskManagerRoot.colAccent : taskManagerRoot.colText
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: model.mem_percent.toFixed(model.mem_percent < 1 && model.mem_percent > 0 ? 1 : 0) + "% RAM"
                                            font.family: "Noto Sans"
                                            font.pixelSize: 9
                                            color: taskManagerRoot.colMuted
                                        }
                                    }

                                    // 3. Action Buttons Row (136px: Focus + End)
                                    RowLayout {
                                        Layout.preferredWidth: 136
                                        spacing: 6

                                        ProcessAction {
                                            visible: procRow.hasWin
                                            text: "Focus"
                                            glyph: "visibility"
                                            hint: "Focus window"
                                            onTriggered: taskManagerRoot.focusWindow(model.address, model.pid)
                                        }

                                        Item {
                                            visible: !procRow.hasWin
                                            Layout.preferredWidth: 64
                                            Layout.preferredHeight: 30
                                        }

                                        ProcessAction {
                                            text: "End"
                                            glyph: "close"
                                            hint: "End process. Right-click to force quit."
                                            destructive: true
                                            onTriggered: force => taskManagerRoot.killProcess(model.pid, force)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.ArrowCursor
                                propagateComposedEvents: true
                                z: -1
                                onClicked: (mouse) => {
                                    processList.currentIndex = index;
                                    mouse.accepted = false;
                                }
                            }
                        }

                        // ── Subprocess Accordion Dropdown List ──
                        ColumnLayout {
                            visible: procRow.isExpanded
                            Layout.fillWidth: true
                            spacing: 3
                            Layout.topMargin: 4
                            Layout.bottomMargin: 6

                            // Subtle Divider
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                Layout.leftMargin: 14
                                Layout.rightMargin: 14
                                color: Qt.rgba(255, 255, 255, 0.06)
                            }

                            Repeater {
                                model: (procRow.isExpanded && procRow.childList) ? procRow.childList : 0
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 12
                                    radius: 8
                                    color: childRowMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : Qt.rgba(255, 255, 255, 0.015)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 6
                                        spacing: 8

                                        MaterialSymbol {
                                            text: modelData.icon || "subdirectory_arrow_right"
                                            iconSize: 14
                                            color: taskManagerRoot.colAccent
                                        }

                                        Text {
                                            text: modelData.title
                                            font.family: "Noto Sans"
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: taskManagerRoot.colText
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 240
                                        }

                                        Text {
                                            text: "PID " + modelData.pid
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 9
                                            color: taskManagerRoot.colMuted
                                        }

                                        Item { Layout.fillWidth: true }

                                        // Subprocess CPU (86px)
                                        Text {
                                            Layout.preferredWidth: 86
                                            horizontalAlignment: Text.AlignHCenter
                                            text: taskManagerRoot.formatCpu(modelData.cpu, modelData.cpu_raw)
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            color: (modelData.cpu > 20) ? taskManagerRoot.colWarning : taskManagerRoot.colSubtext
                                        }

                                        // Subprocess RAM (86px)
                                        Text {
                                            Layout.preferredWidth: 86
                                            horizontalAlignment: Text.AlignHCenter
                                            text: modelData.mem_mb >= 1024 ? ((modelData.mem_mb / 1024).toFixed(1) + " GB") : (Math.round(modelData.mem_mb || 0) + " MB")
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            color: taskManagerRoot.colSubtext
                                        }

                                        // Subprocess Action Column (136px)
                                        RowLayout {
                                            Layout.preferredWidth: 136
                                            spacing: 6

                                            Item { Layout.fillWidth: true }

                                            ProcessAction {
                                                text: "End"
                                                glyph: "close"
                                                hint: "End subprocess. Right-click to force quit."
                                                destructive: true
                                                onTriggered: force => taskManagerRoot.killProcess(modelData.pid, force)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: childRowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        propagateComposedEvents: true
                                        z: -1
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty State Placeholder
                Item {
                    anchors.centerIn: parent
                    visible: displayProcessModel.count === 0
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
                            text: taskManagerRoot.searchQuery !== "" 
                                ? "No processes matching '" + taskManagerRoot.searchQuery + "'" 
                                : "No active processes found"
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                            color: taskManagerRoot.colSubtext
                        }
                    }
                }
            }
        }

        // ── 5. FOOTER STATUS BAR ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: 10

            Text {
                text: "Showing " + displayProcessModel.count + " item" + (displayProcessModel.count === 1 ? "" : "s")
                font.family: "Noto Sans"
                font.pixelSize: 10
                color: taskManagerRoot.colSubtext
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Esc to close • Del to End • Shift+Del Force Kill • Focus to jump to app"
                font.family: "Noto Sans"
                font.pixelSize: 10
                color: taskManagerRoot.colMuted
            }
        }
    }
    component ProcessAction: Rectangle {
        id: action
        required property string text
        required property string glyph
        required property string hint
        property bool destructive: false
        signal triggered(bool force)

        readonly property color tone: destructive ? taskManagerRoot.colDanger : taskManagerRoot.colAccent
        Layout.preferredWidth: 64
        Layout.preferredHeight: 30
        radius: 15
        color: destructive
            ? (pointer.pressed ? Theme.alpha(Theme.error, 0.32) : pointer.containsMouse ? Theme.alpha(Theme.error, 0.20) : Theme.alpha(Theme.text, 0.07))
            : (pointer.pressed ? Theme.alpha(Theme.accent, 0.35) : pointer.containsMouse ? Theme.alpha(Theme.accent, 0.24) : Theme.alpha(Theme.accent, 0.14))

        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.description: hint
        Accessible.onPressAction: triggered(false)
        ToolTip.visible: pointer.containsMouse
        ToolTip.delay: 600
        ToolTip.text: hint

        Behavior on color { ColorAnimation { duration: 115 } }

        Row {
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: action.glyph
                iconSize: 14
                color: action.destructive
                    ? (pointer.containsMouse ? Theme.error : Theme.alpha(Theme.text, 0.70))
                    : Theme.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: action.text
                color: action.destructive
                    ? (pointer.containsMouse ? Theme.error : Theme.alpha(Theme.text, 0.85))
                    : Theme.accent
                font.family: Theme.fontFamilyBody
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            acceptedButtons: action.destructive ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
            onClicked: event => action.triggered(action.destructive
                && (event.button === Qt.RightButton || (event.modifiers & Qt.ShiftModifier) !== 0))
        }
    }

    component MetricCard: Rectangle {
        id: card
        required property string title
        required property string glyph
        required property color tone
        required property string value
        required property var history
        required property string caption
        property string detail: ""
        property string secondary: ""
        property bool compactValue: false
        property bool alert: false
        property string chart: "line"
        property real current: 0
        property color detailTone: tone

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: 0
        Layout.preferredHeight: 142
        radius: 14
        clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.tint(taskManagerRoot.colCard, Theme.alpha(card.tone, 0.24)) }
            GradientStop { position: 1; color: Qt.tint(taskManagerRoot.colCard, Theme.alpha(card.tone, 0.05)) }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 7
                    color: Theme.alpha(card.tone, 0.16)

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: card.glyph
                        iconSize: 15
                        color: card.tone
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: card.title
                    color: taskManagerRoot.colSubtext
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    Layout.fillWidth: true
                    text: card.value
                    color: card.alert ? taskManagerRoot.colDanger : taskManagerRoot.colText
                    font.family: Theme.fontFamilyNerd
                    font.pixelSize: card.compactValue ? 17 : 26
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    visible: card.detail !== ""
                    text: card.detail
                    color: card.detailTone
                    font.family: Theme.fontFamilyNerd
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 24
                clip: true
                sourceComponent: card.chart === "allocation" ? allocationChart
                    : card.chart === "bars" ? graphicsChart : card.chart === "traffic" ? trafficChart : cpuChart
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    Layout.fillWidth: true
                    text: card.caption
                    color: taskManagerRoot.colSubtext
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    visible: card.secondary !== ""
                    text: card.secondary
                    color: card.tone
                    font.family: Theme.fontFamilyNerd
                    font.pixelSize: 9
                }
            }
        }

        Component {
            id: cpuChart
            Item {
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: parent.width
                        height: 1
                        y: (index + 1) * parent.height / 4
                        color: Theme.alpha(card.tone, 0.17)
                    }
                }

                Sparkline {
                    anchors.fill: parent
                    values: card.history
                    strokeColor: card.tone
                    showPeakDot: false
                    fillOpacity: 0.48
                }
            }
        }

        Component {
            id: allocationChart
            Item {
                Row {
                    id: allocation
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 3
                    height: 10
                    spacing: 3

                    Repeater {
                        model: 12
                        delegate: Rectangle {
                            id: segment
                            required property int index
                            width: Math.max(0, (allocation.width - 11 * allocation.spacing) / 12)
                            height: allocation.height
                            radius: 2
                            color: Theme.alpha(card.tone, 0.18)
                            Rectangle {
                                width: segment.width * Math.max(0, Math.min(1, card.current * 0.12 - segment.index))
                                height: parent.height
                                radius: 2
                                color: card.tone
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }

                Sparkline {
                    anchors.top: allocation.bottom
                    anchors.topMargin: 5
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    values: card.history
                    strokeColor: Theme.alpha(card.tone, 0.60)
                    strokeWidth: 1
                    fillArea: false
                    showPeakDot: false
                }
            }
        }

        Component {
            id: graphicsChart
            Row {
                id: samples
                spacing: 3

                Repeater {
                    model: 18
                    delegate: Item {
                        id: sample
                        required property int index
                        readonly property int historyIndex: card.history.length - 18 + index
                        readonly property real reading: historyIndex < 0 ? 0 : card.history[historyIndex]
                        width: Math.max(0, (samples.width - 17 * samples.spacing) / 18)
                        height: samples.height

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.height
                            radius: 2
                            color: Theme.alpha(card.tone, 0.08)
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(2, parent.height * Math.min(100, sample.reading) / 100)
                            radius: 2
                            color: sample.reading > 0 ? card.tone : Theme.alpha(card.tone, 0.28)
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }

        Component {
            id: trafficChart
            Item {
                Sparkline {
                    anchors.fill: parent
                    values: card.history
                    maximum: taskManagerRoot.networkScale
                    strokeColor: card.tone
                    showPeakDot: false
                    fillOpacity: 0.38
                }
                Sparkline {
                    anchors.fill: parent
                    values: taskManagerRoot.uploadHistory
                    maximum: taskManagerRoot.networkScale
                    strokeColor: card.detailTone
                    strokeWidth: 1.4
                    showPeakDot: false
                    fillArea: false
                }
            }
        }
    }

}
