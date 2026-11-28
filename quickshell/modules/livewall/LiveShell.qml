import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root
    property string path: ""
    readonly property string statePath: Quickshell.env("HOME") + "/.config/active-theme/current-wallpaper.txt"

    FileView {
        path: root.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.path = text().trim()
        onLoadFailed: root.path = ""
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "dynamic-you-live"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region {}

            readonly property bool shouldPlay: {
                const monitors = Hyprland.monitors.values;
                for (let i = 0; i < monitors.length; i++) {
                    if (monitors[i].name === modelData.name)
                        return !(monitors[i].activeWorkspace?.hasFullscreen ?? false);
                }
                return true;
            }

            MediaPlayer {
                id: player
                source: root.path ? ("file://" + encodeURI(root.path).replace(/#/g, "%23").replace(/\?/g, "%3F")) : ""
                loops: MediaPlayer.Infinite
                videoOutput: output
                audioOutput: AudioOutput { muted: true }
                onErrorOccurred: (code, message) => console.warn("Live wallpaper:", message)
                Component.onCompleted: if (root.path && win.shouldPlay) play()
                onSourceChanged: if (root.path && win.shouldPlay) play()
            }

            Connections {
                target: win
                function onShouldPlayChanged() {
                    if (win.shouldPlay) player.play(); else player.pause();
                }
            }

            VideoOutput {
                id: output
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                opacity: player.hasVideo ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
