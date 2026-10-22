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
    property string fallbackSymbol: "apps"

    property bool spinning: false
    property int spinDuration: 900

    implicitWidth: iconSize
    implicitHeight: iconSize

    readonly property string rawIcon: (icon || "").toString().trim()

    // 1. Nerd Font detection
    readonly property bool isNerd: rawIcon.length > 0 && rawIcon.charCodeAt(0) >= 0xE000

    // 2. Direct file/image protocol detection
    readonly property bool isDirectFile: rawIcon.startsWith("/") || rawIcon.startsWith("file://") || rawIcon.startsWith("image://") || rawIcon.startsWith("http://") || rawIcon.startsWith("https://")

    // 3. Resolve Image URL
    readonly property string resolvedImageUrl: {
        if (!rawIcon || isNerd) return "";
        if (isDirectFile) {
            return rawIcon.startsWith("/") ? ("file://" + rawIcon) : rawIcon;
        }

        // Try Quickshell.iconPath on rawIcon directly
        try {
            var directPath = Quickshell.iconPath(rawIcon, true);
            if (directPath && directPath.trim() !== "") {
                if (directPath.startsWith("image://") || directPath.startsWith("file://")) {
                    return directPath;
                }
                return directPath.startsWith("/") ? ("file://" + directPath) : ("file://" + directPath);
            }
        } catch (e) {}

        // Try IconResolver mapping
        try {
            if (typeof IconResolver !== "undefined") {
                var res = IconResolver.resolve(rawIcon);
                if (res && res.iconPath && res.iconPath !== "") return res.iconPath;
            }
        } catch (e) {}

        return "";
    }

    readonly property bool isImageIcon: resolvedImageUrl !== ""

    // 4. Resolve fallback glyph text when not an image
    readonly property string resolvedGlyphText: {
        if (isNerd) return rawIcon;
        if (isImageIcon && appImage.status === Image.Ready) return "";

        // If it was supposed to be an image or app name but couldn't load
        if (isImageIcon || rawIcon.includes(".") || rawIcon.includes("-") || rawIcon.includes("/")) {
            try {
                if (typeof IconResolver !== "undefined") {
                    var r = IconResolver.resolve(rawIcon);
                    if (r && r.fallbackSymbol) return r.fallbackSymbol;
                }
            } catch (e) {}
            return root.fallbackSymbol;
        }

        // Check if rawIcon is a known app name in IconResolver
        try {
            if (typeof IconResolver !== "undefined" && IconResolver.iconMap && IconResolver.iconMap[rawIcon.toLowerCase()]) {
                return IconResolver.iconMap[rawIcon.toLowerCase()].symbol;
            }
        } catch (e) {}

        return rawIcon !== "" ? rawIcon : root.fallbackSymbol;
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
