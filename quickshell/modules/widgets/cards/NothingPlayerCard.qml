import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import "../../../"
import "../../../services"
import "../../"
import "../"

// Nothing OS Glyph Spinning Dot-Matrix Vinyl Player Card (Art + Seg + Controls)
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "nothingPlayer"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "2x2")
    readonly property bool spinArt: opts.spinArt !== false
    readonly property bool dotMatrixArt: opts.dotMatrixArt !== false
    readonly property string accentMode: String(opts.accentMode || "glyph")
    readonly property bool showShadow: opts.showShadow !== false

    NothingGlyphTokens {
        id: tok
        accentMode: root.accentMode
    }

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackState === MprisPlaybackState.Playing
    readonly property string playerName: {
        const n = hasPlayer ? String(player.identity || player.desktopEntry || "Audio") : "Idle";
        return n.toUpperCase();
    }
    readonly property string trackTitle: hasPlayer && player.trackTitle ? String(player.trackTitle) : "Nothing Playing"
    readonly property string trackArtist: hasPlayer && player.trackArtist ? String(player.trackArtist) : "Queue empty"
    readonly property string rawArtUrl: hasPlayer ? (MprisController.rawArtUrlFor(player) || String(MprisController.artUrl || "")) : ""
    readonly property string artUrl: CoverArt.source(rawArtUrl)

    property real elapsedSec: 0
    property real lengthSec: 0

    function syncProgress() {
        if (!root.player) {
            root.elapsedSec = 0;
            root.lengthSec = 0;
            return;
        }
        root.lengthSec = MprisController.trackLengthOf(root.player);
        root.elapsedSec = MprisController.trackPositionOf(root.player);
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.hasPlayer
        triggeredOnStart: true
        onTriggered: root.syncProgress()
    }

    onPlayerChanged: syncProgress()
    Component.onCompleted: syncProgress()

    readonly property real progressFrac: lengthSec > 0 ? Math.max(0, Math.min(1, elapsedSec / lengthSec)) : 0

    function fmtTime(sec) {
        const s = Math.max(0, Math.floor(sec));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return String(m).padStart(2, "0") + ":" + String(r).padStart(2, "0");
    }

    function togglePlay() {
        if (!root.player) return;
        if (typeof root.player.togglePlaying === "function") root.player.togglePlaying();
        else root.player.playing = !root.player.playing;
    }

    readonly property bool isStrip: sizeMode === "1x2"
    readonly property bool isWide: sizeMode === "1x3"
    readonly property bool isSquare: sizeMode === "2x2"

    Rectangle {
        anchors.fill: parent
        radius: WidgetStore.s(24)
        color: tok.s1
        border.width: Math.max(1, WidgetStore.s(1))
        border.color: tok.border

        layer.enabled: root.onDesktop && root.showShadow && root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(
            Math.max(1, Math.round(width * WidgetStore.qtScale)),
            Math.max(1, Math.round(height * WidgetStore.qtScale))
        )
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.7
            shadowVerticalOffset: WidgetStore.s(4)
            autoPaddingEnabled: true
        }
    }

    // Spinning circular dot-matrix vinyl album art component
    component DotVinylDisc: Item {
        id: disc
        property real sizePx: WidgetStore.s(108)
        width: sizePx
        height: sizePx

        Item {
            id: spinWrapper
            anchors.fill: parent

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 18000
                loops: Animation.Infinite
                running: root.active && root.playing && root.spinArt
            }

            Item {
                anchors.fill: parent
                layer.enabled: width > 1 && height > 1
                layer.effect: NothingDotMask {
                    step: root.dotMatrixArt ? 5.2 : 1.0
                    circle: true
                }

                // Nothing OS conic gradient fallback when no album artwork exists
                Shape {
                    anchors.fill: parent
                    visible: artImg.status !== Image.Ready
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: ConicalGradient {
                            centerX: disc.width / 2
                            centerY: disc.height / 2
                            angle: 50
                            GradientStop { position: 0.0; color: "#FFFFFF" }
                            GradientStop { position: 0.2; color: "#444444" }
                            GradientStop { position: 0.4; color: "#DDDDDD" }
                            GradientStop { position: 0.6; color: "#141414" }
                            GradientStop { position: 0.8; color: "#BBBBBB" }
                            GradientStop { position: 1.0; color: "#FFFFFF" }
                        }
                        PathRectangle { width: disc.width; height: disc.height }
                    }
                }

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(256, 256)
                    asynchronous: true
                }
            }
        }

        // Spindle dot in center
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(WidgetStore.s(12), disc.width * 0.16)
            height: width
            radius: width / 2
            color: tok.s1
            border.width: Math.max(1, WidgetStore.s(1.5))
            border.color: root.playing ? tok.accent : tok.s3

            Rectangle {
                anchors.centerIn: parent
                width: Math.max(WidgetStore.s(4), parent.width * 0.34)
                height: width
                radius: width / 2
                color: root.playing ? tok.accent : tok.grey
            }
        }
    }

    // Transport Controls Row
    component TransportRow: Row {
        property real btnPlaySize: WidgetStore.s(44)
        property real symbolSize: 20
        spacing: WidgetStore.s(18)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: WidgetStore.s(30)
            height: width
            radius: width / 2
            color: prevMouse.containsMouse ? tok.s2 : "transparent"

            MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_previous"
                iconSize: WidgetStore.si(symbolSize)
                fill: 1
                color: (root.player && root.player.canGoPrevious) ? tok.fg : tok.mute
            }
            MouseArea {
                id: prevMouse
                enabled: root.interactive && root.hasPlayer && root.player.canGoPrevious
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player.previous()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: btnPlaySize
            height: btnPlaySize
            radius: btnPlaySize / 2
            color: playMouse.pressed ? Qt.darker(tok.accent, 1.15) : tok.accent

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.playing ? "pause" : "play_arrow"
                iconSize: WidgetStore.si(Math.round(btnPlaySize * 0.52 / WidgetStore.uiScale))
                fill: 1
                color: tok.onAccent
            }

            MouseArea {
                id: playMouse
                enabled: root.interactive && root.hasPlayer
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePlay()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: WidgetStore.s(30)
            height: width
            radius: width / 2
            color: nextMouse.containsMouse ? tok.s2 : "transparent"

            MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_next"
                iconSize: WidgetStore.si(symbolSize)
                fill: 1
                color: (root.player && root.player.canGoNext) ? tok.fg : tok.mute
            }
            MouseArea {
                id: nextMouse
                enabled: root.interactive && root.hasPlayer && root.player.canGoNext
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player.next()
            }
        }
    }

    // Interactive Segmented Progress Bar
    component SegProgressItem: Item {
        property int segCount: 24
        implicitHeight: WidgetStore.s(14)

        NothingSegBar {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: WidgetStore.s(6)
            n: segCount
            f: root.progressFrac
            onColor: tok.fg
            offColor: tok.s3
            accentHeadColor: tok.accent
        }

        MouseArea {
            enabled: root.interactive && root.hasPlayer && root.lengthSec > 0 && root.player.canSeek
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: (e) => {
                const frac = Math.max(0, Math.min(1, e.x / Math.max(1, width)));
                root.player.position = frac * root.lengthSec;
                root.elapsedSec = root.player.position;
            }
        }
    }

    // 1) Compact Strip 1x2 Layout
    RowLayout {
        visible: root.isStrip
        anchors {
            fill: parent
            margins: WidgetStore.s(12)
        }
        spacing: WidgetStore.s(12)

        DotVinylDisc {
            sizePx: WidgetStore.s(110)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: WidgetStore.s(4)

            Row {
                spacing: WidgetStore.s(5)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: WidgetStore.s(5)
                    height: width
                    radius: width / 2
                    color: root.playing ? tok.accent : tok.mute
                }
                Text {
                    text: root.playing ? "NOW PLAYING" : "PAUSED"
                    color: root.playing ? tok.accent : tok.grey
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(8.5)
                    font.letterSpacing: 0.9
                    renderType: Text.NativeRendering
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.trackTitle
                color: tok.fg
                font.family: tok.uiFont
                font.pixelSize: WidgetStore.si(14)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                Layout.fillWidth: true
                text: root.trackArtist
                color: tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(9.5)
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Item { Layout.fillHeight: true }

            SegProgressItem {
                Layout.fillWidth: true
                segCount: 16
            }

            TransportRow {
                Layout.alignment: Qt.AlignHCenter
                btnPlaySize: WidgetStore.s(34)
                symbolSize: 18
                spacing: WidgetStore.s(10)
            }
        }
    }

    // 2) Wide 1x3 Horizontal Player Layout
    RowLayout {
        visible: root.isWide
        anchors {
            fill: parent
            margins: WidgetStore.s(14)
        }
        spacing: WidgetStore.s(16)

        DotVinylDisc {
            sizePx: WidgetStore.s(124)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: WidgetStore.s(6)

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(6)

                Rectangle {
                    width: WidgetStore.s(6)
                    height: width
                    radius: width / 2
                    color: root.playing ? tok.accent : tok.mute
                }

                Text {
                    Layout.fillWidth: true
                    text: (root.playing ? "NOW PLAYING · " : "PAUSED · ") + root.playerName
                    color: root.playing ? tok.accent : tok.grey
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(9.5)
                    font.letterSpacing: 1.0
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    visible: root.lengthSec > 0
                    text: root.fmtTime(root.elapsedSec) + " / " + root.fmtTime(root.lengthSec)
                    color: tok.grey
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(9)
                    renderType: Text.NativeRendering
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.trackTitle
                color: tok.fg
                font.family: tok.uiFont
                font.pixelSize: WidgetStore.si(17)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                Layout.fillWidth: true
                text: root.trackArtist
                color: tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(10.5)
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(14)

                SegProgressItem {
                    Layout.fillWidth: true
                    segCount: 20
                }

                TransportRow {
                    btnPlaySize: WidgetStore.s(42)
                    symbolSize: 20
                    spacing: WidgetStore.s(10)
                }
            }
        }
    }

    // 3) Classic 2x2 Nothing OS Player Bento Card
    ColumnLayout {
        visible: root.isSquare
        anchors {
            fill: parent
            margins: WidgetStore.s(16)
        }
        spacing: WidgetStore.s(10)

        // Status header
        RowLayout {
            Layout.fillWidth: true
            spacing: WidgetStore.s(6)

            Rectangle {
                width: WidgetStore.s(6)
                height: width
                radius: width / 2
                color: root.playing ? tok.accent : tok.mute
            }

            Text {
                Layout.fillWidth: true
                text: (root.playing ? "NOW PLAYING · " : "PAUSED · ") + root.playerName
                color: root.playing ? tok.accent : tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(9.5)
                font.letterSpacing: 1.0
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                visible: root.lengthSec > 0
                text: root.fmtTime(root.elapsedSec) + " / " + root.fmtTime(root.lengthSec)
                color: tok.grey
                font.family: tok.monoFont
                font.pixelSize: WidgetStore.si(9)
                renderType: Text.NativeRendering
            }
        }

        // Top artwork + title block
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: WidgetStore.s(14)

            DotVinylDisc {
                sizePx: WidgetStore.s(136)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: WidgetStore.s(4)

                Text {
                    Layout.fillWidth: true
                    text: root.trackTitle
                    color: tok.fg
                    font.family: tok.uiFont
                    font.pixelSize: WidgetStore.si(17)
                    font.weight: Font.DemiBold
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    text: root.trackArtist
                    color: tok.grey
                    font.family: tok.monoFont
                    font.pixelSize: WidgetStore.si(10.5)
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }
        }

        SegProgressItem {
            Layout.fillWidth: true
            segCount: 24
        }

        TransportRow {
            Layout.alignment: Qt.AlignHCenter
            btnPlaySize: WidgetStore.s(48)
            symbolSize: 22
            spacing: WidgetStore.s(20)
        }
    }
}
