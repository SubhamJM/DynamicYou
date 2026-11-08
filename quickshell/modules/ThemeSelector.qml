import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.lucidui
import qs.luciddocks
import "../"

FocusScope {
    id: themeSelector
    anchors.fill: parent
    focus: true
    Keys.forwardTo: (searchInput) ? [searchInput] : []

    property alias searchInput: searchInput
    property var allThemes: []
    property var filteredThemes: []
    property int selectedIndex: 0

    function getThemeGlyph(name) {
        var n = (name || "").toLowerCase();
        if (n.indexOf("abyss") !== -1) return "water_drop";
        if (n.indexOf("afterglow") !== -1) return "auto_awesome";
        if (n.indexOf("astral") !== -1) return "diamond";
        if (n.indexOf("cloud") !== -1) return "cloud";
        if (n.indexOf("crimson") !== -1) return "bolt";
        if (n.indexOf("cyber") !== -1) return "terminal";
        if (n.indexOf("frost") !== -1) return "ac_unit";
        if (n.indexOf("serenity") !== -1) return "eco";
        if (n.indexOf("solstice") !== -1) return "wb_sunny";
        if (n.indexOf("verdant") !== -1) return "spa";
        return "palette";
    }

    function applyThemeAt(idx) {
        if (idx >= 0 && idx < filteredThemes.length) {
            var t = filteredThemes[idx];
            if (t && t.rawName) {
                var home = Quickshell.env("HOME") || "";
                var cmd = `
                    for s in "$HOME/.local/bin/apply-theme.sh" "$HOME/.config/scripts/apply-theme.sh" "$HOME/git/MyLinuxSetup/scripts/apply-theme.sh" "$HOME/.config/hypr/scripts/apply-theme.sh"; do
                        if [ -x "$s" ] || [ -f "$s" ]; then
                            exec bash "$s" "${t.rawName}"
                        fi
                    done
                    apply-theme.sh "${t.rawName}"
                `;
                Quickshell.execDetached(["bash", "-c", cmd]);
                Theme.currentThemeName = t.rawName;
                if (typeof root !== "undefined") root.activeMode = "idle";
            }
        }
    }

    function applyCurrentTheme() {
        themeSelector.applyThemeAt(themeSelector.selectedIndex);
    }

    Keys.onLeftPressed: (event) => {
        if (themeSelector.filteredThemes.length > 0) {
            themeSelector.selectedIndex = Math.max(0, themeSelector.selectedIndex - 1);
        }
        event.accepted = true;
    }
    Keys.onRightPressed: (event) => {
        if (themeSelector.filteredThemes.length > 0) {
            themeSelector.selectedIndex = Math.min(themeSelector.filteredThemes.length - 1, themeSelector.selectedIndex + 1);
        }
        event.accepted = true;
    }
    Keys.onUpPressed: (event) => {
        if (themeSelector.filteredThemes.length > 0) {
            themeSelector.selectedIndex = Math.max(0, themeSelector.selectedIndex - 5);
        }
        event.accepted = true;
    }
    Keys.onDownPressed: (event) => {
        if (themeSelector.filteredThemes.length > 0) {
            themeSelector.selectedIndex = Math.min(themeSelector.filteredThemes.length - 1, themeSelector.selectedIndex + 5);
        }
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
    Keys.onSpacePressed: (event) => {
        themeSelector.applyCurrentTheme();
        event.accepted = true;
    }
    Keys.onEscapePressed: (event) => {
        if (typeof root !== "undefined") root.collapseToIdle();
        event.accepted = true;
    }
    Keys.onTabPressed: (event) => {
        if (typeof root !== "undefined") root.switchMode("wallpaper", true);
        event.accepted = true;
    }

    Component.onCompleted: {
        themeSelector.scanThemes();
        Qt.callLater(() => {
            if (searchInput) searchInput.forceActiveFocus();
        });
    }

    Connections {
        target: Theme
        function onCurrentThemeNameChanged() {
            themeSelector.selectActiveTheme();
        }
    }

    Connections {
        target: (typeof root !== "undefined") ? root : null
        function onActiveModeChanged() {
            if (root.activeMode === "theme") {
                themeSelector.resetSearch();
                Qt.callLater(() => {
                    themeSelector.selectActiveTheme();
                    if (searchInput) searchInput.forceActiveFocus();
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
                selectActiveTheme();
            }
            if (searchInput) searchInput.forceActiveFocus();
        }
    }

    function forceThemeFocus() {
        if (searchInput) searchInput.forceActiveFocus();
    }

    function resetSearch() {
        if (searchInput && searchInput.text !== "") {
            searchInput.text = "";
        }
        filterThemes();
        selectActiveTheme();
    }

    function filterThemes() {
        var q = (searchInput ? searchInput.text : "").trim().toLowerCase();
        if (q.startsWith(">theme")) {
            q = q.substring(6).trim();
        } else if (q.startsWith(">")) {
            q = q.substring(1).trim();
        }

        if (!q) {
            filteredThemes = allThemes.slice();
        } else {
            filteredThemes = allThemes.filter(function(t) {
                return (t.themeName && t.themeName.toLowerCase().indexOf(q) !== -1) ||
                       (t.rawName && t.rawName.toLowerCase().indexOf(q) !== -1);
            });
        }
        themeSelector.selectedIndex = 0;
    }

    function selectActiveTheme() {
        var cur = (Theme.currentThemeName || "").toLowerCase().trim();
        for (var i = 0; i < filteredThemes.length; i++) {
            var item = filteredThemes[i];
            if ((item.rawName && item.rawName.toLowerCase().trim() === cur) ||
                (item.themeName && item.themeName.toLowerCase().trim() === cur)) {
                themeSelector.selectedIndex = i;
                break;
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
        command: ["python3", NotchConfig.scriptsDir + "/theme_scanner.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    if (Array.isArray(data)) {
                        allThemes = data;
                        themeSelector.filterThemes();
                        Qt.callLater(() => themeSelector.selectActiveTheme());
                    }
                } catch(e) {
                    console.error("Theme JSON parse error:", e);
                }
            }
        }
    }

    // ==========================================
    // UI LAYOUT (Iris Theme Gallery Grid)
    // ==========================================
    Item {
        anchors.fill: parent

        // ------------------------------------------
        // Center: Iris Theme Cards Grid (5 x 2 layout)
        // ------------------------------------------
        Item {
            id: gridContainer
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.bottom: searchBar.top
            anchors.bottomMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: flowGrid.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Flow {
                    id: flowGrid
                    width: flick.width
                    spacing: 12

                    Repeater {
                        model: themeSelector.filteredThemes

                        Item {
                            id: cardRoot
                            width: Math.floor((flowGrid.width - 4 * flowGrid.spacing) / 5)
                            height: 114

                            readonly property var themeItem: modelData
                            readonly property bool isCurrent: Theme.currentThemeName === themeItem.rawName
                            readonly property bool isHighlighted: themeSelector.selectedIndex === index
                            readonly property color accentCol: themeItem.accentColor || Theme.accent

                            // Concentric Active Selection Ring (Iris 1:1 signature)
                            Rectangle {
                                anchors.fill: plate
                                anchors.margins: -3
                                radius: plate.radius + 3
                                color: "transparent"
                                visible: cardRoot.isCurrent || cardRoot.isHighlighted
                                border.width: 2
                                border.color: cardRoot.accentCol

                                Behavior on border.color { ColorAnimation { duration: 120 } }
                            }

                            // Theme Plate Card
                            Rectangle {
                                id: plate
                                anchors.fill: parent
                                radius: 14
                                color: cardRoot.themeItem.cardBg || "#14141e"
                                border.width: 1
                                border.color: cardMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.22) : Qt.rgba(255, 255, 255, 0.08)
                                scale: cardMouse.pressed ? 0.96 : (cardMouse.containsMouse ? 1.025 : 1.0)
                                clip: true

                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                // Lit 1px top edge rim highlight
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 16
                                    height: 1
                                    color: Qt.rgba(255, 255, 255, 0.16)
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 9
                                    spacing: 4

                                    // Top Header: Glyph + Name + Checkmark Badge
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        Icon {
                                            name: themeSelector.getThemeGlyph(cardRoot.themeItem.rawName)
                                            size: 15
                                            color: cardRoot.accentCol
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: cardRoot.themeItem.themeName || cardRoot.themeItem.rawName
                                            font.family: Theme.fontFamilyBody
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: cardRoot.themeItem.textColor || "#ffffff"
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            visible: cardRoot.isCurrent
                                            width: 15
                                            height: 15
                                            radius: 7.5
                                            color: cardRoot.accentCol

                                            Icon {
                                                anchors.centerIn: parent
                                                name: "check"
                                                size: 10
                                                color: cardRoot.themeItem.cardBg || "#000000"
                                            }
                                        }
                                    }

                                    // Middle Typographic "Aa" Specimen + Tone
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: "Aa"
                                            font.family: Theme.fontFamilyTitle
                                            font.pixelSize: 21
                                            font.bold: true
                                            color: cardRoot.themeItem.textColor || "#ffffff"
                                            opacity: 0.90
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            height: 15
                                            width: cardRoot.themeItem.rawName.length * 6 + 10
                                            radius: 7.5
                                            color: Qt.alpha(cardRoot.accentCol, 0.15)
                                            border.width: 1
                                            border.color: Qt.alpha(cardRoot.accentCol, 0.40)

                                            Text {
                                                anchors.centerIn: parent
                                                text: cardRoot.themeItem.rawName
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: cardRoot.accentCol
                                            }
                                        }
                                    }

                                    // Iris Screen Time Ribbon (multi-color segmented pill)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 6
                                        radius: 3
                                        color: Qt.rgba(255, 255, 255, 0.08)
                                        clip: true

                                        Row {
                                            anchors.fill: parent
                                            spacing: 1.5

                                            readonly property var p: cardRoot.themeItem.palette || []
                                            readonly property var shares: [0.32, 0.22, 0.18, 0.15, 0.13]

                                            Repeater {
                                                model: Math.min(parent.p.length, parent.shares.length)

                                                Rectangle {
                                                    width: Math.floor(parent.parent.width * parent.shares[index])
                                                    height: parent.parent.height
                                                    radius: 2.5
                                                    color: parent.p[index]
                                                }
                                            }
                                        }
                                    }

                                    // Bottom: 6 Palette Dots
                                    Row {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 4

                                        Repeater {
                                            model: (cardRoot.themeItem.palette && cardRoot.themeItem.palette.length >= 6)
                                                ? cardRoot.themeItem.palette.slice(0, 6)
                                                : []

                                            Rectangle {
                                                width: 6
                                                height: 6
                                                radius: 3
                                                color: modelData
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        themeSelector.selectedIndex = index;
                                        themeSelector.applyThemeAt(index);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------
        // Bottom: Material 3 Search Bar Pill (Border-free, White text)
        // ------------------------------------------
        Rectangle {
            id: searchBar
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            height: 48
            radius: 24
            color: searchInput.activeFocus ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.07)
            border.width: 0
            border.color: "transparent"

            Behavior on color { ColorAnimation { duration: 140 } }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    if (searchInput) searchInput.forceActiveFocus();
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8

                // Back Button
                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: backMouse.pressed ? Qt.rgba(255, 255, 255, 0.16) : (backMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent")
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "arrow_back"
                        size: 20
                        color: backMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.75)
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof root !== "undefined") root.collapseToIdle();
                        }
                    }
                }

                // Input + Ghost Placeholder Container
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: searchInput.text === ""
                        text: ">theme"
                        font.family: Theme.fontFamilyBody
                        font.pixelSize: 14
                        color: Qt.rgba(255, 255, 255, 0.65)
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamilyBody
                        font.pixelSize: 14
                        color: "#ffffff"
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.fgAccent
                        clip: true

                        onTextChanged: {
                            var t = text.trim().toLowerCase();
                            if (t === ">wallpaper" || t === ">wallpapers" || t === ">wall") {
                                if (typeof root !== "undefined") root.switchMode("wallpaper", true);
                                return;
                            }
                            themeSelector.filterThemes();
                        }

                        Keys.onLeftPressed: (event) => {
                            if (cursorPosition === 0) {
                                themeSelector.selectedIndex = Math.max(0, themeSelector.selectedIndex - 1);
                                event.accepted = true;
                            }
                        }
                        Keys.onRightPressed: (event) => {
                            if (cursorPosition === text.length) {
                                themeSelector.selectedIndex = Math.min(themeSelector.filteredThemes.length - 1, themeSelector.selectedIndex + 1);
                                event.accepted = true;
                            }
                        }
                        Keys.onUpPressed: (event) => {
                            themeSelector.selectedIndex = Math.max(0, themeSelector.selectedIndex - 5);
                            event.accepted = true;
                        }
                        Keys.onDownPressed: (event) => {
                            themeSelector.selectedIndex = Math.min(themeSelector.filteredThemes.length - 1, themeSelector.selectedIndex + 5);
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
                            if (searchInput.text !== "") {
                                searchInput.text = "";
                            } else if (typeof root !== "undefined") {
                                root.collapseToIdle();
                            }
                            event.accepted = true;
                        }
                        Keys.onTabPressed: (event) => {
                            if (typeof root !== "undefined") root.switchMode("wallpaper", true);
                            event.accepted = true;
                        }
                    }
                }

                // Clear button
                Rectangle {
                    visible: searchInput.text !== ""
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    radius: 12
                    color: clearMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 16
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                    }
                }

                // Switch to Wallpapers Button
                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: wallBtnRow.implicitWidth + 24
                    Layout.alignment: Qt.AlignVCenter
                    radius: 16
                    color: wallBtnMouse.pressed ? Qt.rgba(255, 255, 255, 0.18) : (wallBtnMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06))
                    border.width: 1
                    border.color: wallBtnMouse.containsMouse ? Theme.accent : Qt.rgba(255, 255, 255, 0.12)

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Row {
                        id: wallBtnRow
                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "wallpaper"
                            size: 16
                            color: Theme.accent
                        }

                        LText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "labelMedium"
                            text: "Wallpapers"
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        id: wallBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof root !== "undefined") root.switchMode("wallpaper", true);
                        }
                    }
                }
            }
        }
    }
}
