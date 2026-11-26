pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtMultimedia
import Quickshell
import qs

Item {
    id: root

    required property var context
    property bool editing: false
    property string screenName: ""
    property bool leaving: false
    property bool recordingActive: false

    readonly property int recedeDuration: 280
    readonly property int settleDuration: 420
    readonly property bool sceneReady: !root.painted || wallpaper.status === Image.Ready || wallpaper.status === Image.Error

    property real presence: 0
    readonly property real arrival: Math.max(0, Math.min(1, (presence - 0.20) / 0.75))
    readonly property int presenceTarget: root.leaving || !(root.sceneReady || sceneTimeout.fired) ? 0 : 1

    Behavior on presence {
        NumberAnimation {
            duration: root.presenceTarget > 0 ? root.settleDuration : root.recedeDuration
            easing.type: root.presenceTarget > 0 ? Easing.OutCubic : Easing.InCubic
        }
    }

    Timer { id: sceneTimeout; property bool fired: false; interval: 350; running: true; onTriggered: fired = true }

    Component.onCompleted: {
        LockConfig.refreshEnvironment();
        root.presence = Qt.binding(() => root.presenceTarget);
        root.focusPassword();
    }

    property alias peeking: stage.peeking
    readonly property string selected: stage.selected
    readonly property rect selectedRect: stage.selectedRect
    focus: true

    readonly property var scene: {
        LockConfig.revision;
        return LockConfig.scene;
    }
    readonly property string sourceMode: String(root.scene?.source ?? "desktop")
    readonly property string wallpaperPath: {
        const custom = String(root.scene?.path ?? "").trim();
        if (root.sourceMode === "custom" && custom.length > 0) return custom;
        return LockConfig.desktopWallpaper;
    }
    readonly property bool videoWallpaper: /\.(mp4|webm|mkv|mov)$/i.test(root.wallpaperPath)
    readonly property bool gifWallpaper: /\.gif$/i.test(root.wallpaperPath)
    readonly property string wallpaperSource: {
        const p = root.wallpaperPath;
        if (!p) return "";
        return (p.startsWith("file://") || p.startsWith("/")) ? (p.startsWith("file://") ? p : "file://" + p) : p;
    }

    readonly property int fillMode: String(root.scene?.fit ?? "cover") === "contain"
        ? Image.PreserveAspectFit : Image.PreserveAspectCrop
    readonly property real vignette: Math.max(0, Math.min(1, Number(root.scene?.vignette ?? 26) / 100))
    readonly property real blur: Math.max(0, Math.min(1, Number(root.scene?.blur ?? 88) / 100))
    readonly property real dim: Math.max(0, Math.min(1, Number(root.scene?.dim ?? 8) / 100))
    readonly property real colourLeft: Math.max(0, Math.min(1, Number(root.scene?.saturation ?? 18) / 100))
    readonly property real scrimStrength: Math.max(0, Math.min(2, Number(root.scene?.scrimStrength ?? 100) / 100))
    readonly property string scrimStyle: String(root.scene?.scrim ?? "gradient")
    readonly property bool painted: root.sourceMode !== "colour" && root.wallpaperSource !== ""
    readonly property bool drifts: root.painted && String(root.scene?.motion ?? "none") === "drift"
    readonly property int driftMs: Math.max(4000, Math.round(Number(root.scene?.driftTime ?? 40) * 1000))
    readonly property bool blurEnabled: root.painted && root.blur > 0.01
    readonly property bool frosted: root.painted && LockConfig.material === "glass"
    readonly property bool animates: root.painted && Boolean(LockConfig.data?.enableAnimation ?? true)
    readonly property bool playsVideo: root.animates && root.videoWallpaper
    readonly property bool playsGif: root.animates && root.gifWallpaper

    function focusPassword(): void {
        if (root.editing) return;
        Qt.callLater(() => {
            if (stage.input) stage.input.forceActiveFocus();
        });
    }

    function submit(): void {
        if (root.editing) return;
        if (root.context.currentText.length > 0 && !root.context.unlockInProgress) {
            root.context.tryUnlock();
        }
    }

    Connections {
        target: root.context
        function onShouldReFocus(): void { root.focusPassword(); }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && !root.editing) {
            root.context.clearText();
            event.accepted = true;
            return;
        }
        if (!root.editing || stage.selected.length === 0) return;
        const step = (event.modifiers & Qt.ShiftModifier) ? 0.02 : 0.004;
        if (event.key === Qt.Key_Left) { LockConfig.nudge(stage.selected, -step, 0); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { LockConfig.nudge(stage.selected, step, 0); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { LockConfig.nudge(stage.selected, 0, -step); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { LockConfig.nudge(stage.selected, 0, step); event.accepted = true; }
    }

    // Solid guaranteed-opaque base behind scenery (never leak desktop behind lockscreen)
    Rectangle {
        anchors.fill: parent
        color: "#0b0b10"
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.editing
        onClicked: root.focusPassword()
    }

    // Unified Background Scenery Item
    Item {
        id: scenery
        anchors.fill: parent
        visible: root.painted && !root.blurEnabled
        layer.enabled: root.blurEnabled
        transform: [
            Scale {
                id: driftScale
                origin.x: root.width / 2
                origin.y: root.height / 2
                xScale: root.blurEnabled ? 1 + 0.05 * root.presence : 1
                yScale: driftScale.xScale
            },
            Translate { id: driftShift }
        ]

        Image {
            id: wallpaper
            anchors.fill: parent
            visible: !root.playsVideo && !root.playsGif
            source: root.painted && !root.playsVideo && !root.playsGif ? root.wallpaperSource : ""
            sourceSize: Qt.size(Math.max(1, root.width), Math.max(1, root.height))
            fillMode: root.fillMode
            asynchronous: false
            cache: false
        }

        Loader {
            anchors.fill: parent
            active: root.playsGif
            sourceComponent: AnimatedImage {
                source: root.wallpaperSource
                fillMode: root.fillMode
                cache: false
                playing: true
            }
        }

        Loader {
            anchors.fill: parent
            active: root.playsVideo
            sourceComponent: Video {
                source: root.wallpaperSource
                fillMode: root.fillMode === Image.PreserveAspectFit ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop
                loops: MediaPlayer.Infinite
                muted: true
                autoPlay: true
            }
        }
    }

    SequentialAnimation {
        running: root.drifts
        loops: Animation.Infinite
        ParallelAnimation {
            NumberAnimation { target: driftScale; properties: "xScale"; to: 1.11; duration: root.driftMs; easing.type: Easing.InOutSine }
            NumberAnimation { target: driftShift; property: "x"; to: -18; duration: root.driftMs; easing.type: Easing.InOutSine }
            NumberAnimation { target: driftShift; property: "y"; to: -12; duration: root.driftMs; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: driftScale; properties: "xScale"; to: root.blurEnabled ? 1 + 0.05 * root.presence : 1; duration: root.driftMs; easing.type: Easing.InOutSine }
            NumberAnimation { target: driftShift; property: "x"; to: 0; duration: root.driftMs; easing.type: Easing.InOutSine }
            NumberAnimation { target: driftShift; property: "y"; to: 0; duration: root.driftMs; easing.type: Easing.InOutSine }
        }
    }

    // Blurred & Desaturated Scenery Backdrop
    MultiEffect {
        anchors.fill: parent
        visible: root.blurEnabled
        autoPaddingEnabled: false
        source: scenery
        blurEnabled: true
        blur: root.presence
        blurMax: Math.round(48 * root.blur)
        saturation: (root.colourLeft - 1) * root.presence
    }

    // Scrim, Vignette & Dim Layers
    Item {
        anchors.fill: parent
        opacity: root.presence

        Rectangle {
            anchors.fill: parent
            visible: root.scrimStyle === "gradient"
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, Math.min(1, 0.28 * root.scrimStrength)) }
                GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, Math.min(1, 0.12 * root.scrimStrength)) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, Math.min(1, 0.42 * root.scrimStrength)) }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.scrimStyle === "flat"
            color: Qt.rgba(0, 0, 0, Math.min(1, 0.32 * root.scrimStrength))
        }

        Loader {
            anchors.fill: parent
            active: root.vignette > 0.001
            sourceComponent: Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: root.width / 2
                        centerY: root.height / 2
                        centerRadius: Math.max(root.width, root.height) * 0.72
                        focalX: root.width / 2
                        focalY: root.height / 2
                        focalRadius: 0
                        GradientStop { position: 0.4; color: "transparent" }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, root.vignette) }
                    }
                    startX: 0; startY: 0
                    PathLine { x: root.width; y: 0 }
                    PathLine { x: root.width; y: root.height }
                    PathLine { x: 0; y: root.height }
                    PathLine { x: 0; y: 0 }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.dim > 0.001
            color: Qt.rgba(0, 0, 0, root.dim)
        }
    }

    // Shared Frosted Texture (sampled by every glass cutout block on stage)
    ShaderEffectSource {
        id: sceneTexture
        anchors.fill: parent
        visible: false
        sourceItem: root.frosted ? scenery : null
        hideSource: false
        live: true
    }

    Item {
        id: frost
        anchors.fill: parent
        visible: false
        layer.enabled: root.frosted

        MultiEffect {
            anchors.fill: parent
            visible: root.frosted
            autoPaddingEnabled: false
            source: sceneTexture
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: (root.colourLeft - 1) * root.presence + 0.35 * root.colourLeft
        }
    }

    // Stage Blocks & Sign-in Layer
    IrisLockStage {
        id: stage
        anchors.fill: parent
        opacity: root.arrival
        transform: Translate { y: Math.round((1 - root.arrival) * 24) }
        frost: root.frosted ? frost : null
        context: root.context
        editing: root.editing
        recordingActive: root.recordingActive
        onSubmitted: root.submit()
    }
}
