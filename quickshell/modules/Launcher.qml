import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import "lucidlauncher" as Lucid

FocusScope {
    id: launcher
    focus: true
    activeFocusOnTab: true

    width: parent ? parent.width : 580
    height: parent ? parent.height : 500

    // Theme resolution: seamless Dynamic You singleton with safe fallback
    readonly property var themeObj: (typeof Theme !== "undefined") ? Theme : null
    readonly property color cAccent: (themeObj && themeObj.accent) ? themeObj.accent : "#7aa2f7"
    readonly property color cText: (themeObj && themeObj.text) ? themeObj.text : "#f0dfd7"
    readonly property color cSubtext: (themeObj && themeObj.subtext) ? themeObj.subtext : "#d7c2b8"
    readonly property color cSubtextDim: (themeObj && themeObj.subtextDim) ? themeObj.subtextDim : "#9f8d84"
    readonly property color cCardBg: (themeObj && themeObj.colors && themeObj.colors.card_bg) ? themeObj.colors.card_bg : "#1c1b1f"
    readonly property color cHoverBg: (themeObj && themeObj.colors && themeObj.colors.hover_bg) ? themeObj.colors.hover_bg : "#2b2930"

    // ========================================================
    // PUBLIC INTERFACES & SHELL COMPATIBILITY CONTRACT
    // ========================================================
    property alias searchInput: searchInputField
    property alias searchWidget: searchWidgetProxy
    property var allApps: (typeof root !== "undefined" && root.cachedApps && root.cachedApps.length > 0) ? root.cachedApps : []

    property string activeMode: "apps" // "apps" | "commands" | "calc" | "web"
    readonly property int calculatedCount: resultsModel.count
    readonly property bool browsing: searchInputField.text.trim() === ""

    readonly property real targetWidth: 580
    readonly property real targetHeight: {
        var itemsCount = resultsModel.count;
        var listMeasured = itemsCount === 0 ? 110 : Math.min(6, itemsCount) * 56;
        var totalH = headerBox.height + modeBar.height + listMeasured + 36;
        return Math.min(500, Math.max(170, totalH));
    }

    // Safe color helper to avoid any TypeError
    function safeAlpha(c, a, fallback) {
        if (!c || c === undefined) return fallback || Qt.rgba(1, 1, 1, a || 0.1);
        try {
            return Qt.rgba(c.r, c.g, c.b, a);
        } catch(e) {
            return fallback || Qt.rgba(1, 1, 1, a || 0.1);
        }
    }

    // ========================================================
    // SEARCH WIDGET PROXY (For shell.qml IPC and status checks)
    // ========================================================
    QtObject {
        id: searchWidgetProxy

        readonly property int realResultCount: resultsModel.count
        readonly property real contentTargetWidth: launcher.targetWidth
        readonly property real contentTargetHeight: launcher.targetHeight
        readonly property real collapsedHeight: 170

        readonly property var searchBar: QtObject {
            readonly property var searchInput: searchInputField
        }

        readonly property var appResults: QtObject {
            readonly property int count: resultsModel.count
            readonly property int currentIndex: resultsList.currentIndex
            function selectFirst() {
                if (resultsModel.count > 0) resultsList.currentIndex = 0;
            }
        }

        readonly property var searchKeyRouter: QtObject {
            function dispatch(action) {
                if (action === "navigateDown") {
                    return launcher.navDown();
                } else if (action === "navigateUp") {
                    return launcher.navUp();
                }
                return false;
            }
        }

        function activateSelected() {
            return launcher.activateSelected();
        }

        function setSearchingText(query) {
            launcher.processSearch(query);
        }

        function focusSearchInput() {
            searchInputField.forceActiveFocus();
        }
    }

    // ========================================================
    // NAVIGATION & ACTIVATION FUNCTIONS
    // ========================================================
    function navDown(): bool {
        if (resultsModel.count === 0) return false;
        resultsList.currentIndex = (resultsList.currentIndex + 1) % resultsModel.count;
        resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain);
        return true;
    }

    function navUp(): bool {
        if (resultsModel.count === 0) return false;
        resultsList.currentIndex = (resultsList.currentIndex - 1 + resultsModel.count) % resultsModel.count;
        resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain);
        return true;
    }

    function activateSelected(): bool {
        if (resultsModel.count === 0) return false;
        var idx = resultsList.currentIndex;
        if (idx < 0 || idx >= resultsModel.count) idx = 0;
        return activateItem(resultsModel.get(idx));
    }

    function activateItem(row): bool {
        if (!row) return false;

        var k = row.kind;
        if (k === "app") {
            if (row.rawEntry && typeof row.rawEntry.execute === "function") {
                row.rawEntry.execute();
            } else if (row.exec && row.exec !== "") {
                Quickshell.execDetached(["sh", "-c", row.exec]);
            }
        } else if (k === "calc") {
            Quickshell.execDetached(["wl-copy", "--", String(row.payload)]);
        } else if (k === "run") {
            Quickshell.execDetached(["sh", "-c", String(row.payload)]);
        } else if (k === "runterm") {
            Quickshell.execDetached([
                "sh", "-c",
                "exec xdg-terminal-exec sh -c \"$1; echo; printf 'Done. Press Return to close...'; read _\"",
                "sh", String(row.payload)
            ]);
        } else if (k === "web") {
            Qt.openUrlExternally(String(row.payload));
        } else if (k === "cmd") {
            if (row.payload === "settings") {
                if (typeof root !== "undefined" && typeof root.openSettings === "function") {
                    root.openSettings("");
                }
            } else {
                Quickshell.execDetached(["sh", "-c", String(row.payload)]);
            }
        }

        collapse();
        return true;
    }

    function collapse() {
        try {
            if (typeof GlobalStates !== "undefined") {
                GlobalStates.overviewOpen = false;
            }
        } catch (e) {}
        try {
            if (typeof root !== "undefined" && typeof root.collapseToIdle === "function") {
                root.collapseToIdle();
            }
        } catch (e) {}
    }

    function onOpened() {
        try {
            if (typeof GlobalStates !== "undefined") {
                GlobalStates.overviewOpen = true;
            }
        } catch (e) {}
        searchInputField.forceActiveFocus();
        Qt.callLater(() => {
            searchInputField.forceActiveFocus();
            searchInputField.cursorPosition = searchInputField.text.length;
            if (resultsModel.count > 0) resultsList.currentIndex = 0;
        });
    }

    function processSearch(query) {
        var q = query || "";
        if (searchInputField.text !== q) {
            searchInputField.text = q;
        }
        rebuildResults();
    }

    function updateSuggestions() {
        rebuildResults();
    }

    function cycleMode(delta) {
        var modes = ["apps", "commands", "calc", "web"];
        var at = modes.indexOf(launcher.activeMode);
        if (at === -1) at = 0;
        launcher.activeMode = modes[(at + delta + modes.length) % modes.length];
        rebuildResults();
        searchInputField.forceActiveFocus();
    }

    // ========================================================
    // KEYBOARD EVENTS
    // ========================================================
    Keys.onEscapePressed: {
        collapse();
    }

    Keys.onDownPressed: {
        navDown();
    }

    Keys.onUpPressed: {
        navUp();
    }

    Keys.onReturnPressed: {
        activateSelected();
    }

    Keys.onEnterPressed: {
        activateSelected();
    }

    Keys.onTabPressed: (event) => {
        cycleMode(1);
        event.accepted = true;
    }

    Keys.onBacktabPressed: (event) => {
        cycleMode(-1);
        event.accepted = true;
    }

    onAllAppsChanged: {
        rebuildResults();
    }

    onActiveModeChanged: {
        rebuildResults();
    }

    // ========================================================
    // SEARCH & FILTER LOGIC
    // ========================================================
    readonly property var systemCommands: [
        { name: "Lock Screen", desc: "Lock desktop session", payload: "hyprlock", glyph: "lock" },
        { name: "Dynamic You Settings", desc: "Open dynamic notch configuration", payload: "settings", glyph: "settings" },
        { name: "Take Screenshot (Area)", desc: "Capture selective screen region", payload: "grimblast copy area", glyph: "screenshot_monitor" },
        { name: "Take Screenshot (Full)", desc: "Capture full monitor screen", payload: "grimblast copy screen", glyph: "screenshot_monitor" },
        { name: "Open Terminal", desc: "Launch default command line terminal", payload: "xdg-terminal-exec", glyph: "terminal_2" },
        { name: "Reload Notch Theme", desc: "Refresh Matugen colors and styles", payload: "qs ipc call notch reloadTheme", glyph: "palette" },
        { name: "Suspend System", desc: "Put system to sleep", payload: "systemctl suspend", glyph: "bedtime" },
        { name: "Reboot System", desc: "Restart the operating system", payload: "systemctl reboot", glyph: "restart_alt" },
        { name: "Power Off", desc: "Shutdown computer", payload: "systemctl poweroff", glyph: "power_settings_new" },
        { name: "Exit Hyprland", desc: "Terminate Wayland compositor session", payload: "hyprctl dispatch exit", glyph: "logout" }
    ]

    function matchScore(app, q) {
        var name = (app.name || "").toLowerCase();
        if (name.indexOf(q) === 0) return 100;
        if (name.indexOf(" " + q) !== -1) return 90;
        if (name.indexOf(q) !== -1) return 80;

        var words = name.split(/[\s\-_]+/);
        if (words.length > 1) {
            var initials = "";
            for (var w = 0; w < words.length; w++) {
                if (words[w].length > 0) initials += words[w][0];
            }
            if (initials.indexOf(q) === 0) return 70;
        }

        var comment = (app.comment || "").toLowerCase();
        if (comment.indexOf(q) !== -1) return 50;

        var exec = (app.exec || "").toLowerCase();
        if (exec.indexOf(q) !== -1) return 40;

        var ci = 0;
        for (var i = 0; i < name.length && ci < q.length; i++) {
            if (name.charAt(i) === q.charAt(ci)) ci++;
        }
        if (ci === q.length) return 20;

        return -1;
    }

    function rebuildResults() {
        var raw = searchInputField.text;
        var trimmed = raw.trim();
        var q = trimmed.toLowerCase();
        var mode = launcher.activeMode;

        // Auto-switch prefix detections
        if (raw.startsWith(">") && mode !== "commands") {
            mode = "commands";
        } else if (raw.startsWith("?") && mode !== "web") {
            mode = "web";
        }

        var rows = [];

        // 1. Calculator Check (Lucid DockCalc)
        var calcExpr = raw.startsWith("=") ? raw.substring(1).trim() : raw.trim();
        var calcResult = (mode === "calc" || mode === "apps") ? Lucid.DockCalc.evaluate(calcExpr) : "";
        if (calcResult !== "") {
            rows.push({
                kind: "calc",
                title: calcResult,
                subtitle: "= " + calcExpr,
                payload: calcResult,
                exec: "",
                iconName: "",
                glyph: "calculate",
                actionText: "Copy",
                rawEntry: null
            });
        }

        // 2. Mode Handling
        if (mode === "apps") {
            var appsList = launcher.allApps;
            if (!appsList || appsList.length === 0) {
                if (typeof root !== "undefined" && root.cachedApps) appsList = root.cachedApps;
            }

            if (appsList && appsList.length > 0) {
                if (q === "") {
                    for (var i = 0; i < appsList.length; i++) {
                        var a = appsList[i];
                        rows.push({
                            kind: "app",
                            title: a.name || "",
                            subtitle: a.comment || "",
                            payload: a.exec || "",
                            exec: a.exec || "",
                            iconName: a.iconName || "",
                            glyph: "apps",
                            actionText: "Open",
                            rawEntry: a.rawEntry || null
                        });
                    }
                } else {
                    var scored = [];
                    for (var s = 0; s < appsList.length; s++) {
                        var item = appsList[s];
                        var score = matchScore(item, q);
                        if (score >= 0) {
                            scored.push({ app: item, score: score });
                        }
                    }
                    scored.sort(function(a, b) {
                        if (a.score !== b.score) return b.score - a.score;
                        return a.app.name.localeCompare(b.app.name);
                    });
                    for (var r = 0; r < scored.length; r++) {
                        var sc = scored[r].app;
                        rows.push({
                            kind: "app",
                            title: sc.name || "",
                            subtitle: sc.comment || "",
                            payload: sc.exec || "",
                            exec: sc.exec || "",
                            iconName: sc.iconName || "",
                            glyph: "apps",
                            actionText: "Open",
                            rawEntry: sc.rawEntry || null
                        });
                    }
                }
            }

            if (q !== "" && calcResult === "") {
                rows.push({
                    kind: "web",
                    title: "Search Web for \"" + trimmed + "\"",
                    subtitle: "Open default web browser",
                    payload: "https://www.google.com/search?q=" + encodeURIComponent(trimmed),
                    exec: "",
                    iconName: "",
                    glyph: "travel_explore",
                    actionText: "Search",
                    rawEntry: null
                });
            }
        } else if (mode === "commands") {
            var cmdQuery = raw.startsWith(">") ? raw.substring(1).trim() : trimmed;
            var cmdQ = cmdQuery.toLowerCase();

            if (cmdQuery !== "") {
                rows.push({
                    kind: "run",
                    title: "Run: " + cmdQuery,
                    subtitle: "Execute command in background",
                    payload: cmdQuery,
                    exec: cmdQuery,
                    iconName: "",
                    glyph: "play_arrow",
                    actionText: "Run",
                    rawEntry: null
                });
                rows.push({
                    kind: "runterm",
                    title: "Run in terminal: " + cmdQuery,
                    subtitle: "Execute command inside terminal window",
                    payload: cmdQuery,
                    exec: cmdQuery,
                    iconName: "",
                    glyph: "terminal_2",
                    actionText: "Terminal",
                    rawEntry: null
                });
            }

            for (var c = 0; c < systemCommands.length; c++) {
                var sys = systemCommands[c];
                if (cmdQ === "" || sys.name.toLowerCase().indexOf(cmdQ) !== -1 || sys.desc.toLowerCase().indexOf(cmdQ) !== -1) {
                    rows.push({
                        kind: "cmd",
                        title: sys.name,
                        subtitle: sys.desc,
                        payload: sys.payload,
                        exec: sys.payload,
                        iconName: "",
                        glyph: sys.glyph,
                        actionText: "Run",
                        rawEntry: null
                    });
                }
            }
        } else if (mode === "calc") {
            if (calcResult === "") {
                if (trimmed !== "") {
                    rows.push({
                        kind: "calc",
                        title: "Invalid expression",
                        subtitle: "Try typing: 24 * 7, sqrt(144), 15% of 80, 2^8",
                        payload: "",
                        exec: "",
                        iconName: "",
                        glyph: "calculate",
                        actionText: "",
                        rawEntry: null
                    });
                } else {
                    rows.push({
                        kind: "calc",
                        title: "Calculator ready",
                        subtitle: "Type any math expression (e.g. 128 * 4, pi * 2, sqrt(256))",
                        payload: "",
                        exec: "",
                        iconName: "",
                        glyph: "calculate",
                        actionText: "",
                        rawEntry: null
                    });
                }
            }
        } else if (mode === "web") {
            var wq = raw.startsWith("?") ? raw.substring(1).trim() : trimmed;
            if (wq !== "") {
                var isUrl = wq.indexOf("://") !== -1 || /^[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}/.test(wq);
                if (isUrl) {
                    var fullUrl = wq.indexOf("://") !== -1 ? wq : ("https://" + wq);
                    rows.push({
                        kind: "web",
                        title: "Open: " + wq,
                        subtitle: "Navigate directly to URL",
                        payload: fullUrl,
                        exec: "",
                        iconName: "",
                        glyph: "public",
                        actionText: "Open",
                        rawEntry: null
                    });
                }
                rows.push({
                    kind: "web",
                    title: "Google Search: \"" + wq + "\"",
                    subtitle: "Search web using default browser",
                    payload: "https://www.google.com/search?q=" + encodeURIComponent(wq),
                    exec: "",
                    iconName: "",
                    glyph: "travel_explore",
                    actionText: "Search",
                    rawEntry: null
                });
            } else {
                rows.push({
                    kind: "web",
                    title: "Web Search",
                    subtitle: "Type search keywords or a web URL",
                    payload: "",
                    exec: "",
                    iconName: "",
                    glyph: "travel_explore",
                    actionText: "",
                    rawEntry: null
                });
            }
        }

        resultsModel.clear();
        for (var k = 0; k < rows.length; k++) {
            resultsModel.append(rows[k]);
        }
        if (resultsModel.count > 0) {
            resultsList.currentIndex = 0;
        }
    }

    ListModel {
        id: resultsModel
    }

    // ========================================================
    // UI LAYOUT: DOWNWARDS EXPANSION CONTAINER
    // ========================================================
    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.margins: 12

        // ----------------------------------------------------
        // 1. TOP SEARCH BAR (Material 3 Translucent Pill)
        // ----------------------------------------------------
        Rectangle {
            id: headerBox
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            radius: 24

            color: Qt.rgba(0.12, 0.12, 0.16, 0.85)
            border.width: searchInputField.activeFocus ? 2 : 1
            border.color: searchInputField.activeFocus ? launcher.cAccent : Qt.rgba(1, 1, 1, 0.12)

            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Leading Search Icon
            Lucid.Icon {
                id: searchLeadingIcon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                size: 20
                color: searchInputField.activeFocus ? launcher.cAccent : launcher.cText
                name: {
                    if (launcher.activeMode === "commands") return "terminal_2";
                    if (launcher.activeMode === "calc") return "calculate";
                    if (launcher.activeMode === "web") return "travel_explore";
                    return "search";
                }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Primary Text Input
            TextInput {
                id: searchInputField
                anchors.left: searchLeadingIcon.right
                anchors.leftMargin: 12
                anchors.right: trailingControls.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                focus: true
                activeFocusOnTab: true

                color: launcher.cText
                selectionColor: launcher.cAccent
                selectedTextColor: "#ffffff"
                font.pixelSize: 15
                font.weight: Font.Normal

                onTextChanged: {
                    launcher.rebuildResults();
                }

                Keys.forwardTo: [launcher]

                Text {
                    id: placeholder
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: searchInputField.text === "" && !searchInputField.inputMethodComposing
                    text: {
                        if (launcher.activeMode === "commands") return "Type command or prefix with '>'...";
                        if (launcher.activeMode === "calc") return "Enter calculation (e.g. 54 * 12)...";
                        if (launcher.activeMode === "web") return "Search the web or type a URL...";
                        return "Search apps, calculate, or '>' for commands...";
                    }
                    color: launcher.cSubtextDim
                    font.pixelSize: 15
                }
            }

            // Trailing Controls (Result Count + Clear Button)
            Row {
                id: trailingControls
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    id: countBadge
                    height: 22
                    width: countText.implicitWidth + 14
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.08)
                    visible: resultsModel.count > 0

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: {
                            var n = resultsModel.count;
                            if (launcher.activeMode === "apps" && searchInputField.text === "") {
                                return n + (n === 1 ? " app" : " apps");
                            }
                            return n + (n === 1 ? " result" : " results");
                        }
                        color: launcher.cSubtext
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }

                Lucid.IconButton {
                    id: clearBtn
                    anchors.verticalCenter: parent.verticalCenter
                    size: "xs"
                    icon: "close"
                    visible: searchInputField.text.length > 0
                    onClicked: {
                        searchInputField.text = "";
                        searchInputField.forceActiveFocus();
                        launcher.rebuildResults();
                    }
                }
            }
        }

        // ----------------------------------------------------
        // 2. MODE BAR CHIPS (Apps, Commands, Calc, Web)
        // ----------------------------------------------------
        Item {
            id: modeBar
            anchors.top: headerBox.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    model: [
                        { id: "apps", label: "Apps", icon: "apps" },
                        { id: "commands", label: "Commands", icon: "terminal_2" },
                        { id: "calc", label: "Calculator", icon: "calculate" },
                        { id: "web", label: "Web", icon: "travel_explore" }
                    ]

                    delegate: Rectangle {
                        id: modeChip
                        height: 28
                        width: chipRow.implicitWidth + 20
                        radius: 14
                        readonly property bool isActive: launcher.activeMode === modelData.id
                        property bool isHovered: false

                        color: isActive
                            ? launcher.safeAlpha(launcher.cAccent, 0.22, Qt.rgba(0.5, 0.6, 1, 0.22))
                            : (isHovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                        border.width: 1
                        border.color: isActive
                            ? launcher.cAccent
                            : (isHovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1))

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6

                            Lucid.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 14
                                name: modelData.icon
                                color: modeChip.isActive ? launcher.cAccent : launcher.cSubtext
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: modeChip.isActive ? launcher.cAccent : launcher.cText
                                font.pixelSize: 12
                                font.weight: modeChip.isActive ? Font.DemiBold : Font.Normal
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: modeChip.isHovered = true
                            onExited: modeChip.isHovered = false
                            onClicked: {
                                launcher.activeMode = modelData.id;
                                searchInputField.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------
        // 3. DOWNWARDS RESULTS LIST (Material 3 Results List)
        // ----------------------------------------------------
        ListView {
            id: resultsList
            anchors.top: modeBar.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: resultsModel
            currentIndex: 0

            ScrollBar.vertical: ScrollBar {
                active: resultsList.moving || resultsList.contentHeight > resultsList.height
                policy: (resultsList.contentHeight > resultsList.height) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                width: 6
            }

            delegate: Item {
                id: rowDelegate
                width: resultsList.width
                height: isCalcHero ? 64 : 52

                readonly property bool isSelected: resultsList.currentIndex === index
                readonly property bool isCalcHero: model.kind === "calc" && model.title !== "Calculator ready" && model.title !== "Invalid expression"
                property bool isHovered: false

                // Selection / Hero Background Card
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    radius: isCalcHero ? 16 : 12

                    color: {
                        if (rowDelegate.isCalcHero) {
                            return rowDelegate.isSelected
                                ? launcher.safeAlpha(launcher.cAccent, 0.28, Qt.rgba(0.5, 0.6, 1, 0.28))
                                : launcher.safeAlpha(launcher.cAccent, 0.16, Qt.rgba(0.5, 0.6, 1, 0.16));
                        }
                        if (rowDelegate.isSelected) {
                            return launcher.safeAlpha(launcher.cAccent, 0.18, Qt.rgba(0.5, 0.6, 1, 0.18));
                        }
                        return rowDelegate.isHovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent";
                    }

                    border.width: (rowDelegate.isSelected || rowDelegate.isCalcHero) ? 1 : 0
                    border.color: launcher.safeAlpha(launcher.cAccent, rowDelegate.isCalcHero ? 0.6 : 0.45, Qt.rgba(0.5, 0.6, 1, 0.5))

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    // Accent leading bar for active selection
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: isCalcHero ? 36 : 24
                        radius: 2
                        color: launcher.cAccent
                        visible: rowDelegate.isSelected
                    }
                }

                // Left Icon slot (Fixed 40dp width)
                Item {
                    id: iconSlot
                    x: 12
                    width: 36
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter

                    IconImage {
                        id: appIconImg
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        visible: model.iconName !== "" && status === Image.Ready
                        source: model.iconName !== "" ? Quickshell.iconPath(model.iconName, true) : ""
                    }

                    Lucid.Icon {
                        anchors.centerIn: parent
                        size: rowDelegate.isCalcHero ? 24 : 20
                        visible: model.iconName === "" || appIconImg.status !== Image.Ready
                        name: model.glyph !== "" ? model.glyph : "apps"
                        color: (rowDelegate.isSelected || rowDelegate.isCalcHero) ? launcher.cAccent : launcher.cText
                    }
                }

                // Middle Text Block (Calculated width, never clips or collapses)
                Column {
                    id: textBlock
                    anchors.left: iconSlot.right
                    anchors.leftMargin: 12
                    anchors.right: actionTag.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: model.title
                        color: (rowDelegate.isSelected || rowDelegate.isCalcHero) ? launcher.cAccent : launcher.cText
                        font.pixelSize: rowDelegate.isCalcHero ? 18 : 14
                        font.weight: (rowDelegate.isSelected || rowDelegate.isCalcHero) ? Font.Bold : Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: model.subtitle
                        color: rowDelegate.isCalcHero ? launcher.cAccent : launcher.cSubtext
                        opacity: rowDelegate.isCalcHero ? 0.8 : 1.0
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        visible: model.subtitle !== ""
                    }
                }

                // Right Trailing Action Tag
                Rectangle {
                    id: actionTag
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    width: actionLabel.implicitWidth + 14
                    radius: 12
                    visible: model.actionText !== "" && (rowDelegate.isSelected || rowDelegate.isCalcHero || rowDelegate.isHovered)
                    color: rowDelegate.isSelected ? launcher.cAccent : Qt.rgba(1, 1, 1, 0.1)

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: model.actionText + " ↵"
                        color: rowDelegate.isSelected ? "#ffffff" : launcher.cText
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        rowDelegate.isHovered = true;
                        resultsList.currentIndex = index;
                    }
                    onExited: {
                        rowDelegate.isHovered = false;
                    }
                    onClicked: {
                        launcher.activateItem(resultsModel.get(index));
                    }
                }
            }

            // Empty State View
            Item {
                anchors.centerIn: parent
                width: parent.width - 40
                height: 100
                visible: resultsModel.count === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Lucid.Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 32
                        name: "search_off"
                        color: launcher.cSubtextDim
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No results found"
                        color: launcher.cText
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Try entering math (e.g. 25 * 4), prefix '>' for terminal, or '?' for web"
                        color: launcher.cSubtextDim
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        rebuildResults();
        console.log("[LAUNCHER] Lucid-style lightweight launcher initialized.");
    }
}
