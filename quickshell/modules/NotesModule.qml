import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

FocusScope {
    id: notes
    anchors.fill: parent
    focus: true

    readonly property var store: root.notepadStore
    property int activeTab: 0 // 0: Scratchpad, 1: Tasks
    property bool isWideMode: false
    property bool isPinned: false
    property bool exportOpen: false
    property bool confirmingClear: false
    property string exportPath: "~/Documents/notes.txt"
    property string feedback: ""
    property bool actionFailed: false

    // Word and character count statistics
    readonly property int charCount: editor ? editor.length : 0
    readonly property int wordCount: {
        if (!editor || !editor.text) return 0;
        var t = editor.text.trim();
        return t.length === 0 ? 0 : t.split(/\s+/).length;
    }

    function forceNotesFocus() {
        if (exportOpen) exportField.forceActiveFocus();
        else if (activeTab === 0) editor.forceActiveFocus();
        else newTask.forceActiveFocus();
    }

    function showExport() {
        exportOpen = true;
        Qt.callLater(forceNotesFocus);
    }

    function closeExport() {
        exportOpen = false;
        forceNotesFocus();
    }

    function close() {
        isPinned = false;
        root.collapseToIdle();
    }

    function submitTask() {
        if (store.addTask(newTask.text)) {
            newTask.clear();
            taskList.positionViewAtEnd();
        }
    }

    function runAction(action, path = "") {
        if (!store.loaded || transfer.running) return;
        const target = path.trim();
        if (action === "export-stdin") {
            if (target === "") return;
            exportPath = target;
        }
        feedback = "";
        actionFailed = false;
        transfer.action = action;
        transfer.payload = {
            path: target,
            text: activeTab === 0 ? editor.text : store.textForTasks(action === "export-stdin")
        };
        transfer.command = ["python3", store.script, action];
        transfer.running = true;
    }

    Component.onCompleted: store.ensureLoaded()

    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode === "notes") notes.store.ensureLoaded();
            else {
                notes.store.flush();
                notes.exportOpen = false;
                notes.confirmingClear = false;
                notes.isPinned = false;
            }
        }
    }

    onActiveTabChanged: {
        confirmingClear = false;
        feedback = "";
        Qt.callLater(forceNotesFocus);
    }

    Keys.onEscapePressed: event => {
        if (confirmingClear) confirmingClear = false;
        else if (exportOpen) closeExport();
        else close();
        event.accepted = true;
    }

    Shortcut {
        sequence: "Ctrl+S"
        enabled: root.activeMode === "notes" && notes.store.loaded
        onActivated: notes.showExport()
    }

    FileDialog {
        id: picker
        title: "Export " + (notes.activeTab === 0 ? "note" : "tasks")
        fileMode: FileDialog.SaveFile
        nameFilters: ["Text files (*.txt)", "Markdown files (*.md)", "All files (*)"]
        defaultSuffix: selectedNameFilter.index === 1 ? "md" : "txt"
        currentFolder: "file://" + encodeURI((Quickshell.env("HOME") || "") + "/Documents")
        onAccepted: {
            const url = selectedFile.toString();
            if (url.startsWith("file://")) notes.runAction("export-stdin", decodeURIComponent(url.slice(7)));
        }
    }

    Process {
        id: transfer
        property string action: ""
        property var payload: null
        stdinEnabled: true
        onStarted: {
            write(JSON.stringify(payload) + "\n");
            payload = null;
        }
        onExited: code => {
            notes.actionFailed = code !== 0;
            notes.feedback = code === 0 ? (action === "copy-stdin" ? "Copied" : "Exported")
                : (action === "copy-stdin" ? "Couldn't copy to clipboard." : "Couldn't export to that path.");
            if (code === 0 && action === "export-stdin") notes.closeExport();
            feedbackTimer.restart();
        }
    }

    Timer {
        id: feedbackTimer
        interval: 3600
        onTriggered: notes.feedback = ""
    }

    // ========================================================
    // MAIN UI LAYOUT
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 9

        // 1. M3 Top App Bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Back / Close Button
            IrisIconButton {
                buttonSize: 30
                buttonRadius: 15
                flat: true
                icon: "arrow_back"
                iconSize: 16
                iconColor: Theme.alpha(Theme.text, 0.72)
                Accessible.role: Accessible.Button
                Accessible.name: "Close Notes"
                onClicked: notes.close()
            }

            // Title & Live Status
            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: "Notes"
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: Theme.text
                    renderType: Text.NativeRendering
                }

                Text {
                    text: {
                        if (notes.store.error) return notes.store.error;
                        if (notes.feedback) return notes.feedback;
                        if (!notes.store.loaded) return "Loading notes…";
                        if (notes.store.saving) return "Saving…";
                        return "Auto-saved locally";
                    }
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: {
                        if (notes.store.error || (notes.feedback && notes.actionFailed)) return Theme.error;
                        if (notes.feedback) return Theme.success;
                        if (notes.store.saving) return Theme.accent;
                        return Theme.alpha(Theme.text, 0.45);
                    }
                    renderType: Text.NativeRendering
                }
            }

            Item { Layout.fillWidth: true }

            // M3 Action Toolbar
            RowLayout {
                spacing: 4

                // Copy Action
                M3IconButton {
                    glyph: "content_copy"
                    tooltip: "Copy " + (notes.activeTab === 0 ? "note" : "tasks")
                    enabled: notes.store.loaded && !transfer.running
                    onClicked: notes.runAction("copy-stdin")
                }

                // Export Action
                M3IconButton {
                    glyph: "download"
                    tooltip: "Export note (Ctrl+S)"
                    enabled: notes.store.loaded && !transfer.running
                    active: notes.exportOpen
                    onClicked: notes.showExport()
                }

                // Clear Note / Clear Done (with confirmation pill)
                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: notes.confirmingClear ? confirmClearRow.implicitWidth + 14 : 30
                    radius: 15
                    color: notes.confirmingClear ? Theme.alpha(Theme.error, 0.20) : "transparent"
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        id: confirmClearRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: notes.confirmingClear ? "warning" : "delete_sweep"
                            iconSize: 15
                            color: notes.confirmingClear ? Theme.error : Theme.alpha(Theme.text, 0.70)
                        }

                        Text {
                            visible: notes.confirmingClear
                            text: "Clear?"
                            font.family: Theme.fontFamilyBody
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Theme.error
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: notes.store.loaded && (notes.activeTab === 0 ? editor.length > 0 : notes.store.completedCount > 0)
                        onClicked: {
                            if (!notes.confirmingClear) {
                                notes.confirmingClear = true;
                                return;
                            }
                            if (notes.activeTab === 0) editor.clear();
                            else notes.store.clearCompleted();
                            notes.confirmingClear = false;
                            notes.forceNotesFocus();
                        }
                    }
                }

                // Pin Panel Toggle
                M3IconButton {
                    glyph: "push_pin"
                    tooltip: notes.isPinned ? "Unpin (close on click away)" : "Pin (stay open)"
                    active: notes.isPinned
                    onClicked: notes.isPinned = !notes.isPinned
                }

                // Wide / Narrow Mode Toggle
                M3IconButton {
                    glyph: notes.isWideMode ? "close_fullscreen" : "open_in_full"
                    tooltip: notes.isWideMode ? "Standard width" : "Wide view"
                    active: notes.isWideMode
                    onClicked: notes.isWideMode = !notes.isWideMode
                }
            }
        }

        // 2. M3 Segmented Navigation & Stats Chips Row
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 6

            // Segmented Chips Container
            Rectangle {
                Layout.preferredHeight: 34
                Layout.preferredWidth: tabsRow.implicitWidth + 6
                radius: 17
                color: Theme.alpha(Theme.text, 0.05)

                RowLayout {
                    id: tabsRow
                    anchors.centerIn: parent
                    spacing: 2

                    // Scratchpad Chip
                    M3TabChip {
                        text: "Scratchpad"
                        glyph: "edit_note"
                        selected: notes.activeTab === 0
                        onClicked: notes.activeTab = 0
                    }

                    // Tasks Chip with Count Badge
                    M3TabChip {
                        text: "Tasks"
                        glyph: "checklist"
                        badgeCount: notes.store.tasks ? notes.store.tasks.count : 0
                        selected: notes.activeTab === 1
                        onClicked: notes.activeTab = 1
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // When on Tasks: Progress Bar and Progress Pill
            RowLayout {
                visible: notes.activeTab === 1 && notes.store.tasks && notes.store.tasks.count > 0
                spacing: 8

                Text {
                    text: notes.store.completedCount + " of " + notes.store.tasks.count + " completed"
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Theme.alpha(Theme.text, 0.60)
                    renderType: Text.NativeRendering
                }

                // M3 Linear Progress Bar
                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.alpha(Theme.text, 0.10)

                    Rectangle {
                        height: parent.height
                        radius: 3
                        color: Theme.accent
                        width: Math.max(0, Math.min(parent.width, parent.width * (notes.store.completedCount / Math.max(1, notes.store.tasks.count))))
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // 3. Inline Export Card (collapsible)
        Rectangle {
            id: exportCard
            visible: notes.exportOpen
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 42 : 0
            radius: 12
            color: Theme.alpha(Theme.text, 0.06)
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                MaterialSymbol {
                    text: "drive_file_move"
                    iconSize: 16
                    color: Theme.accent
                }

                TextField {
                    id: exportField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    text: notes.exportPath
                    placeholderText: "Export file path (e.g. ~/Documents/notes.txt)"
                    selectByMouse: true
                    color: Theme.text
                    placeholderTextColor: Theme.alpha(Theme.text, 0.40)
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 12
                    background: Rectangle {
                        color: Theme.alpha(Theme.text, 0.06)
                        radius: 8
                    }
                    onAccepted: notes.runAction("export-stdin", text)
                }

                Button {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: browseRow.implicitWidth + 14
                    hoverEnabled: true
                    onClicked: picker.open()
                    background: Rectangle {
                        radius: 8
                        color: parent.hovered ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.text, 0.06)
                    }
                    contentItem: RowLayout {
                        id: browseRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol { text: "folder_open"; iconSize: 14; color: Theme.alpha(Theme.text, 0.80) }
                        Text { text: "Browse"; font.pixelSize: 11; font.weight: Font.Medium; color: Theme.text }
                    }
                }

                Button {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: saveRow.implicitWidth + 16
                    hoverEnabled: true
                    enabled: !transfer.running && exportField.text.trim() !== ""
                    onClicked: notes.runAction("export-stdin", exportField.text)
                    background: Rectangle {
                        radius: 8
                        color: parent.enabled ? Theme.accent : Theme.alpha(Theme.accent, 0.35)
                    }
                    contentItem: RowLayout {
                        id: saveRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol { text: "save"; iconSize: 14; color: Theme.colors.bg ?? "#12141c" }
                        Text { text: "Save"; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.colors.bg ?? "#12141c" }
                    }
                }

                IrisIconButton {
                    buttonSize: 26
                    buttonRadius: 13
                    flat: true
                    icon: "close"
                    iconSize: 14
                    iconColor: Theme.alpha(Theme.text, 0.60)
                    onClicked: notes.closeExport()
                }
            }
        }

        // 4. Main Content Surface (StackLayout)
        StackLayout {
            currentIndex: notes.activeTab
            Layout.fillWidth: true
            Layout.fillHeight: true

            // === TAB 0: M3 GOOGLE KEEP STYLE SCRATCHPAD ===
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: Theme.alpha(Theme.colors.card_bg || Theme.text, 0.45)

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 6
                        contentItem: Rectangle {
                            radius: 3
                            color: Theme.alpha(Theme.text, 0.25)
                        }
                    }

                    TextArea {
                        id: editor
                        text: notes.store.scratchpad
                        readOnly: !notes.store.loaded
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        leftPadding: 16
                        rightPadding: 16
                        topPadding: 14
                        bottomPadding: 14
                        textFormat: TextEdit.PlainText
                        placeholderText: notes.store.loaded ? "Take a note…" : "Loading note…"
                        placeholderTextColor: Theme.alpha(Theme.text, 0.35)
                        font.family: Theme.fontFamilyBody
                        font.pixelSize: 14
                        color: Theme.text
                        selectionColor: Theme.alpha(Theme.accent, 0.35)
                        selectedTextColor: Theme.text
                        background: null
                        renderType: Text.NativeRendering
                        onTextChanged: notes.store.edit(text)
                    }
                }
            }

            // === TAB 1: M3 ANDROID TASKS / CHECKLIST ===
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Task Input Pill Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 20
                    color: newTask.activeFocus ? Theme.alpha(Theme.text, 0.09) : Theme.alpha(Theme.text, 0.05)
                    Behavior on color { ColorAnimation { duration: 140 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        MaterialSymbol {
                            text: "add_task"
                            iconSize: 16
                            color: newTask.activeFocus ? Theme.accent : Theme.alpha(Theme.text, 0.50)
                        }

                        TextField {
                            id: newTask
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            placeholderText: "Add a task… (Press Enter)"
                            selectByMouse: true
                            enabled: notes.store.loaded
                            color: Theme.text
                            placeholderTextColor: Theme.alpha(Theme.text, 0.38)
                            font.family: Theme.fontFamilyBody
                            font.pixelSize: 12
                            background: Item {}
                            renderType: Text.NativeRendering
                            onAccepted: notes.submitTask()
                        }

                        // Add Button Pill
                        Rectangle {
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: addBtnText.implicitWidth + 16
                            radius: 14
                            visible: newTask.text.trim().length > 0
                            color: Theme.accent

                            Text {
                                id: addBtnText
                                anchors.centerIn: parent
                                text: "Add"
                                font.family: Theme.fontFamilyBody
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Theme.colors.bg ?? "#12141c"
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notes.submitTask()
                            }
                        }
                    }
                }

                // Tasks List Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: Theme.alpha(Theme.colors.card_bg || Theme.text, 0.45)

                    ListView {
                        id: taskList
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        spacing: 3
                        boundsBehavior: Flickable.StopAtBounds
                        model: notes.store.tasks
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6
                            contentItem: Rectangle {
                                radius: 3
                                color: Theme.alpha(Theme.text, 0.25)
                            }
                        }

                        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 } }
                        displaced: Transition { NumberAnimation { property: "y"; duration: 160; easing.type: Easing.OutCubic } }

                        delegate: Rectangle {
                            id: task
                            required property int index
                            required property string text
                            required property bool done
                            width: taskList.width
                            height: 40
                            radius: 10
                            color: taskHover.hovered ? Theme.alpha(Theme.text, 0.05) : "transparent"
                            Behavior on color { ColorAnimation { duration: 110 } }

                            HoverHandler { id: taskHover }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10

                                // M3 Checkbox
                                Rectangle {
                                    id: chkBox
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    radius: 6
                                    color: task.done ? Theme.accent : Theme.alpha(Theme.text, 0.12)
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        visible: task.done
                                        text: "check"
                                        iconSize: 14
                                        color: Theme.colors.bg ?? "#12141c"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notes.store.toggleTask(task.index)
                                    }
                                }

                                // Task Description
                                Text {
                                    Layout.fillWidth: true
                                    text: task.text
                                    textFormat: Text.PlainText
                                    color: task.done ? Theme.alpha(Theme.text, 0.40) : Theme.text
                                    font.family: Theme.fontFamilyBody
                                    font.pixelSize: 12
                                    font.strikeout: task.done
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notes.store.toggleTask(task.index)
                                    }
                                }

                                // Delete Button (visible on hover)
                                IrisIconButton {
                                    buttonSize: 26
                                    buttonRadius: 13
                                    flat: true
                                    icon: "delete_outline"
                                    iconSize: 14
                                    iconColor: taskHover.hovered ? Theme.alpha(Theme.error, 0.85) : "transparent"
                                    onClicked: notes.store.removeTask(task.index)
                                }
                            }
                        }
                    }

                    // Empty State Card
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: notes.store.loaded && notes.store.tasks.count === 0
                        spacing: 8

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "checklist_rtl"
                            iconSize: 38
                            color: Theme.alpha(Theme.accent, 0.40)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "All caught up!"
                            font.family: Theme.fontFamilyBody
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.alpha(Theme.text, 0.70)
                            renderType: Text.NativeRendering
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Add a task above to build your checklist."
                            font.family: Theme.fontFamilyBody
                            font.pixelSize: 11
                            color: Theme.alpha(Theme.text, 0.40)
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }

        // 5. Professional M3 Footer Status Bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            spacing: 8

            Text {
                text: notes.activeTab === 0
                    ? notes.charCount + (notes.charCount === 1 ? " character" : " characters") + (notes.wordCount > 0 ? " • " + notes.wordCount + (notes.wordCount === 1 ? " word" : " words") : "")
                    : notes.store.completedCount + " of " + notes.store.tasks.count + " completed"
                font.family: Theme.fontFamilyBody
                font.pixelSize: 11
                color: Theme.alpha(Theme.text, 0.45)
                renderType: Text.NativeRendering
            }

            Item { Layout.fillWidth: true }

            Text {
                text: notes.store.error || notes.feedback
                    || (!notes.store.loaded ? "Loading…" : notes.store.saving ? "Saving…" : "Saved locally")
                font.family: Theme.fontFamilyBody
                font.pixelSize: 11
                color: notes.store.error || (notes.feedback && notes.actionFailed) ? Theme.error
                    : notes.feedback ? Theme.success
                    : notes.store.saving ? Theme.accent
                    : Theme.alpha(Theme.text, 0.45)
                renderType: Text.NativeRendering
            }
        }
    }

    // ========================================================
    // REUSABLE M3 SUBCOMPONENTS
    // ========================================================
    component M3TabChip: Rectangle {
        id: chip
        required property string text
        required property string glyph
        property int badgeCount: -1
        required property bool selected
        signal clicked()

        Layout.preferredHeight: 28
        Layout.preferredWidth: chipRow.implicitWidth + 18
        radius: 14
        color: chip.selected ? Theme.alpha(Theme.accent, 0.22) : (chipHover.hovered ? Theme.alpha(Theme.text, 0.08) : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler { id: chipHover }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                text: chip.glyph
                iconSize: 15
                color: chip.selected ? Theme.accent : Theme.alpha(Theme.text, 0.65)
            }

            Text {
                text: chip.text
                font.family: Theme.fontFamilyBody
                font.pixelSize: 12
                font.weight: chip.selected ? Font.Bold : Font.Medium
                color: chip.selected ? Theme.accent : Theme.alpha(Theme.text, 0.75)
                renderType: Text.NativeRendering
            }

            // Optional Badge Count Pill
            Rectangle {
                visible: chip.badgeCount > 0
                Layout.preferredHeight: 16
                Layout.preferredWidth: badgeText.implicitWidth + 8
                radius: 8
                color: chip.selected ? Theme.accent : Theme.alpha(Theme.text, 0.14)

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: chip.badgeCount.toString()
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: chip.selected ? (Theme.colors.bg ?? "#12141c") : Theme.alpha(Theme.text, 0.85)
                    renderType: Text.NativeRendering
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component M3IconButton: Rectangle {
        id: btn
        required property string glyph
        property string tooltip: ""
        property bool active: false
        property bool enabled: true
        signal clicked()

        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        radius: 15
        color: btn.active
            ? Theme.alpha(Theme.accent, 0.22)
            : (btnHover.hovered && btn.enabled ? Theme.alpha(Theme.text, 0.09) : "transparent")
        opacity: btn.enabled ? 1.0 : 0.40
        Behavior on color { ColorAnimation { duration: 110 } }

        HoverHandler { id: btnHover }

        MaterialSymbol {
            anchors.centerIn: parent
            text: btn.glyph
            iconSize: 15
            color: btn.active ? Theme.accent : Theme.alpha(Theme.text, 0.75)
        }

        ToolTip.visible: btn.tooltip !== "" && btnHover.hovered
        ToolTip.text: btn.tooltip
        ToolTip.delay: 400

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: btn.enabled
            onClicked: btn.clicked()
        }
    }
}
