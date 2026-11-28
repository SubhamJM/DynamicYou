import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root
    property string path: ""
    property var occupiedMonitors: ({})
    readonly property string statePath: Quickshell.env("HOME") + "/.config/active-theme/current-wallpaper.txt"

    function scheduleWindowProbe() {
        probeDebounce.restart();
    }

    Timer {
        id: probeDebounce
        interval: 40
        repeat: false
        onTriggered: {
            if (!windowStateProc.running) windowStateProc.running = true;
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!windowStateProc.running) windowStateProc.running = true
    }

    Process {
        id: windowStateProc
        running: false
        command: [
            "sh", "-c",
            "hyprctl monitors -j 2>/dev/null; printf '\\n\\x1e\\n'; hyprctl workspaces -j 2>/dev/null; printf '\\n\\x1e\\n'; hyprctl clients -j 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = String(this.text || "").split("\x1e");
                    if (parts.length < 3) return;
                    const monitors = JSON.parse(parts[0] || "[]");
                    const workspaces = JSON.parse(parts[1] || "[]");
                    const clients = JSON.parse(parts[2] || "[]");

                    const wsCountById = {};
                    for (let i = 0; i < workspaces.length; i++) {
                        const w = workspaces[i];
                        if (w && w.id !== undefined) wsCountById[w.id] = Number(w.windows || 0);
                    }

                    const occ = {};
                    for (let i = 0; i < monitors.length; i++) {
                        const m = monitors[i];
                        if (!m || !m.name) continue;
                        const activeId = m.activeWorkspace ? m.activeWorkspace.id : null;
                        const specialName = m.specialWorkspace ? String(m.specialWorkspace.name || "") : "";
                        let hasWin = (activeId !== null && (wsCountById[activeId] || 0) > 0);
                        if (!hasWin) {
                            for (let j = 0; j < clients.length; j++) {
                                const c = clients[j];
                                if (!c || c.hidden) continue;
                                if (activeId !== null && c.workspace && c.workspace.id === activeId) {
                                    hasWin = true;
                                    break;
                                }
                                if (specialName !== "" && c.workspace && c.workspace.name === specialName) {
                                    hasWin = true;
                                    break;
                                }
                            }
                        }
                        occ[m.name] = hasWin;
                    }
                    root.occupiedMonitors = occ;
                } catch (e) {
                    // Preserve previous occupancy state on transient JSON hiccup
                }
            }
        }
    }

    Connections {
        target: typeof Hyprland !== "undefined" ? Hyprland : null
        function onRawEvent(event) {
            const ev = (typeof event === "object" && event !== null) ? String(event.name || "") : String(event || "");
            if (ev === "workspace" || ev === "workspacev2" || ev === "focusedmon"
                || ev === "activespecial" || ev === "activespecialv2"
                || ev === "openwindow" || ev === "closewindow"
                || ev === "movewindow" || ev === "movewindowv2"
                || ev === "fullscreen" || ev === "minimize") {
                root.scheduleWindowProbe();
            }
        }
    }

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

            readonly property bool hasMonitorWindow: {
                const monName = String(modelData.name || "");
                if (root.occupiedMonitors[monName] !== undefined) {
                    return !!root.occupiedMonitors[monName];
                }
                const monitors = Hyprland.monitors.values;
                for (let i = 0; i < monitors.length; i++) {
                    if (monitors[i].name === monName) {
                        const ws = monitors[i].activeWorkspace;
                        if (ws && ws.hasFullscreen) return true;
                        if (ws && ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0) return true;
                        return false;
                    }
                }
                return false;
            }
            readonly property bool shouldPlay: !win.hasMonitorWindow && root.path !== ""

            MediaPlayer {
                id: player
                source: root.path ? ("file://" + encodeURI(root.path).replace(/#/g, "%23").replace(/\?/g, "%3F")) : ""
                loops: MediaPlayer.Infinite
                videoOutput: output
                audioOutput: AudioOutput { muted: true }
                onErrorOccurred: (code, message) => console.warn("Live wallpaper:", message)
                Component.onCompleted: {
                    if (win.shouldPlay) player.play();
                    else player.pause();
                }
                onSourceChanged: {
                    if (win.shouldPlay) player.play();
                    else player.pause();
                }
            }

            Connections {
                target: win
                function onShouldPlayChanged() {
                    if (win.shouldPlay) player.play();
                    else player.pause();
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
