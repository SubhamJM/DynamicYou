pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: root

    property bool recordingActive: false
    property bool receding: false
    property int recedeDuration: 280

    function lock(): void {
        LockConfig.editing = false;
        rehearsal.previewActive = false;
        LockConfig.refreshEnvironment();
        lockContext.reset();
        recedeRelease.stop();
        root.receding = false;
        LockConfig.locked = true;
    }

    function openEditor(): void {
        LockConfig.refreshEnvironment();
        LockConfig.editing = true;
    }

    function togglePreview(open: bool): void {
        LockConfig.refreshEnvironment();
        rehearsal.previewActive = open;
    }

    IrisLockContext {
        id: lockContext

        onUnlocked: {
            root.receding = true;
            recedeRelease.restart();
        }
    }

    Timer {
        id: recedeRelease
        interval: root.recedeDuration + 40
        repeat: false
        onTriggered: {
            LockConfig.locked = false;
            root.receding = false;
            lockContext.reset();
            Quickshell.execDetached(["bash", "-lc", "sleep 0.15; hyprctl dispatch dpms on >/dev/null 2>&1 || true"]);
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: LockConfig.locked

        WlSessionLockSurface {
            id: lockSurface
            color: "#0b0b10"

            Loader {
                id: surfaceLoader
                active: LockConfig.locked
                asynchronous: false
                anchors.fill: parent
                sourceComponent: IrisLockSurface {
                    context: lockContext
                    editing: false
                    screenName: lockSurface.screen?.name ?? ""
                    leaving: root.receding
                    recordingActive: root.recordingActive
                }

                onLoaded: {
                    if (item) {
                        root.recedeDuration = item.recedeDuration;
                        item.forceActiveFocus();
                    }
                }
            }
        }
    }

    IrisLockRehearsal {
        id: rehearsal
        recordingActive: root.recordingActive
    }
}
