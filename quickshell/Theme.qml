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
            "card_bg": raw.card_bg || "#1c1b1f",
            "hover_bg": raw.hover_bg || "#2b2930",
            "border": "transparent",
            "border_hover": "transparent",
            "text_primary": raw.text_primary || "#f0dfd7",
            "text_secondary": raw.text_secondary || "#d7c2b8",
            "text_muted": raw.text_muted || "#9f8d84",
            "accent": activeAcc,
            "error": raw.error || "#ffb4ab",
            "warning": raw.warning || "#fbbf24"
        };
        theme.themeReloaded();
    }

    // Dynamic Artwork Color Quantizer for whole shell synchronization
    property var artQuantizer: ColorQuantizer {
        id: themeQuantizer
        source: (theme.currentArtSource && !theme.currentArtSource.startsWith("http")) ? theme.currentArtSource : ""
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

    // Material 3 Palette with clean borderless surfaces and reactive accent
    property var colors: ({
        "bg": "#000000",
        "card_bg": "#1c1b1f",
        "hover_bg": "#2b2930",
        "border": "transparent",
        "border_hover": "transparent",
        "text_primary": "#f0dfd7",
        "text_secondary": "#d7c2b8",
        "text_muted": "#9f8d84",
        "accent": "#ffb68b",
        "error": "#ffb4ab",
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

    // ==========================================
    // Lucid / Material 3 Design Token Compatibility
    // ==========================================
    function dp(px) { return px; }
    function rad(r) { return r; }
    function pill(h) { return h / 2; }
    function ms(t) { return t; }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function withBlur(c) { return c; }

    function typeSize(role) {
        switch (role) {
            case "displayLarge": return 57;
            case "displayMedium": return 45;
            case "displaySmall": return 36;
            case "headlineLarge": return 32;
            case "headlineMedium": return 28;
            case "headlineSmall": return 24;
            case "titleLarge": return 18;
            case "titleMedium": return 15;
            case "titleSmall": return 13;
            case "bodyLarge": return 15;
            case "bodyMedium": return 12;
            case "bodySmall": return 11;
            case "labelLarge": return 13;
            case "labelMedium": return 11;
            case "labelSmall": return 10;
            default: return 12;
        }
    }

    function typeWeight(role) {
        if (!role) return 400;
        if (role.indexOf("title") === 0 || role.indexOf("headline") === 0) return 560;
        if (role.indexOf("label") === 0) return 500;
        return 400;
    }

    function typeRound(role) { return 0; }
    function axes(s, w, r) { return ({ "wght": w || 400, "opsz": s || 12 }); }

    readonly property color bg: theme.colors.bg
    readonly property color bgTile: theme.colors.card_bg
    readonly property color fgAccent: "#ffffff"
    readonly property color text: theme.colors.text_primary
    readonly property color subtext: theme.colors.text_secondary
    readonly property color subtextDim: theme.colors.text_muted
    readonly property color primary: theme.colors.accent
    readonly property color fgPrimary: "#101014"
    readonly property color secondary: theme.colors.accent
    readonly property color fgSecondary: "#101014"
    readonly property color secondaryContainer: Qt.rgba(255, 255, 255, 0.08)
    readonly property color fgSecondaryContainer: "#ffffff"
    readonly property color tertiary: theme.colors.accent
    readonly property color surfaceHigh: theme.colors.card_bg
    readonly property color surfaceHighest: theme.colors.hover_bg
    readonly property color outline: Qt.rgba(255, 255, 255, 0.12)
    readonly property color outlineStrong: Qt.rgba(255, 255, 255, 0.20)
    readonly property color error: theme.colors.error
    readonly property real disabledContainer: 0.12
    readonly property real disabledContent: 0.38
    readonly property color inverseSurface: "#f8fafc"
    readonly property color fgInverseSurface: "#101014"

    readonly property int shapeFull: 9999
    readonly property int shapeXlInc: 24
    readonly property int shapeXl: 20
    readonly property int shapeLgInc: 18
    readonly property int shapeLg: 16
    readonly property int shapeMd: 12
    readonly property int shapeSm: 8

    readonly property int durQuick: 120
    readonly property int durShort: 140
    readonly property int durMedium: 240
    readonly property int durLong: 350
    readonly property int durEnter: 260
    readonly property int durExit: 180
    readonly property int durFastEffects: 110
    readonly property int durDefaultEffects: 180
    readonly property int durSlowEffects: 260
    readonly property int durFastSpatial: 140
    readonly property int durDefaultSpatial: 240
    readonly property int durSlowSpatial: 380
    readonly property var curveEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var easeEmphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]

    readonly property real motionScale: 1
    readonly property real uiScale: 1.0
    readonly property real jelly: 1

    readonly property real stateHover: 0.08
    readonly property real statePressed: 0.16
    readonly property string fontFamily: "Noto Sans"
}
