pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "."

// Screen snipper host: coordinates the per-screen freeze-frame overlays and
// the post-capture chain (crop -> clipboard -> notify -> thumbnail).
// Direct port of Matushell's ScreenSnip.qml using grim + ImageMagick + wl-copy.
Item {
    id: root

    // --- Public API ---
    enum Mode {
        Region,
        Window,
        Fullscreen,
        FullscreenNow
    }

    readonly property string snipDir: (Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") : "/tmp") + "/matushell/snip"
    readonly property string cropPath: root.snipDir + "/crop.png"
    readonly property alias isOpen: root.snipOpen
    property int currentMode: ScreenSnip.Mode.Region
    property bool snipOpen: false
    property bool closing: false

    // --- Local State ---
    property bool initialized: false
    property var lastSnipScreen: null
    property bool previewOpen: false
    property int snipEpoch: 0
    property int snipWidth: 0
    property int snipHeight: 0
    property string frozenPath: ""

    property int _pendingWidth: 0
    property int _pendingHeight: 0
    property var _pendingCommand: []

    function open(filePath, outputName) {
        root.frozenPath = filePath || ""
        if (outputName && outputName.length > 0) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i]
                const m = Hyprland.monitorFor(s)
                if (s.name === outputName || (m && m.name === outputName)) {
                    root.lastSnipScreen = s
                    break
                }
            }
        }
        root.openMode(ScreenSnip.Mode.Region)
    }

    function openMode(mode) {
        root.initialized = true
        closeFadeTimer.stop()
        root.closing = false
        root.currentMode = mode
        if (root.snipOpen) {
            root.snipOpen = false
        }
        root.snipOpen = true
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
        MatusLogger.log("Snip", "Opening snipper (mode " + mode + ")")
    }

    // Cancel path: fade overlays out, then end the session.
    function close() {
        if (root.closing)
            return
        root.closing = true
        closeFadeTimer.restart()
    }

    // Confirm path: no fade — capture speed matters.
    function closeInstant() {
        closeFadeTimer.stop()
        root.closing = false
        root.snipOpen = false
        root.initialized = false
    }

    function confirmSnip(screenItem, monitorName, cropX, cropY, cropWidth, cropHeight, globalX, globalY) {
        if (cropWidth < 4 || cropHeight < 4)
            return
        root.lastSnipScreen = screenItem
        root._pendingWidth = cropWidth
        root._pendingHeight = cropHeight
        const geom = cropWidth + "x" + cropHeight + "+" + cropX + "+" + cropY
        MatusLogger.log("Snip", "Capturing " + monitorName + " " + geom)

        if (root.frozenPath && root.frozenPath.length > 0) {
            root._pendingCommand = [
                "bash", "-c",
                "mkdir -p \"$1\" && magick \"$2\" -crop \"$3\" +repage \"$4\" && wl-copy --type image/png < \"$4\" && rm -f \"$2\"",
                "sh", root.snipDir, root.frozenPath, geom, root.cropPath
            ]
            root.closeInstant()
            captureProcess.command = root._pendingCommand
            captureProcess.running = true
        } else {
            const tmpFrame = root.snipDir + "/frame.png"
            root._pendingCommand = [
                "bash", "-c",
                "mkdir -p \"$1\" && grim -l 0 -o \"$2\" \"$3\" && magick \"$3\" -crop \"$4\" +repage \"$5\" && wl-copy --type image/png < \"$5\" && rm -f \"$3\"",
                "sh", root.snipDir, monitorName, tmpFrame, geom, root.cropPath
            ]
            root.closeInstant()
            delayedCaptureTimer.restart()
        }
    }

    function dismissPreview() {
        root.previewOpen = false
    }

    function snipFullscreenDirect() {
        if (root.snipOpen)
            root.closeInstant()

        let targetScreen = null
        let monName = ""

        const focusedMon = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.monitor : null
        if (focusedMon) {
            monName = focusedMon.name
            for (let i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i]
                const m = Hyprland.monitorFor(s)
                if (m && m.name === monName) {
                    targetScreen = s
                    break
                }
            }
        }

        if (!targetScreen && Quickshell.screens.length > 0) {
            targetScreen = Quickshell.screens[0]
            const m = Hyprland.monitorFor(targetScreen)
            monName = m ? m.name : (targetScreen.name || "")
        }

        root.lastSnipScreen = targetScreen
        root.initialized = true
        const scale = (focusedMon && focusedMon.scale) ? focusedMon.scale : 1
        root._pendingWidth = targetScreen ? Math.round(targetScreen.width * scale) : 1920
        root._pendingHeight = targetScreen ? Math.round(targetScreen.height * scale) : 1080
        root._pendingCommand = [
            "bash", "-c",
            "mkdir -p \"$1\" && grim -l 0 -o \"$2\" \"$3\" && wl-copy --type image/png < \"$3\"",
            "sh", root.snipDir, monName, root.cropPath
        ]
        captureProcess.command = root._pendingCommand
        captureProcess.running = true
    }

    function saveSnip() {
        const pics = Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures")
        const saveDir = pics + "/Screenshots"
        const fileName = "screenshot-" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss") + ".png"
        const savedPath = saveDir + "/" + fileName
        Quickshell.execDetached([
            "bash", "-c",
            "mkdir -p \"$1\" && cp -- \"$2\" \"$3\" && choice=$(notify-send -a 'ScreenSnip' -i \"file://$3\" -h \"string:image-path:file://$3\" -A 'view=View' -A 'folder=Folder' -t 6000 'Screenshot saved' \"$4\"); case \"$choice\" in view) xdg-open \"$3\" ;; folder) xdg-open \"$1\" ;; esac",
            "sh", saveDir, root.cropPath, savedPath, fileName
        ])
        saveDismissTimer.restart()
    }

    function editSnip() {
        Quickshell.execDetached(["swappy", "-f", root.cropPath])
        root.previewOpen = false
    }

    onPreviewOpenChanged: {
        if (root.previewOpen)
            thumbnailLoader.active = true
    }

    Timer {
        id: closeFadeTimer
        interval: MatusMotion.durationFastEffects + 50
        onTriggered: {
            root.closing = false
            root.snipOpen = false
            root.initialized = false
            if (root.frozenPath && root.frozenPath.length > 0) {
                Quickshell.execDetached(["rm", "-f", root.frozenPath])
                root.frozenPath = ""
            }
        }
    }

    Timer {
        id: delayedCaptureTimer
        interval: 35
        onTriggered: {
            captureProcess.command = root._pendingCommand
            captureProcess.running = true
        }
    }

    Process {
        id: captureProcess
        onExited: function (code, status) {
            if (code === 0) {
                root.snipEpoch++
                root.snipWidth = root._pendingWidth
                root.snipHeight = root._pendingHeight
                root.previewOpen = true
            } else {
                MatusLogger.error("Snip", "Capture failed with exit code " + code)
            }
            root.frozenPath = ""
        }
    }

    Timer {
        id: saveDismissTimer
        interval: MatusMotion.durationDefaultSpatial + 50
        onTriggered: root.previewOpen = false
    }

    Connections {
        function onSnipRequested() {
            root.openMode(ScreenSnip.Mode.Region)
        }

        target: MatusOverlays
    }

    LazyLoader {
        id: thumbnailLoader
        active: false

        SnipThumbnail {
            previewOpen: root.previewOpen
            snipEpoch: root.snipEpoch
            snipWidth: root.snipWidth
            snipHeight: root.snipHeight
            cropPath: root.cropPath
            screen: root.lastSnipScreen

            onSaveRequested: root.saveSnip()
            onEditRequested: root.editSnip()
            onDismissRequested: root.dismissPreview()
            onCloseFinished: thumbnailLoader.active = false
        }
    }

    // One overlay per screen, matching Matushell's AreaPickerOverlay literally.
    Variants {
        model: root.initialized ? Quickshell.screens : []

        AreaPickerOverlay {
            required property var modelData

            screen: modelData
            host: root
            freezeFrame: true
            windowNamespace: "matushell:snip"
            onCancelled: root.close()
            onConfirmed: function (screenItem, monitorName, cropX, cropY, cropWidth, cropHeight, globalX, globalY) {
                root.confirmSnip(screenItem, monitorName, cropX, cropY, cropWidth, cropHeight, globalX, globalY)
            }
        }
    }
}
