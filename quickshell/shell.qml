import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import "./modules"
import "./" // Imports NotchConfig singleton

ShellRoot {
    id: root

    property string activeMode: "idle"
    property string previousExpandedMode: "theme"
    property bool isWorkspacePeeking: false
    property bool isScreenRecording: false
    property int screenRecordSeconds: 0
    property string recSaveDirectory: "~/Videos"
    property bool recAudioEnabled: false
    property string recAudioSourceId: ""
    property string recAudioSourceName: "Default Microphone"

    Timer {
        id: screenRecordTimer
        interval: 1000
        running: root.isScreenRecording
        repeat: true
        onTriggered: root.screenRecordSeconds++
    }

    Process {
        id: globalRecordChecker
        running: false
        command: ["sh", "-c", "pgrep -x wf-recorder > /dev/null && echo 'running' || echo 'stopped'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var running = (this.text.trim() === "running");
                if (root.isScreenRecording !== running) {
                    root.isScreenRecording = running;
                    if (!running) {
                        root.screenRecordSeconds = 0;
                    }
                }
            }
        }
    }

    Timer {
        id: globalRecordPollTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
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
        var saveDir = (root.recSaveDirectory && root.recSaveDirectory !== "") ? root.recSaveDirectory : "~/Videos";
        var expandedDir = saveDir.replace(/^~/, Quickshell.env("HOME"));
        var filename = "recording_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + ".mp4";
        
        var audioCmd = "";
        if (root.recAudioEnabled) {
            var targetSrc = (root.recAudioSourceId && root.recAudioSourceId !== "") ? root.recAudioSourceId : "@DEFAULT_SOURCE@";
            audioCmd = "--audio=" + targetSrc;
        }
        
        var recordCmd = "";
        if (regionMode) {
            recordCmd = `mkdir -p "${expandedDir}" && wf-recorder ${audioCmd} -g "$(slurp)" -f "${expandedDir}/${filename}"`;
        } else {
            recordCmd = `mkdir -p "${expandedDir}" && wf-recorder ${audioCmd} -f "${expandedDir}/${filename}"`;
        }

        Quickshell.execDetached(["sh", "-c", recordCmd]);
        root.isScreenRecording = true;
        root.screenRecordSeconds = 0;
        root.collapseToIdle();
    }

    function stopRecording() {
        Quickshell.execDetached(["sh", "-c", "killall -s SIGINT wf-recorder || killall wf-recorder"]);
        root.isScreenRecording = false;
        root.screenRecordSeconds = 0;
    }
    property bool openedViaShortcut: false

    // Persistent notifications store
    ListModel {
        id: globalNotifModel
    }

    // Notification Island Banner State
    property string notifPopupSummary: ""
    property string notifPopupBody: ""
    property string notifPopupApp: ""
    property bool isNotifPopupActive: notifPopupSummary !== ""

    Timer {
        id: notifPopupTimer
        interval: NotchConfig.timerNotifPopup
        repeat: false
        onTriggered: {
            root.notifPopupSummary = "";
            root.notifPopupBody = "";
            root.notifPopupApp = "";
            if (root.activeMode === "idle" && !notchHoverHandler.hovered) {
                root.collapseToIdle();
            }
        }
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

    // Voice Dictation Island State (Section 5.4 Voice Dictation / AI Speech Island)
    property bool isDictationActive: false
    property string dictationState: "idle" // "idle", "listening", "transcribing", "done", "empty", "error"
    property string dictationText: ""
    property int dictationSeconds: 0
    property real dictationAudioLevel: 0.0
    property var dictationWavePoints: [0.25, 0.45, 0.7, 0.9, 0.7, 0.45, 0.25]
    property real dictationPressTime: 0
    property bool isDictationWorkerReady: false

    Timer {
        id: dictationTimer
        interval: 1000
        repeat: true
        running: root.isDictationActive && root.dictationState === "listening"
        onTriggered: {
            root.dictationSeconds++;
            if (root.dictationSeconds >= 60) {
                root.stopDictation();
            }
        }
    }

    Timer {
        id: dictationAutoDismissTimer
        interval: 1600
        repeat: false
        onTriggered: {
            root.isDictationActive = false;
            root.dictationState = "idle";
            root.dictationText = "";
            root.dictationSeconds = 0;
            if (root.activeMode === "idle" && typeof notchHoverHandler !== "undefined" && !notchHoverHandler.hovered) {
                root.collapseToIdle();
            }
        }
    }

    function startDictation() {
        if (root.activeMode !== "idle" && root.activeMode !== "hover") {
            root.collapseToIdle();
        }
        root.isDictationActive = true;
        root.dictationState = "listening";
        root.dictationText = "";
        root.dictationSeconds = 0;
        dictationAutoDismissTimer.stop();
        if (dictationWorker.running) {
            dictationWorker.write("START\n");
        }
    }

    function stopDictation() {
        if (!root.isDictationActive) return;
        dictationTimer.stop();
        root.dictationState = "transcribing";
        if (dictationWorker.running) {
            dictationWorker.write("STOP\n");
        }
    }

    function cancelDictation() {
        if (!root.isDictationActive) return;
        dictationTimer.stop();
        dictationAutoDismissTimer.stop();
        root.isDictationActive = false;
        root.dictationState = "idle";
        root.dictationText = "";
        root.dictationSeconds = 0;
        if (dictationWorker.running) {
            dictationWorker.write("CANCEL\n");
        }
        if (root.activeMode === "idle" && typeof notchHoverHandler !== "undefined" && !notchHoverHandler.hovered) {
            root.collapseToIdle();
        }
    }

    function toggleDictation() {
        if (root.isDictationActive && root.dictationState === "listening") {
            root.stopDictation();
        } else {
            root.startDictation();
        }
    }

    function handleDictationEvent(msg) {
        if (!msg || !msg.event) return;
        switch(msg.event) {
            case "ready":
                root.isDictationWorkerReady = true;
                break;
            case "state":
                root.dictationState = msg.state;
                break;
            case "level":
                root.dictationAudioLevel = msg.level || 0;
                root.dictationWavePoints = msg.bars || [0.25, 0.45, 0.7, 0.9, 0.7, 0.45, 0.25];
                break;
            case "done":
                root.dictationState = "done";
                root.dictationText = msg.text || "";
                dictationAutoDismissTimer.restart();
                break;
            case "empty":
                root.dictationState = "empty";
                root.dictationText = "No speech detected";
                dictationAutoDismissTimer.restart();
                break;
            case "cancelled":
                root.isDictationActive = false;
                root.dictationState = "idle";
                root.dictationText = "";
                break;
            case "error":
                root.dictationState = "error";
                root.dictationText = msg.message || "Error";
                dictationAutoDismissTimer.restart();
                break;
        }
    }

    // Background Voice Dictation Worker Process
    Process {
        id: dictationWorker
        command: [
            Qt.resolvedUrl("scripts/voice_dictation.sh").toString().replace(/^file:\/\//, ""),
            "worker"
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                var raw = data.trim();
                if (!raw) return;
                try {
                    var msg = JSON.parse(raw);
                    root.handleDictationEvent(msg);
                } catch (e) {
                    // Ignore non-json logs
                }
            }
        }
    }

    // ========================================================
    // SECTION 4.3: QR CODE UTILITIES STATE & ACTIONS
    // ========================================================
    property string qrContentText: ""
    property string qrScannedText: ""
    property bool isQrScannedIslandActive: false

    Timer {
        id: qrScannedIslandTimer
        interval: 7000
        repeat: false
        onTriggered: {
            root.isQrScannedIslandActive = false;
            root.qrScannedText = "";
            if (root.activeMode === "idle" && typeof notchHoverHandler !== "undefined" && !notchHoverHandler.hovered) {
                root.collapseToIdle();
            }
        }
    }

    function scanQr() {
        Quickshell.execDetached(["bash", Qt.resolvedUrl("scripts/qr_utils.sh").toString().replace(/^file:\/\//, ""), "scan"]);
    }

    function generateQrFromClipboard() {
        Quickshell.execDetached(["bash", Qt.resolvedUrl("scripts/qr_utils.sh").toString().replace(/^file:\/\//, ""), "encode"]);
    }

    function showQr(text) {
        root.qrContentText = text || "";
        root.switchMode("qr", true);
    }

    function onQrScanned(text) {
        if (!text) return;
        root.qrScannedText = text;
        root.isQrScannedIslandActive = true;
        qrScannedIslandTimer.restart();
        if (root.activeMode !== "idle" && root.activeMode !== "hover") {
            root.collapseToIdle();
        }
    }

    // ========================================================
    // SECTION 4.4: DYNAMIC ISLAND POMODORO & FOCUS TIMER STATE
    // ========================================================
    property bool pomoRunning: false
    property bool pomoPaused: false
    property int pomoSecondsRemaining: 0
    property int pomoTotalSeconds: 0
    property string pomoMode: "focus" // "focus", "short_break", "long_break"
    property string pomoTag: "Focus Sprint"
    property bool pomoDndWasActive: false
    property bool pomoDndAutoActivated: false
    property bool isPomoFinishedIslandActive: false
    property string pomoFinishedTitle: ""
    property string pomoFinishedMessage: ""

    function formatPomoTime(sec) {
        var s = Math.max(0, sec || 0);
        var m = Math.floor(s / 60);
        var remSec = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (remSec < 10 ? "0" : "") + remSec;
    }

    Timer {
        id: pomoTicker
        interval: 1000
        repeat: true
        running: root.pomoRunning && !root.pomoPaused
        onTriggered: {
            if (root.pomoSecondsRemaining > 0) {
                root.pomoSecondsRemaining--;
                if (root.pomoSecondsRemaining <= 0) {
                    root.completePomodoro();
                }
            }
        }
    }

    Timer {
        id: pomoFinishedAutoDismissTimer
        interval: 10000
        repeat: false
        onTriggered: {
            root.isPomoFinishedIslandActive = false;
            root.pomoFinishedTitle = "";
            root.pomoFinishedMessage = "";
            if (root.activeMode === "idle" && typeof notchHoverHandler !== "undefined" && !notchHoverHandler.hovered) {
                root.collapseToIdle();
            }
        }
    }

    function startPomodoro(minutes, mode, tag) {
        var mins = parseInt(minutes) || 25;
        var m = mode || "focus";
        root.pomoMode = m;
        root.pomoTag = tag || (m === "focus" ? "Focus Sprint" : (m === "short_break" ? "Short Break" : "Long Break"));
        root.pomoTotalSeconds = mins * 60;
        root.pomoSecondsRemaining = mins * 60;
        root.pomoRunning = true;
        root.pomoPaused = false;
        root.isPomoFinishedIslandActive = false;

        if (m === "focus") {
            root.pomoDndWasActive = root.dndEnabled;
            if (!root.dndEnabled) {
                root.dndEnabled = true;
                root.pomoDndAutoActivated = true;
            }
        }

        Quickshell.execDetached(["notify-send", "-a", "Pomodoro", root.pomoTag + " Started (" + mins + "m)", m === "focus" ? "Distraction-Free Focus mode active (DND enabled)" : "Enjoy your rest!"]);
    }

    function pausePomodoro() {
        if (root.pomoRunning) {
            root.pomoPaused = true;
        }
    }

    function resumePomodoro() {
        if (root.pomoRunning) {
            root.pomoPaused = false;
        }
    }

    function togglePomodoroPause() {
        if (!root.pomoRunning) {
            root.startPomodoro(25, "focus");
        } else {
            root.pomoPaused = !root.pomoPaused;
        }
    }

    function stopPomodoro() {
        root.pomoRunning = false;
        root.pomoPaused = false;
        root.pomoSecondsRemaining = 0;
        root.pomoTotalSeconds = 0;
        if (root.pomoDndAutoActivated) {
            root.dndEnabled = root.pomoDndWasActive;
            root.pomoDndAutoActivated = false;
        }
    }

    function completePomodoro() {
        root.pomoRunning = false;
        root.pomoPaused = false;
        if (root.pomoDndAutoActivated) {
            root.dndEnabled = root.pomoDndWasActive;
            root.pomoDndAutoActivated = false;
        }

        Quickshell.execDetached(["sh", "-c", "command -v canberra-gtk-play >/dev/null && canberra-gtk-play -i complete || paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || aplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null"]);

        var wasFocus = (root.pomoMode === "focus");
        root.pomoFinishedTitle = wasFocus ? "Focus Sprint Complete!" : "Break Finished!";
        root.pomoFinishedMessage = wasFocus ? "Outstanding focus! Take a well-earned break." : "Break is over. Ready to lock back in?";
        root.isPomoFinishedIslandActive = true;
        pomoFinishedAutoDismissTimer.restart();

        Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Pomodoro", root.pomoFinishedTitle, root.pomoFinishedMessage]);

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
                root.notifPopupSummary = summaryText !== "" ? summaryText : appNameText;
                root.notifPopupBody = bodyText;
                root.notifPopupApp = appNameText;
                notifPopupTimer.restart();
            }
        }
    }

    readonly property bool isDashMode: activeMode === "idle" || activeMode === "hover"
    readonly property color notchSurfaceColor: Theme.colors.bg ?? "#000000"
    readonly property bool isPopupMode: activeMode !== "idle" && activeMode !== "osd"

    function collapseToIdle() {
        root.isWorkspacePeeking = false;
        root.openedViaShortcut = false;
        if (typeof notchHoverHandler !== "undefined" && notchHoverHandler.hovered) {
            root.activeMode = "hover";
        } else {
            root.activeMode = "idle";
        }
    }

    function switchMode(newMode, fromShortcut = false) {
        root.isWorkspacePeeking = false;
        if (root.activeMode === newMode) {
            root.collapseToIdle();
        } else {
            root.openedViaShortcut = fromShortcut;
            root.activeMode = newMode;
        }
    }

    // Dynamic Module Lazy Loader & State
    property string loadedExpandedMode: ""
    property string requestedUtilitySection: ""
    property string requestedMusicPanel: ""
    property var pendingDropUrls: []

    Timer {
        id: moduleUnloadTimer
        interval: NotchConfig.animNotchResize // 260ms matches collapse animation
        repeat: false
        onTriggered: {
            if (root.activeMode === "idle" || root.activeMode === "hover" || root.activeMode === "osd") {
                root.loadedExpandedMode = "";
            }
        }
    }

    function getModuleSource(mode) {
        switch(mode) {
            case "launcher":      return Qt.resolvedUrl("modules/Launcher.qml");
            case "theme":         return Qt.resolvedUrl("modules/ThemeSelector.qml");
            case "wallpaper":     return Qt.resolvedUrl("modules/WallpaperSelector.qml");
            case "transition":    return Qt.resolvedUrl("modules/TransitionSelector.qml");
            case "bluetooth":     return Qt.resolvedUrl("modules/BluetoothModule.qml");
            case "wifi":          return Qt.resolvedUrl("modules/WifiModule.qml");
            case "recorder":      return Qt.resolvedUrl("modules/RecorderModule.qml");
            case "battery":       return Qt.resolvedUrl("modules/BatteryModule.qml");
            case "powermenu":     return Qt.resolvedUrl("modules/PowerMenu.qml");
            case "calendar":      return Qt.resolvedUrl("modules/CalendarModule.qml");
            case "clipboard":     return Qt.resolvedUrl("modules/ClipboardModule.qml");
            case "shelf":         return Qt.resolvedUrl("modules/ShelfModule.qml");
            case "notifications": return Qt.resolvedUrl("modules/NotificationModule.qml");
            case "switcher":      return Qt.resolvedUrl("modules/WindowSwitcher.qml");
            case "utility":       return Qt.resolvedUrl("modules/UtilityModule.qml");
            case "music":         return Qt.resolvedUrl("modules/MusicModule.qml");
            case "notes":         return Qt.resolvedUrl("modules/NotesModule.qml");
            case "cheatsheet":    return Qt.resolvedUrl("modules/KeybindsModule.qml");
            case "taskmanager":   return Qt.resolvedUrl("modules/TaskManagerModule.qml");
            case "qr":            return Qt.resolvedUrl("modules/QrModule.qml");
            default:              return "";
        }
    }

    // Dynamic Module Aliases (Null-safe; points to moduleLoader.item when active)
    readonly property var launcherMod:   (root.loadedExpandedMode === "launcher") ? moduleLoader.item : null
    readonly property var themeMod:      (root.loadedExpandedMode === "theme") ? moduleLoader.item : null
    readonly property var wallMod:       (root.loadedExpandedMode === "wallpaper") ? moduleLoader.item : null
    readonly property var transMod:      (root.loadedExpandedMode === "transition") ? moduleLoader.item : null
    readonly property var btMod:         (root.loadedExpandedMode === "bluetooth") ? moduleLoader.item : null
    readonly property var wifiMod:       (root.loadedExpandedMode === "wifi") ? moduleLoader.item : null
    readonly property var recMod:        (root.loadedExpandedMode === "recorder") ? moduleLoader.item : null
    readonly property var battMod:       (root.loadedExpandedMode === "battery") ? moduleLoader.item : null
    readonly property var powerMod:      (root.loadedExpandedMode === "powermenu") ? moduleLoader.item : null
    readonly property var calMod:        (root.loadedExpandedMode === "calendar") ? moduleLoader.item : null
    readonly property var clipMod:       (root.loadedExpandedMode === "clipboard") ? moduleLoader.item : null
    readonly property var shelfMod:      (root.loadedExpandedMode === "shelf") ? moduleLoader.item : null
    readonly property var notifMod:      (root.loadedExpandedMode === "notifications") ? moduleLoader.item : null
    readonly property var switcherMod:   (root.loadedExpandedMode === "switcher") ? moduleLoader.item : null
    readonly property var utilMod:       (root.loadedExpandedMode === "utility") ? moduleLoader.item : null
    readonly property var musicMod:      (root.loadedExpandedMode === "music") ? moduleLoader.item : null
    readonly property var notesMod:      (root.loadedExpandedMode === "notes") ? moduleLoader.item : null
    readonly property var cheatsheetMod: (root.loadedExpandedMode === "cheatsheet") ? moduleLoader.item : null
    readonly property var taskMgrMod:    (root.loadedExpandedMode === "taskmanager") ? moduleLoader.item : null
    readonly property var qrMod:         (root.loadedExpandedMode === "qr") ? moduleLoader.item : null

    function openUtility(section = "", fromShortcut = false) {
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
        }
    }

	function regainFocus() {
        if (activeMode === "launcher" && root.launcherMod) root.launcherMod.searchInput.forceActiveFocus();
		else if (activeMode === "switcher" && root.switcherMod) root.switcherMod.forceActiveFocus();
        else if (activeMode === "theme" && root.themeMod) root.themeMod.forceThemeFocus();
        else if (activeMode === "wallpaper" && root.wallMod) root.wallMod.wallpaperGrid.forceActiveFocus();
        else if (activeMode === "transition" && root.transMod) root.transMod.transitionGrid.forceActiveFocus();
        else if (activeMode === "clipboard" && root.clipMod) root.clipMod.searchInput.forceActiveFocus();
        else if (activeMode === "shelf" && root.shelfMod) root.shelfMod.forceShelfFocus();
        else if (activeMode === "powermenu" && root.powerMod) root.powerMod.forceActiveFocus();
        else if (activeMode === "notes" && root.notesMod) root.notesMod.forceNotesFocus();
        else if (activeMode === "cheatsheet" && root.cheatsheetMod) root.cheatsheetMod.forceSearchFocus();
        else if (activeMode === "taskmanager" && root.taskMgrMod) root.taskMgrMod.forceSearchFocus();
        else if (activeMode === "music" && root.musicMod) root.musicMod.forceActiveFocus();
        else if (activeMode === "qr" && root.qrMod) root.qrMod.forceQrFocus();
        else if (typeof moduleLoader !== "undefined" && moduleLoader.item) moduleLoader.item.forceActiveFocus();
        else notchContainer.forceActiveFocus();
    }

    onActiveModeChanged: {
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
        } else if (activeMode === "bluetooth" && typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = true;
        } else if (typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = false;
        }

        if (activeMode === "launcher") {
            if (root.launcherMod) root.launcherMod.onOpened();
        }

        Qt.callLater(() => {
            root.regainFocus();
            if (activeMode !== "launcher" && root.launcherMod) root.launcherMod.searchInput.text = "";
            if (activeMode !== "theme" && root.themeMod) root.themeMod.resetSearch();
            if (activeMode !== "clipboard" && root.clipMod) root.clipMod.searchInput.text = "";
            if (activeMode !== "shelf" && root.shelfMod) root.shelfMod.searchInput.text = "";
            if (activeMode !== "taskmanager" && root.taskMgrMod) root.taskMgrMod.searchInput.text = "";
        });
    }

    // ========================================================
    // CENTRALIZED DIMENSIONS RESOLUTION (from NotchConfig)
    // ========================================================
    readonly property int targetWidth: {
        if (isDashMode && typeof dashMod !== "undefined" && dashMod !== null) {
            return dashMod.implicitWidth;
        }
        if (activeMode === "notes" && root.notesMod && root.notesMod.isWideMode) {
            return 820;
        }
        if (activeMode === "utility" && root.utilMod && root.utilMod.activeSection === "vpn") {
            return 420;
        }
        var dim = NotchConfig.modeDimensions[activeMode];
        return dim && dim.width !== undefined ? dim.width : NotchConfig.modeDimensions["idle"].width;
    }
    
    readonly property int targetHeight: {
        if (root.isPomoFinishedIslandActive && root.isDashMode) {
            return 44;
        }
        if (root.isQrScannedIslandActive && root.isDashMode) {
            return 42;
        }
        if (root.isDictationActive && root.isDashMode) {
            return 42;
        }
        if (root.isScreenshotIslandActive && root.isDashMode) {
            return 44;
        }
        if (root.isNotifPopupActive && root.isDashMode) {
            return 42;
        }
        if (activeMode === "qr") {
            return 390;
        }
        if (activeMode === "cheatsheet" && root.cheatsheetMod && root.cheatsheetMod.isAddingMode) {
            return 500;
        }
        if (activeMode === "launcher") {
            return (root.launcherMod && root.launcherMod.allApps)
                ? NotchConfig.calculateLauncherHeight(root.launcherMod.calculatedCount, root.launcherMod.allApps.length, root.launcherMod.browsing)
                : 246;
        }
        if (activeMode === "transition" || activeMode === "calendar" || activeMode === "powermenu" || activeMode === "battery" || activeMode === "notes" || activeMode === "cheatsheet") {
            var mDim = NotchConfig.modeDimensions[activeMode];
            return mDim && mDim.height !== undefined ? mDim.height : 220;
        }
        if (activeMode === "notifications") {
            return NotchConfig.calculateNotificationsHeight(globalNotifModel.count);
        }
        if (activeMode === "shelf") {
            return NotchConfig.calculateShelfHeight(root.shelfMod ? root.shelfMod.calculatedCount : 0);
        }
        if (activeMode === "clipboard") {
            return NotchConfig.calculateClipboardHeight(root.clipMod ? root.clipMod.calculatedCount : 0);
        }
        if (activeMode === "recorder") {
            return root.recMod 
                ? NotchConfig.calculateRecorderHeight(root.recMod.recordAudio, root.recMod.isMicDropdownOpen, root.recMod.isRecording) 
                : 270;
        }
        if (activeMode === "bluetooth") {
            return (root.btMod && root.btMod.filteredDevices)
                ? NotchConfig.calculateBluetoothHeight(root.btMod.filteredDevices, root.btMod.stateMap)
                : 380;
        }
        if (activeMode === "wifi") {
            return (root.wifiMod && root.wifiMod.model)
                ? NotchConfig.calculateWifiHeight(root.wifiMod.activeTab, root.wifiMod.wifiEnabled, root.wifiMod.model.count, root.wifiMod.listViewContentHeight)
                : 380;
        }
        if (activeMode === "utility") {
            return root.utilMod
                ? NotchConfig.calculateUtilityHeight(root.utilMod.activeSection)
                : 400;
        }
        if (activeMode === "music") {
            return (root.musicMod && root.musicMod.calculatedHeight) ? root.musicMod.calculatedHeight : 265;
        }
        if (activeMode === "idle") {
            return 32;
        }
        if (activeMode === "hover") {
            return 42;
        }
        var hDim = NotchConfig.modeDimensions[activeMode];
        return hDim && hDim.height !== undefined ? hDim.height : NotchConfig.modeDimensions["idle"].height;
    } 

    readonly property int targetRadius: {
        if (root.isDictationActive || (dashMod && dashMod.isIslandActive) || (root.isNotifPopupActive && root.isDashMode) || (root.isScreenshotIslandActive && root.isDashMode) || (root.isPomoFinishedIslandActive && root.isDashMode) || (root.isQrScannedIslandActive && root.isDashMode)) {
            return 21;
        }
        if (activeMode === "idle") {
            return 16;
        }
        if (activeMode === "hover") {
            return 21;
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

    Connections {
        target: typeof Hyprland !== "undefined" ? Hyprland : null
        function onRawEvent(event) {
            var evName = (typeof event === "object" && event !== null) ? event.name : event;
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
    GlobalShortcut { name: "toggleThemeNotch"; onPressed: root.switchMode("theme", true) }
    GlobalShortcut { name: "toggleWallpaperNotch"; onPressed: root.switchMode("wallpaper", true) }
    GlobalShortcut { name: "toggleTransitionNotch"; onPressed: root.switchMode("transition", true) }
    GlobalShortcut { name: "resetNotchToIdle"; onPressed: root.collapseToIdle() }
    GlobalShortcut { name: "toggleBatteryNotch"; onPressed: root.switchMode("battery", true) }
    GlobalShortcut { name: "togglePowerMenuNotch"; onPressed: root.switchMode("powermenu", true) }
    GlobalShortcut { name: "toggleCalendarNotch"; onPressed: root.switchMode("calendar", true) }
    GlobalShortcut { name: "toggleClipboardNotch"; onPressed: root.switchMode("clipboard", true) }
    GlobalShortcut { name: "toggleShelfNotch"; onPressed: root.switchMode("shelf", true) }
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
        name: "triggerScreenOcr"
        onPressed: {
            if (root.activeMode !== "idle" && root.activeMode !== "hover") {
                root.collapseToIdle();
            }
            if (typeof dashMod !== "undefined") dashMod.startOcr();
        }
    }

    GlobalShortcut {
        name: "scanScreenQr"
        onPressed: {
            if (root.activeMode !== "idle" && root.activeMode !== "hover") {
                root.collapseToIdle();
            }
            root.scanQr();
        }
    }

    GlobalShortcut {
        name: "generateClipboardQr"
        onPressed: root.generateQrFromClipboard()
    }

    GlobalShortcut {
        name: "togglePomo"
        onPressed: root.togglePomodoroPause()
    }

    GlobalShortcut {
        name: "voiceDictationPress"
        onPressed: {
            root.dictationPressTime = Date.now();
            if (root.isDictationActive && root.dictationState === "listening") {
                root.stopDictation();
            } else if (!root.isDictationActive) {
                root.startDictation();
            }
        }
    }

    GlobalShortcut {
        name: "voiceDictationRelease"
        onPressed: {
            var elapsed = Date.now() - root.dictationPressTime;
            if (elapsed > 350 && root.isDictationActive && root.dictationState === "listening") {
                root.stopDictation();
            }
        }
    }

    GlobalShortcut {
        name: "toggleDictation"
        onPressed: root.toggleDictation()
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
        target: "notch"
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
            root.activeMode = "launcher";
            if (root.launcherMod && root.launcherMod.searchInput) {
                root.launcherMod.searchInput.text = query || "";
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
        function startDictation(): string {
            root.startDictation();
            return "OK";
        }
        function stopDictation(): string {
            root.stopDictation();
            return "OK";
        }
        function toggleDictation(): string {
            root.toggleDictation();
            return "OK";
        }
        function cancelDictation(): string {
            root.cancelDictation();
            return "OK";
        }
        function scanQr(): string {
            root.scanQr();
            return "OK";
        }
        function showQr(text: string): string {
            root.showQr(text);
            return "OK";
        }
        function onQrScanned(text: string): string {
            root.onQrScanned(text);
            return "OK";
        }
        function startPomo(minutes: int, mode: string): string {
            root.startPomodoro(minutes, mode);
            return "OK";
        }
        function stopPomo(): string {
            root.stopPomodoro();
            return "OK";
        }
        function pausePomo(): string {
            root.pausePomodoro();
            return "OK";
        }
        function resumePomo(): string {
            root.resumePomodoro();
            return "OK";
        }
        function togglePomo(): string {
            root.togglePomodoroPause();
            return "OK";
        }
    }

    // Native Hyprland focus grabber (disabled to prevent background window focus changes from collapsing popups)
    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [panel]
        onCleared: {
            if (root.shelfMod && root.shelfMod.isDragging) return;
            root.collapseToIdle();
        }
    }

    // Permanent top reservation for Hyprland window tiling (32px)
    PanelWindow {
        id: reservationPanel
        anchors.top: true
        exclusiveZone: NotchConfig.baseExclusiveZone
        color: "transparent"
        Item { id: emptyResItem; width: 0; height: 0 }
        mask: Region { item: emptyResItem }
    }

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

        mask: Region {
            item: (root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "osd") 
                ? fullMaskArea 
                : (root.activeMode === "hover" ? hoverMaskArea : notchContainer)
        }

        WlrLayershell.keyboardFocus: (root.activeMode !== "idle" && root.activeMode !== "hover" && root.activeMode !== "osd" && root.activeMode !== "switcher" && !root.isDictationActive)
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        // Click-away backdrop: collapses open popups/hover when clicking outside
        MouseArea {
            id: outsideClickCatcher
            anchors.fill: parent
            z: 0
            enabled: root.activeMode !== "idle" && root.activeMode !== "osd"
            onClicked: {
                if (root.isDictationActive) {
                    root.cancelDictation();
                } else {
                    root.collapseToIdle();
                }
            }
        }

        Item {
            id: notchContainer
            z: 1
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: notch.width + (root.cornerCurveRadius * 2)
            height: notch.height

            y: 0
            opacity: 1.0
            visible: true

            focus: root.activeMode !== "idle" && root.activeMode !== "hover"
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    if (root.isDictationActive) {
                        root.cancelDictation();
                    } else {
                        root.collapseToIdle();
                    }
                    event.accepted = true;
                } else {
                    root.regainFocus();
                }
            }
            Keys.onReleased: (event) => {
                if (root.activeMode === "switcher" && (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta)) {
                    if (root.switcherMod) root.switcherMod.activateSelected();
                    event.accepted = true;
                }
            }

            MouseArea {
                id: notchHoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                z: -1
                onEntered: {
                    autoCollapseTimer.stop();
                    if (root.activeMode === "idle") root.activeMode = "hover";
                }
                onExited: {
                    if (root.activeMode === "hover" && !notchHoverHandler.hovered) {
                        root.collapseToIdle();
                    }
                }
            }

            DropArea {
                id: notchDropArea
                anchors.fill: parent
                keys: ["text/uri-list"]

                onEntered: (drag) => {
                    if (root.shelfMod && root.shelfMod.isDragging) return;
                    if (drag.hasUrls) {
                        if (root.activeMode !== "shelf") {
                            root.switchMode("shelf", false);
                        }
                        drag.acceptProposedAction();
                    }
                }

                onDropped: (drop) => {
                    if (root.shelfMod && root.shelfMod.isDragging) return;
                    if (drop.hasUrls) {
                        if (root.shelfMod) {
                            root.shelfMod.addDroppedFiles(drop.urls);
                        } else {
                            root.pendingDropUrls = drop.urls;
                        }
                        drop.acceptProposedAction();
                    }
                }
            }

            // Left Wing
            Canvas {
                id: leftWing
                width: root.cornerCurveRadius; height: root.cornerCurveRadius
                anchors.top: parent.top; anchors.right: notch.left; anchors.rightMargin: -1 
                renderTarget: Canvas.FramebufferObject

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
                renderTarget: Canvas.FramebufferObject

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
                clip: true

                // Consumes clicks on empty space inside notch so they do not fall through to click-away catcher
                MouseArea {
                    anchors.fill: parent
                    z: -1
                }
                
                radius: 0
                bottomLeftRadius: root.targetRadius
                bottomRightRadius: root.targetRadius
                Behavior on width  { NumberAnimation { duration: root.isOsdMode ? 220 : NotchConfig.animNotchResize; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1] } }
                Behavior on height { NumberAnimation { duration: root.isOsdMode ? 220 : NotchConfig.animNotchResize; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1] } }

                // 1. Persistent Dash Layer
                Item {
                    id: dashContainer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.targetHeight
                    z: 5

                    opacity: (root.isDashMode && root.activeMode !== "osd") ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on height { NumberAnimation { duration: root.isOsdMode ? 220 : NotchConfig.animNotchResize; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1] } }
                    Behavior on opacity { NumberAnimation { duration: root.isOsdMode ? 140 : NotchConfig.animDashFade; easing.type: Easing.OutQuad } }

                    MainDash { 
                        id: dashMod 
                        anchors.fill: parent
                    }
                }

                // 2. Expanded Modules Container
                Item {
                    id: modulesContainer
                    anchors.fill: parent
                    anchors.leftMargin: root.activeMode === "music" ? 0 : 12
                    anchors.rightMargin: root.activeMode === "music" ? 0 : 12
                    anchors.topMargin: root.activeMode === "music" ? 0 : 12
                    anchors.bottomMargin: root.activeMode === "music" ? 0 : 12
                    z: 2

                    opacity: (!root.isDashMode && root.activeMode !== "osd" && notch.height > 35) ? 1.0 : 0.0
                    visible: opacity > 0.001
                    enabled: !root.isDashMode && root.activeMode !== "osd"
                    Behavior on opacity { NumberAnimation { duration: NotchConfig.animModulesFade; easing.type: Easing.OutQuad } }

                    Loader {
                        id: moduleLoader
                        anchors.fill: parent
                        asynchronous: true
                        source: root.getModuleSource(root.loadedExpandedMode)
                        onLoaded: {
                            if (!item) return;
                            if (root.loadedExpandedMode === "launcher") {
                                if (typeof item.onOpened === "function") item.onOpened();
                            } else if (root.loadedExpandedMode === "wifi") {
                                if (typeof item.refreshStatus === "function") item.refreshStatus();
                            } else if (root.loadedExpandedMode === "utility") {
                                if (root.requestedUtilitySection !== "") item.activeSection = root.requestedUtilitySection;
                            } else if (root.loadedExpandedMode === "music") {
                                if (root.requestedMusicPanel !== "" && typeof item.togglePanel === "function") {
                                    item.togglePanel(root.requestedMusicPanel);
                                    root.requestedMusicPanel = "";
                                }
                            } else if (root.loadedExpandedMode === "shelf" && root.pendingDropUrls.length > 0) {
                                if (typeof item.addDroppedFiles === "function") item.addDroppedFiles(root.pendingDropUrls);
                                root.pendingDropUrls = [];
                            } else if (root.loadedExpandedMode === "switcher") {
                                if (typeof item.refreshClients === "function") item.refreshClients();
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

                    Osd {
                        id: osdMod
                        anchors.fill: parent
                    }
                }

                Timer {
                    id: autoCollapseTimer
                    interval: NotchConfig.timerAutoCollapse
                    repeat: false
                    onTriggered: {
                        if (root.activeMode === "hover" && !notchHoverHandler.hovered && !notchHoverArea.containsMouse) {
                            root.collapseToIdle();
                        }
                    }
                }

                HoverHandler {
                    id: notchHoverHandler
                    enabled: root.activeMode !== "osd"
                    cursorShape: Qt.ArrowCursor
                    onHoveredChanged: {
                        if (root.shelfMod && root.shelfMod.isDragging) return;
                        if (root.utilMod && (root.utilMod.isDraggingVolume || root.utilMod.isDraggingBrightness)) return;
                        if (root.musicMod && root.musicMod.isDraggingSeek) return;
                        if (hovered) {
                            autoCollapseTimer.stop();
                            root.isWorkspacePeeking = false;
                            if (root.activeMode === "idle") root.activeMode = "hover";
                        } else {
                            if (root.activeMode === "hover" && !notchHoverArea.containsMouse) {
                                root.collapseToIdle();
                            }
                        }
                    }
                }
            }
        }
    }
}
