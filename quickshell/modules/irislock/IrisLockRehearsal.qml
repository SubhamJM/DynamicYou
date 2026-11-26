pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property bool previewActive: false
    property bool recordingActive: false

    component RehearsalContext: QtObject {
        signal shouldReFocus()
        signal unlocked()
        signal failed()
        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false
        property bool fingerprintsConfigured: false
        function clearText(): void { currentText = ""; }
        function tryUnlock(): void {}
    }

    RehearsalContext { id: rehearsalContext }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property ShellScreen modelData
            screen: modelData
            visible: LockConfig.editing || root.previewActive
            color: "#0b0b10"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:iris-lock-rehearsal"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors { left: true; right: true; top: true; bottom: true }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (LockConfig.selection.length > 0) LockConfig.selection = "";
                    else {
                        LockConfig.editing = false;
                        root.previewActive = false;
                    }
                }
            }

            IrisLockSurface {
                id: surface
                anchors.fill: parent
                context: rehearsalContext
                editing: LockConfig.editing
                screenName: window.modelData?.name ?? ""
                recordingActive: root.recordingActive
            }

            IrisLockInspector {
                id: inspector
                visible: LockConfig.editing
                z: 20
                anchors.fill: parent
                avoid: surface.selectedRect
            }

            Binding {
                target: surface
                property: "peeking"
                value: inspector.peeking
            }
        }
    }
}
