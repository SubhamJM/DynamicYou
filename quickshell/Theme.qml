pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

QtObject {
    id: theme

    property string baseAccent: "#7aa2f7"
    property string mediaAccent: ""
    property string currentArtSource: ""

    readonly property color accent: (theme.mediaAccent !== "") ? theme.mediaAccent : theme.baseAccent

    function setMediaAccent(colorStr) {
        var next = (colorStr || "").trim();
        if (theme.mediaAccent !== next) {
            theme.mediaAccent = next;
            theme._rebuildColors();
        }
    }

    property var rawThemeColors: ({})

    function _rebuildColors() {
        var activeAcc = (theme.mediaAccent !== "") ? theme.mediaAccent : theme.baseAccent;
        var raw = theme.rawThemeColors || {};
        theme.colors = {
            "bg": "#000000",
            "card_bg": "#0e0e12",
            "hover_bg": "#18181c",
            "border": "transparent",
            "border_hover": (theme.mediaAccent !== "") ? theme.mediaAccent : (raw.border_hover || activeAcc),
            "text_primary": raw.text_primary || "#f8fafc",
            "text_secondary": raw.text_secondary || "#94a3b8",
            "text_muted": raw.text_muted || "#64748b",
            "accent": activeAcc,
            "error": raw.error || "#f87171",
            "warning": raw.warning || "#fbbf24"
        };
        theme.themeReloaded();
    }

    // Dynamic Artwork Color Quantizer for whole shell synchronization
    property var artQuantizer: ColorQuantizer {
        id: themeQuantizer
        source: theme.currentArtSource
        depth: 3
        rescaleSize: 48
        onColorsChanged: {
            if (theme.currentArtSource !== "" && colors && colors.length > 0) {
                let best = null;
                let bestScore = -1;
                for (let i = 0; i < colors.length; i++) {
                    const c = colors[i];
                    const score = Math.max(0, c.hslSaturation) * (1 - Math.abs(c.hslLightness - 0.5));
                    if (score > bestScore) { bestScore = score; best = c; }
                }
                if (best && best.hslSaturation >= 0.12 && best.hslHue >= 0) {
                    const extracted = Qt.hsla(best.hslHue, Math.max(0.48, best.hslSaturation),
                        Math.max(0.64, Math.min(0.78, best.hslLightness + 0.20)), 1);
                    theme.setMediaAccent(extracted.toString());
                    return;
                }
            }
            theme.setMediaAccent("");
        }
    }

    // Neutral OLED Deep Black Palette (Pure dark neutrals with dynamic reactive accent)
    property var colors: ({
        "bg": "#000000",
        "card_bg": "#0e0e12",
        "hover_bg": "#18181c",
        "border": "transparent",
        "border_hover": "transparent",
        "text_primary": "#f8fafc",
        "text_secondary": "#94a3b8",
        "text_muted": "#64748b",
        "accent": "#7aa2f7",
        "error": "#f87171",
        "warning": "#fbbf24"
    })

    // --- Modular Design & Icon Tokens (Inspired by Matushell) ---
    readonly property string fontFamilyIcon: "Material Symbols Rounded"
    readonly property string fontFamilyNerd: "JetBrainsMono Nerd Font"
    readonly property string fontFamilyBody: "Noto Sans"
    readonly property int fontIconGrad: -25

    // Standardized Icon Sizes
    readonly property int iconSizeXs: 14
    readonly property int iconSizeSm: 16
    readonly property int iconSize: 18
    readonly property int iconSizeMd: 20
    readonly property int iconSizeLg: 22
    readonly property int iconSizeXl: 26
    readonly property int iconSizeDisplay: 32

    // Standardized Button Dimensions
    readonly property int iconBtnSizeXs: 24
    readonly property int iconBtnSizeSm: 28
    readonly property int iconBtnSize: 34
    readonly property int iconBtnSizeLg: 40
    readonly property int iconBtnSizeXl: 48

    // Standardized Motion / Animation Durations
    readonly property int animFast: 100
    readonly property int animNormal: 180
    readonly property int animSlow: 280

    // --- Matushell Motion Curves (BezierSpline) ---
    readonly property var curveFastSpatial: [0.27, 1.06, 0.18, 1, 1, 1]
    readonly property var curveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var curveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var curveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var curveEmphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var curveGlide: [0.37, 0, 0.63, 1, 1, 1]

    property string currentThemeName: "default"
    property string activeTransition: "simple"

    signal themeReloaded()

    function reload() {
        themeLoader.running = false;
        themeNameLoader.running = false;
        transitionLoader.running = false;
        Qt.callLater(() => {
            themeLoader.running = true;
            themeNameLoader.running = true;
            transitionLoader.running = true;
        });
    }

    Component.onCompleted: theme.reload()

    property Process themeLoader: Process {
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/quickshell-colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var parsed = JSON.parse(this.text);
                    theme.rawThemeColors = parsed;
                    var acc = parsed.accent || "#7aa2f7";
                    theme.baseAccent = acc;
                    theme._rebuildColors();
                } catch(e) {
                    console.warn("[Quickshell Theme] Failed to parse JSON:", e);
                }
            }
        }
    }

    property Process themeNameLoader: Process {
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/theme-name.txt 2>/dev/null || echo 'default'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var name = this.text.trim();
                if (name !== "") {
                    theme.currentThemeName = name;
                    theme.themeReloaded();
                }
            }
        }
    }

    property Process transitionLoader: Process {
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/wallpaper-transition.txt 2>/dev/null || echo 'simple'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var trans = this.text.trim();
                if (trans !== "") theme.activeTransition = trans;
            }
        }
    }
}
