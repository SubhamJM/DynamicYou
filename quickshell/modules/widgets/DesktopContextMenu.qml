pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../"
import "../"
import "WidgetCatalog.js" as Catalog

// Desktop right-click context menu in calm, sharp iNiR architectural style:
// - Unified 12px-rounded container with crisp 1px colBorder and 6px inner radii
// - Opens cleanly below the pointer (flips above only near bottom edge)
// - Native-resolution mipmapped wallpaper carousel + iNiR Theme & Widget hover submenus
// - Zero FBO text resampling layers; QtRendering text sized natively for 1.2x scaling
PanelWindow {
    id: menuWindow

    required property var hostScreen
    property var notchRoot: null
    property real anchorX: 0
    property real anchorY: 0
    property real topInset: 46
    property var desktopIds: []

    signal menuDismissed()
    signal widgetConfigureRequested(string tileId)

    // iNiR architectural design tokens mapped directly from Theme.m3
    readonly property color colLayer1: Theme.m3.surface_container_low ?? "#15151a"
    readonly property color colLayer2: Theme.m3.surface_container ?? "#1c1c22"
    readonly property color colLayer3: Theme.m3.surface_container_high ?? "#26262e"
    readonly property color colLayerHover: Qt.alpha(Theme.m3.on_surface ?? "#ffffff", 0.08)
    readonly property color colBorder: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.72)
    readonly property color colBorderSubtle: Qt.alpha(Theme.m3.outline_variant ?? "#49454f", 0.38)
    readonly property color colBorderFocus: Qt.alpha(Theme.m3.primary ?? Theme.accent, 0.72)
    readonly property color colSelection: Qt.alpha(Theme.m3.primary_container ?? Theme.primaryContainer, 0.45)
    readonly property color colText: Theme.m3.on_surface ?? Theme.text
    readonly property color colTextMuted: Qt.alpha(Theme.m3.on_surface_variant ?? Theme.subtext, 0.78)
    readonly property color colPrimary: Theme.m3.primary ?? Theme.accent
    readonly property color colOnPrimary: Theme.m3.on_primary ?? Theme.onAccent
    readonly property color colDanger: Theme.m3.error ?? Theme.error
    readonly property color colDangerHover: Qt.alpha(Theme.m3.error_container ?? "#7f1d1d", 0.45)

    readonly property int radLarge: 12
    readonly property int radNormal: 8
    readonly property int radSmall: 6
    readonly property string uiFont: "Noto Sans"

    // State
    property string activeWallpaperPath: ""
    property var carouselModel: []
    property var themesModel: []
    property string openSubmenuKind: "" // "" | "wallpaper" | "widgets"
    property real submenuAnchorY: 0
    readonly property int menuWidth: 344
    readonly property int submenuWidth: 296
    property real revealProgress: 0

    function applyWallpaper(path) {
        if (!path) return;
        const trans = (Theme.activeTransition && Theme.activeTransition.trim()) || "simple";
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/quickshell/scripts/apply_wallpaper.sh",
            path,
            trans
        ]);
        menuWindow.menuDismissed();
    }

    function applyTransition(trans) {
        if (!trans) return;
        Theme.activeTransition = trans;
        Quickshell.execDetached([
            "sh", "-c",
            "mkdir -p \"$HOME/.config/active-theme\" && printf '%s' \"$1\" > \"$HOME/.config/active-theme/wallpaper-transition.txt\"",
            "sh", trans
        ]);
    }

    function switchSubmenu(kind, rowItem) {
        submenuCloseTimer.stop();
        menuWindow.openSubmenuKind = kind;
        if (rowItem) {
            const pt = rowItem.mapToItem(menuWindow.contentItem, 0, 0);
            menuWindow.submenuAnchorY = pt ? pt.y : menuCard.y;
        }
    }

    visible: true
    screen: hostScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.namespace: "quickshell:desktopMenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Component.onCompleted: {
        wallpaperScanner.running = true;
        themeScanner.running = true;
        keyScope.forceActiveFocus();
        revealAnim.start();
    }

    NumberAnimation {
        id: revealAnim
        target: menuWindow
        property: "revealProgress"
        from: 0.0
        to: 1.0
        duration: 160
        easing.type: Easing.OutCubic
    }

    // Scan wallpapers (prefer active theme library, fallback to ~/Pictures/Wallpapers)
    Process {
        id: wallpaperScanner
        running: false
        command: ["python3", "-c", `
import hashlib, json, os, random

home = os.path.expanduser("~")
active_dir = os.path.join(home, ".config/active-theme")
lib = os.path.join(home, "Pictures/Wallpapers")

theme = ""
name_file = os.path.join(active_dir, "theme-name.txt")
if os.path.isfile(name_file):
    try:
        with open(name_file, "r", encoding="utf-8") as f:
            theme = f.read().strip()
    except OSError:
        pass

active_wall = ""
wall_file = os.path.join(active_dir, "current-wallpaper.txt")
if os.path.isfile(wall_file):
    try:
        with open(wall_file, "r", encoding="utf-8") as f:
            active_wall = f.readline().strip()
    except OSError:
        pass

exts = (".jpg", ".jpeg", ".png", ".webp", ".mp4", ".webm", ".mkv", ".mov", ".m4v")
video_exts = (".mp4", ".webm", ".mkv", ".mov", ".m4v")

def collect(folder):
    out = []
    if not os.path.isdir(folder):
        return out
    for root_dir, dirs, fnames in os.walk(folder):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for fn in fnames:
            if fn.lower().endswith(exts) and not fn.startswith("."):
                out.append(os.path.join(root_dir, fn))
    return out

files = []
if theme:
    for cand in (os.path.join(lib, theme), os.path.join(lib, theme.lower())):
        files = collect(cand)
        if files:
            break
if not files:
    files = collect(lib)

thumbs_dir = os.path.join(home, ".cache/lucid/wallpaper-thumbs/680x422")
thumbs_map = {}
if os.path.isdir(thumbs_dir):
    try:
        for t in os.listdir(thumbs_dir):
            if t.endswith(".jpg"):
                parts = t.rsplit("-", 1)
                if len(parts) == 2:
                    thumbs_map[parts[0]] = os.path.join(thumbs_dir, t)
    except OSError:
        pass

live_frames = os.path.join(home, ".cache/dynamic-you/live-frames")

def resolve_entry(path):
    is_vid = path.lower().endswith(video_exts)
    thumb = ""
    try:
        st = os.stat(path)
        thumb = thumbs_map.get(f"{st.st_ino}-{st.st_size}", "")
        if not thumb and is_vid:
            key = hashlib.sha256(f"{path}:{st.st_size}:{int(st.st_mtime)}".encode()).hexdigest()[:24]
            cand = os.path.join(live_frames, f"{key}.jpg")
            if os.path.isfile(cand):
                thumb = cand
    except OSError:
        pass
    if is_vid and not thumb:
        return None
    name = os.path.splitext(os.path.basename(path))[0]
    return {"name": name, "path": path, "thumb": thumb, "isVideo": is_vid}

entries = []
seen = set()
if active_wall and os.path.isfile(active_wall):
    item = resolve_entry(active_wall)
    if item:
        entries.append(item)
        seen.add(active_wall)

others = [f for f in set(files) if f not in seen and os.path.isfile(f)]
random.shuffle(others)
for f in others:
    item = resolve_entry(f)
    if item:
        entries.append(item)
        if len(entries) >= 10:
            break

print(json.dumps({"active": active_wall, "items": entries}))
`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text || "{}");
                    menuWindow.activeWallpaperPath = parsed.active || "";
                    menuWindow.carouselModel = Array.isArray(parsed.items) ? parsed.items : [];
                } catch (e) {
                    menuWindow.carouselModel = [];
                }
            }
        }
    }

    // Scan preset themes cleanly using theme_scanner.py
    Process {
        id: themeScanner
        running: false
        command: ["python3", NotchConfig.scriptsDir + "/theme_scanner.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const entries = JSON.parse(this.text || "[]");
                    menuWindow.themesModel = Array.isArray(entries) ? entries : [];
                } catch (e) {
                    menuWindow.themesModel = [];
                }
            }
        }
    }

    Timer {
        id: submenuCloseTimer
        interval: 260
        onTriggered: menuWindow.openSubmenuKind = ""
    }

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (menuWindow.openSubmenuKind !== "") {
                menuWindow.openSubmenuKind = "";
            } else {
                menuWindow.menuDismissed();
            }
        }

        // Outside click scrim
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: menuWindow.menuDismissed()
        }

        // Unified iNiR-Style Floating Context Menu (opens cleanly BELOW the mouse pointer)
        Rectangle {
            id: menuCard

            readonly property real pad: 8
            readonly property real pointerGap: 6
            readonly property bool fitsRight: (menuWindow.anchorX + pointerGap + width) <= (menuWindow.width - pad)
            readonly property bool fitsBelow: (menuWindow.anchorY + pointerGap + height) <= (menuWindow.height - pad)

            width: menuWindow.menuWidth
            height: Math.round(menuCol.implicitHeight + 16)
            x: Math.round(fitsRight
                ? Math.max(pad, menuWindow.anchorX + pointerGap)
                : Math.max(pad, Math.min(menuWindow.width - width - pad, menuWindow.anchorX - width - pointerGap)))
            y: Math.round(fitsBelow
                ? Math.max(menuWindow.topInset + 6, menuWindow.anchorY + pointerGap)
                : Math.max(menuWindow.topInset + 6, Math.min(menuWindow.height - height - pad, menuWindow.anchorY - height - pointerGap)))

            radius: menuWindow.radLarge
            color: menuWindow.colLayer1
            border.width: 1
            border.color: menuWindow.colBorder
            opacity: menuWindow.revealProgress

            transform: Translate {
                y: (1.0 - menuWindow.revealProgress) * (menuCard.fitsBelow ? -8 : 8)
            }

            // Swallow clicks inside the menu surface
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            ColumnLayout {
                id: menuCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                spacing: 6

                // --- 1. Crisp iNiR-Framed Wallpaper Carousel ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 134
                    radius: menuWindow.radNormal
                    color: menuWindow.colLayer2
                    border.width: 1
                    border.color: menuWindow.colBorderSubtle

                    Item {
                        id: carousel
                        anchors.fill: parent
                        anchors.margins: 6

                        property int hoveredIndex: -1
                        readonly property int focusedIndex: hoveredIndex >= 0 ? hoveredIndex : listView.currentIndex
                        readonly property real largeRatio: 0.52
                        readonly property real mediumRatio: 0.32
                        readonly property real smallRatio: 0.12

                        function widthForOffset(offset) {
                            if (offset === 0) return width * largeRatio;
                            if (Math.abs(offset) === 1) return width * mediumRatio;
                            return width * smallRatio;
                        }

                        Row {
                            visible: menuWindow.carouselModel.length === 0
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "wallpaper"
                                iconSize: 16
                                color: menuWindow.colTextMuted
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Loading wallpapers…"
                                color: menuWindow.colTextMuted
                                font.family: menuWindow.uiFont
                                font.pixelSize: 13
                                renderType: Text.QtRendering
                            }
                        }

                        ListView {
                            id: listView
                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: 5
                            clip: true
                            interactive: true
                            snapMode: ListView.SnapOneItem
                            highlightRangeMode: ListView.StrictlyEnforceRange
                            preferredHighlightBegin: 0
                            preferredHighlightEnd: 0
                            highlightMoveDuration: 220
                            model: menuWindow.carouselModel

                            WheelHandler {
                                id: wheelHandler
                                target: listView
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                property bool coolingDown: false
                                onWheel: (event) => {
                                    if (coolingDown) return;
                                    coolingDown = true;
                                    wheelCooldown.restart();
                                    if (event.angleDelta.y < 0 || event.angleDelta.x > 0)
                                        listView.incrementCurrentIndex();
                                    else
                                        listView.decrementCurrentIndex();
                                }
                            }

                            Timer {
                                id: wheelCooldown
                                interval: 80
                                onTriggered: wheelHandler.coolingDown = false
                            }

                            delegate: Item {
                                id: sliceRoot
                                required property var modelData
                                required property int index

                                readonly property int offsetFromCurrent: index - carousel.focusedIndex
                                readonly property bool isActiveWall: menuWindow.activeWallpaperPath !== ""
                                    && modelData.path === menuWindow.activeWallpaperPath
                                readonly property string imgUrl: "file://" + (modelData.thumb && modelData.thumb.length > 0 ? modelData.thumb : modelData.path)

                                width: Math.round(carousel.widthForOffset(offsetFromCurrent))
                                height: listView.height

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
                                    }
                                }

                                // Mask ONLY the image texture at native Qt scale (no text inside FBO!)
                                Item {
                                    id: sliceClip
                                    anchors.fill: parent

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: menuWindow.radSmall
                                        color: menuWindow.colLayer3
                                    }

                                    Image {
                                        anchors.fill: parent
                                        source: sliceRoot.imgUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                        sourceSize.width: Math.round(carousel.width * carousel.largeRatio * WidgetStore.qtScale)
                                        sourceSize.height: Math.round(listView.height * WidgetStore.qtScale)
                                    }

                                    layer.enabled: width > 1 && height > 1
                                    layer.smooth: true
                                    layer.textureSize: Qt.size(
                                        Math.max(1, Math.round(width * WidgetStore.qtScale)),
                                        Math.max(1, Math.round(height * WidgetStore.qtScale))
                                    )
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: sliceClip.width
                                            height: sliceClip.height
                                            radius: menuWindow.radSmall
                                        }
                                    }
                                }

                                // Hover / active indicators kept completely outside any mask FBO
                                Rectangle {
                                    anchors.fill: parent
                                    radius: menuWindow.radSmall
                                    color: sliceMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : "transparent"
                                    border.width: 1
                                    border.color: sliceRoot.isActiveWall
                                        ? menuWindow.colPrimary
                                        : (sliceMouse.containsMouse ? menuWindow.colBorderFocus : menuWindow.colBorderSubtle)
                                }

                                Rectangle {
                                    visible: sliceRoot.isActiveWall
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: menuWindow.colPrimary

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconSize: 15
                                        fill: 1
                                        color: menuWindow.colOnPrimary
                                    }
                                }

                                Rectangle {
                                    visible: !!sliceRoot.modelData.isVideo
                                    anchors { top: parent.top; right: parent.right; margins: 5 }
                                    width: 18
                                    height: 18
                                    radius: 4
                                    color: Qt.rgba(0, 0, 0, 0.65)
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "play_arrow"
                                        iconSize: 12
                                        fill: 1
                                        color: "#ffffff"
                                    }
                                }

                                MouseArea {
                                    id: sliceMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: carousel.hoveredIndex = sliceRoot.index
                                    onExited: if (carousel.hoveredIndex === sliceRoot.index) carousel.hoveredIndex = -1
                                    onClicked: {
                                        listView.currentIndex = sliceRoot.index;
                                        menuWindow.applyWallpaper(sliceRoot.modelData.path);
                                    }
                                }
                            }
                        }
                    }
                }

                // --- 2. Architectural iNiR Menu List with Hairline Separators ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    InirMenuRow {
                        icon: "format_paint"
                        label: "Wallpaper & style"
                        valueText: Theme.currentThemeName || ""
                        hasSubmenu: true
                        submenuActive: menuWindow.openSubmenuKind === "wallpaper"
                        onHoveredRowChanged: (isHov, item) => {
                            if (isHov) menuWindow.switchSubmenu("wallpaper", item);
                            else submenuCloseTimer.restart();
                        }
                        onTriggered: {
                            menuWindow.menuDismissed();
                            if (menuWindow.notchRoot && typeof menuWindow.notchRoot.switchMode === "function")
                                menuWindow.notchRoot.switchMode("wallpaper", false);
                        }
                    }

                    InirMenuRow {
                        icon: "palette"
                        label: "Preset themes"
                        accentDotColor: Theme.accent
                        onHoveredRowChanged: (isHov) => { if (isHov) submenuCloseTimer.restart(); }
                        onTriggered: {
                            menuWindow.menuDismissed();
                            if (menuWindow.notchRoot && typeof menuWindow.notchRoot.switchMode === "function")
                                menuWindow.notchRoot.switchMode("theme", false);
                        }
                    }

                    InirMenuRow {
                        icon: "animation"
                        label: "Transitions"
                        valueText: Theme.activeTransition || "simple"
                        onHoveredRowChanged: (isHov) => { if (isHov) submenuCloseTimer.restart(); }
                        onTriggered: {
                            menuWindow.menuDismissed();
                            if (menuWindow.notchRoot && typeof menuWindow.notchRoot.switchMode === "function")
                                menuWindow.notchRoot.switchMode("transition", false);
                        }
                    }

                    InirSeparator {}

                    InirMenuRow {
                        icon: "widgets"
                        label: "Widgets"
                        valueText: menuWindow.desktopIds.length > 0 ? (menuWindow.desktopIds.length + " pinned") : ""
                        hasSubmenu: true
                        submenuActive: menuWindow.openSubmenuKind === "widgets"
                        onHoveredRowChanged: (isHov, item) => {
                            if (isHov) menuWindow.switchSubmenu("widgets", item);
                            else submenuCloseTimer.restart();
                        }
                        onTriggered: {
                            menuWindow.menuDismissed();
                            WidgetStore.toggleSidebar();
                        }
                    }

                    InirMenuRow {
                        icon: "dashboard_customize"
                        label: "Widget gallery"
                        onHoveredRowChanged: (isHov) => { if (isHov) submenuCloseTimer.restart(); }
                        onTriggered: {
                            menuWindow.menuDismissed();
                            WidgetStore.openSidebar();
                        }
                    }

                    InirSeparator {}

                    InirMenuRow {
                        icon: "settings"
                        label: "Settings"
                        onHoveredRowChanged: (isHov) => { if (isHov) submenuCloseTimer.restart(); }
                        onTriggered: {
                            menuWindow.menuDismissed();
                            if (menuWindow.notchRoot && typeof menuWindow.notchRoot.openSettings === "function")
                                menuWindow.notchRoot.openSettings("");
                        }
                    }
                }
            }
        }

        // --- Floating iNiR Submenu (flips left automatically if near right screen edge) ---
        Loader {
            id: submenuLoader
            active: menuWindow.openSubmenuKind !== ""
            width: menuWindow.submenuWidth
            sourceComponent: menuWindow.openSubmenuKind === "wallpaper" ? wallpaperSubmenuComp : widgetsSubmenuComp

            x: Math.round((menuCard.x + menuCard.width + 6 + menuWindow.submenuWidth > menuWindow.width - 8)
                ? (menuCard.x - menuWindow.submenuWidth - 6)
                : (menuCard.x + menuCard.width + 6))
            y: Math.round(Math.min(
                Math.max(menuWindow.submenuAnchorY, menuWindow.topInset + 6),
                Math.max(menuWindow.topInset + 6, menuWindow.height - (item ? item.implicitHeight : 220) - 8)
            ))

            opacity: active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) submenuCloseTimer.stop();
                    else submenuCloseTimer.restart();
                }
            }
        }
    }

    // --- Submenu 1: Wallpaper & Style (iNiR Theme Preset Tiles + Transition List) ---
    Component {
        id: wallpaperSubmenuComp

        Rectangle {
            width: menuWindow.submenuWidth
            implicitHeight: wSubCol.implicitHeight + 16
            radius: menuWindow.radLarge
            color: menuWindow.colLayer1
            border.width: 1
            border.color: menuWindow.colBorder

            ColumnLayout {
                id: wSubCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Text {
                        text: "Theme preset"
                        color: menuWindow.colTextMuted
                        font.family: menuWindow.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        renderType: Text.QtRendering
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Theme.currentThemeName || ""
                        color: menuWindow.colPrimary
                        font.family: menuWindow.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        renderType: Text.QtRendering
                    }
                }

                // 3x2 iNiR preset tiles (6px sharp corners, 1px borders)
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: 6
                    columnSpacing: 6

                    Repeater {
                        model: menuWindow.themesModel

                        delegate: Rectangle {
                            id: themeTile
                            required property var modelData

                            readonly property bool isSel: {
                                const cur = String(Theme.currentThemeName || "").trim().toLowerCase();
                                return cur !== "" && (String(modelData.rawName || "").toLowerCase() === cur
                                    || String(modelData.themeName || "").trim().toLowerCase() === cur);
                            }

                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: menuWindow.radSmall
                            color: isSel
                                ? menuWindow.colSelection
                                : (tileMa.containsMouse ? menuWindow.colLayerHover : menuWindow.colLayer2)
                            border.width: 1
                            border.color: isSel
                                ? menuWindow.colBorderFocus
                                : (tileMa.containsMouse ? menuWindow.colBorder : menuWindow.colBorderSubtle)

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                width: Math.min(parent.width - 10, implicitWidth)

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 9
                                    height: 9
                                    radius: 2
                                    color: themeTile.modelData.accentColor || "#7aa2f7"
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: themeTile.modelData.themeName || themeTile.modelData.rawName
                                    color: menuWindow.colText
                                    font.family: menuWindow.uiFont
                                    font.pixelSize: 12
                                    font.weight: themeTile.isSel ? Font.Bold : Font.Medium
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, themeTile.width - 24)
                                    renderType: Text.QtRendering
                                }
                            }

                            MouseArea {
                                id: tileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Theme.applyPreset(themeTile.modelData.rawName)
                            }
                        }
                    }
                }

                InirSeparator {}

                Text {
                    Layout.leftMargin: 4
                    text: "Wallpaper transition"
                    color: menuWindow.colTextMuted
                    font.family: menuWindow.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    renderType: Text.QtRendering
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: [
                            { label: "Simple Fade", icon: "blur_on", value: "simple" },
                            { label: "Smooth Fade", icon: "gradient", value: "fade" },
                            { label: "Wipe", icon: "transition_slide", value: "wipe" },
                            { label: "Wave", icon: "waves", value: "wave" },
                            { label: "Outer Bloom", icon: "motion_blur", value: "outer" },
                            { label: "Random", icon: "shuffle", value: "random" }
                        ]

                        delegate: Rectangle {
                            id: trRow
                            required property var modelData
                            readonly property bool activeTr: Theme.activeTransition === modelData.value

                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: menuWindow.radSmall
                            color: activeTr
                                ? menuWindow.colSelection
                                : (trMouse.containsMouse ? menuWindow.colLayerHover : "transparent")
                            border.width: activeTr ? 1 : 0
                            border.color: menuWindow.colBorderFocus

                            RowLayout {
                                anchors { fill: parent; leftMargin: 9; rightMargin: 9 }
                                spacing: 9

                                MaterialSymbol {
                                    text: trRow.modelData.icon
                                    iconSize: 17
                                    fill: trRow.activeTr ? 1 : 0
                                    color: trRow.activeTr ? menuWindow.colPrimary : menuWindow.colTextMuted
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: trRow.modelData.label
                                    color: menuWindow.colText
                                    font.family: menuWindow.uiFont
                                    font.pixelSize: 13
                                    font.weight: trRow.activeTr ? Font.DemiBold : Font.Normal
                                    renderType: Text.QtRendering
                                }
                                MaterialSymbol {
                                    visible: trRow.activeTr
                                    text: "check"
                                    iconSize: 16
                                    color: menuWindow.colPrimary
                                }
                            }

                            MouseArea {
                                id: trMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: menuWindow.applyTransition(trRow.modelData.value)
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Submenu 2: Widgets Quick Toggles & Controls (iNiR architectural frame) ---
    Component {
        id: widgetsSubmenuComp

        Rectangle {
            width: menuWindow.submenuWidth
            implicitHeight: wSubLayout.implicitHeight + 16
            radius: menuWindow.radLarge
            color: menuWindow.colLayer1
            border.width: 1
            border.color: menuWindow.colBorder

            readonly property var quickIds: {
                const base = ["time", "weather", "resources", "music", "end4Media", "nothingPlayer", "nothingBuds", "bgVisualiser"];
                const out = [];
                const seen = {};
                const pinned = menuWindow.desktopIds || [];
                for (let i = 0; i < pinned.length; i++) {
                    const id = String(pinned[i]);
                    if (!seen[id]) { seen[id] = true; out.push(id); }
                }
                for (let i = 0; i < base.length && out.length < 9; i++) {
                    if (!seen[base[i]]) { seen[base[i]] = true; out.push(base[i]); }
                }
                return out;
            }

            ColumnLayout {
                id: wSubLayout
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                spacing: 2

                SubmenuToggleRow {
                    icon: "grid_4x4"
                    label: "Snap to grid"
                    checked: WidgetStore.gridSnapEnabled
                    onToggled: WidgetStore.toggleGridSnap()
                }

                SubmenuActionRow {
                    visible: menuWindow.desktopIds.length > 0
                    icon: "layers_clear"
                    label: "Return all widgets"
                    danger: true
                    onTriggered: {
                        menuWindow.menuDismissed();
                        WidgetStore.returnAllToSidebar();
                    }
                }

                InirSeparator {}

                Repeater {
                    model: parent.parent.quickIds

                    delegate: Rectangle {
                        id: qwRow
                        required property string modelData
                        readonly property var wDef: Catalog.definitionFor(modelData)
                        readonly property bool pinned: WidgetStore.isPinned(modelData)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 35
                        radius: menuWindow.radSmall
                        color: qwMa.containsMouse ? menuWindow.colLayerHover : "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 9; rightMargin: 7 }
                            spacing: 9

                            MaterialSymbol {
                                text: qwRow.wDef ? qwRow.wDef.icon : "widgets"
                                iconSize: 17
                                fill: qwRow.pinned ? 1 : 0
                                color: qwRow.pinned ? menuWindow.colPrimary : menuWindow.colTextMuted
                            }

                            Text {
                                Layout.fillWidth: true
                                text: qwRow.wDef ? qwRow.wDef.name : qwRow.modelData
                                color: menuWindow.colText
                                font.family: menuWindow.uiFont
                                font.pixelSize: 13
                                font.weight: qwRow.pinned ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                renderType: Text.QtRendering
                            }

                            Rectangle {
                                visible: qwRow.pinned
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: 5
                                color: tuneMa.containsMouse ? menuWindow.colSelection : "transparent"

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "tune"
                                    iconSize: 15
                                    color: tuneMa.containsMouse ? menuWindow.colPrimary : menuWindow.colTextMuted
                                }

                                MouseArea {
                                    id: tuneMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: menuWindow.widgetConfigureRequested(qwRow.modelData)
                                }
                            }

                            InirMiniSwitch {
                                checked: qwRow.pinned
                            }
                        }

                        MouseArea {
                            id: qwMa
                            anchors {
                                left: parent.left; top: parent.top; bottom: parent.bottom
                                right: parent.right
                                rightMargin: qwRow.pinned ? 28 : 0
                            }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: WidgetStore.togglePin(qwRow.modelData, menuWindow.hostScreen ? String(menuWindow.hostScreen.name) : "")
                        }
                    }
                }
            }
        }
    }

    component InirSeparator: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 3
        Layout.bottomMargin: 3
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        Layout.preferredHeight: 1
        color: menuWindow.colBorderSubtle
    }

    component InirMiniSwitch: Rectangle {
        property bool checked: false
        Layout.preferredWidth: 26
        Layout.preferredHeight: 15
        radius: 4
        color: checked ? menuWindow.colPrimary : menuWindow.colLayer3
        border.width: 1
        border.color: checked ? menuWindow.colPrimary : menuWindow.colBorder
        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            width: 9
            height: 9
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            x: checked ? (parent.width - width - 3) : 3
            color: checked ? menuWindow.colOnPrimary : menuWindow.colTextMuted
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    component SubmenuToggleRow: Rectangle {
        property string icon: ""
        property string label: ""
        property bool checked: false
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: 35
        radius: menuWindow.radSmall
        color: tMa.containsMouse ? menuWindow.colLayerHover : "transparent"

        RowLayout {
            anchors { fill: parent; leftMargin: 9; rightMargin: 7 }
            spacing: 9
            MaterialSymbol {
                text: icon
                iconSize: 17
                color: checked ? menuWindow.colPrimary : menuWindow.colTextMuted
            }
            Text {
                Layout.fillWidth: true
                text: label
                color: menuWindow.colText
                font.family: menuWindow.uiFont
                font.pixelSize: 13
                font.weight: Font.Medium
                renderType: Text.QtRendering
            }
            InirMiniSwitch { checked: parent.parent.checked }
        }

        MouseArea {
            id: tMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

    component SubmenuActionRow: Rectangle {
        property string icon: ""
        property string label: ""
        property bool danger: false
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: visible ? 35 : 0
        radius: menuWindow.radSmall
        color: aMa.containsMouse
            ? (danger ? menuWindow.colDangerHover : menuWindow.colLayerHover)
            : "transparent"

        RowLayout {
            anchors { fill: parent; leftMargin: 9; rightMargin: 9 }
            spacing: 9
            MaterialSymbol {
                text: icon
                iconSize: 17
                color: danger ? menuWindow.colDanger : menuWindow.colTextMuted
            }
            Text {
                Layout.fillWidth: true
                text: label
                color: danger ? menuWindow.colDanger : menuWindow.colText
                font.family: menuWindow.uiFont
                font.pixelSize: 13
                font.weight: Font.Medium
                renderType: Text.QtRendering
            }
        }

        MouseArea {
            id: aMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.triggered()
        }
    }

    // Crisp 38px iNiR ContextMenu Row (readable typography, subtle calm hover)
    component InirMenuRow: Rectangle {
        id: rowItem
        property string icon: ""
        property string label: ""
        property string valueText: ""
        property color accentDotColor: "transparent"
        property bool hasSubmenu: false
        property bool submenuActive: false
        signal triggered()
        signal hoveredRowChanged(bool hovered, var rowItem)

        readonly property bool isLit: rowMouse.containsMouse || rowHover.hovered || submenuActive

        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: menuWindow.radSmall
        color: submenuActive
            ? menuWindow.colSelection
            : (isLit ? menuWindow.colLayerHover : "transparent")
        border.width: submenuActive ? 1 : 0
        border.color: menuWindow.colBorderFocus

        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 9 }
            spacing: 10

            MaterialSymbol {
                text: rowItem.icon
                iconSize: 18
                fill: rowItem.isLit ? 1 : 0
                color: rowItem.isLit ? menuWindow.colPrimary : menuWindow.colTextMuted
            }

            Text {
                Layout.fillWidth: true
                text: rowItem.label
                color: menuWindow.colText
                font.family: menuWindow.uiFont
                font.pixelSize: 13
                font.weight: rowItem.isLit ? Font.DemiBold : Font.Normal
                renderType: Text.QtRendering
                elide: Text.ElideRight
            }

            Rectangle {
                visible: rowItem.accentDotColor !== Qt.color("transparent") && String(rowItem.accentDotColor) !== "#00000000"
                Layout.preferredWidth: 9
                Layout.preferredHeight: 9
                radius: 2
                color: rowItem.accentDotColor
            }

            Text {
                visible: rowItem.valueText !== ""
                text: rowItem.valueText
                color: menuWindow.colTextMuted
                font.family: menuWindow.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
                renderType: Text.QtRendering
            }

            MaterialSymbol {
                visible: rowItem.hasSubmenu
                text: "chevron_right"
                iconSize: 16
                color: rowItem.isLit ? menuWindow.colPrimary : menuWindow.colTextMuted
            }
        }

        HoverHandler {
            id: rowHover
            onHoveredChanged: rowItem.hoveredRowChanged(hovered, rowItem)
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rowItem.triggered()
        }
    }
}
