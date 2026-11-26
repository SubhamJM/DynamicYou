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
    readonly property int calculatedHeight: previewOpen ? 500 : Math.min(496, Math.max(256,
        168 + Math.min(results.count, 6) * 54 + (failure !== "" ? 22 : 0)))
    readonly property string scriptPath: Quickshell.shellPath("scripts/clipboard_manager.py")
    readonly property color errorColor: (Theme.colors && Theme.colors.error) ? Theme.colors.error : "#f38ba8"

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

    readonly property var filterTabs: [
        { key: "all", label: "All", icon: "select_all" },
        { key: "text", label: "Text", icon: "notes" },
        { key: "image", label: "Images", icon: "image" },
        { key: "code", label: "Code", icon: "code" }
    ]

    readonly property int filterIndex: {
        for (var i = 0; i < filterTabs.length; i++) {
            if (filterTabs[i].key === filter) return i;
        }
        return 0;
    }

    component MIcon: Text {
        property bool filled: false
        property int weightAxis: 500
        font.family: Theme.fontFamilyIcon
        font.pixelSize: 16
        font.variableAxes: ({
            "FILL": filled ? 1 : 0,
            "GRAD": Theme.fontIconGrad,
            "opsz": 20,
            "wght": weightAxis
        })
        renderType: Text.CurveRendering
        font.hintingPreference: Font.PreferNoHinting
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: Theme.text
    }

    component MLabel: Text {
        property int weightAxis: 540
        property bool tabular: false
        font.family: "Google Sans Flex"
        font.pixelSize: 13
        font.weight: weightAxis >= 640 ? Font.Bold : (weightAxis >= 560 ? Font.DemiBold : (weightAxis >= 480 ? Font.Medium : Font.Normal))
        font.variableAxes: ({ "wght": weightAxis })
        font.features: tabular ? ({ "tnum": 1 }) : ({})
        renderType: Text.QtRendering
        font.hintingPreference: Font.PreferNoHinting
        color: Theme.text
    }

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
        previewLoader.running = false;
        previewLoader.binary = item.isImage && item.binary;
        previewLoader.command = previewLoader.binary
            ? ["sh", "-c", 'umask 077; cliphist decode "$1" > "$2"', "clipboard-preview", item.clipId, previewPath]
            : ["cliphist", "decode", item.clipId];
        previewLoader.running = true;
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
            search.text = "";
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

    // Main History View
    ColumnLayout {
        visible: !clipboard.previewOpen
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header Row (borderless, Control Center rhythm)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: backMouse.pressed ? Qt.alpha(Theme.text, 0.14) : (backMouse.containsMouse ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.06))
                Behavior on color { ColorAnimation { duration: 120 } }

                MIcon {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    font.pixelSize: 17
                    filled: backMouse.containsMouse
                    color: backMouse.containsMouse ? Theme.text : Qt.alpha(Theme.text, 0.80)
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("utility", true)
                }
            }

            MLabel {
                text: "Clipboard"
                font.pixelSize: 15
                weightAxis: 640
            }

            Rectangle {
                visible: results.count > 0
                Layout.preferredHeight: 22
                Layout.preferredWidth: countTxt.implicitWidth + 14
                radius: 11
                color: Qt.alpha(Theme.text, 0.07)

                MLabel {
                    id: countTxt
                    anchors.centerIn: parent
                    font.pixelSize: 11
                    weightAxis: 620
                    tabular: true
                    color: Theme.subtext
                    text: String(results.count)
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: clearBtn
                readonly property bool canClear: clipboard.clips.length > 0 && !mutation.running
                Layout.preferredHeight: 30
                Layout.preferredWidth: clearRow.implicitWidth + 20
                radius: 15
                opacity: canClear ? 1.0 : 0.35
                color: clipboard.confirmClear
                    ? clipboard.errorColor
                    : (clearMouse.containsMouse && canClear ? Qt.alpha(clipboard.errorColor, 0.16) : Qt.alpha(Theme.text, 0.06))

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 5

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: clipboard.confirmClear ? "warning" : "delete_sweep"
                        font.pixelSize: 15
                        filled: clipboard.confirmClear
                        color: clipboard.confirmClear ? "#101014" : (clearMouse.containsMouse && clearBtn.canClear ? clipboard.errorColor : Theme.subtext)
                    }

                    MLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 12
                        weightAxis: 600
                        color: clipboard.confirmClear ? "#101014" : (clearMouse.containsMouse && clearBtn.canClear ? clipboard.errorColor : Theme.subtext)
                        text: clipboard.confirmClear ? "Confirm clear" : "Clear"
                    }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    enabled: clearBtn.canClear
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
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
        }

        // Borderless Matushell Search Pill
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 18
            color: search.activeFocus ? Qt.alpha(Theme.text, 0.085) : Qt.alpha(Theme.text, 0.055)

            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 8

                MIcon {
                    text: "search"
                    font.pixelSize: 17
                    color: search.activeFocus ? Theme.accent : Theme.subtext
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    MLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: search.text === ""
                        font.pixelSize: 13
                        weightAxis: 480
                        color: Qt.alpha(Theme.text, 0.42)
                        text: "Search clipboard…"
                    }

                    TextInput {
                        id: search
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        selectByMouse: true
                        font.family: "Google Sans Flex"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        renderType: Text.QtRendering
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        clip: true
                        Keys.forwardTo: [clipboard]
                        onTextChanged: clipboard.rebuild()
                    }
                }

                Rectangle {
                    visible: search.text !== ""
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 11
                    color: clrM.containsMouse ? Qt.alpha(Theme.text, 0.12) : "transparent"

                    MIcon {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 15
                        color: Theme.subtext
                    }
                    MouseArea {
                        id: clrM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            search.text = "";
                            search.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // Borderless Segmented Filter Bar
        Rectangle {
            id: filterTrack
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 16
            color: Qt.alpha(Theme.text, 0.055)

            readonly property real segW: (width - 6) / Math.max(1, clipboard.filterTabs.length)

            Rectangle {
                x: 3 + clipboard.filterIndex * filterTrack.segW
                y: 3
                width: filterTrack.segW
                height: parent.height - 6
                radius: 13
                color: Theme.accent

                Behavior on x {
                    NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 3

                Repeater {
                    model: clipboard.filterTabs

                    delegate: Item {
                        required property var modelData
                        readonly property bool active: clipboard.filter === modelData.key
                        width: filterTrack.segW
                        height: filterTrack.height - 6

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            MIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                font.pixelSize: 14
                                filled: active
                                color: active ? Theme.onAccent : (fMouse.containsMouse ? Theme.text : Theme.subtext)
                                Behavior on color { ColorAnimation { duration: 110 } }
                            }

                            MLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 12
                                weightAxis: active ? 640 : 540
                                color: active ? Theme.onAccent : (fMouse.containsMouse ? Theme.text : Theme.subtext)
                                text: modelData.label
                                Behavior on color { ColorAnimation { duration: 110 } }
                            }
                        }

                        MouseArea {
                            id: fMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                clipboard.filter = modelData.key;
                                search.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        // Clips List (borderless tonal cards matching UtilityModule tiles)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: rows
                anchors.fill: parent
                clip: true
                spacing: 6
                cacheBuffer: 0
                boundsBehavior: Flickable.StopAtBounds
                model: results

                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    width: 4
                    policy: results.count > 6 ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
                    contentItem: Rectangle {
                        radius: 2
                        color: Qt.alpha(Theme.text, 0.25)
                    }
                }

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

                    width: rows.width - (rows.contentHeight > rows.height ? 8 : 0)
                    height: 48
                    radius: 15
                    color: selected
                        ? Qt.alpha(Theme.accent, 0.14)
                        : (pointer.hovered ? Qt.alpha(Theme.text, 0.085) : Qt.alpha(Theme.text, 0.05))

                    Behavior on color { ColorAnimation { duration: 110 } }

                    HoverHandler { id: pointer }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            rows.currentIndex = row.index;
                            clipboard.copyClip(row.clipId);
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        // Leading Circular Icon Badge (or rounded image thumbnail)
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: (thumbnail.status === Image.Ready) ? 9 : 16
                            clip: true
                            color: row.type === "color"
                                ? row.title
                                : (row.selected ? Theme.accent : Qt.alpha(Theme.text, 0.08))

                            Behavior on color { ColorAnimation { duration: 110 } }

                            MIcon {
                                anchors.centerIn: parent
                                visible: row.type !== "color" && thumbnail.status !== Image.Ready
                                text: row.icon
                                font.pixelSize: 16
                                filled: row.selected
                                color: row.selected ? Theme.onAccent : Theme.subtext
                            }

                            Image {
                                id: thumbnail
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize: Qt.size(64, 64)
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

                        // Entry Title + Subtitle
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: row.title || row.description
                                textFormat: Text.PlainText
                                color: Theme.text
                                font.family: ["code", "cmd", "json", "color"].includes(row.type) ? Theme.fontFamilyNerd : "Google Sans Flex"
                                font.pixelSize: ["code", "cmd", "json", "color"].includes(row.type) ? 12 : 13
                                font.weight: row.selected ? Font.DemiBold : Font.Medium
                                renderType: Text.QtRendering
                                font.hintingPreference: Font.PreferNoHinting
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            MLabel {
                                Layout.fillWidth: true
                                visible: row.subtitle !== ""
                                text: row.subtitle
                                textFormat: Text.PlainText
                                font.pixelSize: 10
                                weightAxis: 480
                                tabular: true
                                color: Theme.subtext
                                elide: Text.ElideRight
                            }
                        }

                        // Uncluttered Trailing Action Icons (no nested grey circles)
                        Row {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            // Preview
                            Rectangle {
                                visible: row.hot && /^\d+$/.test(row.clipId)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                height: 26
                                radius: 13
                                color: prevM.containsMouse ? Qt.alpha(Theme.text, 0.10) : "transparent"

                                MIcon {
                                    anchors.centerIn: parent
                                    text: "visibility"
                                    font.pixelSize: 15
                                    color: prevM.containsMouse ? Theme.text : Theme.subtext
                                }
                                MouseArea {
                                    id: prevM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        rows.currentIndex = row.index;
                                        clipboard.openPreview();
                                    }
                                }
                            }

                            // Pin
                            Rectangle {
                                visible: row.hot || row.isPinned
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                height: 26
                                radius: 13
                                color: pinM.containsMouse ? Qt.alpha(Theme.text, 0.10) : "transparent"

                                MIcon {
                                    anchors.centerIn: parent
                                    text: "push_pin"
                                    font.pixelSize: 15
                                    filled: row.isPinned
                                    color: row.isPinned ? Theme.accent : (pinM.containsMouse ? Theme.text : Theme.subtext)
                                }
                                MouseArea {
                                    id: pinM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !mutation.running
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clipboard.changeHistory("pin", row.clipId, row.description)
                                }
                            }

                            // Delete
                            Rectangle {
                                visible: row.hot
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                height: 26
                                radius: 13
                                color: delRowM.containsMouse ? Qt.alpha(clipboard.errorColor, 0.16) : "transparent"

                                MIcon {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    font.pixelSize: 15
                                    color: delRowM.containsMouse ? clipboard.errorColor : Theme.subtext
                                }
                                MouseArea {
                                    id: delRowM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !mutation.running
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clipboard.changeHistory("delete", row.clipId)
                                }
                            }

                            // Compact Copy Pill on active/copied row
                            Rectangle {
                                visible: row.selected || row.copied
                                anchors.verticalCenter: parent.verticalCenter
                                width: copyLbl.implicitWidth + 18
                                height: 26
                                radius: 13
                                color: copyM.pressed ? Qt.alpha(Theme.accent, 0.82) : Theme.accent

                                MLabel {
                                    id: copyLbl
                                    anchors.centerIn: parent
                                    font.pixelSize: 11
                                    weightAxis: 640
                                    color: Theme.onAccent
                                    text: row.copied ? "Copied" : "Copy"
                                }
                                MouseArea {
                                    id: copyM
                                    anchors.fill: parent
                                    enabled: row.selected && !copier.running
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clipboard.copyClip(row.clipId)
                                }
                            }
                        }
                    }
                }
            }

            // Empty / Loading / Error state
            Column {
                visible: results.count === 0
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: Qt.alpha(clipboard.failure ? clipboard.errorColor : Theme.accent, 0.12)

                    MIcon {
                        anchors.centerIn: parent
                        text: clipboard.failure ? "error" : (clipboard.filter === "image" ? "image" : (clipboard.filter === "code" ? "code" : "content_paste_off"))
                        font.pixelSize: 22
                        color: clipboard.failure ? clipboard.errorColor : Theme.accent
                    }
                }

                MLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 13
                    weightAxis: 540
                    color: Theme.subtext
                    text: !clipboard.loaded && !clipboard.failure ? "Loading clipboard…"
                        : clipboard.failure ? "Clipboard unavailable"
                        : search.text.trim() || clipboard.filter !== "all" ? "No matching items" : "Clipboard history is empty"
                }
            }
        }

        MLabel {
            Layout.fillWidth: true
            visible: clipboard.failure !== ""
            text: clipboard.failure
            font.pixelSize: 11
            weightAxis: 540
            color: clipboard.errorColor
        }
    }

    // Expanded Preview View (720 x 500, completely borderless)
    ColumnLayout {
        visible: clipboard.previewOpen
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: pBackM.containsMouse ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.06)

                MIcon {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    font.pixelSize: 17
                }
                MouseArea {
                    id: pBackM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: clipboard.closePreview()
                }
            }

            MLabel {
                Layout.fillWidth: true
                text: clipboard.previewItem?.isImage || clipboard.previewImages.length ? "Image preview" : "Text preview"
                font.pixelSize: 15
                weightAxis: 640
            }

            Row {
                visible: clipboard.previewImages.length > 1
                spacing: 6

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    opacity: clipboard.previewImageIndex > 0 ? 1.0 : 0.35
                    color: Qt.alpha(Theme.text, 0.06)
                    MIcon { anchors.centerIn: parent; text: "chevron_left"; font.pixelSize: 16 }
                    MouseArea {
                        anchors.fill: parent
                        enabled: clipboard.previewImageIndex > 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            clipboard.previewImageIndex--;
                            clipboard.previewImage = clipboard.previewImages[clipboard.previewImageIndex];
                        }
                    }
                }

                MLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 12
                    weightAxis: 600
                    tabular: true
                    color: Theme.subtext
                    text: (clipboard.previewImageIndex + 1) + " / " + clipboard.previewImages.length
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    opacity: clipboard.previewImageIndex < clipboard.previewImages.length - 1 ? 1.0 : 0.35
                    color: Qt.alpha(Theme.text, 0.06)
                    MIcon { anchors.centerIn: parent; text: "chevron_right"; font.pixelSize: 16 }
                    MouseArea {
                        anchors.fill: parent
                        enabled: clipboard.previewImageIndex < clipboard.previewImages.length - 1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            clipboard.previewImageIndex++;
                            clipboard.previewImage = clipboard.previewImages[clipboard.previewImageIndex];
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth: pCopyRow.implicitWidth + 22
                radius: 15
                color: pCopyM.pressed ? Qt.alpha(Theme.accent, 0.82) : Theme.accent

                Row {
                    id: pCopyRow
                    anchors.centerIn: parent
                    spacing: 5
                    MIcon { anchors.verticalCenter: parent.verticalCenter; text: "content_copy"; font.pixelSize: 14; color: Theme.onAccent }
                    MLabel { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; weightAxis: 640; color: Theme.onAccent; text: "Copy" }
                }
                MouseArea {
                    id: pCopyM
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (clipboard.previewItem) clipboard.copyClip(clipboard.previewItem.clipId)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: Qt.alpha(Theme.text, 0.05)
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
                    font.family: "Google Sans Flex"
                    font.pixelSize: 13
                    renderType: Text.QtRendering
                    background: null
                }
            }
        }
    }
}
