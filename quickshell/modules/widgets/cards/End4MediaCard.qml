import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import "../../../"
import "../../../services"
import "../../"
import "../"

// Authentic end-4pc M3 Expressive Media widget supporting 1x1, 1x2, 1x3 (+ lyrics drawer), 2x2, 2x3
Item {
    id: root

    property bool active: true
    property bool interactive: true
    property bool onDesktop: false
    property string tileId: "end4Media"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property string sizeMode: String(opts.sizeMode || "1x3")
    readonly property bool showLyrics: opts.showLyrics === true
    readonly property bool showControls: opts.showControls !== false
    readonly property bool showTitles: opts.showTitles !== false
    readonly property bool showShadow: opts.showShadow !== false
    readonly property bool resizing: resizeHandle.resizing

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null && root.player !== undefined
    readonly property bool playing: root.hasPlayer && root.player.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: root.hasPlayer ? String(root.player.trackTitle || "Nothing playing") : "Nothing playing"
    readonly property string trackArtist: root.hasPlayer ? String(root.player.trackArtist || "Media") : "Play something"
    readonly property string rawArtUrl: root.hasPlayer ? (MprisController.rawArtUrlFor(root.player) || String(MprisController.artUrl || "")) : ""
    readonly property string artUrl: CoverArt.source(root.rawArtUrl)

    function togglePlay() {
        if (!root.player) return;
        if (typeof root.player.togglePlaying === "function") root.player.togglePlaying();
        else root.player.playing = !root.player.playing;
    }

    function ensureLyricsActive() {
        if (root.active && (root.showLyrics || root.sizeMode === "2x3") && !LyricsService.isInitialized) {
            LyricsService.initiliazeLyrics();
        }
    }
    onShowLyricsChanged: ensureLyricsActive()
    onSizeModeChanged: ensureLyricsActive()
    Component.onCompleted: ensureLyricsActive()

    readonly property color cardBg: Theme.m3.primary_container ?? Theme.colors.card_bg
    readonly property color cardFg: Theme.m3.on_primary_container ?? Theme.colors.text_primary
    readonly property color artBg: Theme.m3.surface_container_low ?? Theme.colors.hover_bg
    readonly property color accent: Theme.m3.primary ?? Theme.accent
    readonly property color onAccent: Theme.m3.on_primary ?? "#101014"

    HoverHandler { id: cardHover }

    Rectangle {
        anchors.fill: parent
        radius: WidgetStore.s(28)
        color: root.cardBg

        layer.enabled: root.onDesktop && root.showShadow && root.visible && width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(
            Math.max(1, Math.round(width * WidgetStore.qtScale)),
            Math.max(1, Math.round(height * WidgetStore.qtScale))
        )
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.42)
            shadowBlur: 0.7
            shadowVerticalOffset: WidgetStore.s(4)
            autoPaddingEnabled: true
        }
    }

    Item {
        id: clippedContent
        anchors.fill: parent

        layer.enabled: width > 1 && height > 1
        layer.smooth: true
        layer.textureSize: Qt.size(
            Math.max(1, Math.round(width * 2 * WidgetStore.qtScale)),
            Math.max(1, Math.round(height * 2 * WidgetStore.qtScale))
        )
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: clippedContent.width
                height: clippedContent.height
                radius: WidgetStore.s(28)
            }
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (root.sizeMode === "1x1") return oneByOneComp;
                if (root.sizeMode === "1x2") return oneByTwoComp;
                if (root.sizeMode === "2x2") return twoByTwoComp;
                if (root.sizeMode === "2x3") return twoByThreeComp;
                return oneByThreeComp;
            }
        }
    }

    // 1x1: square cover + bottom scrim + compact transport
    Component {
        id: oneByOneComp
        Item {
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: root.artBg }
            Image {
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize: Qt.size(360, 360)
                visible: status === Image.Ready
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: "music_note"
                iconSize: WidgetStore.si(42)
                fill: 1
                color: root.cardFg
                opacity: 0.65
                visible: root.artUrl === ""
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.25) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
                }
            }
            RowLayout {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: WidgetStore.s(10) }
                spacing: WidgetStore.s(4)
                visible: root.hasPlayer

                Rectangle {
                    Layout.preferredWidth: WidgetStore.s(26); Layout.preferredHeight: WidgetStore.s(26)
                    radius: width / 2; color: "transparent"
                    MaterialSymbol { anchors.centerIn: parent; text: "skip_previous"; iconSize: WidgetStore.si(16); fill: 1; color: root.accent }
                    MouseArea {
                        anchors.fill: parent; enabled: root.interactive
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
                    }
                }
                Item {
                    Layout.preferredWidth: WidgetStore.s(36); Layout.preferredHeight: WidgetStore.s(36)
                    ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: root.accent }
                    MaterialSymbol { anchors.centerIn: parent; text: root.playing ? "pause" : "play_arrow"; iconSize: WidgetStore.si(18); fill: 1; color: root.onAccent }
                    MouseArea {
                        anchors.fill: parent; enabled: root.interactive
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePlay()
                    }
                }
                Rectangle {
                    Layout.preferredWidth: WidgetStore.s(26); Layout.preferredHeight: WidgetStore.s(26)
                    radius: width / 2; color: "transparent"
                    MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; iconSize: WidgetStore.si(16); fill: 1; color: root.accent }
                    MouseArea {
                        anchors.fill: parent; enabled: root.interactive
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player && root.player.canGoNext) root.player.next()
                    }
                }
            }
        }
    }

    // 1x2
    Component {
        id: oneByTwoComp
        Item {
            anchors.fill: parent
            Rectangle {
                id: art2
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: height
                color: root.artBg
                Image { anchors.fill: parent; source: root.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; sourceSize: Qt.size(360, 360); visible: status === Image.Ready }
                MaterialSymbol { anchors.centerIn: parent; text: "music_note"; iconSize: WidgetStore.si(36); fill: 1; color: root.cardFg; opacity: 0.65; visible: root.artUrl === "" }
            }
            ColumnLayout {
                anchors { left: art2.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: WidgetStore.s(12); rightMargin: WidgetStore.s(12); topMargin: WidgetStore.s(14); bottomMargin: WidgetStore.s(12) }
                spacing: WidgetStore.s(4)
                Text {
                    Layout.fillWidth: true; text: root.trackArtist; color: root.cardFg
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(13); font.weight: Font.DemiBold
                    font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true; text: root.trackTitle; color: root.cardFg; opacity: 0.68
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(11)
                    font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: WidgetStore.s(4)
                    Rectangle {
                        Layout.preferredWidth: WidgetStore.s(28); Layout.preferredHeight: WidgetStore.s(28); radius: width / 2; color: "transparent"
                        MaterialSymbol { anchors.centerIn: parent; text: "skip_previous"; iconSize: WidgetStore.si(16); fill: 1; color: root.cardFg }
                        MouseArea { anchors.fill: parent; enabled: root.interactive && root.hasPlayer; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player.canGoPrevious) root.player.previous() }
                    }
                    Item {
                        Layout.preferredWidth: WidgetStore.s(38); Layout.preferredHeight: WidgetStore.s(38)
                        ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: root.accent }
                        MaterialSymbol { anchors.centerIn: parent; text: root.playing ? "pause" : "play_arrow"; iconSize: WidgetStore.si(20); fill: 1; color: root.onAccent }
                        MouseArea { anchors.fill: parent; enabled: root.interactive && root.hasPlayer; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePlay() }
                    }
                    Rectangle {
                        Layout.preferredWidth: WidgetStore.s(28); Layout.preferredHeight: WidgetStore.s(28); radius: width / 2; color: "transparent"
                        MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; iconSize: WidgetStore.si(16); fill: 1; color: root.cardFg }
                        MouseArea { anchors.fill: parent; enabled: root.interactive && root.hasPlayer; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player.canGoNext) root.player.next() }
                    }
                }
            }
        }
    }

    // 1x3 (default, with expandable lyrics panel)
    Component {
        id: oneByThreeComp
        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width
                height: WidgetStore.s(160)

                Rectangle {
                    id: art3
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: height
                    color: root.artBg
                    Image { anchors.fill: parent; source: root.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; sourceSize: Qt.size(384, 384); visible: status === Image.Ready }
                    MaterialSymbol { anchors.centerIn: parent; text: "music_note"; iconSize: WidgetStore.si(42); fill: 1; color: root.cardFg; opacity: 0.7; visible: root.artUrl === "" }
                }

                ColumnLayout {
                    anchors { left: art3.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: WidgetStore.s(16); rightMargin: WidgetStore.s(14); topMargin: WidgetStore.s(16); bottomMargin: WidgetStore.s(14) }
                    spacing: WidgetStore.s(8)

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.showTitles
                        spacing: WidgetStore.s(2)
                        Text {
                            Layout.fillWidth: true; text: root.trackArtist; color: root.cardFg
                            font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(15); font.weight: Font.DemiBold
                            font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true; text: root.trackTitle; color: root.cardFg; opacity: 0.68
                            font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(12)
                            font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        visible: root.showControls
                        Layout.alignment: Qt.AlignRight
                        implicitWidth: row3.implicitWidth + WidgetStore.s(10)
                        implicitHeight: WidgetStore.s(44)
                        radius: height / 2
                        color: Qt.alpha(root.cardFg, 0.11)

                        RowLayout {
                            id: row3
                            anchors.centerIn: parent
                            spacing: WidgetStore.s(2)

                            Rectangle {
                                Layout.preferredWidth: WidgetStore.s(32); Layout.preferredHeight: WidgetStore.s(32); radius: width / 2
                                color: root.showLyrics ? root.accent : (lyricsBtnMouse.containsMouse ? Qt.alpha(root.cardFg, 0.14) : "transparent")
                                MaterialSymbol { anchors.centerIn: parent; text: "lyrics"; iconSize: WidgetStore.si(17); fill: root.showLyrics ? 1 : 0; color: root.showLyrics ? root.onAccent : root.cardFg }
                                MouseArea {
                                    id: lyricsBtnMouse
                                    anchors.fill: parent; enabled: root.interactive; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: WidgetStore.setCardOption(root.tileId, "showLyrics", !root.showLyrics)
                                }
                            }

                            Item {
                                Layout.preferredWidth: WidgetStore.s(42); Layout.preferredHeight: WidgetStore.s(42)
                                scale: play3Mouse.pressed ? 0.90 : 1.0
                                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                                ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: root.accent }
                                MaterialSymbol { anchors.centerIn: parent; text: root.playing ? "pause" : "play_arrow"; iconSize: WidgetStore.si(22); fill: 1; color: root.onAccent }
                                MouseArea { id: play3Mouse; anchors.fill: parent; enabled: root.interactive && root.hasPlayer; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePlay() }
                            }

                            Rectangle {
                                Layout.preferredWidth: WidgetStore.s(32); Layout.preferredHeight: WidgetStore.s(32); radius: width / 2
                                color: next3Mouse.containsMouse ? Qt.alpha(root.cardFg, 0.14) : "transparent"
                                MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; iconSize: WidgetStore.si(18); fill: 1; color: root.cardFg }
                                MouseArea { id: next3Mouse; anchors.fill: parent; enabled: root.interactive && root.hasPlayer; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player.canGoNext) root.player.next() }
                            }
                        }
                    }
                }
            }

            // Expandable lyrics drawer
            Item {
                width: parent.width
                height: Math.max(0, root.height - WidgetStore.s(160))
                visible: root.showLyrics && height > WidgetStore.s(20)

                Rectangle {
                    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                    width: parent.width - WidgetStore.s(48)
                    height: 1
                    color: Qt.alpha(root.cardFg, 0.16)
                }

                ListView {
                    id: lyricList1x3
                    anchors { fill: parent; margins: WidgetStore.s(14) }
                    clip: true
                    spacing: WidgetStore.s(6)
                    model: LyricsService.activeLines ?? []
                    currentIndex: LyricsService.currentIndex ?? -1
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: height * 0.35
                    preferredHighlightEnd: height * 0.65

                    delegate: Text {
                        required property var modelData
                        required property int index
                        readonly property bool isCur: index === lyricList1x3.currentIndex
                        width: lyricList1x3.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: String(modelData.text || modelData.line || "")
                        color: isCur ? root.accent : root.cardFg
                        opacity: isCur ? 1.0 : 0.45
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(isCur ? 14 : 12)
                        font.weight: isCur ? Font.Bold : Font.Medium
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !LyricsService.activeLines || LyricsService.activeLines.length === 0
                    text: LyricsService.isLoading ? "Searching lyrics…" : "No lyrics found"
                    color: root.cardFg
                    opacity: 0.55
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(12)
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // 2x2: big top art + centered Cookie12Sided transport
    Component {
        id: twoByTwoComp
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.artBg
                Image { anchors.fill: parent; source: root.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; sourceSize: Qt.size(512, 512); visible: status === Image.Ready }
                MaterialSymbol { anchors.centerIn: parent; text: "music_note"; iconSize: WidgetStore.si(48); fill: 1; color: root.cardFg; opacity: 0.65; visible: root.artUrl === "" }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: WidgetStore.s(14)
                Layout.rightMargin: WidgetStore.s(14)
                Layout.topMargin: WidgetStore.s(10)
                spacing: WidgetStore.s(2)
                Text {
                    Layout.fillWidth: true; text: root.trackArtist; color: root.cardFg
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(14); font.weight: Font.DemiBold
                    font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true; text: root.trackTitle; color: root.cardFg; opacity: 0.65
                    font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(12)
                    font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: WidgetStore.s(8)
                Layout.bottomMargin: WidgetStore.s(12)
                spacing: WidgetStore.s(8)

                Rectangle {
                    Layout.preferredWidth: WidgetStore.s(30); Layout.preferredHeight: WidgetStore.s(30); radius: width / 2; color: "transparent"
                    MaterialSymbol { anchors.centerIn: parent; text: "skip_previous"; iconSize: WidgetStore.si(18); fill: 1; color: root.cardFg }
                    MouseArea { anchors.fill: parent; enabled: root.interactive && root.hasPlayer; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player.canGoPrevious) root.player.previous() }
                }
                Item {
                    Layout.preferredWidth: WidgetStore.s(46); Layout.preferredHeight: WidgetStore.s(46)
                    ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: root.accent }
                    MaterialSymbol { anchors.centerIn: parent; text: root.playing ? "pause" : "play_arrow"; iconSize: WidgetStore.si(24); fill: 1; color: root.onAccent }
                    MouseArea { anchors.fill: parent; enabled: root.interactive && root.hasPlayer; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePlay() }
                }
                Rectangle {
                    Layout.preferredWidth: WidgetStore.s(30); Layout.preferredHeight: WidgetStore.s(30); radius: width / 2; color: "transparent"
                    MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; iconSize: WidgetStore.si(18); fill: 1; color: root.cardFg }
                    MouseArea { anchors.fill: parent; enabled: root.interactive && root.hasPlayer; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player.canGoNext) root.player.next() }
                }
            }
        }
    }

    // 2x3: compact header + large bottom lyrics surface
    Component {
        id: twoByThreeComp
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: WidgetStore.s(82)
                color: Qt.alpha(root.artBg, 0.7)

                RowLayout {
                    anchors { fill: parent; margins: WidgetStore.s(14) }
                    spacing: WidgetStore.s(12)

                    Rectangle {
                        Layout.preferredWidth: WidgetStore.s(54)
                        Layout.preferredHeight: WidgetStore.s(54)
                        radius: WidgetStore.s(12)
                        color: root.cardBg
                        clip: true
                        Image { anchors.fill: parent; source: root.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; sourceSize: Qt.size(160, 160); visible: status === Image.Ready }
                        MaterialSymbol { anchors.centerIn: parent; text: "music_note"; iconSize: WidgetStore.si(22); fill: 1; color: root.cardFg; visible: root.artUrl === "" }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.showTitles
                        spacing: WidgetStore.s(2)
                        Text {
                            Layout.fillWidth: true; text: root.trackTitle; color: root.cardFg
                            font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(13); font.weight: Font.DemiBold; font.italic: true
                            font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true; text: root.trackArtist; color: root.cardFg; opacity: 0.68
                            font.family: "Google Sans Flex"; font.pixelSize: WidgetStore.si(11)
                            font.hintingPreference: Font.PreferVerticalHinting; renderType: Text.NativeRendering; elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.preferredWidth: WidgetStore.s(42); Layout.preferredHeight: WidgetStore.s(42)
                        ExpressiveShape { anchors.fill: parent; shape: "cookie12"; color: root.accent }
                        MaterialSymbol { anchors.centerIn: parent; text: root.playing ? "pause" : "play_arrow"; iconSize: WidgetStore.si(22); fill: 1; color: root.onAccent }
                        MouseArea { anchors.fill: parent; enabled: root.interactive && root.hasPlayer; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePlay() }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Qt.alpha(root.cardFg, 0.10)

                ListView {
                    id: lyricList2x3
                    anchors { fill: parent; margins: WidgetStore.s(14) }
                    clip: true
                    spacing: WidgetStore.s(6)
                    model: LyricsService.activeLines ?? []
                    currentIndex: LyricsService.currentIndex ?? -1
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: height * 0.35
                    preferredHighlightEnd: height * 0.65

                    delegate: Text {
                        required property var modelData
                        required property int index
                        readonly property bool isCur: index === lyricList2x3.currentIndex
                        width: lyricList2x3.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: String(modelData.text || modelData.line || "")
                        color: isCur ? root.accent : root.cardFg
                        opacity: isCur ? 1.0 : 0.45
                        font.family: "Google Sans Flex"
                        font.pixelSize: WidgetStore.si(isCur ? 15 : 12)
                        font.weight: isCur ? Font.Bold : Font.Medium
                        font.hintingPreference: Font.PreferVerticalHinting
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !LyricsService.activeLines || LyricsService.activeLines.length === 0
                    text: LyricsService.isLoading ? "Searching lyrics…" : "No synced lyrics found"
                    color: root.cardFg
                    opacity: 0.55
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(12)
                    font.hintingPreference: Font.PreferVerticalHinting
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    End4ResizeHandle {
        id: resizeHandle
        tileId: root.tileId
        hoverActive: cardHover.hovered
        enabledHandle: root.onDesktop && root.interactive
        currentMode: root.sizeMode
        snapModes: ["1x1", "1x2", "1x3", "2x2", "2x3"]
        strokeColor: root.cardFg
    }
}
