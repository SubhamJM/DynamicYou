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
    readonly property bool isDirectFile: rawIcon.startsWith("/") || rawIcon.startsWith("file://") || rawIcon.startsWith("http://") || rawIcon.startsWith("https://")

    // Helper: is this string a known Material Symbol name (not a desktop application icon)?
    function isStandardSymbol(s) {
        if (!s) return false;
        if (s.indexOf("_") !== -1) return true; // e.g. memory_alt, play_circle, volume_up, content_paste, screenshot_monitor
        var symbols = {
            "memory": 1, "settings": 1, "widgets": 1, "notifications": 1, "close": 1, "check": 1,
            "refresh": 1, "lock": 1, "folder": 1, "code": 1, "terminal": 1, "palette": 1, "wifi": 1,
            "bluetooth": 1, "crop": 1, "colorize": 1, "videocam": 1, "equalizer": 1, "speed": 1,
            "brush": 1, "window": 1, "edit": 1, "timer": 1, "coffee": 1, "apps": 1, "hub": 1,
            "lan": 1, "monitoring": 1, "hard_drive": 1, "security": 1, "bedtime": 1, "history": 1,
            "tab": 1, "search": 1, "tune": 1, "sync": 1, "dns": 1, "language": 1, "send": 1,
            "movie": 1, "chat": 1, "forum": 1, "help": 1, "info": 1, "download": 1, "upload": 1
        };
        return symbols[s] === 1;
    }

    // Resolved IconResolver entry for apps/processes
    readonly property var resolverEntry: {
        if (!rawIcon || isNerd || isDirectFile || isStandardSymbol(rawIcon)) return null;
        try {
            if (typeof IconResolver !== "undefined") {
                return IconResolver.resolve(rawIcon);
            }
        } catch (e) {}
        return null;
    }

    readonly property bool looksLikeAppName: (root.isApp && !isStandardSymbol(rawIcon)) ||
                                             (resolverEntry !== null && resolverEntry.displayName !== "") ||
                                             (rawIcon.indexOf("-") !== -1 && !isStandardSymbol(rawIcon)) ||
                                             (rawIcon.indexOf(".") !== -1 && !isDirectFile)

    // 3. Resolve Image URL
    readonly property string resolvedImageUrl: {
        if (!rawIcon || isNerd) return "";
        if (isDirectFile) {
            return rawIcon.startsWith("/") ? ("file://" + rawIcon) : rawIcon;
        }

        // Theme / Desktop App Icon lookup
        if (root.looksLikeAppName) {
            if (resolverEntry) {
                if (resolverEntry.iconPath && resolverEntry.iconPath !== "") {
                    return resolverEntry.iconPath;
                }
                if (resolverEntry.hasIcon === false) {
                    return ""; // Known not to have a desktop theme icon
                }
            }
            if (root.isApp && rawIcon !== "" && !isStandardSymbol(rawIcon)) {
                try {
                    var p = Quickshell.iconPath(rawIcon);
                    if (p && p.trim() !== "") return p;
                } catch (e) {}
            }
        }

        return "";
    }

    readonly property bool isImageIcon: resolvedImageUrl !== ""

    readonly property bool hasRenderedDirectImage: isDirectFile && directImage.status === Image.Ready
    readonly property bool hasRenderedAppIcon: !isDirectFile && isImageIcon && appIconImage.status === Image.Ready

    // 4. Resolve fallback glyph text when not an image
    readonly property string resolvedGlyphText: {
        // A. Nerd font glyphs are returned directly
        if (isNerd) return rawIcon;

        // B. When an image is successfully ready/loaded, no text ligature is needed
        if (hasRenderedDirectImage || hasRenderedAppIcon) return "";

        // C. Empty icon string: fall back gracefully
        if (rawIcon === "") {
            return (root.fallbackSymbol && root.fallbackSymbol !== "") ? root.fallbackSymbol : "apps";
        }

        // D. Application name or image that failed to load or has no theme icon
        if (root.looksLikeAppName || isImageIcon || isDirectFile) {
            if (root.fallbackSymbol && root.fallbackSymbol !== "") return root.fallbackSymbol;
            if (resolverEntry && resolverEntry.fallbackSymbol && resolverEntry.fallbackSymbol !== "") return resolverEntry.fallbackSymbol;
            return "apps";
        }

        // E. Otherwise rawIcon is a direct Material Symbol ligature
        return rawIcon;
    }

    // Direct Image branch (handles screenshot images, file paths, web URLs)
    Image {
        id: directImage
        anchors.fill: parent
        visible: root.hasRenderedDirectImage
        source: root.isDirectFile ? root.resolvedImageUrl : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Math.max(32, root.iconSize * 2)
        sourceSize.height: Math.max(32, root.iconSize * 2)
        asynchronous: true
        mipmap: true
    }

    // Native IconImage branch (handles freedesktop theme icons)
    Item {
        id: appIconContainer
        anchors.fill: parent
        clip: root.cornerRadius > 0
        visible: root.hasRenderedAppIcon

        IconImage {
            id: appIconImage
            anchors.fill: parent
            source: (!root.isDirectFile && root.isImageIcon) ? root.resolvedImageUrl : ""
        }
    }

    // Glyph / Material Symbol / Nerd Font branch
    MaterialSymbol {
        id: glyphText
        anchors.centerIn: parent
        visible: !root.hasRenderedDirectImage && !root.hasRenderedAppIcon
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
