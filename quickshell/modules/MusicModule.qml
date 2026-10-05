pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../"

Item {
    id: musicModule
    Layout.fillWidth: true
    Layout.fillHeight: true
    focus: true
    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    // ========================================================
    // 1. MPRIS PLAYER DISCOVERY & SELECTION ENGINE (Iris 1:1)
    // ========================================================
    property var manualPlayer: null
    property bool isDraggingAnyStream: false
    readonly property bool isDraggingSeek: (typeof timelineScrubber !== "undefined" && timelineScrubber.isDragging) || isDraggingAnyStream

    function togglePanel(panelName) {
        // Compatibility stub for shell IPC
    }

    function isRealPlayer(p) {
        if (!p) return false;
        const name = (p.dbusName ?? "").toLowerCase();
        if (!name) return false;

        // 1. Drop playerctld proxy
        if (name.startsWith("org.mpris.MediaPlayer2.playerctld")) return false;

        // 2. Drop Twitter / X noise
        const rawUrl = (p.metadata?.["xesam:url"] ?? "").toLowerCase();
        const lowerTitle = (p.trackTitle ?? "").toLowerCase();
        if (rawUrl.includes("x.com") || rawUrl.includes("twitter.com") ||
            lowerTitle.includes(" on x:") || lowerTitle.includes(" / x")) {
            return false;
        }

        // 3. Browser players (Brave, Chrome, Firefox, Chromium, Zen, Opera, etc.)
        const isBrowser = name.includes("brave") || name.includes("chrome") ||
                          name.includes("chromium") || name.includes("firefox") ||
                          name.includes("zen") || name.includes("vivaldi") ||
                          name.includes("opera") || name.includes("plasma-browser-integration");

        if (isBrowser) {
            // Actively playing ALWAYS accepted immediately!
            if (p.playbackState === MprisPlaybackState.Playing || p.isPlaying) return true;
            // Paused: accept if valid title and has progress, length, or known streaming URL
            const hasTitle = (p.trackTitle ?? "").trim().length > 0;
            const hasProgress = (p.position ?? 0) > 0 || (p.length ?? 0) > 0;
            if (hasTitle && (hasProgress || (p.length ?? 0) >= 15)) return true;
            if (hasTitle && (rawUrl.includes("youtube.com") || rawUrl.includes("youtu.be") ||
                             rawUrl.includes("spotify.com") || rawUrl.includes("soundcloud.com") ||
                             rawUrl.includes("twitch.tv") || rawUrl.includes("bandcamp.com"))) {
                return true;
            }
            return false;
        }

        // 4. Non-browser players (Spotify, VLC, MPV, etc.)
        const hasTitle = (p.trackTitle ?? "").trim().length > 0;
        if (hasTitle || p.playbackState === MprisPlaybackState.Playing || p.isPlaying) return true;
        return false;
    }

    readonly property var allPlayers: {
        if (typeof Mpris === "undefined" || !Mpris.players) return [];
        return Mpris.players.values || [];
    }

    readonly property var realPlayers: {
        const list = [];
        for (let i = 0; i < allPlayers.length; i++) {
            if (isRealPlayer(allPlayers[i])) {
                list.push(allPlayers[i]);
            }
        }
        return list;
    }

    readonly property var activePlayer: {
        const list = realPlayers;
        // 1. Manual user override via player chips
        if (manualPlayer && list.includes(manualPlayer)) return manualPlayer;

        // 2. Active playing player takes instant priority (Brave, Spotify, etc.)
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing || list[i].isPlaying) {
                return list[i];
            }
        }

        // 3. Fallback to first available real player
        if (list.length > 0) return list[0];
        return null;
    }

    readonly property var otherPlayers: realPlayers.filter(p => p !== activePlayer)

    // ========================================================
    // 2. EFFECTIVE MEDIA TRACK METADATA
    // ========================================================
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool effectiveIsPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing || activePlayer.isPlaying) : false
    readonly property string effectiveTitle: activePlayer?.trackTitle ? activePlayer.trackTitle.trim() : (hasPlayer ? (activePlayer.identity || "Media Player") : "No Media Playing")
    readonly property string effectiveArtist: {
        if (!activePlayer) return "Playback will appear here";
        if (Array.isArray(activePlayer.trackArtists) && activePlayer.trackArtists.length > 0) return activePlayer.trackArtists.join(", ").trim();
        if (typeof activePlayer.trackArtists === "string" && activePlayer.trackArtists.trim() !== "") return activePlayer.trackArtists.trim();
        if (typeof activePlayer.trackArtist === "string" && activePlayer.trackArtist.trim() !== "") return activePlayer.trackArtist.trim();
        return activePlayer.identity || "Unknown Artist";
    }
    readonly property string effectiveArtUrl: {
        if (typeof dashMod !== "undefined" && dashMod && dashMod.currentAlbumArt && dashMod.currentAlbumArt !== "") {
            return dashMod.currentAlbumArt;
        }
        return activePlayer?.trackArtUrl ?? "";
    }
    readonly property real effectiveLength: (activePlayer && activePlayer.length > 0 && activePlayer.length < 86400) ? activePlayer.length : 0
    property real trackedPosition: activePlayer ? (activePlayer.position ?? 0) : 0
    readonly property real effectivePosition: Math.max(0, Math.min(effectiveLength > 0 ? effectiveLength : 86400, trackedPosition))

    // Broadcast current album art to whole shell Theme
    onEffectiveArtUrlChanged: {
        if (effectiveIsPlaying && effectiveArtUrl !== "") {
            Theme.currentArtSource = effectiveArtUrl;
        }
    }
    onEffectiveIsPlayingChanged: {
        if (effectiveIsPlaying && effectiveArtUrl !== "") {
            Theme.currentArtSource = effectiveArtUrl;
        } else if (!effectiveIsPlaying) {
            Theme.currentArtSource = "";
        }
    }

    // Smooth position updater
    Timer {
        id: posTickTimer
        interval: 250
        repeat: true
        running: musicModule.visible && musicModule.effectiveIsPlaying && !timelineScrubber.isDragging
        onTriggered: {
            if (activePlayer && activePlayer.position !== undefined) {
                musicModule.trackedPosition = activePlayer.position;
            }
        }
    }

    onActivePlayerChanged: {
        if (activePlayer && activePlayer.position !== undefined) {
            trackedPosition = activePlayer.position;
        }
    }

    // Media actions (infallible playerctl dispatch with active player targeting)
    function togglePlaying() {
        const pName = (activePlayer?.identity || activePlayer?.desktopEntry || "").toLowerCase();
        if (pName && !pName.includes("player")) {
            Quickshell.execDetached(["playerctl", "-p", pName, "play-pause"]);
        } else {
            Quickshell.execDetached(["playerctl", "play-pause"]);
        }
    }

    function previous() {
        const pName = (activePlayer?.identity || activePlayer?.desktopEntry || "").toLowerCase();
        if (pName && !pName.includes("player")) {
            Quickshell.execDetached(["playerctl", "-p", pName, "previous"]);
        } else {
            Quickshell.execDetached(["playerctl", "previous"]);
        }
    }

    function next() {
        const pName = (activePlayer?.identity || activePlayer?.desktopEntry || "").toLowerCase();
        if (pName && !pName.includes("player")) {
            Quickshell.execDetached(["playerctl", "-p", pName, "next"]);
        } else {
            Quickshell.execDetached(["playerctl", "next"]);
        }
    }

    function seek(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        musicModule.trackedPosition = s;
        if (activePlayer) {
            try { activePlayer.position = s; } catch(e) {}
        }
        const pName = (activePlayer?.identity || activePlayer?.desktopEntry || "").toLowerCase();
        if (pName && !pName.includes("player")) {
            Quickshell.execDetached(["playerctl", "-p", pName, "position", s.toString()]);
        } else {
            Quickshell.execDetached(["playerctl", "position", s.toString()]);
        }
    }

    function clockText(total) {
        const s = Math.max(0, Math.floor(total || 0));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        const pad = n => n < 10 ? "0" + n : String(n);
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec);
    }

    // ========================================================
    // 3. COLOR QUANTIZATION (Dynamic Artwork Tint)
    // ========================================================
    ColorQuantizer {
        id: tintQuantizer
        source: musicModule.effectiveArtUrl
        depth: 3
        rescaleSize: 48
        onColorsChanged: {
            if (colors && colors.length > 0) {
                let best = null;
                let bestScore = -1;
                for (let i = 0; i < colors.length; i++) {
                    const c = colors[i];
                    const score = Math.max(0, c.hslSaturation) * (1 - Math.abs(c.hslLightness - 0.5));
                    if (score > bestScore) { bestScore = score; best = c; }
                }
                if (best && best.hslSaturation >= 0.14 && best.hslHue >= 0) {
                    const extracted = Qt.hsla(best.hslHue, Math.max(0.5, best.hslSaturation),
                        Math.max(0.64, Math.min(0.76, best.hslLightness + 0.22)), 1);
                    Theme.setMediaAccent(extracted.toString());
                }
            }
        }
    }

    readonly property color artTint: Theme.colors.accent ?? "#a8c7fa"

    // ========================================================
    // 4. PIPEWIRE APP AUDIO STREAMS (Levels & Mute)
    // ========================================================
    readonly property var streams: {
        if (typeof Pipewire === "undefined" || !Pipewire.nodes) return [];
        const groups = [];
        const nodes = Pipewire.nodes.values.filter(n => n && n.isSink && n.audio && n.isStream);
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i];
            const name = (node.properties?.["application.name"] || node.description || node.name || "App");
            const group = groups.find(g => g.name === name);
            if (group) {
                group.nodes.push(node);
            } else {
                groups.push({ name: name, nodes: [node] });
            }
        }
        return groups;
    }

    function streamIconName(node) {
        if (!node) return "audio-x-generic";
        const props = node.properties ?? {};
        const appName = String(props["application.name"] || node.description || node.name || "").toLowerCase();
        const binary = String(props["application.process.binary"] || "").toLowerCase();
        const iconHint = String(props["application.icon-name"] || props["application.id"] || "").toLowerCase();
        const combined = `${appName} ${binary} ${iconHint}`;

        if (combined.includes("brave")) return "brave-desktop";
        if (combined.includes("spotify")) return "spotify";
        if (combined.includes("zen")) return "zen-browser";
        if (combined.includes("firefox")) return "firefox";
        if (combined.includes("chrome")) return "google-chrome";
        if (combined.includes("chromium")) return "chromium";
        if (combined.includes("mpv")) return "mpv";
        if (combined.includes("vlc")) return "vlc";
        if (combined.includes("discord") || combined.includes("vesktop")) return "discord";

        for (const hint of [props["application.icon-name"], props["application.id"], appName]) {
            if (!hint) continue;
            const p = Quickshell.iconPath(hint, "");
            if (p && p.length > 0) return hint;
        }
        return "audio-x-generic";
    }

    function getStreamVolume(nodes) {
        if (!nodes || nodes.length === 0) return 1.0;
        let maxVol = 0;
        let found = false;
        for (let i = 0; i < nodes.length; i++) {
            const v = nodes[i]?.audio?.volume;
            if (typeof v === "number" && !isNaN(v)) {
                found = true;
                if (v > maxVol) maxVol = v;
            }
        }
        return found ? Math.max(0, Math.min(1, maxVol)) : 1.0;
    }

    function getStreamMuted(nodes) {
        if (!nodes || nodes.length === 0) return false;
        for (let i = 0; i < nodes.length; i++) {
            if (nodes[i]?.audio?.muted === true) return true;
        }
        return false;
    }

    // ========================================================
    // 4.1 AUDIO OUTPUT DEVICES (Headphones, Speakers, etc.)
    // ========================================================
    property var audioSinks: []
    property string currentSinkName: ""

    readonly property var cleanAudioSinks: {
        return (musicModule.audioSinks || []).filter(function(s) {
            return !s.name.includes("HiFi__HDMI") && !s.name.includes("DisplayPort");
        });
    }

    Process {
        id: fetchSinksProcess
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    musicModule.audioSinks = data.sinks || [];
                    for (var i = 0; i < musicModule.audioSinks.length; i++) {
                        if (musicModule.audioSinks[i].isDefault) {
                            musicModule.currentSinkName = musicModule.audioSinks[i].name;
                            break;
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: fetchSinksTimer
        interval: 1000
        repeat: true
        running: musicModule.visible
        triggeredOnStart: true
        onTriggered: {
            if (!fetchSinksProcess.running) fetchSinksProcess.running = true;
        }
    }

    function switchSink(sinkName) {
        musicModule.currentSinkName = sinkName;
        Quickshell.execDetached(["pactl", "set-default-sink", sinkName]);
        Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/audio_devices.py").toString().replace("file://", ""), "set-sink", sinkName]);
        if (!fetchSinksProcess.running) fetchSinksProcess.running = true;
    }

    function cleanDeviceName(name, desc) {
        var d = (desc && desc.length > 0) ? desc : (name || "Device");
        d = d.replace(/^Raptor Lake-P\/U\/H cAVS\s*/i, "");
        d = d.replace(/^Alder Lake PCH-P High Definition Audio Controller\s*/i, "");
        return d.trim() || desc || name;
    }

    function getSinkIcon(name, desc) {
        var n = ((name || "") + " " + (desc || "")).toLowerCase();
        if (n.includes("bluez") || n.includes("buds") || n.includes("headset") || n.includes("headphone") || n.includes("ear") || n.includes("wh-")) return "headphones";
        return "speaker";
    }

    // Global Pipewire stream tracker to ensure all properties are live and reactive
    PwObjectTracker {
        objects: {
            if (typeof Pipewire === "undefined" || !Pipewire.nodes) return [];
            return Pipewire.nodes.values.filter(function(n) { return n && n.isStream && n.audio; });
        }
    }

    function setAppVolume(appLevel, vol) {
        var clamped = Math.max(0, Math.min(1.0, vol));
        var nodes = appLevel?.nodes || [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            if (node?.audio) {
                node.audio.volume = clamped;
                if (clamped > 0.01 && node.audio.muted) {
                    node.audio.muted = false;
                }
            }
            var nId = Number(node?.id ?? 0);
            if (nId > 0) {
                Quickshell.execDetached(["wpctl", "set-volume", String(nId), clamped.toFixed(2)]);
                if (clamped > 0.01) {
                    Quickshell.execDetached(["wpctl", "set-mute", String(nId), "0"]);
                }
            }
        }
    }

    function toggleAppMute(appLevel) {
        var willMute = !appLevel.isMuted;
        var nodes = appLevel?.nodes || [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            if (node?.audio) {
                node.audio.muted = willMute;
            }
            var nId = Number(node?.id ?? 0);
            if (nId > 0) {
                Quickshell.execDetached(["wpctl", "set-mute", String(nId), willMute ? "1" : "0"]);
            }
        }
    }

    // ========================================================
    // 5. DYNAMIC SNUG HEIGHT CALCULATION (Zero bottom dead space)
    // ========================================================
    readonly property real calculatedHeight: {
        let h = 18 + 68 + 12; // top pad + header + spacing
        if (effectiveLength > 0) {
            h += 33 + 12; // timeline + spacing
        }
        h += 52; // transport buttons
        if (otherPlayers.length > 0) {
            h += 10 + 1 + 8 + 32; // hairline + chip row + spacing
        }
        if (cleanAudioSinks.length > 0) {
            h += 10 + 1 + 8 + 28; // hairline + audio output chips
        }
        if (streams.length > 0) {
            const streamCount = Math.min(3, streams.length);
            h += 10 + 1 + 8 + (streamCount * 36 - 6); // hairline + streams
        }
        h += 18; // bottom padding
        return Math.round(h);
    }

    // ========================================================
    // 6. VISUAL CARD STRUCTURE (Iris 1:1)
    // ========================================================

    // Subtle blurred artwork backdrop
    IrisMediaBackdrop {
        anchors.fill: parent
        source: musicModule.effectiveArtUrl
        radius: 26
        strength: 0.50
        visible: musicModule.effectiveArtUrl !== ""
    }

    // Obsidian card container plate
    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 26
        bottomRightRadius: 26
        color: musicModule.effectiveArtUrl !== "" ? Qt.rgba(0.08, 0.08, 0.09, 0.78) : "#141416"
        border.width: 0
        border.color: "transparent"
    }

    // Main Content
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 18
        anchors.bottomMargin: 18
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 12

        // BLOCK 1: PLAYER HEADER (68px Cover, Track Info, Live Waveform)
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            IrisArtwork {
                id: pageCover
                Layout.preferredWidth: 68
                Layout.preferredHeight: 68
                source: musicModule.effectiveArtUrl
                circular: true
                radius: width / 2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: musicModule.effectiveTitle
                    color: "#f5f5f7"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: musicModule.effectiveArtist
                    visible: text.length > 0
                    color: Qt.rgba(255, 255, 255, 0.70)
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }

            IrisWaveform {
                Layout.alignment: Qt.AlignVCenter
                running: musicModule.effectiveIsPlaying && musicModule.visible
                tint: musicModule.artTint
                barHeight: 20
            }
        }

        // BLOCK 2: TIMELINE & SCRUBBER (Elapsed & Remaining Time)
        ColumnLayout {
            Layout.fillWidth: true
            visible: musicModule.effectiveLength > 0
            spacing: 3

            IrisScrubber {
                id: timelineScrubber
                Layout.fillWidth: true
                seekable: musicModule.hasPlayer && musicModule.effectiveLength > 0
                value: musicModule.effectiveLength > 0 ? Math.max(0, Math.min(1, musicModule.effectivePosition / musicModule.effectiveLength)) : 0
                fillColor: musicModule.artTint
                trackColor: Qt.rgba(255, 255, 255, 0.12)
                wavy: true
                isPlaying: musicModule.effectiveIsPlaying
                knob: true
                onSeekRequested: next => musicModule.seek(next * musicModule.effectiveLength)
                onMoved: next => { musicModule.trackedPosition = next * musicModule.effectiveLength; }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: musicModule.clockText(musicModule.effectivePosition)
                    color: Qt.rgba(255, 255, 255, 0.65)
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "-" + musicModule.clockText(Math.max(0, musicModule.effectiveLength - musicModule.effectivePosition))
                    color: Qt.rgba(255, 255, 255, 0.65)
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })
                }
            }
        }

        // BLOCK 3: TRANSPORT BUTTONS (Previous, Play/Pause, Next)
        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Item { Layout.fillWidth: true }

            GlyphButton {
                glyph: "fast_rewind"
                glyphSize: 26
                fill: 1
                implicitWidth: 44
                implicitHeight: 44
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                enabled: musicModule.hasPlayer
                onClicked: musicModule.previous()
            }

            GlyphButton {
                glyph: musicModule.effectiveIsPlaying ? "pause" : "play_arrow"
                glyphSize: 36
                fill: 1
                implicitWidth: 52
                implicitHeight: 52
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                enabled: true
                backgroundColor: Qt.rgba(255, 255, 255, 0.14)
                backgroundHoverColor: Qt.rgba(255, 255, 255, 0.22)
                backgroundPressedColor: Qt.rgba(255, 255, 255, 0.30)
                onClicked: musicModule.togglePlaying()
            }

            GlyphButton {
                glyph: "fast_forward"
                glyphSize: 26
                fill: 1
                implicitWidth: 44
                implicitHeight: 44
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                enabled: musicModule.hasPlayer
                onClicked: musicModule.next()
            }

            Item { Layout.fillWidth: true }
        }

        // BLOCK 4: OTHER PLAYERS (Chips Row)
        ColumnLayout {
            Layout.fillWidth: true
            visible: musicModule.otherPlayers.length > 0
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: musicModule.otherPlayers

                    Rectangle {
                        id: playerChip
                        required property var modelData
                        implicitHeight: 32
                        implicitWidth: chipRow.implicitWidth + 20
                        radius: height / 2
                        color: chipMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06)
                        scale: chipMouse.pressed ? 0.95 : 1.0
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6

                            IrisArtwork {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                source: String(playerChip.modelData?.trackArtUrl ?? "")
                                circular: true
                                radius: 10
                            }

                            Text {
                                text: String(playerChip.modelData?.trackTitle || playerChip.modelData?.identity || "Player")
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: "#f5f5f7"
                                elide: Text.ElideRight
                                Layout.maximumWidth: 150
                            }

                            MaterialSymbol {
                                text: playerChip.modelData?.isPlaying ? "graphic_eq" : "pause"
                                iconSize: 14
                                fill: 1
                                color: playerChip.modelData?.isPlaying ? musicModule.artTint : Qt.rgba(255, 255, 255, 0.45)
                            }
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                musicModule.manualPlayer = playerChip.modelData;
                            }
                        }
                    }
                }
            }
        }

        // BLOCK 4.5: AUDIO OUTPUT DEVICE OPTIONS (Headphones / Speakers switcher)
        ColumnLayout {
            Layout.fillWidth: true
            visible: musicModule.cleanAudioSinks.length > 0
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "OUTPUT"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Qt.rgba(255, 255, 255, 0.40)
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Repeater {
                    model: musicModule.cleanAudioSinks

                    Rectangle {
                        id: sinkChip
                        required property var modelData
                        readonly property bool isSelected: (sinkChip.modelData.isDefault || sinkChip.modelData.name === musicModule.currentSinkName)
                        implicitHeight: 26
                        implicitWidth: sinkChipRow.implicitWidth + 16
                        radius: 13
                        color: isSelected 
                            ? Qt.rgba((Theme.colors.accent ?? "#7aa2f7").r, (Theme.colors.accent ?? "#7aa2f7").g, (Theme.colors.accent ?? "#7aa2f7").b, 0.25)
                            : (sinkMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06))
                        border.width: 0

                        RowLayout {
                            id: sinkChipRow
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                text: musicModule.getSinkIcon(sinkChip.modelData.name, sinkChip.modelData.desc)
                                iconSize: 13
                                fill: sinkChip.isSelected ? 1 : 0
                                color: sinkChip.isSelected ? (Theme.colors.accent ?? "#a8c7fa") : Qt.rgba(255, 255, 255, 0.70)
                            }

                            Text {
                                text: musicModule.cleanDeviceName(sinkChip.modelData.name, sinkChip.modelData.desc)
                                font.pixelSize: 11
                                font.weight: sinkChip.isSelected ? Font.Bold : Font.Medium
                                color: sinkChip.isSelected ? "#ffffff" : Qt.rgba(255, 255, 255, 0.75)
                            }
                        }

                        MouseArea {
                            id: sinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                musicModule.switchSink(sinkChip.modelData.name);
                            }
                        }
                    }
                }
            }
        }

        // BLOCK 5: APP AUDIO STREAMS / LEVELS (PipeWire per-app volume & mute)
        ColumnLayout {
            Layout.fillWidth: true
            visible: musicModule.streams.length > 0
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            Repeater {
                model: musicModule.streams.slice(0, 3)

                RowLayout {
                    id: appLevel
                    required property var modelData
                    readonly property var nodes: Array.from(appLevel.modelData?.nodes ?? [])

                    PwObjectTracker {
                        objects: appLevel.nodes
                    }

                    readonly property bool isMuted: {
                        if (!appLevel.nodes || appLevel.nodes.length === 0) return false;
                        for (var i = 0; i < appLevel.nodes.length; i++) {
                            if (appLevel.nodes[i]?.audio?.muted) return true;
                        }
                        return false;
                    }
                    readonly property real streamVolume: {
                        if (!appLevel.nodes || appLevel.nodes.length === 0) return 1.0;
                        var maxV = 0;
                        var found = false;
                        for (var i = 0; i < appLevel.nodes.length; i++) {
                            var v = appLevel.nodes[i]?.audio?.volume;
                            if (typeof v === "number" && !isNaN(v)) {
                                found = true;
                                if (v > maxV) maxV = v;
                            }
                        }
                        return found ? Math.max(0, Math.min(1.0, maxV)) : 1.0;
                    }

                    Layout.fillWidth: true
                    spacing: 10

                    Item {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22

                        Image {
                            id: appImg
                            anchors.fill: parent
                            sourceSize: Qt.size(44, 44)
                            source: {
                                const iconName = musicModule.streamIconName(appLevel.nodes[0]);
                                return Quickshell.iconPath(iconName, "") || Quickshell.iconPath("audio-x-generic", "") || "";
                            }
                            opacity: appLevel.isMuted ? 0.45 : 1.0
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: appImg.status !== Image.Ready
                            text: "graphic_eq"
                            iconSize: 16
                            fill: 1
                            color: Qt.rgba(255, 255, 255, appLevel.isMuted ? 0.35 : 0.70)
                        }
                    }

                    Text {
                        Layout.preferredWidth: 100
                        text: appLevel.nodes.length > 1 ? appLevel.modelData.name + " · " + appLevel.nodes.length : appLevel.modelData.name
                        color: appLevel.isMuted ? Qt.rgba(255, 255, 255, 0.45) : "#f5f5f7"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    IrisScrubber {
                        id: appScrubber
                        Layout.fillWidth: true
                        seekable: true
                        fillColor: appLevel.isMuted ? Qt.rgba(255, 255, 255, 0.35) : (Theme.colors.accent ?? "#a8c7fa")
                        value: appLevel.streamVolume
                        onMoved: next => {
                            musicModule.isDraggingAnyStream = true;
                            musicModule.setAppVolume(appLevel, next);
                        }
                        onSeekRequested: next => {
                            musicModule.isDraggingAnyStream = false;
                            musicModule.setAppVolume(appLevel, next);
                        }
                    }

                    GlyphButton {
                        glyph: appLevel.isMuted ? "volume_off" : "volume_up"
                        glyphSize: 17
                        fill: 1
                        implicitWidth: 30
                        implicitHeight: 30
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        glyphColor: appLevel.isMuted ? "#ff6961" : "#f5f5f7"
                        onClicked: {
                            musicModule.toggleAppMute(appLevel);
                        }
                    }
                }
            }
        }
    }
}
