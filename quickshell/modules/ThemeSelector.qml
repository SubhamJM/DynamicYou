import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: themeSelector
    spacing: 6
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true
    Keys.forwardTo: [searchInput]

    Keys.onLeftPressed: (event) => {
        carousel.decrementCurrentIndex();
        event.accepted = true;
    }
    Keys.onRightPressed: (event) => {
        carousel.incrementCurrentIndex();
        event.accepted = true;
    }
    Keys.onUpPressed: (event) => {
        carousel.decrementCurrentIndex();
        event.accepted = true;
    }
    Keys.onDownPressed: (event) => {
        carousel.incrementCurrentIndex();
        event.accepted = true;
    }
    Keys.onReturnPressed: (event) => {
        themeSelector.applyCurrentTheme();
        event.accepted = true;
    }
    Keys.onEnterPressed: (event) => {
        themeSelector.applyCurrentTheme();
        event.accepted = true;
    }
    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    property alias searchInput: searchInput
    property alias carousel: carousel
    property var allThemes: []
    property var filteredThemes: []

    Component.onCompleted: {
        themeSelector.scanThemes();
    }

    Connections {
        target: Theme
        function onCurrentThemeNameChanged() {
            themeSelector.selectActiveTheme(false);
        }
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode === "theme") {
                themeSelector.resetSearch();
                Qt.callLater(() => {
                    themeSelector.selectActiveTheme(false);
                    searchInput.forceActiveFocus();
                });
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (allThemes.length === 0) {
                themeSelector.scanThemes();
            } else {
                filterThemes();
                selectActiveTheme(false);
            }
            searchInput.forceActiveFocus();
        }
    }

    function forceThemeFocus() {
        searchInput.forceActiveFocus();
    }

    function resetSearch() {
        if (searchInput.text !== "") {
            searchInput.text = "";
        }
        filterThemes();
        selectActiveTheme(false);
    }

    function filterThemes() {
        var q = searchInput.text.trim().toLowerCase();
        if (!q) {
            filteredThemes = allThemes.slice();
        } else {
            filteredThemes = allThemes.filter(function(t) {
                return (t.themeName && t.themeName.toLowerCase().indexOf(q) !== -1) ||
                       (t.rawName && t.rawName.toLowerCase().indexOf(q) !== -1);
            });
        }
    }

    function selectActiveTheme(animate) {
        var cur = (Theme.currentThemeName || "").toLowerCase().trim();
        var foundIdx = -1;
        for (var i = 0; i < filteredThemes.length; i++) {
            var item = filteredThemes[i];
            if ((item.rawName && item.rawName.toLowerCase().trim() === cur) ||
                (item.themeName && item.themeName.toLowerCase().trim() === cur)) {
                foundIdx = i;
                break;
            }
        }
        if (foundIdx >= 0) {
            if (!animate) carousel.highlightMoveDuration = 0;
            carousel.currentIndex = foundIdx;
            carousel.positionViewAtIndex(foundIdx, PathView.Center);
            if (!animate) Qt.callLater(() => carousel.highlightMoveDuration = 180);
        } else if (filteredThemes.length > 0) {
            carousel.currentIndex = 0;
            carousel.positionViewAtIndex(0, PathView.Center);
        }
    }

    function applyCurrentTheme() {
        if (carousel.currentIndex >= 0 && carousel.currentIndex < filteredThemes.length) {
            var t = filteredThemes[carousel.currentIndex];
            if (t && t.rawName) {
                var home = Quickshell.env("HOME") || "/home/ricing";
                var scriptPath = home + "/.config/scripts/apply-theme.sh";
                Quickshell.execDetached(["bash", scriptPath, t.rawName]);
                Theme.currentThemeName = t.rawName;
                root.activeMode = "idle";
            }
        }
    }

    function scanThemes() {
        if (themeScanner.running) themeScanner.running = false;
        Qt.callLater(() => {
            themeScanner.running = true;
        });
    }

    // Scans all themes in ~/.config/themes via python helper
    Process {
        id: themeScanner
        running: false
        command: ["python3", (Quickshell.shellDir || Quickshell.configDir) + "/scripts/theme_scanner.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    if (Array.isArray(data)) {
                        allThemes = data;
                        themeSelector.filterThemes();
                        Qt.callLater(() => themeSelector.selectActiveTheme(false));
                    }
                } catch(e) {
                    console.error("Theme JSON parse error:", e);
                }
            }
        }
    }

    // ==========================================
    // TOP BAR: Search Field & Index Counter
    // ==========================================
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        // Back to Utility Button
        Rectangle {
            width: 24; height: 24; radius: 7
            color: themeBackMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
            border.width: 0
            scale: themeBackMouse.pressed ? 0.90 : 1.0
            Behavior on scale { NumberAnimation { duration: 90 } }

            Text {
                anchors.centerIn: parent
                text: "󰁍"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.colors.text_primary ?? "#c0caf5"
            }

            MouseArea {
                id: themeBackMouse
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.switchMode("utility", true)
            }
        }

        // Search Icon
        Text {
            text: "⌕"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: searchInput.activeFocus ? (Theme.colors.accent ?? "#2dd4bf") : (Theme.colors.text_secondary ?? "#6c7086")
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Search TextField
        TextField {
            id: searchInput
            focus: true
            selectByMouse: true
            Layout.fillWidth: true
            color: Theme.colors.text_primary ?? "#ffffff"
            font.family: "Inter"
            font.pixelSize: 13
            placeholderText: "Search themes..."
            placeholderTextColor: Theme.colors.text_secondary ?? "#565f89"
            background: Item {}
            leftPadding: 0

            onTextChanged: {
                themeSelector.filterThemes();
                if (themeSelector.filteredThemes.length > 0) {
                    carousel.currentIndex = 0;
                    carousel.positionViewAtIndex(0, PathView.Center);
                }
            }

            Keys.onLeftPressed: (event) => {
                if (cursorPosition === 0 || text.length === 0) {
                    carousel.decrementCurrentIndex();
                    event.accepted = true;
                }
            }
            Keys.onRightPressed: (event) => {
                if (cursorPosition === text.length || text.length === 0) {
                    carousel.incrementCurrentIndex();
                    event.accepted = true;
                }
            }
            Keys.onUpPressed: (event) => {
                carousel.decrementCurrentIndex();
                event.accepted = true;
            }
            Keys.onDownPressed: (event) => {
                carousel.incrementCurrentIndex();
                event.accepted = true;
            }
            Keys.onTabPressed: (event) => {
                carousel.incrementCurrentIndex();
                event.accepted = true;
            }
            Keys.onBacktabPressed: (event) => {
                carousel.decrementCurrentIndex();
                event.accepted = true;
            }
            Keys.onReturnPressed: (event) => {
                themeSelector.applyCurrentTheme();
                event.accepted = true;
            }
            Keys.onEnterPressed: (event) => {
                themeSelector.applyCurrentTheme();
                event.accepted = true;
            }
            Keys.onEscapePressed: (event) => {
                root.activeMode = "idle";
                event.accepted = true;
            }
        }

        // Counter (e.g. 2/19)
        Text {
            text: themeSelector.filteredThemes.length > 0 
                ? (carousel.currentIndex + 1) + "/" + themeSelector.filteredThemes.length 
                : "0/0"
            font.family: "Inter"
            font.pixelSize: 12
            color: Theme.colors.text_secondary ?? "#6c7086"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // ==========================================
    // CENTER: Horizontal 3D Looping Carousel
    // ==========================================
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 110

        Text {
            anchors.centerIn: parent
            visible: themeSelector.filteredThemes.length === 0 && !themeScanner.running
            text: "No matching themes found"
            font.family: "Inter"
            font.pixelSize: 13
            color: Theme.colors.text_secondary ?? "#6c7086"
        }

        RowLayout {
            anchors.fill: parent
            visible: themeSelector.filteredThemes.length > 0
            spacing: 8

            Rectangle {
                id: leftArrow
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: leftArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: 0
                Behavior on color { ColorAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅁"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                    color: leftArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                }
                MouseArea {
                    id: leftArrowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        carousel.decrementCurrentIndex();
                        themeSelector.forceThemeFocus();
                    }
                }
            }

            PathView {
                id: carousel
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true
                model: themeSelector.filteredThemes

                pathItemCount: 5
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 180

                readonly property real itemWidth: 176
                readonly property real itemHeight: 104

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: Qt.PointingHandCursor
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0) carousel.incrementCurrentIndex();
                        else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0) carousel.decrementCurrentIndex();
                    }
                }

                path: Path {
                    startX: -carousel.itemWidth * 0.35
                    startY: carousel.height / 2
                    PathAttribute { name: "itemScale"; value: 0.60 }
                    PathAttribute { name: "itemOpacity"; value: 0.0 }
                    PathAttribute { name: "itemZ"; value: 1 }
                    PathAttribute { name: "itemRotationY"; value: -38.0 }

                    PathLine {
                        x: carousel.width * 0.22
                        y: carousel.height / 2
                    }
                    PathAttribute { name: "itemScale"; value: 0.82 }
                    PathAttribute { name: "itemOpacity"; value: 0.65 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemRotationY"; value: -24.0 }

                    PathLine {
                        x: carousel.width * 0.50
                        y: carousel.height / 2
                    }
                    PathAttribute { name: "itemScale"; value: 1.0 }
                    PathAttribute { name: "itemOpacity"; value: 1.0 }
                    PathAttribute { name: "itemZ"; value: 30 }
                    PathAttribute { name: "itemRotationY"; value: 0.0 }

                    PathLine {
                        x: carousel.width * 0.78
                        y: carousel.height / 2
                    }
                    PathAttribute { name: "itemScale"; value: 0.82 }
                    PathAttribute { name: "itemOpacity"; value: 0.65 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemRotationY"; value: 24.0 }

                    PathLine {
                        x: carousel.width + (carousel.itemWidth * 0.35)
                        y: carousel.height / 2
                    }
                    PathAttribute { name: "itemScale"; value: 0.60 }
                    PathAttribute { name: "itemOpacity"; value: 0.0 }
                    PathAttribute { name: "itemZ"; value: 1 }
                    PathAttribute { name: "itemRotationY"; value: 38.0 }
                }

                delegate: Item {
                    id: delegateRoot
                    width: carousel.itemWidth
                    height: carousel.itemHeight

                    scale: PathView.itemScale ?? 0.8
                    opacity: PathView.itemOpacity ?? 0.0
                    z: PathView.itemZ ?? 1
                    visible: opacity > 0.01

                    readonly property bool isCurrent: PathView.isCurrentItem
                    readonly property bool isCurrentActive: {
                        var cur = (Theme.currentThemeName || "").toLowerCase().trim();
                        return ((modelData.rawName || "").toLowerCase().trim() === cur) ||
                               ((modelData.themeName || "").toLowerCase().trim() === cur);
                    }

                    transform: Rotation {
                        origin.x: delegateRoot.width / 2
                        origin.y: delegateRoot.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: PathView.itemRotationY ?? 0
                    }

                    Rectangle {
                        id: cardRect
                        anchors.fill: parent
                        radius: 16
                        color: modelData.cardBg || "#181825"

                        border.width: 0

                        // Active desktop theme indicator dot (top-right corner)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 10
                            anchors.rightMargin: 10
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.colors.accent ?? "#2dd4bf"
                            visible: delegateRoot.isCurrentActive
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 12

                            // 6 Palette Color Dots (ANSI colors 1-6)
                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 7

                                Repeater {
                                    model: (modelData.palette && modelData.palette.length >= 6) 
                                        ? modelData.palette.slice(0, 6) 
                                        : ["#ef4444", "#10b981", "#f59e0b", "#3b82f6", "#8b5cf6", "#06b6d4"]

                                    Rectangle {
                                        width: 13
                                        height: 13
                                        radius: 6.5
                                        color: modelData
                                    }
                                }
                            }

                            // Theme Name Label
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.themeName || ""
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: delegateRoot.isCurrent ? Font.DemiBold : Font.Normal
                                color: delegateRoot.isCurrent ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#9399b2")
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (carousel.currentIndex === index) {
                                    themeSelector.applyCurrentTheme();
                                } else {
                                    carousel.currentIndex = index;
                                }
                                themeSelector.forceThemeFocus();
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: rightArrow
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: rightArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: 0
                Behavior on color { ColorAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅂"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                    color: rightArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                }
                MouseArea {
                    id: rightArrowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        carousel.incrementCurrentIndex();
                        themeSelector.forceThemeFocus();
                    }
                }
            }
        }
    }

    // ==========================================
    // FOOTER: "Enter to apply"
    // ==========================================
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 18
        Layout.rightMargin: 12
        Layout.leftMargin: 12

        Item { Layout.fillWidth: true }

        Text {
            text: "Enter to apply"
            font.family: "Inter"
            font.pixelSize: 11
            color: Theme.colors.text_secondary ?? "#6c7086"
            opacity: footerMouse.containsMouse ? 1.0 : 0.8
            Behavior on opacity { NumberAnimation { duration: 120 } }

            MouseArea {
                id: footerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: themeSelector.applyCurrentTheme()
            }
        }
    }
}
