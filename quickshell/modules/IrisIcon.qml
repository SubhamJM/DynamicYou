import QtQuick
import Quickshell
import Quickshell.Widgets
import "../"

// Universal modular icon element inspired by Matushell & DMS
// Seamlessly renders:
// 1. Variable-font Material Symbols with optical sizing & dark OLED grade compensation
// 2. JetBrainsMono Nerd Font glyphs
// 3. Desktop application icon theme assets with IconImage
// 4. Local image paths & URLs with graceful fallback symbol handling via IconResolver
Item {
    id: root

    // --- Public API ---
    property string icon: ""               // Material symbol, app name, file path, or nerd glyph
    property bool isApp: false             // Explicitly treat as desktop application icon
    property real iconSize: (typeof Theme !== "undefined" && Theme.iconSize) ? Theme.iconSize : 18
    property real fill: 0                  // 0 = outlined, 1 = filled
    property int grad: (typeof Theme !== "undefined" && Theme.fontIconGrad !== undefined) ? Theme.fontIconGrad : -25
    property color color: (typeof Theme !== "undefined" && Theme.colors && Theme.colors.text_primary) ? Theme.colors.text_primary : "#ffffff"
    property real cornerRadius: 0
    property string fallbackSymbol: ""

    property bool spinning: false
    property int spinDuration: 900

    implicitWidth: iconSize
    implicitHeight: iconSize
    width: iconSize
    height: iconSize

    readonly property string rawIcon: (icon || "").toString().trim()

    // 1. Nerd Font detection
    readonly property bool isNerd: rawIcon.length > 0 && ((rawIcon.codePointAt ? rawIcon.codePointAt(0) : rawIcon.charCodeAt(0)) >= 0xE000)

    // 2. Direct file/image protocol detection
    readonly property bool isDirectFile: rawIcon.startsWith("/") || rawIcon.startsWith("file://") || rawIcon.startsWith("image://") || rawIcon.startsWith("http://") || rawIcon.startsWith("https://")

    // Resolved IconResolver entry for apps/processes
    readonly property var resolverEntry: {
        if (!rawIcon || isNerd || isDirectFile) return null;
        try {
            if (typeof IconResolver !== "undefined") {
                return IconResolver.resolve(rawIcon);
            }
        } catch (e) {}
        return null;
    }

    readonly property bool looksLikeAppName: root.isApp ||
                                             (resolverEntry !== null && resolverEntry.displayName !== "") ||
                                             rawIcon.indexOf(" ") !== -1 ||
                                             rawIcon.indexOf("-") !== -1 ||
                                             rawIcon.indexOf(".") !== -1 ||
                                             rawIcon.indexOf("/") !== -1 ||
                                             /[A-Z]/.test(rawIcon)

    // 3. Resolve Image URL
    readonly property string resolvedImageUrl: {
        if (!rawIcon || isNerd) return "";
        if (isDirectFile) {
            return rawIcon.startsWith("/") ? ("file://" + rawIcon) : rawIcon;
        }

        if (root.looksLikeAppName) {
            if (resolverEntry && resolverEntry.iconPath && resolverEntry.iconPath !== "") {
                return resolverEntry.iconPath;
            }
            var lookupName = (resolverEntry && resolverEntry.iconName) ? resolverEntry.iconName : rawIcon;
            try {
                var p = Quickshell.iconPath(lookupName, "application-x-executable") || Quickshell.iconPath(lookupName);
                if (p && p.trim() !== "") return p;
            } catch (e) {}
        }

        return "";
    }

    readonly property bool isImageIcon: resolvedImageUrl !== ""

    // 4. Resolve fallback glyph text when not an image
    readonly property string resolvedGlyphText: {
        // A. Nerd font glyphs are returned directly
        if (isNerd) return rawIcon;

        // B. When an image is ready/loaded, no text ligature is needed
        if (isImageIcon && appIconImage.status === Image.Ready) return "";

        // C. Empty icon string: fall back gracefully
        if (rawIcon === "") {
            return (root.fallbackSymbol && root.fallbackSymbol !== "") ? root.fallbackSymbol : "apps";
        }

        // D. Application name or image that failed to load
        if (root.looksLikeAppName || isImageIcon) {
            if (root.fallbackSymbol && root.fallbackSymbol !== "") return root.fallbackSymbol;
            if (resolverEntry && resolverEntry.fallbackSymbol && resolverEntry.fallbackSymbol !== "") return resolverEntry.fallbackSymbol;
            return "apps";
        }

        // E. Otherwise rawIcon is a direct Material Symbol ligature (e.g. "arrow_back", "refresh", "settings", "close", "wifi")
        return rawIcon;
    }

    // Native IconImage branch (handles freedesktop theme icons & images)
    Item {
        id: imageContainer
        anchors.fill: parent
        clip: root.cornerRadius > 0
        visible: root.isImageIcon && appIconImage.status === Image.Ready

        IconImage {
            id: appIconImage
            anchors.fill: parent
            source: root.resolvedImageUrl
        }
    }

    // Glyph / Material Symbol / Nerd Font branch
    MaterialSymbol {
        id: glyphText
        anchors.centerIn: parent
        visible: !imageContainer.visible
        text: root.resolvedGlyphText
        iconSize: root.iconSize
        fill: root.fill
        grad: root.grad
        color: root.color
    }

    // Rotation animator for spinning state
    RotationAnimator on rotation {
        running: root.spinning
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: root.spinDuration
    }
}
