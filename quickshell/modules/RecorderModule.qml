import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

ColumnLayout {
    id: recorder
    spacing: 10
    focus: true

    readonly property string scriptPath: Quickshell.shellPath("scripts/record.sh")
    readonly property string videoFolder: root.recSaveDirectory.replace(/^~/, Quickshell.env("HOME"))
    readonly property bool isRecording: root.isScreenRecording
    readonly property bool isPaused: root.isScreenRecordingPaused
    readonly property color panelColor: Theme.alpha(Theme.text, 0.055)
    readonly property color outlineColor: Theme.alpha(Theme.text, 0.10)
    readonly property color secondaryText: Theme.alpha(Theme.text, 0.72)
    readonly property color liveColor: isPaused ? secondaryText : Theme.error
    readonly property int calculatedHeight: Math.max(350, Math.ceil(implicitHeight) + 24)

    property string freeSpace: ""
    property var lastRecording: null
    property string recentError: ""

    Keys.onEscapePressed: event => {
        root.collapseToIdle();
        event.accepted = true;
    }

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const hours = Math.floor(total / 3600);
        const minutes = String(Math.floor((total % 3600) / 60)).padStart(2, "0");
        const remainder = String(total % 60).padStart(2, "0");
        return (hours ? hours + ":" : "") + minutes + ":" + remainder;
    }

    function humanSize(bytes) {
        if (!(bytes > 0)) return "";
        const units = ["B", "KB", "MB", "GB"];
        let unit = 0;
        while (bytes >= 1024 && unit < units.length - 1) {
            bytes /= 1024;
            unit++;
        }
        return bytes.toFixed(unit >= 2 ? 1 : 0) + " " + units[unit];
    }

    function screenshot(region) {
        root.collapseToIdle();
        Quickshell.execDetached([scriptPath, region ? "--screenshot-region" : "--screenshot-full"]);
    }

    function openPath(path) {
        if (!path) return;
        Quickshell.execDetached(["xdg-open", path]);
        root.collapseToIdle();
    }

    function deleteLastVideo() {
        const path = lastRecording?.path;
        if (!path || deleteProcess.running || refreshAfterSave.running) return;
        recentError = "";
        deleteProcess.command = ["rm", "-f", "--", path];
        deleteProcess.running = true;
    }

    function refreshLastRecording() {
        if (!lastRecProcess.running && !deleteProcess.running)
            lastRecProcess.running = true;
    }

    Component.onCompleted: {
        refreshLastRecording();
        diskChecker.running = true;
    }

    onIsRecordingChanged: {
        if (isRecording) refreshAfterSave.stop();
        else refreshAfterSave.restart();
    }

    Connections {
        target: root
        function onActiveModeChanged() {
            if (root.activeMode !== "recorder") return;
            if (!refreshAfterSave.running) recorder.refreshLastRecording();
            diskChecker.running = true;
        }
    }

    Timer {
        id: refreshAfterSave
        interval: 1550
        onTriggered: {
            recorder.refreshLastRecording();
            diskChecker.running = true;
        }
    }

    Process {
        id: lastRecProcess
        command: [recorder.scriptPath, "--last"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const entry = JSON.parse(text.trim());
                    recorder.lastRecording = entry?.path ? entry : null;
                } catch (error) {
                    recorder.lastRecording = null;
                }
            }
        }
    }

    Process {
        id: deleteProcess
        onExited: code => {
            if (code === 0) {
                recorder.lastRecording = null;
                Qt.callLater(recorder.refreshLastRecording);
                diskChecker.running = true;
            } else {
                recorder.recentError = "Couldn’t delete the recording";
            }
        }
    }

    Process {
        id: diskChecker
        command: ["sh", "-c", 'directory=$1; [ -d "$directory" ] || directory=$HOME; LC_ALL=C df -h --output=avail -- "$directory" | tail -n 1',
            "sh", recorder.videoFolder]
        stdout: StdioCollector {
            onStreamFinished: {
                const available = text.trim();
                recorder.freeSpace = available ? available + " free" : "";
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        CaptureButton {
            glyph: "arrow_back"
            iconOnly: true
            text: "Back to Control Center"
            onClicked: root.switchMode("utility", true)
        }

        Text {
            Layout.fillWidth: true
            text: "Screen recorder"
            font.family: Theme.fontFamilyBody
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Theme.text
            elide: Text.ElideRight
        }

        Text {
            visible: recorder.freeSpace !== ""
            text: recorder.freeSpace
            color: recorder.secondaryText
            font.family: Theme.fontFamilyBody
            font.pixelSize: 11
        }

        CaptureButton {
            glyph: "folder_open"
            iconOnly: true
            text: "Open Videos folder"
            onClicked: recorder.openPath(recorder.videoFolder)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        visible: recorder.isRecording
        radius: 15
        color: Theme.alpha(recorder.liveColor, 0.10)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 9

            MaterialSymbol {
                text: recorder.isPaused ? "pause_circle" : "radio_button_checked"
                iconSize: 19
                color: recorder.liveColor
            }

            Text {
                Layout.fillWidth: true
                text: recorder.isPaused ? "Paused" : "Recording"
                color: Theme.text
                font.family: Theme.fontFamilyBody
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                text: recorder.formatTime(root.screenRecordSeconds)
                color: Theme.text
                font.family: Theme.fontFamilyBody
                font.pixelSize: 22
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        CaptureButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: 42
            text: recorder.isRecording ? (recorder.isPaused ? "Resume" : "Pause") : "Record area"
            glyph: recorder.isRecording ? (recorder.isPaused ? "play_arrow" : "pause") : "select_all"
            enabled: !refreshAfterSave.running
            onClicked: {
                if (recorder.isRecording) root.togglePauseRecording();
                else root.startRecording(true);
            }
        }

        CaptureButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: 42
            text: recorder.isRecording ? "Stop & save" : refreshAfterSave.running ? "Saving…" : "Record screen"
            glyph: recorder.isRecording ? "stop" : "videocam"
            filled: true
            tone: recorder.isRecording ? Theme.error : Theme.accent
            onTone: recorder.isRecording ? Theme.bg : Theme.fgPrimary
            enabled: !refreshAfterSave.running
            onClicked: {
                if (recorder.isRecording) root.stopRecording();
                else root.startRecording(false);
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: optionRows.implicitHeight + 16
        radius: 16
        color: recorder.panelColor

        ColumnLayout {
            id: optionRows
            anchors.fill: parent
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 0

            OptionRow {
                label: "Device audio"
                glyph: root.recSoundEnabled ? "volume_up" : "volume_off"
                powered: root.recSoundEnabled
                onToggled: root.recSoundEnabled = !root.recSoundEnabled
            }

            Separator {}

            OptionRow {
                label: "Microphone"
                glyph: root.recAudioEnabled ? "mic" : "mic_off"
                powered: root.recAudioEnabled
                onToggled: root.recAudioEnabled = !root.recAudioEnabled
            }

            Separator {}

            OptionRow {
                label: "Do not disturb"
                glyph: root.dndEnabled ? "notifications_off" : "notifications"
                powered: root.dndEnabled
                onToggled: root.toggleDnd()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !recorder.isRecording
        spacing: 8

        CaptureButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: "Area screenshot"
            glyph: "screenshot_region"
            onClicked: recorder.screenshot(true)
        }

        CaptureButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: "Full screenshot"
            glyph: "photo_camera"
            onClicked: recorder.screenshot(false)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: recorder.lastRecording ? 66 : 36
        radius: 14
        color: recorder.panelColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 8
            visible: recorder.lastRecording !== null

            Item {
                Layout.preferredWidth: 76
                Layout.preferredHeight: 48

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Theme.alpha(Theme.text, 0.08)
                    clip: true

                    Image {
                        id: thumbnail
                        anchors.fill: parent
                        source: recorder.lastRecording?.thumb ? "file://" + recorder.lastRecording.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: thumbnail.status !== Image.Ready
                        text: "movie"
                        iconSize: 20
                        color: recorder.secondaryText
                    }
                }

                TapHandler {
                    onTapped: recorder.openPath(recorder.lastRecording?.path)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: "Last recording"
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 10
                    color: recorder.secondaryText
                }

                Text {
                    Layout.fillWidth: true
                    text: recorder.lastRecording?.name ?? ""
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.text
                    elide: Text.ElideMiddle
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        const file = recorder.lastRecording;
                        if (!file) return "";
                        return [
                            file.duration > 0 ? recorder.formatTime(file.duration) : "",
                            recorder.humanSize(file.size),
                            file.mtime > 0 ? Qt.formatDateTime(new Date(file.mtime * 1000), "dd MMM · hh:mm") : ""
                        ].filter(part => part !== "").join(" · ");
                    }
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 10
                    color: recorder.secondaryText
                    elide: Text.ElideRight
                }
            }

            CaptureButton {
                glyph: "play_arrow"
                text: "Play last recording"
                iconOnly: true
                onClicked: recorder.openPath(recorder.lastRecording?.path)
            }

            CaptureButton {
                glyph: "folder_open"
                text: "Show recording in folder"
                iconOnly: true
                onClicked: {
                    const path = recorder.lastRecording?.path;
                    if (path) recorder.openPath(path.slice(0, path.lastIndexOf("/")));
                }
            }

            CaptureButton {
                glyph: "delete"
                text: "Delete last recording"
                tone: Theme.error
                iconOnly: true
                enabled: !deleteProcess.running && !refreshAfterSave.running
                onClicked: recorder.deleteLastVideo()
            }
        }

        Text {
            anchors.centerIn: parent
            visible: recorder.lastRecording === null
            text: refreshAfterSave.running ? "Saving recording…" : "No recordings yet"
            font.family: Theme.fontFamilyBody
            font.pixelSize: 11
            color: recorder.secondaryText
        }
    }

    Text {
        Layout.fillWidth: true
        visible: recorder.recentError !== ""
        text: recorder.recentError
        font.family: Theme.fontFamilyBody
        font.pixelSize: 11
        color: Theme.error
    }

    component Separator: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 0
        Layout.rightMargin: 0
        Layout.preferredHeight: 1
        color: recorder.outlineColor
    }

    component OptionRow: RowLayout {
        id: option
        required property string label
        required property string glyph
        required property bool powered
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 8

        MaterialSymbol {
            text: option.glyph
            iconSize: 17
            color: option.powered ? Theme.accent : recorder.secondaryText
        }

        Text {
            Layout.fillWidth: true
            text: option.label
            color: Theme.text
            font.family: Theme.fontFamilyBody
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        ConnectivityToggle {
            powered: option.powered
            Accessible.name: option.label
            onClicked: option.toggled()
        }
    }

    component CaptureButton: Controls.Button {
        id: button
        required property string glyph
        property bool filled: false
        property bool iconOnly: false
        property color tone: Theme.accent
        property color onTone: Theme.fgPrimary

        implicitWidth: iconOnly ? 30 : Math.max(36, caption.implicitWidth + 45)
        implicitHeight: iconOnly ? 30 : 35
        padding: 0
        hoverEnabled: true
        Accessible.name: text
        Controls.ToolTip.visible: iconOnly && hovered
        Controls.ToolTip.text: text
        Controls.ToolTip.delay: 450

        contentItem: Item {
            Row {
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: button.glyph
                    iconSize: button.iconOnly ? 16 : 18
                    color: button.filled && button.enabled ? button.onTone : button.tone
                }

                Text {
                    id: caption
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !button.iconOnly
                    text: button.text
                    color: button.filled && button.enabled ? button.onTone : Theme.text
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        background: Rectangle {
            radius: button.iconOnly ? 10 : 12
            color: button.filled && button.enabled ? button.tone
                : Theme.alpha(Theme.text, button.down ? 0.15 : button.hovered ? 0.11 : button.iconOnly ? 0.02 : 0.06)
            opacity: button.enabled ? 1 : 0.5
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }
}
