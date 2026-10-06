import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: notesRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true

    Keys.onEscapePressed: (event) => {
        if (notesRoot.isSaveDrawerOpen) {
            notesRoot.isSaveDrawerOpen = false;
        } else {
            root.collapseToIdle();
        }
        event.accepted = true;
    }

    // ==========================================
    // MATERIAL YOU (M3) THEME & STATE
    // ==========================================
    property int activeTab: 0 // 0: Notepad, 1: Tasks
    property bool isWideMode: false

    // Material 3 Dynamic Tonal Palette (Pixel Aesthetic)
    readonly property color m3Primary: Theme.accent ?? "#89b4fa"
    readonly property color m3OnPrimary: "#0a0e14"
    readonly property color m3PrimaryContainer: Qt.rgba(m3Primary.r, m3Primary.g, m3Primary.b, 0.18)
    readonly property color m3OnPrimaryContainer: m3Primary
    readonly property color m3SurfaceContainer: Qt.rgba(255, 255, 255, 0.05)
    readonly property color m3SurfaceContainerHigh: Qt.rgba(255, 255, 255, 0.09)
    readonly property color m3SurfaceContainerHighest: Qt.rgba(255, 255, 255, 0.14)
    readonly property color m3TextPrimary: "#f8fafc"
    readonly property color m3TextSecondary: Qt.rgba(255, 255, 255, 0.65)
    readonly property color m3TextMuted: Qt.rgba(255, 255, 255, 0.38)
    readonly property color m3Error: "#f87171"
    readonly property color m3ErrorContainer: Qt.rgba(248, 113, 113, 0.18)
    readonly property color m3Success: "#51cf66"
    readonly property var motionCurve: [0.05, 0.7, 0.1, 1, 1, 1]

    // Status Badges
    property bool isSaving: false
    property bool justSaved: false
    property bool justCopied: false
    property bool justExported: false

    // File export state
    property bool isSaveDrawerOpen: false
    property string exportPath: "~/Documents/notes.txt"
    readonly property string expandedExportPath: {
        if (exportPath.startsWith("~/")) {
            return Quickshell.env("HOME") + exportPath.substring(1);
        }
        return exportPath;
    }

    // Models
    ListModel { id: todoModel }
    property string scratchpadContent: ""

    readonly property int completedTodoCount: {
        var count = 0;
        for (var i = 0; i < todoModel.count; i++) {
            if (todoModel.get(i).done) count++;
        }
        return count;
    }

    function forceNotesFocus() {
        if (activeTab === 0) {
            notepadArea.forceActiveFocus();
        } else {
            newTodoInput.forceActiveFocus();
        }
    }

    onVisibleChanged: {
        if (visible) {
            loadProcess.running = true;
            Qt.callLater(forceNotesFocus);
        } else {
            notesRoot.isSaveDrawerOpen = false;
            notesRoot.justExported = false;
        }
    }

    Component.onCompleted: {
        loadProcess.running = true;
    }

    // ==========================================
    // BACKEND LOAD & SAVE PROCESSES
    // ==========================================
    Process {
        id: loadProcess
        running: false
        command: [(Quickshell.shellDir || Quickshell.configDir) + "/scripts/notes_store.py", "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var data = JSON.parse(this.text);
                    if (data.scratchpad !== undefined && !notepadArea.activeFocus) {
                        notesRoot.scratchpadContent = data.scratchpad;
                        notepadArea.text = data.scratchpad;
                    }
                    if (Array.isArray(data.todos)) {
                        todoModel.clear();
                        for (var i = 0; i < data.todos.length; i++) {
                            todoModel.append(data.todos[i]);
                        }
                    }
                } catch (e) {
                    console.log("Error loading notes JSON:", e);
                }
            }
        }
    }

    // Auto-save Notepad
    Timer {
        id: autoSaveDebounce
        interval: 350
        repeat: false
        onTriggered: {
            notesRoot.isSaving = true;
            var enc = encodeURIComponent(notepadArea.text);
            saveScratchProcess.command = [(Quickshell.shellDir || Quickshell.configDir) + "/scripts/notes_store.py", "save_scratchpad_enc", enc];
            saveScratchProcess.running = true;
        }
    }

    Process {
        id: saveScratchProcess
        running: false
        onRunningChanged: {
            if (!running) {
                notesRoot.isSaving = false;
                notesRoot.justSaved = true;
                savedBadgeTimer.restart();
            }
        }
    }

    // Save Todos
    function saveTodosToDisk() {
        var list = [];
        for (var i = 0; i < todoModel.count; i++) {
            var item = todoModel.get(i);
            list.push({
                "id": item.id,
                "text": item.text,
                "done": item.done
            });
        }
        var enc = encodeURIComponent(JSON.stringify(list));
        saveTodosProcess.command = [(Quickshell.shellDir || Quickshell.configDir) + "/scripts/notes_store.py", "save_todos_enc", enc];
        saveTodosProcess.running = true;
    }

    Process {
        id: saveTodosProcess
        running: false
        onRunningChanged: {
            if (!running) {
                notesRoot.justSaved = true;
                savedBadgeTimer.restart();
            }
        }
    }

    // Export As File (.txt or .md)
    function exportContentToDisk(targetPath) {
        var path = targetPath.trim();
        if (path === "") return;
        notesRoot.exportPath = path;

        var textContent = "";
        if (notesRoot.activeTab === 0) {
            textContent = notepadArea.text;
        } else {
            var lines = ["# Tasks & Checklist\n"];
            for (var i = 0; i < todoModel.count; i++) {
                var item = todoModel.get(i);
                lines.push("- [" + (item.done ? "x" : " ") + "] " + item.text);
            }
            textContent = lines.join("\n");
        }

        var enc = encodeURIComponent(textContent);
        exportProcess.targetPath = path;
        exportProcess.command = [(Quickshell.shellDir || Quickshell.configDir) + "/scripts/notes_store.py", "export_txt", path, enc];
        exportProcess.running = true;
    }

    Process {
        id: exportProcess
        running: false
        property string targetPath: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim();
                if (out.startsWith("OK:")) {
                    notesRoot.justExported = true;
                    notesRoot.isSaveDrawerOpen = false;
                    savedBadgeTimer.restart();
                    Quickshell.execDetached(["notify-send", "-a", "Quickshell Notes", "Saved Successfully", "Exported to " + exportProcess.targetPath]);
                }
            }
        }
    }

    // System native file picker (kdialog)
    Process {
        id: fileDialogProcess
        running: false
        command: ["kdialog", "--getsavefilename", notesRoot.expandedExportPath, "Text files (*.txt);;Markdown files (*.md);;All files (*)"]
        stdout: StdioCollector {
            onStreamFinished: {
                var chosen = this.text.trim();
                if (chosen !== "") {
                    exportPathField.text = chosen;
                    notesRoot.exportContentToDisk(chosen);
                }
            }
        }
    }

    Timer {
        id: savedBadgeTimer
        interval: 2200
        repeat: false
        onTriggered: {
            notesRoot.justSaved = false;
            notesRoot.justCopied = false;
            notesRoot.justExported = false;
        }
    }

    function copyActiveContent() {
        var content = "";
        if (notesRoot.activeTab === 0) {
            content = notepadArea.text;
        } else {
            var lines = [];
            for (var i = 0; i < todoModel.count; i++) {
                var item = todoModel.get(i);
                lines.push("- [" + (item.done ? "x" : " ") + "] " + item.text);
            }
            content = lines.join("\n");
        }
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(content) + " | wl-copy"]);
        notesRoot.justCopied = true;
        savedBadgeTimer.restart();
    }

    function clearNotepad() {
        notepadArea.text = "";
        notesRoot.scratchpadContent = "";
        autoSaveDebounce.restart();
    }

    // Task Actions
    function addNewTodo(txt) {
        var clean = txt.trim();
        if (clean === "") return;
        todoModel.append({
            "id": Date.now(),
            "text": clean,
            "done": false
        });
        newTodoInput.text = "";
        saveTodosToDisk();
        todoListView.positionViewAtEnd();
    }

    function toggleTodoDone(idx) {
        if (idx >= 0 && idx < todoModel.count) {
            var item = todoModel.get(idx);
            item.done = !item.done;
            saveTodosToDisk();
        }
    }

    function removeTodo(idx) {
        if (idx >= 0 && idx < todoModel.count) {
            todoModel.remove(idx);
            saveTodosToDisk();
        }
    }

    function clearCompletedTodos() {
        for (var i = todoModel.count - 1; i >= 0; i--) {
            if (todoModel.get(i).done) {
                todoModel.remove(i);
            }
        }
        saveTodosToDisk();
    }

    // ==========================================
    // UI LAYOUT
    // ==========================================
    Item {
        id: mainContainer
        anchors.fill: parent

        // ================= 1. MATERIAL YOU TOP HEADER =================
        Item {
            id: headerBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 38

            RowLayout {
                anchors.fill: parent
                spacing: 8

                // Material Circular Back Button (Pixel style)
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: backMouse.containsMouse ? notesRoot.m3SurfaceContainerHighest : notesRoot.m3SurfaceContainer
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: notesRoot.m3TextPrimary
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.switchMode("utility", true)
                    }
                }

                // ================= PIXEL MATERIAL 3 SEGMENTED SWITCH =================
                Rectangle {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 236
                    radius: 17
                    color: notesRoot.m3SurfaceContainer
                    clip: true

                    // Sliding Pill Indicator
                    Rectangle {
                        x: notesRoot.activeTab === 0 ? 3 : (parent.width / 2) + 1
                        y: 3
                        width: (parent.width / 2) - 4
                        height: parent.height - 6
                        radius: 14
                        color: notesRoot.m3Primary
                        Behavior on x {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: notesRoot.motionCurve
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent

                        // Segment 0: Notepad
                        Item {
                            width: parent.width / 2
                            height: parent.height

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: "󰠮"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    color: notesRoot.activeTab === 0 ? notesRoot.m3OnPrimary : notesRoot.m3TextSecondary
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                Text {
                                    text: "Notepad"
                                    font.family: "Inter"
                                    font.pixelSize: 12
                                    font.weight: notesRoot.activeTab === 0 ? Font.DemiBold : Font.Normal
                                    color: notesRoot.activeTab === 0 ? notesRoot.m3OnPrimary : notesRoot.m3TextSecondary
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    notesRoot.activeTab = 0;
                                    notepadArea.forceActiveFocus();
                                }
                            }
                        }

                        // Segment 1: Todo List
                        Item {
                            width: parent.width / 2
                            height: parent.height

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: "󰄲"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    color: notesRoot.activeTab === 1 ? notesRoot.m3OnPrimary : notesRoot.m3TextSecondary
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                Text {
                                    text: "Tasks (" + todoModel.count + ")"
                                    font.family: "Inter"
                                    font.pixelSize: 12
                                    font.weight: notesRoot.activeTab === 1 ? Font.DemiBold : Font.Normal
                                    color: notesRoot.activeTab === 1 ? notesRoot.m3OnPrimary : notesRoot.m3TextSecondary
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    notesRoot.activeTab = 1;
                                    newTodoInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // ================= MATERIAL YOU ACTION PILLS =================
                // 1. Copy Action Pill
                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: notesRoot.justCopied ? 74 : 64
                    radius: 15
                    color: notesRoot.justCopied
                        ? Qt.rgba(0.32, 0.81, 0.40, 0.22)
                        : (copyMouse.containsMouse ? notesRoot.m3SurfaceContainerHighest : notesRoot.m3SurfaceContainer)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: notesRoot.justCopied ? "✓" : "󰆏"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: notesRoot.justCopied ? notesRoot.m3Success : notesRoot.m3TextPrimary
                        }
                        Text {
                            text: notesRoot.justCopied ? "Copied" : "Copy"
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: notesRoot.justCopied ? notesRoot.m3Success : notesRoot.m3TextPrimary
                        }
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: notesRoot.copyActiveContent()
                    }
                }

                // 2. Export / Save As Action Pill
                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: notesRoot.justExported ? 82 : 74
                    radius: 15
                    color: notesRoot.justExported
                        ? Qt.rgba(0.32, 0.81, 0.40, 0.22)
                        : (notesRoot.isSaveDrawerOpen ? notesRoot.m3PrimaryContainer : (exportMouse.containsMouse ? notesRoot.m3SurfaceContainerHighest : notesRoot.m3SurfaceContainer))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: notesRoot.justExported ? "✓" : "󰈔"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: notesRoot.justExported ? notesRoot.m3Success : (notesRoot.isSaveDrawerOpen ? notesRoot.m3Primary : notesRoot.m3TextPrimary)
                        }
                        Text {
                            text: notesRoot.justExported ? "Saved" : "Export"
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: notesRoot.justExported ? notesRoot.m3Success : (notesRoot.isSaveDrawerOpen ? notesRoot.m3Primary : notesRoot.m3TextPrimary)
                        }
                    }

                    MouseArea {
                        id: exportMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            notesRoot.isSaveDrawerOpen = !notesRoot.isSaveDrawerOpen;
                            if (notesRoot.isSaveDrawerOpen) exportPathField.forceActiveFocus();
                        }
                    }
                }

                // 3. Clear Action Pill (Contextual)
                Rectangle {
                    visible: (notesRoot.activeTab === 0 && notepadArea.text.trim() !== "") || (notesRoot.activeTab === 1 && notesRoot.completedTodoCount > 0)
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: notesRoot.activeTab === 0 ? 62 : 88
                    radius: 15
                    color: clearMouse.containsMouse ? notesRoot.m3ErrorContainer : notesRoot.m3SurfaceContainer
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰅖"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: clearMouse.containsMouse ? notesRoot.m3Error : notesRoot.m3TextSecondary
                        }
                        Text {
                            text: notesRoot.activeTab === 0 ? "Clear" : "Clear Done"
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: clearMouse.containsMouse ? notesRoot.m3Error : notesRoot.m3TextSecondary
                        }
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (notesRoot.activeTab === 0) {
                                notesRoot.clearNotepad();
                            } else {
                                notesRoot.clearCompletedTodos();
                            }
                        }
                    }
                }

                // 4. Wide Mode Pill Button
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 30
                    radius: 15
                    color: notesRoot.isWideMode ? notesRoot.m3PrimaryContainer : (wideMouse.containsMouse ? notesRoot.m3SurfaceContainerHighest : notesRoot.m3SurfaceContainer)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: notesRoot.isWideMode ? "󰆦" : "󰆤"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: notesRoot.isWideMode ? notesRoot.m3Primary : notesRoot.m3TextPrimary
                    }

                    MouseArea {
                        id: wideMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: notesRoot.isWideMode = !notesRoot.isWideMode
                    }
                }
            }
        }

        // ================= 2. SLIDE-DOWN EXPORT DRAWER =================
        Rectangle {
            id: saveDrawer
            anchors.top: headerBar.bottom
            anchors.topMargin: notesRoot.isSaveDrawerOpen ? 6 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            height: notesRoot.isSaveDrawerOpen ? 38 : 0
            visible: height > 0
            clip: true
            radius: 19
            color: notesRoot.m3SurfaceContainerHigh
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 8

                Text {
                    text: "󰈔"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: notesRoot.m3Primary
                }

                TextField {
                    id: exportPathField
                    Layout.fillWidth: true
                    text: notesRoot.exportPath
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: notesRoot.m3TextPrimary
                    placeholderText: "Save path e.g. ~/Documents/notes.txt..."
                    placeholderTextColor: notesRoot.m3TextMuted
                    background: Item {}

                    onAccepted: notesRoot.exportContentToDisk(text)
                    Keys.onEscapePressed: (event) => {
                        notesRoot.isSaveDrawerOpen = false;
                        event.accepted = true;
                    }
                }

                // Browse Button
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: 68
                    radius: 13
                    color: browseMouse.containsMouse ? notesRoot.m3SurfaceContainerHighest : notesRoot.m3SurfaceContainer

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "📁"; font.pixelSize: 10 }
                        Text {
                            text: "Browse"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: notesRoot.m3TextPrimary
                        }
                    }

                    MouseArea {
                        id: browseMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (!fileDialogProcess.running) fileDialogProcess.running = true;
                        }
                    }
                }

                // Save Confirm Button
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: 58
                    radius: 13
                    color: saveConfirmMouse.containsMouse ? notesRoot.m3Primary : notesRoot.m3PrimaryContainer

                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: saveConfirmMouse.containsMouse ? notesRoot.m3OnPrimary : notesRoot.m3Primary
                    }

                    MouseArea {
                        id: saveConfirmMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: notesRoot.exportContentToDisk(exportPathField.text)
                    }
                }

                // Close Drawer Button
                Rectangle {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 11
                    color: closeDrawerMouse.containsMouse ? notesRoot.m3SurfaceContainerHighest : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 11
                        color: notesRoot.m3TextSecondary
                    }

                    MouseArea {
                        id: closeDrawerMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: notesRoot.isSaveDrawerOpen = false
                    }
                }
            }
        }

        // ================= 3. FOOTER STATUS BAR =================
        Item {
            id: footerBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24

            // Status Bar for Notepad
            RowLayout {
                anchors.fill: parent
                visible: notesRoot.activeTab === 0
                spacing: 8

                Text {
                    text: {
                        var chars = notepadArea.text.length;
                        var words = notepadArea.text.trim() === "" ? 0 : notepadArea.text.trim().split(/\s+/).length;
                        var lines = notepadArea.text === "" ? 0 : notepadArea.text.split("\n").length;
                        return words + " words · " + chars + " characters · " + lines + " lines";
                    }
                    font.family: "Inter"
                    font.pixelSize: 10
                    color: notesRoot.m3TextMuted
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 4
                    visible: notesRoot.justSaved || notesRoot.isSaving || notesRoot.justExported
                    Text {
                        text: notesRoot.justExported ? "✓" : (notesRoot.isSaving ? "󰔛" : "󰄬")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: notesRoot.isSaving ? notesRoot.m3Primary : notesRoot.m3Success
                    }
                    Text {
                        text: {
                            if (notesRoot.justExported) return "Saved to " + notesRoot.exportPath;
                            if (notesRoot.isSaving) return "Saving...";
                            return "Auto-saved";
                        }
                        font.family: "Inter"
                        font.pixelSize: 10
                        color: notesRoot.isSaving ? notesRoot.m3Primary : notesRoot.m3Success
                    }
                }
            }

            // Status Bar for Todo Tasks
            RowLayout {
                anchors.fill: parent
                visible: notesRoot.activeTab === 1
                spacing: 10

                Text {
                    text: notesRoot.completedTodoCount + " of " + todoModel.count + " completed (" + (todoModel.count > 0 ? Math.round((notesRoot.completedTodoCount / todoModel.count) * 100) : 0) + "%)"
                    font.family: "Inter"
                    font.pixelSize: 10
                    color: notesRoot.m3TextMuted
                }

                Item { Layout.fillWidth: true }

                // Material 3 Progress Bar Capsule
                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 6
                    radius: 3
                    color: notesRoot.m3SurfaceContainerHighest

                    Rectangle {
                        height: parent.height
                        radius: 3
                        width: parent.width * (todoModel.count > 0 ? (notesRoot.completedTodoCount / todoModel.count) : 0)
                        color: notesRoot.completedTodoCount === todoModel.count ? notesRoot.m3Success : notesRoot.m3Primary
                        Behavior on width { NumberAnimation { duration: 180 } }
                    }
                }
            }
        }

        // ================= 4. BODY CONTENT (STACKED NOTEPAD & TASKS) =================
        StackLayout {
            id: contentStack
            anchors.top: notesRoot.isSaveDrawerOpen ? saveDrawer.bottom : headerBar.bottom
            anchors.topMargin: 8
            anchors.bottom: footerBar.top
            anchors.bottomMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            currentIndex: notesRoot.activeTab

            // ---------------- TAB 0: MATERIAL YOU NOTEPAD ----------------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: notesRoot.m3SurfaceContainer

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 14
                        clip: true

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 5
                            contentItem: Rectangle {
                                radius: 3
                                color: notesRoot.m3TextMuted
                                opacity: 0.35
                            }
                        }

                        TextArea {
                            id: notepadArea
                            wrapMode: TextEdit.Wrap
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: notesRoot.m3TextPrimary
                            placeholderText: "Jot notes, scratch ideas, terminal snippets, or thoughts here...\nAuto-saved automatically in real time."
                            placeholderTextColor: notesRoot.m3TextMuted
                            selectByMouse: true
                            background: Item {}

                            onTextChanged: {
                                notesRoot.scratchpadContent = text;
                                autoSaveDebounce.restart();
                            }

                            Keys.onEscapePressed: root.collapseToIdle()

                            // Ctrl+S shortcut to export
                            Keys.onPressed: (event) => {
                                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                                    notesRoot.isSaveDrawerOpen = true;
                                    exportPathField.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- TAB 1: MATERIAL YOU TODO TASKS ----------------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Material 3 Add Task Input Capsule (Pixel Search Pill style)
                    Rectangle {
                        id: addTodoBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 21
                        color: notesRoot.m3SurfaceContainer
                        border.width: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: "󰄱"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                color: notesRoot.m3Primary
                            }

                            TextField {
                                id: newTodoInput
                                Layout.fillWidth: true
                                font.family: "Inter"
                                font.pixelSize: 12
                                color: notesRoot.m3TextPrimary
                                placeholderText: "Add a task (Press Enter to add)..."
                                placeholderTextColor: notesRoot.m3TextMuted
                                background: Item {}

                                onAccepted: notesRoot.addNewTodo(text)
                                Keys.onEscapePressed: root.collapseToIdle()
                            }

                            // Pixel FAB Button (+)
                            Rectangle {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                radius: 15
                                color: addBtnMouse.containsMouse ? notesRoot.m3PrimaryContainer : notesRoot.m3Primary
                                scale: addBtnMouse.pressed ? 0.92 : (addBtnMouse.containsMouse ? 1.05 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: addBtnMouse.containsMouse ? notesRoot.m3Primary : notesRoot.m3OnPrimary
                                }

                                MouseArea {
                                    id: addBtnMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: notesRoot.addNewTodo(newTodoInput.text)
                                }
                            }
                        }
                    }

                    // Task Cards List
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: todoListView
                            anchors.fill: parent
                            clip: true
                            spacing: 6
                            model: todoModel

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                                width: 5
                                contentItem: Rectangle {
                                    radius: 3
                                    color: notesRoot.m3TextMuted
                                    opacity: 0.35
                                }
                            }

                            add: Transition {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 180; easing.type: Easing.OutBack }
                            }
                            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
                            displaced: Transition { NumberAnimation { property: "y"; duration: 160; easing.type: Easing.OutCubic } }

                            // Material You Card Delegate
                            delegate: Rectangle {
                                id: todoDelegate
                                width: ListView.view.width
                                height: 44
                                radius: 16
                                color: itemMouse.containsMouse ? notesRoot.m3SurfaceContainerHigh : notesRoot.m3SurfaceContainer
                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    // Material 3 Squircle Checkbox
                                    Rectangle {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        radius: 7
                                        color: done ? notesRoot.m3Primary : "transparent"
                                        border.width: done ? 0 : 2
                                        border.color: done ? "transparent" : notesRoot.m3TextSecondary
                                        scale: checkMouse.pressed ? 0.88 : 1.0
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: notesRoot.m3OnPrimary
                                            visible: done
                                        }

                                        MouseArea {
                                            id: checkMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: notesRoot.toggleTodoDone(index)
                                        }
                                    }

                                    // Task Text
                                    Text {
                                        Layout.fillWidth: true
                                        text: model.text
                                        font.family: "Inter"
                                        font.pixelSize: 12
                                        font.weight: done ? Font.Normal : Font.Medium
                                        font.strikeout: done
                                        color: done ? notesRoot.m3TextMuted : notesRoot.m3TextPrimary
                                        opacity: done ? 0.6 : 1.0
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                        Behavior on opacity { NumberAnimation { duration: 140 } }
                                    }

                                    // Pixel Circle Delete Button (reveals on hover)
                                    Rectangle {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        radius: 12
                                        color: delMouse.containsMouse ? notesRoot.m3ErrorContainer : "transparent"
                                        opacity: itemMouse.containsMouse ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            font.pixelSize: 11
                                            color: delMouse.containsMouse ? notesRoot.m3Error : notesRoot.m3TextMuted
                                        }

                                        MouseArea {
                                            id: delMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: notesRoot.removeTodo(index)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    z: -1
                                    onClicked: notesRoot.toggleTodoDone(index)
                                }
                            }
                        }

                        // Empty State Graphic
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: todoModel.count === 0

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 44
                                height: 44
                                radius: 22
                                color: notesRoot.m3PrimaryContainer

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰄵"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 22
                                    color: notesRoot.m3Primary
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "All caught up!"
                                font.family: "Inter"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: notesRoot.m3TextPrimary
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Add a task above to plan your day."
                                font.family: "Inter"
                                font.pixelSize: 11
                                color: notesRoot.m3TextMuted
                            }
                        }
                    }
                }
            }
        }
    }
}
