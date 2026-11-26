import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../../"
import "../../"
import "../"

// Lucid GitHub contribution heatmap widget ported natively to Dynamic You
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "github"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "1x3")
    readonly property string user: String(opts.user || "").trim()
    readonly property string colorMode: String(opts.colorMode || "accent") // "accent" | "github"
    readonly property bool showShadow: opts.showShadow !== false

    property int total: 0
    property int streak: 0
    property int bestDay: 0
    property int activeDays: 0
    property var weeks: []
    property var months: []
    property bool loading: false
    property string errorText: ""
    property string hoveredSummary: ""
    property bool editingUser: false
    readonly property bool resizing: root.editingUser
        || actionBtnMouse.containsMouse || actionBtnMouse.pressed
        || refreshBtnMouse.containsMouse || refreshBtnMouse.pressed
        || profileBtnMouse.containsMouse || profileBtnMouse.pressed
        || heatmapMouse.containsMouse || heatmapMouse.pressed
        || inputBoxMouse.containsMouse || inputBoxMouse.pressed
        || saveBtnMouse.containsMouse || saveBtnMouse.pressed
        || cancelBtnMouse.containsMouse || cancelBtnMouse.pressed

    onEditingUserChanged: {
        if (root.onDesktop && typeof WidgetStore !== "undefined") {
            WidgetStore.desktopKeyboardFocus = root.editingUser;
        }
    }
    Component.onDestruction: {
        if (root.onDesktop && root.editingUser && typeof WidgetStore !== "undefined") {
            WidgetStore.desktopKeyboardFocus = false;
        }
    }

    readonly property bool isCompact: sizeMode === "1x2"
    readonly property bool isTall: sizeMode === "2x2"
    readonly property int maxVisibleCols: isCompact ? 22 : (isTall ? 26 : 52)
    readonly property bool hasUser: root.user.length > 0

    // Sample contribution graph when unconfigured (matching Lucid octocat sample feel)
    readonly property var sampleWeeks: {
        const pattern = [
            0, 1, 2, 1, 0, 2, 3, 1, 0, 1, 3, 4, 2, 1, 0, 2, 1, 0, 1, 2, 3, 4, 2, 1, 0, 1,
            2, 3, 1, 0, 2, 4, 3, 2, 1, 0, 2, 3, 2, 1, 0, 1, 3, 4, 3, 2, 1, 2, 3, 4, 3, 2
        ];
        const out = [];
        const baseMs = Date.now() - 52 * 7 * 86400000;
        for (let w = 0; w < 52; w++) {
            const days = [];
            for (let d = 0; d < 7; d++) {
                const lvl = ((w * 3 + d * 5 + pattern[w]) % 7 === 0) ? 0 : ((w + d + pattern[w]) % 5);
                const dt = new Date(baseMs + (w * 7 + d) * 86400000);
                days.push({
                    date: dt.toISOString().slice(0, 10),
                    count: lvl === 0 ? 0 : lvl * 2,
                    level: lvl
                });
            }
            out.push(days);
        }
        return out;
    }

    readonly property var visibleWeeks: {
        const src = (hasUser && weeks.length > 0) ? weeks : sampleWeeks;
        const count = Math.min(maxVisibleCols, src.length);
        return count > 0 ? src.slice(src.length - count) : [];
    }

    readonly property var paletteLevels: {
        const empty = Theme.m3.surface_container_highest ?? Qt.rgba(1, 1, 1, 0.08);
        if (colorMode === "github") {
            return [empty, "#0e4429", "#006d32", "#26a641", "#39d353"];
        }
        const acc = Qt.color(Theme.m3.primary ?? Theme.accent);
        const bg = Qt.color(Theme.m3.surface_container ?? Theme.colors.card_bg);
        return [
            empty,
            Qt.tint(bg, Qt.rgba(acc.r, acc.g, acc.b, 0.28)),
            Qt.tint(bg, Qt.rgba(acc.r, acc.g, acc.b, 0.50)),
            Qt.tint(bg, Qt.rgba(acc.r, acc.g, acc.b, 0.74)),
            acc
        ];
    }

    function applyContributionData(payload) {
        if (!payload || typeof payload !== "object") return;
        if (payload.ok === false || payload.error) {
            root.errorText = String(payload.error || "User not found");
            return;
        }
        root.errorText = "";
        root.total = Number(payload.total) || 0;

        // github-contributions.py returns `days: [[date, count, level], ...]` + `streak`
        const rawDays = Array.isArray(payload.days) ? payload.days : [];
        let loadedWeeks = Array.isArray(payload.weeks) ? payload.weeks : [];
        let best = 0;
        let activeCnt = 0;

        if (rawDays.length > 0) {
            loadedWeeks = [];
            let currentWeek = [];
            for (let i = 0; i < rawDays.length; i++) {
                const entry = rawDays[i];
                if (!Array.isArray(entry) || entry.length < 3) continue;
                const dStr = String(entry[0]);
                const c = Number(entry[1]) || 0;
                const lvl = Math.max(0, Math.min(4, Number(entry[2]) || 0));
                if (c > best) best = c;
                if (c > 0) activeCnt++;

                if (i === 0) {
                    const dow = new Date(dStr + "T12:00:00").getDay();
                    for (let p = 0; p < dow; p++) {
                        currentWeek.push({ date: "", count: 0, level: 0 });
                    }
                }
                currentWeek.push({ date: dStr, count: c, level: lvl });
                if (currentWeek.length === 7) {
                    loadedWeeks.push(currentWeek);
                    currentWeek = [];
                }
            }
            if (currentWeek.length > 0) {
                loadedWeeks.push(currentWeek);
            }
        }

        root.weeks = loadedWeeks;
        root.streak = Number(payload.streak) || 0;
        root.bestDay = best;
        root.activeDays = activeCnt;
    }

    readonly property string scriptPath: Quickshell.shellPath("modules/widgets/cards/github-contributions.py")

    function openInlineEditor() {
        root.editingUser = true;
        userInput.text = root.user;
        Qt.callLater(() => {
            userInput.forceActiveFocus();
            userInput.selectAll();
        });
    }

    function commitUsername(rawText) {
        const clean = String(rawText || "").trim().replace(/^@/, "");
        WidgetStore.setCardOption(root.tileId, "user", clean);
        root.editingUser = false;
    }

    function fetchContributions() {
        if (!root.hasUser) return;
        if (fetchProc.running) fetchProc.running = false;
        root.loading = true;
        root.errorText = "";
        fetchProc.command = ["python3", root.scriptPath, root.user];
        fetchProc.running = true;
    }

    onUserChanged: {
        if (root.hasUser) Qt.callLater(root.fetchContributions);
        else {
            root.weeks = [];
            root.total = 0;
            root.streak = 0;
            root.errorText = "";
        }
    }

    onActiveChanged: {
        if (root.active && root.hasUser && root.weeks.length === 0 && !fetchProc.running) {
            Qt.callLater(root.fetchContributions);
        }
    }

    Component.onCompleted: {
        if (root.hasUser) Qt.callLater(root.fetchContributions);
    }

    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                const raw = String(this.text || "").trim();
                if (!raw) {
                    root.errorText = "No response";
                    return;
                }
                try {
                    root.applyContributionData(JSON.parse(raw));
                } catch (e) {
                    root.errorText = "Parse error";
                }
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.loading) {
                root.loading = false;
                root.errorText = "Fetch failed";
            }
        }
    }

    Timer {
        interval: 3600000
        repeat: true
        running: root.active && root.hasUser
        onTriggered: root.fetchContributions()
    }

    readonly property color cardBg: Theme.m3.surface_container ?? Theme.colors.card_bg
    readonly property color cardFg: Theme.m3.on_surface ?? Theme.colors.text_primary
    readonly property color mutedFg: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
    readonly property color accentColor: Theme.m3.primary ?? Theme.accent

    Rectangle {
        id: bgSurface
        anchors.fill: parent
        radius: WidgetStore.s(24)
        color: root.cardBg
        border.width: Math.max(1, WidgetStore.s(1))
        border.color: Qt.alpha(Theme.m3.outline_variant ?? "#4a5c72", 0.36)

        layer.enabled: root.onDesktop && root.showShadow && root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(
            Math.max(1, Math.round(width * WidgetStore.qtScale)),
            Math.max(1, Math.round(height * WidgetStore.qtScale))
        )
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.38)
            shadowBlur: 0.65
            shadowVerticalOffset: WidgetStore.s(4)
            autoPaddingEnabled: true
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: WidgetStore.s(14)
        }
        spacing: WidgetStore.s(8)

        // Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: WidgetStore.s(8)

            // GitHub icon badge (opens profile or inline editor)
            Rectangle {
                Layout.preferredWidth: WidgetStore.s(26)
                Layout.preferredHeight: WidgetStore.s(26)
                radius: width / 2
                color: profileBtnMouse.containsMouse
                    ? Qt.alpha(root.accentColor, 0.28)
                    : Qt.alpha(root.accentColor, 0.16)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "commit"
                    iconSize: WidgetStore.si(15)
                    fill: 1
                    color: root.accentColor
                }

                MouseArea {
                    id: profileBtnMouse
                    enabled: root.interactive
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.hasUser) Quickshell.execDetached(["xdg-open", "https://github.com/" + root.user]);
                        else root.openInlineEditor();
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.hasUser ? ("@" + root.user) : "GitHub Activity"
                    color: root.cardFg
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(12)
                    font.weight: Font.Bold
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (!root.hasUser) return "Tap to set username (sample shown)";
                        if (root.hoveredSummary !== "") return root.hoveredSummary;
                        if (root.loading) return "Syncing contributions...";
                        if (root.errorText !== "") return root.errorText;
                        return root.total + " commits · " + root.streak + "d streak";
                    }
                    color: root.hoveredSummary !== "" ? root.accentColor : root.mutedFg
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(9.5)
                    font.weight: root.hoveredSummary !== "" ? Font.DemiBold : Font.Normal
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }
            }

            // Less ... More legend (hidden when ultra compact or editing)
            Row {
                visible: !root.isCompact && !root.editingUser
                spacing: WidgetStore.s(3)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Less"
                    color: root.mutedFg
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(8.5)
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: root.paletteLevels
                    Rectangle {
                        required property color modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: WidgetStore.s(7)
                        height: WidgetStore.s(7)
                        radius: WidgetStore.s(2)
                        color: modelData
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "More"
                    color: root.mutedFg
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(8.5)
                    renderType: Text.NativeRendering
                }
            }

            // Refresh button (when user is configured)
            Rectangle {
                visible: root.interactive && root.hasUser && !root.editingUser
                Layout.preferredWidth: WidgetStore.s(24)
                Layout.preferredHeight: WidgetStore.s(24)
                radius: width / 2
                color: refreshBtnMouse.containsMouse
                    ? Qt.alpha(root.accentColor, 0.18)
                    : Qt.alpha(root.cardFg, 0.08)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: WidgetStore.si(13)
                    color: root.loading ? root.accentColor : root.cardFg
                }

                MouseArea {
                    id: refreshBtnMouse
                    enabled: root.interactive && root.hasUser
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.fetchContributions()
                }
            }

            // Edit / Add username trigger pill
            Rectangle {
                visible: root.interactive
                Layout.preferredWidth: WidgetStore.s(24)
                Layout.preferredHeight: WidgetStore.s(24)
                radius: width / 2
                color: (actionBtnMouse.containsMouse || root.editingUser)
                    ? Qt.alpha(root.accentColor, 0.22)
                    : Qt.alpha(root.cardFg, 0.08)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.editingUser ? "close" : (root.hasUser ? "edit" : "person_add")
                    iconSize: WidgetStore.si(13)
                    color: root.cardFg
                }

                MouseArea {
                    id: actionBtnMouse
                    enabled: root.interactive
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.editingUser) root.editingUser = false;
                        else root.openInlineEditor();
                    }
                }
            }
        }

        // Inline Username Input Drawer (appears when user taps Set / Edit)
        Rectangle {
            visible: root.editingUser && root.interactive
            Layout.fillWidth: true
            Layout.preferredHeight: WidgetStore.s(34)
            radius: WidgetStore.s(11)
            color: Theme.m3.surface_container_highest ?? Qt.rgba(1, 1, 1, 0.10)
            border.width: Math.max(1, WidgetStore.s(1.5))
            border.color: root.accentColor

            MouseArea {
                id: inputBoxMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onClicked: userInput.forceActiveFocus()
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: WidgetStore.s(10)
                    rightMargin: WidgetStore.s(6)
                }
                spacing: WidgetStore.s(6)

                TextInput {
                    id: userInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focus: root.editingUser
                    selectByMouse: true
                    color: root.cardFg
                    selectionColor: Qt.alpha(root.accentColor, 0.35)
                    selectedTextColor: root.cardFg
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(11.5)
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    onAccepted: root.commitUsername(text)
                    Keys.onEscapePressed: root.editingUser = false

                    Text {
                        visible: parent.text === ""
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "github username..."
                        color: root.mutedFg
                        font: parent.font
                    }
                }

                Rectangle {
                    Layout.preferredWidth: WidgetStore.s(46)
                    Layout.preferredHeight: WidgetStore.s(22)
                    radius: WidgetStore.s(7)
                    color: saveBtnMouse.pressed ? Qt.darker(root.accentColor, 1.15) : root.accentColor
                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        color: Theme.m3.on_primary ?? "#101014"
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(9.5)
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }
                    MouseArea {
                        id: saveBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.commitUsername(userInput.text)
                    }
                }

                Rectangle {
                    Layout.preferredWidth: WidgetStore.s(22)
                    Layout.preferredHeight: WidgetStore.s(22)
                    radius: WidgetStore.s(7)
                    color: cancelBtnMouse.containsMouse ? Qt.alpha(root.cardFg, 0.16) : Qt.alpha(root.cardFg, 0.08)
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: WidgetStore.si(12)
                        color: root.mutedFg
                    }
                    MouseArea {
                        id: cancelBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editingUser = false
                    }
                }
            }
        }

        // Heatmap Matrix Grid (Canvas for deterministic zero-lag rendering)
        Item {
            id: heatmapContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property int colsCount: Math.max(1, root.visibleWeeks.length)
            readonly property real gapPx: Math.max(1.5, WidgetStore.s(root.isCompact ? 2.4 : (root.isTall ? 3.0 : 2.0)))
            readonly property real cellSize: Math.max(
                WidgetStore.s(3.2),
                Math.min(
                    (width - (colsCount - 1) * gapPx) / colsCount,
                    (height - 6 * gapPx) / 7
                )
            )
            readonly property real gridW: colsCount * cellSize + (colsCount - 1) * gapPx
            readonly property real gridH: 7 * cellSize + 6 * gapPx
            readonly property real originX: Math.max(0, (width - gridW) / 2)
            readonly property real originY: Math.max(0, (height - gridH) / 2)

            Canvas {
                id: heatmapCanvas
                anchors.fill: parent
                antialiasing: true

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    target: root
                    function onVisibleWeeksChanged() { heatmapCanvas.requestPaint(); }
                    function onPaletteLevelsChanged() { heatmapCanvas.requestPaint(); }
                    function onHasUserChanged() { heatmapCanvas.requestPaint(); }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.clearRect(0, 0, width, height);
                    if (width <= 1 || height <= 1) return;

                    const wks = root.visibleWeeks;
                    if (!wks || wks.length === 0) return;

                    const cSize = heatmapContainer.cellSize;
                    const gPx = heatmapContainer.gapPx;
                    const ox = heatmapContainer.originX;
                    const oy = heatmapContainer.originY;
                    const rad = Math.max(1, Math.min(WidgetStore.s(2.4), cSize * 0.28));
                    const pal = root.paletteLevels.map(c => {
                        const q = Qt.color(c);
                        return "rgba(" + Math.round(q.r * 255) + "," + Math.round(q.g * 255) + "," + Math.round(q.b * 255) + "," + q.a + ")";
                    });

                    ctx.globalAlpha = root.hasUser ? 1.0 : 0.85;

                    for (let w = 0; w < wks.length; w++) {
                        const col = wks[w];
                        if (!Array.isArray(col)) continue;
                        const x = ox + w * (cSize + gPx);
                        for (let d = 0; d < col.length; d++) {
                            const day = col[d];
                            if (!day) continue;
                            const lvl = Math.max(0, Math.min(4, Number(day.level) || 0));
                            const y = oy + d * (cSize + gPx);
                            ctx.fillStyle = pal[lvl];
                            ctx.beginPath();
                            ctx.roundedRect(x, y, cSize, cSize, rad, rad);
                            ctx.fill();
                        }
                    }
                    ctx.globalAlpha = 1.0;
                }
            }

            // Hover tooltip + click to open profile OR set user
            MouseArea {
                id: heatmapMouse
                enabled: root.interactive && !root.editingUser
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: (e) => {
                    if (!root.hasUser) return;
                    const step = heatmapContainer.cellSize + heatmapContainer.gapPx;
                    const wIdx = Math.floor((e.x - heatmapContainer.originX) / step);
                    const dIdx = Math.floor((e.y - heatmapContainer.originY) / step);
                    const wks = root.visibleWeeks;
                    if (wIdx >= 0 && wIdx < wks.length && dIdx >= 0 && dIdx < (wks[wIdx]?.length || 0)) {
                        const day = wks[wIdx][dIdx];
                        if (day && day.date) {
                            const c = Number(day.count) || 0;
                            root.hoveredSummary = c + " contribution" + (c === 1 ? "" : "s") + " · " + day.date;
                            return;
                        }
                    }
                    root.hoveredSummary = "";
                }
                onExited: root.hoveredSummary = ""
                onClicked: {
                    if (!root.hasUser) {
                        root.openInlineEditor();
                    } else {
                        Quickshell.execDetached(["xdg-open", "https://github.com/" + root.user]);
                    }
                }
            }
        }

        // Tall 2x2 Stats Footer
        RowLayout {
            visible: root.isTall && !root.editingUser
            Layout.fillWidth: true
            spacing: WidgetStore.s(8)

            Repeater {
                model: [
                    { label: "YEAR TOTAL", value: root.hasUser ? String(root.total) : "486" },
                    { label: "STREAK", value: root.hasUser ? (root.streak + "d") : "14d" },
                    { label: "BEST DAY", value: root.hasUser ? String(root.bestDay) : "12" },
                    { label: "ACTIVE DAYS", value: root.hasUser ? String(root.activeDays) : "218" }
                ]

                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: WidgetStore.s(46)
                    radius: WidgetStore.s(12)
                    color: Qt.alpha(Theme.m3.surface_container_highest ?? "#ffffff", 0.55)

                    Column {
                        anchors.centerIn: parent
                        spacing: WidgetStore.s(1)

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.value
                            color: root.cardFg
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(14)
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: root.mutedFg
                            font.family: "Google Sans Flex"
                            font.pixelSize: WidgetStore.si(8)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.4
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }
}
