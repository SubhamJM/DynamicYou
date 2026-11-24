import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

FocusScope {
    id: clipboard
    focus: true

    readonly property int targetWidth: previewOpen ? 720 : 480
    readonly property int calculatedCount: results.count
    readonly property int calculatedHeight: previewOpen ? 500 : Math.min(480, Math.max(246,
        120 + Math.min(results.count, 7) * 44 + (failure ? 20 : 0)))
    readonly property string scriptPath: Quickshell.shellPath("scripts/clipboard_manager.py")
    readonly property color secondary: Theme.alpha(Theme.text, 0.72)
    readonly property color outline: Theme.alpha(Theme.text, 0.10)

    property alias searchInput: search
    property var clips: []
    property string filter: "all"
    property string copiedId: ""
    property string failure: ""
    property bool confirmClear: false
    property bool loaded: false
    property bool previewOpen: false
    property var previewItem: null
    property string previewText: ""
    property string previewImage: ""
    property var previewImages: []
    property int previewImageIndex: 0
    readonly property string previewPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dynamic-you-clipboard-preview-" + Quickshell.env("USER")

    function closePreview() {
        previewOpen = false;
        previewImage = "";
        previewImages = [];
        previewText = "";
        previewItem = null;
        if (previewLoader.running) previewLoader.running = false;
        Quickshell.execDetached(["rm", "-f", "--", previewPath]);
        if (root.activeMode === "clipboard") search.forceActiveFocus();
    }
    function openPreview() {
        if (rows.currentIndex < 0 || rows.currentIndex >= results.count) return;
        const item = results.get(rows.currentIndex);
        if (!/^\d+$/.test(item.clipId)) return;
        previewItem = { clipId: item.clipId, isImage: item.isImage, binary: item.binary, imgPath: item.imgPath, title: item.title };
        previewText = "";
        previewImage = "";
        previewImages = [];
        previewImageIndex = 0;
        previewOpen = true;
        {
            previewLoader.running = false;
            previewLoader.binary = item.isImage && item.binary;
            previewLoader.command = previewLoader.binary
                ? ["sh", "-c", 'umask 077; cliphist decode "$1" > "$2"', "clipboard-preview", item.clipId, previewPath]
                : ["cliphist", "decode", item.clipId];
            previewLoader.running = true;
        }
        clipboard.forceActiveFocus();
    }

    onFilterChanged: rebuild()

    function refresh() {
        if (!scanner.running) scanner.running = true;
    }

    function rebuild() {
        const query = search.text.trim().toLowerCase();
        results.clear();
        for (const item of clips) {
            const code = ["code", "cmd", "json"].includes(item.type);
            if (filter === "image" && !item.isImage || filter === "text" && (item.isImage || code)
                    || filter === "code" && !code)
                continue;
            if (query && ![item.title, item.subtitle, item.description].some(value => (value || "").toLowerCase().includes(query)))
                continue;
            results.append(item);
        }
        rows.currentIndex = results.count ? 0 : -1;
        rows.positionViewAtBeginning();
    }

    function navDown() {
        if (rows.currentIndex >= results.count - 1) return false;
        rows.incrementCurrentIndex();
        rows.positionViewAtIndex(rows.currentIndex, ListView.Contain);
        return true;
    }

    function navUp() {
        if (rows.currentIndex <= 0) return false;
        rows.decrementCurrentIndex();
        rows.positionViewAtIndex(rows.currentIndex, ListView.Contain);
        return true;
    }

    function activateSelected() {
        if (rows.currentIndex < 0 || rows.currentIndex >= results.count) return false;
        return copyClip(results.get(rows.currentIndex).clipId);
    }

    function copyClip(id) {
        if (copier.running || copiedId !== "" || !/^\d+$/.test(id)) return false;
        failure = "";
        copier.command = ["bash", "-o", "pipefail", "-c", 'cliphist decode "$1" | wl-copy', "clipboard", id];
        copier.clipId = id;
        copier.running = true;
        return true;
    }

    function changeHistory(action, id, description) {
        if (mutation.running) return;
        failure = "";
        mutation.command = ["python3", scriptPath, action].concat(id ? [id] : [], description ? [description] : []);
        mutation.action = action;
        mutation.running = true;
    }

    function handleEscape() {
        if (previewOpen) {
            closePreview();
        } else if (confirmClear) {
            confirmClear = false;
            confirmTimer.stop();
        } else if (search.text !== "") {
            search.clear();
        } else {
            root.collapseToIdle();
        }
    }

    Keys.onDownPressed: event => { navDown(); event.accepted = true; }
    Keys.onUpPressed: event => { navUp(); event.accepted = true; }
    Keys.onRightPressed: event => { if (!previewOpen) { openPreview(); event.accepted = true; } }
    Keys.onLeftPressed: event => { if (previewOpen) { closePreview(); event.accepted = true; } }
    Keys.onReturnPressed: event => { activateSelected(); event.accepted = true; }
    Keys.onEnterPressed: event => { activateSelected(); event.accepted = true; }
    Keys.onEscapePressed: event => { handleEscape(); event.accepted = true; }
    Keys.onDeletePressed: event => {
        if (event.modifiers & Qt.ShiftModifier && rows.currentIndex >= 0) {
            changeHistory("delete", results.get(rows.currentIndex).clipId);
            event.accepted = true;
        }
    }

    Component.onCompleted: refresh()
    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode !== "clipboard") {
                if (clipboard.previewOpen) clipboard.closePreview();
                closeTimer.stop();
                clipboard.copiedId = "";
                clipboard.confirmClear = false;
                confirmTimer.stop();
                return;
            }
            clipboard.failure = "";
            clipboard.refresh();
        }
    }

    ListModel { id: results }

    Process {
        id: previewLoader
        property bool binary: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!clipboard.previewOpen || previewLoader.binary) return;
                const lines = text.trim().split(/\r?\n/).filter(line => line.trim() !== "");
                const images = lines.filter(line => /^(file:\/\/|\/)/i.test(line.trim()) && /\.(png|jpe?g|webp|gif|avif|bmp|svg)(?:\?.*)?$/i.test(line.trim()));
                if (images.length && images.length === lines.length) {
                    clipboard.previewImages = images.map(line => line.trim().startsWith("file://") ? line.trim() : "file://" + line.trim());
                    clipboard.previewImageIndex = 0;
                    clipboard.previewImage = clipboard.previewImages[0];
                } else clipboard.previewText = text;
            }
        }
        onExited: code => {
            if (!clipboard.previewOpen) return;
            if (code !== 0) clipboard.previewText = "Couldn’t load this item.";
            else if (binary) clipboard.previewImage = "file://" + clipboard.previewPath;
        }
    }

    Process {
        id: scanner
        command: ["python3", clipboard.scriptPath, "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const entries = JSON.parse(text);
                    if (!Array.isArray(entries)) throw new Error("Expected a clipboard list");
                    clipboard.clips = entries;
                    clipboard.loaded = true;
                    clipboard.rebuild();
                } catch (_) {
                    clipboard.failure = "Couldn’t load clipboard history.";
                }
            }
        }
    }

    Process {
        id: copier
        property string clipId: ""
        onExited: code => {
            if (root.activeMode !== "clipboard") return;
            if (code === 0) {
                clipboard.copiedId = clipId;
                closeTimer.restart();
            } else {
                clipboard.failure = "Couldn’t copy this item.";
            }
        }
    }

    Process {
        id: mutation
        property string action: ""
        onExited: code => {
            if (code !== 0) {
                clipboard.failure = "Couldn’t update clipboard history.";
            } else if (action === "wipe") {
                clipboard.clips = [];
                clipboard.rebuild();
                if (root.activeMode === "clipboard") root.collapseToIdle();
            } else {
                Qt.callLater(clipboard.refresh);
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 230
        onTriggered: {
            if (root.activeMode === "clipboard") root.collapseToIdle();
            clipboard.copiedId = "";
        }
    }
    Timer {
        id: confirmTimer
        interval: 3500
        onTriggered: clipboard.confirmClear = false
    }

    ColumnLayout {
        visible: !clipboard.previewOpen
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ActionButton {
                glyph: "arrow_back"
                text: "Back to Control Center"
                iconOnly: true
                onClicked: root.switchMode("utility", true)
            }

            Text {
                Layout.fillWidth: true
                text: "Clipboard"
                color: Theme.text
                font.family: Theme.fontFamilyBody
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            ActionButton {
                Layout.preferredWidth: 112
                glyph: clipboard.confirmClear ? "warning" : "delete_sweep"
                text: clipboard.confirmClear ? "Confirm clear" : "Clear history"
                tone: clipboard.confirmClear ? Theme.error : clipboard.secondary
                enabled: clipboard.clips.length > 0 && !mutation.running
                onClicked: {
                    if (clipboard.confirmClear) {
                        clipboard.confirmClear = false;
                        confirmTimer.stop();
                        clipboard.changeHistory("wipe");
                    } else {
                        clipboard.confirmClear = true;
                        confirmTimer.restart();
                    }
                }
            }
        }

        Controls.TextField {
            id: search
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            focus: true
            leftPadding: 32
            rightPadding: clearSearch.visible ? 32 : 10
            selectByMouse: true
            placeholderText: "Search clipboard"
            placeholderTextColor: clipboard.secondary
            font.family: Theme.fontFamilyBody
            font.pixelSize: 12
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.fgPrimary
            Keys.forwardTo: [clipboard]
            onTextChanged: clipboard.rebuild()

            background: Rectangle {
                radius: 10
                color: Theme.alpha(Theme.text, 0.055)
                border.color: search.activeFocus ? Theme.alpha(Theme.accent, 0.52) : clipboard.outline

                MaterialSymbol {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    iconSize: 15
                    color: clipboard.secondary
                }
            }

            ActionButton {
                id: clearSearch
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text !== ""
                text: "Clear search"
                glyph: "close"
                iconOnly: true
                onClicked: search.clear()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    { key: "all", label: "All" },
                    { key: "text", label: "Text" },
                    { key: "image", label: "Images" },
                    { key: "code", label: "Code" }
                ]

                ActionButton {
                    required property var modelData
                    text: modelData.label
                    selected: clipboard.filter === modelData.key
                    onClicked: {
                        clipboard.filter = modelData.key;
                        search.forceActiveFocus();
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: Theme.alpha(Theme.text, 0.035)
            border.color: clipboard.outline

            ListView {
                id: rows
                anchors.fill: parent
                anchors.margins: 3
                clip: true
                cacheBuffer: 0
                boundsBehavior: Flickable.StopAtBounds
                model: results

                Controls.ScrollBar.vertical: Controls.ScrollBar { width: 5; policy: Controls.ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: row
                    required property int index
                    required property string clipId
                    required property string type
                    required property string icon
                    required property string imgPath
                    required property string title
                    required property string subtitle
                    required property string description
                    required property bool isImage
                    required property bool isPinned
                    required property bool binary

                    readonly property bool selected: ListView.isCurrentItem
                    readonly property bool hot: selected || pointer.hovered
                    readonly property bool copied: clipboard.copiedId === clipId

                    width: rows.width - (rows.contentHeight > rows.height ? 6 : 0)
                    height: 44
                    radius: 8
                    color: selected ? Theme.alpha(Theme.accent, 0.13)
                        : pointer.hovered ? Theme.alpha(Theme.text, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: pointer }

                    Controls.AbstractButton {
                        anchors.fill: parent
                        background: null
                        Accessible.name: "Copy " + row.title
                        onClicked: {
                            rows.currentIndex = row.index;
                            clipboard.copyClip(row.clipId);
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 7

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 6
                            color: row.type === "color" ? row.title : Theme.alpha(Theme.text, 0.06)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: row.type !== "color" && thumbnail.status !== Image.Ready
                                text: row.icon
                                iconSize: 15
                                color: row.selected ? Theme.accent : clipboard.secondary
                            }

                            Image {
                                id: thumbnail
                                anchors.fill: parent
                                anchors.margins: 1
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                                sourceSize: Qt.size(52, 52)
                                source: row.isImage && !row.binary && row.imgPath ? "file://" + row.imgPath : ""
                            }

                            Process {
                                command: ["python3", clipboard.scriptPath, "thumbnail", row.clipId, row.description]
                                running: row.binary
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        const path = text.trim();
                                        if (path) thumbnail.source = "file://" + path;
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: row.title || row.description
                                textFormat: Text.PlainText
                                color: Theme.text
                                font.family: ["code", "cmd", "json", "color"].includes(row.type) ? Theme.fontFamilyNerd : Theme.fontFamilyBody
                                font.pixelSize: 12
                                font.weight: row.selected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: row.subtitle !== ""
                                text: row.subtitle
                                textFormat: Text.PlainText
                                font.family: Theme.fontFamilyBody
                                font.pixelSize: 10
                                color: clipboard.secondary
                                elide: Text.ElideRight
                            }
                        }

                        ActionButton {
                            Layout.preferredWidth: 68
                            opacity: row.selected || row.copied ? 1 : 0
                            enabled: row.selected && !copier.running
                            text: row.copied ? "Copied" : "Copy"
                            primary: true
                            onClicked: clipboard.copyClip(row.clipId)
                        }

                        ActionButton {
                            glyph: "push_pin"
                            iconOnly: true
                            text: row.isPinned ? "Unpin" : "Pin"
                            tone: row.isPinned ? Theme.accent : clipboard.secondary
                            opacity: row.hot || row.isPinned ? 1 : 0
                            enabled: (row.hot || row.isPinned) && !mutation.running
                            onClicked: clipboard.changeHistory("pin", row.clipId, row.description)
                        }

                        ActionButton {
                            glyph: "delete"
                            iconOnly: true
                            text: "Delete"
                            tone: hovered ? Theme.error : clipboard.secondary
                            opacity: row.hot ? 1 : 0
                            enabled: row.hot && !mutation.running
                            onClicked: clipboard.changeHistory("delete", row.clipId)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: results.count === 0
                    text: !clipboard.loaded && !clipboard.failure ? "Loading clipboard…"
                        : clipboard.failure ? "Clipboard unavailable"
                        : search.text.trim() || clipboard.filter !== "all" ? "No matching items" : "Clipboard history is empty"
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 12
                    color: clipboard.secondary
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: clipboard.failure !== ""
            text: clipboard.failure
            font.family: Theme.fontFamilyBody
            font.pixelSize: 11
            color: Theme.error
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: clipboard.previewOpen
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            ActionButton { glyph: "arrow_back"; iconOnly: true; text: "Back"; onClicked: clipboard.closePreview() }
            Text {
                Layout.fillWidth: true
                text: clipboard.previewItem?.isImage || clipboard.previewImages.length ? "Image preview" : "Text preview"
                font.family: Theme.fontFamilyBody
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: Theme.text
            }
            ActionButton { text: "Copy"; primary: true; onClicked: clipboard.copyClip(clipboard.previewItem.clipId) }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: clipboard.previewImages.length > 1
            ActionButton { glyph: "chevron_left"; iconOnly: true; text: "Previous image"; enabled: clipboard.previewImageIndex > 0; onClicked: { clipboard.previewImageIndex--; clipboard.previewImage = clipboard.previewImages[clipboard.previewImageIndex]; } }
            Text { text: (clipboard.previewImageIndex + 1) + " / " + clipboard.previewImages.length; color: clipboard.secondary; font.pixelSize: 12 }
            ActionButton { glyph: "chevron_right"; iconOnly: true; text: "Next image"; enabled: clipboard.previewImageIndex < clipboard.previewImages.length - 1; onClicked: { clipboard.previewImageIndex++; clipboard.previewImage = clipboard.previewImages[clipboard.previewImageIndex]; } }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: Theme.alpha(Theme.text, 0.045)
            clip: true
            Image {
                anchors.fill: parent
                anchors.margins: 14
                visible: clipboard.previewImage !== ""
                source: clipboard.previewImage
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
            Controls.ScrollView {
                anchors.fill: parent
                anchors.margins: 14
                visible: clipboard.previewImage === "" && (!clipboard.previewItem || !clipboard.previewItem.isImage || clipboard.previewText !== "")
                clip: true
                Controls.TextArea {
                    text: clipboard.previewText
                    textFormat: TextEdit.PlainText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 13
                    background: null
                }
            }
        }
    }

    component ActionButton: Controls.Button {
        id: button
        property string glyph: ""
        property bool iconOnly: false
        property bool selected: false
        property bool primary: false
        property color tone: clipboard.secondary

        implicitHeight: 32
        implicitWidth: iconOnly ? 32 : Math.max(48, label.implicitWidth + (glyph ? 35 : 18))
        padding: 0
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        Accessible.name: text
        Controls.ToolTip.visible: iconOnly && hovered
        Controls.ToolTip.text: text
        Controls.ToolTip.delay: 500

        background: Rectangle {
            radius: 8
            color: button.primary ? Theme.accent : button.selected ? Theme.alpha(Theme.accent, 0.16)
                : Theme.alpha(Theme.text, button.down ? 0.12 : button.hovered ? 0.08 : 0)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        contentItem: Item {
            opacity: button.enabled || button.primary ? 1 : 0.45
            Row {
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: button.glyph !== ""
                    text: button.glyph
                    iconSize: 15
                    color: button.tone
                }

                Text {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !button.iconOnly
                    text: button.text
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: button.primary ? Theme.fgPrimary : button.selected ? Theme.accent : button.tone
                }
            }
        }
    }
}
