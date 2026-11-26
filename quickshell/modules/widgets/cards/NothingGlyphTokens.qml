import QtQuick
import "../../../"
import "../"

// Shared Nothing OS Glyph visual tokens, fonts, and color palette
QtObject {
    id: root

    property string accentMode: "glyph" // "glyph" (Nothing Red #D71921) | "shell" (Theme accent)
    property bool lightMode: false

    readonly property FontLoader dotLoader: FontLoader {
        source: Qt.resolvedUrl("../fonts/Doto[ROND,wght].ttf")
    }
    readonly property FontLoader monoLoader: FontLoader {
        source: Qt.resolvedUrl("../fonts/SpaceMono-Regular.ttf")
    }
    readonly property FontLoader monoBoldLoader: FontLoader {
        source: Qt.resolvedUrl("../fonts/SpaceMono-Bold.ttf")
    }
    readonly property FontLoader uiLoader: FontLoader {
        source: Qt.resolvedUrl("../fonts/SpaceGrotesk-Regular.otf")
    }

    readonly property string dotFont: dotLoader.name || "Doto"
    readonly property string monoFont: monoLoader.name || "Space Mono"
    readonly property string uiFont: uiLoader.name || "Space Grotesk"

    readonly property color nothingRed: "#D71921"
    readonly property color bg: "#060606"
    readonly property color s1: "#0E0E0E"
    readonly property color s2: "#191919"
    readonly property color s3: "#2A2A2A"
    readonly property color mute: "#505050"
    readonly property color grey: "#8E8E8E"
    readonly property color fg: "#F2F2F2"
    readonly property color border: "#252525"

    readonly property color shellAccent: Theme.m3.primary ?? Theme.accent
    readonly property color accent: accentMode === "shell" ? shellAccent : nothingRed
    readonly property color onAccent: {
        const c = Qt.color(accent);
        const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return lum > 0.45 ? "#0B0B0D" : "#FFFFFF";
    }
    readonly property color alertRed: nothingRed

    function corner(px) {
        return WidgetStore.s(px);
    }
}
