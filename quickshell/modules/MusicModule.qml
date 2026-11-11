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

    Keys.onSpacePressed: (event) => {
        musicModule.togglePlaying();
        event.accepted = true;
    }

    Keys.onLeftPressed: (event) => {
        musicModule.seek(musicModule.effectivePosition - 5);
        event.accepted = true;
    }

    Keys.onRightPressed: (event) => {
        musicModule.seek(musicModule.effectivePosition + 5);
        event.accepted = true;
    }

    Keys.onUpPressed: (event) => {
        musicModule.nudgeVolume(0.05);
        event.accepted = true;
    }

    Keys.onDownPressed: (event) => {
        musicModule.nudgeVolume(-0.05);
        event.accepted = true;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_N) {
            musicModule.next();
            event.accepted = true;
        } else if (event.key === Qt.Key_P) {
            musicModule.previous();
            event.accepted = true;
        }
    }

    // ========================================================
    // 1. MPRIS PLAYER DISCOVERY & CYCLING ENGINE
    // ========================================================
    property string pinnedName: ""
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
        if (name.indexOf("playerctld") !== -1) return false;

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
            if (p.playbackState === MprisPlaybackState.Playing || p.isPlaying) return true;
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

        // 4. Non-browser players (Spotify, VLC, MPV, Amberol, etc.)
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
        if (pinnedName !== "") {
            for (let i = 0; i < list.length; i++) {
                if (list[i].dbusName === pinnedName) return list[i];
            }
        }

        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing || list[i].isPlaying) {
                return list[i];
            }
        }
        if (list.length > 0) return list[0];
        return null;
    }

    readonly property var otherPlayers: realPlayers.filter(p => p.dbusName !== activePlayer?.dbusName)

    function cyclePlayer() {
        const list = realPlayers;
        if (list.length < 2) return;
        let index = 0;
        for (let i = 0; i < list.length; i++) {
            if (list[i].dbusName === activePlayer?.dbusName) {
                index = i;
                break;
            }
        }
        musicModule.pinnedName = list[(index + 1) % list.length].dbusName;
    }

    function cycleLoop() {
        if (!activePlayer || !activePlayer.loopSupported) return;
        const state = activePlayer.loopState;
        if (state === MprisLoopState.None) activePlayer.loopState = MprisLoopState.Playlist;
        else if (state === MprisLoopState.Playlist) activePlayer.loopState = MprisLoopState.Track;
        else activePlayer.loopState = MprisLoopState.None;
    }

    function raisePlayer() {
        if (activePlayer && activePlayer.canRaise) {
            activePlayer.raise();
        } else {
            togglePlaying();
        }
    }

    // ========================================================
    // 2. REMOTE COVER CACHING VIA CURL (Lucid 1:1 Crash Prevention)
    // ========================================================
    readonly property string rawArtUrl: {
        if (activePlayer && activePlayer.trackArtUrl && String(activePlayer.trackArtUrl).trim() !== "") {
            return String(activePlayer.trackArtUrl).trim();
        }
        if (typeof dashMod !== "undefined" && dashMod && dashMod.currentAlbumArt && String(dashMod.currentAlbumArt).trim() !== "") {
            return String(dashMod.currentAlbumArt).trim();
        }
        return "";
    }

    readonly property bool remoteArt: /^https?:/.test(rawArtUrl)
    readonly property string artFile: {
        if (!remoteArt) return "";
        var h = 5381;
        for (var i = 0; i < rawArtUrl.length; i++) h = ((h * 33) ^ rawArtUrl.charCodeAt(i)) >>> 0;
        return (Quickshell.env("HOME") || "") + "/.cache/quickshell/art/" + h.toString(16) + ".img";
    }
    property string localArt: ""
    readonly property string effectiveArtUrl: remoteArt ? localArt : rawArtUrl

    function fetchCover() {
        if (artFile === "") {
            localArt = "";
            return;
        }
        artFetch.superseded = artFetch.running;
        artFetch.file = artFile;
        artFetch.running = false;
        artFetch.command = ["sh", "-c", artFetch.script, "sh", artFile, rawArtUrl];
        artFetch.running = true;
    }

    onArtFileChanged: fetchCover()
    Component.onCompleted: fetchCover()

    Process {
        id: artFetch
        property string file: ""
        property bool superseded: false
        readonly property string script: "f=\"$1\"; d=\"$(dirname \"$f\")\"; mkdir -p \"$d\"; find \"$d\" -name '*.img' -mtime +14 -delete 2>/dev/null; [ -s \"$f\" ] || { t=\"$f.$$\"; curl -sfL --max-time 10 -o \"$t\" \"$2\" && mv \"$t\" \"$f\" || rm -f \"$t\"; }; [ -s \"$f\" ]"
        onExited: (code) => {
            if (artFetch.superseded) {
                artFetch.superseded = false;
                return;
            }
            localArt = (code === 0) ? ("file://" + artFetch.file) : "";
        }
    }

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

    // Dynamic Artwork Tinting
    ColorQuantizer {
        id: tintQuantizer
        source: (musicModule.effectiveArtUrl && !musicModule.effectiveArtUrl.startsWith("http")) ? musicModule.effectiveArtUrl : ""
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

    readonly property color artTint: (typeof Theme !== "undefined" && Theme.colors && Theme.colors.accent) ? Theme.colors.accent : "#a8c7fa"

    // ========================================================
    // 3. TRACK METADATA & SMOOTH POSITION INTERPOLATION
    // ========================================================
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool effectiveIsPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing || activePlayer.isPlaying) : false
    readonly property string effectiveTitle: activePlayer?.trackTitle ? activePlayer.trackTitle.trim() : (hasPlayer ? (activePlayer.identity || "Media Player") : "No Media Playing")
    readonly property string effectiveArtist: {
        if (!activePlayer) return "Start playback in Spotify, Zen or media player";
        if (Array.isArray(activePlayer.trackArtists) && activePlayer.trackArtists.length > 0) return activePlayer.trackArtists.join(", ").trim();
        if (typeof activePlayer.trackArtists === "string" && activePlayer.trackArtists.trim() !== "") return activePlayer.trackArtists.trim();
        if (typeof activePlayer.trackArtist === "string" && activePlayer.trackArtist.trim() !== "") return activePlayer.trackArtist.trim();
        return activePlayer.identity || "Unknown Artist";
    }
    readonly property string effectiveSource: activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "Media Player") : ""
    readonly property real effectiveLength: (activePlayer && activePlayer.length > 0 && activePlayer.length < 86400) ? activePlayer.length : 0

    readonly property real posSec: activePlayer ? (activePlayer.position ?? 0) : 0
    property real livePosSec: posSec
    property real posBase: posSec
    property double posTimestamp: Date.now()
    property bool showRemaining: false

    onPosSecChanged: {
        if (!timelineScrubber.isDragging) {
            posBase = posSec;
            posTimestamp = Date.now();
            livePosSec = posSec;
        }
    }

    onActivePlayerChanged: {
        posBase = posSec;
        posTimestamp = Date.now();
        livePosSec = posSec;
    }

    Timer {
        interval: 1000
        running: musicModule.visible && musicModule.effectiveIsPlaying
        repeat: true
        onTriggered: {
            if (activePlayer && typeof activePlayer.positionChanged === "function") {
                activePlayer.positionChanged();
            }
        }
    }

    FrameAnimation {
        running: musicModule.visible && musicModule.effectiveIsPlaying && !timelineScrubber.isDragging
        onTriggered: {
            if (effectiveLength > 0) {
                musicModule.livePosSec = Math.min(effectiveLength, posBase + (Date.now() - posTimestamp) / 1000);
            } else {
                musicModule.livePosSec = posBase + (Date.now() - posTimestamp) / 1000;
            }
        }
    }

    readonly property real effectivePosition: Math.max(0, Math.min(effectiveLength > 0 ? effectiveLength : 86400, livePosSec))

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec || 0));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    function togglePlaying() {
        if (activePlayer && activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying();
            return;
        }
        const pName = (activePlayer?.identity || activePlayer?.desktopEntry || "").toLowerCase();
        if (pName && !pName.includes("player")) {
            Quickshell.execDetached(["playerctl", "-p", pName, "play-pause"]);
        } else {
            Quickshell.execDetached(["playerctl", "play-pause"]);
        }
    }

    function previous() {
        if (activePlayer && activePlayer.canGoPrevious) {
            activePlayer.previous();
            return;
        }
        const pName = (activePlayer?.identity || activePlayer?.desktopEntry || "").toLowerCase();
        if (pName && !pName.includes("player")) {
            Quickshell.execDetached(["playerctl", "-p", pName, "previous"]);
        } else {
            Quickshell.execDetached(["playerctl", "previous"]);
        }
    }

    function next() {
        if (activePlayer && activePlayer.canGoNext) {
            activePlayer.next();
            return;
        }
        const pName = (activePlayer?.identity || activePlayer?.desktopEntry || "").toLowerCase();
        if (pName && !pName.includes("player")) {
            Quickshell.execDetached(["playerctl", "-p", pName, "next"]);
        } else {
            Quickshell.execDetached(["playerctl", "next"]);
        }
    }

    function seek(seconds) {
        const s = Math.max(0, Math.min(effectiveLength > 0 ? effectiveLength : 86400, seconds));
        posBase = s;
        posTimestamp = Date.now();
        livePosSec = s;
        if (activePlayer && activePlayer.canSeek) {
            try { activePlayer.position = s; } catch(e) {}
        }
        const pName = (activePlayer?.identity || activePlayer?.desktopEntry || "").toLowerCase();
        if (pName && !pName.includes("player")) {
            Quickshell.execDetached(["playerctl", "-p", pName, "position", Math.floor(s).toString()]);
        } else {
            Quickshell.execDetached(["playerctl", "position", Math.floor(s).toString()]);
        }
    }

    // ========================================================
    // 4. VOLUME & OUTPUT SINK MANAGEMENT
    // ========================================================
    readonly property real playerVolume: (activePlayer && activePlayer.volumeSupported) ? (activePlayer.volume ?? 1.0) : 1.0
    property real unmuteVolume: 0.5

    function nudgeVolume(delta) {
        if (activePlayer && activePlayer.volumeSupported) {
            activePlayer.volume = Math.max(0, Math.min(1.0, playerVolume + delta));
        } else {
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (delta > 0 ? "5%+" : "5%-")]);
        }
    }

    function toggleMute() {
        if (activePlayer && activePlayer.volumeSupported) {
            if (playerVolume > 0.01) {
                unmuteVolume = playerVolume;
                activePlayer.volume = 0;
            } else {
                activePlayer.volume = unmuteVolume > 0.05 ? unmuteVolume : 0.5;
            }
        } else {
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        }
    }

    function getVolumeGlyph(vol) {
        if (vol <= 0.01) return "volume_off";
        if (vol < 0.5) return "volume_down";
        return "volume_up";
    }

    property var audioSinks: []
    property string currentSinkName: ""

    readonly property var cleanAudioSinks: {
        return (musicModule.audioSinks || []).filter(function(s) {
            var text = ((s.desc || "") + " " + (s.name || "")).toLowerCase();
            return !text.includes("hdmi") && !text.includes("displayport");
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
        interval: 1200
        repeat: true
        running: musicModule.visible
        triggeredOnStart: true
        onTriggered: {
            if (!fetchSinksProcess.running) fetchSinksProcess.running = true;
        }
    }

    function switchSink(sinkId) {
        musicModule.currentSinkName = String(sinkId);
        Quickshell.execDetached(["wpctl", "set-default", String(sinkId)]);
        if (!fetchSinksProcess.running) fetchSinksProcess.running = true;
    }

    function cleanDeviceName(name, desc) {
        var d = (desc && desc.length > 0) ? desc : (name || "Device");
        d = d.replace(/^Raptor Lake-P\/U\/H cAVS\s*/i, "");
        d = d.replace(/^Alder Lake PCH-P High Definition Audio Controller\s*/i, "");
        d = d.replace(/\s*Output\s*\(Stereo\)/i, "");
        return d.trim() || desc || name;
    }

    function getSinkIcon(name, desc) {
        var n = ((name || "") + " " + (desc || "")).toLowerCase();
        if (n.includes("bluez") || n.includes("buds") || n.includes("headset") || n.includes("headphone") || n.includes("ear") || n.includes("wh-") || n.includes("airpod")) return "headphones";
        return "speaker";
    }

    // PIPEWIRE APP AUDIO STREAMS
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

    readonly property var displayStreams: streams.slice(0, 2)

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

    function setAppVolume(appLevel, vol) {
        var clamped = Math.max(0, Math.min(1.0, vol));
        var nodes = appLevel?.nodes || [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            if (node?.audio) {
                node.audio.volume = clamped;
                if (clamped > 0.01 && node.audio.muted) node.audio.muted = false;
            }
            var nId = Number(node?.id ?? 0);
            if (nId > 0) {
                Quickshell.execDetached(["wpctl", "set-volume", String(nId), clamped.toFixed(2)]);
                if (clamped > 0.01) Quickshell.execDetached(["wpctl", "set-mute", String(nId), "0"]);
            }
        }
    }

    function toggleAppMute(appLevel) {
        var willMute = !appLevel.isMuted;
        var nodes = appLevel?.nodes || [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            if (node?.audio) node.audio.muted = willMute;
            var nId = Number(node?.id ?? 0);
            if (nId > 0) Quickshell.execDetached(["wpctl", "set-mute", String(nId), willMute ? "1" : "0"]);
        }
    }

    // ========================================================
    // 5. DYNAMIC SNUG HEIGHT CALCULATION
    // ========================================================
    readonly property real calculatedHeight: {
        let h = 16 + 82 + 12; // top pad + header + spacing
        if (effectiveLength > 0 || hasPlayer) {
            h += 34 + 10; // scrubber + spacing
        }
        h += 48; // transport buttons
        if (otherPlayers.length > 0) {
            h += 12 + 1 + 8 + 30; // spacing + divider + other players
        }
        if (cleanAudioSinks.length > 0) {
            h += 12 + 1 + 8 + 26; // spacing + divider + audio sinks
        }
        if (displayStreams.length > 0) {
            h += 12 + 1 + 8 + (displayStreams.length * 34 - 4); // spacing + divider + streams
        }
        h += 16; // bottom padding
        return Math.round(h);
    }

    // ========================================================
    // 6. VISUAL CARD STRUCTURE & LUCID GLASS STYLING
    // ========================================================

    // Subtle blurred artwork backdrop
    IrisMediaBackdrop {
        anchors.fill: parent
        source: musicModule.effectiveArtUrl
        radius: 26
        strength: 0.45
        visible: musicModule.effectiveArtUrl !== ""
    }

    // Obsidian card container plate
    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 26
        bottomRightRadius: 26
        color: musicModule.effectiveArtUrl !== "" ? Qt.rgba(0.07, 0.07, 0.08, 0.82) : "#121214"
        border.width: 0
        border.color: "transparent"
    }

    // Mouse area over container to allow volume adjustment via wheel
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            musicModule.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
        }
    }

    // Main Content Column
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 16
        spacing: 12

        // ----------------------------------------------------
        // ROW 1: LUCID ALBUM ART & TRACK HEADER
        // ----------------------------------------------------
        Row {
            width: parent.width
            spacing: 16

            // Lucid Rounded Album Art with hover actions
            Rectangle {
                id: artBox
                width: 82
                height: 82
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.06)
                clip: true

                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: musicModule.effectiveArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    smooth: true
                    cache: true
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: coverImage.status !== Image.Ready
                    text: "music_note"
                    iconSize: 36
                    fill: 1
                    color: musicModule.artTint
                }

                // Lucid dark overlay with tactile raise/play hint
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "black"
                    opacity: artMouse.containsMouse ? 0.42 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: (activePlayer && activePlayer.canRaise) ? "open_in_new" : (musicModule.effectiveIsPlaying ? "pause" : "play_arrow")
                    iconSize: 26
                    fill: 1
                    color: "#ffffff"
                    opacity: artMouse.containsMouse ? 1.0 : 0.0
                    scale: artMouse.containsMouse ? 1.0 : 0.7
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                }

                MouseArea {
                    id: artMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicModule.raisePlayer()
                    onWheel: (wheel) => {
                        musicModule.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                    }
                }
            }

            // Track Information & Player Badge Column
            Column {
                width: parent.width - 82 - 16
                spacing: 3

                // Top Badge: Player source chip + Live Equalizer
                Item {
                    width: parent.width
                    height: 24

                    // Source chip (Clickable with swap icon if multiple players exist)
                    Rectangle {
                        id: sourceChip
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: 22
                        width: sourceRow.implicitWidth + 14
                        radius: 11
                        color: sourceMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                        scale: sourceMouse.pressed ? 0.95 : 1.0
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Row {
                            id: sourceRow
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: musicModule.effectiveIsPlaying ? "graphic_eq" : "music_note"
                                iconSize: 13
                                fill: 1
                                color: musicModule.artTint
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: musicModule.effectiveSource
                                color: "#f5f5f7"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: musicModule.realPlayers.length > 1
                                text: "swap_horiz"
                                iconSize: 13
                                fill: 1
                                color: Qt.rgba(1, 1, 1, 0.60)
                            }
                        }

                        MouseArea {
                            id: sourceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: musicModule.realPlayers.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (musicModule.realPlayers.length > 1) {
                                    musicModule.cyclePlayer();
                                }
                            }
                        }
                    }

                    // Dynamic Live Audio Equalizer Wave
                    IrisWaveform {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        running: musicModule.effectiveIsPlaying && musicModule.visible
                        tint: musicModule.artTint
                        barHeight: 18
                    }
                }

                Item { width: 1; height: 2 }

                // Track Title (DemiBold, elided)
                Text {
                    width: parent.width
                    text: musicModule.effectiveTitle
                    color: "#f5f5f7"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 1.15
                }

                // Artist & Album
                Text {
                    width: parent.width
                    text: musicModule.effectiveArtist
                    visible: text.length > 0
                    color: Qt.rgba(1, 1, 1, 0.65)
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }

        // ----------------------------------------------------
        // ROW 2: TIMELINE & PROGRESS SCRUBBER
        // ----------------------------------------------------
        Column {
            width: parent.width
            spacing: 2
            visible: musicModule.hasPlayer

            IrisScrubber {
                id: timelineScrubber
                width: parent.width
                seekable: musicModule.hasPlayer && musicModule.effectiveLength > 0
                value: musicModule.effectiveLength > 0 ? Math.max(0, Math.min(1, musicModule.effectivePosition / musicModule.effectiveLength)) : 0
                fillColor: musicModule.artTint
                trackColor: Qt.rgba(1, 1, 1, 0.12)
                wavy: true
                isPlaying: musicModule.effectiveIsPlaying
                knob: true
                onSeekRequested: next => musicModule.seek(next * musicModule.effectiveLength)
                onMoved: next => { musicModule.livePosSec = next * musicModule.effectiveLength; }
            }

            // Elapsed time & Remaining / Total time
            Item {
                width: parent.width
                height: 16

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: musicModule.fmt(musicModule.effectivePosition)
                    color: Qt.rgba(1, 1, 1, 0.65)
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: musicModule.effectiveLength > 0
                        ? (musicModule.showRemaining ? ("-" + musicModule.fmt(Math.max(0, musicModule.effectiveLength - musicModule.effectivePosition))) : musicModule.fmt(musicModule.effectiveLength))
                        : "Live"
                    color: timeMouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })

                    MouseArea {
                        id: timeMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.showRemaining = !musicModule.showRemaining
                    }
                }
            }
        }

        // ----------------------------------------------------
        // ROW 3: TACTILE TRANSPORT CONTROLS (Lucid 1:1)
        // ----------------------------------------------------
        Item {
            width: parent.width
            height: 48

            // Volume Mute/Unmute Mini Button (Left)
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 17
                color: volMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                scale: volMouse.pressed ? 0.92 : (volMouse.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: musicModule.getVolumeGlyph(musicModule.playerVolume)
                    iconSize: 18
                    fill: 1
                    color: Qt.rgba(1, 1, 1, 0.70)
                }

                MouseArea {
                    id: volMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicModule.toggleMute()
                    onWheel: (wheel) => {
                        musicModule.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                    }
                }
            }

            // Centered Transport Row
            Row {
                anchors.centerIn: parent
                spacing: 14

                // Shuffle Button
                Rectangle {
                    id: shuffleBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    readonly property bool isShuffle: activePlayer ? (activePlayer.shuffle ?? false) : false
                    readonly property bool canShuffle: activePlayer ? (activePlayer.shuffleSupported ?? false) : false
                    visible: canShuffle
                    color: shuffleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    scale: shuffleMouse.pressed ? 0.92 : (shuffleMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "shuffle"
                        iconSize: 20
                        fill: shuffleBtn.isShuffle ? 1 : 0
                        color: shuffleBtn.isShuffle ? musicModule.artTint : Qt.rgba(1, 1, 1, 0.65)
                    }

                    MouseArea {
                        id: shuffleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (activePlayer) activePlayer.shuffle = !activePlayer.shuffle;
                        }
                    }
                }

                // Previous Button
                Rectangle {
                    id: prevBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    height: 42
                    radius: 21
                    color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                    scale: prevMouse.pressed ? 0.92 : (prevMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_previous"
                        iconSize: 24
                        fill: 1
                        color: "#f5f5f7"
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: musicModule.hasPlayer
                        onClicked: musicModule.previous()
                    }
                }

                // Lucid Wide Tactile Play/Pause Pill
                Rectangle {
                    id: playPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64
                    height: 46
                    radius: playMouse.pressed ? 14 : 23
                    color: musicModule.artTint
                    opacity: musicModule.hasPlayer ? 1.0 : 0.4
                    scale: playMouse.pressed ? 0.94 : (playMouse.containsMouse ? 1.06 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: musicModule.effectiveIsPlaying ? "pause" : "play_arrow"
                        iconSize: 28
                        fill: 1
                        color: "#0d0e12"
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: musicModule.hasPlayer
                        onClicked: musicModule.togglePlaying()
                    }
                }

                // Next Button
                Rectangle {
                    id: nextBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    height: 42
                    radius: 21
                    color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                    scale: nextMouse.pressed ? 0.92 : (nextMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_next"
                        iconSize: 24
                        fill: 1
                        color: "#f5f5f7"
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: musicModule.hasPlayer
                        onClicked: musicModule.next()
                    }
                }

                // Loop / Repeat Button
                Rectangle {
                    id: loopBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    readonly property bool canLoop: activePlayer ? (activePlayer.loopSupported ?? false) : false
                    readonly property int loopState: activePlayer ? (activePlayer.loopState ?? 0) : 0
                    readonly property bool isLooping: loopState !== MprisLoopState.None
                    visible: canLoop
                    color: loopMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    scale: loopMouse.pressed ? 0.92 : (loopMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: (loopBtn.loopState === MprisLoopState.Track) ? "repeat_one" : "repeat"
                        iconSize: 20
                        fill: loopBtn.isLooping ? 1 : 0
                        color: loopBtn.isLooping ? musicModule.artTint : Qt.rgba(1, 1, 1, 0.65)
                    }

                    MouseArea {
                        id: loopMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicModule.cycleLoop()
                    }
                }
            }
        }

        // ----------------------------------------------------
        // ROW 4: OTHER ACTIVE PLAYERS (Pills)
        // ----------------------------------------------------
        Column {
            width: parent.width
            visible: musicModule.otherPlayers.length > 0
            spacing: 8

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: musicModule.otherPlayers

                    Rectangle {
                        id: playerChip
                        required property var modelData
                        height: 30
                        width: chipRow.implicitWidth + 20
                        radius: 15
                        color: chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                        scale: chipMouse.pressed ? 0.95 : 1.0
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6

                            IrisArtwork {
                                width: 18
                                height: 18
                                source: String(playerChip.modelData?.trackArtUrl ?? "")
                                circular: true
                                radius: 9
                            }

                            Text {
                                text: String(playerChip.modelData?.trackTitle || playerChip.modelData?.identity || "Player")
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: "#f5f5f7"
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 180)
                            }

                            MaterialSymbol {
                                text: playerChip.modelData?.isPlaying ? "graphic_eq" : "pause"
                                iconSize: 13
                                fill: 1
                                color: playerChip.modelData?.isPlaying ? musicModule.artTint : Qt.rgba(1, 1, 1, 0.45)
                            }
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                musicModule.pinnedName = playerChip.modelData?.dbusName ?? "";
                            }
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------
        // ROW 5: AUDIO OUTPUT SINKS (Cleaned & Filtered)
        // ----------------------------------------------------
        Column {
            width: parent.width
            visible: musicModule.cleanAudioSinks.length > 0
            spacing: 8

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Row {
                width: parent.width
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "OUTPUT"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Qt.rgba(1, 1, 1, 0.40)
                }

                Repeater {
                    model: musicModule.cleanAudioSinks

                    Rectangle {
                        id: sinkChip
                        required property var modelData
                        readonly property bool isSelected: (sinkChip.modelData.isDefault || String(sinkChip.modelData.name) === String(musicModule.currentSinkName))
                        height: 26
                        width: sinkChipRow.implicitWidth + 16
                        radius: 13
                        color: isSelected
                            ? Qt.rgba(musicModule.artTint.r, musicModule.artTint.g, musicModule.artTint.b, 0.25)
                            : (sinkMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                        border.width: isSelected ? 1 : 0
                        border.color: isSelected ? musicModule.artTint : "transparent"

                        Row {
                            id: sinkChipRow
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: musicModule.getSinkIcon(sinkChip.modelData.name, sinkChip.modelData.desc)
                                iconSize: 13
                                fill: sinkChip.isSelected ? 1 : 0
                                color: sinkChip.isSelected ? musicModule.artTint : Qt.rgba(1, 1, 1, 0.70)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: musicModule.cleanDeviceName(sinkChip.modelData.name, sinkChip.modelData.desc)
                                font.pixelSize: 11
                                font.weight: sinkChip.isSelected ? Font.Bold : Font.Medium
                                color: sinkChip.isSelected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.75)
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

        // ----------------------------------------------------
        // ROW 6: PIPEWIRE APP AUDIO STREAM SLIDERS
        // ----------------------------------------------------
        Column {
            width: parent.width
            visible: musicModule.displayStreams.length > 0
            spacing: 8

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Repeater {
                model: musicModule.displayStreams

                Row {
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

                    width: parent.width
                    spacing: 10

                    IrisIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        icon: {
                            const iconName = musicModule.streamIconName(appLevel.nodes[0]);
                            const p = Quickshell.iconPath(iconName, "") || Quickshell.iconPath("audio-x-generic", "");
                            return p ? ("file://" + p) : "graphic_eq";
                        }
                        iconSize: 16
                        fill: 1
                        fallbackSymbol: "graphic_eq"
                        color: Qt.rgba(1, 1, 1, appLevel.isMuted ? 0.35 : 0.70)
                        opacity: appLevel.isMuted ? 0.45 : 1.0
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 90
                        text: appLevel.nodes.length > 1 ? appLevel.modelData.name + " · " + appLevel.nodes.length : appLevel.modelData.name
                        color: appLevel.isMuted ? Qt.rgba(1, 1, 1, 0.45) : "#f5f5f7"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    IrisScrubber {
                        id: appScrubber
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(80, appLevel.width - 20 - 90 - 28 - 30)
                        seekable: true
                        fillColor: appLevel.isMuted ? Qt.rgba(1, 1, 1, 0.35) : musicModule.artTint
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

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: appMuteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: appLevel.isMuted ? "volume_off" : "volume_up"
                            iconSize: 16
                            fill: 1
                            color: appLevel.isMuted ? "#ff6961" : "#f5f5f7"
                        }

                        MouseArea {
                            id: appMuteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: musicModule.toggleAppMute(appLevel)
                        }
                    }
                }
            }
        }
    }
}
