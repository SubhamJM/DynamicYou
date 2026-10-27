import QtQuick
import Quickshell
import Quickshell.Widgets
import "../"

// Universal modular icon element inspired by Matushell (MatusIcon + MatusMaskedImage + NotificationIcon)
// Seamlessly renders:
// 1. Variable-font Material Symbols with optical sizing & dark OLED grade compensation
// 2. JetBrainsMono Nerd Font glyphs
// 3. Desktop application icon theme assets with GPU-constrained sourceSize (zero VRAM waste)
// 4. Local image paths & URLs with graceful fallback symbol handling via IconResolver
Item {
    id: root

    // --- Public API ---
    property string icon: ""               // Material symbol, app name, file path, or nerd glyph
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

    // 3. Resolve Image URL
    readonly property string resolvedImageUrl: {
        if (!rawIcon || isNerd) return "";
        if (isDirectFile) {
            return rawIcon.startsWith("/") ? ("file://" + rawIcon) : rawIcon;
        }

        // Try direct Quickshell.iconPath lookup
        try {
            var directPath = Quickshell.iconPath(rawIcon, true);
            if (directPath && directPath.trim() !== "") {
                if (directPath.startsWith("image://") || directPath.startsWith("file://")) {
                    return directPath;
                }
                return directPath.startsWith("/") ? ("file://" + directPath) : ("file://" + directPath);
            }
        } catch (e) {}

        // Try IconResolver mapping path
        if (resolverEntry && resolverEntry.iconPath && resolverEntry.iconPath !== "") {
            return resolverEntry.iconPath;
        }

        return "";
    }

    readonly property bool isImageIcon: resolvedImageUrl !== ""

    // 4. Resolve fallback glyph text when not an image
    readonly property string resolvedGlyphText: {
        // A. Nerd font glyphs are returned directly
        if (isNerd) return rawIcon;

        // B. When an image is ready, no text ligature is needed
        if (isImageIcon && appImage.status === Image.Ready) return "";

        // C. Empty icon string: fall back gracefully
        if (rawIcon === "") {
            return (root.fallbackSymbol && root.fallbackSymbol !== "") ? root.fallbackSymbol : "apps";
        }

        // D. Image icon failed to load (Image.Error)
        if (isImageIcon && appImage.status === Image.Error) {
            if (root.fallbackSymbol && root.fallbackSymbol !== "") return root.fallbackSymbol;
            if (resolverEntry && resolverEntry.fallbackSymbol && resolverEntry.fallbackSymbol !== "") return resolverEntry.fallbackSymbol;
            return "apps";
        }

        // E. Recognized application/process in IconResolver that mapped to a specific symbol
        // (Only when rawIcon is an app like "zen", "firefox", "kitty", "obsidian" and no image was found on disk)
        if (resolverEntry && resolverEntry.displayName && resolverEntry.displayName !== "" && resolverEntry.fallbackSymbol && resolverEntry.fallbackSymbol !== "") {
            return resolverEntry.fallbackSymbol;
        }

        // F. Detect if rawIcon is an application name, desktop file ID, or command line rather than a Material Symbol ligature.
        // Material Symbol ligatures are strictly lowercase ascii words with underscores (e.g. "arrow_back", "wifi", "signal_wifi_4_bar").
        // Desktop IDs, process names, and commands contain spaces, hyphens, dots, slashes, or uppercase characters.
        var looksLikeAppName = rawIcon.indexOf(" ") !== -1 ||
                               rawIcon.indexOf("-") !== -1 ||
                               rawIcon.indexOf(".") !== -1 ||
                               rawIcon.indexOf("/") !== -1 ||
                               /[A-Z]/.test(rawIcon);

        if (looksLikeAppName) {
            if (root.fallbackSymbol && root.fallbackSymbol !== "") return root.fallbackSymbol;
            if (resolverEntry && resolverEntry.fallbackSymbol && resolverEntry.fallbackSymbol !== "") return resolverEntry.fallbackSymbol;
            return "apps";
        }

        // G. Otherwise rawIcon is a direct Material Symbol ligature (e.g. "arrow_back", "refresh", "settings", "close", "wifi", "fast_rewind")
        return rawIcon;
    }

    // Image branch with ClippingRectangle (MatusMaskedImage pattern)
    ClippingRectangle {
        id: imageClipper
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        visible: root.isImageIcon && appImage.status === Image.Ready

        Image {
            id: appImage
            anchors.fill: parent
            source: root.resolvedImageUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            // Strict Matushell guideline: Constrain sourceSize to prevent GPU buffer bloat
            sourceSize.width: Math.max(16, Math.round(root.iconSize * (Screen.devicePixelRatio || 1)))
            sourceSize.height: Math.max(16, Math.round(root.iconSize * (Screen.devicePixelRatio || 1)))
        }
    }

    // Glyph / Material Symbol / Nerd Font branch
    MaterialSymbol {
        id: glyphText
        anchors.centerIn: parent
        visible: !imageClipper.visible
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
