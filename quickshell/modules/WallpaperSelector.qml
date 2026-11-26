import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.lucidui
import qs.luciddocks
import qs.lucidprefs as LP
import "../"

FocusScope {
    id: wallModule
    anchors.fill: parent
    focus: true
    Keys.forwardTo: (searchInput) ? [searchInput] : []

    property alias searchInput: searchInput
    property string lastAppliedWallpaper: ""
    property string searchText: ""
    property bool userInteracted: false
    property alias wallpaperGrid: wallStrip

    // Master Wallpaper Model (all discovered wallpapers)
    ListModel { id: fullWallpaperModel }

    // Display Model (filtered by search input)
    ListModel { id: displayModel }

    property string sortMode: "recent" // "recent" (default) | "oldest" | "name_asc" | "name_desc" | "shuffle"
    property bool sortDropdownOpen: false
    property int filterGeneration: 0

    function filterWallpapers() {
        const generation = ++wallModule.filterGeneration;
        const selectedPath = wallModule.userInteracted && wallStrip.currentIndex >= 0 && wallStrip.currentIndex < displayModel.count
            ? displayModel.get(wallStrip.currentIndex).path : "";
        displayModel.clear();
        var q = wallModule.searchText.trim().toLowerCase();
        if (q.startsWith(">wallpaper")) {
            q = q.substring(10).trim();
        } else if (q.startsWith(">")) {
            q = q.substring(1).trim();
        }

        var matched = [];
        var actWall = selectedPath || wallModule.lastAppliedWallpaper;

        for (var i = 0; i < fullWallpaperModel.count; i++) {
            var item = fullWallpaperModel.get(i);
            if (q === "" || item.name.toLowerCase().indexOf(q) !== -1 || item.path.toLowerCase().indexOf(q) !== -1) {
                matched.push({
                    "path": item.path,
                    "name": item.name,
                    "thumb": item.thumb,
                    "mtime": item.mtime || 0,
                    "temp": item.temp
                });
            }
        }

        // Apply selected sort mode (Recent by default)
        if (wallModule.sortMode === "name_asc") {
            matched.sort(function(a, b) {
                return a.name.localeCompare(b.name);
            });
        } else if (wallModule.sortMode === "name_desc") {
            matched.sort(function(a, b) {
                return b.name.localeCompare(a.name);
            });
        } else if (wallModule.sortMode === "oldest") {
            matched.sort(function(a, b) {
                return (a.mtime || 0) - (b.mtime || 0);
            });
        } else if (wallModule.sortMode === "shuffle") {
            for (var s = matched.length - 1; s > 0; s--) {
                var r = Math.floor(Math.random() * (s + 1));
                var tmp = matched[s];
                matched[s] = matched[r];
                matched[r] = tmp;
            }
        } else {
            // "recent" (default): most recent file modification time descending
            matched.sort(function(a, b) {
                return (b.mtime || 0) - (a.mtime || 0);
            });
        }

        var targetIdx = 0;
        for (var m = 0; m < matched.length; m++) {
            displayModel.append(matched[m]);
            if (actWall !== "" && matched[m].path === actWall) {
                targetIdx = m;
            }
        }

        if (displayModel.count > 0 && wallStrip) {
            wallStrip.setIndexImmediate(targetIdx);
        }
    }

    onSearchTextChanged: filterWallpapers()

    Keys.onLeftPressed: (event) => {
        wallModule.userInteracted = true;
        if (wallStrip) wallStrip.step(-1);
        event.accepted = true;
    }
    Keys.onRightPressed: (event) => {
        wallModule.userInteracted = true;
        if (wallStrip) wallStrip.step(1);
        event.accepted = true;
    }
    Keys.onUpPressed: (event) => {
        wallModule.userInteracted = true;
        if (wallStrip) wallStrip.step(-1);
        event.accepted = true;
    }
    Keys.onDownPressed: (event) => {
        wallModule.userInteracted = true;
        if (wallStrip) wallStrip.step(1);
        event.accepted = true;
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Home) {
            wallModule.userInteracted = true;
            if (wallStrip && displayModel.count > 0) wallStrip.setIndexImmediate(0);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            wallModule.userInteracted = true;
            if (wallStrip && displayModel.count > 0) wallStrip.setIndexImmediate(displayModel.count - 1);
            event.accepted = true;
        }
    }
    Keys.onSpacePressed: (event) => {
        if (wallStrip) wallStrip.activateCurrent();
        event.accepted = true;
    }
    Keys.onReturnPressed: (event) => {
        if (wallStrip) wallStrip.activateCurrent();
        event.accepted = true;
    }
    Keys.onEnterPressed: (event) => {
        if (wallStrip) wallStrip.activateCurrent();
        event.accepted = true;
    }
    Keys.onEscapePressed: (event) => {
        if (typeof root !== "undefined") root.collapseToIdle();
        event.accepted = true;
    }
    Keys.onTabPressed: (event) => {
        if (typeof root !== "undefined") root.switchMode("theme", true);
        event.accepted = true;
    }

    function loadCachedWallpapers() {
        if (typeof root !== "undefined" && root.cachedWallpapers && root.cachedWallpapers.length > 0) {
            if (root.cachedActiveWallpaper) wallModule.lastAppliedWallpaper = root.cachedActiveWallpaper;
            if (fullWallpaperModel.count === 0) {
                fullWallpaperModel.clear();
                for (var j = 0; j < root.cachedWallpapers.length; j++) {
                    var cItem = root.cachedWallpapers[j];
                    fullWallpaperModel.append({
                        "name": cItem.name || cItem.fileName || "",
                        "path": cItem.path || cItem.filePath || "",
                        "thumb": cItem.thumb || "",
                        "mtime": cItem.mtime || 0,
                        "temp": cItem.temp || false
                    });
                }
                wallModule.filterWallpapers();
            }
        }
    }

    function openPicker() {
        wallModule.userInteracted = false;
        wallModule.sortDropdownOpen = false;
        if (wallModule.searchText !== "") wallModule.searchText = "";
        if (searchInput && searchInput.text !== "") searchInput.text = "";
        if (fullWallpaperModel.count === 0) {
            wallModule.loadCachedWallpapers();
        } else if (wallStrip && displayModel.count > 0) {
            var activeIdx = 0;
            for (var i = 0; i < displayModel.count; i++) {
                if (wallModule.lastAppliedWallpaper !== "" && displayModel.get(i).path === wallModule.lastAppliedWallpaper) {
                    activeIdx = i;
                    break;
                }
            }
            wallStrip.setIndexImmediate(activeIdx);
        }
        wallModule.scanWallpapers();
        Qt.callLater(() => {
            if (searchInput) searchInput.forceActiveFocus();
        });
    }

    Component.onCompleted: {
        wallModule.openPicker();
    }

    onVisibleChanged: {
        if (visible && fullWallpaperModel.count === 0 && !wallpaperScanner.running) {
            wallModule.openPicker();
        }
    }

    Connections {
        target: (typeof root !== "undefined") ? root : null
        function onActiveModeChanged() {
            if (root.activeMode === "wallpaper") {
                wallModule.openPicker();
            } else {
                wallModule.sortDropdownOpen = false;
            }
        }
    }

    Connections {
        target: Theme
        function onCurrentThemeNameChanged() {
            if (typeof root !== "undefined" && (root.activeMode === "wallpaper" || wallModule.visible)) {
                wallModule.userInteracted = false;
                wallModule.scanWallpapers();
            }
        }
    }

    function scanWallpapers() {
        if (wallpaperScanner.running) wallpaperScanner.running = false;
        Qt.callLater(() => {
            wallpaperScanner.running = true;
        });
    }

    // Background Wallpaper Scanner Process
    Process {
        id: wallpaperScanner
        running: false
        command: ["sh", "-c", `python3 -c "
import os, glob, subprocess

home = os.path.expanduser('~')
theme = '${Theme.currentThemeName}'.strip()
if not theme or theme.lower() == 'default':
    name_file = os.path.join(home, '.config/active-theme/theme-name.txt')
    if os.path.exists(name_file):
        try:
            with open(name_file, 'r') as f:
                t = f.read().strip()
                if t: theme = t
        except Exception:
            pass

theme_lower = theme.lower()

# Check candidates for theme wallpaper directory
candidates = [
    os.path.join(home, f'Pictures/Wallpapers/{theme}'),
    os.path.join(home, f'Pictures/Wallpapers/{theme_lower}'),
]
wall_dir = ''
for c in candidates:
    if os.path.isdir(c):
        wall_dir = c
        break

# Get current active wallpaper path from awww query
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

exts = ('.jpg', '.jpeg', '.png', '.webp', '.mp4')
files = []
if wall_dir and os.path.exists(wall_dir):
    for root_dir, dirs, fnames in os.walk(wall_dir):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for fn in fnames:
            if fn.lower().endswith(exts) and not fn.startswith('.'):
                files.append(os.path.join(root_dir, fn))

# Fallback: if theme folder has 0 wallpapers, use main Wallpapers directory
if not files:
    for base in [os.path.join(home, 'Pictures/Wallpapers')]:
        if os.path.isdir(base):
            for root_dir, dirs, fnames in os.walk(base):
                dirs[:] = [d for d in dirs if not d.startswith('.')]
                for fn in fnames:
                    if fn.lower().endswith(exts) and not fn.startswith('.'):
                        files.append(os.path.join(root_dir, fn))
            if files:
                break

files_with_mtime = []
if active_wall and os.path.isfile(active_wall) and active_wall not in files:
    files.append(active_wall)
for f in set(files):
    if os.path.isfile(f):
        try:
            files_with_mtime.append((f, os.path.getmtime(f)))
        except Exception:
            files_with_mtime.append((f, 0.0))

# Default sort: most recent first (mtime descending)
files_with_mtime.sort(key=lambda x: x[1], reverse=True)

thumbs_dir = os.path.join(home, '.cache/lucid/wallpaper-thumbs/680x422')
thumbs_map = {}
if os.path.isdir(thumbs_dir):
    try:
        for t in os.listdir(thumbs_dir):
            if t.endswith('.jpg'):
                parts = t.rsplit('-', 1)
                if len(parts) == 2:
                    thumbs_map[parts[0]] = os.path.join(thumbs_dir, t)
    except Exception:
        pass

for f, mtime in files_with_mtime:
    name = os.path.splitext(os.path.basename(f))[0]
    thumb_path = ''
    try:
        st = os.stat(f)
        thumb_path = thumbs_map.get(f'{st.st_ino}-{st.st_size}', '')
    except Exception:
        pass
    print(f'{name}|||{f}|||{thumb_path}|||{active_wall}|||{int(mtime)}')
"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text.trim();
                var lines = raw === "" ? [] : raw.split("\n");
                var scanned = [];
                var activeFromQuery = "";

                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 2) {
                        var name = parts[0];
                        var fPath = parts[1];
                        var thumb = parts.length >= 3 ? parts[2] : "";
                        var act = parts.length >= 4 ? parts[3].trim() : "";
                        var mtime = parts.length >= 5 ? parseInt(parts[4]) : 0;
                        if (act !== "") activeFromQuery = act;
                        scanned.push({
                            "name": name,
                            "path": fPath,
                            "thumb": thumb,
                            "mtime": mtime,
                            "temp": false
                        });
                    }
                }

                var prevActive = wallModule.lastAppliedWallpaper;
                var activeChanged = activeFromQuery !== "" && activeFromQuery !== prevActive;
                if (activeFromQuery !== "") {
                    wallModule.lastAppliedWallpaper = activeFromQuery;
                }

                // Compare paths in-order so opening scans do not wipe & rebuild identical models
                var samePaths = (scanned.length === fullWallpaperModel.count);
                if (samePaths) {
                    for (var s = 0; s < scanned.length; s++) {
                        if (fullWallpaperModel.get(s).path !== scanned[s].path) {
                            samePaths = false;
                            break;
                        }
                    }
                }

                if (samePaths && fullWallpaperModel.count > 0) {
                    var thumbByPath = {};
                    for (var k = 0; k < scanned.length; k++) {
                        var item = scanned[k];
                        var existing = fullWallpaperModel.get(k);
                        if (existing.thumb !== item.thumb) {
                            fullWallpaperModel.setProperty(k, "thumb", item.thumb);
                        }
                        if (existing.mtime !== item.mtime) {
                            fullWallpaperModel.setProperty(k, "mtime", item.mtime);
                        }
                        thumbByPath[item.path] = item;
                    }
                    for (var d = 0; d < displayModel.count; d++) {
                        var dm = displayModel.get(d);
                        var updated = thumbByPath[dm.path];
                        if (updated && dm.thumb !== updated.thumb) {
                            displayModel.setProperty(d, "thumb", updated.thumb);
                        }
                    }
                    if (typeof root !== "undefined") {
                        root.cachedWallpapers = scanned;
                        if (activeFromQuery !== "") root.cachedActiveWallpaper = activeFromQuery;
                    }
                    if (activeChanged && !wallModule.userInteracted && wallStrip && displayModel.count > 0) {
                        for (var a = 0; a < displayModel.count; a++) {
                            if (displayModel.get(a).path === activeFromQuery) {
                                wallStrip.setIndexImmediate(a);
                                break;
                            }
                        }
                    }
                } else {
                    fullWallpaperModel.clear();
                    for (var n = 0; n < scanned.length; n++) {
                        fullWallpaperModel.append(scanned[n]);
                    }
                    if (typeof root !== "undefined") {
                        root.cachedWallpapers = scanned;
                        if (activeFromQuery !== "") root.cachedActiveWallpaper = activeFromQuery;
                    }
                    wallModule.filterWallpapers();
                }

                thumbsRunner.running = true;
            }
        }
    }

    // Background process to generate thumbnails using Lucid's script
    Process {
        id: thumbsRunner
        running: false
        command: [
            Quickshell.env("HOME") + "/.config/quickshell/luciddocks/wallpaper-thumbs.sh",
            Quickshell.env("HOME") + "/Pictures/Wallpapers"
        ]
    }

    function applyWallpaperPath(path) {
        if (!path) return;
        wallModule.lastAppliedWallpaper = path;
        if (typeof root !== "undefined") {
            root.cachedActiveWallpaper = path;
        }
        var trans = (Theme.activeTransition && Theme.activeTransition.trim()) || "simple";
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/quickshell/scripts/apply_wallpaper.sh",
            path,
            trans
        ]);
        if (typeof root !== "undefined") {
            root.collapseToIdle();
        }
    }

    // ==========================================
    // UI LAYOUT (Authentic Shell Layout with Top Controls)
    // ==========================================
    Item {
        anchors.fill: parent

        // ------------------------------------------
        // 1. TOP HEADER BAR: Clean Matushell Action Pills
        // ------------------------------------------
        Item {
            id: topHeaderBar
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            height: 36
            z: 20

            // Left Stack: Back Button, Title, Count Pill, Themes Pill
            RowLayout {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: backMouse.pressed
                        ? Qt.alpha(Theme.text, 0.16)
                        : (backMouse.containsMouse ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.05))
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        font.family: Theme.fontFamilyIcon
                        font.pixelSize: 17
                        font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                        renderType: Text.CurveRendering
                        font.hintingPreference: Font.PreferNoHinting
                        color: backMouse.containsMouse ? Theme.text : Qt.alpha(Theme.text, 0.80)
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

                Text {
                    text: "Wallpapers"
                    font.family: "Google Sans Flex"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    renderType: Text.QtRendering
                    font.hintingPreference: Font.PreferNoHinting
                    color: Theme.text
                }

                // Wallpaper Count Pill
                Rectangle {
                    visible: displayModel.count > 0
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: countLabel.implicitWidth + 14
                    radius: 11
                    color: Qt.alpha(Theme.text, 0.08)

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: displayModel.count.toString()
                        font.family: "Google Sans Flex"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                        renderType: Text.QtRendering
                        font.hintingPreference: Font.PreferNoHinting
                        color: Theme.subtext
                    }
                }

                // Switch to Themes Pill
                Rectangle {
                    id: themeBtn
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: themeRow.implicitWidth + 24
                    radius: 16
                    color: themeMouse.pressed
                        ? Qt.alpha(Theme.accent, 0.24)
                        : (themeMouse.containsMouse ? Qt.alpha(Theme.accent, 0.16) : Qt.alpha(Theme.accent, 0.10))

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: themeRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "palette"
                            font.family: Theme.fontFamilyIcon
                            font.pixelSize: 15
                            font.variableAxes: ({ "FILL": 1, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                            renderType: Text.CurveRendering
                            font.hintingPreference: Font.PreferNoHinting
                            color: Theme.accent
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Themes"
                            font.family: "Google Sans Flex"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            renderType: Text.QtRendering
                            font.hintingPreference: Font.PreferNoHinting
                            color: Theme.text
                        }
                    }

                    MouseArea {
                        id: themeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof root !== "undefined") root.switchMode("theme", true);
                        }
                    }
                }
            }

            // Right Stack: First, Shuffle, Last, Sort Pill
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: firstMouse.pressed
                        ? Qt.alpha(Theme.text, 0.14)
                        : (firstMouse.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "first_page"
                        font.family: Theme.fontFamilyIcon
                        font.pixelSize: 18
                        font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                        renderType: Text.CurveRendering
                        font.hintingPreference: Font.PreferNoHinting
                        color: firstMouse.containsMouse ? Theme.text : Qt.alpha(Theme.text, 0.72)
                    }

                    MouseArea {
                        id: firstMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (displayModel.count > 0 && wallStrip) {
                                wallModule.userInteracted = true;
                                wallStrip.setIndexImmediate(0);
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: randMouse.pressed
                        ? Qt.alpha(Theme.accent, 0.22)
                        : (randMouse.containsMouse ? Qt.alpha(Theme.accent, 0.14) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "shuffle"
                        font.family: Theme.fontFamilyIcon
                        font.pixelSize: 17
                        font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                        renderType: Text.CurveRendering
                        font.hintingPreference: Font.PreferNoHinting
                        color: Theme.accent
                    }

                    MouseArea {
                        id: randMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (displayModel.count > 0 && wallStrip) {
                                wallModule.userInteracted = true;
                                var randIdx = Math.floor(Math.random() * displayModel.count);
                                wallStrip.setIndexImmediate(randIdx);
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: lastMouse.pressed
                        ? Qt.alpha(Theme.text, 0.14)
                        : (lastMouse.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "last_page"
                        font.family: Theme.fontFamilyIcon
                        font.pixelSize: 18
                        font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                        renderType: Text.CurveRendering
                        font.hintingPreference: Font.PreferNoHinting
                        color: lastMouse.containsMouse ? Theme.text : Qt.alpha(Theme.text, 0.72)
                    }

                    MouseArea {
                        id: lastMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (displayModel.count > 0 && wallStrip) {
                                wallModule.userInteracted = true;
                                wallStrip.setIndexImmediate(displayModel.count - 1);
                            }
                        }
                    }
                }

                // Sort Dropdown Pill
                Rectangle {
                    id: sortButton
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: sortRow.implicitWidth + 24
                    radius: 16
                    color: wallModule.sortDropdownOpen
                        ? Theme.accent
                        : (sortMouse.containsMouse ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.07))

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: sortRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "sort"
                            font.family: Theme.fontFamilyIcon
                            font.pixelSize: 15
                            font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                            renderType: Text.CurveRendering
                            font.hintingPreference: Font.PreferNoHinting
                            color: wallModule.sortDropdownOpen ? (Theme.fgPrimary || "#101014") : Theme.accent
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (wallModule.sortMode === "oldest") return "Oldest";
                                if (wallModule.sortMode === "name_asc") return "Name A–Z";
                                if (wallModule.sortMode === "name_desc") return "Name Z–A";
                                if (wallModule.sortMode === "shuffle") return "Shuffle";
                                return "Recent";
                            }
                            font.family: "Google Sans Flex"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            renderType: Text.QtRendering
                            font.hintingPreference: Font.PreferNoHinting
                            color: wallModule.sortDropdownOpen ? (Theme.fgPrimary || "#101014") : Theme.text
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: wallModule.sortDropdownOpen ? "expand_less" : "expand_more"
                            font.family: Theme.fontFamilyIcon
                            font.pixelSize: 16
                            font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                            renderType: Text.CurveRendering
                            font.hintingPreference: Font.PreferNoHinting
                            color: wallModule.sortDropdownOpen ? (Theme.fgPrimary || "#101014") : Theme.subtext
                        }
                    }

                    MouseArea {
                        id: sortMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wallModule.sortDropdownOpen = !wallModule.sortDropdownOpen
                    }
                }
            }
        }

        // ------------------------------------------
        // Transparent Dismiss Overlay
        // ------------------------------------------
        MouseArea {
            anchors.fill: parent
            z: 90
            visible: wallModule.sortDropdownOpen
            onClicked: wallModule.sortDropdownOpen = false
        }

        // ------------------------------------------
        // Sort Dropdown Card
        // ------------------------------------------
        Rectangle {
            id: sortDropdownCard
            z: 100
            anchors.top: topHeaderBar.bottom
            anchors.topMargin: 8
            anchors.right: topHeaderBar.right
            width: 196
            height: sortCol.implicitHeight + 12
            radius: 16
            color: Theme.colors.card_bg || "#181a20"
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.10)
            visible: wallModule.sortDropdownOpen

            Column {
                id: sortCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 2

                Repeater {
                    model: [
                        { mode: "recent", label: "Most Recent", icon: "schedule" },
                        { mode: "oldest", label: "Oldest First", icon: "history" },
                        { mode: "name_asc", label: "Name (A to Z)", icon: "sort_by_alpha" },
                        { mode: "name_desc", label: "Name (Z to A)", icon: "sort_by_alpha" },
                        { mode: "shuffle", label: "Random / Shuffle", icon: "shuffle" }
                    ]

                    delegate: Rectangle {
                        id: sortItemRect
                        required property var modelData
                        readonly property bool active: wallModule.sortMode === modelData.mode

                        width: sortCol.width
                        height: 34
                        radius: 10
                        color: sortItemRect.active
                            ? Qt.alpha(Theme.accent, 0.16)
                            : (itemMouse.containsMouse ? Qt.alpha(Theme.text, 0.08) : "transparent")

                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: sortItemRect.modelData.icon
                                font.family: Theme.fontFamilyIcon
                                font.pixelSize: 16
                                font.variableAxes: ({ "FILL": sortItemRect.active ? 1 : 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                                renderType: Text.CurveRendering
                                font.hintingPreference: Font.PreferNoHinting
                                color: sortItemRect.active ? Theme.accent : Theme.subtext
                            }

                            Text {
                                Layout.fillWidth: true
                                text: sortItemRect.modelData.label
                                font.family: "Google Sans Flex"
                                font.pixelSize: 12
                                font.weight: sortItemRect.active ? Font.DemiBold : Font.Medium
                                renderType: Text.QtRendering
                                font.hintingPreference: Font.PreferNoHinting
                                color: sortItemRect.active ? Theme.accent : Theme.text
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: sortItemRect.active
                                text: "check"
                                font.family: Theme.fontFamilyIcon
                                font.pixelSize: 16
                                font.variableAxes: ({ "FILL": 1, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 600 })
                                renderType: Text.CurveRendering
                                font.hintingPreference: Font.PreferNoHinting
                                color: Theme.accent
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wallModule.sortMode = sortItemRect.modelData.mode;
                                wallModule.sortDropdownOpen = false;
                                wallModule.filterWallpapers();
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------
        // Center: Wallpaper Carousel Strip
        // ------------------------------------------
        Item {
            id: stripContainer
            anchors.top: topHeaderBar.bottom
            anchors.topMargin: 8
            anchors.bottom: searchBar.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            clip: true

            LucidWallpaperStrip {
                id: wallStrip
                anchors.fill: parent
                model: displayModel
                onInteracted: wallModule.userInteracted = true
                appliedPath: wallModule.lastAppliedWallpaper

                onChosen: (path) => wallModule.applyWallpaperPath(path)
            }
        }

        // ------------------------------------------
        // Bottom: Matushell Pill Search Bar
        // ------------------------------------------
        Rectangle {
            id: searchBar
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            height: 40
            radius: 20
            color: searchInput.activeFocus ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0.06)
            border.width: 1
            border.color: searchInput.activeFocus ? Qt.alpha(Theme.accent, 0.35) : Qt.alpha(Theme.text, 0.06)

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

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
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: "search"
                    font.family: Theme.fontFamilyIcon
                    font.pixelSize: 18
                    font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                    renderType: Text.CurveRendering
                    font.hintingPreference: Font.PreferNoHinting
                    color: searchInput.activeFocus ? Theme.accent : Qt.alpha(Theme.text, 0.48)
                }

                // Input + Ghost Placeholder Container
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: searchInput.text === ""
                        text: "Search wallpapers…"
                        font.family: "Google Sans Flex"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        renderType: Text.QtRendering
                        font.hintingPreference: Font.PreferNoHinting
                        color: Qt.alpha(Theme.text, 0.42)
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "Google Sans Flex"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        renderType: Text.QtRendering
                        font.hintingPreference: Font.PreferNoHinting
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.fgAccent
                        clip: true
                        text: wallModule.searchText
                        onTextChanged: {
                            var t = text.trim().toLowerCase();
                            if (t === ">theme" || t === ">themes") {
                                if (typeof root !== "undefined") root.switchMode("theme", true);
                                return;
                            }
                            if (wallModule.searchText !== text) {
                                wallModule.searchText = text;
                            }
                        }

                        Keys.onTabPressed: (event) => {
                            if (typeof root !== "undefined") root.switchMode("theme", true);
                            event.accepted = true;
                        }

                        Keys.onLeftPressed: (event) => {
                            if (cursorPosition === 0) {
                                if (wallStrip) wallStrip.step(-1);
                                event.accepted = true;
                            }
                        }
                        Keys.onRightPressed: (event) => {
                            if (cursorPosition === text.length) {
                                if (wallStrip) wallStrip.step(1);
                                event.accepted = true;
                            }
                        }
                        Keys.onUpPressed: (event) => {
                            if (wallStrip) wallStrip.step(-1);
                            event.accepted = true;
                        }
                        Keys.onDownPressed: (event) => {
                            if (wallStrip) wallStrip.step(1);
                            event.accepted = true;
                        }
                        Keys.onReturnPressed: (event) => {
                            if (wallStrip) wallStrip.activateCurrent();
                            event.accepted = true;
                        }
                        Keys.onEnterPressed: (event) => {
                            if (wallStrip) wallStrip.activateCurrent();
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
                    }
                }

                // Clear button when text present
                Rectangle {
                    visible: searchInput.text !== ""
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 12
                    color: clearMouse.containsMouse ? Qt.alpha(Theme.text, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: Theme.fontFamilyIcon
                        font.pixelSize: 15
                        font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                        renderType: Text.CurveRendering
                        font.hintingPreference: Font.PreferNoHinting
                        color: Theme.subtext
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
            }
        }
    }
}
