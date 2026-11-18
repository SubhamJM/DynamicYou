import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: sorterModule
    focus: true
    Keys.onEscapePressed: (event) => {
        if (sorterModule.isSorting) {
            // Busy sorting
        } else {
            root.switchMode("utility", true);
        }
        event.accepted = true;
    }

    // Palette & Styling
    readonly property color colBg: Theme.colors.bg ?? "#000000"
    readonly property color colCard: Qt.rgba(255, 255, 255, 0.055)
    readonly property color colCardHover: Qt.rgba(255, 255, 255, 0.10)
    readonly property color colCardActive: Qt.rgba(255, 255, 255, 0.16)
    readonly property color colAccent: Theme.accent ?? "#7aa2f7"
    readonly property color colText: Theme.colors.text_primary ?? "#f8fafc"
    readonly property color colSubtext: Theme.colors.text_secondary ?? "#94a3b8"
    readonly property color colMuted: Qt.rgba(255, 255, 255, 0.38)
    readonly property color colBorder: Qt.rgba(255, 255, 255, 0.08)

    // State Variables - Default directory: ~/customwallpapers
    property string sourceDirectory: (Quickshell.env("HOME") || "") + "/customwallpapers"
    property string targetDirectory: (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"
    property string copyMode: "copy"

    property bool isSorting: false
    property bool hasCompleted: false
    property int currentProgress: 0
    property int totalFiles: 0
    property string currentFile: ""
    property string currentTheme: ""
    property string currentHex: ""
    property int totalFound: 0
    property int uniqueAdded: 0
    property int duplicatesSkipped: 0
    property var themeBreakdown: ({ "Abyss": 0, "Verdant": 0, "Crimson": 0, "Afterglow": 0, "Solstice": 0, "Frost": 0 })

    // Zenity Native Folder Chooser Process
    Process {
        id: folderChooser
        running: false
        command: [
            "zenity",
            "--file-selection",
            "--directory",
            "--title=Select Wallpapers Folder",
            "--filename=" + sorterModule.sourceDirectory + "/"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var selected = this.text.trim();
                if (selected.length > 0) {
                    sorterModule.sourceDirectory = selected;
                    sorterModule.hasCompleted = false;
                }
            }
        }
    }

    // Backend Wallpaper Sorter Python Process
    Process {
        id: sorterProcess
        running: false
        command: [
            "python3",
            (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/wallpaper_sorter.py",
            sorterModule.sourceDirectory,
            "--dest=" + sorterModule.targetDirectory,
            "--mode=" + sorterModule.copyMode,
            "--json"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                var line = data.trim();
                if (!line || line.length === 0) return;
                try {
                    var ev = JSON.parse(line);
                    if (ev.type === "start") {
                        sorterModule.totalFiles = ev.total_files;
                        sorterModule.currentProgress = 0;
                    } else if (ev.type === "progress") {
                        sorterModule.currentProgress = ev.current;
                        sorterModule.totalFiles = ev.total;
                        sorterModule.currentFile = ev.filename;
                        if (ev.status === "sorted") {
                            sorterModule.currentTheme = ev.theme;
                            sorterModule.currentHex = ev.hex;
                        } else {
                            sorterModule.currentTheme = "Duplicate";
                            sorterModule.currentHex = "#eab308";
                        }
                    } else if (ev.type === "done") {
                        sorterModule.isSorting = false;
                        sorterModule.hasCompleted = true;
                        sorterModule.totalFound = ev.total_found;
                        sorterModule.uniqueAdded = ev.unique_added;
                        sorterModule.duplicatesSkipped = ev.duplicates_skipped;
                        sorterModule.themeBreakdown = ev.by_theme || ({});
                        // Trigger reload of shell's global wallpaper cache
                        if (typeof globalWallpaperScanner !== "undefined" && !globalWallpaperScanner.running) {
                            globalWallpaperScanner.running = true;
                        }
                    }
                } catch(e) {
                    // Ignore non-json debug lines
                }
            }
        }
        onExited: {
            sorterModule.isSorting = false;
        }
    }

    function startSorting() {
        if (sorterModule.isSorting) return;
        sorterModule.hasCompleted = false;
        sorterModule.isSorting = true;
        sorterModule.currentProgress = 0;
        sorterModule.totalFiles = 0;
        sorterModule.currentFile = "Scanning folder...";
        sorterModule.currentTheme = "";
        sorterProcess.running = true;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 7

        // ── 1. COMPACT HEADER BAR ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8

            // Tactile Back Button
            Rectangle {
                width: 28; height: 28; radius: 14
                color: backMouse.containsMouse ? sorterModule.colCardHover : sorterModule.colCard
                border.width: 1
                border.color: sorterModule.colBorder
                scale: backMouse.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: 15
                    color: sorterModule.colAccent
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.switchMode("utility", true)
                }
            }

            // Title Only (Clean, Debloated)
            Text {
                text: "Wallpaper Color Sorter"
                font.family: "Noto Sans"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: sorterModule.colText
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }
        }

        // ── 2. FOLDER SELECTION CARD ───────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: 12
            color: sorterModule.colCard
            border.width: 1
            border.color: sorterModule.colBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        text: "Source Folder:"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: sorterModule.colSubtext
                    }

                    // Directory Path Input Box
                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: dirInput.activeFocus ? sorterModule.colAccent : sorterModule.colBorder

                        TextInput {
                            id: dirInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            text: sorterModule.sourceDirectory
                            font.family: "Readex Pro"
                            font.pixelSize: 11
                            color: sorterModule.colText
                            clip: true
                            onEditingFinished: sorterModule.sourceDirectory = text.trim()
                        }
                    }

                    // Browse Button
                    Rectangle {
                        width: 72; height: 24; radius: 6
                        color: browseMouse.containsMouse ? sorterModule.colCardHover : Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1
                        border.color: sorterModule.colBorder
                        scale: browseMouse.pressed ? 0.94 : 1.0

                        Row {
                            anchors.centerIn: parent
                            spacing: 3
                            MaterialSymbol {
                                text: "folder_open"
                                iconSize: 12
                                color: sorterModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Browse"
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: sorterModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: browseMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: folderChooser.running = true
                        }
                    }
                }

                // Quick Preset Chips (customwallpapers first)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Presets:"
                        font.family: "Noto Sans"
                        font.pixelSize: 10
                        color: sorterModule.colMuted
                    }

                    // Chip: ~/customwallpapers
                    Rectangle {
                        height: 18; radius: 4
                        color: chipCustomMouse.containsMouse ? sorterModule.colCardHover : Qt.rgba(255, 255, 255, 0.04)
                        border.width: 1; border.color: sorterModule.sourceDirectory.indexOf("customwallpapers") !== -1 ? sorterModule.colAccent : sorterModule.colBorder
                        implicitWidth: chipCustomText.implicitWidth + 10
                        Text {
                            id: chipCustomText
                            anchors.centerIn: parent
                            text: "customwallpapers"
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            color: sorterModule.sourceDirectory.indexOf("customwallpapers") !== -1 ? sorterModule.colAccent : sorterModule.colSubtext
                        }
                        MouseArea {
                            id: chipCustomMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                sorterModule.sourceDirectory = (Quickshell.env("HOME") || "") + "/customwallpapers";
                                sorterModule.hasCompleted = false;
                            }
                        }
                    }

                    // Chip: Downloads
                    Rectangle {
                        height: 18; radius: 4
                        color: chipDlMouse.containsMouse ? sorterModule.colCardHover : Qt.rgba(255, 255, 255, 0.04)
                        border.width: 1; border.color: sorterModule.colBorder
                        implicitWidth: chipDlText.implicitWidth + 10
                        Text {
                            id: chipDlText
                            anchors.centerIn: parent
                            text: "Downloads"
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            color: sorterModule.colSubtext
                        }
                        MouseArea {
                            id: chipDlMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                sorterModule.sourceDirectory = (Quickshell.env("HOME") || "") + "/Downloads";
                                sorterModule.hasCompleted = false;
                            }
                        }
                    }

                    // Chip: Pictures
                    Rectangle {
                        height: 18; radius: 4
                        color: chipPicMouse.containsMouse ? sorterModule.colCardHover : Qt.rgba(255, 255, 255, 0.04)
                        border.width: 1; border.color: sorterModule.colBorder
                        implicitWidth: chipPicText.implicitWidth + 10
                        Text {
                            id: chipPicText
                            anchors.centerIn: parent
                            text: "Pictures"
                            font.family: "Noto Sans"
                            font.pixelSize: 9
                            color: sorterModule.colSubtext
                        }
                        MouseArea {
                            id: chipPicMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                sorterModule.sourceDirectory = (Quickshell.env("HOME") || "") + "/Pictures";
                                sorterModule.hasCompleted = false;
                            }
                        }
                    }
                }
            }
        }

        // ── 3. TARGET THEMES PREVIEW ROW (COMPACT) ─────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 10
            color: sorterModule.colCard
            border.width: 1
            border.color: sorterModule.colBorder

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: [
                        { name: "Abyss", col: "#00e5ff" },
                        { name: "Verdant", col: "#05df72" },
                        { name: "Crimson", col: "#ff2a5f" },
                        { name: "Afterglow", col: "#f472b6" },
                        { name: "Solstice", col: "#ff9e3b" },
                        { name: "Frost", col: "#ffffff" }
                    ]

                    delegate: Rectangle {
                        height: 20
                        radius: 10
                        color: Qt.rgba(255, 255, 255, 0.04)
                        border.width: 1
                        border.color: modelData.col
                        implicitWidth: themePillRow.implicitWidth + 10

                        Row {
                            id: themePillRow
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: modelData.col
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.name
                                font.family: "Readex Pro"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: sorterModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }

        // ── 4. COMPACT ACTION & PROGRESS SECTION (NO GAPS) ─────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: sorterModule.colCard
            border.width: 1
            border.color: sorterModule.colBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 6

                // Live status text
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: sorterModule.isSorting ? "sync" : (sorterModule.hasCompleted ? "check_circle" : "auto_awesome")
                        iconSize: 14
                        color: sorterModule.hasCompleted ? "#30d158" : sorterModule.colAccent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: sorterModule.isSorting
                            ? `Sorting [${sorterModule.currentProgress}/${sorterModule.totalFiles}]: ${sorterModule.currentFile}`
                            : (sorterModule.hasCompleted
                                ? `Completed! Added ${sorterModule.uniqueAdded} unique wallpapers (${sorterModule.duplicatesSkipped} duplicates skipped)`
                                : "Ready to scan and sort wallpapers into theme directories.")
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: sorterModule.colText
                        elide: Text.ElideMiddle
                    }

                    // Progress percentage
                    Text {
                        visible: sorterModule.isSorting && sorterModule.totalFiles > 0
                        text: Math.round((sorterModule.currentProgress / Math.max(1, sorterModule.totalFiles)) * 100) + "%"
                        font.family: "Readex Pro"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: sorterModule.colAccent
                    }
                }

                // Progress Bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Qt.rgba(255, 255, 255, 0.08)
                    visible: sorterModule.isSorting

                    Rectangle {
                        height: parent.height
                        radius: 2
                        color: sorterModule.colAccent
                        width: parent.width * (sorterModule.currentProgress / Math.max(1, sorterModule.totalFiles))
                        Behavior on width { NumberAnimation { duration: 90 } }
                    }
                }

                // Completion Grid / Summary
                GridLayout {
                    visible: sorterModule.hasCompleted
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: 4
                    columnSpacing: 5

                    Repeater {
                        model: [
                            { name: "Abyss", count: sorterModule.themeBreakdown["Abyss"] || 0, col: "#00e5ff" },
                            { name: "Verdant", count: sorterModule.themeBreakdown["Verdant"] || 0, col: "#05df72" },
                            { name: "Crimson", count: sorterModule.themeBreakdown["Crimson"] || 0, col: "#ff2a5f" },
                            { name: "Afterglow", count: sorterModule.themeBreakdown["Afterglow"] || 0, col: "#f472b6" },
                            { name: "Solstice", count: sorterModule.themeBreakdown["Solstice"] || 0, col: "#ff9e3b" },
                            { name: "Frost", count: sorterModule.themeBreakdown["Frost"] || 0, col: "#ffffff" }
                        ]

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 22
                            radius: 5
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.width: 1
                            border.color: modelData.col

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 4

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: modelData.col
                                }
                                Text {
                                    text: modelData.name
                                    font.family: "Noto Sans"
                                    font.pixelSize: 9
                                    color: sorterModule.colText
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "+" + modelData.count
                                    font.family: "Readex Pro"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: modelData.col
                                }
                            }
                        }
                    }
                }

                // Action Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    // View Wallpapers Button (when completed)
                    Rectangle {
                        visible: sorterModule.hasCompleted
                        Layout.fillWidth: true
                        height: 30
                        radius: 7
                        color: viewMouse.containsMouse ? sorterModule.colCardHover : sorterModule.colCard
                        border.width: 1
                        border.color: sorterModule.colBorder

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            MaterialSymbol {
                                text: "wallpaper"
                                iconSize: 14
                                color: sorterModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Open Wallpaper Picker"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: sorterModule.colText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: viewMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.switchMode("wallpaper", false)
                        }
                    }

                    // Main Sort Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        radius: 7
                        color: sortMouse.containsMouse ? Qt.lighter(sorterModule.colAccent, 1.15) : sorterModule.colAccent
                        scale: sortMouse.pressed ? 0.96 : 1.0
                        opacity: sorterModule.isSorting ? 0.6 : 1.0

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            MaterialSymbol {
                                text: sorterModule.isSorting ? "sync" : "auto_awesome"
                                iconSize: 14
                                color: Theme.colors.bg ?? "#000000"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: sorterModule.isSorting ? "Sorting In Progress..." : "Sort Wallpapers Now"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Theme.colors.bg ?? "#000000"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: sortMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            enabled: !sorterModule.isSorting
                            onClicked: sorterModule.startSorting()
                        }
                    }
                }
            }
        }
    }
}
