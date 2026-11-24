import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

FocusScope {
    id: sorter
    focus: true

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string library: home + "/Pictures/Wallpapers"
    readonly property bool sorting: worker.running
    property bool browsingFolder: chooserProc.running
    readonly property var themes: [
        { name: "Abyss", shade: "#122641", color: "#25b4e5" },
        { name: "Afterglow", shade: "#482550", color: "#e591ba" },
        { name: "Crimson", shade: "#501b33", color: "#f76581" },
        { name: "Frost", shade: "#3b4c64", color: "#c9e8f6" },
        { name: "Solstice", shade: "#5b301d", color: "#f9bb64" },
        { name: "Verdant", shade: "#183c34", color: "#75d99c" }
    ]

    property int current: 0
    property int total: 0
    property string currentFile: ""
    property string failure: ""
    property var result: null

    Keys.onEscapePressed: (event) => {
        if (!sorting && !browsingFolder) root.switchMode("utility", true);
        event.accepted = true;
    }

    function startSorting() {
        const source = folderPath.text.trim();
        if (sorting || source === "") return;
        current = 0;
        total = 0;
        currentFile = "";
        failure = "";
        result = null;
        worker.command = ["python3", Quickshell.shellPath("scripts/wallpaper_sorter.py"),
            "--dest", library, "--json", "--", source];
        worker.running = true;
    }

    // Native Wayland asynchronous directory picker (zenity with kdialog fallback)
    // Avoids QtQuick.Dialogs modal lockup on layer-shell overlay surfaces
    Process {
        id: chooserProc
        running: false
        command: [
            "bash", "-c",
            "start_dir=\"$1\"; [ -d \"$start_dir\" ] || start_dir=\"$HOME\"; " +
            "if command -v zenity >/dev/null 2>&1; then " +
            "  zenity --file-selection --directory --filename=\"$start_dir/\" --title=\"Choose Wallpaper Source Folder\" 2>/dev/null; " +
            "elif command -v kdialog >/dev/null 2>&1; then " +
            "  kdialog --title \"Choose Wallpaper Source Folder\" --getexistingdirectory \"$start_dir\" 2>/dev/null; " +
            "fi",
            "sh",
            folderPath.text.trim() || sorter.home
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const picked = this.text.trim();
                if (picked.length > 0) {
                    folderPath.text = picked;
                }
            }
        }

        onExited: (code) => {
            sorter.browsingFolder = false;
        }
    }

    Process {
        id: worker

        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    if (event.type === "start") {
                        sorter.total = event.total_files;
                    } else if (event.type === "progress") {
                        sorter.current = event.current;
                        sorter.currentFile = event.filename;
                    } else if (event.type === "error") {
                        sorter.failure = event.message;
                    } else if (event.type === "done") {
                        sorter.result = event;
                        if (event.unique_added > 0) root.refreshWallpaperCache();
                    }
                } catch (_) {}
            }
        }
        onExited: code => {
            if ((code !== 0 || !sorter.result) && !sorter.failure)
                sorter.failure = "Sorting couldn’t finish. Check that Pillow is installed and the wallpaper library is writable.";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            SortButton {
                text: "Back to Control Center"
                glyph: "arrow_back"
                iconOnly: true
                enabled: !sorter.sorting
                onClicked: root.switchMode("utility", true)
            }

            Text {
                Layout.fillWidth: true
                text: "Wallpaper Color Sorter"
                color: Theme.text
                font.family: Theme.fontFamilyBody
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: sourceLayout.implicitHeight + 20
            radius: 12
            color: Theme.surfaceHigh

            ColumnLayout {
                id: sourceLayout
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Text {
                    text: "Source folder"
                    color: Theme.subtext
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    TextField {
                        id: folderPath
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        text: sorter.home + "/Downloads"
                        placeholderText: "Enter a folder path"
                        selectByMouse: true
                        readOnly: sorter.sorting || sorter.browsingFolder
                        color: Theme.text
                        placeholderTextColor: Theme.subtext
                        font.family: Theme.fontFamilyBody
                        font.pixelSize: 12
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.fgPrimary
                        background: Rectangle {
                            radius: 8
                            color: folderPath.activeFocus ? Theme.surfaceHighest : Theme.bg
                        }
                        onTextChanged: {
                            if (!sorter.sorting) {
                                sorter.failure = "";
                                sorter.result = null;
                            }
                        }
                    }

                    SortButton {
                        text: sorter.browsingFolder ? "Choosing…" : "Browse"
                        baseColor: Theme.surfaceHighest
                        glyph: "folder_open"
                        enabled: !sorter.sorting && !sorter.browsingFolder
                        onClicked: {
                            sorter.browsingFolder = true;
                            chooserProc.running = true;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { title: "Downloads", path: sorter.home + "/Downloads" },
                            { title: "Pictures", path: sorter.home + "/Pictures" },
                            { title: "Wallpapers", path: sorter.library },
                            { title: "Custom", path: sorter.home + "/customwallpapers" }
                        ]
                        delegate: SortButton {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            baseColor: Theme.bg
                            text: modelData.title
                            selected: folderPath.text.trim() === modelData.path
                            enabled: !sorter.sorting && !sorter.browsingFolder
                            onClicked: folderPath.text = modelData.path
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Copies images by color into the theme folders in ~/Pictures/Wallpapers."
            color: Theme.subtext
            font.family: Theme.fontFamilyBody
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: sorter.themes

                delegate: Rectangle {
                    id: themeTile
                    required property var modelData
                    readonly property int copied: sorter.result?.by_theme[modelData.name] ?? 0
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 65
                    radius: 9
                    color: Theme.surfaceHigh
                    Accessible.name: modelData.name + (sorter.result ? ", " + copied + " copied" : "")

                    Rectangle {
                        id: swatch
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 4
                        height: 35
                        radius: 6
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: themeTile.modelData.shade }
                            GradientStop { position: 1; color: themeTile.modelData.color }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                        text: themeTile.modelData.name + (sorter.result ? " · " + themeTile.copied : "")
                        color: Theme.text
                        font.family: Theme.fontFamilyBody
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            visible: sorter.sorting || sorter.result !== null || sorter.failure !== ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: {
                if (sorter.failure) return sorter.failure;
                if (sorter.sorting) return sorter.total > 0
                    ? sorter.current + " / " + sorter.total + " · " + sorter.currentFile : "Scanning folder…";
                if (!sorter.result) return "";
                if (sorter.result.total_found === 0) return "No supported images found in this folder.";
                let summary = sorter.result.unique_added + " copied · " + sorter.result.duplicates_skipped + " duplicate names skipped";
                if (sorter.result.failed > 0) summary += " · " + sorter.result.failed + " failed";
                return summary;
            }
            color: sorter.failure ? Theme.error : Theme.subtext
            font.family: Theme.fontFamilyBody
            font.pixelSize: 11
        }

        ProgressBar {
            Layout.fillWidth: true
            visible: sorter.sorting
            from: 0
            to: Math.max(1, sorter.total)
            value: sorter.current
            indeterminate: sorter.total === 0
            palette.highlight: Theme.accent
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            SortButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: "Open Wallpaper Picker"
                glyph: "wallpaper"
                enabled: !sorter.sorting
                onClicked: root.switchMode("wallpaper", true)
            }
            SortButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: sorter.sorting ? "Sorting…" : "Sort Wallpapers"
                glyph: "auto_awesome_mosaic"
                primary: true
                enabled: !sorter.sorting && folderPath.text.trim() !== ""
                onClicked: sorter.startSorting()
            }
        }
    }

    component SortButton: Button {
        id: button
        property string glyph: ""
        property bool primary: false
        property bool selected: false
        property bool iconOnly: false
        property color baseColor: Theme.surfaceHigh

        implicitHeight: 32
        implicitWidth: iconOnly ? 32 : caption.implicitWidth + (glyph ? 36 : 20)
        padding: 0
        hoverEnabled: true
        Accessible.name: text
        ToolTip.visible: iconOnly && hovered
        ToolTip.text: text

        background: Rectangle {
            radius: 8
            color: button.primary ? Theme.accent
                : button.hovered || button.selected ? Theme.surfaceHighest : button.baseColor
            opacity: button.enabled ? 1 : 0.4
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        contentItem: Item {
            opacity: button.enabled ? 1 : 0.6

            Row {
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: button.glyph !== ""
                    text: button.glyph
                    iconSize: 15
                    color: button.primary ? Theme.fgPrimary : Theme.subtext
                }
                Text {
                    id: caption
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !button.iconOnly
                    text: button.text
                    color: button.primary ? Theme.fgPrimary : Theme.text
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
