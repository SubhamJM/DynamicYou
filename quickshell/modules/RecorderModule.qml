pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: recModule
    spacing: 12
    Layout.fillWidth: true
    focus: true

    Keys.onEscapePressed: (event) => {
        root.collapseToIdle();
        event.accepted = true;
    }

    // Modern M3 / Goat Palette
    readonly property color colSurface: Theme.colors.bg ?? "#0e0e12"
    readonly property color colCard: Qt.rgba(255, 255, 255, 0.06)
    readonly property color colCardHover: Qt.rgba(255, 255, 255, 0.12)
    readonly property color colCardActive: Qt.rgba(255, 255, 255, 0.18)
    readonly property color colChipBg: Qt.rgba(255, 255, 255, 0.08)
    readonly property color colText: Theme.colors.text_primary ?? "#ffffff"
    readonly property color colSubtext: Theme.colors.text_secondary ?? "#8e8e93"
    readonly property color colAccent: Theme.accent ?? "#7aa2f7"
    readonly property color colRed: "#f43f5e"
    readonly property color colAmber: "#f59e0b"

    property string saveDirectory: (typeof root !== "undefined" && root.recSaveDirectory) ? root.recSaveDirectory : "~/Videos"
    property bool recordAudio: (typeof root !== "undefined" && root.recAudioEnabled !== undefined) ? root.recAudioEnabled : false
    property bool recordSound: (typeof root !== "undefined" && root.recSoundEnabled !== undefined) ? root.recSoundEnabled : true
    property bool isDndActive: false

    readonly property bool isRecording: (typeof root !== "undefined" && root.isScreenRecording) ? root.isScreenRecording : false
    readonly property bool isPaused: (typeof root !== "undefined" && root.isScreenRecordingPaused) ? root.isScreenRecordingPaused : false
    readonly property int elapsedSeconds: (typeof root !== "undefined" && root.screenRecordSeconds !== undefined) ? root.screenRecordSeconds : 0

    property string freeDiskSpace: "114 GB Free"
    property var lastRecording: null

    readonly property int calculatedHeight: {
        var base = isRecording ? 162 : 174;
        var cardH = lastRecording ? 68 : 38;
        return base + cardH + 28;
    }

    function formatTime(totalSec) {
        var s = Math.max(0, Math.floor(totalSec));
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        var sec = s % 60;
        var pad = function(val) { return (val < 10 ? "0" : "") + val; };
        return h > 0 ? (h + ":" + pad(m) + ":" + pad(sec)) : (pad(m) + ":" + pad(sec));
    }

    function humanSize(bytes) {
        if (!(bytes > 0)) return "";
        var units = ["B", "KB", "MB", "GB"];
        var val = bytes;
        var unit = 0;
        while (val >= 1024 && unit < units.length - 1) {
            val /= 1024;
            unit++;
        }
        return val.toFixed(unit >= 2 ? 1 : 0) + " " + units[unit];
    }

    function refreshLastRecording() {
        lastRecProcess.running = false;
        lastRecProcess.running = true;
    }

    function openLastVideo() {
        if (!recModule.lastRecording || !recModule.lastRecording.path) return;
        Qt.openUrlExternally("file://" + recModule.lastRecording.path);
        root.collapseToIdle();
    }

    function showLastVideoInFolder() {
        if (!recModule.lastRecording || !recModule.lastRecording.path) return;
        Quickshell.execDetached(["xdg-open", recModule.saveDirectory.replace(/^~/, Quickshell.env("HOME"))]);
        root.collapseToIdle();
    }

    function deleteLastVideo() {
        if (!recModule.lastRecording || !recModule.lastRecording.path) return;
        Quickshell.execDetached(["rm", "-f", recModule.lastRecording.path]);
        recModule.lastRecording = null;
        delTimer.restart();
    }

    Timer {
        id: delTimer
        interval: 300
        onTriggered: recModule.refreshLastRecording()
    }

    // Refresh last recording metadata on load
    Component.onCompleted: {
        recModule.refreshLastRecording();
        diskChecker.running = true;
    }

    onIsRecordingChanged: {
        if (!isRecording) {
            recModule.refreshLastRecording();
        }
    }

    // Query last recording metadata from record.sh
    Process {
        id: lastRecProcess
        command: [Quickshell.env("HOME") + "/dynamic-you/quickshell/scripts/record.sh", "--last"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text.trim());
                    recModule.lastRecording = (parsed && parsed.path) ? parsed : null;
                } catch(e) {
                    recModule.lastRecording = null;
                }
            }
        }
    }

    // Disk space checker
    Process {
        id: diskChecker
        command: ["sh", "-c", "df -h ~/Videos 2>/dev/null | awk 'NR==2{print $4}' || df -h ~ | awk 'NR==2{print $4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = this.text.trim();
                if (val) recModule.freeDiskSpace = val + "B Free";
            }
        }
    }

    // ========================================================
    // 1. MINIMAL HEADER BAR (With live status timer)
    // ========================================================
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 8

        // Back to Utility Button
        Rectangle {
            width: 28
            height: 28
            radius: 8
            color: backMouse.containsMouse ? recModule.colCardHover : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: 17
                color: recModule.colText
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.switchMode("utility", true)
            }
        }

        Text {
            text: "Screen Recorder"
            font.family: "Noto Sans"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: recModule.colText
            renderType: Text.NativeRendering
        }

        // Live Recording Status Badge
        Rectangle {
            visible: recModule.isRecording
            Layout.preferredHeight: 22
            Layout.preferredWidth: recElapsedRow.implicitWidth + 14
            radius: 11
            color: recModule.isPaused ? Qt.alpha(recModule.colAmber, 0.18) : Qt.alpha(recModule.colRed, 0.18)

            RowLayout {
                id: recElapsedRow
                anchors.centerIn: parent
                spacing: 5

                Rectangle {
                    width: 7
                    height: 7
                    radius: 3.5
                    color: recModule.isPaused ? recModule.colAmber : recModule.colRed
                    SequentialAnimation on opacity {
                        running: recModule.isRecording && !recModule.isPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                Text {
                    text: recModule.isPaused ? "Paused" : "Recording"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: recModule.isPaused ? recModule.colAmber : recModule.colRed
                    renderType: Text.NativeRendering
                }

                Text {
                    text: recModule.formatTime(recModule.elapsedSeconds)
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                    color: recModule.isPaused ? recModule.colAmber : recModule.colRed
                    renderType: Text.NativeRendering
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Free disk space pill
        Rectangle {
            Layout.preferredHeight: 22
            Layout.preferredWidth: diskText.implicitWidth + 12
            radius: 11
            color: recModule.colChipBg

            Text {
                id: diskText
                anchors.centerIn: parent
                text: recModule.freeDiskSpace
                font.family: "Noto Sans"
                font.pixelSize: 10
                font.weight: Font.Medium
                color: recModule.colSubtext
                renderType: Text.NativeRendering
            }
        }
    }

    // ========================================================
    // 2. PRIMARY ACTION CONTROLS (The Goat Big Action Buttons)
    // ========================================================

    // ── Mode A: IDLE (4 Major Capture Options) ───────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: !recModule.isRecording

        // 1. Screenshot Region
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: 14
            color: snipRegMouse.pressed ? recModule.colCardActive : (snipRegMouse.containsMouse ? recModule.colCardHover : recModule.colCard)
            scale: snipRegMouse.pressed ? 0.96 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 100 } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "screenshot_region"
                    iconSize: 22
                    color: recModule.colText
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Region Snip"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: recModule.colText
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: snipRegMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.collapseToIdle();
                    var script = Quickshell.env("HOME") + "/dynamic-you/quickshell/scripts/record.sh";
                    Quickshell.execDetached([script, "--screenshot-region"]);
                }
            }
        }

        // 2. Full Screenshot
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: 14
            color: snipFullMouse.pressed ? recModule.colCardActive : (snipFullMouse.containsMouse ? recModule.colCardHover : recModule.colCard)
            scale: snipFullMouse.pressed ? 0.96 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 100 } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "photo_camera"
                    iconSize: 22
                    color: recModule.colText
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Screen Snip"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: recModule.colText
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: snipFullMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.collapseToIdle();
                    var script = Quickshell.env("HOME") + "/dynamic-you/quickshell/scripts/record.sh";
                    Quickshell.execDetached([script, "--screenshot-full"]);
                }
            }
        }

        // 3. Record Region
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: 14
            color: recRegMouse.pressed ? recModule.colCardActive : (recRegMouse.containsMouse ? recModule.colCardHover : recModule.colCard)
            scale: recRegMouse.pressed ? 0.96 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 100 } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "screen_record"
                    iconSize: 22
                    color: recModule.colAccent
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Record Area"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: recModule.colText
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: recRegMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.startRecording(true);
                }
            }
        }

        // 4. Record Full Screen
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: 14
            color: recFullMouse.pressed ? Qt.alpha(recModule.colAccent, 0.28) : (recFullMouse.containsMouse ? Qt.alpha(recModule.colAccent, 0.20) : Qt.alpha(recModule.colAccent, 0.14))
            scale: recFullMouse.pressed ? 0.96 : 1.0
            border.width: 1
            border.color: Qt.alpha(recModule.colAccent, 0.35)
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 100 } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "videocam"
                    iconSize: 22
                    color: recModule.colAccent
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Record Screen"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: recModule.colAccent
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: recFullMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.startRecording(false);
                }
            }
        }
    }

    // ── Mode B: RECORDING (Pause / Resume & Stop Actions) ────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: recModule.isRecording

        // Pause / Resume Button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 14
            color: pauseMouse.pressed ? Qt.rgba(245, 158, 11, 0.35) : (pauseMouse.containsMouse ? Qt.rgba(245, 158, 11, 0.25) : Qt.rgba(245, 158, 11, 0.16))
            scale: pauseMouse.pressed ? 0.97 : 1.0
            border.width: 1
            border.color: Qt.rgba(245, 158, 11, 0.40)
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    text: recModule.isPaused ? "play_arrow" : "pause"
                    iconSize: 22
                    color: recModule.colAmber
                }

                Text {
                    text: recModule.isPaused ? "Resume Recording" : "Pause Recording"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: recModule.colAmber
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: pauseMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    var script = Quickshell.env("HOME") + "/dynamic-you/quickshell/scripts/record.sh";
                    Quickshell.execDetached([script, "--pause"]);
                }
            }
        }

        // Stop Recording Button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 14
            color: stopMouse.pressed ? Qt.darker(recModule.colRed, 1.2) : (stopMouse.containsMouse ? Qt.lighter(recModule.colRed, 1.1) : recModule.colRed)
            scale: stopMouse.pressed ? 0.97 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    text: "stop"
                    iconSize: 22
                    color: "#ffffff"
                }

                Text {
                    text: "Stop & Save"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: "#ffffff"
                    renderType: Text.NativeRendering
                }

                // Time Badge
                Rectangle {
                    width: timeBadgeText.implicitWidth + 10
                    height: 20
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.35)

                    Text {
                        id: timeBadgeText
                        anchors.centerIn: parent
                        text: recModule.formatTime(recModule.elapsedSeconds)
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                        color: "#ffffff"
                        renderType: Text.NativeRendering
                    }
                }
            }

            MouseArea {
                id: stopMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.stopRecording();
                    recModule.refreshLastRecording();
                }
            }
        }
    }

    // ========================================================
    // 3. QUICK SETTINGS CHIPS (The Goat Feature Deck)
    // ========================================================
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        // 1. Microphone Toggle
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 10
            color: recModule.recordAudio ? Qt.alpha(recModule.colAccent, 0.20) : (micMouse.containsMouse ? recModule.colCardHover : recModule.colCard)
            border.width: recModule.recordAudio ? 1 : 0
            border.color: Qt.alpha(recModule.colAccent, 0.35)
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    text: recModule.recordAudio ? "mic" : "mic_off"
                    iconSize: 16
                    color: recModule.recordAudio ? recModule.colAccent : recModule.colSubtext
                }
                Text {
                    text: "Mic"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: recModule.recordAudio ? recModule.colAccent : recModule.colText
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: micMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    recModule.recordAudio = !recModule.recordAudio;
                    if (typeof root !== "undefined") root.recAudioEnabled = recModule.recordAudio;
                }
            }
        }

        // 2. Desktop Audio Toggle
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 10
            color: recModule.recordSound ? Qt.alpha(recModule.colAccent, 0.20) : (sndMouse.containsMouse ? recModule.colCardHover : recModule.colCard)
            border.width: recModule.recordSound ? 1 : 0
            border.color: Qt.alpha(recModule.colAccent, 0.35)
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    text: recModule.recordSound ? "volume_up" : "volume_off"
                    iconSize: 16
                    color: recModule.recordSound ? recModule.colAccent : recModule.colSubtext
                }
                Text {
                    text: "Sound"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: recModule.recordSound ? recModule.colAccent : recModule.colText
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: sndMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    recModule.recordSound = !recModule.recordSound;
                    if (typeof root !== "undefined") root.recSoundEnabled = recModule.recordSound;
                }
            }
        }

        // 3. Silent Mode (DND)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 10
            color: recModule.isDndActive ? Qt.alpha(recModule.colAccent, 0.20) : (dndMouse.containsMouse ? recModule.colCardHover : recModule.colCard)
            border.width: recModule.isDndActive ? 1 : 0
            border.color: Qt.alpha(recModule.colAccent, 0.35)
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    text: recModule.isDndActive ? "notifications_off" : "notifications"
                    iconSize: 16
                    color: recModule.isDndActive ? recModule.colAccent : recModule.colSubtext
                }
                Text {
                    text: "Silent"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: recModule.isDndActive ? recModule.colAccent : recModule.colText
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: dndMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    recModule.isDndActive = !recModule.isDndActive;
                    if (typeof root !== "undefined" && root.toggleDnd) root.toggleDnd();
                }
            }
        }

        // 4. Open Videos Folder
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 10
            color: folMouse.containsMouse ? recModule.colCardHover : recModule.colCard
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    text: "folder_open"
                    iconSize: 16
                    color: recModule.colSubtext
                }
                Text {
                    text: "Videos"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: recModule.colText
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: folMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    Quickshell.execDetached(["xdg-open", recModule.saveDirectory.replace(/^~/, Quickshell.env("HOME"))]);
                    root.collapseToIdle();
                }
            }
        }
    }

    // ========================================================
    // 4. RECENT RECORDING PREVIEW CARD (The Goat 1:1 Feature)
    // ========================================================
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: recModule.lastRecording ? 68 : 38
        radius: 14
        color: recModule.colCard
        clip: true
        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // A. If a recent video exists:
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10
            visible: recModule.lastRecording !== null

            // Video Thumbnail / Cover
            Rectangle {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 52
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.4)
                clip: true

                Image {
                    id: lastThumbImg
                    anchors.fill: parent
                    source: (recModule.lastRecording && recModule.lastRecording.thumb) ? ("file://" + recModule.lastRecording.thumb) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: lastThumbImg.status !== Image.Ready
                    text: "movie"
                    iconSize: 22
                    color: recModule.colSubtext
                }

                // Duration Pill badge in corner
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 3
                    width: durText.implicitWidth + 6
                    height: 14
                    radius: 4
                    color: Qt.rgba(0, 0, 0, 0.70)
                    visible: (recModule.lastRecording && recModule.lastRecording.duration > 0)

                    Text {
                        id: durText
                        anchors.centerIn: parent
                        text: recModule.formatTime(recModule.lastRecording ? recModule.lastRecording.duration : 0)
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: recModule.openLastVideo()
                }
            }

            // File Info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "LAST RECORDING"
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: recModule.colSubtext
                        renderType: Text.NativeRendering
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: recModule.lastRecording ? Qt.formatDateTime(new Date(recModule.lastRecording.mtime * 1000), "dd MMM · hh:mm") : ""
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        color: recModule.colSubtext
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: recModule.lastRecording ? recModule.lastRecording.name : ""
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: recModule.colText
                    elide: Text.ElideMiddle
                    renderType: Text.NativeRendering
                }

                Text {
                    text: recModule.lastRecording ? recModule.humanSize(recModule.lastRecording.size) : ""
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    color: recModule.colSubtext
                    renderType: Text.NativeRendering
                }
            }

            // Quick Actions: Play, Reveal, Delete
            RowLayout {
                spacing: 4

                // Play
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: playMouse.containsMouse ? recModule.colCardHover : recModule.colChipBg
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "play_arrow"
                        iconSize: 16
                        color: recModule.colAccent
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: recModule.openLastVideo()
                    }
                }

                // Show in Folder
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: revMouse.containsMouse ? recModule.colCardHover : recModule.colChipBg
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "folder"
                        iconSize: 15
                        color: recModule.colText
                    }

                    MouseArea {
                        id: revMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: recModule.showLastVideoInFolder()
                    }
                }

                // Delete
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: delMouse.containsMouse ? Qt.alpha(recModule.colRed, 0.25) : recModule.colChipBg
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "delete"
                        iconSize: 15
                        color: delMouse.containsMouse ? recModule.colRed : recModule.colSubtext
                    }

                    MouseArea {
                        id: delMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: recModule.deleteLastVideo()
                    }
                }
            }
        }

        // B. If NO recent recording exists:
        RowLayout {
            anchors.centerIn: parent
            spacing: 6
            visible: recModule.lastRecording === null

            MaterialSymbol {
                text: "video_library"
                iconSize: 16
                color: recModule.colSubtext
            }

            Text {
                text: "No recordings yet · Videos will show here"
                font.family: "Noto Sans"
                font.pixelSize: 11
                color: recModule.colSubtext
                renderType: Text.NativeRendering
            }
        }
    }
}
