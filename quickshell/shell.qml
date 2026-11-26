//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
//@ pragma DefaultEnv __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
//@ pragma DefaultEnv MALLOC_ARENA_MAX=2
//@ pragma DefaultEnv MALLOC_TRIM_THRESHOLD_=131072
//@ pragma DefaultEnv MALLOC_MMAP_THRESHOLD_=131072

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Notifications
import "./modules"
import "./modules/widgets"
import "./" // Imports NotchConfig singleton
import qs
import qs.services
import qs.modules.irislock

ShellRoot {
    id: root

    readonly property alias hotspot: hotspotController
    readonly property alias notepadStore: notesData
    readonly property bool hotspotPanelOpen: activeMode === "wifi" && wifiMod?.activeTab === "hotspot"
    readonly property bool notesPinned: activeMode === "notes" && (notesMod?.isPinned ?? false)

    NotepadStore { id: notesData }

    HotspotController {
        id: hotspotController
        monitoring: root.hotspotPanelOpen || root.activeMode === "utility" || root.activeMode === "tooldeck"
        onOperationFailedChanged: {
            if (operationFailed && !root.hotspotPanelOpen)
                Quickshell.execDetached(["notify-send", "Hotspot", feedback]);
        }
    }

    property string activeMode: "idle"
    property bool settingsOpen: false
    property string initialSettingsPage: "keybinds"
    property string previousExpandedMode: "theme"
    property bool isWorkspacePeeking: false
    property bool isScreenRecording: false
    property bool isScreenRecordingPaused: false
    property int screenRecordSeconds: 0
    property string recSaveDirectory: "~/Videos"
    property bool recAudioEnabled: false
    property bool recSoundEnabled: true
    property string recAudioSourceId: ""
    property string recAudioSourceName: "Default Microphone"

    // Fullscreen auto-hide & top-edge hover reveal state (true fullscreen mode 2 only, not maximized mode 1)
    property bool isWindowFullscreen: false
    property bool fullscreenHoverRevealed: false
    property bool fullscreenCheckPending: false

    onIsWindowFullscreenChanged: {
        if (!root.isWindowFullscreen) {
            root.fullscreenHoverRevealed = false;
        }
    }

    readonly property bool notchHidden: {
        if (!root.isWindowFullscreen) return false;
        if (root.activeMode !== "idle" && root.activeMode !== "hover") return false;
        if (root.fullscreenHoverRevealed) return false;
        if (root.isNotifPopupActive) return false;
        if (root.isScreenshotIslandActive) return false;
        if (root.isWorkspacePeeking) return false;
        return true;
    }

    Timer {
        id: screenRecordTimer
        interval: 1000
        running: root.isScreenRecording && !root.isScreenRecordingPaused
        repeat: true
        onTriggered: root.screenRecordSeconds++
    }

    Process {
        id: globalRecordChecker
        running: false
        command: [Quickshell.shellPath("scripts/record.sh"), "--status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    root.isScreenRecording = (data.active === true);
                    root.isScreenRecordingPaused = (data.paused === true);
                    if (data.seconds !== undefined && data.seconds > 0) {
                        root.screenRecordSeconds = data.seconds;
                    } else if (!data.active) {
                        root.screenRecordSeconds = 0;
                    }
                } catch(e) {
                    root.isScreenRecording = false;
                    root.isScreenRecordingPaused = false;
                }
            }
        }
    }

    Timer {
        id: globalRecordPollTimer
        interval: root.isScreenRecording ? 1000 : 8000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (!globalRecordChecker.running) {
                globalRecordChecker.running = true;
            }
        }
    }

    function formatRecTime(sec) {
        var s = sec || 0;
        var m = Math.floor(s / 60);
        var remSec = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (remSec < 10 ? "0" : "") + remSec;
    }

    function startRecording(regionMode = false) {
        var script = Quickshell.shellPath("scripts/record.sh");
        var args = [script];
        if (regionMode) args.push("--region");
        if (root.recSoundEnabled) args.push("--sound");
        if (root.recAudioEnabled) args.push("--mic");
        Quickshell.execDetached(args);
        root.isScreenRecording = true;
        root.isScreenRecordingPaused = false;
        root.screenRecordSeconds = 0;
        root.collapseToIdle();
    }

    function stopRecording() {
        var script = Quickshell.shellPath("scripts/record.sh");
        Quickshell.execDetached([script, "--stop"]);
        root.isScreenRecording = false;
        root.isScreenRecordingPaused = false;
        root.screenRecordSeconds = 0;
    }

    function togglePauseRecording() {
        var script = Quickshell.shellPath("scripts/record.sh");
        Quickshell.execDetached([script, "--pause"]);
        root.isScreenRecordingPaused = !root.isScreenRecordingPaused;
    }
    property bool openedViaShortcut: false

    // Persistent notifications store
    ListModel {
        id: globalNotifModel
    }

    property var notificationBanner: null
    property bool isNotifPopupActive: false
    property bool notificationBannerHovered: false

    function notificationPreview(text) {
        return text.replace(/<\/?(?:a|b|br|em|i|img|p|s|span|strong|u)(?:\s[^>]*?)?\s*\/?>/gi, " ")
            .replace(/&(?:amp|lt|gt|quot|apos);/g, token => ({
                "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"', "&apos;": "'"
            })[token])
            .replace(/\s+/g, " ").trim();
    }

    function dismissNotificationBanner() {
        notifPopupTimer.stop();
        root.isNotifPopupActive = false;
        root.notificationBannerHovered = false;
    }

    function setNotificationBannerHovered(hovered) {
        if (!root.isNotifPopupActive || hovered === root.notificationBannerHovered) return;
        root.notificationBannerHovered = hovered;
        if (hovered) notifPopupTimer.stop();
        else notifPopupTimer.restart();
    }

    Timer {
        id: notifPopupTimer
        interval: NotchConfig.timerNotifPopup
        onTriggered: root.dismissNotificationBanner()
    }

    // Screenshot Island State (Section 4.1 Screenshot Annotation Hub)
    property string screenshotIslandPath: ""
    property string screenshotIslandStatus: ""
    readonly property bool isScreenshotIslandActive: screenshotIslandPath !== ""

    Timer {
        id: screenshotIslandTimer
        interval: 8000
        repeat: false
        onTriggered: {
            root.screenshotIslandPath = "";
            root.screenshotIslandStatus = "";
            if (root.activeMode === "idle" && !notchHoverHandler.hovered) {
                root.collapseToIdle();
            }
        }
    }

    Timer {
        id: screenshotActionFeedbackTimer
        interval: 1400
        repeat: false
        onTriggered: {
            root.screenshotIslandPath = "";
            root.screenshotIslandStatus = "";
            if (root.activeMode === "idle" && !notchHoverHandler.hovered) {
                root.collapseToIdle();
            }
        }
    }

    function triggerScreenshotHub(filePath) {
        if (!filePath) return;
        root.screenshotIslandStatus = "";
        root.screenshotIslandPath = filePath;
        screenshotIslandTimer.restart();
        if (root.activeMode !== "idle" && root.activeMode !== "hover") {
            root.collapseToIdle();
        }
    }

    property bool isServerReady: false

    Timer {
        id: startupGraceTimer
        interval: NotchConfig.timerStartupGrace
        running: true
        repeat: false
        onTriggered: root.isServerReady = true
    }

    property bool dndEnabled: false



    // Native D-Bus Notification Server
    NotificationServer {
        id: notifServer

        onNotification: (notification) => {
            notification.tracked = true;

            var summaryText = notification.summary || "";
            var bodyText = notification.body || "";
            var appNameText = notification.appName || "System";
            var appIconText = notification.appIcon || "";

            var exists = false;
            for (var i = 0; i < globalNotifModel.count; i++) {
                var item = globalNotifModel.get(i);
                if (item.summary === summaryText && item.body === bodyText && item.appName === appNameText) {
                    exists = true;
                    break;
                }
            }

            if (!exists) {
                globalNotifModel.insert(0, {
                    "summary": summaryText,
                    "body": bodyText,
                    "appName": appNameText,
                    "appIcon": appIconText,
                    "notifObj": notification
                });
            }

            if (root.isServerReady && !root.dndEnabled) {
                const app = root.notificationPreview(appNameText) || "System";
                root.notificationBanner = {
                    summary: root.notificationPreview(summaryText) || app,
                    body: root.notificationPreview(bodyText),
                    app,
                    icon: appIconText || notification.desktopEntry || "",
                    critical: notification.urgency === NotificationUrgency.Critical
                };
                root.isNotifPopupActive = true;
                if (!root.notificationBannerHovered) notifPopupTimer.restart();
            }
        }
    }

    readonly property bool isDashMode: activeMode === "idle" || activeMode === "hover"
    readonly property bool isExpanding: !isDashMode && activeMode !== "osd"
    readonly property bool expandedContentReady: isExpanding && modulesContainer.contentBlend >= 0.98
        && modulesContainer.revealProgress >= 0.98 && modulesContainer.pageBlend >= 0.98
    readonly property color notchSurfaceColor: Theme.colors.bg ?? "#000000"
    readonly property bool isPopupMode: activeMode !== "idle" && activeMode !== "osd"

    function collapseToIdle() {
        root.isWorkspacePeeking = false;
        root.openedViaShortcut = false;
        root.activeMode = "idle";
        if (typeof GlobalStates !== "undefined") {
            GlobalStates.overviewOpen = false;
        }
    }

    function openSettings(page) {
        root.collapseToIdle();
        if (page && page.length > 0) {
            root.initialSettingsPage = page;
            if (settingsModalLoader.item && typeof settingsModalLoader.item.setPage === "function") {
                settingsModalLoader.item.setPage(page);
            }
        }
        root.settingsOpen = true;
    }

    function switchMode(newMode, fromShortcut = false) {
        root.isWorkspacePeeking = false;
        if (root.activeMode === newMode) {
            root.collapseToIdle();
        } else {
            root.openedViaShortcut = fromShortcut;
            root.activeMode = newMode;
            if (typeof GlobalStates !== "undefined") {
                if (newMode === "launcher") {
                    if (typeof GlobalStates !== "undefined") {
                GlobalStates.overviewOpen = true;
            }
                } else {
                    GlobalStates.overviewOpen = false;
                }
            }
            if (root.isWindowFullscreen) {
                root.fullscreenHoverRevealed = true;
            }
        }
    }

    // Dynamic Module Lazy Loader & State
    property string loadedExpandedMode: ""
    property string requestedUtilitySection: ""
    property string requestedMusicPanel: ""
    property string pendingSearchQuery: ""

    // Persistent caches for instant zero-latency module rendering across the entire shell
    property var cachedApps: []
    property bool desktopEntriesIndexed: false
    property Component launcherDefinition: null
    property var cachedWallpapers: []
    property string cachedActiveWallpaper: ""
    property var cachedBatteryTelemetry: null
    property var cachedThemes: []

    Timer {
        id: moduleUnloadTimer
        interval: 8000 // 8s grace period: promptly unloads modules and releases memory
        repeat: false
        onTriggered: {
            if (root.activeMode === "idle" || root.activeMode === "hover" || root.activeMode === "osd") {
                root.loadedExpandedMode = "";
                gc();
            }
        }
    }

    // Native DesktopEntries sync (matching Caelestia architecture)
    Timer {
        id: deSyncDebounce
        interval: 60
        repeat: false
        onTriggered: root.syncDesktopEntries()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            deSyncDebounce.restart();
        }
    }

    Connections {
        target: (typeof GlobalStates !== "undefined") ? GlobalStates : null
        function onOverviewOpenChanged() {
            if (typeof GlobalStates !== "undefined" && !GlobalStates.overviewOpen && root.activeMode === "launcher") {
                root.collapseToIdle();
            }
        }
    }

    function syncDesktopEntries() {
        var rawApps = DesktopEntries.applications.values;
        if (!rawApps) return;
        var list = [];
        for (var i = 0; i < rawApps.length; i++) {
            var entry = rawApps[i];
            if (!entry || entry.noDisplay || !entry.name) continue;
            var cmdStr = "";
            if (typeof entry.execString === "string" && entry.execString.trim() !== "") {
                cmdStr = entry.execString.trim();
            } else if (entry.command) {
                if (typeof entry.command === "string") {
                    cmdStr = entry.command.trim();
                } else {
                    try {
                        cmdStr = Array.from(entry.command).join(" ").trim();
                    } catch (e) {
                        cmdStr = String(entry.command).trim();
                    }
                }
            } else if (entry.id) {
                cmdStr = "gtk-launch " + entry.id;
            }
            if (!cmdStr && typeof entry.execute !== "function") continue;
            var cleanExec = cmdStr.replace(/%[fFuUiDcnmk]/g, "").trim();
            list.push({
                name: String(entry.name),
                exec: String(cleanExec),
                iconName: (entry.icon ? String(entry.icon) : ""),
                comment: (entry.comment ? String(entry.comment) : (entry.genericName ? String(entry.genericName) : "")),
                id: (entry.id ? String(entry.id) : ""),
                rawEntry: entry
            });
        }
        list.sort(function(a, b) { return a.name.localeCompare(b.name); });
        root.cachedApps = list;
        root.desktopEntriesIndexed = true;
    }

    // Warm the app index and compiled QML after the bar has drawn. The launcher
    // instance still follows the normal module unload timer.
    Timer {
        interval: 450
        running: true
        onTriggered: {
            if (!root.desktopEntriesIndexed) root.syncDesktopEntries();
            root.launcherDefinition = Qt.createComponent(root.getModuleSource("launcher"), Component.Asynchronous);
        }
    }

    // Background Global Wallpaper Scanner
    function refreshWallpaperCache() {
        root.cachedWallpapers = [];
        globalWallpaperScanTimer.restart();
    }

    Process {
        id: globalWallpaperScanner
        running: false
        command: ["sh", "-c", `python3 -c "
import os, subprocess

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
wall_dir = ''
for c in [os.path.join(home, f'Pictures/Wallpapers/{theme}'), os.path.join(home, f'Pictures/Wallpapers/{theme_lower}')]:
    if os.path.isdir(c):
        wall_dir = c
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

exts = ('.jpg', '.jpeg', '.png', '.webp', '.mp4')
files = []
if wall_dir and os.path.exists(wall_dir):
    for root_dir, dirs, fnames in os.walk(wall_dir):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for fn in fnames:
            if fn.lower().endswith(exts) and not fn.startswith('.'):
                files.append(os.path.join(root_dir, fn))

if not files:
    base = os.path.join(home, 'Pictures/Wallpapers')
    if os.path.isdir(base):
        for root_dir, dirs, fnames in os.walk(base):
            dirs[:] = [d for d in dirs if not d.startswith('.')]
            for fn in fnames:
                if fn.lower().endswith(exts) and not fn.startswith('.'):
                    files.append(os.path.join(root_dir, fn))

if active_wall and os.path.isfile(active_wall) and active_wall not in files:
    files.append(active_wall)

def safe_mtime(p):
    try: return os.path.getmtime(p)
    except Exception: return 0

files_with_mtime = [(f, safe_mtime(f)) for f in set(files) if os.path.isfile(f)]
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
                var temp = [];
                var activeFromQuery = "";

                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|||");
                    if (parts.length >= 2) {
                        var act = parts.length >= 4 ? parts[3].trim() : "";
                        if (act !== "") activeFromQuery = act;
                        temp.push({
                            "name": parts[0],
                            "path": parts[1],
                            "thumb": parts.length >= 3 ? parts[2] : "",
                            "mtime": parts.length >= 5 ? (parseInt(parts[4]) || 0) : 0,
                            "temp": false
                        });
                    }
                }

                if (temp.length > 0) {
                    root.cachedWallpapers = temp;
                    if (activeFromQuery !== "") root.cachedActiveWallpaper = activeFromQuery;
                }
            }
        }
    }

    Timer {
        id: globalWallpaperScanTimer
        interval: 250
        running: true
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            if (!globalWallpaperScanner.running) globalWallpaperScanner.running = true;
        }
    }

    Connections {
        target: Theme
        function onCurrentThemeNameChanged() {
            if (!globalWallpaperScanner.running) globalWallpaperScanner.running = true;
        }
    }

    function getModuleSource(mode) {
        switch(mode) {
            case "launcher":      return Qt.resolvedUrl("modules/Launcher.qml");
            case "theme":         return Qt.resolvedUrl("modules/ThemeSelector.qml");
            case "wallpaper":     return Qt.resolvedUrl("modules/WallpaperSelector.qml");
            case "wallsort":      return Qt.resolvedUrl("modules/WallpaperSorterModule.qml");
            case "lockscreen":     return Qt.resolvedUrl("modules/ThemeWallpaperSelector.qml");
            case "engine":        return Qt.resolvedUrl("modules/EngineWallpaperSelector.qml");
            case "transition":    return Qt.resolvedUrl("modules/TransitionSelector.qml");
            case "bluetooth":     return Qt.resolvedUrl("modules/BluetoothModule.qml");
            case "wifi":          return Qt.resolvedUrl("modules/WifiModule.qml");
            case "recorder":      return Qt.resolvedUrl("modules/RecorderModule.qml");
            case "battery":       return Qt.resolvedUrl("modules/BatteryModule.qml");
            case "powermenu":     return Qt.resolvedUrl("modules/PowerMenu.qml");
            case "calendar":      return Qt.resolvedUrl("modules/CalendarModule.qml");
            case "clipboard":     return Qt.resolvedUrl("modules/ClipboardModule.qml");
            case "notifications": return Qt.resolvedUrl("modules/NotificationModule.qml");
            case "switcher":      return Qt.resolvedUrl("modules/WindowSwitcher.qml");
            case "utility":       return Qt.resolvedUrl("modules/UtilityModule.qml");
            case "music":         return Qt.resolvedUrl("modules/MusicModule.qml");
            case "notes":         return Qt.resolvedUrl("modules/NotesModule.qml");
            case "cheatsheet":    return Qt.resolvedUrl("modules/KeybindsModule.qml");
            case "wallhaven":     return Qt.resolvedUrl("modules/WallhavenModule.qml");
            case "taskmanager":   return Qt.resolvedUrl("modules/TaskManagerModule.qml");
            default:              return "";
        }
    }

    // Dynamic Module Aliases (Null-safe; points to moduleLoader.item when active)
    readonly property var dashMod:       dashLoader ? dashLoader.item : null
    readonly property var launcherMod:   (root.loadedExpandedMode === "launcher") ? moduleLoader.item : null
    readonly property var themeMod:      (root.loadedExpandedMode === "theme") ? moduleLoader.item : null
    readonly property var wallMod:       (root.loadedExpandedMode === "wallpaper") ? moduleLoader.item : null
    readonly property var wallSortMod:   (root.loadedExpandedMode === "wallsort") ? moduleLoader.item : null
    readonly property var engineMod:     (root.loadedExpandedMode === "engine") ? moduleLoader.item : null
    readonly property var transMod:      (root.loadedExpandedMode === "transition") ? moduleLoader.item : null
    readonly property var btMod:         (root.loadedExpandedMode === "bluetooth") ? moduleLoader.item : null
    readonly property var wifiMod:       (root.loadedExpandedMode === "wifi") ? moduleLoader.item : null
    readonly property var recMod:        (root.loadedExpandedMode === "recorder") ? moduleLoader.item : null
    readonly property var battMod:       (root.loadedExpandedMode === "battery") ? moduleLoader.item : null
    readonly property var powerMod:      (root.loadedExpandedMode === "powermenu") ? moduleLoader.item : null
    readonly property var calMod:        (root.loadedExpandedMode === "calendar") ? moduleLoader.item : null
    readonly property var clipMod:       (root.loadedExpandedMode === "clipboard") ? moduleLoader.item : null
    readonly property var notifMod:      (root.loadedExpandedMode === "notifications") ? moduleLoader.item : null
    readonly property var switcherMod:   (root.loadedExpandedMode === "switcher") ? moduleLoader.item : null
    readonly property var utilMod:       (root.loadedExpandedMode === "utility") ? moduleLoader.item : null
    readonly property var musicMod:      (root.loadedExpandedMode === "music") ? moduleLoader.item : null
    readonly property var notesMod:      (root.loadedExpandedMode === "notes") ? moduleLoader.item : null
    readonly property var cheatsheetMod: (root.loadedExpandedMode === "cheatsheet") ? moduleLoader.item : null
    readonly property var wallhavenMod:  (root.loadedExpandedMode === "wallhaven") ? moduleLoader.item : null
    readonly property var taskMgrMod:    (root.loadedExpandedMode === "taskmanager") ? moduleLoader.item : null

    property string requestedClockTab: ""
    function openClockTab(tab) {
        root.requestedClockTab = tab || "calendar";
        if (root.activeMode !== "calendar") {
            root.switchMode("calendar", true);
        }
        if (root.calMod && typeof root.calMod.showTab === "function") {
            root.calMod.showTab(tab);
            root.requestedClockTab = "";
        }
    }

    function openUtility(section = "", fromShortcut = false) {
        if (section === "pomo") {
            root.openClockTab("timer");
            return;
        }
        root.isWorkspacePeeking = false;
        if (root.activeMode === "utility" && root.utilMod && root.utilMod.activeSection === section) {
            root.collapseToIdle();
        } else {
            root.requestedUtilitySection = section;
            if (root.utilMod) {
                root.utilMod.activeSection = section;
            }
            root.openedViaShortcut = fromShortcut;
            root.activeMode = "utility";
            if (root.isWindowFullscreen) {
                root.fullscreenHoverRevealed = true;
            }
        }
    }

	function regainFocus() {
        if (activeMode === "launcher" && root.launcherMod) root.launcherMod.searchInput.forceActiveFocus();
		else if (activeMode === "switcher" && root.switcherMod) root.switcherMod.forceActiveFocus();
        else if (activeMode === "theme" && root.themeMod) root.themeMod.forceThemeFocus();
        else if (activeMode === "wallpaper" && root.wallMod) {
            if (root.wallMod.searchInput) root.wallMod.searchInput.forceActiveFocus();
            else if (typeof root.wallMod.forceActiveFocus === "function") root.wallMod.forceActiveFocus();
            else root.wallMod.focus = true;
        }
        else if (activeMode === "transition" && root.transMod) root.transMod.transitionGrid.forceActiveFocus();
        else if (activeMode === "clipboard" && root.clipMod) root.clipMod.searchInput.forceActiveFocus();
        else if (activeMode === "powermenu" && root.powerMod) root.powerMod.forceActiveFocus();
        else if (activeMode === "notes" && root.notesMod) root.notesMod.forceNotesFocus();
        else if (activeMode === "cheatsheet" && root.cheatsheetMod) root.cheatsheetMod.forceSearchFocus();
        else if (activeMode === "taskmanager" && root.taskMgrMod) root.taskMgrMod.forceSearchFocus();
        else if (activeMode === "music" && root.musicMod) root.musicMod.forceActiveFocus();
        else if (typeof moduleLoader !== "undefined" && moduleLoader.item) moduleLoader.item.forceActiveFocus();
        else notchContainer.forceActiveFocus();
    }

    onActiveModeChanged: {
        const launcherWasLoaded = root.launcherMod !== null;
        if (activeMode !== "idle" && activeMode !== "hover" && activeMode !== "osd") {
            root.previousExpandedMode = activeMode;
            moduleUnloadTimer.stop();
            root.loadedExpandedMode = activeMode;
        } else {
            moduleUnloadTimer.restart();
        }

        if (activeMode === "idle") {
            root.openedViaShortcut = false;
        } else if (activeMode === "wifi") {
            if (root.wifiMod) {
                root.wifiMod.activeTab = "wifi";
                root.wifiMod.refreshStatus();
            }
        }

        if (activeMode === "launcher") {
            if (launcherWasLoaded && root.launcherMod) root.launcherMod.onOpened();
        } else if (activeMode === "lockscreen") {
            Qt.callLater(() => {
                if (root.activeMode === "lockscreen" && moduleLoader.item)
                    moduleLoader.item.switchTab("lockscreen");
            });
        } else if (activeMode === "wallpaper") {
            if (root.cachedWallpapers.length === 0 && !globalWallpaperScanner.running) globalWallpaperScanner.running = true;
        }

        Qt.callLater(() => {
            root.regainFocus();
            if (activeMode !== "launcher" && root.launcherMod) root.launcherMod.searchInput.text = "";
            if (activeMode !== "theme" && root.themeMod) root.themeMod.resetSearch();
            if (activeMode !== "clipboard" && root.clipMod) root.clipMod.searchInput.text = "";
            if (activeMode !== "taskmanager" && root.taskMgrMod) root.taskMgrMod.searchInput.text = "";
        });
    }

    // ========================================================
    // CENTRALIZED DIMENSIONS RESOLUTION (from NotchConfig)
    // ========================================================
    readonly property int targetWidth: {
        var calculatedWidth = NotchConfig.modeDimensions["idle"].width;
        if (isDashMode && typeof dashMod !== "undefined" && dashMod !== null) {
            calculatedWidth = dashMod.implicitWidth;
        } else if (activeMode === "notes" && root.notesMod && root.notesMod.isWideMode) {
            calculatedWidth = 820;
        } else if (activeMode === "utility" && root.utilMod && root.utilMod.activeSection === "vpn") {
            calculatedWidth = 420;
        } else if (activeMode === "launcher") {
            calculatedWidth = (root.launcherMod && root.launcherMod.targetWidth > 0)
                ? root.launcherMod.targetWidth
                : (NotchConfig.modeDimensions["launcher"] ? NotchConfig.modeDimensions["launcher"].width : 580);
        } else if (activeMode === "calendar") {
            calculatedWidth = (root.calMod && root.calMod.targetWidth > 0)
                ? root.calMod.targetWidth
                : (NotchConfig.modeDimensions["calendar"] ? NotchConfig.modeDimensions["calendar"].width : 720);
        } else if (activeMode === "clipboard") {
            calculatedWidth = (root.clipMod && root.clipMod.targetWidth > 0)
                ? root.clipMod.targetWidth
                : (NotchConfig.modeDimensions["clipboard"] ? NotchConfig.modeDimensions["clipboard"].width : 480);
        } else {
            var dim = NotchConfig.modeDimensions[activeMode];
            calculatedWidth = (dim && dim.width !== undefined) ? dim.width : NotchConfig.modeDimensions["idle"].width;
        }
        var maxW = (panel && panel.width > 0) ? (panel.width - 32) : 1920;
        return Math.min(maxW, calculatedWidth);
    }
    
    readonly property int targetHeight: {
        var calculatedHeight = NotchConfig.modeDimensions["idle"] ? NotchConfig.modeDimensions["idle"].height : 38;
        if (root.isScreenshotIslandActive && root.isDashMode) {
            calculatedHeight = 44;
        } else if (root.isNotifPopupActive && root.isDashMode) {
            calculatedHeight = dashMod ? dashMod.notificationHeight : NotchConfig.heightNotifBanner;
        } else if (activeMode === "cheatsheet" && root.cheatsheetMod && root.cheatsheetMod.isAddingMode) {
            calculatedHeight = 500;
        } else if (activeMode === "launcher") {
            calculatedHeight = (root.launcherMod && root.launcherMod.targetHeight > 0)
                ? root.launcherMod.targetHeight
                : 500;
        } else if (activeMode === "calendar") {
            calculatedHeight = (root.calMod && root.calMod.targetHeight > 0)
                ? root.calMod.targetHeight
                : (NotchConfig.modeDimensions["calendar"] ? NotchConfig.modeDimensions["calendar"].height : 490);
        } else if (activeMode === "battery") {
            calculatedHeight = (root.battMod && root.battMod.calculatedHeight)
                ? root.battMod.calculatedHeight
                : (NotchConfig.modeDimensions["battery"] ? NotchConfig.modeDimensions["battery"].height : 382);
        } else if (activeMode === "notes") {
            calculatedHeight = (root.notesMod && root.notesMod.isWideMode) ? 520 : 480;
        } else if (activeMode === "transition" || activeMode === "powermenu" || activeMode === "cheatsheet") {
            var mDim = NotchConfig.modeDimensions[activeMode];
            calculatedHeight = (mDim && mDim.height !== undefined) ? mDim.height : 220;
        } else if (activeMode === "notifications") {
            calculatedHeight = NotchConfig.calculateNotificationsHeight(globalNotifModel.count);
        } else if (activeMode === "clipboard") {
            calculatedHeight = (root.clipMod && root.clipMod.calculatedHeight > 0)
                ? root.clipMod.calculatedHeight
                : NotchConfig.calculateClipboardHeight(root.clipMod ? root.clipMod.calculatedCount : 0);
        } else if (activeMode === "recorder") {
            calculatedHeight = root.recMod 
                ? root.recMod.calculatedHeight
                : 270;
        } else if (activeMode === "bluetooth") {
            calculatedHeight = (root.btMod && root.btMod.calculatedHeight)
                ? root.btMod.calculatedHeight
                : (NotchConfig.modeDimensions["bluetooth"] ? NotchConfig.modeDimensions["bluetooth"].height : 280);
        } else if (activeMode === "wifi") {
            calculatedHeight = (root.wifiMod && root.wifiMod.calculatedHeight)
                ? root.wifiMod.calculatedHeight
                : ((root.wifiMod && root.wifiMod.model)
                    ? NotchConfig.calculateWifiHeight(root.wifiMod.activeTab, root.wifiMod.wifiEnabled, root.wifiMod.model.count, root.wifiMod.listViewContentHeight, root.wifiMod.ethernetData !== null)
                    : 380);
        } else if (activeMode === "utility") {
            calculatedHeight = root.utilMod
                ? (root.utilMod.activeSection === "audio" ? root.utilMod.audioPanelHeight
                    : NotchConfig.calculateUtilityHeight(root.utilMod.activeSection))
                : 400;
        } else if (activeMode === "music") {
            calculatedHeight = (root.musicMod && root.musicMod.calculatedHeight) ? root.musicMod.calculatedHeight : 265;
        } else if (activeMode === "wallhaven") {
            calculatedHeight = (root.wallhavenMod && root.wallhavenMod.targetHeight > 0) ? root.wallhavenMod.targetHeight : 860;
        } else if (activeMode === "taskmanager") {
            calculatedHeight = (NotchConfig.modeDimensions["taskmanager"] && NotchConfig.modeDimensions["taskmanager"].height !== undefined)
                ? NotchConfig.modeDimensions["taskmanager"].height
                : 620;
        } else if (activeMode === "idle") {
            calculatedHeight = NotchConfig.modeDimensions["idle"] ? NotchConfig.modeDimensions["idle"].height : 38;
        } else if (activeMode === "hover") {
            calculatedHeight = 44;
        } else {
            var hDim = NotchConfig.modeDimensions[activeMode];
            calculatedHeight = (hDim && hDim.height !== undefined) ? hDim.height : NotchConfig.modeDimensions["idle"].height;
        }
        var maxH = (panel && panel.height > 0) ? (panel.height - 48) : 1080;
        return Math.min(maxH, calculatedHeight);
    } 

    readonly property int targetRadius: {
        if ((dashMod && dashMod.isIslandActive) || (root.isNotifPopupActive && root.isDashMode) || (root.isScreenshotIslandActive && root.isDashMode)) {
            return 21;
        }
        if (activeMode === "idle") {
            return NotchConfig.modeDimensions["idle"] ? NotchConfig.modeDimensions["idle"].radius : 19;
        }
        if (activeMode === "hover") {
            return 22;
        }
        if (activeMode === "utility") {
            return 28;
        }
        if (activeMode === "music") {
            return 26;
        }
        var rDim = NotchConfig.modeDimensions[activeMode];
        return rDim && rDim.radius !== undefined ? rDim.radius : NotchConfig.modeDimensions["idle"].radius;
    }
    readonly property int cornerCurveRadius: NotchConfig.cornerCurveRadius

    // OSD Engine
    property string osdType: "volume"
    property int osdValue: 50
    property string previousActiveMode: "idle"
    readonly property bool isOsdMode: activeMode === "osd" || previousActiveMode === "osd"

    function triggerOsd(type, val) {
        root.osdType = type;
        root.osdValue = Math.max(0, Math.min(100, val));
        if (root.utilMod) {
            if (type === "volume") {
                root.utilMod.audioVolume = root.osdValue / 100.0;
                root.utilMod.audioMuted = (root.osdValue <= 0);
            } else if (type === "brightness") {
                root.utilMod.displayBrightness = Math.max(0.01, root.osdValue / 100.0);
            }
        }
        if (root.activeMode !== "osd") {
            root.previousActiveMode = root.activeMode;
            root.activeMode = "osd";
        }
        osdHideTimer.restart();
    }

    Timer {
        id: osdResetPrevModeTimer
        interval: 240
        onTriggered: {
            if (root.previousActiveMode === "osd" && root.activeMode !== "osd") {
                root.previousActiveMode = root.activeMode;
            }
        }
    }

    Timer {
        id: osdHideTimer
        interval: NotchConfig.timerOsdHide
        onTriggered: {
            if (root.activeMode === "osd") {
                root.previousActiveMode = "osd";
                root.collapseToIdle();
                osdResetPrevModeTimer.restart();
            }
        }
    }

    Timer {
        id: workspaceSwitchSettleTimer
        interval: NotchConfig.timerWorkspacePeek
        repeat: false
        onTriggered: {
            root.isWorkspacePeeking = false;
        }
    }

    Timer {
        id: fullscreenCheckDebounce
        interval: 60
        repeat: false
        onTriggered: {
            if (!checkFullscreenProc.running) {
                checkFullscreenProc.running = true;
            } else {
                root.fullscreenCheckPending = true;
            }
        }
    }

    function triggerFullscreenCheck() {
        fullscreenCheckDebounce.restart();
    }

    Process {
        id: checkFullscreenProc
        running: false
        command: ["sh", Quickshell.env("HOME") + "/.config/quickshell/scripts/check_fullscreen.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                var isFull = (this.text.trim() === "1");
                root.isWindowFullscreen = isFull;
                if (!isFull) {
                    root.fullscreenHoverRevealed = false;
                }
                if (root.fullscreenCheckPending) {
                    root.fullscreenCheckPending = false;
                    checkFullscreenProc.running = true;
                }
            }
        }
    }

    Timer {
        id: fullscreenPollTimer
        interval: 30000 // Fallback poll; Hyprland events handle real-time changes
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            root.triggerFullscreenCheck();
        }
    }

    Connections {
        target: typeof Hyprland !== "undefined" ? Hyprland : null
        function onRawEvent(event) {
            var evName = (typeof event === "object" && event !== null) ? event.name : event;
            var evData = (typeof event === "object" && event !== null) ? (event.data || "") : "";

            if (evName === "fullscreen" || evName === "workspace" || evName === "focusedmon" || evName === "workspacev2" || evName === "activewindow" || evName === "openwindow" || evName === "closewindow") {
                root.triggerFullscreenCheck();
            }

            if (evName === "workspace" || evName === "focusedmon" || evName === "workspacev2") {
                if (typeof dashMod !== "undefined") dashMod.refreshWorkspaceIds();
                if (root.activeMode === "idle") {
                    root.isWorkspacePeeking = true;
                    workspaceSwitchSettleTimer.restart();
                } else if (root.isWorkspacePeeking) {
                    workspaceSwitchSettleTimer.restart();
                }
            }
        }
    }

    // Global Shortcuts
    GlobalShortcut {
        name: "toggleNotchLauncher"
        onPressed: {
            if (root.activeMode === "launcher") {
                root.collapseToIdle();
            } else {
                root.switchMode("launcher", true);
            }
        }
    }
    GlobalShortcut { name: "toggleLockscreenNotch"; onPressed: root.switchMode("lockscreen", true) }
    GlobalShortcut { name: "toggleThemeNotch"; onPressed: root.switchMode("theme", true) }
    GlobalShortcut { name: "toggleWallpaperNotch"; onPressed: root.switchMode("wallpaper", true) }
    GlobalShortcut { name: "toggleWallpaperEngineNotch"; onPressed: root.switchMode("engine", true) }
    GlobalShortcut { name: "toggleTransitionNotch"; onPressed: root.switchMode("transition", true) }
    GlobalShortcut { name: "resetNotchToIdle"; onPressed: root.collapseToIdle() }
    GlobalShortcut { name: "toggleBatteryNotch"; onPressed: root.switchMode("battery", true) }
    GlobalShortcut { name: "togglePowerMenuNotch"; onPressed: root.switchMode("powermenu", true) }
    GlobalShortcut { name: "toggleCalendarNotch"; onPressed: root.switchMode("calendar", true) }
    GlobalShortcut { name: "toggleClipboardNotch"; onPressed: root.switchMode("clipboard", true) }
    GlobalShortcut { name: "toggleNotificationsNotch"; onPressed: root.switchMode("notifications", true) }
    GlobalShortcut { name: "toggleDndNotch"; onPressed: root.dndEnabled = !root.dndEnabled }
    GlobalShortcut { 
        name: "toggleUtilityNotch"
        onPressed: root.openUtility("", true)
    }
    GlobalShortcut { 
        name: "toggleHoverNotch"
        onPressed: root.switchMode("hover", true)
    }
    GlobalShortcut { 
        name: "toggleMusicInfoNotch"
        onPressed: {
            if (root.activeMode === "music") {
                root.collapseToIdle();
            } else {
                root.switchMode("music", true);
            }
        }
    }
    GlobalShortcut { name: "toggleNotesNotch"; onPressed: root.switchMode("notes", true) }
    GlobalShortcut { name: "toggleCheatsheetNotch"; onPressed: root.switchMode("cheatsheet", true) }
    GlobalShortcut { name: "toggleTaskManagerNotch"; onPressed: root.switchMode("taskmanager", true) }
    GlobalShortcut { 
        name: "toggleWifiNotch"
        onPressed: root.switchMode("wifi", true)
    }
    GlobalShortcut { 
        name: "toggleBluetoothNotch"
        onPressed: root.switchMode("bluetooth", true)
    }
    GlobalShortcut { 
        name: "toggleRecorderNotch"
        onPressed: root.switchMode("recorder", true)
    }
    GlobalShortcut {
        name: "togglePomo"
        onPressed: Chrono.pomoToggle()
    }
    GlobalShortcut {
        name: "toggleSettings"
        onPressed: root.settingsOpen = !root.settingsOpen
    }

    GlobalShortcut {
        name: "toggleWidgetSidebar"
        onPressed: WidgetStore.toggleSidebar()
    }

    property bool switcherQuickTapArmed: false

    Timer {
        id: switcherOpenTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (root.switcherQuickTapArmed) {
                root.switcherQuickTapArmed = false;
                root.switchMode("switcher", true);
            }
        }
    }

    GlobalShortcut { 
        name: "cycleWindowNext"
        onPressed: {
            if (root.activeMode !== "switcher") {
                if (!switcherOpenTimer.running) {
                    root.switcherQuickTapArmed = true;
                    switcherOpenTimer.restart();
                    root.loadedExpandedMode = "switcher";
                    if (root.switcherMod) root.switcherMod.refreshClients();
                } else {
                    switcherOpenTimer.stop();
                    root.switcherQuickTapArmed = false;
                    root.switchMode("switcher", true);
                    if (root.switcherMod) root.switcherMod.cycleNext();
                }
            } else {
                if (root.switcherMod) root.switcherMod.cycleNext();
            }
        }
    }

    GlobalShortcut { 
        name: "cycleWindowPrev"
        onPressed: {
            if (root.activeMode !== "switcher") {
                if (!switcherOpenTimer.running) {
                    root.switcherQuickTapArmed = true;
                    switcherOpenTimer.restart();
                    root.loadedExpandedMode = "switcher";
                    if (root.switcherMod) root.switcherMod.refreshClients();
                } else {
                    switcherOpenTimer.stop();
                    root.switcherQuickTapArmed = false;
                    root.switchMode("switcher", true);
                    if (root.switcherMod) root.switcherMod.cyclePrev();
                }
            } else {
                if (root.switcherMod) root.switcherMod.cyclePrev();
            }
        }
    }

    GlobalShortcut {
        name: "confirmAltRelease"
        onPressed: {
            if (switcherOpenTimer.running && root.switcherQuickTapArmed) {
                switcherOpenTimer.stop();
                root.switcherQuickTapArmed = false;
                if (root.switcherMod) {
                    root.switcherMod.quickSwitchToLast();
                }
            } else if (root.activeMode === "switcher") {
                if (root.switcherMod) root.switcherMod.activateSelected();
            }
        }
    }

    IpcHandler {
        target: "workspaces"

        function open(): void {
            if (root.activeMode !== "hover")
                root.switchMode("hover", true);
        }

        function close(): void {
            if (root.activeMode === "hover")
                root.collapseToIdle();
        }

        function toggle(): void {
            if (root.activeMode === "hover")
                close();
            else
                open();
        }
    }

    IpcHandler {
        target: "sidebar"

        function toggle(): string {
            return WidgetStore.toggleSidebar();
        }

        function open(): string {
            return WidgetStore.openSidebar();
        }

        function close(): string {
            return WidgetStore.closeSidebar();
        }
    }

    IpcHandler {
        target: "widgets"

        function toggle(): string {
            return WidgetStore.toggleSidebar();
        }

        function open(): string {
            return WidgetStore.openSidebar();
        }

        function close(): string {
            return WidgetStore.closeSidebar();
        }

        function pin(cardId: string): string {
            const screenName = widgetSidebar.screen ? String(widgetSidebar.screen.name || "") : "";
            return WidgetStore.pinToDesktop(cardId, screenName) ? "OK" : "ERROR";
        }

        function unpin(cardId: string): string {
            return WidgetStore.setContainer(cardId, "sidebar") ? "OK" : "ERROR";
        }

        function returnAll(): string {
            WidgetStore.returnAllToSidebar();
            return "OK";
        }

        function toggleClockStyle(): string {
            WidgetStore.toggleClockStyle();
            return WidgetStore.clockStyle;
        }

        function toggleMusicStyle(): string {
            WidgetStore.toggleMusicStyle();
            return WidgetStore.musicStyle;
        }

        function toggleSide(): string {
            WidgetStore.toggleSidebarSide();
            return WidgetStore.sidebarSide;
        }

        function scrollFraction(frac: real): string {
            return widgetSidebar.scrollDrawer(frac);
        }

        function setOption(cardId: string, key: string, val: string): string {
            let parsed = val;
            if (val === "true") parsed = true;
            else if (val === "false") parsed = false;
            return WidgetStore.setCardOption(cardId, key, parsed) ? "OK" : "ERROR";
        }

        function openMenu(cardId: string): string {
            return WidgetStore.openMenu(cardId);
        }

        function openDesktopMenu(xPos: real, yPos: real): string {
            return WidgetStore.openDesktopMenu(xPos, yPos);
        }
    }

    IpcHandler {
        target: "notch"
        function toggleSettings(): string {
            root.collapseToIdle();
            root.settingsOpen = !root.settingsOpen;
            return "OK";
        }
        function openSettings(): string {
            root.openSettings("");
            return "OK";
        }
        function openSettingsPage(page: string): string {
            root.openSettings(page);
            return "OK";
        }
        function checkSettings(): string {
            return "settingsOpen: " + root.settingsOpen + " page: " + root.initialSettingsPage;
        }
        function getActiveMode(): string {
            return root.activeMode;
        }
        function setCalendarTab(tabName: string): string {
            if (root.calMod) {
                root.calMod.showTab(tabName);
                return "OK: " + root.calMod.tab;
            }
            return "calMod null";
        }
        function openClockTab(tabName: string): string {
            root.openClockTab(tabName);
            return "OK";
        }
        function isOverviewOpen(): string {
            return "" + (typeof GlobalStates !== "undefined" ? GlobalStates.overviewOpen : false);
        }
        function getLauncherDebug(): string {
            var sm = root.launcherMod;
            var si = sm ? sm.searchInput : null;
            var ar = sm && sm.searchWidget ? sm.searchWidget.appResults : null;
            return "activeMode=" + root.activeMode
                 + " targetW=" + root.targetWidth
                 + " targetH=" + root.targetHeight
                 + " notchW=" + notch.width
                 + " notchH=" + notch.height
                 + " launcherMod=" + (sm ? "exists" : "null")
                 + " siFocus=" + (si ? si.focus : "null")
                 + " siActiveFocus=" + (si ? si.activeFocus : "null")
                 + " overviewOpen=" + (typeof GlobalStates !== "undefined" ? GlobalStates.overviewOpen : "null")
                 + " realResults=" + (sm && sm.searchWidget ? sm.searchWidget.realResultCount : "null")
                 + " arCount=" + (ar ? ar.count : "null")
                 + " arIndex=" + (ar ? ar.currentIndex : "null");
        }
        function activate(): string {
            if (root.activeMode === "clipboard" && root.clipMod && typeof root.clipMod.activateSelected === "function") {
                return "res=" + root.clipMod.activateSelected();
            }
            if (root.launcherMod && typeof root.launcherMod.activateSelected === "function") {
                return "res=" + root.launcherMod.activateSelected();
            }
            return "no target";
        }
        function navDown(): string {
            if (root.activeMode === "clipboard" && root.clipMod && typeof root.clipMod.navDown === "function") {
                return "res=" + root.clipMod.navDown();
            }
            if (root.launcherMod && root.launcherMod.searchWidget && root.launcherMod.searchWidget.searchKeyRouter) {
                return "res=" + root.launcherMod.searchWidget.searchKeyRouter.dispatch("navigateDown");
            }
            return "no router";
        }
        function navUp(): string {
            if (root.activeMode === "clipboard" && root.clipMod && typeof root.clipMod.navUp === "function") {
                return "res=" + root.clipMod.navUp();
            }
            if (root.launcherMod && root.launcherMod.searchWidget && root.launcherMod.searchWidget.searchKeyRouter) {
                return "res=" + root.launcherMod.searchWidget.searchKeyRouter.dispatch("navigateUp");
            }
            return "no router";
        }
        function switchMode(mode: string): string {
            root.switchMode(mode, true);
            return "OK";
        }
        function collapse(): string {
            root.collapseToIdle();
            return "OK";
        }
        function collapseToIdle(): string {
            root.collapseToIdle();
            return "OK";
        }
        function triggerOsd(type: string, value: string): string {
            var v = parseInt(value);
            if (!isNaN(v)) {
                root.triggerOsd(type, v);
            }
            return "OK";
        }
        function openUtility(subpage: string): string {
            root.openUtility(subpage || "", true);
            return "OK";
        }
        function search(query: string): string {
            root.openedViaShortcut = true;
            var q = query || "";
            if (typeof GlobalStates !== "undefined") {
                GlobalStates.overviewOpen = true;
            }
            if (root.activeMode === "launcher" && root.launcherMod) {
                root.launcherMod.processSearch(q);
                root.launcherMod.searchInput.forceActiveFocus();
            } else {
                root.pendingSearchQuery = q;
                root.switchMode("launcher", true);
                if (root.pendingSearchQuery !== "" && root.launcherMod) {
                    root.launcherMod.processSearch(root.pendingSearchQuery);
                    root.pendingSearchQuery = "";
                }
            }
            return "OK";
        }
        function reloadTheme(): string {
            Theme.reload();
            return "OK";
        }
        function toggleMusic(): string {
            if (root.activeMode === "music") {
                root.collapseToIdle();
            } else {
                root.switchMode("music", true);
            }
            return "OK";
        }
        function toggleTaskExpand(pidStr: string): string {
            if (root.activeMode !== "taskmanager") root.switchMode("taskmanager", true);
            var pid = parseInt(pidStr);
            if (!isNaN(pid) && root.taskMgrMod) {
                root.taskMgrMod.toggleExpand(pid);
                return "OK";
            }
            return "ERROR";
        }
        function toggleBtExpand(address: string): string {
            if (root.activeMode !== "bluetooth") root.switchMode("bluetooth", true);
            if (root.btMod) {
                root.btMod.expandedKey = (root.btMod.expandedKey === address) ? "" : address;
                return "OK";
            }
            return "ERROR";
        }
        function searchTask(query: string): string {
            if (root.activeMode !== "taskmanager") root.switchMode("taskmanager", true);
            if (root.taskMgrMod && root.taskMgrMod.searchInput) {
                root.taskMgrMod.searchInput.text = query || "";
                return "OK";
            }
            return "ERROR";
        }
        function setTaskTab(tabStr: string): string {
            if (root.activeMode !== "taskmanager") root.switchMode("taskmanager", true);
            var t = parseInt(tabStr);
            if (!isNaN(t) && root.taskMgrMod) {
                root.taskMgrMod.activeTab = t;
                root.taskMgrMod.applyFilterAndSort(true);
                return "OK";
            }
            return "ERROR";
        }
        function setTaskSort(field: string): string {
            if (root.activeMode !== "taskmanager") root.switchMode("taskmanager", true);
            if (root.taskMgrMod) {
                if (root.taskMgrMod.sortField === field) {
                    root.taskMgrMod.sortAsc = !root.taskMgrMod.sortAsc;
                } else {
                    root.taskMgrMod.sortField = field;
                    root.taskMgrMod.sortAsc = (field === "name");
                }
                root.taskMgrMod.applyFilterAndSort(true);
                return "OK";
            }
            return "ERROR";
        }
        function getTargetHeight(): string {
            return "" + root.targetHeight + " mode: " + root.activeMode;
        }
        function toggleMusicPanel(panelName: string): string {
            if (root.activeMode !== "music") root.switchMode("music", true);
            if (root.musicMod) {
                root.musicMod.togglePanel(panelName);
            } else {
                root.requestedMusicPanel = panelName;
            }
            return "OK";
        }
        function toggleRecorder(): string {
            root.switchMode("recorder", true);
            return "OK";
        }
        function setScreenRecording(active: bool): string {
            if (active) {
                root.startRecording(false);
            } else {
                root.stopRecording();
            }
            return "OK";
        }
        function showScreenshot(filePath: string): string {
            root.triggerScreenshotHub(filePath);
            return "OK";
        }
        function toggleDnd(): string {
            root.dndEnabled = !root.dndEnabled;
            return root.dndEnabled ? "DND Enabled" : "DND Disabled";
        }
        function startPomo(minutes: int, mode: string): string {
            const phase = mode === "short_break" ? "short" : mode === "long_break" ? "long" : "focus";
            if (phase === "focus") Chrono.pomoRound = 0;
            Chrono.pomoBegin(phase, minutes > 0 ? minutes : Chrono.phaseMinutes(phase));
            return "OK";
        }
        function stopPomo(): string {
            Chrono.pomoStop();
            return "OK";
        }
        function pausePomo(): string {
            if (Chrono.pomoRunning) Chrono.pomoToggle();
            return "OK";
        }
        function resumePomo(): string {
            if (Chrono.pomoActive && !Chrono.pomoRunning) Chrono.pomoToggle();
            return "OK";
        }
        function togglePomo(): string {
            Chrono.pomoToggle();
            return "OK";
        }
    }

    // Native Hyprland focus grabber (disabled to prevent background window focus changes from collapsing popups)
    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [panel]
        onCleared: {
            root.collapseToIdle();
        }
    }

    // Permanent top reservation for Hyprland window tiling (32px)
    PanelWindow {
        id: reservationPanel
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: NotchConfig.baseExclusiveZone
        exclusiveZone: NotchConfig.baseExclusiveZone
        color: "transparent"
        WlrLayershell.namespace: "notch-reserve"
        mask: Region {}
    }

    // Modern hardware display rounded corners (Liquid Retina aesthetic, 100% click-through)
    // Variants {
    //     model: Quickshell.screens
    //
    //     ScreenCorners {
    //         required property var modelData
    //         screen: modelData
    //         cornerRadius: 16
    //         cornerColor: "#000000"
    //     }
    // }

    // Main Notch Panel
    PanelWindow {
        id: panel
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell"

        Item {
            id: fullMaskArea
            anchors.fill: parent
        }

        Item {
            id: hoverMaskArea
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: notch.width + (root.cornerCurveRadius * 2) + 60
            height: notch.height + 40
        }

        // Invisible top sensor strip for fullscreen autohide hover reveal
        Item {
            id: topHoverSensorArea
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(notch.width + (root.cornerCurveRadius * 2) + 160, 520)
            height: 4
        }

        mask: Region {
            item: {
                if (root.settingsOpen) {
                    return fullMaskArea;
                }
                if (root.notesPinned) return notchContainer;
                if (root.wallSortMod && root.wallSortMod.browsingFolder) return notchContainer;
                if (root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "osd") {
                    return fullMaskArea;
                }
                if (root.notchHidden) {
                    return topHoverSensorArea;
                }
                if (root.activeMode === "hover") {
                    return hoverMaskArea;
                }
                return notchContainer;
            }

            Region {
                item: (root.isScreenRecording && recordingBubble.visible) ? recordingBubble : null
            }

            Region {
                item: mediaBubble.mediaActive ? mediaBubble : null
            }
        }

        WlrLayershell.keyboardFocus: root.notesPinned && !root.settingsOpen ? WlrKeyboardFocus.OnDemand
            : (root.wallSortMod && root.wallSortMod.browsingFolder) ? WlrKeyboardFocus.None
            : (root.settingsOpen || (root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "compact" && root.activeMode !== "workspace_peek" && root.activeMode !== "dashboard_peek" && root.activeMode !== "osd"))
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        // Top hover sensor mouse trigger for fullscreen mode
        MouseArea {
            id: topHoverSensorMouse
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(notch.width + (root.cornerCurveRadius * 2) + 160, 520)
            height: 4
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.ArrowCursor
            z: 2
            enabled: root.isWindowFullscreen

            onEntered: {
                fullscreenHideTimer.stop();
                if (root.isWindowFullscreen) {
                    root.fullscreenHoverRevealed = true;
                }
            }
            onExited: {
                if (root.isWindowFullscreen && (root.activeMode === "idle" || root.activeMode === "hover")) {
                    fullscreenHideTimer.restart();
                }
            }
        }

        Timer {
            id: fullscreenHideTimer
            interval: NotchConfig.timerFullscreenHideGrace
            repeat: false
            onTriggered: {
                if (!topHoverSensorMouse.containsMouse && 
                    !notchHoverArea.containsMouse && 
                    !notchHoverHandler.hovered &&
                    !root.openedViaShortcut &&
                    (root.activeMode === "idle" || root.activeMode === "hover")) {
                    root.fullscreenHoverRevealed = false;
                    if (root.activeMode === "hover") {
                        root.collapseToIdle();
                    }
                }
            }
        }

        // Click-away backdrop: collapses open popups/hover when clicking outside
        MouseArea {
            id: outsideClickCatcher
            anchors.fill: parent
            z: 0
            enabled: root.activeMode !== "idle" && root.activeMode !== "osd"
                && !(root.activeMode === "wallsort" && root.wallSortMod?.sorting)
                && !(root.wallSortMod && root.wallSortMod.browsingFolder)
                && !root.notesPinned
            onClicked: {
                root.collapseToIdle();
                if (root.isWindowFullscreen) {
                    root.fullscreenHoverRevealed = false;
                }
            }
        }

        Item {
            id: notchContainer
            z: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: notch.width + (root.cornerCurveRadius * 2)
            height: notch.height

            y: root.notchHidden ? (-notchContainer.height - root.cornerCurveRadius - 8) : 0
            opacity: root.notchHidden ? 0.0 : 1.0
            visible: opacity > 0.001

            Behavior on y {
                NumberAnimation {
                    duration: root.notchHidden ? NotchConfig.animNotchExit : NotchConfig.animNotchEnter
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.notchHidden ? NotchConfig.curveAccel : NotchConfig.curveMorph
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.notchHidden ? NotchConfig.animContentExit : NotchConfig.animDashEnter
                    easing.type: Easing.OutCubic
                }
            }

            focus: root.activeMode !== "idle" && root.activeMode !== "hover"
            Keys.forwardTo: (moduleLoader && moduleLoader.item) ? [moduleLoader.item] : []
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.collapseToIdle();
                    if (root.isWindowFullscreen) {
                        root.fullscreenHoverRevealed = false;
                    }
                    event.accepted = true;
                }
            }
            Keys.onReleased: (event) => {
                if (root.activeMode === "switcher" && (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta)) {
                    if (root.switcherMod) root.switcherMod.activateSelected();
                    event.accepted = true;
                }
            }

            // Notch Shadow System (Tight bounds prevent allocating 1920x1200 full-screen FBO textures)
            Item {
                id: shadowSilhouette
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: notch.width + (root.cornerCurveRadius * 2) + 16
                height: notch.height + 16
                visible: false

                Canvas {
                    id: sLeftWing
                    width: root.cornerCurveRadius; height: root.cornerCurveRadius
                    anchors.top: parent.top; anchors.right: sNotch.left; anchors.rightMargin: -1
                    renderTarget: Canvas.Image
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = "" + root.notchSurfaceColor;
                        ctx.beginPath();
                        ctx.moveTo(width + 1, 0); ctx.lineTo(width + 1, height);
                        ctx.arcTo(width, 0, 0, 0, height);
                        ctx.closePath(); ctx.fill();
                    }
                    Connections { target: root; function onCornerCurveRadiusChanged() { sLeftWing.requestPaint(); } }
                    onAvailableChanged: if (available) requestPaint()
                    Component.onCompleted: requestPaint()
                }

                Rectangle {
                    id: sNotch
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: notch.width
                    height: notch.height
                    color: "#000000"
                    bottomLeftRadius: notch.bottomLeftRadius
                    bottomRightRadius: notch.bottomRightRadius
                }

                Canvas {
                    id: sRightWing
                    width: root.cornerCurveRadius; height: root.cornerCurveRadius
                    anchors.top: parent.top; anchors.left: sNotch.right; anchors.leftMargin: -1
                    renderTarget: Canvas.Image
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = "" + root.notchSurfaceColor;
                        ctx.beginPath();
                        ctx.moveTo(-1, 0); ctx.lineTo(-1, height);
                        ctx.arcTo(0, 0, width, 0, height);
                        ctx.closePath(); ctx.fill();
                    }
                    Connections { target: root; function onCornerCurveRadiusChanged() { sRightWing.requestPaint(); } }
                    onAvailableChanged: if (available) requestPaint()
                    Component.onCompleted: requestPaint()
                }
            }

            MultiEffect {
                id: notchShadow
                source: shadowSilhouette
                anchors.fill: shadowSilhouette
                z: -2
                shadowEnabled: NotchConfig.shadowEnabled
                shadowColor: NotchConfig.shadowColor
                shadowOpacity: NotchConfig.shadowOpacity
                shadowBlur: NotchConfig.shadowBlur
                shadowVerticalOffset: NotchConfig.shadowVerticalOffset
                shadowHorizontalOffset: NotchConfig.shadowHorizontalOffset
            }

            MouseArea {
                id: notchHoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                z: -1
                onEntered: {
                    fullscreenHideTimer.stop();
                    autoCollapseTimer.stop();
                    if (root.isWindowFullscreen) root.fullscreenHoverRevealed = true;
                    if (root.activeMode === "idle") root.activeMode = "hover";
                }
                onExited: {
                    if (root.isWindowFullscreen) {
                        fullscreenHideTimer.restart();
                    }
                    if (root.activeMode === "hover" && !root.openedViaShortcut && !notchHoverHandler.hovered) {
                        root.collapseToIdle();
                    }
                }
            }

            // Left Wing
            Canvas {
                id: leftWing
                width: root.cornerCurveRadius; height: root.cornerCurveRadius
                anchors.top: parent.top; anchors.right: notch.left; anchors.rightMargin: -1 
                renderTarget: Canvas.Image

                Connections { target: Theme; function onThemeReloaded() { leftWing.requestPaint(); } }
                Connections { target: Theme; function onColorsChanged() { leftWing.requestPaint(); } }
                Connections { target: root; function onNotchSurfaceColorChanged() { leftWing.requestPaint(); } }
                Connections { target: root; function onActiveModeChanged() { leftWing.requestPaint(); } }
                onAvailableChanged: if (available) requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "" + root.notchSurfaceColor;
                    ctx.beginPath();
                    ctx.moveTo(width + 1, 0); ctx.lineTo(width + 1, height);
                    ctx.arcTo(width, 0, 0, 0, height);
                    ctx.closePath(); ctx.fill();
                }
            }

            // Right Wing
            Canvas {
                id: rightWing
                width: root.cornerCurveRadius; height: root.cornerCurveRadius
                anchors.top: parent.top; anchors.left: notch.right; anchors.leftMargin: -1 
                renderTarget: Canvas.Image

                Connections { target: Theme; function onThemeReloaded() { rightWing.requestPaint(); } }
                Connections { target: Theme; function onColorsChanged() { rightWing.requestPaint(); } }
                Connections { target: root; function onNotchSurfaceColorChanged() { rightWing.requestPaint(); } }
                Connections { target: root; function onActiveModeChanged() { rightWing.requestPaint(); } }
                onAvailableChanged: if (available) requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: rightWing.requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "" + root.notchSurfaceColor;
                    ctx.beginPath();
                    ctx.moveTo(-1, 0); ctx.lineTo(-1, height);
                    ctx.arcTo(0, 0, width, 0, height);
                    ctx.closePath(); ctx.fill();
                }
            }

            // Notch Surface
            Rectangle {
                id: notch
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.targetWidth
                height: root.targetHeight
                color: root.notchSurfaceColor
                border.width: 0
                border.color: "transparent"
                antialiasing: true
                clip: true

                // Consumes clicks on empty space inside notch so they do not fall through to click-away catcher
                MouseArea {
                    anchors.fill: parent
                    z: -1
                }
                
                radius: 0
                bottomLeftRadius: root.targetRadius
                bottomRightRadius: bottomLeftRadius

                readonly property int morphDuration: root.isOsdMode ? NotchConfig.animOsdMorph
                    : root.isExpanding ? NotchConfig.popupOpenDuration(root.targetWidth, root.targetHeight)
                    : NotchConfig.animNotchExit
                readonly property var morphCurve: root.isExpanding ? NotchConfig.curveMorph : NotchConfig.curveAccel

                Behavior on width {
                    NumberAnimation {
                        duration: notch.morphDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: notch.morphCurve
                    }
                }
                Behavior on height {
                    // The disclosure already animates the measured height for these panels.
                    enabled: !(root.activeMode === "wifi" && root.wifiMod?.resizingRows)
                        && !(root.activeMode === "bluetooth" && root.btMod?.resizingRows)
                    NumberAnimation {
                        duration: notch.morphDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: notch.morphCurve
                    }
                }
                Behavior on bottomLeftRadius {
                    NumberAnimation {
                        duration: notch.morphDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: notch.morphCurve
                    }
                }

                // Keep the clock and dash controls at bar height while the panel expands.
                Item {
                    id: dashContainer
                    property int dashHeight: NotchConfig.modeDimensions["idle"].height

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.min(notch.height, dashHeight)
                    z: 5

                    Binding {
                        target: dashContainer
                        property: "dashHeight"
                        value: root.targetHeight
                        when: root.isDashMode
                        restoreMode: Binding.RestoreNone
                    }

                    opacity: root.isDashMode ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.isDashMode ? NotchConfig.animDashEnter : NotchConfig.animDashExit
                            easing.type: Easing.OutQuad
                        }
                    }

                    Loader {
                        id: dashLoader
                        anchors.fill: parent
                        asynchronous: false
                        source: Qt.resolvedUrl("modules/MainDash.qml")
                        onLoaded: {
                            if (item) {
                                item.settingsOpen = Qt.binding(() => root.settingsOpen);
                                item.settingsRequested.connect(() => {
                                    root.collapseToIdle();
                                    root.settingsOpen = !root.settingsOpen;
                                });
                            }
                        }
                    }
                }

                // Lay out the panel at its destination size and let the surface reveal it.
                Item {
                    id: modulesContainer
                    property size layoutSize: Qt.size(0, 0)
                    readonly property bool fullBleed: ["music", "launcher", "wallpaper", "utility", "powermenu", "calendar", "clipboard"].includes(root.loadedExpandedMode)
                    readonly property int inset: fullBleed ? 0 : 12
                    readonly property real revealProgress: NotchConfig.popupReveal(root.loadedExpandedMode,
                        layoutSize.width, layoutSize.height, inset, notch.width, notch.height)
                    property real contentBlend: root.isExpanding ? 1 : 0
                    property real pageBlend: 1

                    anchors.top: parent.top
                    anchors.topMargin: inset
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(0, layoutSize.width - 2 * inset)
                    height: Math.max(0, layoutSize.height - 2 * inset)
                    z: 2

                    Binding {
                        target: modulesContainer
                        property: "layoutSize"
                        value: Qt.size(root.targetWidth, root.targetHeight)
                        when: root.isExpanding
                        restoreMode: Binding.RestoreNone
                    }

                    opacity: contentBlend * revealProgress * pageBlend
                    visible: opacity > 0.001
                    enabled: root.isExpanding

                    Behavior on contentBlend {
                        NumberAnimation {
                            duration: root.isExpanding ? NotchConfig.animContentEnter : NotchConfig.animContentExit
                            easing.type: Easing.OutCubic
                        }
                    }

                    NumberAnimation {
                        id: pageReveal
                        target: modulesContainer
                        property: "pageBlend"
                        from: 0
                        to: 1
                        duration: NotchConfig.animContentEnter
                        easing.type: Easing.OutCubic
                    }

                    Loader {
                        id: moduleLoader
                        anchors.fill: parent
                        asynchronous: false
                        source: root.getModuleSource(root.loadedExpandedMode)
                        onLoaded: {
                            if (!item) return;
                            if (modulesContainer.contentBlend >= 0.95) {
                                modulesContainer.pageBlend = 0;
                                pageReveal.restart();
                            }
                            if (root.loadedExpandedMode === "launcher") {
                                if (!root.desktopEntriesIndexed) root.syncDesktopEntries();
                                if (typeof item.onOpened === "function") item.onOpened();
                                if (root.pendingSearchQuery !== "") {
                                    item.processSearch(root.pendingSearchQuery);
                                    root.pendingSearchQuery = "";
                                }
                            } else if (root.loadedExpandedMode === "theme") {
                                item.notch = root;
                            } else if (root.loadedExpandedMode === "wifi") {
                                if (typeof item.refreshStatus === "function") item.refreshStatus();
                            } else if (root.loadedExpandedMode === "utility") {
                                if (root.requestedUtilitySection !== "") item.activeSection = root.requestedUtilitySection;
                            } else if (root.loadedExpandedMode === "music") {
                                if (root.requestedMusicPanel !== "" && typeof item.togglePanel === "function") {
                                    item.togglePanel(root.requestedMusicPanel);
                                    root.requestedMusicPanel = "";
                                }
                            } else if (root.loadedExpandedMode === "switcher") {
                                if (typeof item.refreshClients === "function") item.refreshClients();
                            } else if (root.loadedExpandedMode === "calendar") {
                                if (root.requestedClockTab !== "" && typeof item.showTab === "function") {
                                    item.showTab(root.requestedClockTab);
                                    root.requestedClockTab = "";
                                }
                            }
                            root.regainFocus();
                        }
                    }
                }

                // 3. Dedicated OSD HUD Layer
                Item {
                    id: osdContainer
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    z: 10

                    opacity: root.activeMode === "osd" ? 1.0 : 0.0
                    visible: opacity > 0.001
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                    Loader {
                        id: osdLoader
                        anchors.fill: parent
                        active: root.activeMode === "osd"
                        source: (root.activeMode === "osd") ? Qt.resolvedUrl("modules/Osd.qml") : ""
                    }
                }

                Timer {
                    id: autoCollapseTimer
                    interval: NotchConfig.timerAutoCollapse
                    repeat: false
                    onTriggered: {
                        if (root.activeMode === "hover" && !root.openedViaShortcut && !notchHoverHandler.hovered && !notchHoverArea.containsMouse) {
                            root.collapseToIdle();
                        }
                    }
                }

                HoverHandler {
                    id: notchHoverHandler
                    enabled: root.activeMode !== "osd"
                    cursorShape: Qt.ArrowCursor
                    onHoveredChanged: {
                        if (root.utilMod && (root.utilMod.isDraggingVolume || root.utilMod.isDraggingBrightness)) return;
                        if (root.musicMod && root.musicMod.isDraggingSeek) return;
                        if (hovered) {
                            fullscreenHideTimer.stop();
                            autoCollapseTimer.stop();
                            root.isWorkspacePeeking = false;
                            if (root.isWindowFullscreen) root.fullscreenHoverRevealed = true;
                            if (root.activeMode === "idle") root.activeMode = "hover";
                        } else {
                            if (root.isWindowFullscreen) {
                                fullscreenHideTimer.restart();
                            }
                            if (root.activeMode === "hover" && !root.openedViaShortcut && !notchHoverArea.containsMouse) {
                                root.collapseToIdle();
                            }
                        }
                    }
                }
            }
        }

        // Inir-style Floating Activity Island Bubbles (Detached stadium pills floating next to the notch bar)
        Row {
            id: floatingRightBubbles
            z: 2
            anchors.left: notchContainer.right
            anchors.leftMargin: 8
            anchors.top: parent.top
            anchors.topMargin: root.notchHidden ? -50 : 4
            spacing: 6

            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: root.notchHidden ? NotchConfig.animNotchExit : NotchConfig.animNotchEnter
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.notchHidden ? NotchConfig.curveAccel : NotchConfig.curveMorph
                }
            }

            // 1. Screen Recording Floating Bubble
            Item {
                id: recordingBubble
                readonly property int bubbleHeight: 30
                readonly property int bubbleRadius: 15

                visible: opacity > 0.001
                opacity: root.isScreenRecording ? 1.0 : 0.0
                scale: root.isScreenRecording ? 1.0 : 0.75
                transformOrigin: Item.Center

                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

                width: root.isScreenRecording ? (recContentRow.implicitWidth + 24) : 0
                height: bubbleHeight
                clip: true

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: recSilhouette
                    anchors.fill: parent
                    radius: recordingBubble.bubbleRadius
                    color: root.notchSurfaceColor
                    visible: false
                }

                MultiEffect {
                    anchors.fill: recSilhouette
                    source: recSilhouette
                    z: -1
                    shadowEnabled: NotchConfig.shadowEnabled
                    shadowColor: NotchConfig.shadowColor
                    shadowOpacity: 0.4
                    shadowBlur: 10
                    shadowVerticalOffset: 2
                }

                Rectangle {
                    id: recBg
                    anchors.fill: parent
                    radius: recordingBubble.bubbleRadius
                    color: root.notchSurfaceColor
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.12)

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: recMouse.containsMouse
                            ? (recMouse.pressed ? Qt.rgba(255, 84, 73, 0.22) : Qt.rgba(255, 84, 73, 0.14))
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                Row {
                    id: recContentRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: root.isScreenRecordingPaused
                            ? (Theme.colors.warning || "#fbbf24")
                            : (Theme.colors.error || "#ff5449")
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            running: root.isScreenRecording && !root.isScreenRecordingPaused
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatRecTime(root.screenRecordSeconds)
                        color: root.isScreenRecordingPaused
                            ? (Theme.colors.warning || "#fbbf24")
                            : (Theme.colors.error || "#ff5449")
                        font.family: "Readex Pro"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: recMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        root.switchMode("recorder", true);
                    }
                }
            }

            // 2. Stopwatch Floating Bubble
            Item {
                id: stopwatchBubble
                readonly property int bubbleHeight: 30
                readonly property int bubbleRadius: 15
                readonly property bool swRunning: (typeof Chrono !== "undefined" && Chrono.swRunning)
                    || (typeof TimerService !== "undefined" && TimerService.stopwatchRunning)
                readonly property bool swActive: (typeof Chrono !== "undefined" && Chrono.swActive)
                    || (typeof TimerService !== "undefined" && (TimerService.stopwatchRunning || TimerService.stopwatchTime > 0))

                visible: opacity > 0.001
                opacity: swActive ? 1.0 : 0.0
                scale: swActive ? 1.0 : 0.75
                transformOrigin: Item.Center

                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

                width: swActive ? (swContentRow.implicitWidth + 24) : 0
                height: bubbleHeight
                clip: true

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: swSilhouette
                    anchors.fill: parent
                    radius: stopwatchBubble.bubbleRadius
                    color: root.notchSurfaceColor
                    visible: false
                }

                MultiEffect {
                    anchors.fill: swSilhouette
                    source: swSilhouette
                    z: -1
                    shadowEnabled: NotchConfig.shadowEnabled
                    shadowColor: NotchConfig.shadowColor
                    shadowOpacity: 0.4
                    shadowBlur: 10
                    shadowVerticalOffset: 2
                }

                Rectangle {
                    id: swBg
                    anchors.fill: parent
                    radius: stopwatchBubble.bubbleRadius
                    color: root.notchSurfaceColor
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.12)

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: swMouse.containsMouse
                            ? (swMouse.pressed ? Qt.rgba(37, 180, 229, 0.22) : Qt.rgba(37, 180, 229, 0.14))
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                Row {
                    id: swContentRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "timer"
                        iconSize: 15
                        color: stopwatchBubble.swRunning
                            ? (Theme.colors.primary || "#25b4e5")
                            : (Theme.colors.subtext || "#888888")
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (typeof Chrono !== "undefined" && Chrono.swActive) {
                                return Chrono.clock(Chrono.swElapsed, false);
                            }
                            if (typeof TimerService !== "undefined" && (TimerService.stopwatchRunning || TimerService.stopwatchTime > 0)) {
                                const totalSec = Math.floor(TimerService.stopwatchTime / 100);
                                const m = Math.floor(totalSec / 60);
                                const s = totalSec % 60;
                                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                            }
                            return "00:00";
                        }
                        color: stopwatchBubble.swRunning
                            ? (Theme.colors.text || "#ffffff")
                            : (Theme.colors.subtext || "#888888")
                        font.family: "Readex Pro"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: swMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        root.openClockTab("stopwatch");
                    }
                }
            }

            // 3. Countdown Timer Floating Bubble
            Item {
                id: timerBubble
                readonly property int bubbleHeight: 30
                readonly property int bubbleRadius: 15
                readonly property var chronoHeadline: (typeof Chrono !== "undefined" && Chrono.headline) ? Chrono.headline : null
                readonly property bool chronoTimerActive: chronoHeadline !== null && (chronoHeadline.kind === "timer" || chronoHeadline.kind === "pomodoro")
                readonly property var tsCountdown: (typeof TimerService !== "undefined" && TimerService.countdowns)
                    ? (TimerService.countdowns.find(c => !c.notified) ?? null)
                    : null
                readonly property bool timerActive: chronoTimerActive
                    || (tsCountdown !== null)
                    || (typeof TimerService !== "undefined" && TimerService.pomodoroRunning)

                readonly property bool isFinished: (chronoHeadline && chronoHeadline.left <= 0 && chronoHeadline.total > 0)
                    || (tsCountdown && tsCountdown.notified)

                visible: opacity > 0.001
                opacity: timerActive ? 1.0 : 0.0
                scale: timerActive ? 1.0 : 0.75
                transformOrigin: Item.Center

                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

                width: timerActive ? (timerContentRow.implicitWidth + 24) : 0
                height: bubbleHeight
                clip: true

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: timerSilhouette
                    anchors.fill: parent
                    radius: timerBubble.bubbleRadius
                    color: root.notchSurfaceColor
                    visible: false
                }

                MultiEffect {
                    anchors.fill: timerSilhouette
                    source: timerSilhouette
                    z: -1
                    shadowEnabled: NotchConfig.shadowEnabled
                    shadowColor: NotchConfig.shadowColor
                    shadowOpacity: 0.4
                    shadowBlur: 10
                    shadowVerticalOffset: 2
                }

                Rectangle {
                    id: timerBg
                    anchors.fill: parent
                    radius: timerBubble.bubbleRadius
                    color: root.notchSurfaceColor
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.12)

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: timerMouse.containsMouse
                            ? (timerMouse.pressed ? Qt.rgba(251, 191, 36, 0.22) : Qt.rgba(251, 191, 36, 0.14))
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                Row {
                    id: timerContentRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: timerBubble.isFinished ? "alarm_on" : (timerBubble.chronoHeadline?.kind === "pomodoro" ? "timelapse" : "hourglass_top")
                        iconSize: 15
                        color: timerBubble.isFinished
                            ? (Theme.colors.warning || "#fbbf24")
                            : (Theme.colors.primary || "#25b4e5")

                        SequentialAnimation on opacity {
                            running: timerBubble.isFinished
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 400; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (timerBubble.chronoTimerActive) {
                                return Chrono.countdown(timerBubble.chronoHeadline.left);
                            }
                            if (timerBubble.tsCountdown) {
                                return TimerService.formatCountdownDuration(TimerService.countdownSecondsLeft(timerBubble.tsCountdown));
                            }
                            if (typeof TimerService !== "undefined" && TimerService.pomodoroRunning) {
                                return TimerService.formatCountdownDuration(TimerService.pomodoroSecondsLeft);
                            }
                            return "00:00";
                        }
                        color: timerBubble.isFinished
                            ? (Theme.colors.warning || "#fbbf24")
                            : (Theme.colors.text || "#ffffff")
                        font.family: "Readex Pro"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: timerMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        root.openClockTab("timer");
                    }
                }
            }
        }

        // Inir-style Media Disc Bubble (circular album art + playback progress ring, left of the bar)
        Item {
            id: mediaBubble
            readonly property bool mediaActive: typeof MprisController !== "undefined" && !!MprisController.activePlayer
            readonly property string artSource: {
                if (!mediaActive) return "";
                const ctrlUrl = MprisController.artUrl ? String(MprisController.artUrl) : "";
                if (ctrlUrl !== "") return ctrlUrl;
                const playerUrl = MprisController.activePlayer && MprisController.activePlayer.trackArtUrl
                    ? String(MprisController.activePlayer.trackArtUrl)
                    : "";
                return playerUrl;
            }
            readonly property bool remoteArt: /^https?:/.test(artSource)
            readonly property string remoteArtCachePath: {
                if (!remoteArt) return "";
                var h = 5381;
                for (var i = 0; i < artSource.length; i++) h = ((h * 33) ^ artSource.charCodeAt(i)) >>> 0;
                return (Quickshell.env("HOME") || "") + "/.cache/quickshell/art/" + h.toString(16) + ".img";
            }
            property string localFetchedArt: ""
            readonly property string quantizerSource: {
                if (!mediaActive || artSource === "") return "";
                if (remoteArt) return localFetchedArt;
                if (artSource.startsWith("file://")) return artSource;
                if (artSource.startsWith("/")) return "file://" + artSource;
                return "";
            }
            property color extractedArtColor: (typeof Theme !== "undefined") ? Theme.accent : "#25b4e5"
            readonly property color ringColor: mediaActive && quantizerSource !== "" ? extractedArtColor : ((typeof Theme !== "undefined") ? Theme.accent : "#25b4e5")
            property real trackProgress: 0

            function refreshBubbleArtCache() {
                if (remoteArtCachePath === "") {
                    localFetchedArt = "";
                    return;
                }
                bubbleArtFetch.superseded = bubbleArtFetch.running;
                bubbleArtFetch.file = remoteArtCachePath;
                bubbleArtFetch.running = false;
                bubbleArtFetch.command = ["sh", "-c", bubbleArtFetch.script, "sh", remoteArtCachePath, artSource];
                bubbleArtFetch.running = true;
            }

            onRemoteArtCachePathChanged: refreshBubbleArtCache()
            onArtSourceChanged: {
                if (!remoteArt) localFetchedArt = "";
                if (artSource === "") extractedArtColor = (typeof Theme !== "undefined") ? Theme.accent : "#25b4e5";
            }
            Component.onCompleted: refreshBubbleArtCache()

            Process {
                id: bubbleArtFetch
                property string file: ""
                property bool superseded: false
                readonly property string script: "f=\"$1\"; d=\"$(dirname \"$f\")\"; mkdir -p \"$d\"; [ -s \"$f\" ] || { t=\"$f.$$\"; curl -sfL --max-time 8 -o \"$t\" \"$2\" && mv \"$t\" \"$f\" || rm -f \"$t\"; }; [ -s \"$f\" ]"
                onExited: (code) => {
                    if (bubbleArtFetch.superseded) {
                        bubbleArtFetch.superseded = false;
                        return;
                    }
                    mediaBubble.localFetchedArt = (code === 0) ? ("file://" + bubbleArtFetch.file) : "";
                }
            }

            ColorQuantizer {
                id: bubbleQuantizer
                source: mediaBubble.quantizerSource
                depth: 3
                rescaleSize: 48
                onColorsChanged: {
                    if (!colors || colors.length === 0) return;
                    let best = null;
                    let bestScore = -1;
                    for (let i = 0; i < colors.length; i++) {
                        const c = colors[i];
                        const score = Math.max(0, c.hslSaturation) * (1 - Math.abs(c.hslLightness - 0.5));
                        if (score > bestScore) { bestScore = score; best = c; }
                    }
                    if (best && best.hslSaturation >= 0.14 && best.hslHue >= 0) {
                        const extracted = Qt.hsla(best.hslHue, Math.max(0.55, best.hslSaturation),
                            Math.max(0.60, Math.min(0.76, best.hslLightness + 0.18)), 1);
                        mediaBubble.extractedArtColor = extracted;
                        if (typeof Theme !== "undefined") Theme.setMediaAccent(extracted.toString());
                    } else if (colors[0]) {
                        const mono = colors[0];
                        mediaBubble.extractedArtColor = Qt.hsla(0, 0, Math.max(0.68, Math.min(0.86, mono.hslLightness + 0.25)), 1);
                    }
                }
            }

            Timer {
                interval: 1000
                running: mediaBubble.mediaActive && mediaBubble.visible
                repeat: true
                triggeredOnStart: true
                onTriggered: mediaBubble.trackProgress = (MprisController.trackProgressOf(MprisController.activePlayer) ?? 0)
            }

            z: 2
            anchors.right: notchContainer.left
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: root.notchHidden ? -50 : 4
            width: 32
            height: 32

            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: root.notchHidden ? NotchConfig.animNotchExit : NotchConfig.animNotchEnter
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.notchHidden ? NotchConfig.curveAccel : NotchConfig.curveMorph
                }
            }

            visible: opacity > 0.001
            opacity: (mediaActive && root.isDashMode && !root.notchHidden) ? 1.0 : 0.0
            scale: mediaActive ? 1.0 : 0.75
            transformOrigin: Item.Center

            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            Behavior on trackProgress { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Rectangle {
                id: mediaSilhouette
                anchors.fill: parent
                radius: 16
                color: root.notchSurfaceColor
                visible: false
            }

            MultiEffect {
                anchors.fill: mediaSilhouette
                source: mediaSilhouette
                z: -1
                shadowEnabled: NotchConfig.shadowEnabled
                shadowColor: NotchConfig.shadowColor
                shadowOpacity: 0.4
                shadowBlur: 10
                shadowVerticalOffset: 2
            }

            Rectangle {
                id: mediaDisc
                anchors.centerIn: parent
                width: 27
                height: 27
                radius: 13.5
                color: root.notchSurfaceColor
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.12)

                scale: mediaHover.containsMouse ? (mediaHover.pressed ? 0.92 : 1.06) : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Image {
                    id: discArt
                    anchors.fill: parent
                    anchors.margins: 1
                    source: mediaBubble.artSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(96, 96)
                    visible: false
                }

                Rectangle {
                    id: discMask
                    anchors.fill: discArt
                    radius: width / 2
                    visible: false
                    layer.enabled: discArt.status === Image.Ready
                    layer.smooth: true
                    layer.textureSize: Qt.size(96, 96)
                }

                OpacityMask {
                    anchors.fill: discArt
                    source: discArt
                    maskSource: discMask
                    visible: discArt.status === Image.Ready
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: discArt.status !== Image.Ready
                    text: "music_note"
                    iconSize: 14
                    color: (typeof Theme !== "undefined" && Theme.colors && Theme.colors.text_primary) ? Theme.colors.text_primary : "#ffffff"
                }

                Shape {
                    z: 2
                    x: -2.5
                    y: -2.5
                    width: 32
                    height: 32
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Qt.rgba(255, 255, 255, 0.22)
                        strokeWidth: 2
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"

                        PathAngleArc {
                            centerX: 16
                            centerY: 16
                            radiusX: 14.5
                            radiusY: 14.5
                            startAngle: 0
                            sweepAngle: 360
                        }
                    }
                }

                Shape {
                    z: 2
                    visible: mediaBubble.trackProgress > 0.001
                    x: -2.5
                    y: -2.5
                    width: 32
                    height: 32
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: mediaBubble.ringColor
                        strokeWidth: 2
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"

                        Behavior on strokeColor {
                            ColorAnimation { duration: 280 }
                        }

                        PathAngleArc {
                            centerX: 16
                            centerY: 16
                            radiusX: 14.5
                            radiusY: 14.5
                            startAngle: -90
                            sweepAngle: Math.min(1, Math.max(0, mediaBubble.trackProgress)) * 360
                        }
                    }
                }
            }

            MouseArea {
                id: mediaHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.switchMode("music", true)
            }
        }

        // Expressive Settings Modal Window (The Goat Architecture)
        Rectangle {
            id: settingsBackdrop
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.65)
            opacity: root.settingsOpen ? 1.0 : 0.0
            visible: opacity > 0.001
            z: 99

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.settingsOpen = false
            }

            Loader {
                id: settingsModalLoader
                active: root.settingsOpen
                asynchronous: true
                anchors.centerIn: parent
                width: Math.min(panel.width - 48, 1040)
                height: Math.min(panel.height - 64, 680)
                scale: root.settingsOpen ? 1.0 : 0.95
                opacity: root.settingsOpen ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1] }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                source: root.settingsOpen ? Qt.resolvedUrl("modules/SettingsWindow.qml") : ""
                onLoaded: {
                    if (item) {
                        item.activePageId = root.initialSettingsPage;
                        if (typeof item.closeRequested !== "undefined") {
                            item.closeRequested.connect(() => { root.settingsOpen = false; });
                        }
                    }
                }
            }
        }
    }

    WidgetDesktopHost {
        id: widgetDesktopHost
        notchRoot: root
    }

    WidgetSidebarWindow {
        id: widgetSidebar
        notchRoot: root
    }

    IrisLockManager {
        id: irisLock
        recordingActive: root.isScreenRecording
    }

    IpcHandler {
        target: "lock"
        function lock(): string {
            root.collapseToIdle();
            irisLock.lock();
            return "LOCKED";
        }
        function edit(): string {
            root.collapseToIdle();
            if (LockConfig.editing) {
                LockConfig.editing = false;
                LockConfig.selection = "";
                return "EDIT_CLOSED";
            }
            irisLock.openEditor();
            return "EDITING";
        }
        function preview(open: bool): string {
            root.collapseToIdle();
            irisLock.togglePreview(open);
            return open ? "PREVIEW_ON" : "PREVIEW_OFF";
        }
        function status(): string {
            return LockConfig.locked ? "locked" : (LockConfig.editing ? "editing" : "unlocked");
        }
    }
}
