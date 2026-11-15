import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "./"

Item {
    id: selectorRoot
    anchors.fill: parent
    focus: true

    // ==========================================
    // COMBINED STATE: "theme", "wallpaper", OR "lockscreen"
    // ==========================================
    property string activeTab: (root && root.activeMode === "lockscreen") ? "lockscreen" : ((root && root.activeMode === "wallpaper") ? "wallpaper" : "theme")
    property string lastScannedTheme: ""
    property bool userInteracted: false
    property string lastAppliedWallpaper: ""

    // Lockscreen Data Properties
    property var allLockscreens: []
    property string activeLockscreenId: "dog-samurai"
    property string activeLockscreenName: "Dog Samurai"

    // Theme Data Properties
    property var allThemes: []
    property var filteredThemes: []

    // Aliases for external references in shell.qml
    property alias searchInput: searchInput
    property alias carousel: themeCarousel
    property alias wallpaperGrid: wallpaperCarousel
    property alias lockscreenGrid: lockscreenCarousel

    // Forward keys according to active tab
    Keys.forwardTo: (activeTab === "theme") ? [searchInput, themeCarousel] : ((activeTab === "wallpaper") ? [wallpaperCarousel] : [lockscreenCarousel])

    Keys.onEscapePressed: (event) => {
        if (typeof root !== "undefined") root.collapseToIdle();
        event.accepted = true;
    }

    Keys.onTabPressed: (event) => {
        if (event.modifiers & Qt.ControlModifier) {
            var nextTab = "theme";
            if (selectorRoot.activeTab === "theme") nextTab = "wallpaper";
            else if (selectorRoot.activeTab === "wallpaper") nextTab = "lockscreen";
            else nextTab = "theme";
            selectorRoot.switchTab(nextTab);
            event.accepted = true;
        }
    }

    // ==========================================
    // TAB SWITCHING FUNCTION
    // ==========================================
    function switchTab(tabName) {
        if (tabName === activeTab) return;
        activeTab = tabName;
        if (typeof root !== "undefined") {
            if (tabName === "theme") {
                if (root.activeMode !== "theme") {
                    root.activeMode = "theme";
                }
                Qt.callLater(() => forceThemeFocus());
            } else if (tabName === "wallpaper") {
                if (root.activeMode !== "wallpaper") {
                    root.activeMode = "wallpaper";
                }
                if (wallpaperModel.count === 0 || lastScannedTheme !== Theme.currentThemeName) {
                    scanWallpapers();
                }
                Qt.callLater(() => {
                    if (wallpaperCarousel) wallpaperCarousel.forceActiveFocus();
                });
            } else if (tabName === "lockscreen") {
                if (root.activeMode !== "lockscreen") {
                    root.activeMode = "lockscreen";
                }
                if (selectorRoot.allLockscreens.length === 0) {
                    scanLockscreens();
                }
                Qt.callLater(() => {
                    if (lockscreenCarousel) lockscreenCarousel.forceActiveFocus();
                });
            }
        }
    }

    onActiveTabChanged: {
        if (activeTab === "theme") {
            Qt.callLater(() => forceThemeFocus());
        } else if (activeTab === "wallpaper") {
            if (wallpaperModel.count === 0 || lastScannedTheme !== Theme.currentThemeName) {
                scanWallpapers();
            }
            Qt.callLater(() => {
                if (wallpaperCarousel) wallpaperCarousel.forceActiveFocus();
            });
        } else if (activeTab === "lockscreen") {
            if (allLockscreens.length === 0) {
                scanLockscreens();
            }
            Qt.callLater(() => {
                if (lockscreenCarousel) lockscreenCarousel.forceActiveFocus();
            });
        }
    }

    // ==========================================
    // LIFECYCLE & SIGNALS
    // ==========================================
    Component.onCompleted: {
        scanThemes();
        loadCachedWallpapers();
        scanWallpapers();
        scanLockscreens();
        if (activeTab === "theme") {
            Qt.callLater(() => forceThemeFocus());
        } else if (activeTab === "wallpaper") {
            Qt.callLater(() => {
                if (wallpaperCarousel) wallpaperCarousel.forceActiveFocus();
            });
        } else if (activeTab === "lockscreen") {
            Qt.callLater(() => {
                if (lockscreenCarousel) lockscreenCarousel.forceActiveFocus();
            });
        }
    }

    Connections {
        target: Theme
        function onCurrentThemeNameChanged() {
            selectorRoot.selectActiveTheme(false);
            if (selectorRoot.activeTab === "wallpaper" || (typeof root !== "undefined" && root.activeMode === "wallpaper")) {
                selectorRoot.userInteracted = false;
                selectorRoot.scanWallpapers();
            }
        }
    }

    Connections {
        target: (typeof root !== "undefined") ? root : null
        function onActiveModeChanged() {
            if (root.activeMode === "theme") {
                selectorRoot.activeTab = "theme";
                selectorRoot.resetSearch();
                Qt.callLater(() => {
                    selectorRoot.selectActiveTheme(false);
                    searchInput.forceActiveFocus();
                });
            } else if (root.activeMode === "wallpaper") {
                selectorRoot.activeTab = "wallpaper";
                selectorRoot.userInteracted = false;
                selectorRoot.loadCachedWallpapers();
                selectorRoot.scanWallpapers();
                Qt.callLater(() => {
                    if (wallpaperCarousel) wallpaperCarousel.forceActiveFocus();
                });
            } else if (root.activeMode === "lockscreen") {
                selectorRoot.activeTab = "lockscreen";
                selectorRoot.scanLockscreens();
                Qt.callLater(() => {
                    if (lockscreenCarousel) lockscreenCarousel.forceActiveFocus();
                });
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (typeof root !== "undefined" && root.activeMode === "wallpaper") {
                selectorRoot.activeTab = "wallpaper";
            } else if (typeof root !== "undefined" && root.activeMode === "theme") {
                selectorRoot.activeTab = "theme";
            } else if (typeof root !== "undefined" && root.activeMode === "lockscreen") {
                selectorRoot.activeTab = "lockscreen";
            }

            if (selectorRoot.activeTab === "theme") {
                if (allThemes.length === 0) {
                    scanThemes();
                } else {
                    filterThemes();
                    selectActiveTheme(false);
                }
                searchInput.forceActiveFocus();
            } else if (selectorRoot.activeTab === "wallpaper") {
                userInteracted = false;
                loadCachedWallpapers();
                scanWallpapers();
                Qt.callLater(() => {
                    if (wallpaperCarousel) wallpaperCarousel.forceActiveFocus();
                });
            } else if (selectorRoot.activeTab === "lockscreen") {
                scanLockscreens();
                Qt.callLater(() => {
                    if (lockscreenCarousel) lockscreenCarousel.forceActiveFocus();
                });
            }
        }
    }

    // ==========================================
    // THEME LOGIC & FUNCTIONS
    // ==========================================
    function forceThemeFocus() {
        if (searchInput) searchInput.forceActiveFocus();
    }

    function resetSearch() {
        if (searchInput && searchInput.text !== "") {
            searchInput.text = "";
        }
        filterThemes();
        selectActiveTheme(false);
    }

    function filterThemes() {
        var q = searchInput ? searchInput.text.trim().toLowerCase() : "";
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
            if (!animate) themeCarousel.highlightMoveDuration = 0;
            themeCarousel.currentIndex = foundIdx;
            themeCarousel.positionViewAtIndex(foundIdx, PathView.Center);
            if (!animate) Qt.callLater(() => themeCarousel.highlightMoveDuration = 180);
        } else if (filteredThemes.length > 0) {
            themeCarousel.currentIndex = 0;
            themeCarousel.positionViewAtIndex(0, PathView.Center);
        }
    }

    function applyCurrentTheme() {
        if (themeCarousel.currentIndex >= 0 && themeCarousel.currentIndex < filteredThemes.length) {
            var t = filteredThemes[themeCarousel.currentIndex];
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
                if (typeof root !== "undefined") root.collapseToIdle();
            }
        }
    }

    function scanThemes() {
        if (themeScanner.running) themeScanner.running = false;
        Qt.callLater(() => {
            themeScanner.running = true;
        });
    }

    Process {
        id: themeScanner
        running: false
        command: ["python3", NotchConfig.scriptsDir + "/theme_scanner.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    if (Array.isArray(data)) {
                        selectorRoot.allThemes = data;
                        selectorRoot.filterThemes();
                        Qt.callLater(() => selectorRoot.selectActiveTheme(false));
                    }
                } catch(e) {
                    console.error("Theme JSON parse error:", e);
                }
            }
        }
    }

    // ==========================================
    // LOCKSCREEN LOGIC & FUNCTIONS
    // ==========================================
    function forceLockscreenFocus() {
        if (lockscreenCarousel) lockscreenCarousel.forceActiveFocus();
    }

    function scanLockscreens() {
        if (lockscreenScanner.running) lockscreenScanner.running = false;
        Qt.callLater(() => {
            lockscreenScanner.running = true;
        });
    }

    Process {
        id: lockscreenScanner
        running: false
        command: ["python3", NotchConfig.scriptsDir + "/lockscreen_scanner.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var data = JSON.parse(this.text.trim());
                    if (Array.isArray(data)) {
                        selectorRoot.allLockscreens = data;
                        for (var i = 0; i < data.length; i++) {
                            if (data[i].isActive) {
                                selectorRoot.activeLockscreenId = data[i].id;
                                selectorRoot.activeLockscreenName = data[i].name;
                                if (lockscreenCarousel) {
                                    lockscreenCarousel.currentIndex = i;
                                    lockscreenCarousel.positionViewAtIndex(i, PathView.Center);
                                }
                                break;
                            }
                        }
                    }
                } catch(e) {
                    console.error("Lockscreen JSON parse error:", e);
                }
            }
        }
    }

    function applyLockscreen(idx) {
        if (idx >= 0 && idx < allLockscreens.length) {
            var item = allLockscreens[idx];
            if (!item || !item.id) return;
            selectorRoot.activeLockscreenId = item.id;
            selectorRoot.activeLockscreenName = item.name;

            var updated = [];
            for (var i = 0; i < allLockscreens.length; i++) {
                var copy = Object.assign({}, allLockscreens[i]);
                copy.isActive = (copy.id === item.id);
                updated.push(copy);
            }
            selectorRoot.allLockscreens = updated;

            Quickshell.execDetached([
                "bash",
                NotchConfig.scriptsDir + "/apply_lockscreen.sh",
                item.id
            ]);
        }
    }

    function lockSessionNow() {
        if (typeof root !== "undefined") root.collapseToIdle();
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.local/bin/lock-screen.sh"]);
    }

    // ==========================================
    // WALLPAPER LOGIC & FUNCTIONS
    // ==========================================
    ListModel { id: wallpaperModel }

    function loadCachedWallpapers() {
        if (typeof root !== "undefined" && root.cachedWallpapers && root.cachedWallpapers.length > 0) {
            if (wallpaperModel.count === 0) {
                wallpaperModel.clear();
                for (var j = 0; j < root.cachedWallpapers.length; j++) {
                    wallpaperModel.append(root.cachedWallpapers[j]);
                }
                var actWall = root.cachedActiveWallpaper || selectorRoot.lastAppliedWallpaper;
                var targetIdx = 0;
                if (actWall !== "") {
                    for (var k = 0; k < wallpaperModel.count; k++) {
                        var fPath = wallpaperModel.get(k).filePath;
                        if (fPath === actWall || actWall.endsWith(wallpaperModel.get(k).fileName)) {
                            targetIdx = k;
                            break;
                        }
                    }
                }
                wallpaperCarousel.highlightMoveDuration = 0;
                wallpaperCarousel.currentIndex = targetIdx;
                wallpaperCarousel.positionViewAtIndex(targetIdx, PathView.Center);
                restoreAnimTimer.restart();
            }
        }
    }

    function scanWallpapers() {
        selectorRoot.lastScannedTheme = Theme.currentThemeName || "";
        if (wallpaperScanner.running) wallpaperScanner.running = false;
        Qt.callLater(() => {
            if (selectorRoot.activeTab === "wallpaper" || (typeof root !== "undefined" && root.activeMode === "wallpaper") || visible) {
                wallpaperScanner.running = true;
            }
        });
    }

    Process {
        id: wallpaperScanner
        running: false
        command: ["sh", "-c", `python3 -c "
import os, glob, subprocess

theme = '${Theme.currentThemeName}'.strip()
if not theme or theme.lower() == 'default':
    name_file = os.path.expanduser('~/.config/active-theme/theme-name.txt')
    if os.path.exists(name_file):
        try:
            with open(name_file, 'r') as f:
                t = f.read().strip()
                if t: theme = t
        except Exception:
            pass

theme_lower = theme.lower()

candidates = [
    os.path.expanduser(f'~/Pictures/Wallpapers/{theme}'),
    os.path.expanduser(f'~/Pictures/Wallpapers/{theme_lower}'),
    os.path.expanduser(f'~/git/DynamicYou/Wallpapers/{theme}'),
    os.path.expanduser(f'~/git/DynamicYou/Wallpapers/{theme_lower}'),
    os.path.expanduser(f'~/git/MyLinuxSetup/Wallpapers/{theme}'),
    os.path.expanduser(f'~/git/MyLinuxSetup/Wallpapers/{theme_lower}'),
    os.path.expanduser(f'~/rice/Wallpapers/{theme}'),
    os.path.expanduser(f'~/current/Wallpapers/{theme}')
]
wall_dir = ''
for c in candidates:
    if os.path.isdir(c):
        wall_dir = c
        break

if not wall_dir:
    for base in [os.path.expanduser('~/Pictures/Wallpapers'), os.path.expanduser('~/git/DynamicYou/Wallpapers'), os.path.expanduser('~/git/MyLinuxSetup/Wallpapers'), os.path.expanduser('~/rice/Wallpapers'), os.path.expanduser('~/current/Wallpapers')]:
        if os.path.isdir(base):
            for d in os.listdir(base):
                if d.lower() == theme_lower and os.path.isdir(os.path.join(base, d)):
                    wall_dir = os.path.join(base, d)
                    break
        if wall_dir:
            break

active_wall = ''
try:
    p = subprocess.run(['awww', 'query'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    for line in p.stdout.splitlines():
        if 'image:' in line.lower():
            active_wall = line.split('image:', 1)[1].strip()
            break
        elif line.strip():
            active_wall = line.strip().split()[-1]
            break
except Exception:
    pass

exts = ('.jpg', '.jpeg', '.png', '.webp')
files = []
if wall_dir and os.path.exists(wall_dir):
    for root_dir, dirs, fnames in os.walk(wall_dir, followlinks=True):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for fn in fnames:
            if fn.lower().endswith(exts) and not fn.startswith('.'):
                files.append(os.path.join(root_dir, fn))

if not files:
    for base in [os.path.expanduser('~/Pictures/Wallpapers'), os.path.expanduser('~/git/MyLinuxSetup/Wallpapers'), os.path.expanduser('~/rice/Wallpapers'), os.path.expanduser('~/Pictures')]:
        if os.path.isdir(base):
            for root_dir, dirs, fnames in os.walk(base, followlinks=True):
                dirs[:] = [d for d in dirs if not d.startswith('.')]
                for fn in fnames:
                    if fn.lower().endswith(exts) and not fn.startswith('.'):
                        files.append(os.path.join(root_dir, fn))

sorted_files = sorted(list(set(files)))
for f in sorted_files:
    name = os.path.basename(f)
    print(f'{name}|||{f}|||{active_wall}')
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                var temp = [];
                var activeFromQuery = "";

                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 2) {
                        temp.push({
                            "fileName": parts[0],
                            "filePath": parts[1]
                        });
                        if (parts.length >= 3 && parts[2].trim() !== "") {
                            activeFromQuery = parts[2].trim();
                        }
                    }
                }

                if (activeFromQuery !== "") {
                    selectorRoot.lastAppliedWallpaper = activeFromQuery;
                }

                if (temp.length > 0) {
                    if (typeof root !== "undefined") {
                        root.cachedWallpapers = temp;
                        if (activeFromQuery !== "") root.cachedActiveWallpaper = activeFromQuery;
                    }
                }

                var isDifferent = (temp.length !== wallpaperModel.count);
                if (!isDifferent) {
                    for (var m = 0; m < temp.length; m++) {
                        if (wallpaperModel.get(m).filePath !== temp[m].filePath) {
                            isDifferent = true;
                            break;
                        }
                    }
                }

                if (isDifferent) {
                    wallpaperModel.clear();
                    for (var j = 0; j < temp.length; j++) {
                        wallpaperModel.append(temp[j]);
                    }
                }

                if (!selectorRoot.userInteracted && wallpaperModel.count > 0) {
                    var targetIdx = 0;
                    var checkWall = selectorRoot.lastAppliedWallpaper || activeFromQuery;
                    if (checkWall !== "") {
                        for (var k = 0; k < wallpaperModel.count; k++) {
                            var fPath = wallpaperModel.get(k).filePath;
                            if (fPath === checkWall || checkWall.endsWith(wallpaperModel.get(k).fileName)) {
                                targetIdx = k;
                                break;
                            }
                        }
                    }
                    if (wallpaperCarousel.currentIndex !== targetIdx || isDifferent) {
                        wallpaperCarousel.highlightMoveDuration = 0;
                        wallpaperCarousel.currentIndex = targetIdx;
                        wallpaperCarousel.positionViewAtIndex(targetIdx, PathView.Center);
                        restoreAnimTimer.restart();
                    }
                    if (selectorRoot.activeTab === "wallpaper") {
                        Qt.callLater(() => wallpaperCarousel.forceActiveFocus());
                    }
                } else if (selectorRoot.userInteracted) {
                    if (wallpaperCarousel.currentIndex >= wallpaperModel.count) {
                        wallpaperCarousel.currentIndex = Math.max(0, wallpaperModel.count - 1);
                    }
                }
            }
        }
    }

    Timer {
        id: restoreAnimTimer
        interval: 60
        repeat: false
        onTriggered: wallpaperCarousel.highlightMoveDuration = 200
    }

    function applyWallpaper(idx) {
        if (idx >= 0 && idx < wallpaperModel.count) {
            var path = wallpaperModel.get(idx).filePath;
            selectorRoot.lastAppliedWallpaper = path;
            if (typeof root !== "undefined") {
                root.cachedActiveWallpaper = path;
            }
            var trans = (Theme.activeTransition && Theme.activeTransition.trim()) || "simple";
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.config/quickshell/scripts/apply_wallpaper.sh",
                path,
                trans
            ]);
            if (typeof root !== "undefined") root.collapseToIdle();
        }
    }

    // ==========================================
    // MAIN LAYOUT
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ==========================================
        // 1. TOP BAR: Back + Context Controls + Top-Right Tabs
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 8

            // Back to Utility Button
            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: backBtnMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: 0
                scale: backBtnMouse.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.colors.text_primary ?? "#c0caf5"
                }

                MouseArea {
                    id: backBtnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (typeof root !== "undefined") root.switchMode("utility", true);
                    }
                }
            }

            // --- THEME CONTEXT: Search + Count ---
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: selectorRoot.activeTab === "theme"
                spacing: 8

                Text {
                    text: "⌕"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: searchInput.activeFocus ? (Theme.colors.accent ?? "#2dd4bf") : (Theme.colors.text_secondary ?? "#6c7086")
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                TextField {
                    id: searchInput
                    focus: selectorRoot.activeTab === "theme"
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
                        selectorRoot.filterThemes();
                        if (selectorRoot.filteredThemes.length > 0) {
                            themeCarousel.currentIndex = 0;
                            themeCarousel.positionViewAtIndex(0, PathView.Center);
                        }
                    }

                    Keys.onLeftPressed: (event) => {
                        if (cursorPosition === 0 || text.length === 0) {
                            themeCarousel.decrementCurrentIndex();
                            event.accepted = true;
                        }
                    }
                    Keys.onRightPressed: (event) => {
                        if (cursorPosition === text.length || text.length === 0) {
                            themeCarousel.incrementCurrentIndex();
                            event.accepted = true;
                        }
                    }
                    Keys.onUpPressed: (event) => {
                        themeCarousel.decrementCurrentIndex();
                        event.accepted = true;
                    }
                    Keys.onDownPressed: (event) => {
                        themeCarousel.incrementCurrentIndex();
                        event.accepted = true;
                    }
                    Keys.onTabPressed: (event) => {
                        if (event.modifiers & Qt.ControlModifier) {
                            selectorRoot.switchTab("wallpaper");
                            event.accepted = true;
                        } else {
                            themeCarousel.incrementCurrentIndex();
                            event.accepted = true;
                        }
                    }
                    Keys.onBacktabPressed: (event) => {
                        themeCarousel.decrementCurrentIndex();
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: (event) => {
                        selectorRoot.applyCurrentTheme();
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: (event) => {
                        selectorRoot.applyCurrentTheme();
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: (event) => {
                        if (typeof root !== "undefined") root.collapseToIdle();
                        event.accepted = true;
                    }
                }

                Text {
                    text: selectorRoot.filteredThemes.length > 0 
                        ? (themeCarousel.currentIndex + 1) + "/" + selectorRoot.filteredThemes.length 
                        : "0/0"
                    font.family: "Inter"
                    font.pixelSize: 12
                    color: Theme.colors.text_secondary ?? "#6c7086"
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // --- WALLPAPER CONTEXT: Title + Count + Active Theme Badge ---
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: selectorRoot.activeTab === "wallpaper"
                spacing: 8

                Text {
                    text: "Wallpapers"
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.bold: true
                    color: Theme.colors.text_primary ?? "white"
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    visible: wallpaperModel.count > 0
                    text: "(" + (wallpaperCarousel.currentIndex + 1) + " / " + wallpaperModel.count + ")"
                    font.family: "Inter"
                    font.pixelSize: 12
                    color: Theme.colors.text_secondary ?? "#565f89"
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: activeThemeBadgeRow.implicitWidth + 14
                    radius: 11
                    color: Qt.alpha(Theme.colors.accent ?? "#7aa2f7", 0.12)
                    border.width: 1
                    border.color: Qt.alpha(Theme.colors.accent ?? "#7aa2f7", 0.25)
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        id: activeThemeBadgeRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "palette"
                            iconSize: 11
                            color: Theme.colors.accent ?? "#7aa2f7"
                        }

                        Text {
                            text: Theme.currentThemeName || "Default"
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.colors.accent ?? "#7aa2f7"
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // --- LOCKSCREEN CONTEXT: Title + Count + Active Badge + Lock Now ---
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: selectorRoot.activeTab === "lockscreen"
                spacing: 8

                Text {
                    text: "Lock Screens"
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.bold: true
                    color: Theme.colors.text_primary ?? "white"
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    visible: selectorRoot.allLockscreens.length > 0
                    text: "(" + (lockscreenCarousel.currentIndex + 1) + " / " + selectorRoot.allLockscreens.length + ")"
                    font.family: "Inter"
                    font.pixelSize: 12
                    color: Theme.colors.text_secondary ?? "#565f89"
                    Layout.alignment: Qt.AlignVCenter
                }

                // Active Badge
                Rectangle {
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: activeLockBadgeRow.implicitWidth + 14
                    radius: 11
                    color: Qt.alpha(Theme.colors.accent ?? "#7aa2f7", 0.12)
                    border.width: 1
                    border.color: Qt.alpha(Theme.colors.accent ?? "#7aa2f7", 0.25)
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        id: activeLockBadgeRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "lock"
                            iconSize: 11
                            color: Theme.colors.accent ?? "#7aa2f7"
                        }

                        Text {
                            text: selectorRoot.activeLockscreenName
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.colors.accent ?? "#7aa2f7"
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // ==========================================
            // TOP-RIGHT TAB BUTTONS (Theme | Wallpaper | Lockscreen)
            // ==========================================
            Rectangle {
                id: tabPillContainer
                Layout.preferredHeight: 26
                Layout.preferredWidth: tabButtonsRow.implicitWidth + 4
                Layout.alignment: Qt.AlignVCenter
                radius: 13
                color: Theme.colors.card_bg ?? "#181825"
                border.width: 1
                border.color: Qt.alpha(Theme.colors.text_primary ?? "#ffffff", 0.08)

                RowLayout {
                    id: tabButtonsRow
                    anchors.centerIn: parent
                    spacing: 2

                    // Tab Button: Theme
                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: themeTabInnerRow.implicitWidth + 16
                        radius: 11
                        color: selectorRoot.activeTab === "theme"
                            ? (Theme.colors.accent ?? "#7aa2f7")
                            : (themeTabMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            id: themeTabInnerRow
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                text: "palette"
                                iconSize: 13
                                fill: selectorRoot.activeTab === "theme" ? 1 : 0
                                color: selectorRoot.activeTab === "theme"
                                    ? (Theme.colors.bg ?? "#101318")
                                    : (themeTabMouse.containsMouse ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#6c7086"))
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            Text {
                                text: "Theme"
                                font.family: "Inter"
                                font.pixelSize: 11
                                font.weight: selectorRoot.activeTab === "theme" ? Font.Bold : Font.Normal
                                color: selectorRoot.activeTab === "theme"
                                    ? (Theme.colors.bg ?? "#101318")
                                    : (themeTabMouse.containsMouse ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#6c7086"))
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }

                        MouseArea {
                            id: themeTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: selectorRoot.switchTab("theme")
                        }
                    }

                    // Tab Button: Wallpaper
                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: wallTabInnerRow.implicitWidth + 16
                        radius: 11
                        color: selectorRoot.activeTab === "wallpaper"
                            ? (Theme.colors.accent ?? "#7aa2f7")
                            : (wallTabMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            id: wallTabInnerRow
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                text: "wallpaper"
                                iconSize: 13
                                fill: selectorRoot.activeTab === "wallpaper" ? 1 : 0
                                color: selectorRoot.activeTab === "wallpaper"
                                    ? (Theme.colors.bg ?? "#101318")
                                    : (wallTabMouse.containsMouse ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#6c7086"))
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            Text {
                                text: "Wallpaper"
                                font.family: "Inter"
                                font.pixelSize: 11
                                font.weight: selectorRoot.activeTab === "wallpaper" ? Font.Bold : Font.Normal
                                color: selectorRoot.activeTab === "wallpaper"
                                    ? (Theme.colors.bg ?? "#101318")
                                    : (wallTabMouse.containsMouse ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#6c7086"))
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }

                        MouseArea {
                            id: wallTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: selectorRoot.switchTab("wallpaper")
                        }
                    }

                    // Tab Button: Lockscreen
                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: lockTabInnerRow.implicitWidth + 16
                        radius: 11
                        color: selectorRoot.activeTab === "lockscreen"
                            ? (Theme.colors.accent ?? "#7aa2f7")
                            : (lockTabMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            id: lockTabInnerRow
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                text: "lock"
                                iconSize: 13
                                fill: selectorRoot.activeTab === "lockscreen" ? 1 : 0
                                color: selectorRoot.activeTab === "lockscreen"
                                    ? (Theme.colors.bg ?? "#101318")
                                    : (lockTabMouse.containsMouse ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#6c7086"))
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            Text {
                                text: "Lockscreen"
                                font.family: "Inter"
                                font.pixelSize: 11
                                font.weight: selectorRoot.activeTab === "lockscreen" ? Font.Bold : Font.Normal
                                color: selectorRoot.activeTab === "lockscreen"
                                    ? (Theme.colors.bg ?? "#101318")
                                    : (lockTabMouse.containsMouse ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#6c7086"))
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }

                        MouseArea {
                            id: lockTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: selectorRoot.switchTab("lockscreen")
                        }
                    }
                }
            }
        }

        // ==========================================
        // 2. BODY CONTENT (Theme View & Wallpaper View)
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ------------------------------------------
            // TAB A: THEME SELECTOR VIEW
            // ------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                visible: selectorRoot.activeTab === "theme"
                spacing: 6

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: selectorRoot.filteredThemes.length === 0 && !themeScanner.running
                        text: "No matching themes found"
                        font.family: "Inter"
                        font.pixelSize: 13
                        color: Theme.colors.text_secondary ?? "#6c7086"
                    }

                    RowLayout {
                        anchors.fill: parent
                        visible: selectorRoot.filteredThemes.length > 0
                        spacing: 8

                        Rectangle {
                            id: leftThemeArrow
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: leftThemeArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅁"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                color: leftThemeArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                            }
                            MouseArea {
                                id: leftThemeArrowMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    themeCarousel.decrementCurrentIndex();
                                    selectorRoot.forceThemeFocus();
                                }
                            }
                        }

                        PathView {
                            id: themeCarousel
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            focus: selectorRoot.activeTab === "theme"
                            model: selectorRoot.filteredThemes

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
                                    if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0) themeCarousel.incrementCurrentIndex();
                                    else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0) themeCarousel.decrementCurrentIndex();
                                }
                            }

                            path: Path {
                                startX: -themeCarousel.itemWidth * 0.35
                                startY: themeCarousel.height / 2
                                PathAttribute { name: "itemScale"; value: 0.60 }
                                PathAttribute { name: "itemOpacity"; value: 0.0 }
                                PathAttribute { name: "itemZ"; value: 1 }
                                PathAttribute { name: "itemRotationY"; value: -38.0 }

                                PathLine {
                                    x: themeCarousel.width * 0.22
                                    y: themeCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 0.82 }
                                PathAttribute { name: "itemOpacity"; value: 0.65 }
                                PathAttribute { name: "itemZ"; value: 10 }
                                PathAttribute { name: "itemRotationY"; value: -24.0 }

                                PathLine {
                                    x: themeCarousel.width * 0.50
                                    y: themeCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 1.0 }
                                PathAttribute { name: "itemOpacity"; value: 1.0 }
                                PathAttribute { name: "itemZ"; value: 30 }
                                PathAttribute { name: "itemRotationY"; value: 0.0 }

                                PathLine {
                                    x: themeCarousel.width * 0.78
                                    y: themeCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 0.82 }
                                PathAttribute { name: "itemOpacity"; value: 0.65 }
                                PathAttribute { name: "itemZ"; value: 10 }
                                PathAttribute { name: "itemRotationY"; value: 24.0 }

                                PathLine {
                                    x: themeCarousel.width + (themeCarousel.itemWidth * 0.35)
                                    y: themeCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 0.60 }
                                PathAttribute { name: "itemOpacity"; value: 0.0 }
                                PathAttribute { name: "itemZ"; value: 1 }
                                PathAttribute { name: "itemRotationY"; value: 38.0 }
                            }

                            delegate: Item {
                                id: themeDelegateRoot
                                width: themeCarousel.itemWidth
                                height: themeCarousel.itemHeight

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
                                    origin.x: themeDelegateRoot.width / 2
                                    origin.y: themeDelegateRoot.height / 2
                                    axis { x: 0; y: 1; z: 0 }
                                    angle: PathView.itemRotationY ?? 0
                                }

                                Rectangle {
                                    id: cardRect
                                    anchors.fill: parent
                                    radius: 16
                                    color: modelData.cardBg || "#181825"
                                    border.width: 0

                                    // Active desktop theme indicator dot
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: 10
                                        anchors.rightMargin: 10
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Theme.colors.accent ?? "#2dd4bf"
                                        visible: themeDelegateRoot.isCurrentActive
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
                                            font.weight: themeDelegateRoot.isCurrent ? Font.DemiBold : Font.Normal
                                            color: themeDelegateRoot.isCurrent ? (Theme.colors.text_primary ?? "#ffffff") : (Theme.colors.text_secondary ?? "#9399b2")
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (themeCarousel.currentIndex === index) {
                                                selectorRoot.applyCurrentTheme();
                                            } else {
                                                themeCarousel.currentIndex = index;
                                            }
                                            selectorRoot.forceThemeFocus();
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: rightThemeArrow
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: rightThemeArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                color: rightThemeArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                            }
                            MouseArea {
                                id: rightThemeArrowMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    themeCarousel.incrementCurrentIndex();
                                    selectorRoot.forceThemeFocus();
                                }
                            }
                        }
                    }
                }

                // Theme Footer: Hint + "Enter to apply"
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4

                    Text {
                        text: "󰅁 󰅂 Navigate • ↵ Apply"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: Theme.colors.text_secondary ?? "#565f89"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Enter to apply"
                        font.family: "Inter"
                        font.pixelSize: 11
                        color: Theme.colors.text_secondary ?? "#6c7086"
                        opacity: themeFooterMouse.containsMouse ? 1.0 : 0.8
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        MouseArea {
                            id: themeFooterMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: selectorRoot.applyCurrentTheme()
                        }
                    }
                }
            }

            // ------------------------------------------
            // TAB B: WALLPAPER SELECTOR VIEW
            // ------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                visible: selectorRoot.activeTab === "wallpaper"
                spacing: 6

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: wallpaperModel.count === 0 && !wallpaperScanner.running
                        text: "No wallpapers found for " + (Theme.currentThemeName || "theme")
                        color: Theme.colors.text_secondary ?? "#565f89"
                        font.pixelSize: 13
                    }

                    RowLayout {
                        anchors.fill: parent
                        visible: wallpaperModel.count > 0
                        spacing: 8

                        Rectangle {
                            id: leftWallArrow
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: leftWallArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅁"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                color: leftWallArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                            }
                            MouseArea {
                                id: leftWallArrowMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selectorRoot.userInteracted = true;
                                    wallpaperCarousel.decrementCurrentIndex();
                                    wallpaperCarousel.forceActiveFocus();
                                }
                            }
                        }

                        PathView {
                            id: wallpaperCarousel
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            focus: selectorRoot.activeTab === "wallpaper"
                            model: wallpaperModel

                            pathItemCount: 5
                            preferredHighlightBegin: 0.5
                            preferredHighlightEnd: 0.5
                            highlightRangeMode: PathView.StrictlyEnforceRange
                            highlightMoveDuration: 200
                            onMovementStarted: selectorRoot.userInteracted = true

                            readonly property real itemWidth: Math.min(270, Math.max(160, width * 0.44))
                            readonly property real itemHeight: height * 0.88

                            Keys.onLeftPressed: (event) => {
                                selectorRoot.userInteracted = true;
                                decrementCurrentIndex();
                                event.accepted = true;
                            }
                            Keys.onRightPressed: (event) => {
                                selectorRoot.userInteracted = true;
                                incrementCurrentIndex();
                                event.accepted = true;
                            }
                            Keys.onUpPressed: (event) => {
                                selectorRoot.userInteracted = true;
                                decrementCurrentIndex();
                                event.accepted = true;
                            }
                            Keys.onDownPressed: (event) => {
                                selectorRoot.userInteracted = true;
                                incrementCurrentIndex();
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: (event) => {
                                applySelected();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: (event) => {
                                applySelected();
                                event.accepted = true;
                            }
                            Keys.onEscapePressed: (event) => {
                                if (typeof root !== "undefined") root.collapseToIdle();
                                event.accepted = true;
                            }

                            function applySelected() {
                                selectorRoot.applyWallpaper(currentIndex);
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.PointingHandCursor
                                onWheel: (wheel) => {
                                    wheel.accepted = true;
                                    selectorRoot.userInteracted = true;
                                    if (wheel.angleDelta.y < 0) wallpaperCarousel.incrementCurrentIndex();
                                    else if (wheel.angleDelta.y > 0) wallpaperCarousel.decrementCurrentIndex();
                                }
                            }

                            path: Path {
                                startX: -wallpaperCarousel.itemWidth * 0.35
                                startY: wallpaperCarousel.height / 2
                                PathAttribute { name: "itemScale"; value: 0.55 }
                                PathAttribute { name: "itemOpacity"; value: 0.0 }
                                PathAttribute { name: "itemZ"; value: 1 }
                                PathAttribute { name: "itemRotationY"; value: -42.0 }

                                PathLine {
                                    x: wallpaperCarousel.width * 0.22
                                    y: wallpaperCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 0.80 }
                                PathAttribute { name: "itemOpacity"; value: 0.65 }
                                PathAttribute { name: "itemZ"; value: 10 }
                                PathAttribute { name: "itemRotationY"; value: -28.0 }

                                PathLine {
                                    x: wallpaperCarousel.width * 0.50
                                    y: wallpaperCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 1.0 }
                                PathAttribute { name: "itemOpacity"; value: 1.0 }
                                PathAttribute { name: "itemZ"; value: 30 }
                                PathAttribute { name: "itemRotationY"; value: 0.0 }

                                PathLine {
                                    x: wallpaperCarousel.width * 0.78
                                    y: wallpaperCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 0.80 }
                                PathAttribute { name: "itemOpacity"; value: 0.65 }
                                PathAttribute { name: "itemZ"; value: 10 }
                                PathAttribute { name: "itemRotationY"; value: 28.0 }

                                PathLine {
                                    x: wallpaperCarousel.width + (wallpaperCarousel.itemWidth * 0.35)
                                    y: wallpaperCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 0.55 }
                                PathAttribute { name: "itemOpacity"; value: 0.0 }
                                PathAttribute { name: "itemZ"; value: 1 }
                                PathAttribute { name: "itemRotationY"; value: 42.0 }
                            }

                            delegate: Item {
                                id: wallDelegateRoot
                                width: wallpaperCarousel.itemWidth
                                height: wallpaperCarousel.itemHeight

                                scale: PathView.itemScale ?? 0.8
                                opacity: PathView.itemOpacity ?? 0.0
                                z: PathView.itemZ ?? 1
                                visible: opacity > 0.01

                                transform: Rotation {
                                    origin.x: wallDelegateRoot.width / 2
                                    origin.y: wallDelegateRoot.height / 2
                                    axis { x: 0; y: 1; z: 0 }
                                    angle: PathView.itemRotationY ?? 0
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: Theme.colors.card_bg ?? "#1f2335"
                                    border.width: 0
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: filePath ? ("file://" + filePath) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                        mipmap: false
                                        sourceSize.width: 480
                                        sourceSize.height: 300
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        selectorRoot.userInteracted = true;
                                        if (PathView.isCurrentItem) {
                                            wallpaperCarousel.applySelected();
                                        } else {
                                            wallpaperCarousel.currentIndex = index;
                                        }
                                        wallpaperCarousel.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: rightWallArrow
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: rightWallArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                color: rightWallArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                            }
                            MouseArea {
                                id: rightWallArrowMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selectorRoot.userInteracted = true;
                                    wallpaperCarousel.incrementCurrentIndex();
                                    wallpaperCarousel.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // Wallpaper Footer: Navigate hints + Apply button
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    spacing: 8

                    Text {
                        text: "󰅁 󰅂 Navigate • ↵ Apply"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: Theme.colors.text_secondary ?? "#565f89"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 120; Layout.preferredHeight: 28
                        radius: 8
                        color: applyWallMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.hover_bg ?? "#24283b")
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Apply"
                            font.bold: true; font.pixelSize: 12
                            color: applyWallMouse.containsMouse ? (Theme.colors.bg ?? "#000000") : (Theme.colors.text_primary ?? "white")
                        }
                        MouseArea {
                            id: applyWallMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (wallpaperModel.count > 0) wallpaperCarousel.applySelected();
                            }
                        }
                    }
                }
            }

            // ------------------------------------------
            // TAB C: LOCKSCREEN SELECTOR VIEW
            // ------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                visible: selectorRoot.activeTab === "lockscreen"
                spacing: 6

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: selectorRoot.allLockscreens.length === 0 && !lockscreenScanner.running
                        text: "No lock screens found"
                        font.family: "Inter"
                        font.pixelSize: 13
                        color: Theme.colors.text_secondary ?? "#6c7086"
                    }

                    RowLayout {
                        anchors.fill: parent
                        visible: selectorRoot.allLockscreens.length > 0
                        spacing: 8

                        Rectangle {
                            id: leftLockArrow
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: leftLockArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅁"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                color: leftLockArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                            }
                            MouseArea {
                                id: leftLockArrowMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    lockscreenCarousel.decrementCurrentIndex();
                                    lockscreenCarousel.forceActiveFocus();
                                }
                            }
                        }

                        PathView {
                            id: lockscreenCarousel
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            focus: selectorRoot.activeTab === "lockscreen"
                            model: selectorRoot.allLockscreens

                            pathItemCount: 5
                            preferredHighlightBegin: 0.5
                            preferredHighlightEnd: 0.5
                            highlightRangeMode: PathView.StrictlyEnforceRange
                            highlightMoveDuration: 200

                            readonly property real itemWidth: Math.min(270, Math.max(160, width * 0.44))
                            readonly property real itemHeight: height * 0.88

                            Keys.onLeftPressed: (event) => {
                                decrementCurrentIndex();
                                event.accepted = true;
                            }
                            Keys.onRightPressed: (event) => {
                                incrementCurrentIndex();
                                event.accepted = true;
                            }
                            Keys.onUpPressed: (event) => {
                                decrementCurrentIndex();
                                event.accepted = true;
                            }
                            Keys.onDownPressed: (event) => {
                                incrementCurrentIndex();
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: (event) => {
                                applySelected();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: (event) => {
                                applySelected();
                                event.accepted = true;
                            }
                            Keys.onEscapePressed: (event) => {
                                if (typeof root !== "undefined") root.collapseToIdle();
                                event.accepted = true;
                            }

                            function applySelected() {
                                selectorRoot.applyLockscreen(currentIndex);
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.PointingHandCursor
                                onWheel: (wheel) => {
                                    wheel.accepted = true;
                                    if (wheel.angleDelta.y < 0) lockscreenCarousel.incrementCurrentIndex();
                                    else if (wheel.angleDelta.y > 0) lockscreenCarousel.decrementCurrentIndex();
                                }
                            }

                            path: Path {
                                startX: -lockscreenCarousel.itemWidth * 0.35
                                startY: lockscreenCarousel.height / 2
                                PathAttribute { name: "itemScale"; value: 0.55 }
                                PathAttribute { name: "itemOpacity"; value: 0.0 }
                                PathAttribute { name: "itemZ"; value: 1 }
                                PathAttribute { name: "itemRotationY"; value: -42.0 }

                                PathLine {
                                    x: lockscreenCarousel.width * 0.22
                                    y: lockscreenCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 0.80 }
                                PathAttribute { name: "itemOpacity"; value: 0.65 }
                                PathAttribute { name: "itemZ"; value: 10 }
                                PathAttribute { name: "itemRotationY"; value: -28.0 }

                                PathLine {
                                    x: lockscreenCarousel.width * 0.50
                                    y: lockscreenCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 1.0 }
                                PathAttribute { name: "itemOpacity"; value: 1.0 }
                                PathAttribute { name: "itemZ"; value: 30 }
                                PathAttribute { name: "itemRotationY"; value: 0.0 }

                                PathLine {
                                    x: lockscreenCarousel.width * 0.78
                                    y: lockscreenCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 0.80 }
                                PathAttribute { name: "itemOpacity"; value: 0.65 }
                                PathAttribute { name: "itemZ"; value: 10 }
                                PathAttribute { name: "itemRotationY"; value: 28.0 }

                                PathLine {
                                    x: lockscreenCarousel.width + (lockscreenCarousel.itemWidth * 0.35)
                                    y: lockscreenCarousel.height / 2
                                }
                                PathAttribute { name: "itemScale"; value: 0.55 }
                                PathAttribute { name: "itemOpacity"; value: 0.0 }
                                PathAttribute { name: "itemZ"; value: 1 }
                                PathAttribute { name: "itemRotationY"; value: 42.0 }
                            }

                            delegate: Item {
                                id: lockDelegateRoot
                                width: lockscreenCarousel.itemWidth
                                height: lockscreenCarousel.itemHeight

                                scale: PathView.itemScale ?? 0.8
                                opacity: PathView.itemOpacity ?? 0.0
                                z: PathView.itemZ ?? 1
                                visible: opacity > 0.01

                                transform: Rotation {
                                    origin.x: lockDelegateRoot.width / 2
                                    origin.y: lockDelegateRoot.height / 2
                                    axis { x: 0; y: 1; z: 0 }
                                    angle: PathView.itemRotationY ?? 0
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: Theme.colors.card_bg ?? "#1f2335"
                                    border.width: lockCardMouse.containsMouse ? 1 : 0
                                    border.color: lockCardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : "transparent"
                                    clip: true

                                    // Preview Image
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: modelData.preview ? ("file://" + modelData.preview) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                    }

                                    // Dark bottom gradient for legible text
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        radius: 10
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 0.50; color: Qt.rgba(0, 0, 0, 0.15) }
                                            GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.05, 0.08, 0.90) }
                                        }
                                    }

                                    // Active Checkmark Badge (Top-Right)
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        height: 20
                                        width: activeBadgeRow.implicitWidth + 12
                                        radius: 10
                                        color: modelData.accent || (Theme.colors.accent ?? "#7aa2f7")
                                        visible: modelData.isActive

                                        RowLayout {
                                            id: activeBadgeRow
                                            anchors.centerIn: parent
                                            spacing: 3
                                            Text {
                                                text: "󰄬"
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: "#0f172a"
                                            }
                                            Text {
                                                text: "ACTIVE"
                                                font.family: "Inter"
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: "#0f172a"
                                            }
                                        }
                                    }

                                    // Bottom Text (Theme Name Only)
                                    Text {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 12
                                        text: modelData.name
                                        font.family: "Inter"
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: "#ffffff"
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: lockCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (PathView.isCurrentItem) {
                                            lockscreenCarousel.applySelected();
                                        } else {
                                            lockscreenCarousel.currentIndex = index;
                                        }
                                        lockscreenCarousel.forceActiveFocus();
                                    }
                                    onDoubleClicked: {
                                        lockscreenCarousel.applySelected();
                                        if (typeof root !== "undefined") root.collapseToIdle();
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: rightLockArrow
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: rightLockArrowMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                color: rightLockArrowMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.text_secondary ?? "#565f89")
                            }
                            MouseArea {
                                id: rightLockArrowMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    lockscreenCarousel.incrementCurrentIndex();
                                    lockscreenCarousel.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // Lockscreen Footer: Navigation hints + Apply button + Lock Now button
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    spacing: 8

                    Text {
                        text: "󰅁 󰅂 Navigate • ↵ Apply Lockscreen"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: Theme.colors.text_secondary ?? "#565f89"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    // Apply Button
                    Rectangle {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 28
                        radius: 8
                        color: applyLockMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.hover_bg ?? "#24283b")
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Apply"
                            font.bold: true; font.pixelSize: 12
                            color: applyLockMouse.containsMouse ? (Theme.colors.bg ?? "#000000") : (Theme.colors.text_primary ?? "white")
                        }
                        MouseArea {
                            id: applyLockMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (selectorRoot.allLockscreens.length > 0) lockscreenCarousel.applySelected();
                            }
                        }
                    }

                    // Test / Lock Now Button
                    Rectangle {
                        Layout.preferredWidth: 110; Layout.preferredHeight: 28
                        radius: 8
                        color: testLockMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "󰌾"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.colors.accent ?? "#7aa2f7"
                            }
                            Text {
                                text: "Lock Now"
                                font.bold: true; font.pixelSize: 12
                                color: Theme.colors.text_primary ?? "white"
                            }
                        }
                        MouseArea {
                            id: testLockMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (selectorRoot.allLockscreens.length > 0) lockscreenCarousel.applySelected();
                                selectorRoot.lockSessionNow();
                            }
                        }
                    }
                }
            }
        }
    }
}
