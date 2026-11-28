import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import "../../../"
import "../../../services"
import "../../../modules/common"
import "../../"
import "../"
import "LyricsMath.js" as LM

Item {
    id: root

    property bool active: true
    property bool onDesktop: false
    property var notchRoot: null
    property string tileId: "music"

    readonly property var opts: WidgetStore.cardOptions(root.tileId)
    readonly property bool isStickerMode: root.onDesktop && WidgetStore.musicStyle === "sticker"
    readonly property bool wordByWord: opts.wordByWord !== false
    readonly property bool dimPaused: opts.dimPaused !== false
    readonly property string textScale: String(opts.textScale || "md") // "sm" | "md" | "lg"
    readonly property string tagMode: String(opts.tagMode || "always")   // "always" | "hover" | "off"
    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: hasPlayer ? String(player.trackTitle || "").trim() : ""
    readonly property string trackArtist: hasPlayer ? String(player.trackArtist || "").trim() : ""
    readonly property string trackAlbum: hasPlayer ? String(player.trackAlbum || "").trim() : ""
    readonly property string rawArtUrl: hasPlayer ? (MprisController.rawArtUrlFor(player) || String(MprisController.artUrl || "")) : ""
    readonly property string artUrl: CoverArt.source(rawArtUrl)
    readonly property real trackLength: {
        if (!hasPlayer) return 0;
        const known = MprisController.trackLengths ? MprisController.trackLengths[player.dbusName ?? ""] : null;
        if (known && known.key === MprisController.trackKeyOf(player) && known.length > 0) {
            return Number(known.length);
        }
        return (player.lengthSupported && player.length > 0) ? Number(player.length) : 0;
    }

    // Wake LyricsService cleanly whenever the card becomes visible/active
    function ensureLyricsActive() {
        if (root.active && !LyricsService.isInitialized) {
            LyricsService.initiliazeLyrics();
        }
    }
    Component.onCompleted: ensureLyricsActive()
    onActiveChanged: ensureLyricsActive()
    onTrackTitleChanged: ensureLyricsActive()

    readonly property bool pausedDim: !root.playing && root.dimPaused

    // Smooth drift-free Sekai Pop playback clock between 250ms MPRIS polls
    property var clk: LM.clockReset(0, 0)
    property real nowMs: Date.now()
    property real lastPolled: -1
    property int stalePolls: 0
    property real nudgeMs: 0
    readonly property real globalOffsetMs: (Config.options && Config.options.background && Config.options.background.mediaMode)
        ? Number(Config.options.background.mediaMode.lyricsOffsetMs || 0) : 0
    readonly property string identSig: [trackTitle, trackArtist, trackAlbum].join("\u241f")

    onIdentSigChanged: Qt.callLater(() => {
        root.nudgeMs = 0;
        root.clk = LM.clockReset(0, Date.now());
        root.lastPolled = -1;
        root.stalePolls = 0;
        root.poll();
    })

    onPlayingChanged: Qt.callLater(() => {
        const now = Date.now();
        root.clk = LM.clockReset(LM.estimate(root.clk, now, !root.playing), now);
        root.lastPolled = -1;
        root.stalePolls = 0;
        root.nowMs = now;
        root.poll();
    })

    function poll() {
        const p = root.player;
        if (!p || !p.positionSupported) return;
        p.positionChanged();
        const polled = Number(p.position);
        if (!isFinite(polled)) return;
        const trust = LM.pollTrust(root.lastPolled, polled, root.stalePolls, root.playing);
        root.lastPolled = polled;
        root.stalePolls = trust.stale;
        if (trust.use) {
            const stamp = Date.now();
            root.clk = LM.observe(root.clk, polled, stamp, root.playing);
        }
        root.nowMs = Date.now();
    }

    Timer {
        interval: 250
        repeat: true
        running: root.active && root.hasPlayer
        onTriggered: root.poll()
    }

    // Adapted lines from Dynamic You's multi-provider LyricsService
    readonly property var adaptedLines: {
        const raw = LyricsService.syncedLines;
        return LM.adaptServiceLines(raw);
    }

    readonly property real songEnd: {
        const n = adaptedLines.length;
        if (n === 0) return 0;
        let e = Math.max(endOf(n - 1), bgEndOf(n - 1));
        if (n > 1) e = Math.max(e, endOf(n - 2));
        return e;
    }

    readonly property bool animating: adaptedLines.length > 0 && clockT < songEnd + 3

    FrameAnimation {
        running: root.active && root.visible && root.playing && root.animating
        onTriggered: root.nowMs = Date.now()
    }

    readonly property real clockT: Math.max(0,
        LM.estimate(root.clk, root.nowMs, root.playing) + 0.18 + (root.globalOffsetMs + root.nudgeMs) / 1000)
    readonly property real playPositionSec: Math.max(0, root.clockT - 0.18 - (root.globalOffsetMs + root.nudgeMs) / 1000)
    readonly property real trackProgressFrac: root.trackLength > 0
        ? Math.max(0, Math.min(1, playPositionSec / root.trackLength))
        : 0

    readonly property real rate: LM.songRate(adaptedLines)
    readonly property real lead: 0.45
    readonly property int curIndex: LM.lineIndexAt(adaptedLines, clockT)
    readonly property real nextRush: takeAfter(curIndex)
    readonly property real cursorV: LM.cursor(adaptedLines, clockT, lead, nextRush)
    readonly property int baseIndex: Math.round(cursorV)

    function endOf(i) {
        const l = adaptedLines[i];
        if (!l) return 0;
        const next = i + 1 < adaptedLines.length ? adaptedLines[i + 1].t : Infinity;
        const room = next - l.t;
        if (l.text === "") return l.t + (isFinite(room) ? room : 4);
        const known = (l.end !== undefined && l.end > l.t) ? l.end - l.t : undefined;
        return l.t + LM.sungSpan(l.text, room, rate, known);
    }

    function bgEndOf(i) {
        const l = adaptedLines[i];
        if (!l || !l.bg) return 0;
        return Math.max(endOf(i), l.bg.t + LM.sungSpan(l.bg.text, Infinity, rate));
    }

    function rushAfter(i) {
        if (i < 0 || i + 1 >= adaptedLines.length) return 0;
        const l = adaptedLines[i];
        if (!l || l.text === "") return 0;
        return LM.rushOf(LM.overrun(endOf(i), LM.leaveAt(l.t, adaptedLines[i + 1].t, lead)));
    }

    function takeAfter(i) {
        if (i < 0 || i + 1 >= adaptedLines.length || adaptedLines[i].text === "") return 0;
        return LM.rushOf(LM.overrun(endOf(i), adaptedLines[i + 1].t));
    }

    readonly property string stageStatusMessage: {
        if (!hasPlayer || trackTitle === "") return "Play music for live lyrics";
        if (adaptedLines.length > 0) return "";
        if (LyricsService.searching) return "Searching lyrics…";
        if (LyricsService.instrumental) return "Instrumental track";
        if (LyricsService.hasPlainLyrics) {
            const firstLines = String(LyricsService.plainLyrics || "").split("\n").filter(s => s.trim() !== "");
            return firstLines.length > 0 ? firstLines[0].trim() : "Synced lyrics unavailable";
        }
        return "No synced lyrics found";
    }

    readonly property string plainPreviewSecondLine: {
        if (!hasPlayer || adaptedLines.length > 0 || !LyricsService.hasPlainLyrics) return "";
        const firstLines = String(LyricsService.plainLyrics || "").split("\n").filter(s => s.trim() !== "");
        return firstLines.length > 1 ? firstLines[1].trim() : "";
    }

    function fmtTime(sec) {
        const s = Math.max(0, Math.floor(sec || 0));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    function nudge(deltaMs) {
        root.nudgeMs += deltaMs;
    }

    function openFullMusic() {
        if (root.notchRoot && typeof root.notchRoot.switchMode === "function") {
            WidgetStore.closeSidebar();
            root.notchRoot.switchMode("music", false);
        }
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

    readonly property color colBg: Theme.m3.surface_container_high ?? Theme.colors.card_bg
    readonly property color colPrimary: Theme.m3.primary ?? Theme.accent
    readonly property color colOnPrimary: Theme.m3.on_primary ?? "#101014"
    readonly property color colOnSurface: Theme.m3.on_surface ?? Theme.colors.text_primary
    readonly property color colMuted: Theme.m3.on_surface_variant ?? Theme.colors.text_secondary
    readonly property color colBorder: Theme.alpha(Theme.m3.outline_variant ?? "#163a70", 0.5)

    HoverHandler {
        id: cardHover
    }

    // ---------------------------------------------------------
    // 1. CARD VESSEL (shown in Sidebar OR Desktop "Card" style)
    // ---------------------------------------------------------
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: WidgetStore.s(24)
        visible: !root.isStickerMode
        color: root.colBg
        border.width: Math.max(1, WidgetStore.s(1))
        border.color: root.colBorder
        clip: true

        // Subtle atmospheric album art glow inside card
        Image {
            anchors.fill: parent
            source: root.artUrl
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 0.16 : 0
            visible: source !== ""
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(root.colBg, 0.72) }
                GradientStop { position: 0.5; color: Qt.alpha(root.colBg, 0.86) }
                GradientStop { position: 1.0; color: Qt.alpha(root.colBg, 0.96) }
            }
        }
    }

    // ---------------------------------------------------------
    // 2. HEADER ROW (Card Mode only — hidden in OG Sticker mode!)
    // ---------------------------------------------------------
    Item {
        id: headerRow
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: WidgetStore.s(12)
            leftMargin: WidgetStore.s(14)
            rightMargin: WidgetStore.s(14)
        }
        height: WidgetStore.s(48)
        z: 5
        visible: !root.isStickerMode

        // Album Cover Art
        Rectangle {
            id: coverBox
            width: WidgetStore.s(44)
            height: WidgetStore.s(44)
            radius: WidgetStore.s(12)
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            color: Theme.m3.surface_container_highest ?? Theme.colors.hover_bg
            clip: true

            Image {
                anchors.fill: parent
                source: root.artUrl
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: source !== "" && status === Image.Ready
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.artUrl === ""
                text: "music_note"
                iconSize: WidgetStore.si(22)
                fill: 1
                color: root.colPrimary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (MprisController.players && MprisController.players.length > 1) root.cyclePlayer();
                    else root.openFullMusic();
                }
            }
        }

        // Title + Artist
        Column {
            anchors {
                left: coverBox.right
                right: transportRow.left
                verticalCenter: parent.verticalCenter
                leftMargin: WidgetStore.s(10)
                rightMargin: WidgetStore.s(8)
            }
            spacing: 1

            Text {
                width: parent.width
                text: root.trackTitle !== "" ? root.trackTitle : "Nothing Playing"
                color: root.colOnSurface
                font.family: "Google Sans Flex"
                font.pixelSize: WidgetStore.si(15)
                font.weight: Font.Bold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                text: root.trackArtist !== "" ? root.trackArtist : (LyricsService.syncedSourceName || "Sekai Lyrics")
                color: root.colMuted
                font.family: "Noto Sans"
                font.pixelSize: WidgetStore.si(12)
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }

        // Transport Buttons
        Row {
            id: transportRow
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: WidgetStore.s(4)

            TransportBtn {
                icon: "skip_previous"
                enabled: root.hasPlayer && root.player.canGoPrevious
                onClicked: if (root.player) root.player.previous()
            }

            Rectangle {
                width: WidgetStore.s(34)
                height: WidgetStore.s(34)
                radius: WidgetStore.s(17)
                anchors.verticalCenter: parent.verticalCenter
                color: playMouse.pressed ? Qt.darker(root.colPrimary, 1.1) : root.colPrimary
                opacity: (root.hasPlayer && (root.player.canTogglePlaying || root.player.canPlay || root.player.canPause)) ? 1.0 : 0.45

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.playing ? "pause" : "play_arrow"
                    iconSize: WidgetStore.si(19)
                    fill: 1
                    color: root.colOnPrimary
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player) root.player.togglePlaying()
                }
            }

            TransportBtn {
                icon: "skip_next"
                enabled: root.hasPlayer && root.player.canGoNext
                onClicked: if (root.player) root.player.next()
            }
        }
    }

    // ---------------------------------------------------------
    // 3. SEKAI POP STICKER LYRICS STAGE
    // ---------------------------------------------------------
    Item {
        id: lyricsStage
        anchors {
            top: root.isStickerMode ? parent.top : headerRow.bottom
            bottom: footerRow.top
            left: parent.left
            right: parent.right
            topMargin: root.isStickerMode ? WidgetStore.s(4) : WidgetStore.s(2)
            bottomMargin: WidgetStore.s(2)
        }
        clip: !root.isStickerMode

        readonly property real midY: height / 2
        readonly property int scaleBaseSticker: root.textScale === "sm" ? 30 : (root.textScale === "lg" ? 44 : 38)
        readonly property int scaleBaseCard: root.textScale === "sm" ? 24 : (root.textScale === "lg" ? 34 : 30)
        readonly property int wordPx: WidgetStore.si(root.isStickerMode ? scaleBaseSticker : scaleBaseCard)
        readonly property real poseScale: root.isStickerMode ? 0.94 : 0.78
        readonly property real maxLineW: root.isStickerMode ? WidgetStore.s(680) : (lyricsStage.width - WidgetStore.s(20))

        // Live 3-line expressive word-sync stack
        Repeater {
            model: root.adaptedLines.length

            delegate: Loader {
                id: lineLoader
                required property int index
                active: Math.abs(lineLoader.index - root.baseIndex) <= 2

                sourceComponent: SekaiLyricsLine {
                    text: root.adaptedLines[lineLoader.index] ? root.adaptedLines[lineLoader.index].text : ""
                    index: lineLoader.index
                    curIndex: root.curIndex
                    lineStart: root.adaptedLines[lineLoader.index] ? root.adaptedLines[lineLoader.index].t : 0
                    lineEnd: root.endOf(lineLoader.index)
                    rush: root.rushAfter(lineLoader.index)
                    prevRush: root.rushAfter(lineLoader.index - 1)
                    prevEnd: lineLoader.index > 0 ? root.endOf(lineLoader.index - 1) : 0
                    marks: (root.adaptedLines[lineLoader.index] && root.adaptedLines[lineLoader.index].marks)
                        ? root.adaptedLines[lineLoader.index].marks : []
                    bgText: (root.adaptedLines[lineLoader.index] && root.adaptedLines[lineLoader.index].bg)
                        ? root.adaptedLines[lineLoader.index].bg.text : ""
                    bgStart: (root.adaptedLines[lineLoader.index] && root.adaptedLines[lineLoader.index].bg)
                        ? root.adaptedLines[lineLoader.index].bg.t : 0
                    bgEnd: root.bgEndOf(lineLoader.index)
                    t: root.clockT
                    d: lineLoader.index - root.cursorV
                    playing: !root.pausedDim
                    lineOnly: !root.wordByWord
                    maxW: lyricsStage.maxLineW
                    px: lyricsStage.wordPx
                    poseScaleY: lyricsStage.poseScale
                    cx: lyricsStage.width / 2
                    cy: lyricsStage.midY
                }
            }
        }

        // Empty / searching / plain-lyrics sticker fallback
        SekaiLyricsLine {
            visible: root.stageStatusMessage !== "" && root.adaptedLines.length === 0
            still: true
            text: root.stageStatusMessage
            px: WidgetStore.si(root.isStickerMode ? 28 : 22)
            d: 0
            playing: true
            poseScaleY: lyricsStage.poseScale
            maxW: lyricsStage.maxLineW
            cx: lyricsStage.width / 2
            cy: root.plainPreviewSecondLine !== "" ? (lyricsStage.midY - WidgetStore.s(22)) : lyricsStage.midY
        }

        SekaiLyricsLine {
            visible: root.plainPreviewSecondLine !== "" && root.adaptedLines.length === 0
            still: true
            text: root.plainPreviewSecondLine
            px: WidgetStore.si(root.isStickerMode ? 20 : 17)
            d: 1
            playing: true
            poseScaleY: lyricsStage.poseScale
            maxW: lyricsStage.maxLineW
            cx: lyricsStage.width / 2
            cy: lyricsStage.midY + WidgetStore.s(6)
        }
    }

    // ---------------------------------------------------------
    // 4. OG SEKAI POP STICKER HOVER KEYS + TAG & CARD FOOTER
    // ---------------------------------------------------------
    Item {
        id: footerRow
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            bottomMargin: root.isStickerMode ? WidgetStore.s(2) : WidgetStore.s(10)
            leftMargin: WidgetStore.s(16)
            rightMargin: WidgetStore.s(16)
        }
        height: root.isStickerMode ? WidgetStore.s(54) : WidgetStore.s(40)
        z: 5

        // OG Sekai Pop hover sticker keys row (no card chrome behind it)
        Row {
            id: stickerKeysRow
            visible: root.isStickerMode && opacity > 0.01
            opacity: (root.isStickerMode && cardHover.hovered) ? 1.0 : 0.0
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: stickerTagHolder.top
                bottomMargin: WidgetStore.s(5)
            }
            spacing: WidgetStore.s(14)

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            SekaiLyricsKey {
                visible: root.adaptedLines.length > 0
                label: "<< earlier"
                onClicked: root.nudge(100)
            }

            SekaiLyricsKey {
                visible: root.adaptedLines.length > 0
                readonly property real totalS: (root.globalOffsetMs + root.nudgeMs) / 1000
                label: (totalS >= 0 ? "+" : "") + totalS.toFixed(1) + " s"
                onClicked: root.nudgeMs = 0
            }

            SekaiLyricsKey {
                visible: root.adaptedLines.length > 0
                label: "later >>"
                onClicked: root.nudge(-100)
            }

            SekaiLyricsKey {
                visible: root.hasPlayer
                label: root.playing ? "pause" : "play"
                onClicked: if (root.player) root.player.togglePlaying()
            }

            SekaiLyricsKey {
                visible: root.hasPlayer && root.player.canGoNext
                label: "next"
                onClicked: if (root.player) root.player.next()
            }

            SekaiLyricsKey {
                label: "music"
                onClicked: root.openFullMusic()
            }
        }

        // OG Sekai Pop small track title - artist sticker tag at bottom
        Item {
            id: stickerTagHolder
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: WidgetStore.s(2)
            }
            width: Math.min(lyricsStage.maxLineW, stickerTagWord.implicitWidth + WidgetStore.s(30))
            height: WidgetStore.s(24)
            visible: root.isStickerMode && root.tagMode !== "off" && opacity > 0.01
            opacity: {
                if (!root.isStickerMode || root.tagMode === "off") return 0.0;
                if (root.tagMode === "hover") return cardHover.hovered ? 0.96 : 0.0;
                return cardHover.hovered ? 1.0 : 0.78;
            }

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Row {
                anchors.centerIn: parent
                spacing: WidgetStore.s(6)

                Rectangle {
                    width: WidgetStore.s(18)
                    height: WidgetStore.s(18)
                    radius: WidgetStore.s(5)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.artUrl !== ""
                    clip: true
                    color: "transparent"
                    Image {
                        anchors.fill: parent
                        source: root.artUrl
                        sourceSize: Qt.size(64, 64)
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                SekaiLyricsWord {
                    id: stickerTagWord
                    anchors.verticalCenter: parent.verticalCenter
                    pixelSize: WidgetStore.si(14)
                    fillColor: cardHover.hovered ? (Theme.m3.primary ?? "#95f0d2") : "#FFFFFF"
                    text: {
                        if (root.trackTitle === "") return "play music for live lyrics";
                        const raw = root.trackArtist ? (root.trackTitle + " - " + root.trackArtist) : root.trackTitle;
                        return raw.length > 52 ? raw.slice(0, 50) + "..." : raw;
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.isStickerMode
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (MprisController.players && MprisController.players.length > 1) root.cyclePlayer();
                    else root.openFullMusic();
                }
            }
        }

        // Full progress + sync nudge bar (Card mode only)
        Item {
            anchors.fill: parent
            visible: !root.isStickerMode
            opacity: !root.isStickerMode ? 1.0 : 0.0

            ColumnLayout {
                anchors.fill: parent
                spacing: WidgetStore.s(4)

            // Frosted capsule backing in Sticker hover mode
            // Progress bar + times
            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(8)
                visible: root.trackLength > 0

                Text {
                    text: root.fmtTime(root.playPositionSec)
                    color: root.colMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: WidgetStore.si(10)
                    renderType: Text.NativeRendering
                }

                Item {
                    Layout.fillWidth: true
                    height: WidgetStore.s(14)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: WidgetStore.s(4)
                        radius: WidgetStore.s(2)
                        color: Qt.alpha(root.colOnSurface, 0.14)

                        Rectangle {
                            width: parent.width * root.trackProgressFrac
                            height: parent.height
                            radius: WidgetStore.s(2)
                            color: root.colPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.hasPlayer && root.player.canSeek && root.trackLength > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        function seekTo(px) {
                            const f = Math.max(0, Math.min(1, px / Math.max(1, width)));
                            const sec = f * root.trackLength;
                            root.player.position = sec;
                            root.clk = LM.clockReset(sec, Date.now());
                            root.nowMs = Date.now();
                        }
                        onClicked: (e) => seekTo(e.x)
                        onPositionChanged: (e) => { if (pressed) seekTo(e.x); }
                    }
                }

                Text {
                    text: root.fmtTime(root.trackLength)
                    color: root.colMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: WidgetStore.si(10)
                    renderType: Text.NativeRendering
                }
            }

            // Sync nudge pills & provider badge
            RowLayout {
                Layout.fillWidth: true
                spacing: WidgetStore.s(6)

                Rectangle {
                    visible: LyricsService.syncedSourceName !== ""
                    height: WidgetStore.s(18)
                    width: srcTxt.implicitWidth + WidgetStore.s(12)
                    radius: WidgetStore.s(6)
                    color: Qt.alpha(root.colPrimary, 0.14)

                    Text {
                        id: srcTxt
                        anchors.centerIn: parent
                        text: LyricsService.syncedSourceName
                        color: root.colPrimary
                        font.family: "Noto Sans"
                        font.pixelSize: WidgetStore.si(10)
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }
                }

                Item { Layout.fillWidth: true }

                Row {
                    visible: root.adaptedLines.length > 0
                    spacing: WidgetStore.s(4)

                    NudgeBtn {
                        label: "-0.1s"
                        onClicked: root.nudge(-100)
                    }
                    NudgeBtn {
                        readonly property real totalS: (root.globalOffsetMs + root.nudgeMs) / 1000
                        label: (totalS >= 0 ? "+" : "") + totalS.toFixed(1) + "s"
                        highlighted: Math.abs(root.nudgeMs) >= 50
                        onClicked: root.nudgeMs = 0
                    }
                    NudgeBtn {
                        label: "+0.1s"
                        onClicked: root.nudge(100)
                    }
                }
            }
        }
        }
    }

    component TransportBtn: Rectangle {
        property string icon: ""
        signal clicked()

        width: WidgetStore.s(28)
        height: WidgetStore.s(28)
        radius: WidgetStore.s(14)
        anchors.verticalCenter: parent.verticalCenter
        color: tMouse.containsMouse ? Qt.alpha(root.colOnSurface, 0.12) : "transparent"
        opacity: enabled ? 1.0 : 0.35

        MaterialSymbol {
            anchors.centerIn: parent
            text: parent.icon
            iconSize: WidgetStore.si(18)
            color: root.colOnSurface
        }

        MouseArea {
            id: tMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component SekaiLyricsKey: Item {
        property string label: ""
        signal clicked()

        implicitWidth: keyWord.implicitWidth
        implicitHeight: keyWord.implicitHeight
        width: implicitWidth
        height: implicitHeight
        anchors.verticalCenter: parent.verticalCenter

        scale: skMouse.pressed ? 0.94 : (skMouse.containsMouse ? 1.12 : 1.0)
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }

        SekaiLyricsWord {
            id: keyWord
            text: parent.label
            pixelSize: WidgetStore.si(14)
            fillColor: skMouse.containsMouse ? (Theme.m3.primary ?? "#95f0d2") : "#FFFFFF"
        }

        MouseArea {
            id: skMouse
            anchors.fill: parent
            anchors.margins: -WidgetStore.s(5)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component NudgeBtn: Rectangle {
        property string label: ""
        property bool highlighted: false
        signal clicked()

        height: WidgetStore.s(18)
        width: nLbl.implicitWidth + WidgetStore.s(10)
        radius: WidgetStore.s(6)
        color: nMouse.containsMouse || highlighted
            ? Qt.alpha(root.colPrimary, 0.20)
            : Qt.alpha(root.colOnSurface, 0.08)

        Text {
            id: nLbl
            anchors.centerIn: parent
            text: parent.label
            color: parent.highlighted ? root.colPrimary : root.colMuted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: WidgetStore.si(9)
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: nMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
