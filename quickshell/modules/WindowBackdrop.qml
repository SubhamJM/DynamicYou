import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import qs.services

// Niri-style blurred desktop backdrop painted on WlrLayer.Bottom strictly beneath desktop widgets
// and windows whenever any window is open on a monitor's active or special workspace.
// Caches a single 0.25x downsampled blurred texture per wallpaper change (~0% runtime GPU/CPU cost).
Scope {
    id: backdropRoot

    property var notchRoot: null

    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    property string displayImagePath: ""

    function resolveWallpaperImage() {
        if (!wallResolver.running) wallResolver.running = true;
    }

    Component.onCompleted: resolveWallpaperImage()

    Connections {
        target: typeof Theme !== "undefined" ? Theme : null
        function onThemeReloaded() { wallRefreshDebounce.restart(); }
    }

    FileView {
        path: backdropRoot.configDir + "/active-theme/current-wallpaper.txt"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            wallRefreshDebounce.restart();
        }
        onLoaded: wallRefreshDebounce.restart()
    }

    Timer {
        id: wallRefreshDebounce
        interval: 90
        repeat: false
        onTriggered: backdropRoot.resolveWallpaperImage()
    }

    Process {
        id: wallResolver
        running: false
        command: [
            "sh", "-c",
            "cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/active-theme\"; " +
            "if [ -e \"$cfg/current-wallpaper\" ]; then realpath -e -- \"$cfg/current-wallpaper\" 2>/dev/null && exit 0; fi; " +
            "if [ -f \"$cfg/current-wallpaper.txt\" ]; then p=$(head -n1 \"$cfg/current-wallpaper.txt\"); [ -f \"$p\" ] && printf '%s\\n' \"$p\"; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = String(this.text || "").trim();
                if (p !== "" && p !== backdropRoot.displayImagePath) {
                    backdropRoot.displayImagePath = p;
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            readonly property string screenKey: String(modelData.name || "")
            readonly property bool isFullscreen: !!(backdropRoot.notchRoot && backdropRoot.notchRoot.isWindowFullscreen)
            readonly property bool hasWindow: (typeof HyprlandData !== "undefined" && HyprlandData.windowListLoaded)
                ? HyprlandData.monitorHasWindow(win.screenKey)
                : false
            readonly property bool shouldBlur: !win.isFullscreen
                && win.hasWindow
                && backdropRoot.displayImagePath !== ""

            screen: modelData
            color: "transparent"
            visible: !win.isFullscreen && (win.shouldBlur || fadeBox.opacity > 0.001)

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell-window-backdrop"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            mask: Region {}

            Item {
                id: fadeBox
                anchors.fill: parent
                opacity: win.shouldBlur ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                // Cached 0.25x blurred wallpaper framebuffer (~0.6 MB VRAM at 1920x1200, 0% steady-state shader cost)
                Item {
                    id: blurCache
                    anchors.fill: parent
                    clip: true

                    Image {
                        id: rawImg
                        anchors.fill: parent
                        anchors.margins: -36
                        visible: false
                        source: backdropRoot.displayImagePath !== ""
                            ? ("file://" + encodeURI(backdropRoot.displayImagePath).replace(/#/g, "%23").replace(/\?/g, "%3F"))
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        sourceSize: Qt.size(
                            Math.max(64, Math.ceil((win.width + 72) * 0.25)),
                            Math.max(64, Math.ceil((win.height + 72) * 0.25))
                        )
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: rawImg
                        visible: rawImg.status === Image.Ready
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 48
                        saturation: -0.05
                        autoPaddingEnabled: false
                    }

                    layer.enabled: rawImg.status === Image.Ready && blurCache.width > 1 && blurCache.height > 1
                    layer.smooth: true
                    layer.textureSize: Qt.size(
                        Math.max(1, Math.ceil(blurCache.width * 0.25)),
                        Math.max(1, Math.ceil(blurCache.height * 0.25))
                    )
                }

                // Soft tonal dim scrim matching Niri backdrop contrast
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.24)
                }
            }
        }
    }
}
