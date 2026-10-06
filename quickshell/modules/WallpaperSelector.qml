import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: wallModule
    spacing: 10
    focus: true
    Keys.forwardTo: [wallpaperCarousel]

    property bool userInteracted: false

    Keys.onLeftPressed: (event) => {
        wallModule.userInteracted = true;
        wallpaperCarousel.decrementCurrentIndex();
        event.accepted = true;
    }
    Keys.onRightPressed: (event) => {
        wallModule.userInteracted = true;
        wallpaperCarousel.incrementCurrentIndex();
        event.accepted = true;
    }
    Keys.onUpPressed: (event) => {
        wallModule.userInteracted = true;
        wallpaperCarousel.decrementCurrentIndex();
        event.accepted = true;
    }
    Keys.onDownPressed: (event) => {
        wallModule.userInteracted = true;
        wallpaperCarousel.incrementCurrentIndex();
        event.accepted = true;
    }
    Keys.onReturnPressed: (event) => {
        wallModule.applyWallpaper(wallpaperCarousel.currentIndex);
        event.accepted = true;
    }
    Keys.onEnterPressed: (event) => {
        wallModule.applyWallpaper(wallpaperCarousel.currentIndex);
        event.accepted = true;
    }
    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    function loadCachedWallpapers() {
        if (typeof root !== "undefined" && root.cachedWallpapers && root.cachedWallpapers.length > 0) {
            if (wallpaperModel.count === 0) {
                wallpaperModel.clear();
                for (var j = 0; j < root.cachedWallpapers.length; j++) {
                    wallpaperModel.append(root.cachedWallpapers[j]);
                }
                var actWall = root.cachedActiveWallpaper || wallModule.lastAppliedWallpaper;
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

    Component.onCompleted: {
        wallModule.userInteracted = false;
        wallModule.loadCachedWallpapers();
        wallModule.scanWallpapers();
    }

    function scanWallpapers() {
        if (wallpaperScanner.running) wallpaperScanner.running = false;
        Qt.callLater(() => {
            if (root.activeMode === "wallpaper" || visible) {
                wallpaperScanner.running = true;
            }
        });
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode === "wallpaper") {
                wallModule.userInteracted = false;
                wallModule.loadCachedWallpapers();
                wallModule.scanWallpapers();
                Qt.callLater(() => wallpaperCarousel.forceActiveFocus());
            }
        }
    }

    Connections {
        target: Theme
        function onCurrentThemeNameChanged() {
            if (root.activeMode === "wallpaper" || visible) {
                wallModule.userInteracted = false;
                wallModule.scanWallpapers();
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            wallModule.userInteracted = false;
            wallModule.loadCachedWallpapers();
            wallModule.scanWallpapers();
            Qt.callLater(() => wallpaperCarousel.forceActiveFocus());
        }
    }

    property alias wallpaperGrid: wallpaperCarousel
    property string lastAppliedWallpaper: ""
    ListModel { id: wallpaperModel }

    // Query active wallpaper and populate carousel whenever the module opens
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

# Check candidates for theme wallpaper directory
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

exts = ('.jpg', '.jpeg', '.png', '.webp')
files = []
if wall_dir and os.path.exists(wall_dir):
    for root_dir, dirs, fnames in os.walk(wall_dir, followlinks=True):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for fn in fnames:
            if fn.lower().endswith(exts) and not fn.startswith('.'):
                files.append(os.path.join(root_dir, fn))

# Global Fallback: if theme folder is empty, missing, or has 0 wallpapers, show all wallpapers from Wallpapers directories
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
                    wallModule.lastAppliedWallpaper = activeFromQuery;
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

                // If user has not interacted with the carousel yet, position it to active wallpaper
                if (!wallModule.userInteracted && wallpaperModel.count > 0) {
                    var targetIdx = 0;
                    var checkWall = wallModule.lastAppliedWallpaper || activeFromQuery;
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
                    Qt.callLater(() => wallpaperCarousel.forceActiveFocus());
                } else if (wallModule.userInteracted) {
                    // Make sure currentIndex remains within valid bounds
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

    Process { id: wallpaperRunner; running: false }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 24
		spacing: 6
		Layout.leftMargin: 8
        Layout.rightMargin: 8

        Text {
            text: "Wallpapers"
            font.pixelSize: 15
            font.bold: true
            color: Theme.colors.text_primary ?? "white"
        }

        Text {
            visible: wallpaperModel.count > 0
            text: "(" + (wallpaperCarousel.currentIndex + 1) + " / " + wallpaperModel.count + ")"
            font.pixelSize: 12
            font.bold: true
            color: Theme.colors.text_secondary ?? "#565f89"
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "Active: " + Theme.currentThemeName
            font.family: "Inter"
            font.pixelSize: 11
            font.bold: true
            color: Theme.colors.accent ?? "#7aa2f7"
        }
	}


    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent
            visible: wallpaperModel.count === 0
            text: "No wallpapers found in ~/Pictures/Wallpapers/" + Theme.currentThemeName
            color: Theme.colors.text_secondary ?? "#565f89"
            font.pixelSize: 13
        }

        RowLayout {
            anchors.fill: parent
            visible: wallpaperModel.count > 0
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
                        wallModule.userInteracted = true;
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
                focus: true
                model: wallpaperModel

                pathItemCount: 5
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 200
                onMovementStarted: wallModule.userInteracted = true

                readonly property real itemWidth: Math.min(270, Math.max(160, width * 0.44))
                readonly property real itemHeight: height * 0.88

                Keys.onLeftPressed: (event) => {
                    wallModule.userInteracted = true;
                    decrementCurrentIndex();
                    event.accepted = true;
                }
                Keys.onRightPressed: (event) => {
                    wallModule.userInteracted = true;
                    incrementCurrentIndex();
                    event.accepted = true;
                }
                Keys.onUpPressed: (event) => {
                    wallModule.userInteracted = true;
                    decrementCurrentIndex();
                    event.accepted = true;
                }
                Keys.onDownPressed: (event) => {
                    wallModule.userInteracted = true;
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
                    root.collapseToIdle();
                    event.accepted = true;
                }

                function applySelected() {
                    wallModule.applyWallpaper(currentIndex);
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: Qt.PointingHandCursor
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        wallModule.userInteracted = true;
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
                    id: delegateRoot
                    width: wallpaperCarousel.itemWidth
                    height: wallpaperCarousel.itemHeight

                    scale: PathView.itemScale ?? 0.8
                    opacity: PathView.itemOpacity ?? 0.0
                    z: PathView.itemZ ?? 1
                    visible: opacity > 0.01

                    transform: Rotation {
                        origin.x: delegateRoot.width / 2
                        origin.y: delegateRoot.height / 2
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
                            wallModule.userInteracted = true;
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
                        wallModule.userInteracted = true;
                        wallpaperCarousel.incrementCurrentIndex();
                        wallpaperCarousel.forceActiveFocus();
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
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
            color: applyMouse.containsMouse ? (Theme.colors.accent ?? "#7aa2f7") : (Theme.colors.hover_bg ?? "#24283b")
            border.width: 0
            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text: "Apply"
                font.bold: true; font.pixelSize: 12
                color: applyMouse.containsMouse ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
            }
            MouseArea {
                id: applyMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wallpaperModel.count > 0) wallpaperCarousel.applySelected();
                }
            }
        }
    }

    function applyWallpaper(idx) {
        if (idx >= 0 && idx < wallpaperModel.count) {
            var path = wallpaperModel.get(idx).filePath;
            wallModule.lastAppliedWallpaper = path;
            if (typeof root !== "undefined") {
                root.cachedActiveWallpaper = path;
            }
            var trans = (Theme.activeTransition && Theme.activeTransition.trim()) || "simple";
            Quickshell.execDetached([
                "awww", "img", path,
                "--transition-type", trans,
                "--transition-fps", "144",
                "--transition-step", "240",
                "--transition-bezier", "0.25,0.1,0.25,1.0"
            ]);
            root.collapseToIdle();
        }
    }
}
