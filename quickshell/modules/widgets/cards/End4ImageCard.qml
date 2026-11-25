import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import "../../../"
import "../../../modules/common"
import "../../"
import "../"

// Authentic end-4pc M3 Image Card + CustomImage widget:
// Supports 1x1, 1x2, 1x3, 2x2, 2x3 + custom file/GIF/drop + M3 shape mask (rounded, cookie4, cookie12, gem, circle) + fit/fill + opacity + shadow.
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "end4Image"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "1x2")
    readonly property string customPath: String(opts.customPath || "")
    readonly property string shapeMode: String(opts.shapeMode || "rounded")
    readonly property string fitMode: String(opts.fitMode || "fill")
    readonly property real opacityLevel: Math.max(0.2, Math.min(1.0, Number(opts.opacityLevel !== undefined ? opts.opacityLevel : 1.0)))
    readonly property bool showShadow: opts.showShadow !== false
    readonly property bool resizing: resizeHandle.resizing

    property bool dropHover: false
    property string wallpaperPath: ""

    readonly property string configuredWallpaper: {
        const bg = (Config.options && Config.options.background && Config.options.background.wallpaperPath)
            ? String(Config.options.background.wallpaperPath)
            : "";
        if (bg === "" || /\.(mp4|webm|mkv|avi|mov)$/i.test(bg)) return "";
        return bg;
    }

    readonly property string effectivePath: customPath !== ""
        ? customPath
        : (wallpaperPath !== "" ? wallpaperPath : configuredWallpaper)
    readonly property bool isAnimatedGif: /\.gif$/i.test(effectivePath)
    readonly property string sourceUri: effectivePath !== "" ? ("file://" + encodeURI(effectivePath)) : ""

    onActiveChanged: {
        if (active && !readWallpaper.running) readWallpaper.running = true;
    }

    Process {
        id: readWallpaper
        running: true
        command: [
            "sh", "-c",
            "p=$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n1); " +
            "if [ -n \"$p\" ] && [ -f \"$p\" ]; then printf '%s' \"$p\"; exit 0; fi; " +
            "cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/active-theme\"; " +
            "for f in \"$cfg/current-wallpaper.txt\" \"$HOME/.cache/current_wallpaper\"; do " +
            "  if [ -f \"$f\" ]; then c=$(head -n1 \"$f\"); [ -f \"$c\" ] && printf '%s' \"$c\" && exit 0; fi; " +
            "done; " +
            "if [ -e \"$cfg/current-wallpaper\" ]; then realpath -e -- \"$cfg/current-wallpaper\" 2>/dev/null || true; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = String(this.text || "").trim().split("\n")[0];
                root.wallpaperPath = path.indexOf("/") === 0 ? path : "";
            }
        }
    }

    function acceptDrop(drop) {
        if (drop.hasUrls && drop.urls.length > 0) {
            const cleanPath = decodeURIComponent(String(drop.urls[0]).replace(/^file:\/\//, ""));
            const ext = cleanPath.split(".").pop().toLowerCase();
            if (["png", "jpg", "jpeg", "webp", "avif", "bmp", "gif", "tiff", "tif", "svg"].indexOf(ext) !== -1) {
                WidgetStore.setCardOption(root.tileId, "customPath", cleanPath);
            }
        }
        root.dropHover = false;
    }

    HoverHandler { id: cardHover }

    // Shadow layer (follows rounded rectangle or ExpressiveShape!)
    Item {
        id: shadowSource
        anchors.fill: parent
        visible: false
        opacity: root.opacityLevel

        Rectangle {
            anchors.fill: parent
            radius: root.shapeMode === "circle" ? Math.min(width, height) / 2 : WidgetStore.s(28)
            color: Theme.m3.primary_container ?? Theme.colors.card_bg
            visible: root.shapeMode === "rounded" || root.shapeMode === "circle"
        }

        ExpressiveShape {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            shape: root.shapeMode
            color: Theme.m3.primary_container ?? Theme.colors.card_bg
            visible: root.shapeMode !== "rounded" && root.shapeMode !== "circle"
        }
    }

    MultiEffect {
        anchors.fill: shadowSource
        source: shadowSource
        visible: root.showShadow && root.visible && width > 1 && height > 1
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.45)
        shadowBlur: 0.72
        shadowVerticalOffset: WidgetStore.s(4)
        autoPaddingEnabled: true
    }

    // Shaped container & background fill
    Item {
        id: photoClip
        anchors.fill: parent
        opacity: root.opacityLevel

        layer.enabled: width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(
            Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)),
            Math.max(1, Math.round(height * 2 * WidgetStore.qtScale))
        )
        layer.effect: OpacityMask {
            maskSource: Item {
                width: photoClip.width
                height: photoClip.height

                Rectangle {
                    anchors.fill: parent
                    radius: root.shapeMode === "circle" ? Math.min(width, height) / 2 : WidgetStore.s(28)
                    visible: root.shapeMode === "rounded" || root.shapeMode === "circle"
                }

                ExpressiveShape {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    shape: root.shapeMode
                    color: "#ffffff"
                    visible: root.shapeMode !== "rounded" && root.shapeMode !== "circle"
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.m3.primary_container ?? Theme.colors.card_bg
        }

        Image {
            id: photoImg
            anchors.fill: parent
            source: !root.isAnimatedGif ? root.sourceUri : ""
            fillMode: root.fitMode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            sourceSize: Qt.size(
                Math.min(720, Math.max(120, Math.round(width * 2 * WidgetStore.qtScale))),
                Math.min(720, Math.max(80, Math.round(height * 2 * WidgetStore.qtScale)))
            )
            visible: !root.isAnimatedGif && status === Image.Ready
        }

        AnimatedImage {
            id: animImg
            anchors.fill: parent
            source: root.isAnimatedGif ? root.sourceUri : ""
            fillMode: root.fitMode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            playing: root.active && root.isAnimatedGif
            paused: !root.active
            visible: root.isAnimatedGif && status === AnimatedImage.Ready
        }

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: WidgetStore.si(42)
            text: root.dropHover ? "download" : "image"
            fill: root.dropHover ? 1 : 0
            color: root.dropHover
                ? (Theme.m3.primary ?? Theme.accent)
                : (Theme.m3.on_primary_container ?? Theme.colors.text_primary)
            visible: (root.isAnimatedGif ? animImg.status !== AnimatedImage.Ready : photoImg.status !== Image.Ready) || root.dropHover
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: (drag) => {
                drag.accept(Qt.CopyAction);
                root.dropHover = true;
            }
            onExited: root.dropHover = false
            onDropped: (drop) => root.acceptDrop(drop)
        }
    }

    End4ResizeHandle {
        id: resizeHandle
        tileId: root.tileId
        hoverActive: cardHover.hovered
        enabledHandle: root.onDesktop && root.interactive
        currentMode: root.sizeMode
        snapModes: ["1x1", "1x2", "1x3", "2x2", "2x3"]
        strokeColor: "#ffffff"
    }
}
