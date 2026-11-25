import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../../"
import "../../../services"
import "../../"
import "../"

Item {
    id: root

    property bool active: true
    property bool interactive: true
    readonly property var opts: WidgetStore.cardOptions("media")
    readonly property bool showDuration: opts.showDuration !== false
    readonly property bool showArt: opts.showArt !== false
    readonly property bool showBadge: opts.showBadge !== false

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null && root.player !== undefined
    readonly property bool playing: root.hasPlayer && root.player.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: root.hasPlayer ? String(root.player.trackTitle || "") : ""
    readonly property string trackArtist: root.hasPlayer ? String(root.player.trackArtist || "") : ""
    readonly property string artUrl: root.hasPlayer ? String(root.player.trackArtUrl || "") : ""
    readonly property real trackLength: {
        if (!root.hasPlayer) return 0;
        if (root.player.lengthSupported && Number(root.player.length) > 0)
            return Number(root.player.length);
        if (root.player.metadata && root.player.metadata["mpris:length"])
            return Number(root.player.metadata["mpris:length"]) / 1000000;
        return 0;
    }

    property real positionSec: 0

    readonly property color accent: Theme.m3.primary ?? Theme.accent
    readonly property color onAccent: Theme.m3.on_primary ?? "#101014"
    readonly property color secondary: Theme.m3.secondary ?? "#67e8f9"
    readonly property color fg: Theme.m3.on_surface ?? Theme.colors.text_primary
    readonly property color muted: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary

    function formatTime(seconds) {
        const total = Math.max(0, Math.round(Number(seconds) || 0));
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    function refreshPosition() {
        const p = root.player;
        if (!p) {
            root.positionSec = 0;
            return;
        }
        if (typeof p.positionChanged === "function") p.positionChanged();
        root.positionSec = Math.max(0, Number(p.position) || 0);
    }

    function cyclePlayer() {
        if (MprisController.players && MprisController.players.length > 1) {
            const list = MprisController.players;
            let idx = -1;
            for (let i = 0; i < list.length; i++) {
                if (list[i] === root.player) { idx = i; break; }
            }
            MprisController.setActivePlayer(list[(idx + 1) % list.length]);
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.active && root.hasPlayer
        onTriggered: root.refreshPosition()
    }

    Connections {
        target: root.player
        function onTrackTitleChanged() { root.refreshPosition(); }
        function onPlaybackStateChanged() { root.refreshPosition(); }
    }

    Component.onCompleted: root.refreshPosition()

    SekaiPill {
        anchors.fill: parent
        cornerRadius: WidgetStore.s(22)
        borderWidth: WidgetStore.s(2.5)
        ringWidth: WidgetStore.s(3)
        shadowDx: WidgetStore.s(3)
        shadowDy: WidgetStore.s(4)
        fillColor: Theme.m3.surface_container ?? Theme.colors.card_bg
        ringColor: Qt.alpha(root.accent, 0.24)

        // Subtle accent circle behind art
        Rectangle {
            width: WidgetStore.s(210)
            height: width
            radius: width / 2
            x: WidgetStore.s(12)
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(root.accent, 0.14)
        }

        // Framed square album cover with Sekai Pop outline & ON AIR chip
        SekaiPill {
            id: artFrame
            visible: root.showArt
            width: root.showArt ? WidgetStore.s(208) : 0
            height: WidgetStore.s(208)
            anchors {
                left: parent.left
                leftMargin: WidgetStore.s(18)
                verticalCenter: parent.verticalCenter
            }
            cornerRadius: WidgetStore.s(18)
            borderWidth: WidgetStore.s(2.5)
            ringWidth: WidgetStore.s(2.5)
            shadowDx: WidgetStore.s(2)
            shadowDy: WidgetStore.s(3)
            fillColor: Theme.m3.surface_container_lowest ?? "#0b0b12"
            ringColor: root.accent

            Image {
                id: artImage
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize: Qt.size(
                    Math.min(512, Math.max(96, Math.round(width * 2 * WidgetStore.qtScale))),
                    Math.min(512, Math.max(96, Math.round(height * 2 * WidgetStore.qtScale)))
                )
                visible: status === Image.Ready
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: !artImage.visible
                text: "album"
                iconSize: WidgetStore.si(64)
                color: root.muted
            }

            SekaiPill {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    margins: WidgetStore.s(8)
                }
                width: artTag.implicitWidth + WidgetStore.s(16)
                height: WidgetStore.s(22)
                cornerRadius: WidgetStore.s(7)
                borderWidth: WidgetStore.s(1.8)
                ringWidth: WidgetStore.s(1.5)
                shadowDy: WidgetStore.s(2)
                rotation: -3
                fillColor: root.playing ? root.accent : (Theme.m3.surface_container_highest ?? Theme.colors.hover_bg)
                visible: root.hasPlayer && root.showBadge

                Text {
                    id: artTag
                    anchors.centerIn: parent
                    text: root.playing ? "ON AIR" : "PAUSED"
                    color: root.playing ? root.onAccent : root.fg
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(9)
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.8
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.interactive && MprisController.players && MprisController.players.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.cyclePlayer()
            }
        }

        // Right column: NOW PLAYING pill + Title/Artist + Seek bar + SekaiPill transport buttons
        Item {
            id: infoColumn
            anchors {
                left: root.showArt ? artFrame.right : parent.left
                leftMargin: WidgetStore.s(18)
                right: parent.right
                rightMargin: WidgetStore.s(18)
                top: parent.top
                topMargin: WidgetStore.s(18)
                bottom: parent.bottom
                bottomMargin: WidgetStore.s(16)
            }
            visible: root.hasPlayer

            SekaiPill {
                id: nowPlayingTag
                width: tagLabel.implicitWidth + WidgetStore.s(18)
                height: WidgetStore.s(22)
                cornerRadius: WidgetStore.s(7)
                borderWidth: WidgetStore.s(1.8)
                ringWidth: WidgetStore.s(1.5)
                shadowDy: WidgetStore.s(2)
                rotation: 1.8
                fillColor: root.secondary

                Text {
                    id: tagLabel
                    anchors.centerIn: parent
                    text: "MEDIA PLAYER"
                    color: Theme.m3.on_secondary ?? "#030a16"
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(9)
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.9
                    renderType: Text.NativeRendering
                }
            }

            Text {
                id: titleText
                anchors {
                    top: nowPlayingTag.bottom
                    topMargin: WidgetStore.s(10)
                    left: parent.left
                    right: parent.right
                }
                text: root.trackTitle || "Unknown track"
                color: root.fg
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(20)
                font.weight: Font.ExtraBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 0.96
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
            }

            Text {
                id: artistText
                anchors {
                    top: titleText.bottom
                    topMargin: WidgetStore.s(4)
                    left: parent.left
                    right: parent.right
                }
                text: root.trackArtist || "Unknown artist"
                color: root.muted
                font.family: "Noto Sans"
                font.pixelSize: WidgetStore.si(12)
                font.weight: Font.Medium
                elide: Text.ElideRight
                font.hintingPreference: Font.PreferVerticalHinting
                renderType: Text.NativeRendering
            }

            RowLayout {
                id: timeRow
                visible: root.showDuration
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: progressTrack.top
                    bottomMargin: WidgetStore.s(4)
                }

                Text {
                    text: root.formatTime(root.positionSec)
                    color: root.muted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: WidgetStore.si(10)
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                Item { Layout.fillWidth: true }

                Text {
                    id: timeEnd
                    text: root.trackLength > 0 ? root.formatTime(root.trackLength) : "--:--"
                    color: root.muted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: WidgetStore.si(10)
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }

            Item {
                id: progressTrack
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: controlsRow.top
                    bottomMargin: WidgetStore.s(12)
                }
                height: WidgetStore.s(16)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: WidgetStore.s(8)
                    radius: height / 2
                    color: Qt.alpha(root.fg, 0.14)
                    border.width: WidgetStore.s(1.5)
                    border.color: Qt.darker(Theme.m3.surface_container_lowest ?? "#030a16", 1.35)

                    Rectangle {
                        readonly property real frac: root.trackLength > 0
                            ? Math.max(0, Math.min(1, root.positionSec / root.trackLength))
                            : 0
                        width: Math.max(frac > 0 ? height : 0, parent.width * frac)
                        height: parent.height
                        radius: height / 2
                        color: root.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.interactive && root.hasPlayer && root.player.canSeek && root.trackLength > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    function seekAt(px) {
                        const f = Math.max(0, Math.min(1, px / Math.max(1, width)));
                        const sec = f * root.trackLength;
                        root.player.position = sec;
                        root.positionSec = sec;
                    }
                    onClicked: (e) => seekAt(e.x)
                    onPositionChanged: (e) => { if (pressed) seekAt(e.x); }
                }
            }

            Row {
                id: controlsRow
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                spacing: WidgetStore.s(10)

                TransportKey {
                    iconName: "skip_previous"
                    keySize: WidgetStore.s(42)
                    keyEnabled: root.hasPlayer && root.player.canGoPrevious
                    onTriggered: if (root.player) root.player.previous()
                }

                TransportKey {
                    iconName: root.playing ? "pause" : "play_arrow"
                    keySize: WidgetStore.s(50)
                    primary: true
                    keyEnabled: root.hasPlayer
                    onTriggered: if (root.player) root.player.togglePlaying()
                }

                TransportKey {
                    iconName: "skip_next"
                    keySize: WidgetStore.s(42)
                    keyEnabled: root.hasPlayer && root.player.canGoNext
                    onTriggered: if (root.player) root.player.next()
                }
            }
        }

        // Empty state
        Item {
            anchors.fill: parent
            visible: !root.hasPlayer

            Column {
                anchors.centerIn: parent
                spacing: WidgetStore.s(10)

                SekaiPill {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: WidgetStore.s(56)
                    height: WidgetStore.s(56)
                    cornerRadius: WidgetStore.s(28)
                    borderWidth: WidgetStore.s(2.5)
                    ringWidth: WidgetStore.s(2)
                    shadowDy: WidgetStore.s(3)
                    fillColor: root.accent

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "music_note"
                        iconSize: WidgetStore.si(28)
                        fill: 1
                        color: root.onAccent
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing Playing"
                    color: root.fg
                    font.family: "Google Sans Flex"
                    font.pixelSize: WidgetStore.si(16)
                    font.weight: Font.ExtraBold
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Play media in any app"
                    color: root.muted
                    font.family: "Noto Sans"
                    font.pixelSize: WidgetStore.si(11)
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    component TransportKey: Item {
        property string iconName: ""
        property real keySize: WidgetStore.s(42)
        property bool primary: false
        property bool keyEnabled: true
        signal triggered()

        width: keySize
        height: keySize
        anchors.verticalCenter: parent.verticalCenter
        opacity: keyEnabled ? 1.0 : 0.42

        SekaiPill {
            anchors.fill: parent
            cornerRadius: width / 2
            borderWidth: WidgetStore.s(2)
            ringWidth: WidgetStore.s(2)
            shadowDy: WidgetStore.s(3)
            pressed: tMouse.pressed && keyEnabled
            fillColor: primary
                ? root.accent
                : (tMouse.containsMouse
                    ? (Theme.m3.surface_container_highest ?? Theme.colors.hover_bg)
                    : (Theme.m3.surface_container_high ?? Theme.colors.card_bg))

            MaterialSymbol {
                anchors.centerIn: parent
                text: iconName
                iconSize: WidgetStore.si(primary ? 24 : 19)
                fill: 1
                color: primary ? root.onAccent : root.fg
            }
        }

        MouseArea {
            id: tMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.interactive && keyEnabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: triggered()
        }
    }
}
