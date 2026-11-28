pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs
import qs.services

Item {
    id: root

    property var player: MprisController.activePlayer
    property bool active: visible
    property string styleMode: "card" // "card" | "bare"
    readonly property bool hasPlayer: root.player !== null && root.player !== undefined
    readonly property string trackTitle: root.hasPlayer ? (root.player.trackTitle || root.player.identity || "Nothing playing") : "Nothing playing"
    readonly property string trackArtist: root.hasPlayer ? (root.player.trackArtist || root.player.identity || "") : "Your music appears here"

    readonly property color ink: "#ffffff"
    readonly property color inkSecondary: Qt.rgba(1, 1, 1, 0.72)
    readonly property color inkTertiary: Qt.rgba(1, 1, 1, 0.56)
    readonly property color discBg: Qt.rgba(1, 1, 1, 0.16)
    readonly property color discHover: Qt.rgba(1, 1, 1, 0.26)

    readonly property string rawArtUrl: {
        if (!root.hasPlayer) return "";
        const u = MprisController.rawArtUrlFor(root.player);
        if (u.length > 0) return u;
        return MprisController.artUrl ? String(MprisController.artUrl) : "";
    }
    readonly property string displayArt: CoverArt.source(root.rawArtUrl)

    property real posSec: 0
    property real lenSec: 0
    readonly property bool isPlaying: root.hasPlayer && (root.player.playbackState === MprisPlaybackState.Playing || root.player.isPlaying)
    readonly property bool hasTimeline: root.hasPlayer && root.lenSec > 1
    readonly property bool canSeekBy: root.hasTimeline && (root.player?.canSeek ?? false)
    readonly property bool canShuffle: root.hasPlayer && (root.player?.shuffleSupported ?? false) && (root.player?.canControl ?? false)
    readonly property bool canLoop: root.hasPlayer && (root.player?.loopSupported ?? false) && (root.player?.canControl ?? false)
    readonly property int loopState: root.player?.loopState ?? MprisLoopState.None

    function fmtTime(sec) {
        const s = Math.max(0, Math.floor(sec));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + String(r).padStart(2, "0");
    }

    function syncProgress(): void {
        if (!root.hasPlayer) {
            root.posSec = 0;
            root.lenSec = 0;
            return;
        }
        const len = MprisController.trackLengthOf(root.player) || root.player.length || 0;
        const pos = MprisController.trackPositionOf(root.player) || root.player.position || 0;
        root.lenSec = len > 0 ? len : 0;
        root.posSec = Math.max(0, Math.min(root.lenSec > 0 ? root.lenSec : pos, pos));
    }

    Timer {
        interval: 250
        repeat: true
        running: root.active && root.hasPlayer
        triggeredOnStart: true
        onTriggered: root.syncProgress()
    }

    implicitWidth: 380
    implicitHeight: body.implicitHeight + 28

    component CardIcon: Text {
        property bool filled: false
        font.family: Theme.fontFamilyIcon
        font.pixelSize: 20
        font.variableAxes: ({ "FILL": filled ? 1 : 0, "GRAD": Theme.fontIconGrad, "opsz": 24, "wght": 500 })
        renderType: Text.CurveRendering
        font.hintingPreference: Font.PreferNoHinting
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.ink
    }

    component CardText: Text {
        property bool tabular: false
        property int weightAxis: 540
        font.family: "Google Sans Flex"
        font.pixelSize: 13
        font.weight: weightAxis >= 640 ? Font.Bold : (weightAxis >= 560 ? Font.DemiBold : Font.Medium)
        font.variableAxes: ({ "wght": weightAxis })
        font.features: tabular ? ({ "tnum": 1 }) : ({})
        renderType: Text.QtRendering
        font.hintingPreference: Font.PreferNoHinting
        color: root.ink
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        // Top: Cover art + Title + Artist
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            ClippingRectangle {
                Layout.preferredWidth: 74
                Layout.preferredHeight: 74
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.12)

                Image {
                    id: coverImg
                    anchors.fill: parent
                    source: root.displayArt
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                CardIcon {
                    anchors.centerIn: parent
                    visible: coverImg.status !== Image.Ready
                    text: "music_note"
                    font.pixelSize: 28
                    color: Qt.rgba(1, 1, 1, 0.65)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                CardText {
                    Layout.fillWidth: true
                    text: root.trackTitle
                    font.pixelSize: 15
                    weightAxis: 680
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                CardText {
                    Layout.fillWidth: true
                    text: root.trackArtist
                    font.pixelSize: 12
                    weightAxis: 500
                    color: root.inkSecondary
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        // Timeline Scrubber
        RowLayout {
            Layout.fillWidth: true
            visible: root.hasTimeline
            spacing: 10

            CardText {
                Layout.minimumWidth: 32
                text: root.fmtTime(root.posSec)
                font.pixelSize: 11
                weightAxis: 520
                tabular: true
                color: root.inkTertiary
            }

            Item {
                id: scrubBox
                Layout.fillWidth: true
                height: 18

                readonly property real progress: root.lenSec > 0 ? Math.max(0, Math.min(1, root.posSec / root.lenSec)) : 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: scrubMouse.pressed ? 8 : 5
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.20)
                    Behavior on height { NumberAnimation { duration: 110 } }

                    Rectangle {
                        width: parent.width * scrubBox.progress
                        height: parent.height
                        radius: parent.radius
                        color: root.ink
                    }
                }

                MouseArea {
                    id: scrubMouse
                    anchors.fill: parent
                    enabled: root.player?.canSeek ?? false
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => {
                        const frac = Math.max(0, Math.min(1, mouse.x / Math.max(1, width)));
                        MprisController.seekFraction(root.player, frac);
                        root.posSec = frac * root.lenSec;
                    }
                }
            }

            CardText {
                Layout.minimumWidth: 36
                horizontalAlignment: Text.AlignRight
                text: "-" + root.fmtTime(Math.max(0, root.lenSec - root.posSec))
                font.pixelSize: 11
                weightAxis: 520
                tabular: true
                color: root.inkTertiary
            }
        }

        // Apple-style 5-button transport row
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.hasPlayer
            spacing: 10

            // Shuffle or -10s
            Rectangle {
                visible: root.canShuffle || root.canSeekBy
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: shfM.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"

                CardIcon {
                    anchors.centerIn: parent
                    text: root.canShuffle ? "shuffle" : "replay_10"
                    font.pixelSize: 18
                    color: (root.canShuffle && (root.player?.shuffle ?? false)) ? Theme.accent : root.inkSecondary
                }
                MouseArea {
                    id: shfM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.canShuffle) root.player.shuffle = !(root.player?.shuffle ?? false);
                        else if (root.lenSec > 0) MprisController.seekFraction(root.player, Math.max(0, (root.posSec - 10) / root.lenSec));
                    }
                }
            }

            // Previous
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                opacity: (root.player?.canGoPrevious ?? true) ? 1.0 : 0.4
                color: prevM.containsMouse ? root.discHover : Qt.rgba(1, 1, 1, 0.10)

                CardIcon {
                    anchors.centerIn: parent
                    text: "skip_previous"
                    font.pixelSize: 22
                    filled: true
                }
                MouseArea {
                    id: prevM
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.player?.canGoPrevious ?? true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.previous()
                }
            }

            // Play/Pause Hero Disc
            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 24
                color: ppM.pressed ? Qt.rgba(1, 1, 1, 0.34) : (ppM.containsMouse ? root.discHover : root.discBg)
                scale: ppM.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                CardIcon {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "pause" : "play_arrow"
                    font.pixelSize: 26
                    filled: true
                }
                MouseArea {
                    id: ppM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.togglePlaying()
                }
            }

            // Next
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                opacity: (root.player?.canGoNext ?? true) ? 1.0 : 0.4
                color: nxtM.containsMouse ? root.discHover : Qt.rgba(1, 1, 1, 0.10)

                CardIcon {
                    anchors.centerIn: parent
                    text: "skip_next"
                    font.pixelSize: 22
                    filled: true
                }
                MouseArea {
                    id: nxtM
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.player?.canGoNext ?? true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.next()
                }
            }

            // Repeat or +10s
            Rectangle {
                visible: root.canLoop || root.canSeekBy
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: repM.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"

                CardIcon {
                    anchors.centerIn: parent
                    text: !root.canLoop ? "forward_10" : (root.loopState === MprisLoopState.Track ? "repeat_one" : "repeat")
                    font.pixelSize: 18
                    color: (root.canLoop && root.loopState !== MprisLoopState.None) ? Theme.accent : root.inkSecondary
                }
                MouseArea {
                    id: repM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.canLoop) {
                            root.player.loopState = root.loopState === MprisLoopState.None
                                ? MprisLoopState.Playlist
                                : (root.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
                        } else if (root.lenSec > 0) {
                            MprisController.seekFraction(root.player, Math.min(1, (root.posSec + 10) / root.lenSec));
                        }
                    }
                }
            }
        }
    }
}
