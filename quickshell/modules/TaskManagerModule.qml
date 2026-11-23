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
    readonly property color colAccent: Theme.accent ?? "#a8c7fa"
    readonly property color colCard: Qt.rgba(255, 255, 255, 0.045)
    readonly property color colCardHover: Qt.rgba(255, 255, 255, 0.085)
    readonly property color colCardSelected: Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.12)
    readonly property color colDanger: "#ff5449"
    readonly property color colDangerHover: "#ff6e65"
    readonly property color colDangerBg: Qt.rgba(255, 84, 73, 0.16)
    readonly property color colWarning: "#fbbf24"
    readonly property color colSuccess: "#51cf66"
    readonly property color colText: "#ffffff"
    readonly property color colSubtext: Qt.rgba(255, 255, 255, 0.65)
    readonly property color colMuted: Qt.rgba(255, 255, 255, 0.40)

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
    property var cpuHistory: [0, 0]
    property var memHistory: [0, 0]
    property var gpuHistory: [0, 0]
    property var netHistory: [0, 0]

    function pushHistory(arr, val, maxLen) {
        var a = (arr && arr.length > 0) ? arr.slice() : [0, 0];
        a.push(typeof val === "number" ? val : 0);
        while (a.length > (maxLen || 24)) a.shift();
        return a;
    }

    property var rawApps: []
    property var rawBackground: []
    property var rawAll: []

    property int activeTab: 0 // 0: Apps, 1: Background, 2: All
    property string sortField: "cpu" // "cpu", "mem", "name"
    property bool sortAsc: false
    property string searchQuery: ""
    property int selectedPid: -1
    property bool isRefreshing: false
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
            isRefreshing = true;
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

    function applyFilterAndSort(userTriggered) {
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
                diff = a.cpu - b.cpu;
            } else if (sortField === "mem") {
                diff = a.mem_mb - b.mem_mb;
            } else if (sortField === "name") {
                diff = (a.display_name || a.name).localeCompare(b.display_name || b.name);
            }
            return sortAsc ? diff : -diff;
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

        // 5. Re-order items ONLY if user explicitly changed sort/search OR if the user is NOT actively scrolling!
        var isUserScrolling = processList.moving || processList.flicking || processList.dragging;
        if ((userTriggered || sortChanged || searchChanged || !isUserScrolling)) {
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
                taskManagerRoot.isRefreshing = false;
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
                        taskManagerRoot.netHistory = taskManagerRoot.pushHistory(taskManagerRoot.netHistory, Math.min(100, (taskManagerRoot.netRxRate / (1024 * 1024)) * 10), 24);

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
        anchors.margins: 16
        spacing: 11

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
                spacing: 8
                MaterialSymbol {
                    text: "monitoring"
                    iconSize: 22
                    color: taskManagerRoot.colAccent
                    fill: 1
                }

                ColumnLayout {
                    spacing: 1
                    Text {
                        text: "System Monitor"
                        font.family: "Noto Sans"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: taskManagerRoot.colText
                    }
                    Text {
                        text: taskManagerRoot.statusMessage !== "" 
                            ? taskManagerRoot.statusMessage 
                            : (taskManagerRoot.distroName + (taskManagerRoot.kernelVer !== "" ? " • " + taskManagerRoot.kernelVer : "") + " • " + taskManagerRoot.cpuModel + (taskManagerRoot.uptimeStr !== "" ? " • Up " + taskManagerRoot.uptimeStr : ""))
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        color: taskManagerRoot.statusMessage !== "" ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Live Network Throughput Chip
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: netChipRow.implicitWidth + 20
                radius: 12
                color: taskManagerRoot.colCard
                border.width: 1
                border.color: Qt.rgba(224, 175, 104, 0.25)

                RowLayout {
                    id: netChipRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "swap_vert"
                        iconSize: 15
                        fill: 1
                        color: "#e0af68"
                    }

                    Text {
                        text: "↓ " + taskManagerRoot.netRxStr + "   ↑ " + taskManagerRoot.netTxStr
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                    }
                }
            }

            // Quick Refresh Button
            IrisIconButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                buttonSize: 32
                icon: "refresh"
                iconSize: 15
                spinning: taskManagerRoot.isRefreshing
                backgroundColor: taskManagerRoot.colCard
                backgroundHoverColor: taskManagerRoot.colCardHover
                iconColor: taskManagerRoot.isRefreshing ? taskManagerRoot.colAccent : taskManagerRoot.colSubtext
                onClicked: taskManagerRoot.refresh()
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

        // ── 2. LIVE HARDWARE HERO CARDS (The Goat / Lucid Style) ──
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            spacing: 8

            // ── Card 1: CPU HERO ──────────────────────────────────
            Rectangle {
                id: cpuCard
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                radius: 14
                color: cpuCardMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.075) : taskManagerRoot.colCard
                border.width: 1
                border.color: cpuCardMouse.containsMouse ? Qt.rgba(122, 162, 247, 0.55) : Qt.rgba(122, 162, 247, 0.25)
                clip: true

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: cpuCardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2

                    // Card Header: Icon + Name + Temp badge
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            text: "memory"
                            iconSize: 15
                            fill: 1
                            color: "#7aa2f7"
                        }
                        Text {
                            text: "CPU"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: taskManagerRoot.cpuTemp > 0
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: tempText.implicitWidth + 12
                            radius: 9
                            color: taskManagerRoot.cpuTemp >= 80 ? Qt.rgba(247, 118, 142, 0.25) : (taskManagerRoot.cpuTemp >= 65 ? Qt.rgba(224, 175, 104, 0.22) : Qt.rgba(115, 218, 202, 0.18))
                            border.width: 1
                            border.color: taskManagerRoot.cpuTemp >= 80 ? "#f7768e" : (taskManagerRoot.cpuTemp >= 65 ? "#e0af68" : "#73daca")

                            Text {
                                id: tempText
                                anchors.centerIn: parent
                                text: taskManagerRoot.cpuTemp + "°C"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                color: parent.border.color
                            }
                        }
                    }

                    // Card Body: Big Value + Sparkline
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: Math.round(taskManagerRoot.cpuTotal) + "%"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: taskManagerRoot.cpuTotal > 80 ? taskManagerRoot.colDanger : (taskManagerRoot.cpuTotal > 50 ? taskManagerRoot.colWarning : "#7aa2f7")
                            }
                            Text {
                                text: taskManagerRoot.cpuMhz > 0 ? (taskManagerRoot.cpuMhz / 1000).toFixed(1) + " GHz" : (taskManagerRoot.cpuCount + " cores")
                                font.family: "Noto Sans"
                                font.pixelSize: 9
                                color: taskManagerRoot.colSubtext
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Sparkline {
                            Layout.preferredWidth: 78
                            Layout.preferredHeight: 32
                            strokeColor: "#7aa2f7"
                            values: taskManagerRoot.cpuHistory
                            maximum: 100
                            fillArea: true
                            fillOpacity: 0.22
                        }
                    }

                    // Card Footer: Cores & Load averages
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: taskManagerRoot.cpuCount + " Cores • Load " + taskManagerRoot.load1 + ", " + taskManagerRoot.load5
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        color: taskManagerRoot.colMuted
                    }
                }
            }

            // ── Card 2: MEMORY HERO ───────────────────────────────
            Rectangle {
                id: memCard
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                radius: 14
                color: memCardMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.075) : taskManagerRoot.colCard
                border.width: 1
                border.color: memCardMouse.containsMouse ? Qt.rgba(187, 154, 247, 0.55) : Qt.rgba(187, 154, 247, 0.25)
                clip: true

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: memCardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            text: "storage"
                            iconSize: 15
                            fill: 1
                            color: "#bb9af7"
                        }
                        Text {
                            text: "RAM"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: taskManagerRoot.memUsedGb.toFixed(1) + " / " + taskManagerRoot.memTotalGb.toFixed(1) + " GB"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 9
                            color: taskManagerRoot.colSubtext
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: Math.round(taskManagerRoot.memPercent) + "%"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: taskManagerRoot.memPercent > 85 ? taskManagerRoot.colDanger : (taskManagerRoot.memPercent > 70 ? taskManagerRoot.colWarning : "#bb9af7")
                            }
                            Text {
                                text: (taskManagerRoot.memTotalGb - taskManagerRoot.memUsedGb).toFixed(1) + " GB avail"
                                font.family: "Noto Sans"
                                font.pixelSize: 9
                                color: taskManagerRoot.colSubtext
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Sparkline {
                            Layout.preferredWidth: 78
                            Layout.preferredHeight: 32
                            strokeColor: "#bb9af7"
                            values: taskManagerRoot.memHistory
                            maximum: 100
                            fillArea: true
                            fillOpacity: 0.22
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: taskManagerRoot.swapTotalGb > 0
                            ? ("Swap: " + taskManagerRoot.swapUsedGb.toFixed(1) + " / " + taskManagerRoot.swapTotalGb.toFixed(1) + " GB (" + Math.round(taskManagerRoot.swapPercent) + "%)")
                            : "Swap inactive"
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        color: taskManagerRoot.colMuted
                    }
                }
            }

            // ── Card 3: GPU HERO ──────────────────────────────────
            Rectangle {
                id: gpuCard
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                radius: 14
                color: gpuCardMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.075) : taskManagerRoot.colCard
                border.width: 1
                border.color: gpuCardMouse.containsMouse ? Qt.rgba(115, 218, 202, 0.55) : Qt.rgba(115, 218, 202, 0.25)
                clip: true

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: gpuCardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            text: "developer_board"
                            iconSize: 15
                            fill: 1
                            color: "#73daca"
                        }
                        Text {
                            text: "GPU"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: taskManagerRoot.gpuName
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            color: taskManagerRoot.colSubtext
                            elide: Text.ElideRight
                            Layout.maximumWidth: 100
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: Math.round(taskManagerRoot.gpuUsage) + "%"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: taskManagerRoot.gpuUsage > 80 ? taskManagerRoot.colDanger : "#73daca"
                            }
                            Text {
                                text: taskManagerRoot.gpuTemp > 0 ? (taskManagerRoot.gpuTemp + "°C") : "Rendering"
                                font.family: "Noto Sans"
                                font.pixelSize: 9
                                color: taskManagerRoot.colSubtext
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Sparkline {
                            Layout.preferredWidth: 78
                            Layout.preferredHeight: 32
                            strokeColor: "#73daca"
                            values: taskManagerRoot.gpuHistory
                            maximum: 100
                            fillArea: true
                            fillOpacity: 0.22
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: taskManagerRoot.gpuName.indexOf("RTX") !== -1 || taskManagerRoot.gpuName.indexOf("Radeon") !== -1 ? "Dedicated Graphics" : "Hardware Accelerated"
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        color: taskManagerRoot.colMuted
                    }
                }
            }

            // ── Card 4: DISK & NETWORK HERO ───────────────────────
            Rectangle {
                id: ioCard
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                radius: 14
                color: ioCardMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.075) : taskManagerRoot.colCard
                border.width: 1
                border.color: ioCardMouse.containsMouse ? Qt.rgba(224, 175, 104, 0.55) : Qt.rgba(224, 175, 104, 0.25)
                clip: true

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: ioCardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            text: "speed"
                            iconSize: 15
                            fill: 1
                            color: "#e0af68"
                        }
                        Text {
                            text: "I/O & DISK"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: taskManagerRoot.diskFreeGb.toFixed(0) + " GB free"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 9
                            color: taskManagerRoot.colSubtext
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "↓ " + taskManagerRoot.netRxStr
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: "#e0af68"
                            }
                            Text {
                                text: "↑ " + taskManagerRoot.netTxStr
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: taskManagerRoot.colSubtext
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Sparkline {
                            Layout.preferredWidth: 78
                            Layout.preferredHeight: 32
                            strokeColor: "#e0af68"
                            values: taskManagerRoot.netHistory
                            maximum: 100
                            fillArea: true
                            fillOpacity: 0.22
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: "Root: " + Math.round(taskManagerRoot.diskPercent) + "% (" + taskManagerRoot.diskUsedGb.toFixed(0) + " / " + taskManagerRoot.diskTotalGb.toFixed(0) + " GB)"
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        color: taskManagerRoot.colMuted
                    }
                }
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
                border.width: 0

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
                                color: taskManagerRoot.activeTab === 0 ? "#101318" : (appTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                            Text {
                                text: "Apps (" + taskManagerRoot.tasksAppsCount + ")"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: taskManagerRoot.activeTab === 0 ? Font.Bold : Font.Normal
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
                                color: taskManagerRoot.activeTab === 1 ? "#101318" : (bgTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                            Text {
                                text: "Background (" + taskManagerRoot.tasksBgCount + ")"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: taskManagerRoot.activeTab === 1 ? Font.Bold : Font.Normal
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
                                color: taskManagerRoot.activeTab === 2 ? "#101318" : (allTabMouse.containsMouse ? taskManagerRoot.colText : taskManagerRoot.colSubtext)
                            }
                            Text {
                                text: "All (" + taskManagerRoot.tasksTotalCount + ")"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: taskManagerRoot.activeTab === 2 ? Font.Bold : Font.Normal
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
                color: searchInput.activeFocus ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.045)
                border.width: searchInput.activeFocus ? 1 : 0
                border.color: Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.45)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

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
                        font.family: "Noto Sans"
                        font.pixelSize: 11
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
                    border.width: 0

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
                    border.width: 0

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
                    border.width: 0

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
                text: "APPLICATION / PROCESS"
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
                text: "MEMORY"
                font.family: "Noto Sans"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: taskManagerRoot.colMuted
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 86
            }

            Text {
                text: "ACTIONS"
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
            color: Qt.rgba(255, 255, 255, 0.02)
            border.width: 0
            clip: true

            ListView {
                id: processList
                anchors.fill: parent
                anchors.margins: 4
                model: displayProcessModel
                spacing: 5
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                cacheBuffer: 600
                pixelAligned: true
                highlightFollowsCurrentItem: false

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
                    border.width: (processList.currentIndex === index || rowMouse.containsMouse) ? 1 : 0
                    border.color: (processList.currentIndex === index) 
                        ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.35) 
                        : Qt.rgba(255, 255, 255, 0.08)
                    clip: true

                    scale: rowMouse.pressed ? 0.995 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }
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
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
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
                                    border.width: 0
                                    clip: true

                                    IrisIcon {
                                        anchors.centerIn: parent
                                        icon: (model.icon_name && model.icon_name !== "") ? model.icon_name : (model.icon || "memory")
                                        isApp: true
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
                                            border.width: 0
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
                                            border.width: 0

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
                                            text: model.cpu.toFixed(1) + "%"
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
                                                width: Math.max(2, parent.width * Math.min(1.0, model.cpu / 100.0))
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
                                            text: model.mem_percent.toFixed(0) + "% RAM"
                                            font.family: "Noto Sans"
                                            font.pixelSize: 9
                                            color: taskManagerRoot.colMuted
                                        }
                                    }

                                    // 3. Action Buttons Row (124px: Focus + End)
                                    RowLayout {
                                        Layout.preferredWidth: 124
                                        spacing: 6

                                        Rectangle {
                                            id: focusBtn
                                            visible: procRow.hasWin
                                            Layout.preferredWidth: 58
                                            Layout.preferredHeight: 28
                                            radius: 14
                                            color: focusMouse.containsMouse 
                                                ? Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.28)
                                                : Qt.rgba(taskManagerRoot.colAccent.r, taskManagerRoot.colAccent.g, taskManagerRoot.colAccent.b, 0.15)
                                            border.width: 0
                                            scale: focusMouse.pressed ? 0.92 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 80 } }
                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4

                                                MaterialSymbol {
                                                    text: "open_in_new"
                                                    iconSize: 12
                                                    color: taskManagerRoot.colAccent
                                                }

                                                Text {
                                                    text: "Focus"
                                                    font.family: "Noto Sans"
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                    color: taskManagerRoot.colAccent
                                                }
                                            }

                                            MouseArea {
                                                id: focusMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: {
                                                    taskManagerRoot.focusWindow(model.address, model.pid);
                                                }
                                            }
                                        }

                                        Item { 
                                            visible: !procRow.hasWin
                                            Layout.preferredWidth: 58
                                            Layout.preferredHeight: 28
                                        }

                                        // End Task Action Button
                                        Rectangle {
                                            id: killBtn
                                            Layout.preferredWidth: 58
                                            Layout.preferredHeight: 28
                                            radius: 14
                                            color: killBtnMouse.containsMouse ? taskManagerRoot.colDanger : taskManagerRoot.colDangerBg
                                            border.width: 0
                                            scale: killBtnMouse.pressed ? 0.92 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 80 } }
                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 3

                                                MaterialSymbol {
                                                    text: "close"
                                                    iconSize: 12
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
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onClicked: (mouse) => {
                                                    var force = (mouse.button === Qt.RightButton) || (mouse.modifiers & Qt.ShiftModifier);
                                                    taskManagerRoot.killProcess(model.pid, force);
                                                }
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
                                propagateComposedEvents: true
                                z: -1
                                onClicked: (mouse) => {
                                    processList.currentIndex = index;
                                    taskManagerRoot.selectedPid = model.pid;
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
                                Layout.leftMargin: 16
                                Layout.rightMargin: 16
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
                                    border.width: 0

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
                                            text: (modelData.cpu || 0.0).toFixed(1) + "%"
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

                                        // Subprocess Action Column (124px)
                                        RowLayout {
                                            Layout.preferredWidth: 124
                                            spacing: 6

                                            Item { Layout.fillWidth: true }

                                            Rectangle {
                                                Layout.preferredWidth: 54
                                                Layout.preferredHeight: 24
                                                radius: 12
                                                color: subKillMouse.containsMouse ? taskManagerRoot.colDanger : Qt.rgba(255, 84, 73, 0.12)
                                                border.width: 0
                                                scale: subKillMouse.pressed ? 0.90 : 1.0
                                                Behavior on scale { NumberAnimation { duration: 80 } }
                                                Behavior on color { ColorAnimation { duration: 120 } }

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 3
                                                    MaterialSymbol {
                                                        text: "close"
                                                        iconSize: 11
                                                        color: subKillMouse.containsMouse ? "#ffffff" : taskManagerRoot.colDanger
                                                    }
                                                    Text {
                                                        text: "End"
                                                        font.family: "Noto Sans"
                                                        font.pixelSize: 9
                                                        font.weight: Font.DemiBold
                                                        color: subKillMouse.containsMouse ? "#ffffff" : taskManagerRoot.colDanger
                                                    }
                                                }

                                                MouseArea {
                                                    id: subKillMouse
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                    onClicked: (mouse) => {
                                                        var force = (mouse.button === Qt.RightButton) || (mouse.modifiers & Qt.ShiftModifier);
                                                        taskManagerRoot.killProcess(modelData.pid, force);
                                                    }
                                                }
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
}
