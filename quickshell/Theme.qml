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

    function _rebuildColors() {
        var activeAcc = (theme.mediaAccent !== "") ? theme.mediaAccent : theme.baseAccent;
        theme.colors = {
            "bg": "#000000",
            "card_bg": "#0e0e12",
            "hover_bg": "#18181c",
            "border": "transparent",
            "border_hover": "transparent",
            "text_primary": "#f8fafc",
            "text_secondary": "#94a3b8",
            "text_muted": "#64748b",
            "accent": activeAcc,
            "error": "#f87171",
            "warning": "#fbbf24"
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

    property string currentThemeName: "default"
    property string activeTransition: "simple"

    signal themeReloaded()

    function reload() {
        if (themeLoader.running) themeLoader.running = false;
        themeLoader.running = true;
        
        if (themeNameLoader.running) themeNameLoader.running = false;
        themeNameLoader.running = true;

        if (transitionLoader.running) transitionLoader.running = false;
        transitionLoader.running = true;
    }

    Component.onCompleted: theme.reload()

    property Timer pollTimer: Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: theme.reload()
    }

    property Process themeLoader: Process {
        running: false
        command: ["sh", "-c", "cat $HOME/.config/active-theme/quickshell-colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    var parsed = JSON.parse(this.text);
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
                if (name !== "") theme.currentThemeName = name;
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
