import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../"
import "."
import "." as DashComponents
import "./widgets"
import qs.services

Item {
    id: dash
    Layout.fillWidth: true
    Layout.fillHeight: true

    readonly property var upowerDev: (typeof UPower !== "undefined") ? UPower.displayDevice : null
    readonly property int currentBatteryLevel: (upowerDev && upowerDev.percentage !== undefined) ? Math.round(upowerDev.percentage * 100) : 100
    readonly property bool isBatteryCharging: (upowerDev && upowerDev.state !== undefined) ? (upowerDev.state === UPowerDevice.Charging) : false

    property bool netIslandExpanded: false
    property bool powerIslandExpanded: false
    property bool settingsOpen: false
    signal settingsRequested()
    property bool isIslandActive: btIslandExpanded || powerIslandExpanded || netIslandExpanded || root.isNotifPopupActive || root.isWorkspacePeeking || root.isScreenshotIslandActive

    readonly property string currentIslandType: {
        if (root.isScreenshotIslandActive) return "screenshot";
        if (root.isNotifPopupActive) return "notif";
        if (btIslandExpanded) return "bluetooth";
        if (powerIslandExpanded) return "power";
        if (netIslandExpanded) return "net";
        if (root.isWorkspacePeeking) return "workspace";
        return "";
    }

    property string displayedIslandType: ""
    readonly property real notificationHeight: notificationBanner.implicitHeight

    FileView {
        id: osReleaseFile
        path: "/etc/os-release"
    }

    readonly property string distroGlyph: {
        var text = "";
        try {
            text = osReleaseFile.text().toLowerCase();
        } catch(e) {}
        if (text.indexOf("arch") !== -1 || text.indexOf("artix") !== -1 || text.indexOf("cachy") !== -1 || text.indexOf("endeavour") !== -1) return ""; // Arch Linux \uf303
        if (text.indexOf("nix") !== -1) return ""; // NixOS \uf313
        if (text.indexOf("fedora") !== -1) return ""; // Fedora \uf30a
        if (text.indexOf("debian") !== -1) return ""; // Debian \uf306
        if (text.indexOf("ubuntu") !== -1) return ""; // Ubuntu \uf31b
        if (text.indexOf("gentoo") !== -1) return ""; // Gentoo \uf30d
        if (text.indexOf("void") !== -1) return ""; // Void \uf32e
        return ""; // Default to Arch Linux \uf303
    }

    onCurrentIslandTypeChanged: {
        if (currentIslandType !== "") {
            displayedIslandType = currentIslandType;
        } else if (displayedIslandType === "notif" || !islandContainer.visible || islandContainer.opacity <= 0.01) {
            displayedIslandType = "";
        }
    }

    onIsIslandActiveChanged: {
        if (!isIslandActive && (displayedIslandType === "notif" || !islandContainer.visible || islandContainer.opacity <= 0.01)) {
            displayedIslandType = "";
        }
    }

    Connections {
        target: root
        function onIsNotifPopupActiveChanged() {
            if (!root.isNotifPopupActive && dash.displayedIslandType === "notif") {
                dash.displayedIslandType = "";
            }
        }
        function onActiveModeChanged() {
            if (root.activeMode !== "idle" && !dash.isIslandActive) {
                dash.displayedIslandType = "";
            }
        }
    }

    readonly property int restingIdleWidth: {
        var source = (dash.isMediaPlaying && !dash.showMusicInfo && typeof musicIdleGlances !== "undefined")
            ? musicIdleGlances
            : (typeof idleGlances !== "undefined" ? idleGlances : null);
        var w = Math.max(176, (source && source.implicitWidth > 40 ? Math.ceil(source.implicitWidth) : 176) + 28);
        return w + (w % 2);
    }

    property int activeIslandWidth: {
        if (displayedIslandType === "screenshot" || root.isScreenshotIslandActive) {
            return Math.max(260, screenshotPopupRow.implicitWidth + 36);
        }
        if (root.isNotifPopupActive) return notificationBanner.preferredWidth;
        if (displayedIslandType === "workspace" || root.isWorkspacePeeking) {
            var ww = Math.max(dash.restingIdleWidth, wsIslandRow.implicitWidth + 36);
            return ww + (ww % 2);
        }
        if (displayedIslandType === "bluetooth" || btIslandExpanded) return Math.max(dash.restingIdleWidth, btPopupRow.implicitWidth + 36);
        if (displayedIslandType === "power" || powerIslandExpanded) return Math.max(220, powerPopupRow.implicitWidth + 36);
        if (displayedIslandType === "net" || netIslandExpanded) return Math.max(dash.restingIdleWidth, netPopupRow.implicitWidth + 36);
        return dash.restingIdleWidth;
    }

    implicitWidth: {
        if (isIslandActive || (displayedIslandType !== "" && displayedIslandType !== "notif" && islandContainer.opacity > 0.01)) return activeIslandWidth;
        if (root.activeMode === "hover") {
            var hw = Math.ceil(dashRow.implicitWidth) + 32;
            return hw + (hw % 2);
        }
        if (dash.isMediaPlaying && root.activeMode === "idle" && dash.showMusicInfo) {
            return 360 + (expandedMusicReadouts.visible ? expandedMusicReadouts.implicitWidth + 10 : 0);
        }
        return dash.restingIdleWidth;
    }

    property bool showMusicInfo: false
    property string playbackStatus: activeMprisPlayer ? (activeMprisPlayer.playbackState === MprisPlaybackState.Playing ? "Playing" : "Paused") : ""
    property bool isMediaPlaying: activeMprisPlayer ? (activeMprisPlayer.playbackState === MprisPlaybackState.Playing || activeMprisPlayer.isPlaying) : false
    property string currentSongTitle: (activeMprisPlayer && activeMprisPlayer.trackTitle) ? activeMprisPlayer.trackTitle.trim() : ""
    property string currentSongArtist: {
        if (!activeMprisPlayer) return "";
        if (Array.isArray(activeMprisPlayer.trackArtists) && activeMprisPlayer.trackArtists.length > 0) return activeMprisPlayer.trackArtists.join(", ").trim();
        if (typeof activeMprisPlayer.trackArtists === "string" && activeMprisPlayer.trackArtists.trim() !== "") return activeMprisPlayer.trackArtists.trim();
        if (typeof activeMprisPlayer.trackArtist === "string" && activeMprisPlayer.trackArtist.trim() !== "") return activeMprisPlayer.trackArtist.trim();
        return activeMprisPlayer.identity || "";
    }
    property string currentAlbumArt: {
        if (!activeMprisPlayer) return "";
        var raw = MprisController.rawArtUrlFor(activeMprisPlayer) || "";
        if (raw === "" && activeMprisPlayer === MprisController.activePlayer) {
            raw = MprisController.artUrl ? String(MprisController.artUrl) : "";
        }
        return raw !== "" ? CoverArt.source(raw) : "";
    }
    property real trackPosition: (activeMprisPlayer && activeMprisPlayer.position) ? activeMprisPlayer.position : 0
    property real trackLength: (activeMprisPlayer && activeMprisPlayer.length) ? activeMprisPlayer.length : 0
    property real trackProgress: trackLength > 0 ? Math.max(0, Math.min(1, trackPosition / trackLength)) : 0

    readonly property var motionCurve: [0.16, 1, 0.3, 1, 1, 1]  // Iris liquid morph curve

    // Cava visualizer for music
    CavaProcess {
        id: cavaViz
        active: dash.isMediaPlaying && !root.notchHidden && (root.activeMode === "idle" || root.activeMode === "hover")
        bars: 5
    }

    // Native Event-Driven MPRIS Tracking (Section 1.1)
    readonly property var allMprisPlayers: (typeof Mpris !== "undefined" && Mpris.players) ? Mpris.players.values : []

    readonly property var activeMprisPlayer: {
        if (typeof MprisController !== "undefined" && MprisController.activePlayer) {
            return MprisController.activePlayer;
        }
        var list = allMprisPlayers;
        if (!list || list.length === 0) return null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (p && (p.playbackState === MprisPlaybackState.Playing || p.isPlaying)) {
                return p;
            }
        }
        for (var j = 0; j < list.length; j++) {
            var q = list[j];
            if (q && q.trackTitle && q.trackTitle.trim() !== "") {
                return q;
            }
        }
        return list[0] || null;
    }

    onIsMediaPlayingChanged: {
        if (isMediaPlaying && currentAlbumArt !== "") {
            Theme.currentArtSource = currentAlbumArt;
        } else if (!isMediaPlaying) {
            Theme.currentArtSource = "";
            Theme.setMediaAccent("");
            dash.showMusicInfo = false;
        }
    }

    onCurrentAlbumArtChanged: {
        if (isMediaPlaying && currentAlbumArt !== "") {
            Theme.currentArtSource = currentAlbumArt;
        }
    }

    property string activeNetType: "wifi"
    property string activeNetName: ""
    property int activeNetSignal: 0
    property string btConnectedMac: ""
    property bool btConnected: false
    property string btDeviceName: ""

    property bool triggerNetText: false
    property bool triggerBtText: false

    property bool isNetInitialized: false
    onActiveNetTypeChanged: {
        if (dash.isNetInitialized) {
            dash.netIslandExpanded = true;
            netPopupTimer.restart();
        }
    }
    onActiveNetNameChanged: { triggerNetText = true; netTextTimer.restart(); }
    onBtConnectedChanged: { 
        triggerBtText = true; btTextTimer.restart(); 
        if (!btConnected) {
            dash.btConnectedMac = "";
            dash.btDeviceName = "";
            dash.btIslandBattery = "";
            dash.btIslandExpanded = false;
        }
    }

    property bool btIslandExpanded: false
    property string btIslandBattery: ""
    Timer { id: btPopupTimer; interval: NotchConfig.timerBtPopup; onTriggered: dash.btIslandExpanded = false }
    Timer { id: powerPopupTimer; interval: NotchConfig.timerPowerPopup; onTriggered: dash.powerIslandExpanded = false }
    Timer { id: netPopupTimer; interval: NotchConfig.timerNetPopup; onTriggered: dash.netIslandExpanded = false }

    Timer { id: netTextTimer; interval: NotchConfig.timerIslandText; onTriggered: triggerNetText = false }
    Timer { id: btTextTimer; interval: NotchConfig.timerIslandText; onTriggered: triggerBtText = false }

    onIsBatteryChargingChanged: {
        if (isBatteryCharging && !dash.btStartupGraceActive) {
            dash.powerIslandExpanded = true;
            powerPopupTimer.restart();
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netPoller.running = true;
        }
    }

    Process {
        id: netPoller
        command: ["sh", "-c", "nmcli -t -f TYPE,CONNECTION,STATE dev | grep -E '^(ethernet|wifi):.*:connected'; echo '---'; nmcli -t -f IN-USE,SIGNAL dev wifi list --rescan no 2>/dev/null | grep '^\\*' | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rawText = this.text.trim();
                var sections = rawText.split("---");
                var devSection = sections[0] ? sections[0].trim() : "";
                var sigStr = sections[1] ? sections[1].trim() : "0";

                var devLines = devSection.length > 0 ? devSection.split("\n") : [];
                var ethConn = null;
                var wifiClientConn = null;
                var hotspotConn = null;

                for (var i = 0; i < devLines.length; i++) {
                    var l = devLines[i].trim();
                    if (l.length === 0) continue;
                    var parts = l.split(":");
                    if (parts.length >= 3 && parts[2].indexOf("connected") !== -1) {
                        var type = parts[0].toLowerCase();
                        var conName = parts[1];
                        if (type.indexOf("ethernet") !== -1) {
                            ethConn = conName;
                        } else if (type.indexOf("wifi") !== -1 || type.indexOf("wireless") !== -1) {
                            if (conName.toLowerCase().indexOf("hotspot") !== -1) {
                                hotspotConn = conName;
                            } else {
                                wifiClientConn = conName;
                            }
                        }
                    }
                }

                // Prioritize: 1. Ethernet (wired) > 2. Wi-Fi Client > 3. Hotspot AP
                if (ethConn !== null) {
                    dash.activeNetType = "eth";
                    dash.activeNetName = ethConn;
                    dash.activeNetSignal = 100;
                } else if (wifiClientConn !== null) {
                    dash.activeNetType = "wifi";
                    dash.activeNetName = wifiClientConn;
                    dash.activeNetSignal = parseInt(sigStr) || 0;
                } else if (hotspotConn !== null) {
                    dash.activeNetType = "wifi";
                    dash.activeNetName = hotspotConn;
                    dash.activeNetSignal = 100;
                } else {
                    dash.activeNetType = "wifi";
                    dash.activeNetName = "";
                    dash.activeNetSignal = 0;
                }
                dash.isNetInitialized = true;
            }
        }
    }

    // Native Event-Driven Bluetooth Tracking (Section 1.2)
    readonly property var connectedBtDevice: {
        if (typeof Bluetooth === "undefined" || !Bluetooth.devices) return null;
        var list = Bluetooth.devices.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].connected) return list[i];
        }
        return null;
    }

    property bool btStartupGraceActive: true
    Timer { id: btStartupGraceTimer; interval: 2200; running: true; repeat: false; onTriggered: dash.btStartupGraceActive = false }

    onConnectedBtDeviceChanged: {
        if (connectedBtDevice) {
            var newMac = connectedBtDevice.address || "";
            var newName = connectedBtDevice.name ? connectedBtDevice.name.trim() : newMac;
            var isNewDevice = (!dash.btConnected || dash.btConnectedMac !== newMac);
            dash.btConnected = true;
            dash.btConnectedMac = newMac;
            dash.btDeviceName = newName;
            if (isNewDevice && !dash.btStartupGraceActive) {
                dash.btIslandExpanded = true;
                btPopupTimer.restart();
                dash.triggerBtText = true;
                btTextTimer.restart();
            }
            if (!btBatteryPoller.running) btBatteryPoller.running = true;
        } else {
            dash.btConnected = false;
            dash.btConnectedMac = "";
            dash.btDeviceName = "";
            dash.btIslandBattery = "";
            dash.btIslandExpanded = false;
        }
    }

    Process {
        id: btBatteryPoller
        running: false
        command: ["python3", Qt.resolvedUrl("../scripts/bt-status.py").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                var line = this.text.trim();
                var parts = line.split("|");
                if (parts.length >= 4 && parts[0] === "1" && parts[3]) {
                    dash.btIslandBattery = parts[3];
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: dash.btConnected
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!btBatteryPoller.running) btBatteryPoller.running = true;
        }
    }

    readonly property int activeWsId: Hyprland.focusedWorkspace?.id > 0 ? Hyprland.focusedWorkspace.id : 1
    readonly property int workspaceGroupStart: Math.floor((activeWsId - 1) / 10) * 10 + 1
    property var workspaceIds: [1, 2]
    onActiveWsIdChanged: refreshWorkspaceIds()

    property real wsWheelAcc: 0
    property real wsWheelLastMs: 0

    function switchToWorkspace(wsId) {
        if (Number.isInteger(wsId) && wsId > 0)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })");
    }

    function handleWorkspaceScroll(deltaY) {
        if (deltaY === 0) return;
        const now = Date.now();
        if (now - wsWheelLastMs > 350 || Math.sign(deltaY) !== Math.sign(wsWheelAcc))
            wsWheelAcc = 0;
        wsWheelLastMs = now;
        wsWheelAcc += deltaY;

        if (Math.abs(wsWheelAcc) < 120) return;
        const steps = Math.trunc(wsWheelAcc / 120);
        wsWheelAcc -= steps * 120;
        const count = workspaceIds.length;
        const offset = ((activeWsId - workspaceGroupStart - steps) % count + count) % count;
        dash.switchToWorkspace(workspaceGroupStart + offset);
    }

    function refreshWorkspaceIds() {
        const start = dash.workspaceGroupStart;
        const end = start + 9;
        let maxOccupied = dash.activeWsId;
        if (typeof Hyprland !== "undefined" && Hyprland.workspaces && Hyprland.workspaces.values) {
            for (const ws of Hyprland.workspaces.values) {
                if (ws && ws.id >= start && ws.id <= end) {
                    const winCount = (ws.toplevels && ws.toplevels.values) ? ws.toplevels.values.length : (typeof ws.windows === "number" ? ws.windows : 0);
                    if (winCount > 0) {
                        maxOccupied = Math.max(maxOccupied, ws.id);
                    }
                }
            }
        }
        // GNOME dynamic workspaces: show all occupied/active workspaces + exactly 1 empty workspace
        const last = Math.min(end, maxOccupied + 1);
        const count = Math.max(1, last - start + 1);
        const newIds = Array.from({ length: count }, (_, index) => start + index);
        if (dash.workspaceIds.length !== newIds.length || dash.workspaceIds.some((id, idx) => id !== newIds[idx])) {
            dash.workspaceIds = newIds;
        }
    }

    property int workspaceWindowCountTick: 0

    function getWorkspaceWindowCount(wsId) {
        var _tick = dash.workspaceWindowCountTick;
        if (typeof Hyprland === "undefined" || !Hyprland.workspaces) return 0;
        var ws = Hyprland.workspaces.values.find(function(w) { return w.id === wsId; });
        if (!ws) return 0;
        if (ws.toplevels && ws.toplevels.values) return ws.toplevels.values.length;
        if (typeof ws.windows === "number") return ws.windows;
        return 0;
    }

    Component.onCompleted: refreshWorkspaceIds()

    Connections {
        target: typeof Hyprland !== "undefined" ? Hyprland : null
        function onFocusedWorkspaceChanged() {
            dash.refreshWorkspaceIds();
            dash.workspaceWindowCountTick++;
        }
        function onRawEvent(event) {
            var evName = (typeof event === "object" && event !== null) ? event.name : event;
            if (evName === "workspace" || evName === "focusedmon" || evName === "workspacev2" || evName === "createworkspace" || evName === "destroyworkspace" || evName === "openwindow" || evName === "closewindow" || evName === "movewindow") {
                dash.refreshWorkspaceIds();
                dash.workspaceWindowCountTick++;
            }
        }
    }

    // Dynamic Island Container
    Item {
        id: islandContainer
        anchors.fill: parent
        readonly property bool showIsland: dash.isIslandActive && dash.currentIslandType !== "notif"
        opacity: showIsland ? 1.0 : 0.0
        scale: showIsland ? 1.0 : 0.9
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }
        Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }

        onOpacityChanged: {
            if (opacity <= 0.01 && !dash.isIslandActive) {
                dash.displayedIslandType = "";
            }
        }

        // Screenshot Annotation Hub Island (Section 4.1)
        RowLayout {
            id: screenshotPopupRow
            anchors.centerIn: parent
            spacing: 10
            visible: (dash.displayedIslandType || dash.currentIslandType) === "screenshot"

            // 1. Thumbnail Preview (or fallback icon)
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 6
                color: Qt.rgba(0, 0, 0, 0.4)
                clip: true
                border.width: 0
                border.color: "transparent"
                Layout.alignment: Qt.AlignVCenter

                Image {
                    anchors.fill: parent
                    source: root.screenshotIslandPath !== "" ? ("file://" + root.screenshotIslandPath) : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    cache: false
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.screenshotIslandPath === ""
                    text: "photo_camera"
                    font.family: Theme.fontFamilyIcon
                    font.pixelSize: 16
                    font.hintingPreference: Font.PreferNoHinting
                    font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 16, "wght": 500 })
                    renderType: Text.CurveRendering
                    antialiasing: true
                    smooth: true
                    color: Theme.accent
                }
            }

            // 2. Info text Column
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    text: "Screenshot"
                    font.family: "Google Sans Flex"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.variableAxes: ({ "wght": 560, "wdth": 100 })
                    font.hintingPreference: Font.PreferNoHinting
                    renderType: Text.QtRendering
                    antialiasing: true
                    smooth: true
                    color: Theme.colors.text_primary ?? "white"
                }

                Text {
                    text: root.screenshotIslandStatus !== "" ? root.screenshotIslandStatus : "Captured & Copied"
                    font.family: "Google Sans Flex"
                    font.pixelSize: 10
                    font.variableAxes: ({ "wght": 450, "wdth": 100 })
                    font.hintingPreference: Font.PreferNoHinting
                    renderType: Text.QtRendering
                    antialiasing: true
                    smooth: true
                    color: root.screenshotIslandStatus !== "" ? Theme.accent : (Theme.colors.text_secondary ?? "#565f89")
                }
            }

            // 3. Action Buttons Row
            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                // Action 1: Annotate (swappy)
                Rectangle {
                    width: annotRow.implicitWidth + 14
                    height: 24
                    radius: 12
                    color: annotMouse.containsMouse ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                    border.width: 0
                    border.color: "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Row {
                        id: annotRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "edit"
                            font.family: Theme.fontFamilyIcon
                            font.pixelSize: 13
                            font.hintingPreference: Font.PreferNoHinting
                            font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 13, "wght": 500 })
                            renderType: Text.CurveRendering
                            antialiasing: true
                            smooth: true
                            color: annotMouse.containsMouse ? Theme.onAccent : Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Annotate"
                            font.family: "Google Sans Flex"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            font.variableAxes: ({ "wght": 550, "wdth": 100 })
                            font.hintingPreference: Font.PreferNoHinting
                            renderType: Text.QtRendering
                            antialiasing: true
                            smooth: true
                            color: annotMouse.containsMouse ? Theme.onAccent : (Theme.colors.text_primary ?? "#ffffff")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: annotMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["swappy", "-f", root.screenshotIslandPath]);
                            root.screenshotIslandPath = "";
                            root.screenshotIslandStatus = "";
                        }
                    }
                }

                // Action 4: Close / Dismiss
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: closeMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: Theme.fontFamilyIcon
                        font.pixelSize: 14
                        font.hintingPreference: Font.PreferNoHinting
                        font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 14, "wght": 500 })
                        renderType: Text.CurveRendering
                        antialiasing: true
                        smooth: true
                        color: closeMouse.containsMouse ? (Theme.colors.text_primary ?? "white") : (Theme.colors.text_secondary ?? "#565f89")
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.screenshotIslandPath = "";
                            root.screenshotIslandStatus = "";
                        }
                    }
                }
            }
        }

        // Workspace switch OSD: the active dot stretches into a pill with comfortable spacing.
        Item {
            id: wsIslandContainer
            anchors.centerIn: parent
            width: wsIslandRow.implicitWidth
            height: wsIslandRow.implicitHeight
            visible: (dash.displayedIslandType || dash.currentIslandType) === "workspace"

            Row {
                id: wsIslandRow
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    model: dash.workspaceIds

                    delegate: Item {
                        id: indicator
                        required property int modelData
                        readonly property bool isFocused: modelData === dash.activeWsId

                        width: isFocused ? 26 : 8
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on width {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 8
                            radius: height / 2
                            color: indicator.isFocused ? Theme.accent
                                : dotMouse.containsMouse ? (Theme.colors.text_primary ?? "#c0caf5")
                                : Qt.rgba(1, 1, 1, 0.28)

                            Behavior on color {
                                ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: dotMouse
                            anchors.centerIn: parent
                            width: parent.width + wsIslandRow.spacing
                            height: parent.height
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: dash.switchToWorkspace(indicator.modelData)
                            onWheel: (wheel) => {
                                wheel.accepted = true;
                                dash.handleWorkspaceScroll(wheel.angleDelta.y);
                            }
                        }
                    }
                }
            }

            // Mouse wheel workspace scrolling on entire island
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                z: -1
                onWheel: (wheel) => {
                    wheel.accepted = true;
                    dash.handleWorkspaceScroll(wheel.angleDelta.y);
                }
            }
        }

        // Bluetooth Connected OSD (Matushell OsdText style)
        Row {
            id: btPopupRow
            anchors.centerIn: parent
            spacing: 10
            visible: (dash.displayedIslandType || dash.currentIslandType) === "bluetooth"

            readonly property bool isAudioDevice: {
                const n = (dash.btDeviceName || "").toLowerCase();
                return n.includes("bud") || n.includes("headphone") || n.includes("wh-") || n.includes("airpod") || n.includes("ear") || n.includes("pod") || n.includes("headset") || n.includes("tws");
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: btPopupRow.isAudioDevice ? "headphones" : "bluetooth"
                color: Theme.accent
                font.family: Theme.fontFamilyIcon
                font.pixelSize: 20
                font.hintingPreference: Font.PreferNoHinting
                font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                renderType: Text.CurveRendering
                antialiasing: true
                smooth: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Connected: " + (dash.btDeviceName || "Bluetooth")
                color: Theme.colors.text_primary ?? "#eceff4"
                font.family: "Google Sans Flex"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.variableAxes: ({ "wght": 560, "wdth": 100 })
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
            }

            Rectangle {
                visible: dash.btIslandBattery !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: btBatRow.implicitWidth + 12
                height: 20
                radius: height / 2
                color: Qt.alpha(Theme.accent, 0.16)

                Row {
                    id: btBatRow
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "battery_android_full"
                        color: Theme.accent
                        font.family: Theme.fontFamilyIcon
                        font.pixelSize: 13
                        font.hintingPreference: Font.PreferNoHinting
                        font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 13, "wght": 500 })
                        renderType: Text.CurveRendering
                        antialiasing: true
                        smooth: true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: dash.btIslandBattery
                        color: Theme.accent
                        font.family: "Google Sans Flex"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.variableAxes: ({ "wght": 560, "wdth": 100 })
                        font.features: ({ "tnum": 1 })
                        font.hintingPreference: Font.PreferNoHinting
                        renderType: Text.QtRendering
                        antialiasing: true
                        smooth: true
                    }
                }
            }
        }

        // Power / Charging Connected OSD (Matushell OsdProgress style)
        Row {
            id: powerPopupRow
            anchors.centerIn: parent
            spacing: 10
            visible: (dash.displayedIslandType || dash.currentIslandType) === "power"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "battery_charging_full"
                color: Theme.accent
                font.family: Theme.fontFamilyIcon
                font.pixelSize: 20
                font.hintingPreference: Font.PreferNoHinting
                font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                renderType: Text.CurveRendering
                antialiasing: true
                smooth: true
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 96
                height: 16
                readonly property real frac: Math.max(0, Math.min(1, dash.currentBatteryLevel / 100.0))
                readonly property real handleX: 3 + frac * (width - 6)

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.handleX - 4.5)
                    height: 8
                    topLeftRadius: 4
                    bottomLeftRadius: 4
                    topRightRadius: 2
                    bottomRightRadius: 2
                    color: Theme.accent
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, (parent.width - parent.handleX) - 4.5)
                    height: 8
                    topLeftRadius: 2
                    bottomLeftRadius: 2
                    topRightRadius: 4
                    bottomRightRadius: 4
                    color: Qt.alpha(Theme.colors.text_primary ?? "#f5f5f7", 0.16)
                }

                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.handleX - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 15
                    radius: 2
                    color: Theme.accent
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dash.currentBatteryLevel + "%"
                color: Theme.colors.text_primary ?? "#f5f5f7"
                font.family: "Google Sans Flex"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.variableAxes: ({ "wght": 560, "wdth": 100 })
                font.features: ({ "tnum": 1 })
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
            }
        }

        // Network Handoff OSD (Matushell OsdText style)
        Row {
            id: netPopupRow
            anchors.centerIn: parent
            spacing: 10
            visible: (dash.displayedIslandType || dash.currentIslandType) === "net"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dash.activeNetType === "eth" ? "lan" : "network_wifi"
                color: Theme.accent
                font.family: Theme.fontFamilyIcon
                font.pixelSize: 20
                font.hintingPreference: Font.PreferNoHinting
                font.variableAxes: ({ "FILL": 0, "GRAD": Theme.fontIconGrad, "opsz": 20, "wght": 500 })
                renderType: Text.CurveRendering
                antialiasing: true
                smooth: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Connected: " + (dash.activeNetType === "eth" ? "Ethernet" : (dash.activeNetName || "Wi-Fi"))
                color: Theme.colors.text_primary ?? "#f5f5f7"
                font.family: "Google Sans Flex"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.variableAxes: ({ "wght": 560, "wdth": 100 })
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
            }
        }
    }

    // Iris Cava Waveform Component
    component IrisWaveform: Item {
        id: wave
        property bool running: dash.isMediaPlaying && !root.notchHidden && (root.activeMode === "idle" || root.activeMode === "hover")
        property int bars: 5
        property real barHeight: 13
        
        implicitWidth: bars * 3 + (bars - 1) * 2
        implicitHeight: barHeight
        
        readonly property var restShape: [0.45, 0.8, 0.6, 0.9, 0.5]
        
        Row {
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: wave.bars
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    radius: width / 2
                    color: Theme.accent
                    height: {
                        if (!wave.running) return 3;
                        if (cavaViz.audioSignalActive && cavaViz.points.length > index) {
                            var level = Math.min(1, (cavaViz.points[index] || 0) / Math.max(1, cavaViz.normalizationCeiling));
                            return Math.max(3, level * wave.barHeight);
                        }
                        return Math.max(3, (wave.restShape[index] || 0.4) * wave.barHeight);
                    }
                    Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                }
            }
        }
    }


    DashComponents.NotificationBanner {
        id: notificationBanner
        z: 2
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(preferredWidth, root.isNotifPopupActive ? root.targetWidth : preferredWidth)
        surfaceWidth: dash.width
        surfaceHeight: dash.height
        notification: root.notificationBanner
        active: dash.currentIslandType === "notif" && root.isDashMode
        onHoverChanged: hovered => root.setNotificationBannerHovered(hovered)
        onDismissed: root.dismissNotificationBanner()
        onOpened: {
            root.dismissNotificationBanner();
            root.switchMode("notifications", true);
        }
    }

    // ========================================================
    // 1. IRIS IDLE CAPSULE (Look 1: Idle when no music)
    // ========================================================
    Item {
        id: idleRow
        anchors.fill: parent
        opacity: (root.activeMode === "idle" && !dash.isMediaPlaying && !dash.isIslandActive) ? 1.0 : 0.0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    root.switchMode("calendar", true);
                } else {
                    root.openUtility("", true);
                }
            }
        }

        // Matushell resting Dynamic Island glance row
        DashComponents.IslandIdleGlances {
            id: idleGlances
            anchors.centerIn: parent
            z: 2
            clockDate: clock.date
            isScreenRecording: root.isScreenRecording
            notificationCount: (typeof globalNotifModel !== "undefined") ? globalNotifModel.count : 0
            dndEnabled: root.dndEnabled
            activeNetType: dash.activeNetType
            activeNetName: dash.activeNetName
            activeNetSignal: dash.activeNetSignal
            onTimerOpenRequested: tab => root.openClockTab(tab)
        }
    }

    // ========================================================
    // 2. IRIS IDLE WITH MUSIC CAPSULE (Look 2: Idle with music)
    // ========================================================
    Item {
        id: musicIdleCapsule
        anchors.fill: parent
        opacity: (root.activeMode === "idle" && dash.isMediaPlaying && !dash.showMusicInfo && !dash.isIslandActive) ? 1.0 : 0.0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton) {
                    Quickshell.execDetached(["playerctl", "play-pause"]);
                } else if (mouse.button === Qt.RightButton) {
                    root.switchMode("calendar", true);
                } else {
                    root.switchMode("music", true);
                }
            }
        }

        DashComponents.IslandIdleGlances {
            id: musicIdleGlances
            anchors.centerIn: parent
            z: 2
            clockDate: clock.date
            isScreenRecording: root.isScreenRecording
            notificationCount: (typeof globalNotifModel !== "undefined") ? globalNotifModel.count : 0
            dndEnabled: root.dndEnabled
            activeNetType: dash.activeNetType
            activeNetName: dash.activeNetName
            activeNetSignal: dash.activeNetSignal
            onTimerOpenRequested: tab => root.openClockTab(tab)
        }
    }

    // ========================================================
    // 3. IRIS EXPANDED MUSIC CAPSULE (Look 3: Super+Shift+M Music Info)
    // ========================================================
    Item {
        id: musicExpandedCapsule
        anchors.fill: parent
        opacity: (root.activeMode === "idle" && dash.isMediaPlaying && dash.showMusicInfo && !dash.isIslandActive) ? 1.0 : 0.0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton) {
                    Quickshell.execDetached(["playerctl", "play-pause"]);
                } else {
                    root.switchMode("music", true);
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            // Left: Circular Album Cover (22px)
            IrisArtwork {
                source: dash.currentAlbumArt
                circular: true
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
            }

            // Center Column: Title and Progress Bar
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: dash.currentSongTitle
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.colors.text_primary ?? "#f5f5f7"
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: dash.trackLength > 0
                    implicitHeight: 2
                    radius: 1
                    color: Qt.rgba(1, 1, 1, 0.18)
                    clip: true

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                        width: parent.width * dash.trackProgress
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }
            }

            // Tabular Clock Time
            Text {
                text: {
                    var h = clock.date.getHours() % 12 || 12;
                    var m = clock.date.getMinutes();
                    var hh = String(h);
                    var mm = (m < 10 ? "0" : "") + m;
                    return hh + ":" + mm;
                }
                color: Theme.colors.text_secondary ?? "#aeaeb2"
                font.family: "Google Sans Flex"
                font.pixelSize: 12
                font.weight: Font.Medium
                font.variableAxes: ({ "wght": 500, "wdth": 100 })
                font.features: ({ "tnum": 1 })
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
                Layout.alignment: Qt.AlignVCenter
            }

            BarTimeReadouts {
                id: expandedMusicReadouts
                Layout.alignment: Qt.AlignVCenter
                onOpenRequested: tab => root.openClockTab(tab)
            }

            // Live Waveform
            IrisWaveform {
                running: dash.isMediaPlaying && (root.activeMode === "idle" || root.activeMode === "hover")
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // Roman numeral lookup for modern minimalist workspaces
    readonly property var romanNumerals: ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

    function getWorkspaceLabel(wsId) {
        if (wsId >= 1 && wsId <= 10) return romanNumerals[wsId - 1];
        return String(wsId);
    }

    // ========================================================
    // 4. MATUSHELL-STYLE DYNAMIC ISLAND EXPANDED BAR (Hover Mode)
    // ========================================================
    RowLayout {
        id: dashRow
        anchors.centerIn: parent
        spacing: 10
        readonly property color fgPrimary: Theme.colors.text_primary ?? "#f5f5f7"
        readonly property color fgMuted: Qt.alpha(fgPrimary, 0.48)
        property real hoverBlend: root.activeMode === "hover" && !dash.isIslandActive ? 1 : 0

        opacity: hoverBlend * NotchConfig.revealBetween(dash.width / Math.max(1, implicitWidth), 0.72, 1.04)
        visible: opacity > 0.01

        Behavior on hoverBlend {
            NumberAnimation {
                duration: root.activeMode === "hover" ? NotchConfig.animContentEnter : NotchConfig.animContentExit
                easing.type: Easing.OutCubic
            }
        }

        // ── 1. LEFT GROUP: LAUNCHER & WORKSPACES ─────────────────
        Row {
            id: leftGroupRow
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            // Distro Logo Launcher Button (crisp vector CurveRendering)
            Item {
                width: 28
                height: 28
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: launcherBg
                    anchors.fill: parent
                    radius: height / 2
                    color: launcherMouse.pressed
                        ? Qt.alpha(Theme.accent, 0.24)
                        : (launcherMouse.containsMouse ? Qt.alpha(Theme.accent, 0.14) : "transparent")
                    scale: launcherMouse.pressed ? 0.92 : (launcherMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: dash.distroGlyph
                        color: Theme.accent
                        font.family: Theme.fontFamilyNerd
                        font.pixelSize: 18
                        font.hintingPreference: Font.PreferNoHinting
                        renderType: Text.CurveRendering
                        antialiasing: true
                        smooth: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MouseArea {
                    id: launcherMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("launcher", false)
                }
            }

            // Subtle Hairline Divider
            Rectangle {
                width: 1
                height: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(dashRow.fgPrimary, 0.14)
            }

            // Workspaces Pager: clean pill chips in crisp Google Sans Flex
            Row {
                id: wsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: dash.workspaceIds

                    delegate: Rectangle {
                        id: wsCell
                        required property int modelData
                        readonly property int wsId: modelData
                        readonly property bool isFocused: wsCell.wsId === dash.activeWsId
                        readonly property int winCount: dash.getWorkspaceWindowCount(wsCell.wsId)
                        readonly property bool hasWindows: wsCell.winCount > 0

                        width: isFocused ? 28 : 22
                        height: 22
                        implicitWidth: width
                        implicitHeight: height
                        radius: height / 2
                        anchors.verticalCenter: parent.verticalCenter

                        color: isFocused
                            ? Theme.accent
                            : (wsCellMouse.containsMouse
                                ? Qt.alpha(dashRow.fgPrimary, 0.14)
                                : (wsCell.hasWindows ? Qt.alpha(dashRow.fgPrimary, 0.08) : "transparent"))

                        scale: wsCellMouse.pressed ? 0.92 : (wsCellMouse.containsMouse && !isFocused ? 1.06 : 1.0)

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: String(wsCell.wsId)
                            color: wsCell.isFocused
                                ? Theme.onAccent
                                : (wsCellMouse.containsMouse || wsCell.hasWindows
                                    ? dashRow.fgPrimary
                                    : Qt.alpha(dashRow.fgPrimary, 0.4))
                            font.family: "Google Sans Flex"
                            font.pixelSize: 12
                            font.weight: wsCell.isFocused ? Font.DemiBold : Font.Medium
                            font.variableAxes: ({ "wght": wsCell.isFocused ? 620 : 500, "wdth": 100 })
                            font.features: ({ "tnum": 1 })
                            font.hintingPreference: Font.PreferNoHinting
                            renderType: Text.QtRendering
                            antialiasing: true
                            smooth: true

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: wsCellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dash.switchToWorkspace(wsCell.wsId)
                            onWheel: (wheel) => {
                                wheel.accepted = true;
                                dash.handleWorkspaceScroll(wheel.angleDelta.y);
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 1
            Layout.preferredHeight: 14
            color: Qt.alpha(dashRow.fgPrimary, 0.14)
        }

        // ── 2. CENTER GROUP: MATUSHELL DATE & CLOCK ──────────────
        Item {
            id: centerItem
            Layout.preferredHeight: 28
            Layout.preferredWidth: centerGroupRow.implicitWidth + 14
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: centerMouse.containsMouse ? Qt.alpha(dashRow.fgPrimary, 0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            RowLayout {
                id: centerGroupRow
                z: 1
                anchors.centerIn: parent
                spacing: 6

                Row {
                    id: hoverDateClockRow
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 5

                    Text {
                        anchors.baseline: hoverClock.baseline
                        text: Qt.formatDate(clock.date, "ddd, MMM d")
                        color: dashRow.fgPrimary
                        font.family: "Google Sans Flex"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.variableAxes: ({ "wght": 500, "wdth": 100 })
                        font.hintingPreference: Font.PreferNoHinting
                        renderType: Text.QtRendering
                        antialiasing: true
                        smooth: true
                    }

                    Text {
                        anchors.baseline: hoverClock.baseline
                        text: "•"
                        color: Qt.alpha(dashRow.fgPrimary, 0.72)
                        font.family: "Google Sans Flex"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.variableAxes: ({ "wght": 500, "wdth": 100 })
                        font.hintingPreference: Font.PreferNoHinting
                        renderType: Text.QtRendering
                        antialiasing: true
                        smooth: true
                    }

                    IrisClock {
                        id: hoverClock
                        pixelSize: 13
                        family: "Google Sans Flex"
                        weight: Font.Medium
                        axisWeight: 500
                        renderType: Text.QtRendering
                        text: {
                            var h = clock.date.getHours() % 12 || 12;
                            var m = clock.date.getMinutes();
                            return String(h) + ":" + (m < 10 ? "0" : "") + m;
                        }
                        color: dashRow.fgPrimary
                        separatorColor: Theme.accent
                        isScreenRecording: root.isScreenRecording
                    }
                }

                BarTimeReadouts {
                    Layout.alignment: Qt.AlignVCenter
                    onOpenRequested: tab => root.openClockTab(tab)
                }
            }

            MouseArea {
                id: centerMouse
                z: 0
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.switchMode("calendar");
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 1
            Layout.preferredHeight: 14
            color: Qt.alpha(dashRow.fgPrimary, 0.14)
        }

        // ── 3. RIGHT GROUP: MATUS BATTERY CAPSULE & CONTROLS ────
        RowLayout {
            id: rightGroupRow
            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            // Shared Matushell Material Battery Capsule (same icon/font as resting island)
            Item {
                Layout.preferredHeight: 28
                Layout.preferredWidth: hoverBattery.implicitWidth + 10
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: battMouse.pressed
                        ? Qt.alpha(dashRow.fgPrimary, 0.14)
                        : (battMouse.containsMouse ? Qt.alpha(dashRow.fgPrimary, 0.08) : "transparent")
                    scale: battMouse.pressed ? 0.94 : (battMouse.containsMouse ? 1.04 : 1.0)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    DashComponents.MatusBatteryCapsule {
                        id: hoverBattery
                        anchors.centerIn: parent
                    }
                }

                MouseArea {
                    id: battMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("battery", false)
                }
            }

            // Hairline Divider
            Rectangle {
                width: 1
                height: 14
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                color: Qt.alpha(dashRow.fgPrimary, 0.14)
            }

            // Control Center Toggle (clean instant_mix sliders icon)
            Item {
                width: 28
                height: 28
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: ccMouse.pressed
                        ? Qt.alpha(Theme.accent, 0.24)
                        : (ccMouse.containsMouse ? Qt.alpha(Theme.accent, 0.14) : "transparent")
                    scale: ccMouse.pressed ? 0.92 : (ccMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: "instant_mix"
                        color: ccMouse.containsMouse ? Theme.accent : dashRow.fgPrimary
                        font.family: Theme.fontFamilyIcon
                        font.pixelSize: 17
                        font.hintingPreference: Font.PreferNoHinting
                        font.variableAxes: ({
                            "FILL": 0,
                            "GRAD": Theme.fontIconGrad,
                            "opsz": 17,
                            "wght": 500
                        })
                        renderType: Text.CurveRendering
                        antialiasing: true
                        smooth: true

                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                }

                MouseArea {
                    id: ccMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openUtility("", false)
                }
            }

            // Power Menu Toggle (clean power_settings_new with soft crimson hover tint)
            Item {
                width: 28
                height: 28
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: pwrMouse.pressed
                        ? Qt.rgba(1, 0.33, 0.29, 0.24)
                        : (pwrMouse.containsMouse ? Qt.rgba(1, 0.33, 0.29, 0.15) : "transparent")
                    scale: pwrMouse.pressed ? 0.92 : (pwrMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        color: pwrMouse.containsMouse ? (Theme.colors.error ?? "#ffb4ab") : Qt.alpha(dashRow.fgPrimary, 0.85)
                        font.family: Theme.fontFamilyIcon
                        font.pixelSize: 17
                        font.hintingPreference: Font.PreferNoHinting
                        font.variableAxes: ({
                            "FILL": 0,
                            "GRAD": Theme.fontIconGrad,
                            "opsz": 17,
                            "wght": 500
                        })
                        renderType: Text.CurveRendering
                        antialiasing: true
                        smooth: true

                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                }

                MouseArea {
                    id: pwrMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("powermenu", false)
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
