import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: engineModule
    focus: true

    // --- State ---
    property int activeProvider: 0 // 0 = Wallpaper Engine, 1 = Local Wallpapers
    property int activeCategory: 0 // 0 = All, 1 = Scenes, 2 = Videos (or 1=Images, 2=GIFs in Local)
    property string searchQuery: ""
    property string activeWallpaper: ""
    property int selectedIndex: -1

    // Data lists
    property var allEngineItems: []
    property var allLocalItems: []

    // Filtered items based on active provider, category, and search query
    readonly property var currentItems: {
        var list = (activeProvider === 0) ? allEngineItems : allLocalItems;
        if (!list || list.length === 0) return [];
        var q = searchQuery.toLowerCase().trim();
        var cat = activeCategory;

        var filtered = [];
        for (var i = 0; i < list.length; i++) {
            var it = list[i];
            if (!it) continue;

            // Category filter
            if (activeProvider === 0) {
                // Engine: 0=All, 1=Scenes, 2=Videos
                if (cat === 1 && it.type !== "scene") continue;
                if (cat === 2 && it.type !== "video") continue;
            } else {
                // Local: 0=All, 1=Images, 2=GIFs
                if (cat === 1 && it.type === "gif") continue;
                if (cat === 2 && it.type !== "gif") continue;
            }

            // Search query filter
            if (q !== "") {
                var titleMatch = it.title && it.title.toLowerCase().indexOf(q) !== -1;
                var idMatch = it.id && it.id.toLowerCase().indexOf(q) !== -1;
                if (!titleMatch && !idMatch) continue;
            }

            filtered.push(it);
        }
        return filtered;
    }

    Component.onCompleted: {
        refresh();
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    onVisibleChanged: {
        if (visible) {
            refresh();
            Qt.callLater(() => searchInput.forceActiveFocus());
        }
    }

    function refresh() {
        if (scannerProcess.running) scannerProcess.running = false;
        scannerProcess.running = true;
    }

    Process {
        id: scannerProcess
        running: false
        command: [
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/scripts/scan_engine_wallpapers.py"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var data = JSON.parse(this.text);
                    if (data.active) {
                        engineModule.activeWallpaper = data.active;
                    }
                    if (data.engine) {
                        engineModule.allEngineItems = data.engine;
                    }
                    if (data.local) {
                        engineModule.allLocalItems = data.local;
                    }
                } catch (e) {
                    console.warn("Failed to parse wallpaper data:", e);
                }
            }
        }
    }

    // --- Keyboard Navigation ---
    Keys.onEscapePressed: (event) => {
        if (typeof root !== "undefined") root.collapseToIdle();
        event.accepted = true;
    }

    Keys.onReturnPressed: (event) => {
        applyCurrent();
        event.accepted = true;
    }
    Keys.onEnterPressed: (event) => {
        applyCurrent();
        event.accepted = true;
    }

    function applyCurrent() {
        if (cardGrid.currentIndex >= 0 && cardGrid.currentIndex < currentItems.length) {
            applyItem(currentItems[cardGrid.currentIndex]);
        }
    }

    function applyItem(item) {
        if (!item) return;
        var applyTarget = (item.isWE && item.path) ? item.path : (item.path || item.preview || "");
        if (!applyTarget) return;

        engineModule.activeWallpaper = applyTarget;
        if (typeof root !== "undefined") {
            root.cachedActiveWallpaper = applyTarget;
        }

        var trans = (Theme.activeTransition && Theme.activeTransition.trim()) || "simple";
        var scriptPath = Quickshell.env("HOME") + "/.config/quickshell/scripts/apply_wallpaper.sh";
        var poster = item.poster || item.preview || "";

        Quickshell.execDetached([
            scriptPath,
            applyTarget,
            trans,
            poster
        ]);

        if (typeof root !== "undefined") {
            root.collapseToIdle();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ==========================================
        // 1. TOP HEADER & PROVIDER SELECTION BAR
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Header Title & Icon
            RowLayout {
                spacing: 6
                MaterialSymbol {
                    text: "animation"
                    iconSize: 22
                    color: Theme.colors.accent ?? "#7aa2f7"
                }
                Text {
                    text: "Wallpaper Engine"
                    font.family: Theme.fontFamilyBody ?? "Noto Sans"
                    font.pixelSize: 15
                    font.bold: true
                    color: Theme.colors.text_primary ?? "#ffffff"
                }
                Text {
                    text: "(" + currentItems.length + ")"
                    font.family: Theme.fontFamilyNerd ?? "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.colors.text_secondary ?? "#94a3b8"
                }
            }

            Item { Layout.fillWidth: true }

            // Provider Pill Switcher: [ Wallpaper Engine | Local ]
            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth: 260
                radius: 15
                color: Theme.colors.card_bg ?? "#121216"
                border.width: 1
                border.color: Theme.colors.hover_bg ?? "#24242e"

                Row {
                    anchors.fill: parent
                    anchors.margins: 2

                    // Engine Pill
                    Rectangle {
                        width: parent.width / 2
                        height: parent.height
                        radius: 13
                        color: engineModule.activeProvider === 0 ? (Theme.colors.accent ?? "#7aa2f7") : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast ?? 100 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol {
                                text: "animation"
                                iconSize: 14
                                color: engineModule.activeProvider === 0 ? (Theme.colors.bg ?? "#000000") : (Theme.colors.text_secondary ?? "#94a3b8")
                            }
                            Text {
                                text: "Engine"
                                font.pixelSize: 12
                                font.bold: true
                                color: engineModule.activeProvider === 0 ? (Theme.colors.bg ?? "#000000") : (Theme.colors.text_secondary ?? "#94a3b8")
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engineModule.activeProvider = 0;
                                engineModule.activeCategory = 0;
                            }
                        }
                    }

                    // Local Pill
                    Rectangle {
                        width: parent.width / 2
                        height: parent.height
                        radius: 13
                        color: engineModule.activeProvider === 1 ? (Theme.colors.accent ?? "#7aa2f7") : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast ?? 100 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol {
                                text: "folder_open"
                                iconSize: 14
                                color: engineModule.activeProvider === 1 ? (Theme.colors.bg ?? "#000000") : (Theme.colors.text_secondary ?? "#94a3b8")
                            }
                            Text {
                                text: "Local"
                                font.pixelSize: 12
                                font.bold: true
                                color: engineModule.activeProvider === 1 ? (Theme.colors.bg ?? "#000000") : (Theme.colors.text_secondary ?? "#94a3b8")
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engineModule.activeProvider = 1;
                                engineModule.activeCategory = 0;
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Close button
            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 13
                color: closeMouse.containsMouse ? (Theme.colors.hover_bg ?? "#1e1e24") : "transparent"
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 16
                    color: Theme.colors.text_secondary ?? "#94a3b8"
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof root !== "undefined") root.collapseToIdle();
                    }
                }
            }
        }

        // ==========================================
        // 2. SEARCH & CATEGORY FILTER BAR
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Search Input Box
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 16
                color: Theme.colors.card_bg ?? "#121216"
                border.width: 1
                border.color: searchInput.activeFocus ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.hover_bg ?? "#24242e")
                Behavior on border.color { ColorAnimation { duration: Theme.animFast ?? 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6

                    MaterialSymbol {
                        text: "search"
                        iconSize: 16
                        color: Theme.colors.text_secondary ?? "#94a3b8"
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: Theme.fontFamilyBody ?? "Noto Sans"
                        font.pixelSize: 12
                        color: Theme.colors.text_primary ?? "#ffffff"
                        clip: true
                        selectByMouse: true
                        text: engineModule.searchQuery
                        onTextChanged: engineModule.searchQuery = text

                        Text {
                            anchors.fill: parent
                            text: engineModule.activeProvider === 0 ? "Search Wallpaper Engine..." : "Search local wallpapers..."
                            color: Theme.colors.text_muted ?? "#64748b"
                            font: parent.font
                            visible: !parent.text && !parent.activeFocus
                        }
                    }

                    // Clear button
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        visible: searchInput.text !== ""
                        color: clearMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24242e") : "transparent"
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 13
                            color: Theme.colors.text_secondary ?? "#94a3b8"
                        }
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                engineModule.searchQuery = "";
                            }
                        }
                    }
                }
            }

            // Category Filter Chips
            Row {
                spacing: 6

                Repeater {
                    model: (engineModule.activeProvider === 0)
                        ? [ { text: "All", icon: "grid_view" }, { text: "Scenes", icon: "animation" }, { text: "Videos", icon: "movie" } ]
                        : [ { text: "All", icon: "grid_view" }, { text: "Images", icon: "image" }, { text: "GIFs", icon: "animation" } ]

                    delegate: Rectangle {
                        id: chipBtn
                        required property var modelData
                        required property int index

                        width: chipRow.implicitWidth + 16
                        height: 30
                        radius: 15
                        color: (engineModule.activeCategory === index)
                            ? (Theme.colors.accent ?? "#7aa2f7")
                            : (chipMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24242e") : (Theme.colors.card_bg ?? "#121216"))
                        border.width: 1
                        border.color: (engineModule.activeCategory === index) ? "transparent" : (Theme.colors.hover_bg ?? "#24242e")

                        Behavior on color { ColorAnimation { duration: Theme.animFast ?? 100 } }

                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol {
                                text: chipBtn.modelData.icon
                                iconSize: 13
                                color: (engineModule.activeCategory === chipBtn.index)
                                    ? (Theme.colors.bg ?? "#000000")
                                    : (Theme.colors.text_secondary ?? "#94a3b8")
                            }
                            Text {
                                text: chipBtn.modelData.text
                                font.pixelSize: 11
                                font.bold: true
                                color: (engineModule.activeCategory === chipBtn.index)
                                    ? (Theme.colors.bg ?? "#000000")
                                    : (Theme.colors.text_primary ?? "#ffffff")
                            }
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: engineModule.activeCategory = chipBtn.index
                        }
                    }
                }
            }

            // Refresh Button
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: refreshMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24242e") : (Theme.colors.card_bg ?? "#121216")
                border.width: 1
                border.color: Theme.colors.hover_bg ?? "#24242e"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 16
                    color: Theme.colors.accent ?? "#7aa2f7"
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: engineModule.refresh()
                }
            }
        }

        // ==========================================
        // 3. CARDS GRID VIEW (Matushell-style)
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty state message
            Text {
                anchors.centerIn: parent
                visible: currentItems.length === 0
                text: engineModule.searchQuery !== ""
                    ? ("No wallpapers match \"" + engineModule.searchQuery + "\"")
                    : "No wallpapers found in library."
                color: Theme.colors.text_muted ?? "#64748b"
                font.family: Theme.fontFamilyBody ?? "Noto Sans"
                font.pixelSize: 13
            }

            GridView {
                id: cardGrid
                anchors.fill: parent
                clip: true
                cellWidth: Math.floor(width / 4)
                cellHeight: Math.floor(cellWidth * 0.65)
                model: currentItems

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                }

                delegate: Item {
                    id: cardItem
                    required property var modelData
                    required property int index

                    width: cardGrid.cellWidth - 8
                    height: cardGrid.cellHeight - 8
                    anchors.margins: 4

                    readonly property string itemPath: modelData.path || ""
                    readonly property string itemPreview: modelData.preview || ""
                    readonly property string itemTitle: modelData.title || modelData.id || ""
                    readonly property string itemType: modelData.type || "scene"
                    readonly property bool isCurrent: {
                        if (!engineModule.activeWallpaper || !itemPath) return false;
                        var act = engineModule.activeWallpaper.toLowerCase();
                        var curPath = itemPath.toLowerCase();
                        var curPrev = itemPreview.toLowerCase();
                        return act === curPath || act === curPrev || act.endsWith(itemTitle.toLowerCase());
                    }

                    Rectangle {
                        id: cardBody
                        anchors.fill: parent
                        radius: 10
                        color: Theme.colors.card_bg ?? "#121216"
                        clip: true
                        scale: cardMouse.containsMouse ? 1.03 : 1.0
                        border.width: cardItem.isCurrent ? 2 : (cardMouse.containsMouse ? 1.5 : 1)
                        border.color: cardItem.isCurrent
                            ? (Theme.colors.accent ?? "#7aa2f7")
                            : (cardMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.hover_bg ?? "#24242e"))

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.animFast ?? 120
                                easing.type: Easing.OutQuad
                            }
                        }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast ?? 100 } }

                        // Crisp High-Resolution Static or Cached Preview Image
                        Image {
                            id: previewImg
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(400, 260)
                            source: {
                                if (!cardItem.itemPreview) return "";
                                return cardItem.itemPreview.indexOf("://") !== -1
                                    ? cardItem.itemPreview
                                    : "file://" + cardItem.itemPreview;
                            }
                        }

                        // Gradient shading at bottom for readability
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 38
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: "#d9000000" }
                            }
                        }

                        // Title text at bottom
                        Text {
                            anchors.left: parent.left
                            anchors.right: typeChip.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            text: cardItem.itemTitle
                            font.family: Theme.fontFamilyBody ?? "Noto Sans"
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideMiddle
                            color: "#ffffff"
                        }

                        // Bottom-right type chip (scene/video/image)
                        Rectangle {
                            id: typeChip
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            width: 20
                            height: 20
                            radius: 10
                            color: "#b3000000"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: cardItem.itemType === "video" ? "movie" : (cardItem.itemType === "scene" ? "animation" : "image")
                                iconSize: 12
                                color: "#ffffff"
                            }
                        }

                        // Top-right Current checkmark badge
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 22
                            height: 22
                            radius: 11
                            visible: cardItem.isCurrent
                            color: Theme.colors.accent ?? "#7aa2f7"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 14
                                color: Theme.colors.bg ?? "#000000"
                            }
                        }

                        // Click mouse area
                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                cardGrid.currentIndex = cardItem.index;
                                engineModule.applyItem(cardItem.modelData);
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 4. BOTTOM STATUS HINT BAR
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            spacing: 6

            Text {
                text: "󰅁 󰅂 Browse • ↵ Apply • Esc Close"
                font.family: Theme.fontFamilyNerd ?? "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: Theme.colors.text_muted ?? "#64748b"
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Active: " + Theme.currentThemeName
                font.family: Theme.fontFamilyBody ?? "Noto Sans"
                font.pixelSize: 11
                font.bold: true
                color: Theme.colors.accent ?? "#7aa2f7"
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
