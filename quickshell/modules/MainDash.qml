import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../"

Item {
    id: dash
    Layout.fillWidth: true
    Layout.fillHeight: true

    readonly property var upowerDev: (typeof UPower !== "undefined") ? UPower.displayDevice : null
    readonly property int currentBatteryLevel: (upowerDev && upowerDev.percentage !== undefined) ? Math.round(upowerDev.percentage * 100) : 100
    readonly property bool isBatteryCharging: (upowerDev && upowerDev.state !== undefined) ? (upowerDev.state === UPowerDevice.Charging) : false

    property bool netIslandExpanded: false
    property bool powerIslandExpanded: false
    property bool isIslandActive: btIslandExpanded || powerIslandExpanded || netIslandExpanded || root.isNotifPopupActive || root.isWorkspacePeeking || root.isScreenshotIslandActive || root.isPomoFinishedIslandActive

    readonly property string currentIslandType: {
        if (root.isPomoFinishedIslandActive) return "pomo_done";
        if (root.isScreenshotIslandActive) return "screenshot";
        if (root.isNotifPopupActive) return "notif";
        if (btIslandExpanded) return "bluetooth";
        if (powerIslandExpanded) return "power";
        if (netIslandExpanded) return "net";
        if (root.isWorkspacePeeking) return "workspace";
        return "";
    }

    property string displayedIslandType: ""

    onCurrentIslandTypeChanged: {
        if (currentIslandType !== "") {
            displayedIslandType = currentIslandType;
        }
    }

    property int activeIslandWidth: {
        if (displayedIslandType === "pomo_done" || root.isPomoFinishedIslandActive) {
            return Math.max(380, pomoDonePopupRow.implicitWidth + 36);
        }
        if (displayedIslandType === "screenshot" || root.isScreenshotIslandActive) {
            return Math.max(260, screenshotPopupRow.implicitWidth + 36);
        }
        if (displayedIslandType === "notif" || root.isNotifPopupActive) {
            var textW = Math.max(notifSummaryText.implicitWidth, notifBodyText.implicitWidth);
            return Math.min(520, Math.max(260, textW + 80));
        }
        if (displayedIslandType === "workspace" || root.isWorkspacePeeking) {
            return Math.max(136, wsIslandRow.implicitWidth + 36);
        }
        if (displayedIslandType === "bluetooth" || btIslandExpanded) return btPopupRow.implicitWidth + 36;
        if (displayedIslandType === "power" || powerIslandExpanded) return powerPopupRow.implicitWidth + 36;
        if (displayedIslandType === "net" || netIslandExpanded) return netPopupRow.implicitWidth + 36;
        return 120;
    }

    implicitWidth: {
        if (isIslandActive) return activeIslandWidth;
        if (root.activeMode === "hover") {
            return Math.max(160, dashRow.implicitWidth + 32);
        }
        if (dash.isMediaPlaying && root.activeMode === "idle") {
            var baseMusic = dash.showMusicInfo ? 340 : 240;
            if (root.pomoRunning) baseMusic += 80;
            return baseMusic;
        }
        return Math.max(184, idleCluster.implicitWidth + 36);  // Iris idle width (DateMark + IrisClock)
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
        var art = activeMprisPlayer.trackArtUrl || activeMprisPlayer.artUrl || "";
        return (art.startsWith("file://") || art.startsWith("http://") || art.startsWith("https://") || art.length > 0) ? art : "";
    }
    property real trackPosition: (activeMprisPlayer && activeMprisPlayer.position) ? activeMprisPlayer.position : 0
    property real trackLength: (activeMprisPlayer && activeMprisPlayer.length) ? activeMprisPlayer.length : 0
    property real trackProgress: trackLength > 0 ? Math.max(0, Math.min(1, trackPosition / trackLength)) : 0

    readonly property var motionCurve: [0.16, 1, 0.3, 1, 1, 1]  // Iris liquid morph curve

    // Cava visualizer for music
    CavaProcess {
        id: cavaViz
        active: dash.isMediaPlaying && (root.activeMode === "idle" || root.activeMode === "hover")
        bars: 5
    }

    // Native Event-Driven MPRIS Tracking (Section 1.1)
    readonly property var allMprisPlayers: (typeof Mpris !== "undefined" && Mpris.players) ? Mpris.players.values : []

    readonly property var activeMprisPlayer: {
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
        if (isBatteryCharging) {
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

    onConnectedBtDeviceChanged: {
        if (connectedBtDevice) {
            var newMac = connectedBtDevice.address || "";
            var newName = connectedBtDevice.name ? connectedBtDevice.name.trim() : newMac;
            var isNewDevice = (!dash.btConnected || dash.btConnectedMac !== newMac);
            dash.btConnected = true;
            dash.btConnectedMac = newMac;
            dash.btDeviceName = newName;
            if (isNewDevice) {
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

    // Stable workspace model tracking
    property var workspaceIds: [1]

    function refreshWorkspaceIds() {
        if (typeof Hyprland === "undefined" || !Hyprland.workspaces) return;
        var raw = Hyprland.workspaces.values.filter(function(w) { return w.id > 0; });
        var focusedId = (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0)
            ? Hyprland.focusedWorkspace.id
            : 1;
        var ids = [];
        var found = false;
        for (var i = 0; i < raw.length; i++) {
            ids.push(raw[i].id);
            if (raw[i].id === focusedId) found = true;
        }
        if (!found) ids.push(focusedId);
        ids.sort(function(a, b) { return a - b; });

        if (ids.length !== dash.workspaceIds.length) {
            dash.workspaceIds = ids;
            return;
        }
        for (var j = 0; j < ids.length; j++) {
            if (ids[j] !== dash.workspaceIds[j]) {
                dash.workspaceIds = ids;
                return;
            }
        }
    }

    Component.onCompleted: refreshWorkspaceIds()

    Connections {
        target: typeof Hyprland !== "undefined" ? Hyprland : null
        function onRawEvent(event) {
            var evName = (typeof event === "object" && event !== null) ? event.name : event;
            if (evName === "workspace" || evName === "focusedmon" || evName === "workspacev2" || evName === "createworkspace" || evName === "destroyworkspace") {
                dash.refreshWorkspaceIds();
            }
        }
    }

    // Dynamic Island Container
    Item {
        id: islandContainer
        anchors.fill: parent
        opacity: dash.isIslandActive ? 1.0 : 0.0
        scale: dash.isIslandActive ? 1.0 : 0.9
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
            visible: dash.displayedIslandType === "screenshot" || root.isScreenshotIslandActive

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
                    text: "󰄀"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Theme.accent
                }
            }

            // 2. Info text Column
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    text: "Screenshot"
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.colors.text_primary ?? "white"
                }

                Text {
                    text: root.screenshotIslandStatus !== "" ? root.screenshotIslandStatus : "Captured & Copied"
                    font.family: "Inter"
                    font.pixelSize: 9
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
                            text: "󰏫"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: annotMouse.containsMouse ? (Theme.colors.bg ?? "#16161e") : Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Annotate"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: annotMouse.containsMouse ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "#ffffff")
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
                            screenshotIslandTimer.stop();
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
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: closeMouse.containsMouse ? (Theme.colors.text_primary ?? "white") : (Theme.colors.text_secondary ?? "#565f89")
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            screenshotIslandTimer.stop();
                            root.screenshotIslandPath = "";
                            root.screenshotIslandStatus = "";
                        }
                    }
                }
            }
        }

        // Pomodoro Completed Celebration Island (Section 4.4)
        RowLayout {
            id: pomoDonePopupRow
            anchors.centerIn: parent
            spacing: 10
            visible: dash.displayedIslandType === "pomo_done" || root.isPomoFinishedIslandActive

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 13
                color: Qt.rgba(0.18, 0.82, 0.34, 0.22)
                border.width: 0
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "󰄬"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: "#30d158"
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    text: root.pomoFinishedTitle !== "" ? root.pomoFinishedTitle : "Sprint Complete!"
                    font.family: "Readex Pro"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: "#ffffff"
                    renderType: Text.NativeRendering
                }

                Text {
                    text: root.pomoFinishedMessage !== "" ? root.pomoFinishedMessage : "Take a well-deserved break"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    color: Theme.colors.text_secondary ?? "#8e8e93"
                    renderType: Text.NativeRendering
                }
            }

            // Quick transition action button
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: pomoNextActionText.implicitWidth + 16
                radius: 12
                color: pomoNextMouse.containsMouse ? Qt.alpha(Theme.accent, 0.35) : Qt.alpha(Theme.accent, 0.20)
                border.width: 0
                scale: pomoNextMouse.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                Text {
                    id: pomoNextActionText
                    anchors.centerIn: parent
                    text: root.pomoMode === "focus" ? "5m Break" : "25m Focus"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.accent
                }

                MouseArea {
                    id: pomoNextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.pomoMode === "focus") {
                            root.startPomodoro(5, "short_break");
                        } else {
                            root.startPomodoro(25, "focus");
                        }
                        root.isPomoFinishedIslandActive = false;
                    }
                }
            }

            // Dismiss
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: pomoDismissMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                scale: pomoDismissMouse.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 13
                    color: Theme.colors.text_secondary ?? "#8e8e93"
                }

                MouseArea {
                    id: pomoDismissMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isPomoFinishedIslandActive = false;
                        root.collapseToIdle();
                    }
                }
            }
        }

        // Pop-up Notification Row
        RowLayout {
            id: notifPopupRow
            anchors.centerIn: parent
            spacing: 8
            visible: dash.displayedIslandType === "notif" || root.isNotifPopupActive

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.accent
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    id: notifSummaryText
                    text: root.notifPopupSummary
                    font.family: "Inter"
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.colors.text_primary ?? "white"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 380
                }

                Text {
                    id: notifBodyText
                    text: root.notifPopupBody
                    font.family: "Inter"
                    font.pixelSize: 10
                    color: Theme.colors.text_secondary ?? "#565f89"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 380
                    visible: text !== ""
                }
            }
        }

        MouseArea {
            anchors.fill: notifPopupRow
            visible: notifPopupRow.visible
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                notifPopupTimer.stop();
                root.notifPopupSummary = "";
                root.notifPopupBody = "";
                root.switchMode("notifications", true);
            }
        }

        // Workspace Switch Island Row (minimalist dot-to-pill indicator)
        Row {
            id: wsIslandRow
            anchors.centerIn: parent
            spacing: 8
            visible: dash.displayedIslandType === "workspace" || (root.isWorkspacePeeking && !root.isNotifPopupActive && !dash.btIslandExpanded && !dash.powerIslandExpanded && !dash.netIslandExpanded)

            Repeater {
                model: dash.workspaceIds

                delegate: Item {
                    id: indicatorItem
                    property int wsId: modelData
                    property bool isFocused: typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && (wsId === Hyprland.focusedWorkspace.id)

                    width: isFocused ? 26 : 8
                    height: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        id: pillShape
                        anchors.fill: parent
                        radius: 4
                        color: indicatorItem.isFocused
                            ? Theme.accent
                            : (dotMouse.containsMouse ? (Theme.colors.text_primary ?? "#c0caf5") : Qt.rgba(1, 1, 1, 0.28))

                        Behavior on color {
                            ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }

                        // Soft glow ring for active workspace pill
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: 5
                            color: "transparent"
                            border.width: 0
                            border.color: "transparent"
                            opacity: indicatorItem.isFocused ? 0.35 : 0.0
                            visible: opacity > 0.001
                            Behavior on opacity {
                                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    MouseArea {
                        id: dotMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (typeof Hyprland !== "undefined") {
                                Hyprland.dispatch("hl.dsp.focus({ workspace = " + indicatorItem.wsId + " })");
                            }
                        }
                    }
                }
            }
        }

        // Bluetooth Connected Alert
        Row {
            id: btPopupRow
            anchors.centerIn: parent
            spacing: 8
            visible: dash.displayedIslandType === "bluetooth" || (dash.btIslandExpanded && !root.isNotifPopupActive && !root.isWorkspacePeeking)

            Rectangle {
                width: 22
                height: 22
                radius: 7
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                anchors.verticalCenter: parent.verticalCenter
                Text { 
                    anchors.centerIn: parent
                    text: (dash.btDeviceName.toLowerCase().includes("bud") || dash.btDeviceName.toLowerCase().includes("headphone") || dash.btDeviceName.toLowerCase().includes("wh-")) ? "󰋋" : "󰂱"
                    font.family: "JetBrainsMono Nerd Font"
                    color: Theme.accent
                    font.pixelSize: 13
                }
            }

            Text { 
                text: dash.btDeviceName
                color: Theme.colors.text_primary ?? "#eceff4"
                font.family: "Noto Sans"
                font.pixelSize: 12
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                visible: dash.btIslandBattery !== ""
                width: batRow.implicitWidth + 10
                height: 18
                radius: 9
                color: Qt.rgba(1, 1, 1, 0.12)
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 3
                    Text {
                        text: dash.btIslandBattery
                        font.family: "Rubik"
                        font.pixelSize: 11
                        font.bold: true
                        font.features: ({ "tnum": 1 })
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "󰁹"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Power Notification (MagSafe style)
        Row {
            id: powerPopupRow
            anchors.centerIn: parent
            spacing: 12
            visible: dash.displayedIslandType === "power" || (dash.powerIslandExpanded && !dash.btIslandExpanded && !root.isNotifPopupActive && !root.isWorkspacePeeking)
            
            Item {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 20; height: 20
                    radius: 10
                    color: "transparent"
                    border.width: 3
                    border.color: "#4caf50"
                    opacity: dash.powerIslandExpanded ? 1.0 : 0.0
                    scale: dash.powerIslandExpanded ? 1.0 : 0.5
                    
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }
                    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "󰚥"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                    color: "#4caf50"
                }
            }

            Text {
                text: dash.currentBatteryLevel + "% Charging"
                color: "#4caf50"
                font.pixelSize: 14; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Network Handoff Notification
        Row {
            id: netPopupRow
            anchors.centerIn: parent
            spacing: 8
            visible: dash.displayedIslandType === "net" || (dash.netIslandExpanded && !dash.powerIslandExpanded && !dash.btIslandExpanded && !root.isNotifPopupActive && !root.isWorkspacePeeking)
            
            Text {
                text: dash.activeNetType === "eth" ? "󰈀" : "󰤨"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: dash.activeNetType === "eth" ? "Switched to Wired" : "Switched to WiFi"
                color: Theme.colors.text_primary ?? "white"
                font.pixelSize: 14; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Iris Cava Waveform Component
    component IrisWaveform: Item {
        id: wave
        property bool running: dash.isMediaPlaying && (root.activeMode === "idle" || root.activeMode === "hover")
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

        // Grouped Iris DateMark + Separator + IrisClock cluster centered in the capsule
        Row {
            id: idleCluster
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -0.5
            spacing: 7

            // DateMark: weekday quiet, day number carrying accent,
            // sharing optical baseline directly with IrisClock figures
            Row {
                id: idleDateMark
                spacing: 4
                baselineOffset: idleWeekdayText.baselineOffset
                anchors.baseline: idleIrisClock.baseline

                Text {
                    id: idleWeekdayText
                    text: Qt.formatDate(clock.date, "ddd").replace(/\.$/, "")
                    color: Theme.colors.text_muted ?? "#8e8e93"
                    font.family: "Readex Pro"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                Text {
                    id: idleDayText
                    anchors.baseline: idleWeekdayText.baseline
                    text: Qt.formatDate(clock.date, "d")
                    color: Theme.accent
                    font.family: "Readex Pro"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                }
            }

            // Material You subtle separator bullet
            Text {
                text: "•"
                anchors.baseline: idleIrisClock.baseline
                anchors.baselineOffset: -0.5
                color: Qt.alpha(Theme.colors.text_muted ?? "#8e8e93", 0.5)
                font.family: "Readex Pro"
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }

            // IrisClock: clean Readex Pro numbers, accent colon, no leading zero in 12h
            IrisClock {
                id: idleIrisClock
                pixelSize: 16
                family: "Readex Pro"
                weight: Font.Bold
                text: {
                    var h = clock.date.getHours() % 12 || 12;
                    var m = clock.date.getMinutes();
                    var hh = String(h);
                    var mm = (m < 10 ? "0" : "") + m;
                    return hh + ":" + mm;
                }
                color: Theme.colors.text_primary ?? "#f5f5f7"
                separatorColor: Theme.accent
                isScreenRecording: root.isScreenRecording
            }

            // Ambient Pomodoro Countdown Indicator (Section 4.4)
            Row {
                id: idlePomoContainer
                visible: root.pomoRunning
                spacing: 7
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "•"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(Theme.colors.text_muted ?? "#8e8e93", 0.5)
                    font.family: "Readex Pro"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    height: 20
                    width: idlePomoRow.implicitWidth + 12
                    radius: 10
                    color: root.pomoPaused ? Qt.rgba(1, 1, 1, 0.08) : (root.pomoMode === "focus" ? Qt.alpha(Theme.accent, 0.16) : Qt.rgba(0.18, 0.82, 0.34, 0.16))
                    border.width: 0
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: idlePomoRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: root.pomoPaused ? "󰏤" : (root.pomoMode === "focus" ? "󱎫" : "󰄉")
                            color: root.pomoPaused ? (Theme.colors.text_muted ?? "#8e8e93") : (root.pomoMode === "focus" ? Theme.accent : "#30d158")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.formatPomoTime(root.pomoSecondsRemaining)
                            color: Theme.colors.text_primary ?? "#f5f5f7"
                            font.family: "Readex Pro"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                            renderType: Text.NativeRendering
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                root.togglePomodoroPause();
                            } else {
                                root.openUtility("pomo", false);
                            }
                        }
                    }
                }
            }
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
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 10

            // Left: Circular Album Cover (22px)
            IrisArtwork {
                source: dash.currentAlbumArt
                circular: true
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            // Center: DateMark + Separator + IrisClock cluster
            Row {
                id: musicIdleCluster
                spacing: 7
                Layout.alignment: Qt.AlignVCenter

                Row {
                    id: musicIdleDateMark
                    spacing: 4
                    baselineOffset: musicIdleWeekdayText.baselineOffset
                    anchors.baseline: musicIdleClock.baseline

                    Text {
                        id: musicIdleWeekdayText
                        text: Qt.formatDate(clock.date, "ddd").replace(/\.$/, "")
                        color: Theme.colors.text_muted ?? "#8e8e93"
                        font.family: "Readex Pro"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        id: musicIdleDayText
                        anchors.baseline: musicIdleWeekdayText.baseline
                        text: Qt.formatDate(clock.date, "d")
                        color: Theme.accent
                        font.family: "Readex Pro"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    text: "•"
                    anchors.baseline: musicIdleClock.baseline
                    anchors.baselineOffset: -0.5
                    color: Qt.alpha(Theme.colors.text_muted ?? "#8e8e93", 0.5)
                    font.family: "Readex Pro"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                IrisClock {
                    id: musicIdleClock
                    pixelSize: 16
                    family: "Readex Pro"
                    weight: Font.Bold
                    text: {
                        var h = clock.date.getHours() % 12 || 12;
                        var m = clock.date.getMinutes();
                        var hh = String(h);
                        var mm = (m < 10 ? "0" : "") + m;
                        return hh + ":" + mm;
                    }
                    color: Theme.colors.text_primary ?? "#f5f5f7"
                    separatorColor: Theme.accent
                    isScreenRecording: root.isScreenRecording
                }

                // Ambient Pomodoro Countdown Indicator (Look 2: Music Idle)
                Row {
                    id: musicIdlePomoContainer
                    visible: root.pomoRunning
                    spacing: 7
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "•"
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.alpha(Theme.colors.text_muted ?? "#8e8e93", 0.5)
                        font.family: "Readex Pro"
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        height: 20
                        width: musicIdlePomoRow.implicitWidth + 12
                        radius: 10
                        color: root.pomoPaused ? Qt.rgba(1, 1, 1, 0.08) : (root.pomoMode === "focus" ? Qt.alpha(Theme.accent, 0.16) : Qt.rgba(0.18, 0.82, 0.34, 0.16))
                        border.width: 0
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            id: musicIdlePomoRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: root.pomoPaused ? "󰏤" : (root.pomoMode === "focus" ? "󱎫" : "󰄉")
                                color: root.pomoPaused ? (Theme.colors.text_muted ?? "#8e8e93") : (root.pomoMode === "focus" ? Theme.accent : "#30d158")
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.formatPomoTime(root.pomoSecondsRemaining)
                                color: Theme.colors.text_primary ?? "#f5f5f7"
                                font.family: "Readex Pro"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    root.togglePomodoroPause();
                                } else {
                                    root.openUtility("pomo", false);
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Right: Live Animated Waveform
            IrisWaveform {
                running: dash.isMediaPlaying && (root.activeMode === "idle" || root.activeMode === "hover")
                Layout.alignment: Qt.AlignVCenter
            }
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
                font.family: "Readex Pro"
                font.pixelSize: 11
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })
                Layout.alignment: Qt.AlignVCenter
            }

            // Live Waveform
            IrisWaveform {
                running: dash.isMediaPlaying && (root.activeMode === "idle" || root.activeMode === "hover")
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ========================================================
    // 4. EXPANDED DASH ROW (Look 4: Hover state)
    // ========================================================
    Row {
        id: dashRow
        anchors.centerIn: parent
        spacing: 16
        opacity: (root.activeMode === "hover" && !dash.isIslandActive) ? 1.0 : 0.0
        scale: (root.activeMode === "hover" && !dash.isIslandActive) ? 1.0 : 0.95
        visible: opacity > 0.01
        layer.enabled: true
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }

        // Workspaces (left of clock)
        Row {
            id: leftGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: root.activeMode === "hover"
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // Arch Logo (Opens Launcher)
            Rectangle {
                width: 26; height: 26; radius: 8
                color: archMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: 0
                scale: archMouse.pressed ? 0.90 : (archMouse.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: "󰣇"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: archMouse.containsMouse ? Theme.accent : (Theme.colors.text_primary ?? "#c0caf5")
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: archMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("launcher", false)
                }
            }

            Repeater {
                model: dash.workspaceIds
                delegate: Rectangle {
                    width: 26; height: 26; radius: 8
                    property int wsId: modelData
                    property bool isFocused: typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && (wsId === Hyprland.focusedWorkspace.id)
                    color: isFocused ? Theme.accent : (wsMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent")
                    border.width: 0
                    border.color: "transparent"
                    scale: isFocused ? 1.06 : 1.0
                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: dash.motionCurve } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.isFocused ? (Theme.colors.bg ?? "#16161e") : (Theme.colors.text_primary ?? "white")
                        font.pixelSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof Hyprland !== "undefined") Hyprland.dispatch(`hl.dsp.focus({workspace = ${modelData}})`);
                        }
                    }
                }
            }
        }

        // Divider — workspaces | clock
        Rectangle {
            width: 1
            height: 18
            radius: 0.5
            color: Theme.colors.text_secondary ?? "#565f89"
            opacity: leftGroup.visible ? 0.25 : 0.0
            visible: leftGroup.visible
            anchors.verticalCenter: parent.verticalCenter
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        // Date & Time (Hover Mode)
        Item {
            id: centerItem
            width: hoverCenterRow.implicitWidth
            height: 26
            anchors.verticalCenter: parent.verticalCenter

            Row {
                id: hoverCenterRow
                anchors.centerIn: parent
                spacing: 7

                // Iris DateMark component
                Row {
                    id: hoverDateMark
                    spacing: 4
                    baselineOffset: hoverWeekdayText.baselineOffset
                    anchors.baseline: hoverClock.baseline

                    Text {
                        id: hoverWeekdayText
                        text: Qt.formatDate(clock.date, "ddd").replace(/\.$/, "")
                        color: Theme.colors.text_muted ?? "#8e8e93"
                        font.family: "Readex Pro"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        id: hoverDayText
                        anchors.baseline: hoverWeekdayText.baseline
                        text: Qt.formatDate(clock.date, "d")
                        color: Theme.accent
                        font.family: "Readex Pro"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    text: "•"
                    anchors.baseline: hoverClock.baseline
                    anchors.baselineOffset: -0.5
                    color: Qt.alpha(Theme.colors.text_muted ?? "#8e8e93", 0.5)
                    font.family: "Readex Pro"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                // Iris Clock with accent separator
                IrisClock {
                    id: hoverClock
                    anchors.verticalCenter: parent.verticalCenter
                    pixelSize: 16
                    family: "Readex Pro"
                    weight: Font.Bold
                    text: {
                        var h = clock.date.getHours() % 12 || 12;
                        var m = clock.date.getMinutes();
                        var hh = String(h);
                        var mm = (m < 10 ? "0" : "") + m;
                        return hh + ":" + mm;
                    }
                    color: Theme.colors.text_primary ?? "#f5f5f7"
                    separatorColor: Theme.accent
                    isScreenRecording: root.isScreenRecording
                }
            }

            MouseArea {
                id: timeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.isScreenRecording) {
                        root.switchMode("recorder");
                    } else {
                        root.switchMode("calendar");
                    }
                }
            }
        }

        // Divider — clock | tray
        Rectangle {
            width: 1
            height: 18
            radius: 0.5
            color: Theme.colors.text_secondary ?? "#565f89"
            opacity: leftGroup.visible ? 0.25 : 0.0
            visible: leftGroup.visible
            anchors.verticalCenter: parent.verticalCenter
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        // System Tray Container (Unified Control Center + Battery)
        Row {
            id: rightGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: root.activeMode === "hover"
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // Control Center Trigger
            Rectangle {
                width: 28; height: 26; radius: 8
                color: utilMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: 0
                border.color: "transparent"
                scale: utilMouse.pressed ? 0.90 : (utilMouse.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: "󰘮"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                    color: utilMouse.containsMouse ? Theme.accent : (Theme.colors.text_primary ?? "#c0caf5")
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    id: utilMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openUtility("", false)
                }
            }

            // Battery
            Rectangle {
                width: battRow.implicitWidth + 16; height: 26; radius: 8
                color: battMouse.containsMouse ? (Theme.colors.hover_bg ?? "#24283b") : "transparent"
                border.width: 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                BatteryPill {
                    id: battRow
                    anchors.centerIn: parent
                }
                MouseArea {
                    id: battMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchMode("battery", false)
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
