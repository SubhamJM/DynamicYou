import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../../"
import "../"

// Matushell 3-mode backdrop: Material (borderless solid), Glass (ambient blurred wallpaper + sheen), Blur (bokeh dither shader)
Item {
    id: root

    property string style: "material" // "material" | "glass" | "blur"
    property real cornerRadius: WidgetStore.s(26)
    property color materialColor: Theme.m3.surface_container ?? Theme.colors.card_bg
    property color glassTintColor: Qt.alpha(Theme.m3.surface_container ?? "#11131a", 0.72)
    property color blurTintColor: Qt.rgba(1, 1, 1, 0.12)
    property string wallpaperOverride: ""
    property real blurScale: 1.0

    readonly property bool isMaterial: style === "material"
    readonly property bool isGlass: style === "glass"
    readonly property bool isBlur: style === "blur"

    readonly property string wallpaperUrl: {
        if (wallpaperOverride !== "") {
            return wallpaperOverride.indexOf("://") >= 0
                ? wallpaperOverride
                : ("file://" + encodeURI(wallpaperOverride));
        }
        const wp = (typeof WidgetTelemetry !== "undefined") ? WidgetTelemetry.wallpaperPath : "";
        if (wp !== "") return "file://" + encodeURI(wp);
        return "";
    }

    // 1. Material: Clean flat borderless M3 surface
    Rectangle {
        visible: root.isMaterial
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.materialColor
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    // 2. Glass: Blurred ambient wallpaper + dark glass tint + hairline perimeter highlight
    Item {
        visible: root.isGlass
        anchors.fill: parent

        Rectangle {
            id: glassMaskSource
            anchors.fill: parent
            radius: root.cornerRadius
            color: root.materialColor
            clip: true

            Image {
                id: glassBgImg
                anchors.fill: parent
                source: root.wallpaperUrl
                sourceSize: Qt.size(480, 240)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: glassBgImg
                blurEnabled: true
                blur: 0.9
                saturation: 0.25
                brightness: -0.18
                visible: root.wallpaperUrl !== "" && glassBgImg.status === Image.Ready
                opacity: 0.65
            }

            Rectangle {
                anchors.fill: parent
                radius: root.cornerRadius
                color: root.wallpaperUrl !== "" ? root.glassTintColor : root.materialColor
            }

            Rectangle {
                anchors.fill: parent
                radius: root.cornerRadius
                color: "transparent"
                border.width: Math.max(1, WidgetStore.s(1))
                border.color: Qt.alpha(Theme.m3.on_surface ?? "#ffffff", 0.14)
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.13) }
                    GradientStop { position: 0.42; color: Qt.rgba(1, 1, 1, 0.02) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.28) }
                }
            }
        }
    }

    // 3. Blur: Live screen-UV aligned Liquid Frosted Bokeh Dither Blur shader (ditherglass.frag.qsb)
    Item {
        visible: root.isBlur
        anchors.fill: parent

        readonly property real winW: (root.Window.window && root.Window.window.width > 1) ? root.Window.window.width : 1920
        readonly property real winH: (root.Window.window && root.Window.window.height > 1) ? root.Window.window.height : 1200
        readonly property point originPt: root.mapToItem(null, 0, 0)

        Image {
            id: ditherWallTex
            anchors.fill: parent
            source: root.wallpaperUrl
            sourceSize: Qt.size(Math.max(1, Math.round(parent.winW / 2)), Math.max(1, Math.round(parent.winH / 2)))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        ShaderEffect {
            id: ditherShader
            anchors.fill: parent
            visible: root.wallpaperUrl !== "" && ditherWallTex.status === Image.Ready
            blending: true

            property variant sourceTex: ditherWallTex
            property real itemWidth: Math.max(1, root.width)
            property real itemHeight: Math.max(1, root.height)
            property real cornerRadius: root.cornerRadius
            property vector2d uvOffset: Qt.vector2d(
                Math.max(0, Math.min(1, parent.originPt.x / Math.max(1, parent.winW))),
                Math.max(0, Math.min(1, parent.originPt.y / Math.max(1, parent.winH)))
            )
            property vector2d uvScale: Qt.vector2d(
                Math.max(0.01, (root.width * root.blurScale) / Math.max(1, parent.winW)),
                Math.max(0.01, (root.height * root.blurScale) / Math.max(1, parent.winH))
            )
            property real blurRadius: 0.024
            property real ditherStrength: 0.015
            property real frostOpacity: 0.18
            property real brightnessBoost: 0.08
            property real saturation: 1.25
            property real rimGlow: 0.70
            property real pad0: 0.0
            property real pad1: 0.0
            property color tintColor: root.blurTintColor
            property color highlightColor: Qt.rgba(1, 1, 1, 0.82)

            fragmentShader: Qt.resolvedUrl("shaders/ditherglass.frag.qsb")
        }

        Rectangle {
            visible: !ditherShader.visible
            anchors.fill: parent
            radius: root.cornerRadius
            color: root.materialColor
        }
    }
}
