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

    readonly property color accent: theme.baseAccent
    readonly property color onAccent: (accent.r * 0.2126 + accent.g * 0.7152 + accent.b * 0.0722) > 0.52 ? "#101014" : "#ffffff"

    function setMediaAccent(colorStr) {
        var next = (colorStr || "").trim();
        if (theme.mediaAccent !== next) {
            theme.mediaAccent = next;
        }
    }

    property var rawThemeColors: ({})
    function _rebuildColors() {
        var activeAcc = theme.accent;
        var raw = theme.rawThemeColors || {};
        theme.colors = {
            "bg": raw.bg || "#030a16",
            "card_bg": raw.card_bg || "#1c1b1f",
            "hover_bg": raw.hover_bg || "#2b2930",
            "border": "transparent",
            "border_hover": raw.border_hover || activeAcc,
            "text_primary": raw.text_primary || "#f0dfd7",
            "text_secondary": raw.text_secondary || "#d7c2b8",
            "text_muted": raw.text_muted || "#9f8d84",
            "accent": activeAcc,
            "accent_secondary": raw.border || activeAcc,
            "error": raw.error || "#ffb4ab",
            "warning": raw.warning || "#fbbf24"
        };
        theme.themeReloaded();
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
        "accent_secondary": "#ffb68b",
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

    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property string activeThemeDir: configDir + "/active-theme"
    readonly property bool presetApplying: presetApplyProcess.running
    property string currentThemeName: "default"
    property string activeTransition: "simple"

    signal themeReloaded()
    signal presetApplyFinished(bool success)

    function applyPreset(name) {
        if (!name || presetApplying) return;
        presetApplyProcess.command = ["bash", configDir + "/hypr/scripts/apply-theme.sh", name];
        presetApplyProcess.running = true;
    }

    // The apply keeps running if the notch closes or switches panels.
    property Process presetApplyProcess: Process {
        onExited: (code, status) => {
            const success = code === 0 && status === 0;
            if (success) theme.reload();
            theme.presetApplyFinished(success);
        }
    }

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
        command: ["cat", theme.activeThemeDir + "/quickshell-colors.json"]
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
        command: ["cat", theme.activeThemeDir + "/theme-name.txt"]
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
        command: ["cat", theme.activeThemeDir + "/wallpaper-transition.txt"]
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
    function alpha(c, a) {
        if (!c) return Qt.rgba(1, 1, 1, a !== undefined ? a : 1);
        if (typeof c === "string") {
            var col = Qt.color(c);
            return Qt.rgba(col.r, col.g, col.b, a !== undefined ? a : 1);
        }
        return Qt.rgba(c.r !== undefined ? c.r : 1, c.g !== undefined ? c.g : 1, c.b !== undefined ? c.b : 1, a !== undefined ? a : 1);
    }
    function withBlur(c) { return c; }
    function barType(role) { return typeSize(role); }
    function fs(px) { return dp(px); }
    function barDp(px) { return dp(px); }
    function barFs(px) { return dp(px); }
    function barMs(d) { return ms(d); }

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
    readonly property color fgAccent: theme.onAccent
    readonly property color text: theme.colors.text_primary
    readonly property color subtext: theme.colors.text_secondary
    readonly property color subtextDim: theme.colors.text_muted
    readonly property color primary: theme.colors.accent
    readonly property color fgPrimary: theme.onAccent
    readonly property color primaryContainer: theme.colors.accent_secondary
    readonly property color fgPrimaryContainer: theme.colors.text_primary
    readonly property color secondary: theme.colors.accent
    readonly property color fgSecondary: theme.onAccent
    readonly property color secondaryContainer: theme.colors.card_bg
    readonly property color fgSecondaryContainer: theme.colors.text_primary
    readonly property color tertiary: theme.colors.accent
    readonly property color tertiaryContainer: theme.colors.hover_bg
    readonly property color fgTertiaryContainer: theme.colors.text_primary
    readonly property color surfaceHigh: theme.colors.card_bg
    readonly property color surfaceHighest: theme.colors.hover_bg
    readonly property color outline: theme.rawThemeColors.border || (Qt.rgba(255, 255, 255, 0.12))
    readonly property color outlineStrong: theme.rawThemeColors.border_hover || theme.accent
    readonly property color divider: theme.rawThemeColors.border || (Qt.rgba(255, 255, 255, 0.12))
    readonly property color success: theme.colors.green || "#50fa7b"
    readonly property color error: theme.colors.error
    readonly property color errorContainer: Qt.rgba(0.4, 0.12, 0.14, 1)
    readonly property color fgErrorContainer: theme.colors.error
    readonly property real disabledContainer: 0.12
    readonly property real disabledContent: 0.38
    readonly property color inverseSurface: theme.colors.text_primary
    readonly property color fgInverseSurface: theme.colors.bg

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
    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]

    readonly property real motionScale: 1
    readonly property real uiScale: 1.0
    readonly property real jelly: 1

    readonly property real stateHover: 0.08
    readonly property real statePressed: 0.16
    readonly property string fontFamily: "Noto Sans"
}
