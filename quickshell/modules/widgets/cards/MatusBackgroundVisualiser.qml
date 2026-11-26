import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../../../"
import "../../../services"
import "../../"
import "../"

// Matushell GPU-shader Audio Visualiser (cava.frag.qsb + 1px grayscale texture pipeline)
// Works fullscreen along desktop bottom (when onDesktop) AND renders a live wave preview in the Widget Shelf.
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "bgVisualiser"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string styleName: String(opts.visStyle || "wave_outlined") // "wave_outlined" | "wave" | "bars"
    readonly property string paletteName: String(opts.colorMode || "inverse")      // "inverse" | "primary" | "secondary" | "tertiary"
    readonly property int barCount: Math.max(16, Math.min(96, Number(opts.barCount || 60)))
    readonly property real gain: Math.max(0.2, Math.min(1.5, Number(opts.gain || 0.55)))
    readonly property real barRounding: Math.max(0, Math.min(24, Number(opts.rounding !== undefined ? opts.rounding : 6)))
    readonly property real barSpacing: Math.max(0, Math.min(20, Number(opts.spacing !== undefined ? opts.spacing : 4)))
    readonly property real heightScale: Math.max(0.22, Math.min(0.80, Number(opts.heightScale !== undefined ? opts.heightScale : 0.42)))
    readonly property real edgeInset: Math.max(0, Math.min(160, Number(opts.edgeInset !== undefined ? opts.edgeInset : 0)))
    readonly property real visOpacity: Math.max(0.25, Math.min(1.0, Number(opts.visOpacity !== undefined ? opts.visOpacity : 0.70)))
    readonly property int targetFps: Math.max(15, Math.min(90, Number(opts.fps || 45)))
    readonly property bool alwaysVisible: opts.alwaysVisible === true

    readonly property bool mediaPlaying: (MprisController.activePlayer?.isPlaying ?? false)
        || (Mpris.players && Mpris.players.values.some(p => p && p.isPlaying === true))

    // Palette matching Matushell's Theming.visualiserPalette pairs
    readonly property color colorMain: {
        const p = Theme.m3.primary ?? Theme.accent;
        const s = Theme.m3.secondary ?? "#67e8f9";
        const t = Theme.m3.tertiary ?? p;
        const onS = Theme.m3.on_surface ?? "#f2f2f2";
        let base = p;
        if (paletteName === "inverse") base = onS;
        else if (paletteName === "secondary") base = s;
        else if (paletteName === "tertiary") base = t;
        return Qt.rgba(Qt.color(base).r, Qt.color(base).g, Qt.color(base).b, root.visOpacity);
    }

    readonly property color colorAlt: {
        const p = Theme.m3.primary ?? Theme.accent;
        const s = Theme.m3.secondary ?? "#67e8f9";
        const t = Theme.m3.tertiary ?? p;
        let alt = p;
        if (paletteName === "inverse") alt = p;
        else if (paletteName === "primary") alt = s;
        else if (paletteName === "secondary") alt = t;
        else if (paletteName === "tertiary") alt = p;
        return Qt.rgba(Qt.color(alt).r, Qt.color(alt).g, Qt.color(alt).b, root.visOpacity);
    }

    // Retain desktop MatusCava stream only while active on desktop
    property bool _cavaRetained: false
    readonly property bool shouldRetainCava: root.onDesktop && root.active && (root.mediaPlaying || root.alwaysVisible)

    function syncCava() {
        if (typeof MatusCava === "undefined") return;
        MatusCava.bars = root.barCount;
        MatusCava.fps = root.targetFps;
        if (root.shouldRetainCava && !root._cavaRetained) {
            root._cavaRetained = true;
            MatusCava.retain();
        } else if (!root.shouldRetainCava && root._cavaRetained) {
            root._cavaRetained = false;
            MatusCava.release();
        }
    }

    onShouldRetainCavaChanged: syncCava()
    onBarCountChanged: { if (typeof MatusCava !== "undefined" && root._cavaRetained) MatusCava.bars = root.barCount; }
    onTargetFpsChanged: { if (typeof MatusCava !== "undefined" && root._cavaRetained) MatusCava.fps = root.targetFps; }
    Component.onCompleted: syncCava()
    Component.onDestruction: {
        if (root._cavaRetained && typeof MatusCava !== "undefined") {
            root._cavaRetained = false;
            MatusCava.release();
        }
    }

    // Smooth wake/sleep fade identical to Matushell BackgroundVisualiser
    readonly property bool showWave: !root.onDesktop
        || root.alwaysVisible
        || !MatusCava.isSilent
        || root.mediaPlaying

    property real shaderOpacity: showWave ? 1.0 : 0.0
    Behavior on shaderOpacity {
        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
    }

    // Shelf preview synthetic gentle wave when not playing / in drawer preview
    property real demoPhase: 0
    FrameAnimation {
        running: root.active && (!root.onDesktop || (root.alwaysVisible && MatusCava.isSilent))
        onTriggered: {
            root.demoPhase += frameTime * 2.2;
            dataCanvas.requestPaint();
        }
    }

    // Shelf backdrop badge frame when previewed in Widget Deck
    Rectangle {
        visible: !root.onDesktop
        anchors.fill: parent
        radius: WidgetStore.s(20)
        color: Theme.m3.surface_container_lowest ?? "#0c0f16"

        RowLayout {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: WidgetStore.s(12) }
            spacing: WidgetStore.s(6)
            MaterialSymbol {
                text: "graphic_eq"
                iconSize: WidgetStore.si(15)
                color: Theme.m3.primary ?? Theme.accent
            }
            Text {
                Layout.fillWidth: true
                text: "Fullscreen Bottom Audio Wave"
                color: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(10.5)
                font.weight: Font.Medium
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
            Text {
                text: root.styleName === "wave_outlined" ? "Outlined" : (root.styleName === "wave" ? "Wave" : "Bars")
                color: Theme.m3.primary ?? Theme.accent
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(9.5)
                font.weight: Font.Bold
                renderType: Text.NativeRendering
            }
        }
    }

    // 1px tall grayscale CAVA data texture -> GPU ShaderEffectSource -> cava.frag.qsb
    Item {
        anchors.fill: parent
        opacity: root.shaderOpacity
        visible: opacity > 0.005

        Canvas {
            id: dataCanvas
            readonly property var greys: {
                const g = new Array(256);
                for (let i = 0; i < 256; i++) {
                    const f = i / 255;
                    g[i] = Qt.rgba(f, f, f, 1);
                }
                return g;
            }

            width: Math.max(1, root.onDesktop
                ? ((MatusCava.cavaData && MatusCava.cavaData.length > 0) ? MatusCava.cavaData.length : root.barCount)
                : 32)
            height: 1
            visible: false
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Cooperative

            property bool _silentCleared: false

            onPaint: {
                const ctx = getContext("2d");
                const g = dataCanvas.greys;
                const useDemo = !root.onDesktop || (root.alwaysVisible && MatusCava.isSilent);
                const w = dataCanvas.width;

                if (useDemo) {
                    _silentCleared = false;
                    const p = root.demoPhase;
                    for (let i = 0; i < w; i++) {
                        const x = i / Math.max(1, w - 1);
                        const env = Math.sin(x * Math.PI);
                        const h = env * (0.28 + 0.22 * Math.sin(x * 7.5 - p) + 0.14 * Math.cos(x * 13.0 + p * 1.4));
                        const v = Math.max(0, Math.min(255, Math.round(h * 255)));
                        ctx.fillStyle = g[v];
                        ctx.fillRect(i, 0, 1, 1);
                    }
                } else {
                    const bars = MatusCava.cavaData;
                    const n = bars ? bars.length : 0;
                    if (n === 0 || MatusCava.isSilent) {
                        if (_silentCleared) return;
                        _silentCleared = true;
                        ctx.fillStyle = g[0];
                        ctx.fillRect(0, 0, w, 1);
                    } else {
                        _silentCleared = false;
                        for (let i = 0; i < Math.min(w, n); i++) {
                            const b = (Number(bars[i]) || 0) * root.gain;
                            const v = b <= 0 ? 0 : (b >= 1 ? 255 : (b * 255) | 0);
                            ctx.fillStyle = g[v];
                            ctx.fillRect(i, 0, 1, 1);
                        }
                    }
                }
                dataTexSource.scheduleUpdate();
            }

            Component.onCompleted: requestPaint()

            Connections {
                target: MatusCava
                function onCavaDataChanged() {
                    if (root.onDesktop && (root.alwaysVisible || !MatusCava.isSilent || !dataCanvas._silentCleared)) {
                        dataCanvas.requestPaint();
                    }
                }
            }
        }

        ShaderEffectSource {
            id: dataTexSource
            sourceItem: dataCanvas
            hideSource: true
            smooth: false
            live: false
        }

        ShaderEffect {
            id: cavaShader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.onDesktop ? Math.max(1, Math.round(parent.height * Math.min(0.88, root.heightScale + 0.06))) : parent.height
            blending: true

            property variant dataTex: dataTexSource
            property real itemWidth: Math.max(1, width)
            property real itemHeight: Math.max(1, height)
            property int barCount: dataCanvas.width
            property int styleMode: root.styleName === "wave_outlined" ? 1 : (root.styleName === "wave" ? 2 : 0)
            property real inset: root.onDesktop ? WidgetStore.s(root.edgeInset) : WidgetStore.s(Math.min(16, root.edgeInset))
            property real amplitudeScale: root.onDesktop ? (root.heightScale * parent.height / Math.max(1, height)) : 0.72
            property real rounding: WidgetStore.s(root.barRounding)
            property real spacing: WidgetStore.s(root.barSpacing)
            property color colorMain: root.colorMain
            property color colorAlt: root.colorAlt

            fragmentShader: Qt.resolvedUrl("shaders/cava.frag.qsb")
        }
    }
}
