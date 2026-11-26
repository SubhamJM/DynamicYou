import QtQuick
import Quickshell
import Quickshell.Io
import "../../../"
import "../../../modules/common"
import "../../"
import "../"

// Sekai Pop Custom Image widget (based on sekai-pop ImageService + ImageWidget + Polaroid matte):
// Supports ANY custom image or GIF (via file picker or DropArea), plus fallback to live wallpaper,
// fit/fill/crop modes, zoom, roundness, opacity, border, frame style (polaroid/card/clean), caption, tilt.
Item {
    id: root

    property bool active: true
    property string tileId: "image"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string customPath: String(opts.customPath || "")
    readonly property string fitMode: String(opts.fitMode || "fill")
    readonly property real zoom: Math.max(1.0, Math.min(2.5, Number(opts.zoom !== undefined ? opts.zoom : 1.0)))
    readonly property string frameStyle: String(opts.frameStyle || "polaroid")
    readonly property real roundness: Math.max(0, Math.min(36, Number(opts.roundness !== undefined ? opts.roundness : 12)))
    readonly property real opacityLevel: Math.max(0.2, Math.min(1.0, Number(opts.opacityLevel !== undefined ? opts.opacityLevel : 1.0)))
    readonly property bool showBorder: opts.showBorder !== false
    readonly property bool showCaption: opts.showCaption !== false
    readonly property bool tilted: opts.tilted !== false

    property bool dropHover: false
    readonly property string wallpaperPath: (typeof WidgetTelemetry !== "undefined") ? WidgetTelemetry.wallpaperPath : ""

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

    readonly property string fileName: {
        if (effectivePath === "") return "Picture";
        const parts = effectivePath.split("/");
        const name = parts.length > 0 ? parts[parts.length - 1] : "";
        return name.replace(/\.[^.]+$/, "").replace(/[_-]+/g, " ");
    }

    readonly property color fg: Theme.m3.on_surface ?? Theme.colors.text_primary
    readonly property color accent: Theme.m3.primary ?? Theme.accent
    readonly property color onAccent: Theme.m3.on_primary ?? "#101014"

    onConfiguredWallpaperChanged: {
        if (typeof WidgetTelemetry !== "undefined") WidgetTelemetry.refreshEnvironment();
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

    SekaiPill {
        id: frame
        anchors.fill: parent
        opacity: root.opacityLevel
        cornerRadius: WidgetStore.s(root.frameStyle === "clean" ? root.roundness : 22)
        borderWidth: root.showBorder ? WidgetStore.s(2.5) : 0
        ringWidth: root.showBorder && root.frameStyle !== "clean" ? WidgetStore.s(3) : 0
        shadowDx: root.showBorder ? WidgetStore.s(3) : 0
        shadowDy: root.showBorder ? WidgetStore.s(4) : 0
        flat: !root.showBorder
        fillColor: root.frameStyle === "clean" ? "transparent" : (Theme.m3.surface_container ?? Theme.colors.card_bg)
        ringColor: Qt.alpha(root.accent, 0.24)

        // Subtle atmospheric backdrop circle
        Rectangle {
            visible: root.frameStyle === "polaroid"
            width: WidgetStore.s(190)
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: Qt.alpha(root.accent, 0.14)
        }

        // Top Sekai Pop header badge (for polaroid/card modes)
        SekaiPill {
            id: headerTag
            visible: root.frameStyle !== "clean"
            z: 5
            anchors {
                top: parent.top
                left: parent.left
                topMargin: WidgetStore.s(10)
                leftMargin: WidgetStore.s(12)
            }
            width: tagRow.implicitWidth + WidgetStore.s(18)
            height: WidgetStore.s(22)
            cornerRadius: WidgetStore.s(8)
            borderWidth: WidgetStore.s(2)
            ringWidth: WidgetStore.s(1.5)
            shadowDy: WidgetStore.s(2)
            rotation: root.tilted ? -2 : 0
            fillColor: root.accent

            Row {
                id: tagRow
                anchors.centerIn: parent
                spacing: WidgetStore.s(4)
                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.customPath !== "" ? "photo_library" : "image"
                    iconSize: WidgetStore.si(12)
                    fill: 1
                    color: root.onAccent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.customPath !== "" ? "PICTURE" : "WALLPAPER"
                    color: root.onAccent
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(9)
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.8
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                }
            }
        }

        // Polaroid matte / card inner frame
        SekaiPill {
            id: polaroid
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.frameStyle === "polaroid"
                ? WidgetStore.s(8)
                : (root.frameStyle === "card" ? WidgetStore.s(14) : 0)
            width: root.frameStyle === "clean"
                ? parent.width
                : (root.frameStyle === "card" ? parent.width - WidgetStore.s(16) : Math.min(parent.width - WidgetStore.s(28), WidgetStore.s(258)))
            height: root.frameStyle === "clean"
                ? parent.height
                : (root.frameStyle === "card" ? parent.height - WidgetStore.s(42) : parent.height - WidgetStore.s(48))
            cornerRadius: WidgetStore.s(root.frameStyle === "clean" ? root.roundness : Math.min(20, root.roundness))
            borderWidth: root.frameStyle === "clean" ? 0 : WidgetStore.s(2)
            ringWidth: root.frameStyle === "clean" ? 0 : WidgetStore.s(2)
            shadowDx: root.frameStyle === "clean" ? 0 : WidgetStore.s(2)
            shadowDy: root.frameStyle === "clean" ? 0 : WidgetStore.s(3)
            flat: root.frameStyle === "clean"
            rotation: (root.tilted && root.frameStyle === "polaroid") ? 1.4 : 0
            fillColor: root.frameStyle === "polaroid" ? "#F6F0E3" : (Theme.m3.surface_container_lowest ?? "#0b0b12")

            Rectangle {
                id: photoFrame
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: root.frameStyle === "polaroid" ? WidgetStore.s(9) : 0
                }
                height: root.frameStyle === "polaroid"
                    ? Math.max(WidgetStore.s(40), parent.height - (root.showCaption ? WidgetStore.s(44) : WidgetStore.s(18)))
                    : parent.height
                radius: WidgetStore.s(root.frameStyle === "polaroid" ? Math.max(4, Math.min(14, root.roundness * 0.6)) : root.roundness)
                color: root.fitMode === "fit" ? "transparent" : (Theme.m3.surface_container_lowest ?? "#0b0b12")
                clip: true

                Image {
                    id: photo
                    anchors.centerIn: parent
                    width: parent.width * (root.fitMode === "crop" ? root.zoom : 1.0)
                    height: parent.height * (root.fitMode === "crop" ? root.zoom : 1.0)
                    source: !root.isAnimatedGif ? root.sourceUri : ""
                    fillMode: root.fitMode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(
                        Math.min(720, Math.max(128, Math.round(photoFrame.width * 2 * WidgetStore.qtScale))),
                        Math.min(720, Math.max(128, Math.round(photoFrame.height * 2 * WidgetStore.qtScale)))
                    )
                    visible: !root.isAnimatedGif && status === Image.Ready
                }

                AnimatedImage {
                    id: animPhoto
                    anchors.centerIn: parent
                    width: parent.width * (root.fitMode === "crop" ? root.zoom : 1.0)
                    height: parent.height * (root.fitMode === "crop" ? root.zoom : 1.0)
                    source: root.isAnimatedGif ? root.sourceUri : ""
                    fillMode: root.fitMode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    playing: root.active && root.isAnimatedGif
                    paused: !root.active
                    visible: root.isAnimatedGif && status === AnimatedImage.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    visible: (root.isAnimatedGif ? !animPhoto.visible : !photo.visible) || root.dropHover
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.dropHover ? Qt.alpha(root.accent, 0.35) : (Theme.m3.primary_container ?? "#2a2230") }
                        GradientStop { position: 1.0; color: Theme.m3.surface_container_lowest ?? "#0b0b12" }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: WidgetStore.s(6)

                        MaterialSymbol {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.dropHover ? "download" : "image"
                            iconSize: WidgetStore.si(28)
                            color: root.dropHover ? root.accent : Theme.alpha(root.fg, 0.7)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.dropHover ? "Drop image" : "Drop or pick image"
                            color: Theme.alpha(root.fg, 0.78)
                            font.family: "Noto Sans"
                            font.pixelSize: WidgetStore.si(10)
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            Text {
                id: caption
                visible: root.frameStyle === "polaroid" && root.showCaption
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: WidgetStore.s(10)
                    rightMargin: WidgetStore.s(10)
                    bottomMargin: WidgetStore.s(7)
                }
                horizontalAlignment: Text.AlignHCenter
                text: root.fileName
                color: "#1B1918"
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(10)
                font.weight: Font.ExtraBold
                font.letterSpacing: 0.5
                elide: Text.ElideRight
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
            }
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
}
