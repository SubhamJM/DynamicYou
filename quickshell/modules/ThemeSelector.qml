import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell.Io
import qs
import qs.luciddocks
import qs.lucidui as Lucid

FocusScope {
    id: picker
    anchors.fill: parent
    focus: true

    property var notch: null
    property alias searchInput: searchInput
    property var themes: []
    property string applyError: ""
    property bool scanFailed: false
    property bool stripReady: false
    property int refreshGeneration: 0
    property string activeName: ""
    property bool opening: true
    readonly property var results: {
        const query = searchInput.text.trim().toLowerCase().replace(/^(>themes?|>)/, "").trim();
        return themes.filter(theme => !query || [theme.themeName, theme.rawName].some(name => name.toLowerCase().includes(query)));
    }
    readonly property var activeTheme: themes.find(theme => {
        const active = picker.activeName.toLowerCase().trim();
        return theme.rawName.toLowerCase() === active || theme.themeName.toLowerCase().trim() === active;
    }) ?? null
    readonly property var selected: results[strip.currentIndex] ?? null

    function forceThemeFocus() {
        if (picker.notch && picker.notch.activeMode === "theme") {
            picker.opening = true;
            activeNameReader.running = false;
            activeNameReader.running = true;
        }
        searchInput.forceActiveFocus();
    }

    function resetSearch() {
        searchInput.clear();
        applyError = "";
        centerActive();
    }

    function centerActive() {
        const activeName = activeTheme?.rawName ?? "";
        const index = results.findIndex(theme => theme.rawName === activeName);
        strip.setIndexImmediate(results.length ? Math.max(0, index) : -1);
    }

    function refreshStrip() {
        const generation = ++refreshGeneration;
        Qt.callLater(() => {
            if (generation === picker.refreshGeneration) picker.centerActive();
        });
    }

    function applyTheme(name) {
        if (!name || Theme.presetApplying) return;
        applyError = "";
        Theme.applyPreset(name);
    }

    function dismiss() {
        if (searchInput.text !== "") {
            searchInput.clear();
            searchInput.forceActiveFocus();
        } else if (notch) {
            notch.collapseToIdle();
        }
    }

    function openWallpapers() {
        if (notch) notch.switchMode("wallpaper", true);
    }

    onResultsChanged: {
        if (stripReady) refreshStrip();
    }
    Component.onCompleted: {
        stripReady = true;
        refreshStrip();
        forceThemeFocus();
    }
    Keys.onLeftPressed: event => { strip.step(-1); event.accepted = true; }
    Keys.onRightPressed: event => { strip.step(1); event.accepted = true; }
    Keys.onEscapePressed: event => { dismiss(); event.accepted = true; }
    Keys.onReturnPressed: event => { strip.activateCurrent(); event.accepted = true; }
    Keys.onEnterPressed: event => { strip.activateCurrent(); event.accepted = true; }

    Connections {
        target: Theme
        function onCurrentThemeNameChanged() {
            picker.activeName = Theme.currentThemeName;
            if (picker.notch && picker.notch.activeMode === "theme") picker.centerActive();
        }
        function onPresetApplyFinished(success) {
            if (!success) {
                picker.applyError = "Couldn’t apply this theme. Try again.";
            } else if (picker.notch && picker.notch.activeMode === "theme") {
                picker.notch.collapseToIdle();
            }
        }
    }

    Process {
        id: activeNameReader
        command: ["cat", Theme.activeThemeDir + "/theme-name.txt"]
        stdout: StdioCollector {
            onStreamFinished: {
                picker.activeName = text.trim() || Theme.currentThemeName;
                picker.centerActive();
                revealTimer.restart();
            }
        }
        onExited: code => {
            if (code !== 0) {
                picker.activeName = Theme.currentThemeName;
                picker.centerActive();
                revealTimer.restart();
            }
        }
    }
    Timer {
        id: revealTimer
        interval: 1
        onTriggered: {
            if (!scanner.running && !activeNameReader.running) picker.opening = false;
            else restart();
        }
    }

    Process {
        id: scanner
        running: true
        command: ["python3", NotchConfig.scriptsDir + "/theme_scanner.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const entries = JSON.parse(text);
                    if (!Array.isArray(entries)) throw new Error("Expected a list of themes");
                    picker.scanFailed = false;
                    picker.themes = entries;
                    if (picker.opening) revealTimer.restart();
                } catch (error) {
                    picker.scanFailed = true;
                    console.warn("Could not read theme list:", error);
                }
            }
        }
        onExited: code => { if (code !== 0) picker.scanFailed = true; }
    }

    Item {
        id: strip
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.bottom: statusLine.top
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        visible: picker.results.length > 0 && !picker.opening
        property int currentIndex: -1
        property bool immediate: true
        readonly property int heroW: 180
        readonly property int midW: 124
        readonly property int smallW: 77
        readonly property int gap: 10

        function setIndexImmediate(index) {
            immediate = true;
            currentIndex = index;
            Qt.callLater(() => strip.immediate = false);
        }
        function step(direction) {
            if (!picker.results.length || Theme.presetApplying) return;
            immediate = false;
            currentIndex = Math.max(0, Math.min(picker.results.length - 1, currentIndex + direction));
        }
        function activateCurrent() {
            if (picker.selected) picker.applyTheme(picker.selected.rawName);
        }
        function cardWidth(distance) {
            return heroW;
        }
        function offset(distance) {
            let result = heroW / 2 + gap;
            for (let i = 1; i < distance; i++) result += cardWidth(i) + gap;
            return result;
        }
        onCurrentIndexChanged: picker.applyError = ""

        Repeater {
            model: picker.results
            delegate: Rectangle {
                id: swatch
                required property var modelData
                required property int index
                readonly property int distance: Math.abs(index - strip.currentIndex)
                readonly property bool active: modelData.rawName === picker.activeTheme?.rawName
                width: strip.cardWidth(distance)
                height: 100
                x: (strip.width - width) / 2 + (index - strip.currentIndex) * (strip.heroW + strip.gap)
                y: (strip.height - height) / 2
                z: 10 - distance
                radius: 16
                opacity: distance < 2 ? 1 : 0.55
                color: modelData.cardBg || Theme.bgTile
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: swatch.color }
                    GradientStop { position: 1; color: Qt.tint(swatch.color, Theme.alpha(swatch.modelData.accentColor || Theme.accent, 0.2)) }
                }
                Behavior on x { enabled: !strip.immediate && !picker.opening; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on opacity { enabled: !strip.immediate && !picker.opening; NumberAnimation { duration: 180 } }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.bottom: paletteBar.top
                    anchors.bottomMargin: 10
                    text: swatch.modelData.themeName
                    color: swatch.modelData.textColor || Theme.text
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: swatch.distance === 0 ? 20 : 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    visible: swatch.distance < 2
                }
                Text {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 10
                    text: "✓"
                    color: swatch.modelData.accentColor || Theme.accent
                    font.pixelSize: 15
                    visible: swatch.active
                }
                Row {
                    id: paletteBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: swatch.distance === 0 ? 14 : 7
                    height: swatch.distance === 0 ? 10 : 6
                    Repeater {
                        model: swatch.modelData.palette || []
                        Rectangle {
                            required property color modelData
                            width: paletteBar.width / Math.max(1, swatch.modelData.palette.length)
                            height: paletteBar.height
                            color: modelData
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !Theme.presetApplying
                    onClicked: {
                        if (strip.currentIndex === swatch.index) strip.activateCurrent();
                        else { strip.immediate = false; strip.currentIndex = swatch.index; }
                    }
                }
            }
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => { strip.step(event.angleDelta.y < 0 || event.angleDelta.x < 0 ? 1 : -1); event.accepted = true; }
        }
    }

    Text {
        anchors.centerIn: strip
        visible: picker.results.length === 0 && !picker.opening
        text: picker.scanFailed ? "Couldn’t load themes"
            : scanner.running ? "Loading themes…"
            : searchInput.text.trim() !== "" ? "No matching themes" : "No installed themes"
        color: Theme.subtext
        font.family: Theme.fontFamilyBody
        font.pixelSize: 14
    }

    Text {
        id: statusLine
        anchors.bottom: searchBar.top
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        height: 17
        visible: !picker.opening
        text: picker.applyError || (Theme.presetApplying ? "Applying…"
            : picker.selected ? picker.selected.themeName
                + (picker.selected.rawName === picker.activeTheme?.rawName ? "  ·  Active" : "")
                + "  ·  " + (strip.currentIndex + 1) + " / " + picker.results.length : "")
        color: picker.applyError ? Theme.error : Theme.subtext
        font.family: Theme.fontFamilyBody
        font.pixelSize: 11
    }

    Rectangle {
        id: searchBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 12
        height: 40
        radius: 12
        color: Theme.alpha(Theme.text, searchInput.activeFocus ? 0.10 : 0.06)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 6
            spacing: 8

            Lucid.Icon {
                name: "search"
                size: 15
                color: Theme.subtext
            }

            Controls.TextField {
                id: searchInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 4
                background: null
                placeholderText: "Search themes"
                placeholderTextColor: Theme.subtext
                font.family: Theme.fontFamilyBody
                font.pixelSize: 13
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.fgAccent

                Keys.onLeftPressed: event => {
                    if (cursorPosition === 0) {
                        strip.step(-1);
                        event.accepted = true;
                    }
                }
                Keys.onRightPressed: event => {
                    if (cursorPosition === text.length) {
                        strip.step(1);
                        event.accepted = true;
                    }
                }
                Keys.onUpPressed: event => { strip.step(-1); event.accepted = true; }
                Keys.onDownPressed: event => { strip.step(1); event.accepted = true; }
                Keys.onTabPressed: event => {
                    if (picker.notch) {
                        picker.openWallpapers();
                        event.accepted = true;
                    }
                }
                Keys.onEscapePressed: event => { picker.dismiss(); event.accepted = true; }
                Keys.onReturnPressed: event => { strip.activateCurrent(); event.accepted = true; }
                Keys.onEnterPressed: event => { strip.activateCurrent(); event.accepted = true; }
                onTextEdited: {
                    if (/^>wall(?:paper(?:s)?)?$/i.test(text.trim())) picker.openWallpapers();
                }
            }

            PickerButton {
                text: "Wallpapers"
                visible: picker.notch !== null
                onClicked: picker.openWallpapers()
            }

            PickerButton {
                text: "Apply"
                primary: true
                enabled: picker.selected !== null && !Theme.presetApplying
                onClicked: strip.activateCurrent()
            }
        }
    }

    component PickerButton: Controls.Button {
        id: button
        property bool primary: false
        implicitHeight: 32
        leftPadding: 12
        rightPadding: 12
        focusPolicy: Qt.NoFocus
        hoverEnabled: true

        contentItem: Text {
            text: button.text
            font.family: Theme.fontFamilyBody
            font.pixelSize: 12
            color: button.primary && button.enabled ? (Theme.fgPrimary || "#101014") : Theme.text
            opacity: button.enabled ? 1 : 0.4
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 9
            color: button.primary && button.enabled ? Theme.accent
                : Theme.alpha(Theme.text, button.hovered && button.enabled ? 0.14 : 0.07)
        }
    }
}
